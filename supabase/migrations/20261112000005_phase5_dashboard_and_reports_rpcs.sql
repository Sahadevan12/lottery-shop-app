-- ============================================================================
-- LuckyLedger — Phase 5 Migration
-- Server-Side Home Dashboard (dashboard_today) & Reports P&L (get_reports_summary)
-- ============================================================================

-- ============================================================================
-- 1. dashboard_today() — Single server-side RPC for Home screen (Rule a)
-- ============================================================================

create or replace function dashboard_today()
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_today date := (now() at time zone 'Asia/Kolkata')::date;
  v_draws_count int := 0;
  v_in_stock int := 0;
  v_with_seller int := 0;
  v_sold_counter int := 0;
  v_sold_seller int := 0;
  v_returned int := 0;
  v_total_tickets int := 0;
  v_today_wins_count int := 0;
  v_today_prizes_total numeric(14,2) := 0;
  v_unclaimed_wins_count int := 0;
  v_total_due_from_sellers numeric(14,2) := 0;
  v_to_recover_from_office numeric(14,2) := 0;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required.';
  end if;

  select s.id into v_shop_id
  from shops s
  where s.owner_id = v_user_id
  limit 1;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for user.';
  end if;

  select count(*)::int
  into v_draws_count
  from draws d
  where d.shop_id = v_shop_id
    and d.draw_date = v_today;

  select
    coalesce(count(*) filter (where t.status = 'IN_STOCK'), 0)::int,
    coalesce(count(*) filter (where t.status = 'WITH_SELLER'), 0)::int,
    coalesce(count(*) filter (where t.status = 'SOLD_COUNTER'), 0)::int,
    coalesce(count(*) filter (where t.status = 'SOLD_BY_SELLER'), 0)::int,
    coalesce(count(*) filter (where t.status = 'RETURNED_UNSOLD'), 0)::int,
    coalesce(count(*), 0)::int
  into
    v_in_stock,
    v_with_seller,
    v_sold_counter,
    v_sold_seller,
    v_returned,
    v_total_tickets
  from tickets t
  join draws d on d.id = t.draw_id
  where d.shop_id = v_shop_id
    and d.draw_date = v_today;

  select
    coalesce(count(*), 0)::int,
    coalesce(sum(w.prize_amount), 0)::numeric(14,2),
    coalesce(count(*) filter (where w.claim_status = 'UNCLAIMED'), 0)::int
  into
    v_today_wins_count,
    v_today_prizes_total,
    v_unclaimed_wins_count
  from wins w
  join draws d on d.id = w.draw_id
  where d.shop_id = v_shop_id
    and d.draw_date = v_today;

  select coalesce(sum(greatest(sb.bal, 0)), 0)::numeric(14,2)
  into v_total_due_from_sellers
  from (
    select l.seller_id, coalesce(sum(l.amount), 0) as bal
    from ledger_entries l
    where l.shop_id = v_shop_id
    group by l.seller_id
  ) sb;

  select coalesce(sum(w.prize_amount), 0)::numeric(14,2)
  into v_to_recover_from_office
  from wins w
  where w.shop_id = v_shop_id
    and w.claim_status = 'PAID_TO_CUSTOMER';

  return jsonb_build_object(
    'today_date', v_today,
    'draws_count', v_draws_count,
    'in_stock_count', v_in_stock,
    'with_seller_count', v_with_seller,
    'sold_counter_count', v_sold_counter,
    'sold_seller_count', v_sold_seller,
    'returned_count', v_returned,
    'total_tickets', v_total_tickets,
    'today_wins_count', v_today_wins_count,
    'today_prizes_total', v_today_prizes_total,
    'unclaimed_wins_count', v_unclaimed_wins_count,
    'total_due_from_sellers', v_total_due_from_sellers,
    'to_recover_from_office', v_to_recover_from_office
  );
end;
$$;

grant execute on function dashboard_today() to authenticated;

-- ============================================================================
-- 2. get_reports_summary(p_from_date, p_to_date) — Draw-wise P&L (Rules b, c)
-- ============================================================================
-- P&L model:
-- - Sales = sold tickets * price (counter + sellers; seller sales = issued - returned)
-- - Stock cost = all tickets bought * cost_per_ticket
-- - Gross margin = Sales - Stock cost
-- - Unsold prize gain = prizes on UNSOLD tickets
-- - Net profit = Gross margin + Unsold prize gain
-- - Separate: To recover from lottery office (claim_status = 'PAID_TO_CUSTOMER')
-- - Separate: To collect from sellers (current positive seller dues)
-- - CLOSED draws read from draw_summaries only (no tickets table scan).

create or replace function get_reports_summary(
  p_from_date date,
  p_to_date date
)
returns jsonb
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_draws jsonb := '[]'::jsonb;
  v_to_collect_from_sellers numeric(14,2) := 0;
  v_total_to_recover_from_office numeric(14,2) := 0;
  v_total_sales numeric(14,2) := 0;
  v_total_stock_cost numeric(14,2) := 0;
  v_total_gross_margin numeric(14,2) := 0;
  v_total_unsold_prize_gain numeric(14,2) := 0;
  v_total_net_profit numeric(14,2) := 0;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required.';
  end if;

  select s.id into v_shop_id
  from shops s
  where s.owner_id = v_user_id
  limit 1;

  if v_shop_id is null then
    raise exception 'NOT_FOUND' using detail = 'Shop not found for user.';
  end if;

  if p_from_date is null or p_to_date is null or p_from_date > p_to_date then
    raise exception 'INVALID_RANGE'
      using detail = 'Start date must be on or before end date.';
  end if;

  if (p_to_date - p_from_date) > 366 then
    raise exception 'RANGE_TOO_LARGE'
      using detail = 'Date range cannot exceed 366 days.';
  end if;

  select coalesce(sum(greatest(sb.bal, 0)), 0)::numeric(14,2)
  into v_to_collect_from_sellers
  from (
    select l.seller_id, coalesce(sum(l.amount), 0) as bal
    from ledger_entries l
    where l.shop_id = v_shop_id
    group by l.seller_id
  ) sb;

  select coalesce(sum(w.prize_amount), 0)::numeric(14,2)
  into v_total_to_recover_from_office
  from wins w
  where w.shop_id = v_shop_id
    and w.claim_status = 'PAID_TO_CUSTOMER';

  with batch_costs as (
    select
      b.draw_id,
      coalesce(sum(b.quantity * coalesce(b.cost_per_ticket, 0)), 0)::numeric(14,2) as stock_cost
    from stock_batches b
    where b.shop_id = v_shop_id
    group by b.draw_id
  ),
  win_agg as (
    select
      w.draw_id,
      coalesce(sum(w.prize_amount) filter (where w.sold_by = 'UNSOLD'), 0)::numeric(14,2) as unsold_prize_gain,
      coalesce(sum(w.prize_amount) filter (where w.claim_status = 'PAID_TO_CUSTOMER'), 0)::numeric(14,2) as to_recover_from_office
    from wins w
    where w.shop_id = v_shop_id
    group by w.draw_id
  ),
  open_ticket_agg as (
    select
      t.draw_id,
      count(*)::int as tickets_bought,
      count(*) filter (where t.status = 'SOLD_COUNTER')::int as tickets_sold_counter,
      count(*) filter (where t.status in ('WITH_SELLER', 'SOLD_BY_SELLER'))::int as tickets_sold_seller,
      count(*) filter (where t.status in ('IN_STOCK', 'RETURNED_UNSOLD'))::int as tickets_unsold
    from tickets t
    join draws d on d.id = t.draw_id
    where d.shop_id = v_shop_id
      and d.draw_date between p_from_date and p_to_date
      and d.status <> 'CLOSED'
    group by t.draw_id
  ),
  draw_rows as (
    select
      d.id as draw_id,
      l.name as lottery_name,
      d.draw_number,
      d.draw_date,
      d.status,
      d.ticket_price,
      case
        when d.status = 'CLOSED' then coalesce(ds.tickets_bought, 0)
        else coalesce(ota.tickets_bought, 0)
      end as tickets_bought,
      case
        when d.status = 'CLOSED' then coalesce(ds.tickets_sold_counter, 0)
        else coalesce(ota.tickets_sold_counter, 0)
      end as tickets_sold_counter,
      case
        when d.status = 'CLOSED' then coalesce(ds.tickets_sold_seller, 0)
        else coalesce(ota.tickets_sold_seller, 0)
      end as tickets_sold_seller,
      case
        when d.status = 'CLOSED' then coalesce(ds.tickets_unsold, 0)
        else coalesce(ota.tickets_unsold, 0)
      end as tickets_unsold,
      case
        when d.status = 'CLOSED' then coalesce(ds.gross_revenue, 0)::numeric(14,2)
        else (
          (coalesce(ota.tickets_sold_counter, 0) + coalesce(ota.tickets_sold_seller, 0))
          * d.ticket_price
        )::numeric(14,2)
      end as sales,
      coalesce(bc.stock_cost, 0)::numeric(14,2) as stock_cost,
      coalesce(wa.unsold_prize_gain, 0)::numeric(14,2) as unsold_prize_gain,
      coalesce(wa.to_recover_from_office, 0)::numeric(14,2) as to_recover_from_office
    from draws d
    join lotteries l on l.id = d.lottery_id
    left join draw_summaries ds on ds.draw_id = d.id
    left join batch_costs bc on bc.draw_id = d.id
    left join win_agg wa on wa.draw_id = d.id
    left join open_ticket_agg ota on ota.draw_id = d.id
    where d.shop_id = v_shop_id
      and d.draw_date between p_from_date and p_to_date
    order by d.draw_date desc, d.created_at desc
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'draw_id', dr.draw_id,
          'lottery_name', dr.lottery_name,
          'draw_number', dr.draw_number,
          'draw_date', dr.draw_date,
          'status', dr.status,
          'ticket_price', dr.ticket_price,
          'tickets_bought', dr.tickets_bought,
          'tickets_sold_counter', dr.tickets_sold_counter,
          'tickets_sold_seller', dr.tickets_sold_seller,
          'tickets_unsold', dr.tickets_unsold,
          'sales', dr.sales,
          'stock_cost', dr.stock_cost,
          'gross_margin', (dr.sales - dr.stock_cost),
          'unsold_prize_gain', dr.unsold_prize_gain,
          'net_profit', ((dr.sales - dr.stock_cost) + dr.unsold_prize_gain),
          'to_recover_from_office', dr.to_recover_from_office
        )
      ),
      '[]'::jsonb
    ),
    coalesce(sum(dr.sales), 0)::numeric(14,2),
    coalesce(sum(dr.stock_cost), 0)::numeric(14,2),
    coalesce(sum(dr.sales - dr.stock_cost), 0)::numeric(14,2),
    coalesce(sum(dr.unsold_prize_gain), 0)::numeric(14,2),
    coalesce(sum((dr.sales - dr.stock_cost) + dr.unsold_prize_gain), 0)::numeric(14,2)
  into
    v_draws,
    v_total_sales,
    v_total_stock_cost,
    v_total_gross_margin,
    v_total_unsold_prize_gain,
    v_total_net_profit
  from draw_rows dr;

  return jsonb_build_object(
    'from_date', p_from_date,
    'to_date', p_to_date,
    'total_sales', v_total_sales,
    'total_stock_cost', v_total_stock_cost,
    'total_gross_margin', v_total_gross_margin,
    'total_unsold_prize_gain', v_total_unsold_prize_gain,
    'total_net_profit', v_total_net_profit,
    'total_to_recover_from_office', v_total_to_recover_from_office,
    'to_collect_from_sellers', v_to_collect_from_sellers,
    'draws', v_draws
  );
end;
$$;

grant execute on function get_reports_summary(date, date) to authenticated;
