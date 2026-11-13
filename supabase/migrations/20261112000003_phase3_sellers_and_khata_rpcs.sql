-- Migration: 20261112000003_phase3_sellers_and_khata_rpcs.sql
-- Description: Phase 3 — Sellers & Khata data safety, triggers, and atomic RPCs:
--   1. Multi-range STOCK_OVERLAP detail in create_stock_batch (A.1)
--   2. Change ledger_entries.seller_id, tickets.seller_id, and ledger_entries.reversed_entry_id
--      FKs to ON DELETE NO ACTION
--   3. Replace ledger_entries "for all" RLS policy with SELECT + INSERT only, replace shops
--      "for all" RLS policy with SELECT + INSERT + UPDATE only, and add trg_ledger_entries_immutable
--      blocking app roles (authenticated/anon) while allowing postgres/service_role and admin
--      shop/account cascade deletes
--   4. Lock draws.ticket_price once any ledger_entries row exists for that draw ('PRICE_LOCKED', B.12)
--   5. RPCs:
--      - issue_tickets(p_seller_id, p_draw_id, p_ticket_ids) with SELECT ... FOR UPDATE (B.11)
--      - return_tickets(p_seller_id, p_draw_id, p_ticket_ids) allowing UPCOMING or RESULT_ENTERED,
--        blocking only CLOSED ('DRAW_NOT_OPEN'), with SELECT ... FOR UPDATE (B.11)
--      - record_payment(p_seller_id, p_amount, p_payment_method, p_note) with 0 < amount <= 1000000 (A.5, B.13)
--      - record_prize_paid_by_seller(p_seller_id, p_draw_id, p_amount, p_note) with 0 < amount <= 1000000 (A.5)
--      - reverse_ledger_entry(p_entry_id) for PAYMENT, PRIZE_PAID_BY_SELLER, ADJUSTMENT (A.2)
--      - mark_counter_sold(p_draw_id, p_series, p_start_number, p_end_number) (A.4, B.11)
--      - unmark_counter_sold(p_draw_id, p_series, p_start_number, p_end_number) (A.4, B.11)
--      - seller_balances() (§6.5)

-- ============================================================================
-- 1. FOREIGN KEY PROTECTION (ON DELETE NO ACTION) & REVERSAL LINK COLUMN
-- ============================================================================

alter table ledger_entries
  drop constraint if exists ledger_entries_seller_id_fkey;

alter table ledger_entries
  add constraint ledger_entries_seller_id_fkey
  foreign key (seller_id) references sellers(id) on delete no action;

alter table tickets
  drop constraint if exists tickets_seller_id_fkey;

alter table tickets
  add constraint tickets_seller_id_fkey
  foreign key (seller_id) references sellers(id) on delete no action;

alter table ledger_entries
  add column if not exists reversed_entry_id uuid unique;

alter table ledger_entries
  drop constraint if exists ledger_entries_reversed_entry_id_fkey;

alter table ledger_entries
  add constraint ledger_entries_reversed_entry_id_fkey
  foreign key (reversed_entry_id) references ledger_entries(id) on delete no action;

-- ============================================================================
-- 2. LEDGER IMMUTABILITY RLS + TRIGGER & SHOP CASCADE SUPPORT
-- ============================================================================

drop policy if exists "owner access" on ledger_entries;

create policy "owner select" on ledger_entries
  for select
  using (shop_id in (select id from shops where owner_id = auth.uid()));

create policy "owner insert" on ledger_entries
  for insert
  with check (shop_id in (select id from shops where owner_id = auth.uid()));

-- Restrict shops RLS for authenticated users to SELECT, INSERT, UPDATE only (no direct DELETE by app role)
drop policy if exists "owner access" on shops;

create policy "owner select" on shops
  for select
  using (owner_id = auth.uid());

create policy "owner insert" on shops
  for insert
  with check (owner_id = auth.uid());

create policy "owner update" on shops
  for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

create or replace function enforce_ledger_immutability()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- 1. Allow privileged backend roles (postgres, service_role, supabase_auth_admin)
  --    when not impersonating 'authenticated' or 'anon'.
  if session_user in ('postgres', 'service_role', 'supabase_admin', 'supabase_auth_admin')
     and coalesce(current_setting('role', true), '') not in ('authenticated', 'anon') then
    if tg_level = 'ROW' and tg_op = 'DELETE' then
      return old;
    end if;
    return new;
  end if;

  -- 2. Allow row DELETE when the parent shop row has already been deleted (ON DELETE CASCADE from shops/auth.users).
  --    Authenticated users have no DELETE RLS policy on shops, so they can never trigger this path.
  if tg_level = 'ROW' and tg_op = 'DELETE' and not exists (select 1 from shops where id = old.shop_id) then
    return old;
  end if;

  raise exception 'LEDGER_IMMUTABLE'
    using detail = 'Ledger entries cannot be modified or deleted. Use reverse_ledger_entry instead.';
end;
$$;

drop trigger if exists trg_ledger_entries_immutable_stmt on ledger_entries;
create trigger trg_ledger_entries_immutable_stmt
  before update or delete on ledger_entries
  for each statement
  execute function enforce_ledger_immutability();

drop trigger if exists trg_ledger_entries_immutable on ledger_entries;
create trigger trg_ledger_entries_immutable
  before update or delete on ledger_entries
  for each row
  execute function enforce_ledger_immutability();

-- ============================================================================
-- 3. LOCK DRAW TICKET PRICE ONCE LEDGER ENTRIES EXIST (B.12)
-- ============================================================================

create or replace function enforce_draw_ticket_price_lock()
returns trigger
language plpgsql
security invoker
as $$
begin
  if new.ticket_price is distinct from old.ticket_price then
    if exists (select 1 from ledger_entries where draw_id = old.id) then
      raise exception 'PRICE_LOCKED'
        using detail = 'Cannot change ticket price after ledger entries exist for this draw.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_draws_lock_ticket_price on draws;
create trigger trg_draws_lock_ticket_price
  before update of ticket_price on draws
  for each row
  execute function enforce_draw_ticket_price_lock();

-- ============================================================================
-- 4. RPC: create_stock_batch (A.1 — Multi-Range STOCK_OVERLAP Detail)
-- ============================================================================

create or replace function create_stock_batch(
  p_draw_id uuid,
  p_series text,
  p_start_number text,
  p_end_number text,
  p_cost_per_ticket numeric(10,2) default null
)
returns uuid
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_draw_status text;
  v_series text := upper(trim(coalesce(p_series, '')));
  v_start_str text := trim(coalesce(p_start_number, ''));
  v_end_str text := trim(coalesce(p_end_number, ''));
  v_start_int int;
  v_end_int int;
  v_quantity int;
  v_overlap_detail text;
  v_batch_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required.';
  end if;

  select id into v_shop_id
  from shops
  where owner_id = v_user_id;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for current user.';
  end if;

  -- Verify draw_id belongs to caller's shop and lock row for status check
  select status into v_draw_status
  from draws
  where id = p_draw_id and shop_id = v_shop_id
  for share;

  if v_draw_status is null then
    raise exception 'NOT_FOUND' using detail = 'Draw does not belong to this shop.';
  end if;

  if v_draw_status <> 'UPCOMING' then
    raise exception 'DRAW_NOT_OPEN'
      using detail = 'Stock can only be added when draw status is UPCOMING.';
  end if;

  -- Validate series and 6-digit range
  if v_series !~ '^[A-Z]{1,3}$' then
    raise exception 'INVALID_RANGE'
      using detail = 'Series must be 1 to 3 uppercase letters.';
  end if;

  if v_start_str !~ '^\d{1,6}$' or v_end_str !~ '^\d{1,6}$' then
    raise exception 'INVALID_RANGE'
      using detail = 'Start and end ticket numbers must be 6 digits.';
  end if;

  v_start_int := v_start_str::int;
  v_end_int := v_end_str::int;
  v_start_str := lpad(v_start_int::text, 6, '0');
  v_end_str := lpad(v_end_int::text, 6, '0');

  if v_end_int < v_start_int then
    raise exception 'INVALID_RANGE'
      using detail = 'End number must be greater than or equal to start number.';
  end if;

  v_quantity := v_end_int - v_start_int + 1;
  if v_quantity > 5000 then
    raise exception 'INVALID_RANGE'
      using detail = 'Maximum 5,000 tickets allowed per batch.';
  end if;

  -- Compute ALL overlapping contiguous ticket islands for this draw & series
  select string_agg(
    format('%s %s–%s', v_series, min_num, max_num),
    ', ' order by min_num
  )
  into v_overlap_detail
  from (
    select
      min(number) as min_num,
      max(number) as max_num
    from (
      select
        number,
        (number::int - row_number() over (order by number::int)) as grp
      from tickets
      where draw_id = p_draw_id
        and series = v_series
        and number between v_start_str and v_end_str
    ) t
    group by grp
  ) islands;

  if v_overlap_detail is not null then
    raise exception 'STOCK_OVERLAP'
      using detail = v_overlap_detail;
  end if;

  begin
    insert into stock_batches (
      shop_id,
      draw_id,
      series,
      start_number,
      end_number,
      quantity,
      cost_per_ticket
    )
    values (
      v_shop_id,
      p_draw_id,
      v_series,
      v_start_str,
      v_end_str,
      v_quantity,
      p_cost_per_ticket
    )
    returning id into v_batch_id;

    insert into tickets (
      shop_id,
      draw_id,
      batch_id,
      series,
      number,
      status
    )
    select
      v_shop_id,
      p_draw_id,
      v_batch_id,
      v_series,
      lpad(gs::text, 6, '0'),
      'IN_STOCK'
    from generate_series(v_start_int, v_end_int) as gs;
  exception
    when unique_violation then
      raise exception 'STOCK_OVERLAP'
        using detail = format('%s %s–%s', v_series, v_start_str, v_end_str);
  end;

  return v_batch_id;
end;
$$;

-- ============================================================================
-- 5. RPC: issue_tickets (B.11, A.3, §7.2)
-- ============================================================================

create or replace function issue_tickets(
  p_seller_id uuid,
  p_draw_id uuid,
  p_ticket_ids uuid[]
)
returns uuid
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_seller_active boolean;
  v_draw_status text;
  v_ticket_price numeric(10,2);
  v_unique_ids uuid[];
  v_expected_count int;
  v_locked_count int;
  v_non_stock_count int;
  v_entry_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required.';
  end if;

  select id into v_shop_id
  from shops
  where owner_id = v_user_id;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for current user.';
  end if;

  if p_ticket_ids is null then
    raise exception 'INVALID_RANGE' using detail = 'Ticket list cannot be empty.';
  end if;

  select array_agg(distinct u.id)
  into v_unique_ids
  from unnest(p_ticket_ids) as u(id);

  v_expected_count := coalesce(cardinality(v_unique_ids), 0);
  if v_expected_count < 1 or v_expected_count > 5000 then
    raise exception 'INVALID_RANGE'
      using detail = 'Must issue between 1 and 5,000 tickets per call.';
  end if;

  -- Verify seller belongs to caller's shop and is active
  select is_active into v_seller_active
  from sellers
  where id = p_seller_id and shop_id = v_shop_id
  for share;

  if v_seller_active is null then
    raise exception 'NOT_FOUND' using detail = 'Seller does not belong to this shop.';
  end if;

  if not v_seller_active then
    raise exception 'SELLER_INACTIVE' using detail = 'Cannot issue tickets to an inactive seller.';
  end if;

  -- Verify draw belongs to caller's shop and is UPCOMING
  select status, ticket_price
  into v_draw_status, v_ticket_price
  from draws
  where id = p_draw_id and shop_id = v_shop_id
  for share;

  if v_draw_status is null then
    raise exception 'NOT_FOUND' using detail = 'Draw does not belong to this shop.';
  end if;

  if v_draw_status <> 'UPCOMING' then
    raise exception 'DRAW_NOT_OPEN'
      using detail = 'Tickets can only be issued when draw status is UPCOMING.';
  end if;

  -- Lock target tickets in deterministic id order before checking status
  with locked as (
    select id, status
    from tickets
    where shop_id = v_shop_id
      and draw_id = p_draw_id
      and id = any(v_unique_ids)
    order by id
    for update
  )
  select
    count(*),
    count(*) filter (where status <> 'IN_STOCK')
  into v_locked_count, v_non_stock_count
  from locked;

  if v_locked_count <> v_expected_count or v_non_stock_count > 0 then
    raise exception 'TICKETS_NOT_AVAILABLE'
      using detail = 'One or more selected tickets are no longer IN_STOCK.';
  end if;

  update tickets
  set status = 'WITH_SELLER',
      seller_id = p_seller_id,
      updated_at = now()
  where shop_id = v_shop_id
    and draw_id = p_draw_id
    and id = any(v_unique_ids);

  insert into ledger_entries (
    shop_id,
    seller_id,
    draw_id,
    type,
    amount,
    ticket_count
  )
  values (
    v_shop_id,
    p_seller_id,
    p_draw_id,
    'ISSUE',
    round(v_expected_count * v_ticket_price, 2),
    v_expected_count
  )
  returning id into v_entry_id;

  return v_entry_id;
end;
$$;

-- ============================================================================
-- 6. RPC: return_tickets (B.11, §7.3 — allows UPCOMING or RESULT_ENTERED)
-- ============================================================================

create or replace function return_tickets(
  p_seller_id uuid,
  p_draw_id uuid,
  p_ticket_ids uuid[]
)
returns uuid
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_draw_status text;
  v_draw_date date;
  v_draw_time time;
  v_ticket_price numeric(10,2);
  v_unique_ids uuid[];
  v_expected_count int;
  v_locked_count int;
  v_invalid_count int;
  v_before_draw boolean;
  v_entry_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required.';
  end if;

  select id into v_shop_id
  from shops
  where owner_id = v_user_id;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for current user.';
  end if;

  if p_ticket_ids is null then
    raise exception 'INVALID_RANGE' using detail = 'Ticket list cannot be empty.';
  end if;

  select array_agg(distinct u.id)
  into v_unique_ids
  from unnest(p_ticket_ids) as u(id);

  v_expected_count := coalesce(cardinality(v_unique_ids), 0);
  if v_expected_count < 1 or v_expected_count > 5000 then
    raise exception 'INVALID_RANGE'
      using detail = 'Must return between 1 and 5,000 tickets per call.';
  end if;

  if not exists (
    select 1 from sellers
    where id = p_seller_id and shop_id = v_shop_id
  ) then
    raise exception 'NOT_FOUND' using detail = 'Seller does not belong to this shop.';
  end if;

  select status, draw_date, draw_time, ticket_price
  into v_draw_status, v_draw_date, v_draw_time, v_ticket_price
  from draws
  where id = p_draw_id and shop_id = v_shop_id
  for share;

  if v_draw_status is null then
    raise exception 'NOT_FOUND' using detail = 'Draw does not belong to this shop.';
  end if;

  -- Allow UPCOMING or RESULT_ENTERED; only block when status = 'CLOSED'
  if v_draw_status = 'CLOSED' then
    raise exception 'DRAW_NOT_OPEN'
      using detail = 'Tickets cannot be returned once the draw is CLOSED.';
  end if;

  -- Lock target tickets in deterministic id order before checking status & seller
  with locked as (
    select id, status, seller_id
    from tickets
    where shop_id = v_shop_id
      and draw_id = p_draw_id
      and id = any(v_unique_ids)
    order by id
    for update
  )
  select
    count(*),
    count(*) filter (where status <> 'WITH_SELLER' or seller_id is distinct from p_seller_id)
  into v_locked_count, v_invalid_count
  from locked;

  if v_locked_count <> v_expected_count or v_invalid_count > 0 then
    raise exception 'TICKETS_NOT_WITH_SELLER'
      using detail = 'One or more tickets are not currently with this seller.';
  end if;

  v_before_draw := (v_draw_status = 'UPCOMING')
    and (((v_draw_date + v_draw_time) at time zone 'Asia/Kolkata') > now());

  if v_before_draw then
    update tickets
    set status = 'IN_STOCK',
        seller_id = null,
        updated_at = now()
    where shop_id = v_shop_id
      and draw_id = p_draw_id
      and id = any(v_unique_ids);
  else
    update tickets
    set status = 'RETURNED_UNSOLD',
        updated_at = now()
    where shop_id = v_shop_id
      and draw_id = p_draw_id
      and id = any(v_unique_ids);
  end if;

  insert into ledger_entries (
    shop_id,
    seller_id,
    draw_id,
    type,
    amount,
    ticket_count
  )
  values (
    v_shop_id,
    p_seller_id,
    p_draw_id,
    'RETURN',
    -round(v_expected_count * v_ticket_price, 2),
    v_expected_count
  )
  returning id into v_entry_id;

  return v_entry_id;
end;
$$;

-- ============================================================================
-- 7. RPC: record_payment & record_prize_paid_by_seller (A.5, B.13, §7.4)
-- ============================================================================

create or replace function record_payment(
  p_seller_id uuid,
  p_amount numeric(12,2),
  p_payment_method text,
  p_note text default null
)
returns uuid
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_method text := upper(trim(coalesce(p_payment_method, '')));
  v_entry_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required.';
  end if;

  select id into v_shop_id
  from shops
  where owner_id = v_user_id;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for current user.';
  end if;

  if not exists (
    select 1 from sellers
    where id = p_seller_id and shop_id = v_shop_id
  ) then
    raise exception 'NOT_FOUND' using detail = 'Seller does not belong to this shop.';
  end if;

  if p_amount is null or p_amount <= 0 or p_amount > 1000000 then
    raise exception 'INVALID_AMOUNT'
      using detail = 'Amount must be greater than 0 and at most ₹10,00,000.';
  end if;

  if v_method not in ('CASH', 'UPI', 'OTHER') then
    raise exception 'INVALID_AMOUNT'
      using detail = 'Payment method must be CASH, UPI, or OTHER.';
  end if;

  insert into ledger_entries (
    shop_id,
    seller_id,
    type,
    amount,
    payment_method,
    note
  )
  values (
    v_shop_id,
    p_seller_id,
    'PAYMENT',
    -round(p_amount, 2),
    v_method,
    nullif(trim(coalesce(p_note, '')), '')
  )
  returning id into v_entry_id;

  return v_entry_id;
end;
$$;

create or replace function record_prize_paid_by_seller(
  p_seller_id uuid,
  p_draw_id uuid,
  p_amount numeric(12,2),
  p_note text default null
)
returns uuid
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_entry_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required.';
  end if;

  select id into v_shop_id
  from shops
  where owner_id = v_user_id;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for current user.';
  end if;

  if not exists (
    select 1 from sellers
    where id = p_seller_id and shop_id = v_shop_id
  ) then
    raise exception 'NOT_FOUND' using detail = 'Seller does not belong to this shop.';
  end if;

  if p_draw_id is null or not exists (
    select 1 from draws
    where id = p_draw_id and shop_id = v_shop_id
  ) then
    raise exception 'NOT_FOUND' using detail = 'Draw does not belong to this shop.';
  end if;

  if p_amount is null or p_amount <= 0 or p_amount > 1000000 then
    raise exception 'INVALID_AMOUNT'
      using detail = 'Amount must be greater than 0 and at most ₹10,00,000.';
  end if;

  insert into ledger_entries (
    shop_id,
    seller_id,
    draw_id,
    type,
    amount,
    note
  )
  values (
    v_shop_id,
    p_seller_id,
    p_draw_id,
    'PRIZE_PAID_BY_SELLER',
    -round(p_amount, 2),
    nullif(trim(coalesce(p_note, '')), '')
  )
  returning id into v_entry_id;

  return v_entry_id;
end;
$$;

-- ============================================================================
-- 8. RPC: reverse_ledger_entry (A.2)
-- ============================================================================

create or replace function reverse_ledger_entry(
  p_entry_id uuid
)
returns uuid
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_entry record;
  v_new_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required.';
  end if;

  select id into v_shop_id
  from shops
  where owner_id = v_user_id;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for current user.';
  end if;

  select id, shop_id, seller_id, draw_id, type, amount, reversed_entry_id
  into v_entry
  from ledger_entries
  where id = p_entry_id and shop_id = v_shop_id;

  if v_entry.id is null then
    raise exception 'NOT_FOUND' using detail = 'Ledger entry not found.';
  end if;

  -- Lock parent seller row to serialize concurrent reversal attempts
  perform 1
  from sellers
  where id = v_entry.seller_id and shop_id = v_shop_id
  for update;

  if v_entry.type not in ('PAYMENT', 'PRIZE_PAID_BY_SELLER', 'ADJUSTMENT') then
    raise exception 'NOT_REVERSIBLE'
      using detail = 'Only PAYMENT, PRIZE_PAID_BY_SELLER, and ADJUSTMENT entries can be reversed.';
  end if;

  if v_entry.reversed_entry_id is not null or exists (
    select 1 from ledger_entries
    where reversed_entry_id = p_entry_id
  ) then
    raise exception 'ALREADY_REVERSED'
      using detail = 'This ledger entry has already been reversed.';
  end if;

  begin
    insert into ledger_entries (
      shop_id,
      seller_id,
      draw_id,
      type,
      amount,
      reversed_entry_id,
      note
    )
    values (
      v_shop_id,
      v_entry.seller_id,
      v_entry.draw_id,
      'ADJUSTMENT',
      -v_entry.amount,
      p_entry_id,
      'Reversal of ' || p_entry_id::text
    )
    returning id into v_new_id;
  exception
    when unique_violation then
      raise exception 'ALREADY_REVERSED'
        using detail = 'This ledger entry has already been reversed.';
  end;

  return v_new_id;
end;
$$;

-- ============================================================================
-- 9. RPCs: mark_counter_sold & unmark_counter_sold (A.4, B.11)
-- ============================================================================

create or replace function mark_counter_sold(
  p_draw_id uuid,
  p_series text,
  p_start_number text,
  p_end_number text
)
returns int
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_draw_status text;
  v_series text := upper(trim(coalesce(p_series, '')));
  v_start_str text := trim(coalesce(p_start_number, ''));
  v_end_str text := trim(coalesce(p_end_number, ''));
  v_start_int int;
  v_end_int int;
  v_expected_count int;
  v_locked_count int;
  v_non_stock_count int;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required.';
  end if;

  select id into v_shop_id
  from shops
  where owner_id = v_user_id;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for current user.';
  end if;

  select status into v_draw_status
  from draws
  where id = p_draw_id and shop_id = v_shop_id
  for share;

  if v_draw_status is null then
    raise exception 'NOT_FOUND' using detail = 'Draw does not belong to this shop.';
  end if;

  if v_draw_status <> 'UPCOMING' then
    raise exception 'DRAW_NOT_OPEN'
      using detail = 'Counter sales can only be marked when draw status is UPCOMING.';
  end if;

  if v_series !~ '^[A-Z]{1,3}$' or v_start_str !~ '^\d{1,6}$' or v_end_str !~ '^\d{1,6}$' then
    raise exception 'INVALID_RANGE' using detail = 'Invalid series or ticket number range.';
  end if;

  v_start_int := v_start_str::int;
  v_end_int := v_end_str::int;
  v_start_str := lpad(v_start_int::text, 6, '0');
  v_end_str := lpad(v_end_int::text, 6, '0');

  if v_end_int < v_start_int then
    raise exception 'INVALID_RANGE' using detail = 'End number must be >= start number.';
  end if;

  v_expected_count := v_end_int - v_start_int + 1;
  if v_expected_count > 5000 then
    raise exception 'INVALID_RANGE' using detail = 'Maximum 5,000 tickets allowed per range.';
  end if;

  with locked as (
    select id, status
    from tickets
    where shop_id = v_shop_id
      and draw_id = p_draw_id
      and series = v_series
      and number between v_start_str and v_end_str
    order by id
    for update
  )
  select
    count(*),
    count(*) filter (where status <> 'IN_STOCK')
  into v_locked_count, v_non_stock_count
  from locked;

  if v_locked_count <> v_expected_count or v_non_stock_count > 0 then
    raise exception 'TICKETS_NOT_AVAILABLE'
      using detail = 'All tickets in the range must exist and be IN_STOCK.';
  end if;

  update tickets
  set status = 'SOLD_COUNTER',
      updated_at = now()
  where shop_id = v_shop_id
    and draw_id = p_draw_id
    and series = v_series
    and number between v_start_str and v_end_str;

  return v_expected_count;
end;
$$;

create or replace function unmark_counter_sold(
  p_draw_id uuid,
  p_series text,
  p_start_number text,
  p_end_number text
)
returns int
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_draw_status text;
  v_series text := upper(trim(coalesce(p_series, '')));
  v_start_str text := trim(coalesce(p_start_number, ''));
  v_end_str text := trim(coalesce(p_end_number, ''));
  v_start_int int;
  v_end_int int;
  v_expected_count int;
  v_locked_count int;
  v_non_counter_count int;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required.';
  end if;

  select id into v_shop_id
  from shops
  where owner_id = v_user_id;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for current user.';
  end if;

  select status into v_draw_status
  from draws
  where id = p_draw_id and shop_id = v_shop_id
  for share;

  if v_draw_status is null then
    raise exception 'NOT_FOUND' using detail = 'Draw does not belong to this shop.';
  end if;

  if v_draw_status <> 'UPCOMING' then
    raise exception 'DRAW_NOT_OPEN'
      using detail = 'Counter sales can only be unmarked when draw status is UPCOMING.';
  end if;

  if v_series !~ '^[A-Z]{1,3}$' or v_start_str !~ '^\d{1,6}$' or v_end_str !~ '^\d{1,6}$' then
    raise exception 'INVALID_RANGE' using detail = 'Invalid series or ticket number range.';
  end if;

  v_start_int := v_start_str::int;
  v_end_int := v_end_str::int;
  v_start_str := lpad(v_start_int::text, 6, '0');
  v_end_str := lpad(v_end_int::text, 6, '0');

  if v_end_int < v_start_int then
    raise exception 'INVALID_RANGE' using detail = 'End number must be >= start number.';
  end if;

  v_expected_count := v_end_int - v_start_int + 1;
  if v_expected_count > 5000 then
    raise exception 'INVALID_RANGE' using detail = 'Maximum 5,000 tickets allowed per range.';
  end if;

  with locked as (
    select id, status
    from tickets
    where shop_id = v_shop_id
      and draw_id = p_draw_id
      and series = v_series
      and number between v_start_str and v_end_str
    order by id
    for update
  )
  select
    count(*),
    count(*) filter (where status <> 'SOLD_COUNTER')
  into v_locked_count, v_non_counter_count
  from locked;

  if v_locked_count <> v_expected_count or v_non_counter_count > 0 then
    raise exception 'TICKETS_NOT_AVAILABLE'
      using detail = 'All tickets in the range must exist and be SOLD_COUNTER.';
  end if;

  update tickets
  set status = 'IN_STOCK',
      updated_at = now()
  where shop_id = v_shop_id
    and draw_id = p_draw_id
    and series = v_series
    and number between v_start_str and v_end_str;

  return v_expected_count;
end;
$$;

-- ============================================================================
-- 10. RPC: seller_balances (§6.5)
-- ============================================================================

create or replace function seller_balances()
returns table (
  seller_id uuid,
  balance numeric(12,2),
  tickets_with_seller int,
  last_activity_at timestamptz
)
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required.';
  end if;

  select id into v_shop_id
  from shops
  where owner_id = v_user_id;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for current user.';
  end if;

  return query
  with ledger_agg as (
    select
      le.seller_id,
      coalesce(sum(le.amount), 0)::numeric(12,2) as balance,
      max(le.created_at) as last_entry_at
    from ledger_entries le
    where le.shop_id = v_shop_id
    group by le.seller_id
  ),
  ticket_agg as (
    select
      t.seller_id,
      count(*)::int as tickets_with_seller
    from tickets t
    where t.shop_id = v_shop_id
      and t.status = 'WITH_SELLER'
      and t.seller_id is not null
    group by t.seller_id
  )
  select
    s.id as seller_id,
    coalesce(la.balance, 0.00)::numeric(12,2) as balance,
    coalesce(ta.tickets_with_seller, 0)::int as tickets_with_seller,
    coalesce(la.last_entry_at, s.created_at) as last_activity_at
  from sellers s
  left join ledger_agg la on la.seller_id = s.id
  left join ticket_agg ta on ta.seller_id = s.id
  where s.shop_id = v_shop_id;
end;
$$;
