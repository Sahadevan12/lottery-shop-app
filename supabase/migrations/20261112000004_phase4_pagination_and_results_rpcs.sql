-- ============================================================================
-- LuckyLedger — Phase 4 Migration
-- Server-Side Pagination/Aggregation RPCs + Results, 10-Second Matcher & Close Draw
-- ============================================================================

-- ============================================================================
-- 1. INDEXES & RLS HARDENING ON wins (Rule 4 & Rule 5)
-- ============================================================================

create index if not exists idx_tickets_draw_last3
  on tickets (draw_id, right(number, 3));

create index if not exists idx_tickets_draw_status_series_num
  on tickets (draw_id, status, series, number);

-- wins table: app gets SELECT only via RLS.
-- Writes to wins only happen through check_draw, return_tickets, close_draw,
-- and update_win_claim_status.
drop policy if exists "owner access" on wins;
drop policy if exists "owner select" on wins;

create policy "owner select" on wins
  for select
  using (shop_id in (select id from shops where owner_id = auth.uid()));

-- ============================================================================
-- 2. SERVER-SIDE BATCH COUNTS & SELLER BREAKDOWN RPCs (Audit #2)
-- ============================================================================

create or replace function get_batches_for_draw(
  p_draw_id uuid
)
returns table (
  id uuid,
  shop_id uuid,
  draw_id uuid,
  series text,
  start_number text,
  end_number text,
  quantity int,
  cost_per_ticket numeric(10,2),
  created_at timestamptz,
  in_stock_count int,
  with_seller_count int,
  sold_count int,
  returned_count int
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

  select s.id into v_shop_id
  from shops s
  where s.owner_id = v_user_id;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for current user.';
  end if;

  return query
  with ticket_counts as (
    select
      t.batch_id,
      count(*) filter (where t.status = 'IN_STOCK')::int as in_stock_cnt,
      count(*) filter (where t.status = 'WITH_SELLER')::int as with_seller_cnt,
      count(*) filter (where t.status in ('SOLD_COUNTER', 'SOLD_BY_SELLER'))::int as sold_cnt,
      count(*) filter (where t.status = 'RETURNED_UNSOLD')::int as returned_cnt,
      count(*)::int as total_cnt
    from tickets t
    where t.shop_id = v_shop_id
      and t.draw_id = p_draw_id
    group by t.batch_id
  )
  select
    sb.id,
    sb.shop_id,
    sb.draw_id,
    trim(sb.series) as series,
    trim(sb.start_number::text) as start_number,
    trim(sb.end_number::text) as end_number,
    sb.quantity,
    sb.cost_per_ticket,
    sb.created_at,
    case
      when coalesce(tc.total_cnt, 0) = 0 then sb.quantity
      else coalesce(tc.in_stock_cnt, 0)
    end as in_stock_count,
    coalesce(tc.with_seller_cnt, 0) as with_seller_count,
    coalesce(tc.sold_cnt, 0) as sold_count,
    coalesce(tc.returned_cnt, 0) as returned_count
  from stock_batches sb
  left join ticket_counts tc on tc.batch_id = sb.id
  where sb.shop_id = v_shop_id
    and sb.draw_id = p_draw_id
  order by sb.created_at desc;
end;
$$;

-- Update seller_balances() to include has_ledger_history so the app never
-- queries raw ledger_entries to check if a seller has history.
drop function if exists seller_balances();

create or replace function seller_balances()
returns table (
  seller_id uuid,
  balance numeric(12,2),
  tickets_with_seller int,
  last_activity_at timestamptz,
  has_ledger_history boolean
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
      max(le.created_at) as last_entry_at,
      (count(*) > 0) as has_history
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
    coalesce(la.last_entry_at, s.created_at) as last_activity_at,
    coalesce(la.has_history, false) as has_ledger_history
  from sellers s
  left join ledger_agg la on la.seller_id = s.id
  left join ticket_agg ta on ta.seller_id = s.id
  where s.shop_id = v_shop_id;
end;
$$;

-- Server-side per-draw balance breakdown for a seller (Audit #2)
create or replace function get_seller_balance_breakdown(
  p_seller_id uuid
)
returns table (
  row_kind text,
  draw_id uuid,
  draw_label text,
  draw_date date,
  issued_amount numeric(12,2),
  issued_ticket_count int,
  returned_amount numeric(12,2),
  returned_ticket_count int,
  prize_paid_amount numeric(12,2),
  draw_adjustments_amount numeric(12,2),
  payments_total numeric(12,2),
  general_adjustments_total numeric(12,2),
  grand_total numeric(12,2)
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

  if not exists (
    select 1 from sellers s where s.id = p_seller_id and s.shop_id = v_shop_id
  ) then
    raise exception 'NOT_FOUND' using detail = 'Seller does not belong to this shop.';
  end if;

  return query
  with draw_rows as (
    select
      'DRAW'::text as r_kind,
      le.draw_id as d_id,
      coalesce(
        nullif(trim(coalesce(l.name, '') || ' ' || coalesce(d.draw_number, '')), ''),
        l.name,
        'Draw'
      ) as d_label,
      d.draw_date as d_date,
      coalesce(sum(le.amount) filter (where le.type = 'ISSUE'), 0)::numeric(12,2) as iss_amt,
      coalesce(sum(le.ticket_count) filter (where le.type = 'ISSUE'), 0)::int as iss_cnt,
      coalesce(sum(le.amount) filter (where le.type = 'RETURN'), 0)::numeric(12,2) as ret_amt,
      coalesce(sum(le.ticket_count) filter (where le.type = 'RETURN'), 0)::int as ret_cnt,
      coalesce(sum(le.amount) filter (where le.type = 'PRIZE_PAID_BY_SELLER'), 0)::numeric(12,2) as prz_amt,
      coalesce(sum(le.amount) filter (where le.type = 'ADJUSTMENT'), 0)::numeric(12,2) as adj_amt,
      0::numeric(12,2) as pay_tot,
      0::numeric(12,2) as gen_adj_tot,
      0::numeric(12,2) as grd_tot
    from ledger_entries le
    left join draws d on d.id = le.draw_id
    left join lotteries l on l.id = d.lottery_id
    where le.shop_id = v_shop_id
      and le.seller_id = p_seller_id
      and le.draw_id is not null
      and le.type in ('ISSUE', 'RETURN', 'PRIZE_PAID_BY_SELLER', 'ADJUSTMENT')
    group by le.draw_id, l.name, d.draw_number, d.draw_date
  ),
  summary_row as (
    select
      'SUMMARY'::text as r_kind,
      null::uuid as d_id,
      null::text as d_label,
      null::date as d_date,
      0::numeric(12,2) as iss_amt,
      0::int as iss_cnt,
      0::numeric(12,2) as ret_amt,
      0::int as ret_cnt,
      0::numeric(12,2) as prz_amt,
      0::numeric(12,2) as adj_amt,
      coalesce(sum(le.amount) filter (where le.type = 'PAYMENT'), 0)::numeric(12,2) as pay_tot,
      coalesce(
        sum(le.amount) filter (
          where le.draw_id is null and le.type <> 'PAYMENT'
        ),
        0
      )::numeric(12,2) as gen_adj_tot,
      coalesce(sum(le.amount), 0)::numeric(12,2) as grd_tot
    from ledger_entries le
    where le.shop_id = v_shop_id
      and le.seller_id = p_seller_id
  )
  select * from draw_rows
  union all
  select * from summary_row;
end;
$$;

-- ============================================================================
-- 3. SERVER-SIDE TICKET PREVIEW & BULK ISSUE/RETURN RPCs (Addition #2)
-- ============================================================================

create or replace function preview_tickets(
  p_draw_id uuid,
  p_mode text,
  p_count int default null,
  p_series text default null,
  p_start_number text default null,
  p_end_number text default null,
  p_status text default 'IN_STOCK',
  p_seller_id uuid default null
)
returns table (
  total_count int,
  ranges_summary text
)
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_mode text := upper(trim(coalesce(p_mode, '')));
  v_series text := nullif(upper(trim(coalesce(p_series, ''))), '');
  v_start_str text := trim(coalesce(p_start_number, ''));
  v_end_str text := trim(coalesce(p_end_number, ''));
  v_start_int int;
  v_end_int int;
  v_expected_qty int;
  v_matched_count int := 0;
  v_summary text := null;
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

  if v_mode = 'COUNT' then
    if p_count is null or p_count < 1 or p_count > 5000 then
      return query select 0, null::text;
      return;
    end if;

    with picked as (
      select
        t.series,
        t.number
      from tickets t
      where t.shop_id = v_shop_id
        and t.draw_id = p_draw_id
        and t.status = p_status
        and (v_series is null or t.series = v_series)
        and (p_seller_id is null or t.seller_id = p_seller_id)
      order by t.series asc, t.number asc
      limit p_count
    ),
    islands as (
      select
        series,
        min(number) as min_num,
        max(number) as max_num,
        count(*)::int as cnt
      from (
        select
          series,
          number,
          (number::int - row_number() over (partition by series order by number::int)) as grp
        from picked
      ) g
      group by series, grp
    )
    select
      coalesce((select count(*)::int from picked), 0),
      (
        select string_agg(
          case
            when min_num = max_num then format('%s %s (%s)', series, min_num, cnt)
            else format('%s %s–%s (%s)', series, min_num, max_num, cnt)
          end,
          ', ' order by series, min_num
        )
        from islands
      )
    into v_matched_count, v_summary;

    if v_matched_count < p_count then
      return query select 0, null::text;
      return;
    end if;

    return query select v_matched_count, v_summary;
    return;

  elsif v_mode = 'RANGE' then
    if v_series is null or v_series !~ '^[A-Z]{1,3}$'
       or v_start_str !~ '^\d{1,6}$' or v_end_str !~ '^\d{1,6}$' then
      return query select 0, null::text;
      return;
    end if;

    v_start_int := v_start_str::int;
    v_end_int := v_end_str::int;
    if v_end_int < v_start_int or (v_end_int - v_start_int + 1) > 5000 then
      return query select 0, null::text;
      return;
    end if;

    v_start_str := lpad(v_start_int::text, 6, '0');
    v_end_str := lpad(v_end_int::text, 6, '0');
    v_expected_qty := v_end_int - v_start_int + 1;

    select count(*)::int
    into v_matched_count
    from tickets t
    where t.shop_id = v_shop_id
      and t.draw_id = p_draw_id
      and t.series = v_series
      and t.number between v_start_str and v_end_str
      and t.status = p_status
      and (p_seller_id is null or t.seller_id = p_seller_id);

    if v_matched_count <> v_expected_qty then
      return query select 0, null::text;
      return;
    end if;

    v_summary := case
      when v_start_str = v_end_str then format('%s %s (1)', v_series, v_start_str)
      else format('%s %s–%s (%s)', v_series, v_start_str, v_end_str, v_expected_qty)
    end;

    return query select v_expected_qty, v_summary;
    return;
  else
    raise exception 'INVALID_RANGE' using detail = 'Mode must be COUNT or RANGE.';
  end if;
end;
$$;

-- Issue next N IN_STOCK tickets server-side in one transaction (supports up to 5,000)
create or replace function issue_tickets_by_count(
  p_seller_id uuid,
  p_draw_id uuid,
  p_count int,
  p_series text default null
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
  v_series text := nullif(upper(trim(coalesce(p_series, ''))), '');
  v_locked_ids uuid[];
  v_summary text;
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

  if p_count is null or p_count < 1 or p_count > 5000 then
    raise exception 'INVALID_RANGE'
      using detail = 'Must issue between 1 and 5,000 tickets per call.';
  end if;

  select is_active into v_seller_active
  from sellers
  where id = p_seller_id and shop_id = v_shop_id
  for share;

  if v_seller_active is null then
    raise exception 'NOT_FOUND' using detail = 'Seller does not belong to this shop.';
  end if;

  if not v_seller_active then
    raise exception 'SELLER_INACTIVE'
      using detail = 'Cannot issue tickets to an inactive seller.';
  end if;

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

  with candidate as (
    select id, series, number
    from tickets
    where shop_id = v_shop_id
      and draw_id = p_draw_id
      and status = 'IN_STOCK'
      and (v_series is null or series = v_series)
    order by series asc, number asc
    limit p_count
    for update
  ),
  islands as (
    select
      series,
      min(number) as min_num,
      max(number) as max_num
    from (
      select
        series,
        number,
        (number::int - row_number() over (partition by series order by number::int)) as grp
      from candidate
    ) g
    group by series, grp
  )
  select
    (select array_agg(id) from candidate),
    (
      select string_agg(
        case
          when min_num = max_num then format('%s %s', series, min_num)
          else format('%s %s–%s', series, min_num, max_num)
        end,
        ', ' order by series, min_num
      )
      from islands
    )
  into v_locked_ids, v_summary;

  if coalesce(cardinality(v_locked_ids), 0) <> p_count then
    raise exception 'TICKETS_NOT_AVAILABLE'
      using detail = 'Not enough IN_STOCK tickets available for this draw.';
  end if;

  update tickets
  set status = 'WITH_SELLER',
      seller_id = p_seller_id,
      updated_at = now()
  where id = any(v_locked_ids);

  insert into ledger_entries (
    shop_id,
    seller_id,
    draw_id,
    type,
    amount,
    ticket_count,
    note
  )
  values (
    v_shop_id,
    p_seller_id,
    p_draw_id,
    'ISSUE',
    round(p_count * v_ticket_price, 2),
    p_count,
    format('Issued %s tickets (%s)', p_count, coalesce(v_summary, ''))
  )
  returning id into v_entry_id;

  return v_entry_id;
end;
$$;

-- Issue IN_STOCK tickets by range server-side in one transaction (supports up to 5,000)
create or replace function issue_tickets_by_range(
  p_seller_id uuid,
  p_draw_id uuid,
  p_series text,
  p_start_number text,
  p_end_number text
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
  v_series text := upper(trim(coalesce(p_series, '')));
  v_start_str text := trim(coalesce(p_start_number, ''));
  v_end_str text := trim(coalesce(p_end_number, ''));
  v_start_int int;
  v_end_int int;
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

  select is_active into v_seller_active
  from sellers
  where id = p_seller_id and shop_id = v_shop_id
  for share;

  if v_seller_active is null then
    raise exception 'NOT_FOUND' using detail = 'Seller does not belong to this shop.';
  end if;

  if not v_seller_active then
    raise exception 'SELLER_INACTIVE'
      using detail = 'Cannot issue tickets to an inactive seller.';
  end if;

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
  set status = 'WITH_SELLER',
      seller_id = p_seller_id,
      updated_at = now()
  where shop_id = v_shop_id
    and draw_id = p_draw_id
    and series = v_series
    and number between v_start_str and v_end_str;

  insert into ledger_entries (
    shop_id,
    seller_id,
    draw_id,
    type,
    amount,
    ticket_count,
    note
  )
  values (
    v_shop_id,
    p_seller_id,
    p_draw_id,
    'ISSUE',
    round(v_expected_count * v_ticket_price, 2),
    v_expected_count,
    format('Issued %s tickets (%s %s–%s)', v_expected_count, v_series, v_start_str, v_end_str)
  )
  returning id into v_entry_id;

  return v_entry_id;
end;
$$;

-- Return tickets by range server-side in one transaction (supports up to 5,000 + Rule c)
create or replace function return_tickets_by_range(
  p_seller_id uuid,
  p_draw_id uuid,
  p_series text,
  p_start_number text,
  p_end_number text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_draw_status text;
  v_draw_date date;
  v_draw_time time;
  v_ticket_price numeric(10,2);
  v_series text := upper(trim(coalesce(p_series, '')));
  v_start_str text := trim(coalesce(p_start_number, ''));
  v_end_str text := trim(coalesce(p_end_number, ''));
  v_start_int int;
  v_end_int int;
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

  if v_draw_status = 'CLOSED' then
    raise exception 'DRAW_NOT_OPEN'
      using detail = 'Tickets cannot be returned once the draw is CLOSED.';
  end if;

  with locked as (
    select id, status, seller_id
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
    count(*) filter (where status <> 'WITH_SELLER' or seller_id is distinct from p_seller_id)
  into v_locked_count, v_invalid_count
  from locked;

  if v_locked_count <> v_expected_count or v_invalid_count > 0 then
    raise exception 'TICKETS_NOT_WITH_SELLER'
      using detail = 'One or more tickets in the range are not currently with this seller.';
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
      and series = v_series
      and number between v_start_str and v_end_str;
  else
    update tickets
    set status = 'RETURNED_UNSOLD',
        updated_at = now()
    where shop_id = v_shop_id
      and draw_id = p_draw_id
      and series = v_series
      and number between v_start_str and v_end_str;

    -- Rule (c): If returned after results are entered and a returned ticket is a winner,
    -- update that win to sold_by = 'UNSOLD', seller_id = null in the same transaction.
    if v_draw_status = 'RESULT_ENTERED' then
      update wins
      set sold_by = 'UNSOLD',
          seller_id = null
      where shop_id = v_shop_id
        and draw_id = p_draw_id
        and series = v_series
        and number between v_start_str and v_end_str;
    end if;
  end if;

  insert into ledger_entries (
    shop_id,
    seller_id,
    draw_id,
    type,
    amount,
    ticket_count,
    note
  )
  values (
    v_shop_id,
    p_seller_id,
    p_draw_id,
    'RETURN',
    -round(v_expected_count * v_ticket_price, 2),
    v_expected_count,
    format('Returned %s unsold tickets (%s %s–%s)', v_expected_count, v_series, v_start_str, v_end_str)
  )
  returning id into v_entry_id;

  return v_entry_id;
end;
$$;

-- Update ID-array issue_tickets & return_tickets:
-- 1. Cap ID array at <= 500 (Addition #2: tap-to-select small lists only)
-- 2. In return_tickets, update wins to sold_by = 'UNSOLD', seller_id = null when
--    returned after results entered (Rule c).
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
  if v_expected_count < 1 or v_expected_count > 500 then
    raise exception 'INVALID_RANGE'
      using detail = 'Tap-to-select ID list must contain between 1 and 500 tickets.';
  end if;

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

create or replace function return_tickets(
  p_seller_id uuid,
  p_draw_id uuid,
  p_ticket_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
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
  if v_expected_count < 1 or v_expected_count > 500 then
    raise exception 'INVALID_RANGE'
      using detail = 'Tap-to-select ID list must contain between 1 and 500 tickets.';
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

  if v_draw_status = 'CLOSED' then
    raise exception 'DRAW_NOT_OPEN'
      using detail = 'Tickets cannot be returned once the draw is CLOSED.';
  end if;

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

    -- Rule (c): If returned after results are entered and a returned ticket is a winner,
    -- update that win to sold_by = 'UNSOLD', seller_id = null in the same transaction.
    if v_draw_status = 'RESULT_ENTERED' then
      update wins w
      set sold_by = 'UNSOLD',
          seller_id = null
      from tickets t
      where t.id = any(v_unique_ids)
        and w.shop_id = v_shop_id
        and w.draw_id = p_draw_id
        and w.series = t.series
        and w.number = t.number;
    end if;
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
-- 4. PHASE 4 RPCs: check_draw, save_draw_results_and_check,
--    update_win_claim_status, close_draw (Rules a–g & Additions #1, #3, #4)
-- ============================================================================

create or replace function check_draw(
  p_draw_id uuid,
  p_force boolean default false
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_draw_status text;
  v_draw_date date;
  v_draw_time time;
  v_affected_detail text;
  v_win_count int;
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

  select status, draw_date, draw_time
  into v_draw_status, v_draw_date, v_draw_time
  from draws
  where id = p_draw_id and shop_id = v_shop_id
  for update;

  if v_draw_status is null then
    raise exception 'NOT_FOUND' using detail = 'Draw does not belong to this shop.';
  end if;

  -- Rule (d): Cannot check/save results for CLOSED draws or before draw date+time (IST)
  if v_draw_status = 'CLOSED' then
    raise exception 'DRAW_CLOSED'
      using detail = 'Results cannot be modified once the draw is CLOSED.';
  end if;

  if ((v_draw_date + v_draw_time) at time zone 'Asia/Kolkata') > now() then
    raise exception 'DRAW_BEFORE_TIME'
      using detail = 'Results can only be entered after the official draw time (IST).';
  end if;

  -- Rule (e): Ensure CONSOLATION rows in draw_results are synced from 1st prize (tier_order = 1, FULL)
  delete from draw_results dr
  using draw_prize_tiers dpt
  where dr.draw_id = p_draw_id
    and dr.tier_id = dpt.id
    and dpt.match_type = 'CONSOLATION';

  insert into draw_results (draw_id, tier_id, series, number)
  select
    p_draw_id,
    consol_tier.id,
    first_res.series,
    first_res.number
  from draw_prize_tiers consol_tier
  join draw_prize_tiers first_tier
    on first_tier.draw_id = p_draw_id
   and first_tier.match_type = 'FULL'
   and first_tier.tier_order = 1
  join draw_results first_res
    on first_res.draw_id = p_draw_id
   and first_res.tier_id = first_tier.id
  where consol_tier.draw_id = p_draw_id
    and consol_tier.match_type = 'CONSOLATION';

  -- Build candidate wins in a temporary table for fast comparison & upsert
  create temporary table if not exists _tmp_computed_wins (
    ticket_id uuid,
    series text,
    number char(6),
    seller_id uuid,
    sold_by text,
    tier_id uuid,
    amount numeric(12,2)
  ) on commit drop;

  truncate table _tmp_computed_wins;

  insert into _tmp_computed_wins (
    ticket_id,
    series,
    number,
    seller_id,
    sold_by,
    tier_id,
    amount
  )
  with raw_matches as (
    -- 1. FULL match: exact series + 6-digit number
    select
      t.id as ticket_id,
      t.series,
      t.number,
      t.status,
      t.seller_id,
      dpt.id as tier_id,
      dpt.amount,
      dpt.tier_order
    from draw_results dr
    join draw_prize_tiers dpt on dpt.id = dr.tier_id and dpt.draw_id = p_draw_id
    join tickets t
      on t.draw_id = p_draw_id
     and t.shop_id = v_shop_id
     and t.number = dr.number::char(6)
     and t.series = dr.series
    where dr.draw_id = p_draw_id
      and dpt.match_type = 'FULL'

    union all

    -- 2. CONSOLATION match: same 6-digit number, different series
    select
      t.id as ticket_id,
      t.series,
      t.number,
      t.status,
      t.seller_id,
      dpt.id as tier_id,
      dpt.amount,
      dpt.tier_order
    from draw_results dr
    join draw_prize_tiers dpt on dpt.id = dr.tier_id and dpt.draw_id = p_draw_id
    join tickets t
      on t.draw_id = p_draw_id
     and t.shop_id = v_shop_id
     and t.number = dr.number::char(6)
     and t.series <> dr.series
    where dr.draw_id = p_draw_id
      and dpt.match_type = 'CONSOLATION'

    union all

    -- 3. LAST_4 match
    select
      t.id as ticket_id,
      t.series,
      t.number,
      t.status,
      t.seller_id,
      dpt.id as tier_id,
      dpt.amount,
      dpt.tier_order
    from draw_results dr
    join draw_prize_tiers dpt on dpt.id = dr.tier_id and dpt.draw_id = p_draw_id
    join tickets t
      on t.draw_id = p_draw_id
     and t.shop_id = v_shop_id
     and right(t.number, 4) = dr.number
    where dr.draw_id = p_draw_id
      and dpt.match_type = 'LAST_4'

    union all

    -- 4. LAST_3 match
    select
      t.id as ticket_id,
      t.series,
      t.number,
      t.status,
      t.seller_id,
      dpt.id as tier_id,
      dpt.amount,
      dpt.tier_order
    from draw_results dr
    join draw_prize_tiers dpt on dpt.id = dr.tier_id and dpt.draw_id = p_draw_id
    join tickets t
      on t.draw_id = p_draw_id
     and t.shop_id = v_shop_id
     and right(t.number, 3) = dr.number
    where dr.draw_id = p_draw_id
      and dpt.match_type = 'LAST_3'
  ),
  best_per_ticket as (
    select distinct on (rm.ticket_id)
      rm.ticket_id,
      rm.series,
      rm.number,
      case
        when rm.status in ('WITH_SELLER', 'SOLD_BY_SELLER') then rm.seller_id
        else null
      end as mapped_seller_id,
      case
        when rm.status = 'SOLD_COUNTER' then 'COUNTER'
        when rm.status in ('WITH_SELLER', 'SOLD_BY_SELLER') then 'SELLER'
        else 'UNSOLD'
      end as mapped_sold_by,
      rm.tier_id,
      rm.amount
    from raw_matches rm
    order by rm.ticket_id, rm.amount desc, rm.tier_order asc
  )
  select
    ticket_id,
    series,
    number,
    mapped_seller_id,
    mapped_sold_by,
    tier_id,
    amount
  from best_per_ticket;

  -- Addition #1: Protect wins where claim_status != 'UNCLAIMED'
  if not coalesce(p_force, false) then
    select string_agg(
      format('%s %s', w.series, trim(w.number::text)),
      ', ' order by w.series, w.number
    )
    into v_affected_detail
    from wins w
    left join _tmp_computed_wins cw
      on cw.series = w.series
     and cw.number = w.number
    where w.shop_id = v_shop_id
      and w.draw_id = p_draw_id
      and w.claim_status <> 'UNCLAIMED'
      and (cw.ticket_id is null or cw.amount <> w.amount);

    if v_affected_detail is not null then
      raise exception 'CLAIMED_WIN_AFFECTED'
        using detail = v_affected_detail;
    end if;
  end if;

  -- Delete wins that no longer match
  delete from wins w
  where w.shop_id = v_shop_id
    and w.draw_id = p_draw_id
    and not exists (
      select 1
      from _tmp_computed_wins cw
      where cw.series = w.series
        and cw.number = w.number
    );

  -- Upsert current wins, preserving claim_status for tickets that still win
  insert into wins (
    shop_id,
    draw_id,
    ticket_id,
    series,
    number,
    seller_id,
    sold_by,
    tier_id,
    amount
  )
  select
    v_shop_id,
    p_draw_id,
    cw.ticket_id,
    cw.series,
    cw.number,
    cw.seller_id,
    cw.sold_by,
    cw.tier_id,
    cw.amount
  from _tmp_computed_wins cw
  on conflict (draw_id, series, number) do update
  set ticket_id = excluded.ticket_id,
      seller_id = excluded.seller_id,
      sold_by = excluded.sold_by,
      tier_id = excluded.tier_id,
      amount = excluded.amount;

  update draws
  set status = 'RESULT_ENTERED'
  where id = p_draw_id and shop_id = v_shop_id;

  select count(*)::int into v_win_count from _tmp_computed_wins;
  return v_win_count;
end;
$$;

-- Validate and save draw_results, then run check_draw in a single atomic transaction
create or replace function save_draw_results_and_check(
  p_draw_id uuid,
  p_entries jsonb,
  p_force boolean default false
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_draw_status text;
  v_draw_date date;
  v_draw_time time;
  v_item jsonb;
  v_tier_id uuid;
  v_match_type text;
  v_series text;
  v_number text;
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

  select status, draw_date, draw_time
  into v_draw_status, v_draw_date, v_draw_time
  from draws
  where id = p_draw_id and shop_id = v_shop_id
  for update;

  if v_draw_status is null then
    raise exception 'NOT_FOUND' using detail = 'Draw does not belong to this shop.';
  end if;

  -- Rule (d)
  if v_draw_status = 'CLOSED' then
    raise exception 'DRAW_CLOSED'
      using detail = 'Results cannot be modified once the draw is CLOSED.';
  end if;

  if ((v_draw_date + v_draw_time) at time zone 'Asia/Kolkata') > now() then
    raise exception 'DRAW_BEFORE_TIME'
      using detail = 'Results can only be entered after the official draw time (IST).';
  end if;

  if p_entries is null or jsonb_typeof(p_entries) <> 'array' then
    raise exception 'INVALID_RESULT_ENTRY'
      using detail = 'Result entries must be a JSON array.';
  end if;

  create temporary table if not exists _tmp_validated_results (
    tier_id uuid,
    series text,
    number text
  ) on commit drop;

  truncate table _tmp_validated_results;

  for v_item in select * from jsonb_array_elements(p_entries)
  loop
    v_tier_id := (v_item->>'tier_id')::uuid;
    v_series := nullif(upper(trim(coalesce(v_item->>'series', ''))), '');
    v_number := trim(coalesce(v_item->>'number', ''));

    select match_type into v_match_type
    from draw_prize_tiers
    where id = v_tier_id and draw_id = p_draw_id;

    if v_match_type is null then
      raise exception 'INVALID_RESULT_ENTRY'
        using detail = 'Tier does not belong to this draw.';
    end if;

    -- Skip manual CONSOLATION entries; check_draw auto-generates them from 1st prize (Rule e)
    if v_match_type = 'CONSOLATION' then
      continue;
    elsif v_match_type = 'FULL' then
      if v_series is null or v_series !~ '^[A-Z]{1,3}$' or v_number !~ '^\d{6}$' then
        raise exception 'INVALID_RESULT_ENTRY'
          using detail = 'FULL prize entry requires a 1–3 letter series and a 6-digit number.';
      end if;
    elsif v_match_type = 'LAST_4' then
      v_series := null;
      if v_number !~ '^\d{4}$' then
        raise exception 'INVALID_RESULT_ENTRY'
          using detail = 'LAST_4 prize entry requires an exact 4-digit number.';
      end if;
    elsif v_match_type = 'LAST_3' then
      v_series := null;
      if v_number !~ '^\d{3}$' then
        raise exception 'INVALID_RESULT_ENTRY'
          using detail = 'LAST_3 prize entry requires an exact 3-digit number.';
      end if;
    end if;

    if exists (
      select 1 from _tmp_validated_results
      where tier_id = v_tier_id
        and coalesce(series, '') = coalesce(v_series, '')
        and number = v_number
    ) then
      raise exception 'DUPLICATE_RESULT_ENTRY'
        using detail = format('%s %s', coalesce(v_series, ''), v_number);
    end if;

    insert into _tmp_validated_results (tier_id, series, number)
    values (v_tier_id, v_series, v_number);
  end loop;

  delete from draw_results where draw_id = p_draw_id;

  insert into draw_results (draw_id, tier_id, series, number)
  select p_draw_id, tier_id, series, number
  from _tmp_validated_results;

  return check_draw(p_draw_id, p_force);
end;
$$;

-- Rule 3 & 4: Update claim status via RPC only
create or replace function update_win_claim_status(
  p_win_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_status text := upper(trim(coalesce(p_status, '')));
  v_updated int;
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

  if v_status not in ('UNCLAIMED', 'PAID_TO_CUSTOMER', 'CLAIMED_FROM_OFFICE', 'UNSOLD_WIN') then
    raise exception 'INVALID_CLAIM_STATUS'
      using detail = 'Invalid claim_status value.';
  end if;

  update wins
  set claim_status = v_status
  where id = p_win_id
    and shop_id = v_shop_id;

  get diagnostics v_updated = row_count;
  if v_updated = 0 then
    raise exception 'NOT_FOUND' using detail = 'Winning ticket not found in this shop.';
  end if;
end;
$$;

-- Rule (g): close_draw converts remaining WITH_SELLER -> SOLD_BY_SELLER and writes draw_summaries
create or replace function close_draw(
  p_draw_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_draw_status text;
  v_ticket_price numeric(10,2);
  v_total_tickets int;
  v_sold_counter int;
  v_sold_by_sellers int;
  v_returned_unsold int;
  v_total_cost numeric(12,2);
  v_total_sales numeric(12,2);
  v_total_prizes numeric(12,2);
  v_per_seller jsonb;
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

  select status, ticket_price
  into v_draw_status, v_ticket_price
  from draws
  where id = p_draw_id and shop_id = v_shop_id
  for update;

  if v_draw_status is null then
    raise exception 'NOT_FOUND' using detail = 'Draw does not belong to this shop.';
  end if;

  if v_draw_status <> 'RESULT_ENTERED' then
    raise exception 'DRAW_NOT_OPEN'
      using detail = 'A draw can only be closed after results are entered.';
  end if;

  -- 1. Convert all remaining WITH_SELLER tickets to SOLD_BY_SELLER
  update tickets
  set status = 'SOLD_BY_SELLER',
      updated_at = now()
  where shop_id = v_shop_id
    and draw_id = p_draw_id
    and status = 'WITH_SELLER';

  -- 2. Compute permanent draw_summaries metrics
  select
    count(*)::int,
    count(*) filter (where status = 'SOLD_COUNTER')::int,
    count(*) filter (where status = 'SOLD_BY_SELLER')::int,
    count(*) filter (where status = 'RETURNED_UNSOLD')::int
  into
    v_total_tickets,
    v_sold_counter,
    v_sold_by_sellers,
    v_returned_unsold
  from tickets
  where shop_id = v_shop_id
    and draw_id = p_draw_id;

  select coalesce(sum(quantity * coalesce(cost_per_ticket, 0)), 0)::numeric(12,2)
  into v_total_cost
  from stock_batches
  where shop_id = v_shop_id
    and draw_id = p_draw_id;

  v_total_sales := round((v_sold_counter + v_sold_by_sellers) * v_ticket_price, 2);

  select coalesce(sum(amount), 0)::numeric(12,2)
  into v_total_prizes
  from wins
  where shop_id = v_shop_id
    and draw_id = p_draw_id
    and sold_by in ('COUNTER', 'SELLER');

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'seller_id', seller_id,
        'issued', issued_cnt,
        'returned', returned_cnt,
        'sold', greatest(issued_cnt - returned_cnt, 0),
        'amount', net_amount
      )
    ),
    '[]'::jsonb
  )
  into v_per_seller
  from (
    select
      le.seller_id,
      coalesce(sum(le.ticket_count) filter (where le.type = 'ISSUE'), 0)::int as issued_cnt,
      coalesce(sum(le.ticket_count) filter (where le.type = 'RETURN'), 0)::int as returned_cnt,
      coalesce(sum(le.amount) filter (where le.type in ('ISSUE', 'RETURN')), 0)::numeric(12,2) as net_amount
    from ledger_entries le
    where le.shop_id = v_shop_id
      and le.draw_id = p_draw_id
    group by le.seller_id
  ) ps;

  insert into draw_summaries (
    draw_id,
    shop_id,
    total_tickets,
    sold_counter,
    sold_by_sellers,
    returned_unsold,
    total_cost,
    total_sales,
    total_prizes,
    per_seller
  )
  values (
    p_draw_id,
    v_shop_id,
    v_total_tickets,
    v_sold_counter,
    v_sold_by_sellers,
    v_returned_unsold,
    v_total_cost,
    v_total_sales,
    v_total_prizes,
    v_per_seller
  )
  on conflict (draw_id) do update
  set total_tickets = excluded.total_tickets,
      sold_counter = excluded.sold_counter,
      sold_by_sellers = excluded.sold_by_sellers,
      returned_unsold = excluded.returned_unsold,
      total_cost = excluded.total_cost,
      total_sales = excluded.total_sales,
      total_prizes = excluded.total_prizes,
      per_seller = excluded.per_seller;

  update draws
  set status = 'CLOSED',
      closed_at = now()
  where id = p_draw_id and shop_id = v_shop_id;
end;
$$;
