-- ============================================================================
-- LuckyLedger — Phase 4 pgTAP Test Suite
-- Tests:
--   1. 3,000-ticket batch stock counts (`get_batches_for_draw`), `preview_tickets`,
--      and `issue_tickets_by_count` (3,000 tickets in 1 transaction)
--   2. All 8 prize-matching test cases (§7.5) + Rules (a), (b), (e)
--   3. Rule (c): return_tickets after RESULT_ENTERED updates winner to UNSOLD
--   4. Rule (d) & (f): DRAW_BEFORE_TIME, INVALID_RESULT_ENTRY, DUPLICATE_RESULT_ENTRY
--   5. Additions #1, #3, #4: wins RLS select-only, update_win_claim_status,
--      check_draw preserves claim_status, raises CLAIMED_WIN_AFFECTED, and p_force=true
--   6. Rule (g): close_draw converts WITH_SELLER -> SOLD_BY_SELLER and writes draw_summaries
--   7. Rule 5: Performance test (10,000 tickets x 100 result entries < 3,000 ms)
-- ============================================================================

begin;

select plan(26);

-- Create test owner in auth.users
insert into auth.users (id, email, raw_user_meta_data, created_at, updated_at)
values
  ('dddddddd-dddd-dddd-dddd-dddddddddddd', '9876500004@luckyledger.app', '{}', now(), now())
on conflict (id) do nothing;

-- Authenticate as test owner
set local role authenticated;
set local "request.jwt.claim.sub" = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
set local "request.jwt.claims" = '{"sub": "dddddddd-dddd-dddd-dddd-dddddddddddd", "role": "authenticated"}';

do $$
declare
  v_shop_id uuid;
  v_lottery_id uuid;
  v_template_id uuid;
  v_draw_3k uuid;
  v_batch_3k uuid;
  v_seller_id uuid;
  v_draw_match uuid;
begin
  v_shop_id := create_shop_with_defaults('Phase4 Shop', 'Anand', 'Ernakulam', 'EKM-404', 'en', '9876500004');
  select id into v_lottery_id from lotteries where shop_id = v_shop_id and code = 'KR' limit 1;
  select id into v_template_id from prize_templates where shop_id = v_shop_id limit 1;

  -- Add a LAST_3 tier (9th Prize ₹100) to template so all 4 match types exist
  insert into prize_template_tiers (template_id, tier_order, label, amount, match_type)
  values (v_template_id, 10, '9th Prize', 100.00, 'LAST_3');

  -- 1. Create draw for 3,000-ticket batch test
  v_draw_3k := create_draw(v_lottery_id, current_date - 2, 'KR-3000', 40.00, v_template_id);
  v_batch_3k := create_stock_batch(v_draw_3k, 'KR', '100001', '103000', 35.00);

  insert into sellers (shop_id, name, phone, area)
  values (v_shop_id, 'Rajan', '9876511111', 'Aluva')
  returning id into v_seller_id;

  -- 2. Create draw in the past (current_date - 1) so results can be entered (Rule d)
  v_draw_match := create_draw(v_lottery_id, current_date - 1, 'KR-700', 40.00, v_template_id);

  -- Add batches across series KR, WN, KN
  perform create_stock_batch(v_draw_match, 'KR', '482901', '482920', 35.00);
  perform create_stock_batch(v_draw_match, 'WN', '482901', '482905', 35.00);
  perform create_stock_batch(v_draw_match, 'WN', '100998', '100999', 35.00);
  perform create_stock_batch(v_draw_match, 'KR', '555555', '555555', 35.00);

  -- Mark KR 482901 as SOLD_COUNTER
  perform mark_counter_sold(v_draw_match, 'KR', '482901', '482901');

  -- Issue KR 482910..482912 to Seller Rajan (WITH_SELLER)
  perform issue_tickets_by_range(v_seller_id, v_draw_match, 'KR', '482910', '482912');

  perform set_config('test.shop_id', v_shop_id::text, true);
  perform set_config('test.lottery_id', v_lottery_id::text, true);
  perform set_config('test.template_id', v_template_id::text, true);
  perform set_config('test.draw_3k', v_draw_3k::text, true);
  perform set_config('test.seller_id', v_seller_id::text, true);
  perform set_config('test.draw_match', v_draw_match::text, true);
end $$;

-- ============================================================================
-- SECTION 1: 3,000-Ticket Batch Server-Side Counts & Bulk Issue (Assertions 1–4)
-- ============================================================================

-- 1. get_batches_for_draw returns exact 3,000 in_stock_count (no 1000-row cap)
select is(
  (select in_stock_count from get_batches_for_draw(current_setting('test.draw_3k')::uuid) limit 1),
  3000,
  'get_batches_for_draw returns 3000 in_stock_count for a 3000-ticket batch'
);

-- 2. preview_tickets returns total_count = 3000 and contiguous range summary
select is(
  (select ranges_summary from preview_tickets(current_setting('test.draw_3k')::uuid, 'COUNT', 3000, 'KR')),
  'KR 100001–103000 (3000)',
  'preview_tickets summarizes 3000 tickets without returning 3000 row IDs'
);

-- 3. issue_tickets_by_count issues all 3,000 tickets in a single server-side transaction
do $$
begin
  perform issue_tickets_by_count(
    current_setting('test.seller_id')::uuid,
    current_setting('test.draw_3k')::uuid,
    3000,
    'KR'
  );
end $$;

select is(
  (select with_seller_count from get_batches_for_draw(current_setting('test.draw_3k')::uuid) limit 1),
  3000,
  'issue_tickets_by_count updates all 3000 tickets to WITH_SELLER atomically'
);

-- 4. seller_balances reports has_ledger_history = true
select is(
  (select has_ledger_history from seller_balances() where seller_id = current_setting('test.seller_id')::uuid),
  true,
  'seller_balances includes server-side has_ledger_history boolean'
);

-- ============================================================================
-- SECTION 2: 8 Prize-Matching Cases (§7.5) & Rules a, b, e (Assertions 5–13)
-- ============================================================================

do $$
declare
  v_draw_id uuid := current_setting('test.draw_match')::uuid;
  v_t1 uuid;
  v_t3 uuid;
  v_t4 uuid;
  v_t9 uuid;
  v_entries jsonb;
  v_wins_count int;
begin
  select id into v_t1 from draw_prize_tiers where draw_id = v_draw_id and tier_order = 1; -- 1st FULL 75,00,000
  select id into v_t3 from draw_prize_tiers where draw_id = v_draw_id and tier_order = 3; -- 2nd FULL 5,00,000
  select id into v_t4 from draw_prize_tiers where draw_id = v_draw_id and tier_order = 5; -- 4th LAST_4 5,000
  select id into v_t9 from draw_prize_tiers where draw_id = v_draw_id and tier_order = 10; -- 9th LAST_3 100

  -- Note: Owner does NOT pass any CONSOLATION entry (Rule e)
  -- Also include '2901' in LAST_4 to test Case 6 (KR 482901 matches both 1st FULL and 4th LAST_4)
  v_entries := jsonb_build_array(
    jsonb_build_object('tier_id', v_t1, 'series', 'KR', 'number', '482901'),
    jsonb_build_object('tier_id', v_t3, 'series', 'KN', 'number', '555555'),
    jsonb_build_object('tier_id', v_t4, 'number', '2901'),
    jsonb_build_object('tier_id', v_t4, 'number', '2910'),
    jsonb_build_object('tier_id', v_t9, 'number', '999')
  );

  v_wins_count := save_draw_results_and_check(v_draw_id, v_entries, false);
  perform set_config('test.wins_count', v_wins_count::text, true);
end $$;

-- 5. Case 1 + Case 6: KR 482901 wins ONLY 1st Prize (7500000.00), not LAST_4 (2901)
select is(
  (select amount from wins where draw_id = current_setting('test.draw_match')::uuid and series = 'KR' and number = '482901'),
  7500000.00::numeric(12,2),
  'Case 1 & 6: KR 482901 matches FULL 1st Prize and takes highest tier over LAST_4'
);

-- 6. Case 7a (Rule b): KR 482901 was SOLD_COUNTER -> sold_by = COUNTER
select is(
  (select sold_by from wins where draw_id = current_setting('test.draw_match')::uuid and series = 'KR' and number = '482901'),
  'COUNTER',
  'Case 7a: SOLD_COUNTER winning ticket maps to sold_by = COUNTER'
);

-- 7. Case 2 (Rule e): WN 482901 auto-matches CONSOLATION (8000.00) even though also matching LAST_4 (5000.00)
select is(
  (select amount from wins where draw_id = current_setting('test.draw_match')::uuid and series = 'WN' and number = '482901'),
  8000.00::numeric(12,2),
  'Case 2: WN 482901 auto-matches CONSOLATION (8000) from 1st prize number'
);

-- 8. Case 7c (Rule b): WN 482901 is IN_STOCK -> sold_by = UNSOLD
select is(
  (select sold_by from wins where draw_id = current_setting('test.draw_match')::uuid and series = 'WN' and number = '482901'),
  'UNSOLD',
  'Case 7c: IN_STOCK winning ticket maps to sold_by = UNSOLD'
);

-- 9. Case 3: KR 555555 does NOT win 2nd Prize FULL (KN 555555)
select is(
  (select count(*)::int from wins where draw_id = current_setting('test.draw_match')::uuid and series = 'KR' and number = '555555'),
  0,
  'Case 3: FULL prize does not match same 6-digit number in a different series'
);

-- 10. Case 4: KR 482910 matches LAST_4 '2910' (5000.00)
select is(
  (select amount from wins where draw_id = current_setting('test.draw_match')::uuid and series = 'KR' and number = '482910'),
  5000.00::numeric(12,2),
  'Case 4: KR 482910 matches LAST_4 tier'
);

-- 11. Case 7b (Rule b): KR 482910 is WITH_SELLER -> sold_by = SELLER and seller_id = Rajan
select is(
  (select sold_by from wins where draw_id = current_setting('test.draw_match')::uuid and series = 'KR' and number = '482910'),
  'SELLER',
  'Case 7b: WITH_SELLER winning ticket maps to sold_by = SELLER'
);

-- 12. Case 5: WN 100999 matches LAST_3 '999' (100.00)
select is(
  (select amount from wins where draw_id = current_setting('test.draw_match')::uuid and series = 'WN' and number = '100999'),
  100.00::numeric(12,2),
  'Case 5: WN 100999 matches LAST_3 tier'
);

-- 13. Case 8: Non-matching tickets produce no win rows (total wins = 4: KR 482901, WN 482901, KR 482910, WN 100999)
select is(
  current_setting('test.wins_count')::int,
  4,
  'Case 8: Exact total of 4 winning tickets matched across all tiers'
);

-- ============================================================================
-- SECTION 3: Rule (c) — Return Winning Ticket After Results Entered (Assertion 14)
-- ============================================================================

do $$
begin
  perform return_tickets_by_range(
    current_setting('test.seller_id')::uuid,
    current_setting('test.draw_match')::uuid,
    'KR',
    '482910',
    '482910'
  );
end $$;

-- 14. Returning KR 482910 after results entered updates its win row to sold_by = UNSOLD, seller_id = null
select is(
  (
    select sold_by || ':' || coalesce(seller_id::text, 'NULL')
    from wins
    where draw_id = current_setting('test.draw_match')::uuid
      and series = 'KR'
      and number = '482910'
  ),
  'UNSOLD:NULL',
  'Rule (c): Returning a winning ticket after RESULT_ENTERED updates win to sold_by=UNSOLD and seller_id=null'
);

-- ============================================================================
-- SECTION 4: Rules (d) & (f) — Time & Entry Validation (Assertions 15–17)
-- ============================================================================

do $$
declare
  v_future_draw uuid;
begin
  v_future_draw := create_draw(
    current_setting('test.lottery_id')::uuid,
    current_date + 3,
    'KR-FUTURE',
    40.00,
    current_setting('test.template_id')::uuid
  );
  perform set_config('test.future_draw', v_future_draw::text, true);
end $$;

-- 15. Rule (d): Saving results before draw date+time raises DRAW_BEFORE_TIME
select throws_ok(
  format(
    'select check_draw(%L::uuid, false)',
    current_setting('test.future_draw')
  ),
  'DRAW_BEFORE_TIME',
  'Rule (d): check_draw before draw time raises DRAW_BEFORE_TIME'
);

-- 16. Rule (f): Invalid LAST_4 entry (3 digits instead of 4) raises INVALID_RESULT_ENTRY
select throws_ok(
  format(
    $q$
      select save_draw_results_and_check(
        %L::uuid,
        jsonb_build_array(
          jsonb_build_object(
            'tier_id', (select id from draw_prize_tiers where draw_id = %L::uuid and match_type = 'LAST_4' limit 1),
            'number', '123'
          )
        ),
        false
      )
    $q$,
    current_setting('test.draw_match'),
    current_setting('test.draw_match')
  ),
  'INVALID_RESULT_ENTRY',
  'Rule (f): 3-digit number in LAST_4 tier raises INVALID_RESULT_ENTRY'
);

-- 17. Rule (f): Duplicate entry in the same tier raises DUPLICATE_RESULT_ENTRY
select throws_ok(
  format(
    $q$
      select save_draw_results_and_check(
        %L::uuid,
        jsonb_build_array(
          jsonb_build_object(
            'tier_id', (select id from draw_prize_tiers where draw_id = %L::uuid and match_type = 'LAST_4' limit 1),
            'number', '2910'
          ),
          jsonb_build_object(
            'tier_id', (select id from draw_prize_tiers where draw_id = %L::uuid and match_type = 'LAST_4' limit 1),
            'number', '2910'
          )
        ),
        false
      )
    $q$,
    current_setting('test.draw_match'),
    current_setting('test.draw_match'),
    current_setting('test.draw_match')
  ),
  'DUPLICATE_RESULT_ENTRY',
  'Rule (f): Duplicate entry in same tier raises DUPLICATE_RESULT_ENTRY'
);

-- ============================================================================
-- SECTION 5: Additions #1, #3, #4 — wins RLS, Claim Status & Non-Destructive check_draw (Assertions 18–22)
-- ============================================================================

-- 18. Addition #4: Direct INSERT into wins by authenticated is blocked by RLS (42501)
select throws_ok(
  format(
    $q$
      insert into wins (shop_id, draw_id, series, number, sold_by, tier_id, amount)
      values (
        %L::uuid,
        %L::uuid,
        'KR',
        '999999',
        'COUNTER',
        (select id from draw_prize_tiers where draw_id = %L::uuid limit 1),
        100.00
      )
    $q$,
    current_setting('test.shop_id'),
    current_setting('test.draw_match'),
    current_setting('test.draw_match')
  ),
  '42501',
  'new row violates row-level security policy for table "wins"',
  'Addition #4: Direct INSERT into wins by authenticated is blocked by RLS'
);

-- 19. Addition #3 & #4: update_win_claim_status sets PAID_TO_CUSTOMER
do $$
declare
  v_win_id uuid;
begin
  select id into v_win_id
  from wins
  where draw_id = current_setting('test.draw_match')::uuid
    and series = 'KR'
    and number = '482901';

  perform update_win_claim_status(v_win_id, 'PAID_TO_CUSTOMER');
end $$;

select is(
  (select claim_status from wins where draw_id = current_setting('test.draw_match')::uuid and series = 'KR' and number = '482901'),
  'PAID_TO_CUSTOMER',
  'Addition #3 & #4: update_win_claim_status updates claim_status to PAID_TO_CUSTOMER'
);

-- 20. Addition #1: Re-running check_draw when KR 482901 still wins the same amount preserves PAID_TO_CUSTOMER
do $$
begin
  perform check_draw(current_setting('test.draw_match')::uuid, false);
end $$;

select is(
  (select claim_status from wins where draw_id = current_setting('test.draw_match')::uuid and series = 'KR' and number = '482901'),
  'PAID_TO_CUSTOMER',
  'Addition #1: Re-running check_draw preserves claim_status for unchanged winning ticket'
);

-- 21. Addition #1: Changing 1st prize so claimed ticket KR 482901 would lose raises CLAIMED_WIN_AFFECTED when p_force = false
select throws_ok(
  format(
    $q$
      select save_draw_results_and_check(
        %L::uuid,
        jsonb_build_array(
          jsonb_build_object(
            'tier_id', (select id from draw_prize_tiers where draw_id = %L::uuid and tier_order = 1),
            'series', 'KR',
            'number', '482902'
          )
        ),
        false
      )
    $q$,
    current_setting('test.draw_match'),
    current_setting('test.draw_match')
  ),
  'CLAIMED_WIN_AFFECTED',
  'Addition #1: Modifying results that remove/change a claimed win raises CLAIMED_WIN_AFFECTED when p_force=false'
);

-- 22. Addition #1: Calling save_draw_results_and_check with p_force = true succeeds and updates the win
do $$
declare
  v_draw_id uuid := current_setting('test.draw_match')::uuid;
  v_t1 uuid;
begin
  select id into v_t1 from draw_prize_tiers where draw_id = v_draw_id and tier_order = 1;
  perform save_draw_results_and_check(
    v_draw_id,
    jsonb_build_array(
      jsonb_build_object('tier_id', v_t1, 'series', 'KR', 'number', '482902')
    ),
    true
  );
end $$;

select is(
  (select count(*)::int from wins where draw_id = current_setting('test.draw_match')::uuid and series = 'KR' and number = '482902'),
  1,
  'Addition #1: save_draw_results_and_check with p_force=true succeeds when overriding claimed wins'
);

-- ============================================================================
-- SECTION 6: Rule (g) — close_draw & draw_summaries (Assertions 23–25)
-- ============================================================================

do $$
begin
  perform close_draw(current_setting('test.draw_match')::uuid);
end $$;

-- 23. Remaining WITH_SELLER tickets (KR 482911, KR 482912) converted to SOLD_BY_SELLER
select is(
  (
    select count(*)::int
    from tickets
    where draw_id = current_setting('test.draw_match')::uuid
      and status = 'SOLD_BY_SELLER'
  ),
  2,
  'Rule (g): close_draw converts remaining WITH_SELLER tickets to SOLD_BY_SELLER'
);

-- 24. draw_summaries row written with accurate sold_counter=1, sold_by_sellers=2, returned_unsold=1
select is(
  (
    select format('%s:%s:%s', sold_counter, sold_by_sellers, returned_unsold)
    from draw_summaries
    where draw_id = current_setting('test.draw_match')::uuid
  ),
  '1:2:1',
  'Rule (g): close_draw writes accurate counts to draw_summaries'
);

-- 25. Rule (d): check_draw on a CLOSED draw raises DRAW_CLOSED
select throws_ok(
  format(
    'select check_draw(%L::uuid, true)',
    current_setting('test.draw_match')
  ),
  'DRAW_CLOSED',
  'Rule (d): check_draw on a CLOSED draw raises DRAW_CLOSED'
);

-- ============================================================================
-- SECTION 7: Rule 5 — Performance Test (10,000 tickets x 100 result entries < 3s) (Assertion 26)
-- ============================================================================

do $$
declare
  v_perf_draw uuid;
  v_t1 uuid;
  v_t4 uuid;
  v_entries jsonb := '[]'::jsonb;
  v_start_ts timestamptz;
  v_elapsed_ms numeric;
  i int;
begin
  v_perf_draw := create_draw(
    current_setting('test.lottery_id')::uuid,
    current_date - 3,
    'KR-PERF10K',
    40.00,
    current_setting('test.template_id')::uuid
  );

  -- Create 10,000 tickets (two 5,000-ticket batches)
  perform create_stock_batch(v_perf_draw, 'KR', '100001', '105000', 35.00);
  perform create_stock_batch(v_perf_draw, 'WN', '105001', '110000', 35.00);

  select id into v_t1 from draw_prize_tiers where draw_id = v_perf_draw and tier_order = 1;
  select id into v_t4 from draw_prize_tiers where draw_id = v_perf_draw and match_type = 'LAST_4' limit 1;

  -- Build 100 result entries: 1st prize + 99 distinct 4-digit numbers
  v_entries := jsonb_build_array(
    jsonb_build_object('tier_id', v_t1, 'series', 'KR', 'number', '100500')
  );
  for i in 1..99 loop
    v_entries := v_entries || jsonb_build_array(
      jsonb_build_object('tier_id', v_t4, 'number', lpad((1000 + i)::text, 4, '0'))
    );
  end loop;

  v_start_ts := clock_timestamp();
  perform save_draw_results_and_check(v_perf_draw, v_entries, false);
  v_elapsed_ms := round(extract(epoch from (clock_timestamp() - v_start_ts)) * 1000.0, 2);

  raise notice 'PERF_BENCHMARK: 10,000 tickets x 100 result entries check_draw elapsed = % ms', v_elapsed_ms;
  perform set_config('test.perf_elapsed_ms', v_elapsed_ms::text, true);
  perform set_config('test.perf_under_limit', (v_elapsed_ms < 3000)::text, true);
end $$;

select diag(
  format(
    'PERF_BENCHMARK: 10,000 tickets x 100 result entries check_draw elapsed = %s ms',
    current_setting('test.perf_elapsed_ms')
  )
);

-- 26. Assert 10,000 tickets x 100 result entries completed in < 3,000 ms
select is(
  current_setting('test.perf_under_limit')::boolean,
  true,
  format(
    'Rule 5: 10,000 tickets x 100 result entries completes in %s ms (< 3,000 ms)',
    current_setting('test.perf_elapsed_ms')
  )
);

select * from finish();

rollback;
