-- Migration: 20261112000002_phase2_draws_and_stock_rpcs.sql
-- Description: Phase 2 constraints and atomic RPCs for draws and stock batches:
--   1. unique (shop_id, lottery_id, draw_date) on draws
--   2. create_draw(p_lottery_id, p_draw_date, p_draw_number, p_ticket_price, p_template_id)
--   3. create_stock_batch(p_draw_id, p_series, p_start_number, p_end_number, p_cost_per_ticket)
--   4. delete_stock_batch(p_batch_id)

-- ============================================================================
-- 1. UNIQUE CONSTRAINT ON DRAWS
-- ============================================================================
alter table draws
  add constraint draws_shop_lottery_date_unique unique (shop_id, lottery_id, draw_date);

-- ============================================================================
-- 2. RPC: create_draw
-- ============================================================================
create or replace function create_draw(
  p_lottery_id uuid,
  p_draw_date date,
  p_draw_number text,
  p_ticket_price numeric(10,2),
  p_template_id uuid default null
)
returns uuid
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_draw_id uuid;
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

  -- Verify lottery_id belongs to caller's shop
  if not exists (
    select 1 from lotteries
    where id = p_lottery_id and shop_id = v_shop_id
  ) then
    raise exception 'NOT_FOUND' using detail = 'Lottery does not belong to this shop.';
  end if;

  -- Verify template_id (if provided) belongs to caller's shop
  if p_template_id is not null and not exists (
    select 1 from prize_templates
    where id = p_template_id and shop_id = v_shop_id
  ) then
    raise exception 'NOT_FOUND' using detail = 'Prize template does not belong to this shop.';
  end if;

  begin
    insert into draws (
      shop_id,
      lottery_id,
      draw_number,
      draw_date,
      ticket_price,
      status
    )
    values (
      v_shop_id,
      p_lottery_id,
      nullif(trim(coalesce(p_draw_number, '')), ''),
      p_draw_date,
      p_ticket_price,
      'UPCOMING'
    )
    returning id into v_draw_id;
  exception
    when unique_violation then
      raise exception 'DRAW_EXISTS'
        using detail = 'A draw for this lottery on this date already exists.';
  end;

  -- Copy template tiers into draw_prize_tiers if template_id was supplied
  if p_template_id is not null then
    insert into draw_prize_tiers (
      draw_id,
      tier_order,
      label,
      amount,
      match_type
    )
    select
      v_draw_id,
      ptt.tier_order,
      ptt.label,
      ptt.amount,
      ptt.match_type
    from prize_template_tiers ptt
    where ptt.template_id = p_template_id
    order by ptt.tier_order asc;
  end if;

  return v_draw_id;
end;
$$;

-- ============================================================================
-- 3. RPC: create_stock_batch
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
  v_overlap_min char(6);
  v_overlap_max char(6);
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

  -- Check overlap with existing tickets of the same draw & series
  select min(number), max(number)
  into v_overlap_min, v_overlap_max
  from tickets
  where draw_id = p_draw_id
    and series = v_series
    and number between v_start_str and v_end_str;

  if v_overlap_min is not null then
    raise exception 'STOCK_OVERLAP'
      using detail = format('%s %s–%s', v_series, v_overlap_min, v_overlap_max);
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
-- 4. RPC: delete_stock_batch
-- ============================================================================
create or replace function delete_stock_batch(
  p_batch_id uuid
)
returns void
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_batch_shop_id uuid;
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

  select shop_id into v_batch_shop_id
  from stock_batches
  where id = p_batch_id and shop_id = v_shop_id
  for update;

  if v_batch_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Stock batch does not belong to this shop.';
  end if;

  -- Allowed only if ALL tickets in the batch are IN_STOCK
  if exists (
    select 1 from tickets
    where batch_id = p_batch_id
      and status <> 'IN_STOCK'
  ) then
    raise exception 'BATCH_IN_USE'
      using detail = 'Cannot delete batch because one or more tickets are no longer IN_STOCK.';
  end if;

  delete from stock_batches
  where id = p_batch_id and shop_id = v_shop_id;
end;
$$;
