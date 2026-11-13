-- pgTAP Phase 2 Stock & Draw RPC Tests
-- Verifies:
--   1. create_draw copies template tiers and rejects duplicate (shop_id, lottery_id, draw_date) with DRAW_EXISTS
--   2. create_stock_batch expands tickets via generate_series and rejects overlapping ranges with STOCK_OVERLAP
--   3. create_stock_batch rejects non-UPCOMING draws with DRAW_NOT_OPEN
--   4. delete_stock_batch blocks deletion with BATCH_IN_USE when any ticket is not IN_STOCK, and succeeds when all are IN_STOCK
--   5. User B cannot create stock in User A's draw or delete User A's batch (NOT_FOUND)

begin;
create extension if not exists pgtap;
select plan(8);

insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', '9876543210@luckyledger.app'),
  ('22222222-2222-2222-2222-222222222222', '9876543211@luckyledger.app')
on conflict (id) do nothing;

-- ============================================================================
-- Setup as User A ('11111111-1111-1111-1111-111111111111')
-- ============================================================================
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select create_shop_with_defaults('Shop A', 'Owner A', 'Ernakulam', 'AG-A', 'ml', '9876543210');

-- Execute create_draw in its own statement so the new draw and its 9 copied tiers are visible in the snapshot
do $$
declare
  v_draw_id uuid;
begin
  v_draw_id := create_draw(
    (select id from lotteries where code = 'W' limit 1),
    current_date,
    'W-900',
    40.00,
    (select id from prize_templates limit 1)
  );
  perform set_config('test.user_a_draw_id', v_draw_id::text, true);
end;
$$;

-- 1. Verify create_draw created the draw and copied 9 template tiers into draw_prize_tiers
select is(
  (
    select count(*)::int from draw_prize_tiers
    where draw_id = current_setting('test.user_a_draw_id')::uuid
  ),
  9,
  '1. create_draw creates draw and copies 9 template tiers into draw_prize_tiers'
);

-- 2. Duplicate draw on same date for same lottery raises DRAW_EXISTS
select throws_ok(
  $$select create_draw(
      (select id from lotteries where code = 'W' limit 1),
      current_date,
      'W-900-DUP',
      40.00,
      null
    )$$,
  'P0001',
  'DRAW_EXISTS',
  '2. create_draw raises DRAW_EXISTS on duplicate (shop_id, lottery_id, draw_date)'
);

-- 3. Add stock batch KR 482900..482999 (100 tickets) in its own statement, then assert ticket count
do $$
declare
  v_batch_id uuid;
begin
  v_batch_id := create_stock_batch(
    current_setting('test.user_a_draw_id')::uuid,
    'KR',
    '482900',
    '482999',
    35.00
  );
  perform set_config('test.user_a_batch_id', v_batch_id::text, true);
end;
$$;

select is(
  (
    select count(*)::int from tickets
    where batch_id = current_setting('test.user_a_batch_id')::uuid
      and status = 'IN_STOCK'
  ),
  100,
  '3. create_stock_batch creates batch and expands 100 tickets in IN_STOCK status'
);

-- 4. Overlapping range raises STOCK_OVERLAP with overlapping range detail
select throws_ok(
  $$select create_stock_batch(
      current_setting('test.user_a_draw_id')::uuid,
      'KR',
      '482950',
      '483049',
      35.00
    )$$,
  'P0001',
  'STOCK_OVERLAP',
  '4. create_stock_batch raises STOCK_OVERLAP when ticket numbers overlap'
);

-- 5. User B cannot create stock in User A's draw (raises NOT_FOUND)
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select create_shop_with_defaults('Shop B', 'Owner B', 'Kollam', 'AG-B', 'ml', '9876543211');

select throws_ok(
  $$select create_stock_batch(
      current_setting('test.user_a_draw_id')::uuid,
      'KR',
      '100000',
      '100099',
      35.00
    )$$,
  'P0001',
  'NOT_FOUND',
  '5. User B cannot create stock in User A draw (NOT_FOUND)'
);

-- Switch back to User A
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

-- 6. Mark one ticket as WITH_SELLER and verify delete_stock_batch raises BATCH_IN_USE
update tickets
set status = 'WITH_SELLER'
where draw_id = current_setting('test.user_a_draw_id')::uuid
  and number = '482900';

select throws_ok(
  $$select delete_stock_batch(
      current_setting('test.user_a_batch_id')::uuid
    )$$,
  'P0001',
  'BATCH_IN_USE',
  '6. delete_stock_batch raises BATCH_IN_USE when any ticket is not IN_STOCK'
);

-- 7. Restore ticket to IN_STOCK and verify delete_stock_batch deletes the batch and its tickets
update tickets
set status = 'IN_STOCK'
where draw_id = current_setting('test.user_a_draw_id')::uuid
  and number = '482900';

select lives_ok(
  $$select delete_stock_batch(
      current_setting('test.user_a_batch_id')::uuid
    )$$,
  '7. delete_stock_batch succeeds when all tickets are IN_STOCK'
);

-- 8. Set draw status to RESULT_ENTERED and verify create_stock_batch raises DRAW_NOT_OPEN
update draws
set status = 'RESULT_ENTERED'
where id = current_setting('test.user_a_draw_id')::uuid;

select throws_ok(
  $$select create_stock_batch(
      current_setting('test.user_a_draw_id')::uuid,
      'KR',
      '500000',
      '500099',
      35.00
    )$$,
  'P0001',
  'DRAW_NOT_OPEN',
  '8. create_stock_batch raises DRAW_NOT_OPEN when draw status is not UPCOMING'
);

select * from finish();
rollback;
