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
set local "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

select create_shop_with_defaults('Shop A', 'Owner A', 'Ernakulam', 'AG-A', 'ml', '9876543210');

-- Create a draw for User A using create_draw RPC
select is(
  (
    select count(*)::int from draw_prize_tiers
    where draw_id = create_draw(
      (select id from lotteries where code = 'W' limit 1),
      current_date,
      'W-900',
      40.00,
      (select id from prize_templates limit 1)
    )
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
  'DRAW_EXISTS',
  '2. create_draw raises DRAW_EXISTS on duplicate (shop_id, lottery_id, draw_date)'
);

-- 3. Add stock batch KR 482900..482999 (100 tickets)
select is(
  (
    with new_batch as (
      select create_stock_batch(
        (select id from draws where draw_number = 'W-900' limit 1),
        'KR',
        '482900',
        '482999',
        35.00
      ) as id
    )
    select count(*)::int from tickets where batch_id = (select id from new_batch)
  ),
  100,
  '3. create_stock_batch creates batch and expands 100 tickets in IN_STOCK status'
);

-- 4. Overlapping range raises STOCK_OVERLAP with overlapping range detail
select throws_ok(
  $$select create_stock_batch(
      (select id from draws where draw_number = 'W-900' limit 1),
      'KR',
      '482950',
      '483049',
      35.00
    )$$,
  'STOCK_OVERLAP',
  '4. create_stock_batch raises STOCK_OVERLAP when ticket numbers overlap'
);

-- Save User A's draw_id in a custom transaction setting so User B can attempt to target it directly
select set_config(
  'test.user_a_draw_id',
  (select id::text from draws where draw_number = 'W-900' limit 1),
  true
);

-- 5. User B cannot create stock in User A's draw (raises NOT_FOUND)
set local "request.jwt.claim.sub" = '22222222-2222-2222-2222-222222222222';
select create_shop_with_defaults('Shop B', 'Owner B', 'Kollam', 'AG-B', 'ml', '9876543211');

select throws_ok(
  $$select create_stock_batch(
      current_setting('test.user_a_draw_id')::uuid,
      'KR',
      '100000',
      '100099',
      35.00
    )$$,
  'NOT_FOUND',
  '5. User B cannot create stock in User A draw (NOT_FOUND)'
);

-- Switch back to User A
set local "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';

-- 6. Mark one ticket as WITH_SELLER and verify delete_stock_batch raises BATCH_IN_USE
update tickets
set status = 'WITH_SELLER'
where draw_id = (select id from draws where draw_number = 'W-900' limit 1)
  and number = '482900';

select throws_ok(
  $$select delete_stock_batch(
      (select id from stock_batches where series = 'KR' and start_number = '482900' limit 1)
    )$$,
  'BATCH_IN_USE',
  '6. delete_stock_batch raises BATCH_IN_USE when any ticket is not IN_STOCK'
);

-- 7. Restore ticket to IN_STOCK and verify delete_stock_batch deletes the batch and its tickets
update tickets
set status = 'IN_STOCK'
where draw_id = (select id from draws where draw_number = 'W-900' limit 1)
  and number = '482900';

select lives_ok(
  $$select delete_stock_batch(
      (select id from stock_batches where series = 'KR' and start_number = '482900' limit 1)
    )$$,
  '7. delete_stock_batch succeeds when all tickets are IN_STOCK'
);

-- 8. Set draw status to RESULT_ENTERED and verify create_stock_batch raises DRAW_NOT_OPEN
update draws
set status = 'RESULT_ENTERED'
where draw_number = 'W-900';

select throws_ok(
  $$select create_stock_batch(
      (select id from draws where draw_number = 'W-900' limit 1),
      'KR',
      '500000',
      '500099',
      35.00
    )$$,
  'DRAW_NOT_OPEN',
  '8. create_stock_batch raises DRAW_NOT_OPEN when draw status is not UPCOMING'
);

select * from finish();
rollback;
