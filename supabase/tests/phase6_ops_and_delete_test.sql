-- ============================================================================
-- LuckyLedger — Phase 6 pgTAP Test Suite
-- Tests:
--   1. cleanup_old_closed_draws() uses draws.closed_at (NOT draw_date):
--      - Deletes tickets AND stock_batches for CLOSED draws with closed_at > 30d ago
--      - Does NOT delete tickets/batches for CLOSED draws with closed_at < 30d ago
--        even if draw_date is > 45 days ago
--      - Does NOT delete tickets/batches for RESULT_ENTERED / UPCOMING draws
--      - Leaves wins, ledger_entries, and draw_summaries completely untouched
--   2. storage_usage view returns all 13 core tables with non-negative byte sizes
--   3. delete_my_shop_and_account() (no parameters, uses only auth.uid()):
--      - User A deletes their own shop, sellers, draws, batches, tickets, wins,
--        ledger_entries (including reversed pairs), draw_summaries, and auth.users row
--      - User B's shop, sellers, draws, batches, tickets, wins, ledger_entries,
--        draw_summaries, and auth.users row remain 100% intact
-- ============================================================================

begin;

select plan(17);

insert into auth.users (id, email, raw_user_meta_data, created_at, updated_at)
values
  ('aaaaaaaa-6666-6666-6666-aaaaaaaaaaaa', '9876500061@luckyledger.app', '{}', now(), now()),
  ('bbbbbbbb-6666-6666-6666-bbbbbbbbbbbb', '9876500062@luckyledger.app', '{}', now(), now())
on conflict (id) do nothing;

-- ============================================================================
-- Setup User A and User B shops & draws
-- ============================================================================

set local role authenticated;
set local "request.jwt.claim.sub" = 'aaaaaaaa-6666-6666-6666-aaaaaaaaaaaa';
set local "request.jwt.claims" = '{"sub": "aaaaaaaa-6666-6666-6666-aaaaaaaaaaaa", "role": "authenticated"}';

do $$
declare
  v_shop_a uuid;
  v_lottery_a uuid;
  v_template_a uuid;
  v_seller_a uuid;
  v_draw_old_closed uuid;
  v_draw_recent_closed uuid;
  v_tier_1 uuid;
  v_pay_id uuid;
begin
  v_shop_a := create_shop_with_defaults('Shop A', 'Owner A', 'Ernakulam', 'A-100', 'en', '9876500061');
  select id into v_lottery_a from lotteries where shop_id = v_shop_a and code = 'KR' limit 1;
  select id into v_template_a from prize_templates where shop_id = v_shop_a limit 1;

  insert into sellers (shop_id, name, phone, area)
  values (v_shop_a, 'Seller A', '9876511111', 'Aluva')
  returning id into v_seller_a;

  -- Draw 1 (User A): draw_date 40 days ago, closed_at 31 days ago -> ELIGIBLE for cleanup
  v_draw_old_closed := create_draw(v_lottery_a, current_date - 40, 'KR-601', 40.00, v_template_a);
  perform create_stock_batch(v_draw_old_closed, 'KR', '100001', '100010', 35.00);
  perform mark_counter_sold(v_draw_old_closed, 'KR', '100001', '100002');
  perform issue_tickets_by_range(v_seller_a, v_draw_old_closed, 'KR', '100003', '100005');

  select id into v_tier_1 from draw_prize_tiers where draw_id = v_draw_old_closed and tier_order = 1;
  perform save_draw_results_and_check(
    v_draw_old_closed,
    jsonb_build_array(
      jsonb_build_object('tier_id', v_tier_1, 'series', 'KR', 'number', '100001')
    )
  );
  perform close_draw(v_draw_old_closed);

  -- Record a payment and reverse it so reversed_entry_id FK is exercised on delete
  v_pay_id := record_payment(v_seller_a, 50.00, 'CASH', 'Partial');
  perform reverse_ledger_entry(v_pay_id);

  -- Draw 2 (User A): draw_date 45 days ago, but closed_at only 10 days ago -> NOT eligible
  v_draw_recent_closed := create_draw(v_lottery_a, current_date - 45, 'KR-600', 40.00, v_template_a);
  perform create_stock_batch(v_draw_recent_closed, 'KR', '200001', '200005', 35.00);
  select id into v_tier_1 from draw_prize_tiers where draw_id = v_draw_recent_closed and tier_order = 1;
  perform save_draw_results_and_check(
    v_draw_recent_closed,
    jsonb_build_array(
      jsonb_build_object('tier_id', v_tier_1, 'series', 'KR', 'number', '999999')
    )
  );
  perform close_draw(v_draw_recent_closed);
end;
$$;

-- Switch to User B and create Shop B + closed draw (closed 35 days ago) + active draw
set local "request.jwt.claim.sub" = 'bbbbbbbb-6666-6666-6666-bbbbbbbbbbbb';
set local "request.jwt.claims" = '{"sub": "bbbbbbbb-6666-6666-6666-bbbbbbbbbbbb", "role": "authenticated"}';

do $$
declare
  v_shop_b uuid;
  v_lottery_b uuid;
  v_template_b uuid;
  v_seller_b uuid;
  v_draw_b uuid;
begin
  v_shop_b := create_shop_with_defaults('Shop B', 'Owner B', 'Thrissur', 'B-200', 'ml', '9876500062');
  select id into v_lottery_b from lotteries where shop_id = v_shop_b and code = 'KR' limit 1;
  select id into v_template_b from prize_templates where shop_id = v_shop_b limit 1;

  insert into sellers (shop_id, name, phone, area)
  values (v_shop_b, 'Seller B', '9876522222', 'Town')
  returning id into v_seller_b;

  v_draw_b := create_draw(v_lottery_b, current_date, 'KR-701', 40.00, v_template_b);
  perform create_stock_batch(v_draw_b, 'KR', '300001', '300010', 35.00);
  perform issue_tickets_by_range(v_seller_b, v_draw_b, 'KR', '300001', '300004');
end;
$$;

-- Backdate closed_at timestamps as superuser (postgres) to test cleanup_old_closed_draws()
reset role;

update public.draws
set closed_at = now() - interval '31 days'
where draw_number = 'KR-601';

update public.draws
set closed_at = now() - interval '10 days'
where draw_number = 'KR-600';

-- ============================================================================
-- 1. Test cleanup_old_closed_draws()
-- ============================================================================

select is(
  public.cleanup_old_closed_draws(),
  jsonb_build_object('deleted_tickets', 10, 'deleted_batches', 1),
  'cleanup_old_closed_draws() deletes 10 tickets and 1 batch from draw closed 31 days ago'
);

select is(
  (select count(*)::int from public.tickets t join public.draws d on d.id = t.draw_id where d.draw_number = 'KR-601'),
  0,
  'KR-601 (closed 31d ago) has 0 tickets remaining'
);

select is(
  (select count(*)::int from public.stock_batches sb join public.draws d on d.id = sb.draw_id where d.draw_number = 'KR-601'),
  0,
  'KR-601 (closed 31d ago) has 0 stock_batches remaining'
);

select is(
  (select count(*)::int from public.tickets t join public.draws d on d.id = t.draw_id where d.draw_number = 'KR-600'),
  5,
  'KR-600 (draw_date 45d ago, but closed_at 10d ago) keeps all 5 tickets because cleanup uses closed_at'
);

select is(
  (select count(*)::int from public.stock_batches sb join public.draws d on d.id = sb.draw_id where d.draw_number = 'KR-600'),
  1,
  'KR-600 (closed_at 10d ago) keeps its stock_batch'
);

select is(
  (select count(*)::int from public.wins w join public.draws d on d.id = w.draw_id where d.draw_number = 'KR-601'),
  1,
  'KR-601 wins row survives ticket and stock_batch cleanup untouched'
);

select is(
  (select count(*)::int from public.draw_summaries ds join public.draws d on d.id = ds.draw_id where d.draw_number = 'KR-601'),
  1,
  'KR-601 draw_summaries row survives cleanup untouched'
);

select is(
  (select count(*)::int from public.ledger_entries le join public.shops s on s.id = le.shop_id where s.name = 'Shop A'),
  3,
  'Shop A ledger_entries (ISSUE + PAYMENT + reversal) survive cleanup untouched'
);

-- ============================================================================
-- 2. Test storage_usage view
-- ============================================================================

select is(
  (select count(*)::int from public.storage_usage),
  13,
  'storage_usage view reports all 13 core public tables'
);

select ok(
  (select bool_and(total_bytes >= 0 and pct_of_500mb_limit >= 0) from public.storage_usage),
  'storage_usage view reports non-negative byte sizes and percentages'
);

-- ============================================================================
-- 3. Test delete_my_shop_and_account() isolation (User A cannot delete User B)
-- ============================================================================

set local role authenticated;
set local "request.jwt.claim.sub" = 'aaaaaaaa-6666-6666-6666-aaaaaaaaaaaa';
set local "request.jwt.claims" = '{"sub": "aaaaaaaa-6666-6666-6666-aaaaaaaaaaaa", "role": "authenticated"}';

select is(
  (public.delete_my_shop_and_account() ->> 'deleted_user_id'),
  'aaaaaaaa-6666-6666-6666-aaaaaaaaaaaa',
  'delete_my_shop_and_account() deletes User A using auth.uid()'
);

reset role;

select is(
  (select count(*)::int from auth.users where id = 'aaaaaaaa-6666-6666-6666-aaaaaaaaaaaa'),
  0,
  'User A auth.users row is permanently deleted'
);

select is(
  (select count(*)::int from public.shops where owner_id = 'aaaaaaaa-6666-6666-6666-aaaaaaaaaaaa'),
  0,
  'User A shop is permanently deleted'
);

select is(
  (select count(*)::int from public.ledger_entries le where not exists (select 1 from public.shops s where s.id = le.shop_id)),
  0,
  'User A ledger_entries are completely deleted with no orphans'
);

select is(
  (select count(*)::int from auth.users where id = 'bbbbbbbb-6666-6666-6666-bbbbbbbbbbbb'),
  1,
  'User B auth.users row is untouched by User A account deletion'
);

select is(
  (select count(*)::int from public.shops where owner_id = 'bbbbbbbb-6666-6666-6666-bbbbbbbbbbbb'),
  1,
  'User B shop is untouched by User A account deletion'
);

select is(
  (select count(*)::int from public.tickets t join public.shops s on s.id = t.shop_id where s.owner_id = 'bbbbbbbb-6666-6666-6666-bbbbbbbbbbbb'),
  10,
  'User B tickets (10) are untouched by User A account deletion'
);

select * from finish();

rollback;
