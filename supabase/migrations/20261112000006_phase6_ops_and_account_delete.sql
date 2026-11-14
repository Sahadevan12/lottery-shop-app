-- Migration: 20261112000006_phase6_ops_and_account_delete.sql
-- Description: Phase 6 — Operations, 30-day closed-draw cleanup via pg_cron,
--              storage_usage monitoring view, and delete_my_shop_and_account() RPC.
--
-- Includes:
--   1. cleanup_old_closed_draws(): deletes tickets + stock_batches for draws where
--      status = 'CLOSED' and closed_at < now() - interval '30 days'. Leaves wins,
--      ledger_entries, and draw_summaries untouched (§6.6).
--   2. pg_cron daily schedule at 21:30 UTC (03:00 AM IST).
--   3. storage_usage view (§6.7): per-table row estimate, total bytes, pretty size,
--      and percentage of the 500 MB Supabase Free Tier limit.
--   4. delete_my_shop_and_account(): zero-argument SECURITY DEFINER RPC using only
--      auth.uid() to permanently delete the caller's shop, all child data, and
--      auth.users record (Play Store account deletion requirement).

-- ============================================================================
-- 1. 30-DAY TICKET & STOCK BATCH CLEANUP (§6.6)
-- ============================================================================

create or replace function public.cleanup_old_closed_draws()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleted_tickets bigint := 0;
  v_deleted_batches bigint := 0;
begin
  -- Delete expanded tickets for draws closed more than 30 days ago
  -- (uses draws.closed_at, NOT draw_date).
  -- wins.ticket_id has ON DELETE SET NULL and keeps series + number on wins.
  with eligible_draws as (
    select d.id
    from public.draws d
    where d.status = 'CLOSED'
      and d.closed_at is not null
      and d.closed_at < now() - interval '30 days'
  ),
  del_tickets as (
    delete from public.tickets t
    using eligible_draws ed
    where t.draw_id = ed.id
    returning t.id
  )
  select count(*) into v_deleted_tickets from del_tickets;

  -- Also delete stock_batches for those closed draws (> 30 days after closed_at).
  with eligible_draws as (
    select d.id
    from public.draws d
    where d.status = 'CLOSED'
      and d.closed_at is not null
      and d.closed_at < now() - interval '30 days'
  ),
  del_batches as (
    delete from public.stock_batches sb
    using eligible_draws ed
    where sb.draw_id = ed.id
    returning sb.id
  )
  select count(*) into v_deleted_batches from del_batches;

  return jsonb_build_object(
    'deleted_tickets', coalesce(v_deleted_tickets, 0),
    'deleted_batches', coalesce(v_deleted_batches, 0)
  );
end;
$$;

revoke all on function public.cleanup_old_closed_draws() from public, anon, authenticated;
grant execute on function public.cleanup_old_closed_draws() to postgres, service_role;

-- Schedule daily cleanup at 21:30 UTC (03:00 AM IST) via pg_cron when available.
do $$
begin
  if exists (select 1 from pg_available_extensions where name = 'pg_cron') then
    create extension if not exists pg_cron;
    if exists (
      select 1
      from cron.job
      where jobname = 'cleanup-closed-draw-tickets-30d'
    ) then
      perform cron.unschedule('cleanup-closed-draw-tickets-30d');
    end if;
    perform cron.schedule(
      'cleanup-closed-draw-tickets-30d',
      '30 21 * * *',
      $cron$select public.cleanup_old_closed_draws();$cron$
    );
  end if;
exception
  when others then
    -- If pg_cron cannot be enabled in a restricted local test container,
    -- cleanup_old_closed_draws() remains directly callable and testable.
    null;
end;
$$;

-- ============================================================================
-- 2. STORAGE USAGE MONITORING VIEW (§6.7)
-- ============================================================================

create or replace view public.storage_usage as
select
  c.relname::text as table_name,
  greatest(c.reltuples::bigint, 0) as estimated_rows,
  pg_total_relation_size(c.oid) as total_bytes,
  pg_size_pretty(pg_total_relation_size(c.oid)) as total_size_pretty,
  round(
    (pg_total_relation_size(c.oid)::numeric / (500.0 * 1024.0 * 1024.0)) * 100.0,
    2
  ) as pct_of_500mb_limit
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in (
    'shops',
    'sellers',
    'lotteries',
    'prize_templates',
    'prize_template_tiers',
    'draws',
    'draw_prize_tiers',
    'stock_batches',
    'tickets',
    'ledger_entries',
    'draw_results',
    'wins',
    'draw_summaries'
  )
order by pg_total_relation_size(c.oid) desc, c.relname asc;

grant select on public.storage_usage to authenticated, service_role, postgres;

-- ============================================================================
-- 3. ACCOUNT & SHOP DELETION RPC (Play Store Data Deletion Requirement)
-- ============================================================================

-- Update enforce_ledger_immutability() to permit delete_my_shop_and_account()
-- (running as SECURITY DEFINER owner) to purge only the shop recorded in the
-- transaction-local setting 'app.deleting_shop_id', while keeping all other
-- ledger rows strictly immutable.
create or replace function public.enforce_ledger_immutability()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_deleting_shop text := coalesce(current_setting('app.deleting_shop_id', true), '');
begin
  -- 1. Privileged backend roles (postgres, service_role, supabase_admin, supabase_auth_admin)
  --    when not impersonating 'authenticated' or 'anon'.
  if session_user in ('postgres', 'service_role', 'supabase_admin', 'supabase_auth_admin')
     and coalesce(current_setting('role', true), '') not in ('authenticated', 'anon') then
    if tg_level = 'ROW' and tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  -- 2. Controlled shop deletion inside delete_my_shop_and_account() (SECURITY DEFINER):
  --    current_user is the function owner ('postgres' / 'supabase_admin') and
  --    'app.deleting_shop_id' is set to the authenticated caller's own shop_id.
  if current_user in ('postgres', 'service_role', 'supabase_admin', 'supabase_auth_admin')
     and v_deleting_shop <> '' then
    if tg_level = 'STATEMENT' then
      return null;
    end if;
    if tg_level = 'ROW' and old.shop_id::text = v_deleting_shop then
      if tg_op = 'DELETE' then
        return old;
      end if;
      return new;
    end if;
  end if;

  -- 3. Row DELETE when the parent shop row has already been deleted.
  if tg_level = 'ROW' and tg_op = 'DELETE' and not exists (select 1 from public.shops where id = old.shop_id) then
    return old;
  end if;

  raise exception 'LEDGER_IMMUTABLE'
    using detail = 'Ledger entries cannot be modified or deleted. Use reverse_ledger_entry instead.';
end;
$$;

create or replace function public.delete_my_shop_and_account()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_shop_id uuid;
begin
  if v_uid is null then
    raise exception 'UNAUTHENTICATED'
      using detail = 'Must be signed in to delete your account.';
  end if;

  select s.id
  into v_shop_id
  from public.shops s
  where s.owner_id = v_uid
  for update;

  if v_shop_id is not null then
    -- Mark transaction-local shop deletion flag for enforce_ledger_immutability()
    perform set_config('app.deleting_shop_id', v_shop_id::text, true);

    -- Delete child records in strict dependency order so ON DELETE NO ACTION
    -- constraints on tickets.seller_id, ledger_entries.seller_id,
    -- ledger_entries.reversed_entry_id, draws.lottery_id, and wins.tier_id
    -- are satisfied cleanly.
    delete from public.wins where shop_id = v_shop_id;
    delete from public.draw_summaries where shop_id = v_shop_id;
    delete from public.tickets where shop_id = v_shop_id;
    delete from public.stock_batches where shop_id = v_shop_id;

    update public.ledger_entries
    set reversed_entry_id = null
    where shop_id = v_shop_id
      and reversed_entry_id is not null;

    delete from public.ledger_entries where shop_id = v_shop_id;
    delete from public.draws where shop_id = v_shop_id;
    delete from public.prize_templates where shop_id = v_shop_id;
    delete from public.lotteries where shop_id = v_shop_id;
    delete from public.sellers where shop_id = v_shop_id;
    delete from public.shops where id = v_shop_id;

    perform set_config('app.deleting_shop_id', '', true);
  end if;

  -- Delete the caller's auth.users row
  delete from auth.users where id = v_uid;

  return jsonb_build_object(
    'deleted_user_id', v_uid,
    'deleted_shop_id', v_shop_id
  );
end;
$$;

revoke all on function public.delete_my_shop_and_account() from public, anon;
grant execute on function public.delete_my_shop_and_account() to authenticated;
