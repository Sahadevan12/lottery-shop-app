-- ============================================================================
-- LuckyLedger — Phase 5 pgTAP Test Suite
-- Tests:
--   1. dashboard_today() server-side aggregates (including 3,000-ticket batch)
--   2. get_reports_summary() > 366 days raises RANGE_TOO_LARGE
--   3. get_reports_summary() P&L model on open draw (customer prizes NOT expense,
--      unsold prize = owner's gain, PAID_TO_CUSTOMER = to_recover_from_office,
--      seller dues = to_collect_from_sellers)
--   4. get_reports_summary() on CLOSED draw reads draw_summaries after tickets
--      are deleted (30-day retention cleanup simulation)
-- ============================================================================

begin;

select plan(13);

insert into auth.users (id, email, raw_user_meta_data, created_at, updated_at)
values
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', '9876500005@luckyledger.app', '{}', now(), now())
on conflict (id) do nothing;

set local role authenticated;
set local "request.jwt.claim.sub" = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
set local "request.jwt.claims" = '{"sub": "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee", "role": "authenticated"}';

do $$
declare
  v_shop_id uuid;
  v_lottery_id uuid;
  v_template_id uuid;
  v_seller_id uuid;
  v_draw_today uuid;
  v_draw_past uuid;
  v_tier_1 uuid;
  v_tier_8 uuid;
  v_win_counter_id uuid;
  v_today date := (now() at time zone 'Asia/Kolkata')::date;
begin
  v_shop_id := create_shop_with_defaults('Phase5 Shop', 'Saha', 'Kochi', 'EKM-505', 'en', '9876500005');
  select id into v_lottery_id from lotteries where shop_id = v_shop_id and code = 'KR' limit 1;
  select id into v_template_id from prize_templates where shop_id = v_shop_id limit 1;

  insert into prize_template_tiers (template_id, tier_order, label, amount, match_type)
  values (v_template_id, 10, '9th Prize', 100.00, 'LAST_3');

  insert into sellers (shop_id, name, phone, area)
  values (v_shop_id, 'Mani', '9876522222', 'Market')
  returning id into v_seller_id;

  -- 1. Today's IST draw with 3,000 tickets:
  --    2,000 IN_STOCK, 600 SOLD_COUNTER, 400 WITH_SELLER
  v_draw_today := create_draw(v_lottery_id, v_today, 'KR-501', 40.00, v_template_id);
  perform create_stock_batch(v_draw_today, 'KR', '100001', '103000', 35.00);
  perform mark_counter_sold(v_draw_today, 'KR', '100001', '100600');
  perform issue_tickets_by_count(v_seller_id, v_draw_today, 400, 'KR');

  -- 2. Past draw (v_today - 2) with 10 tickets @ ₹40 (cost ₹35 = ₹350 total cost):
  --    4 SOLD_COUNTER (₹160), 4 WITH_SELLER (₹160) -> Sales = ₹320, Gross margin = -₹30
  --    2 IN_STOCK (UNSOLD): one wins 9th Prize (₹100 -> unsold_prize_gain = ₹100)
  --    1 SOLD_COUNTER wins 1st Prize (₹80,00,000) & marked PAID_TO_CUSTOMER
  --    -> Net profit = -30 + 100 = +70 (1st prize is NOT a shop expense!)
  --    -> to_recover_from_office = 80,00,000
  v_draw_past := create_draw(v_lottery_id, v_today - 2, 'KR-500', 40.00, v_template_id);
  perform create_stock_batch(v_draw_past, 'KR', '200001', '200010', 35.00);
  perform mark_counter_sold(v_draw_past, 'KR', '200001', '200004');
  perform issue_tickets_by_range(v_seller_id, v_draw_past, 'KR', '200005', '200008');

  select id into v_tier_1 from draw_prize_tiers where draw_id = v_draw_past and tier_order = 1;
  select id into v_tier_8 from draw_prize_tiers where draw_id = v_draw_past and match_type = 'LAST_3' limit 1;

  perform save_draw_results_and_check(
    v_draw_past,
    jsonb_build_array(
      jsonb_build_object('tier_id', v_tier_1, 'series', 'KR', 'number', '200001'),
      jsonb_build_object('tier_id', v_tier_8, 'series', null, 'number', '009')
    )
  );

  select w.id into v_win_counter_id
  from wins w
  join tickets t on t.id = w.ticket_id
  where w.draw_id = v_draw_past and t.number = '200001';

  perform update_win_claim_status(v_win_counter_id, 'PAID_TO_CUSTOMER');
end $$;

-- Tests 1-5: dashboard_today()
select is((dashboard_today()->>'draws_count')::int, 1, 'dashboard_today: 1 draw today');
select is((dashboard_today()->>'total_tickets')::int, 3000, 'dashboard_today: 3000 total tickets');
select is((dashboard_today()->>'in_stock_count')::int, 2000, 'dashboard_today: 2000 in stock');
select is((dashboard_today()->>'sold_counter_count')::int, 600, 'dashboard_today: 600 counter sold');
select is((dashboard_today()->>'with_seller_count')::int, 400, 'dashboard_today: 400 with seller');

-- Test 6: get_reports_summary max 366 days -> RANGE_TOO_LARGE
select throws_ok(
  format(
    'select get_reports_summary(%L::date, %L::date)',
    ((now() at time zone 'Asia/Kolkata')::date - 367),
    (now() at time zone 'Asia/Kolkata')::date
  ),
  'P0001',
  'RANGE_TOO_LARGE',
  'get_reports_summary rejects > 366 day range with RANGE_TOO_LARGE'
);

-- Tests 7-11: Open draw P&L model
select is(
  (get_reports_summary((now() at time zone 'Asia/Kolkata')::date - 3, (now() at time zone 'Asia/Kolkata')::date - 1)->>'total_sales')::numeric,
  320.00,
  'get_reports_summary: sales = 8 sold * 40 = 320.00'
);
select is(
  (get_reports_summary((now() at time zone 'Asia/Kolkata')::date - 3, (now() at time zone 'Asia/Kolkata')::date - 1)->>'total_stock_cost')::numeric,
  350.00,
  'get_reports_summary: stock_cost = 10 * 35 = 350.00'
);
select is(
  (get_reports_summary((now() at time zone 'Asia/Kolkata')::date - 3, (now() at time zone 'Asia/Kolkata')::date - 1)->>'total_unsold_prize_gain')::numeric,
  100.00,
  'get_reports_summary: unsold_prize_gain = 100.00'
);
select is(
  (get_reports_summary((now() at time zone 'Asia/Kolkata')::date - 3, (now() at time zone 'Asia/Kolkata')::date - 1)->>'total_net_profit')::numeric,
  70.00,
  'get_reports_summary: net_profit = (320 - 350) + 100 = 70.00 (customer prize not subtracted)'
);
select is(
  (get_reports_summary((now() at time zone 'Asia/Kolkata')::date - 3, (now() at time zone 'Asia/Kolkata')::date - 1)->>'total_to_recover_from_office')::numeric,
  7500000.00,
  'get_reports_summary: to_recover_from_office = 7500000.00 (PAID_TO_CUSTOMER)'
);

-- Close past draw, delete its tickets (simulate 30-day cleanup), verify draw_summaries is used
do $$
declare
  v_draw_past uuid;
begin
  select id into v_draw_past from draws where draw_number = 'KR-500' limit 1;
  perform close_draw(v_draw_past);
  delete from tickets where draw_id = v_draw_past;
end $$;

select is(
  (get_reports_summary((now() at time zone 'Asia/Kolkata')::date - 3, (now() at time zone 'Asia/Kolkata')::date - 1)->>'total_sales')::numeric,
  320.00,
  'CLOSED draw reads sales (320.00) from draw_summaries after tickets deleted'
);
select is(
  (get_reports_summary((now() at time zone 'Asia/Kolkata')::date - 3, (now() at time zone 'Asia/Kolkata')::date - 1)->>'total_net_profit')::numeric,
  70.00,
  'CLOSED draw retains exact net_profit (70.00) after tickets deleted'
);

select * from finish();

rollback;
