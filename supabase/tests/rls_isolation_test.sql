-- pgTAP RLS Isolation Test (§6.4)
-- Proves User A cannot read, insert, update, or delete User B's shop, sellers, tickets, ledger, or wins.

begin;
create extension if not exists pgtap;
select plan(12);

-- Create two mock auth users
insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', '9876543210@luckyledger.app'),
  ('22222222-2222-2222-2222-222222222222', '9876543211@luckyledger.app')
on conflict (id) do nothing;

-- ============================================================================
-- Setup as User B ('22222222-2222-2222-2222-222222222222')
-- ============================================================================
set local role authenticated;
set local "request.jwt.claim.sub" = '22222222-2222-2222-2222-222222222222';

select create_shop_with_defaults('Shop B', 'Owner B', 'Kochi', 'AG-B', 'ml', '9876543211');

insert into sellers (id, shop_id, name, phone, area)
select 'b0000000-0000-0000-0000-000000000001', id, 'Seller B1', '9000000001', 'Aluva'
from shops where owner_id = '22222222-2222-2222-2222-222222222222';

insert into draws (id, shop_id, lottery_id, draw_number, draw_date, ticket_price)
select
  'b0000000-0000-0000-0000-000000000002',
  s.id,
  l.id,
  'W-100',
  current_date,
  40.00
from shops s
join lotteries l on l.shop_id = s.id
where s.owner_id = '22222222-2222-2222-2222-222222222222'
limit 1;

insert into draw_prize_tiers (id, draw_id, tier_order, label, amount, match_type)
values ('b0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000002', 1, '1st Prize', 7500000, 'FULL');

insert into stock_batches (id, shop_id, draw_id, series, start_number, end_number, quantity, cost_per_ticket)
select
  'b0000000-0000-0000-0000-000000000004',
  id,
  'b0000000-0000-0000-0000-000000000002',
  'KR',
  '482900',
  '482900',
  1,
  35.00
from shops where owner_id = '22222222-2222-2222-2222-222222222222';

insert into tickets (id, shop_id, draw_id, batch_id, series, number)
select
  'b0000000-0000-0000-0000-000000000005',
  id,
  'b0000000-0000-0000-0000-000000000002',
  'b0000000-0000-0000-0000-000000000004',
  'KR',
  '482900'
from shops where owner_id = '22222222-2222-2222-2222-222222222222';

insert into ledger_entries (id, shop_id, seller_id, draw_id, type, amount)
select
  'b0000000-0000-0000-0000-000000000006',
  id,
  'b0000000-0000-0000-0000-000000000001',
  'b0000000-0000-0000-0000-000000000002',
  'ISSUE',
  400.00
from shops where owner_id = '22222222-2222-2222-2222-222222222222';

insert into wins (id, shop_id, draw_id, ticket_id, series, number, sold_by, tier_id, amount)
select
  'b0000000-0000-0000-0000-000000000007',
  id,
  'b0000000-0000-0000-0000-000000000002',
  'b0000000-0000-0000-0000-000000000005',
  'KR',
  '482900',
  'COUNTER',
  'b0000000-0000-0000-0000-000000000003',
  7500000.00
from shops where owner_id = '22222222-2222-2222-2222-222222222222';

-- ============================================================================
-- Switch to User A ('11111111-1111-1111-1111-111111111111')
-- ============================================================================
set local "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';
select create_shop_with_defaults('Shop A', 'Owner A', 'Thrissur', 'AG-A', 'en', '9876543210');

-- 1. User A sees only their own shop (1 row, not Shop B)
select is(
  (select count(*)::int from shops),
  1,
  'User A can only read their own shop'
);

-- 2. User A cannot read User B sellers
select is(
  (select count(*)::int from sellers where id = 'b0000000-0000-0000-0000-000000000001'),
  0,
  'User A cannot read Shop B sellers'
);

-- 3. User A cannot read User B tickets
select is(
  (select count(*)::int from tickets where id = 'b0000000-0000-0000-0000-000000000005'),
  0,
  'User A cannot read Shop B tickets'
);

-- 4. User A cannot read User B ledger entries
select is(
  (select count(*)::int from ledger_entries where id = 'b0000000-0000-0000-0000-000000000006'),
  0,
  'User A cannot read Shop B ledger entries'
);

-- 5. User A cannot read User B wins
select is(
  (select count(*)::int from wins where id = 'b0000000-0000-0000-0000-000000000007'),
  0,
  'User A cannot read Shop B wins'
);

-- 6. User A cannot read User B draw_prize_tiers (child table without shop_id)
select is(
  (select count(*)::int from draw_prize_tiers where id = 'b0000000-0000-0000-0000-000000000003'),
  0,
  'User A cannot read Shop B draw_prize_tiers'
);

-- 7. User A cannot update User B seller
update sellers set name = 'Hacked' where id = 'b0000000-0000-0000-0000-000000000001';
set local "request.jwt.claim.sub" = '22222222-2222-2222-2222-222222222222';
select is(
  (select name from sellers where id = 'b0000000-0000-0000-0000-000000000001'),
  'Seller B1',
  'User A cannot update Shop B seller'
);

-- 8. User A cannot delete User B ticket
set local "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';
delete from tickets where id = 'b0000000-0000-0000-0000-000000000005';
set local "request.jwt.claim.sub" = '22222222-2222-2222-2222-222222222222';
select is(
  (select count(*)::int from tickets where id = 'b0000000-0000-0000-0000-000000000005'),
  1,
  'User A cannot delete Shop B ticket'
);

-- 9. User A cannot delete User B ledger_entry (blocked by LEDGER_IMMUTABLE + RLS)
set local "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';
select throws_ok(
  $$delete from ledger_entries where id = 'b0000000-0000-0000-0000-000000000006'$$,
  'P0001',
  'LEDGER_IMMUTABLE',
  'User A cannot delete Shop B ledger_entry'
);

-- 10. User A cannot delete User B win
set local "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';
delete from wins where id = 'b0000000-0000-0000-0000-000000000007';
set local "request.jwt.claim.sub" = '22222222-2222-2222-2222-222222222222';
select is(
  (select count(*)::int from wins where id = 'b0000000-0000-0000-0000-000000000007'),
  1,
  'User A cannot delete Shop B win'
);

-- 11. User A cannot insert a seller into Shop B
set local "request.jwt.claim.sub" = '11111111-1111-1111-1111-111111111111';
select throws_ok(
  $$insert into sellers (shop_id, name)
    values ((select id from shops where owner_id = '22222222-2222-2222-2222-222222222222'), 'Injected Seller')$$,
  null,
  'User A cannot insert seller into Shop B'
);

-- 12. User A cannot insert draw_results into Shop B draw
select throws_ok(
  $$insert into draw_results (draw_id, tier_id, series, number)
    values ('b0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000003', 'KR', '482900')$$,
  null,
  'User A cannot insert draw_results into Shop B draw'
);

select * from finish();
rollback;
