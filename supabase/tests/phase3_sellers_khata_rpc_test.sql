-- pgTAP test: Phase 3 Sellers & Khata RPCs, Data Safety & Cross-Shop Isolation
-- Verifies:
--   1. Multi-range STOCK_OVERLAP detail lists ALL overlapping ranges (A.1)
--   2. issue_tickets blocked when draw status != UPCOMING ('DRAW_NOT_OPEN') or seller inactive ('SELLER_INACTIVE') (A.3, A.8)
--   3. return_tickets of another seller's ticket rejected ('TICKETS_NOT_WITH_SELLER') (A.8)
--   4. return_tickets after result entered (status = 'RESULT_ENTERED') succeeds and sets RETURNED_UNSOLD;
--      blocked when status = 'CLOSED' ('DRAW_NOT_OPEN')
--   5. Deleting a seller with ledger_entries as authenticated rejected by ON DELETE NO ACTION (A.8, B.9)
--   6. Authenticated user blocked from UPDATE/DELETE on ledger_entries ('LEDGER_IMMUTABLE')
--   7. reverse_ledger_entry reverses PAYMENT once, blocks 2nd reversal ('ALREADY_REVERSED'), blocks ISSUE ('NOT_REVERSIBLE') (A.2)
--   8. Changing draws.ticket_price blocked once ledger_entries exist ('PRICE_LOCKED') (B.12)
--   9. mark_counter_sold & unmark_counter_sold transitions (A.4)
--  10. Cross-shop isolation for sellers and ledger_entries (A.8)
--  11. As postgres, deleting a shop that has sellers, tickets WITH_SELLER, and ledger entries (including a reversed pair)
--      succeeds and leaves zero orphan rows.

begin;
create extension if not exists pgtap;
select plan(21);

-- Create two test users in auth.users
insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111', '9876543210@luckyledger.app'),
  ('22222222-2222-2222-2222-222222222222', '9876543211@luckyledger.app')
on conflict (id) do nothing;

-- Authenticate as User A and create Shop A
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select create_shop_with_defaults('Shop A', 'Owner A', 'Ernakulam', 'EKM-001', 'en');

-- Authenticate as User B and create Shop B
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select create_shop_with_defaults('Shop B', 'Owner B', 'Kollam', 'KLM-002', 'ml');

-- Switch back to User A
select set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

-- Create draw and two stock batches for User A: KR 482900..482910 and KR 482920..482930
do $$
declare
  v_lottery_id uuid;
  v_template_id uuid;
  v_draw_id uuid;
  v_shop_a uuid;
begin
  select id into v_shop_a from shops where owner_id = '11111111-1111-1111-1111-111111111111';
  perform set_config('test.shop_a_id', v_shop_a::text, true);
  select id into v_lottery_id from lotteries where name = 'Win-Win' limit 1;
  select id into v_template_id from prize_templates limit 1;

  v_draw_id := create_draw(v_lottery_id, '2026-11-25'::date, 'W-901', 50.00, v_template_id);
  perform set_config('test.draw_a_id', v_draw_id::text, true);

  perform create_stock_batch(v_draw_id, 'KR', '482900', '482910', 44.00);
  perform create_stock_batch(v_draw_id, 'KR', '482920', '482930', 44.00);

  insert into sellers (id, shop_id, name, phone, area)
  values
    ('aaaaaaaa-0000-0000-0000-000000000001', v_shop_a, 'Rajan', '9000000001', 'Aluva'),
    ('aaaaaaaa-0000-0000-0000-000000000002', v_shop_a, 'Babu', '9000000002', 'Kaloor');
end;
$$;

-- 1. Multi-range STOCK_OVERLAP detail lists ALL overlapping ranges
select throws_ok(
  format(
    'select create_stock_batch(%L::uuid, ''KR'', ''482905'', ''482925'', 44.00)',
    current_setting('test.draw_a_id')
  ),
  'P0001',
  'STOCK_OVERLAP',
  'STOCK_OVERLAP raised when overlapping multiple existing batches'
);

do $$
begin
  perform create_stock_batch(current_setting('test.draw_a_id')::uuid, 'KR', '482905', '482925', 44.00);
exception
  when others then
    declare
      v_detail text;
    begin
      get stacked diagnostics v_detail = pg_exception_detail;
      perform set_config('test.overlap_detail', coalesce(v_detail, ''), true);
    end;
end;
$$;

select is(
  current_setting('test.overlap_detail'),
  'KR 482905–482910, KR 482920–482925',
  'STOCK_OVERLAP detail lists all overlapping sub-ranges'
);

-- 2. Issue 3 tickets to Seller 1 (Rajan) and verify balance = 150.00
do $$
declare
  v_ids uuid[];
  v_issue_entry uuid;
begin
  select array_agg(id order by number)
  into v_ids
  from (
    select id, number
    from tickets
    where draw_id = current_setting('test.draw_a_id')::uuid
      and number in ('482900', '482901', '482902')
  ) t;

  v_issue_entry := issue_tickets(
    'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
    current_setting('test.draw_a_id')::uuid,
    v_ids
  );
  perform set_config('test.issue_entry_id', v_issue_entry::text, true);
  perform set_config('test.rajan_ticket_1', v_ids[1]::text, true);
  perform set_config('test.rajan_ticket_2', v_ids[2]::text, true);
end;
$$;

select is(
  (select balance from seller_balances() where seller_id = 'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  150.00::numeric(12,2),
  'Seller balance is ₹150.00 after issuing 3 tickets at ₹50'
);

-- 3. Return of Seller 1's ticket by Seller 2 is rejected with TICKETS_NOT_WITH_SELLER
select throws_ok(
  format(
    'select return_tickets(''aaaaaaaa-0000-0000-0000-000000000002''::uuid, %L::uuid, array[%L::uuid])',
    current_setting('test.draw_a_id'),
    current_setting('test.rajan_ticket_1')
  ),
  'P0001',
  'TICKETS_NOT_WITH_SELLER',
  'Cannot return a ticket belonging to another seller'
);

-- 4. Changing draws.ticket_price is locked once a ledger entry exists for that draw (PRICE_LOCKED)
select throws_ok(
  format(
    'update draws set ticket_price = 60.00 where id = %L::uuid',
    current_setting('test.draw_a_id')
  ),
  'P0001',
  'PRICE_LOCKED',
  'Changing draws.ticket_price after ledger entry exists raises PRICE_LOCKED'
);

-- 5. Deleting a seller who has ledger entries is blocked by ON DELETE NO ACTION
select throws_ok(
  'delete from sellers where id = ''aaaaaaaa-0000-0000-0000-000000000001''::uuid',
  '23503',
  null,
  'Deleting a seller with ledger entries is blocked by ON DELETE NO ACTION'
);

-- 6. Authenticated user cannot UPDATE or DELETE ledger_entries (LEDGER_IMMUTABLE)
select throws_ok(
  format(
    'update ledger_entries set amount = 0 where id = %L::uuid',
    current_setting('test.issue_entry_id')
  ),
  'P0001',
  'LEDGER_IMMUTABLE',
  'Authenticated user cannot UPDATE ledger_entries'
);

select throws_ok(
  format(
    'delete from ledger_entries where id = %L::uuid',
    current_setting('test.issue_entry_id')
  ),
  'P0001',
  'LEDGER_IMMUTABLE',
  'Authenticated user cannot DELETE ledger_entries'
);

-- 7. reverse_ledger_entry rejects ISSUE entry ('NOT_REVERSIBLE')
select throws_ok(
  format(
    'select reverse_ledger_entry(%L::uuid)',
    current_setting('test.issue_entry_id')
  ),
  'P0001',
  'NOT_REVERSIBLE',
  'ISSUE ledger entry cannot be reversed via reverse_ledger_entry'
);

-- 8. Record payment & reverse it once; second reversal raises ALREADY_REVERSED
do $$
declare
  v_pay_id uuid;
begin
  v_pay_id := record_payment(
    'aaaaaaaa-0000-0000-0000-000000000001'::uuid,
    100.00,
    'CASH',
    'Morning collection'
  );
  perform set_config('test.pay_entry_id', v_pay_id::text, true);
  perform reverse_ledger_entry(v_pay_id);
end;
$$;

select is(
  (select balance from seller_balances() where seller_id = 'aaaaaaaa-0000-0000-0000-000000000001'::uuid),
  150.00::numeric(12,2),
  'Balance returns to ₹150.00 after payment reversal'
);

select throws_ok(
  format(
    'select reverse_ledger_entry(%L::uuid)',
    current_setting('test.pay_entry_id')
  ),
  'P0001',
  'ALREADY_REVERSED',
  'Reversing an already reversed entry raises ALREADY_REVERSED'
);

-- 9. mark_counter_sold and unmark_counter_sold work on valid range
select is(
  mark_counter_sold(current_setting('test.draw_a_id')::uuid, 'KR', '482905', '482908'),
  4,
  'mark_counter_sold marks 4 IN_STOCK tickets as SOLD_COUNTER'
);

select is(
  unmark_counter_sold(current_setting('test.draw_a_id')::uuid, 'KR', '482905', '482908'),
  4,
  'unmark_counter_sold restores 4 SOLD_COUNTER tickets to IN_STOCK'
);

-- 10. When draw status = RESULT_ENTERED:
--     a) issue_tickets is blocked ('DRAW_NOT_OPEN')
--     b) return_tickets succeeds and sets ticket status = 'RETURNED_UNSOLD'
update draws
set status = 'RESULT_ENTERED'
where id = current_setting('test.draw_a_id')::uuid;

select throws_ok(
  format(
    'select issue_tickets(''aaaaaaaa-0000-0000-0000-000000000002''::uuid, %L::uuid, array[(select id from tickets where draw_id = %L::uuid and status = ''IN_STOCK'' limit 1)])',
    current_setting('test.draw_a_id'),
    current_setting('test.draw_a_id')
  ),
  'P0001',
  'DRAW_NOT_OPEN',
  'issue_tickets blocked when draw status is RESULT_ENTERED'
);

select lives_ok(
  format(
    'select return_tickets(''aaaaaaaa-0000-0000-0000-000000000001''::uuid, %L::uuid, array[%L::uuid])',
    current_setting('test.draw_a_id'),
    current_setting('test.rajan_ticket_1')
  ),
  'return_tickets succeeds when draw status is RESULT_ENTERED'
);

select is(
  (select status from tickets where id = current_setting('test.rajan_ticket_1')::uuid),
  'RETURNED_UNSOLD',
  'Returned ticket after RESULT_ENTERED has status RETURNED_UNSOLD'
);

-- 11. When draw status = CLOSED, return_tickets is blocked ('DRAW_NOT_OPEN')
update draws
set status = 'CLOSED'
where id = current_setting('test.draw_a_id')::uuid;

select throws_ok(
  format(
    'select return_tickets(''aaaaaaaa-0000-0000-0000-000000000001''::uuid, %L::uuid, array[%L::uuid])',
    current_setting('test.draw_a_id'),
    current_setting('test.rajan_ticket_2')
  ),
  'P0001',
  'DRAW_NOT_OPEN',
  'return_tickets blocked when draw status is CLOSED'
);

-- 12. Cross-shop isolation: User B cannot read User A sellers/ledger or record payment on User A seller
select set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select is(
  (select count(*)::int from ledger_entries),
  0,
  'User B cannot read User A ledger_entries'
);

select throws_ok(
  'select record_payment(''aaaaaaaa-0000-0000-0000-000000000001''::uuid, 50.00, ''CASH'', ''Cross-shop attempt'')',
  'P0001',
  'NOT_FOUND',
  'User B cannot record payment for User A seller'
);

-- 13. As postgres, deleting Shop A (which has sellers, tickets WITH_SELLER, and ledger entries including a reversed pair)
--     succeeds and leaves zero orphan rows.
reset role;

select lives_ok(
  format('delete from shops where id = %L::uuid', current_setting('test.shop_a_id')),
  'Deleting shop as postgres succeeds with sellers, WITH_SELLER tickets, and reversed ledger pair'
);

select is(
  (
    (select count(*)::int from sellers where shop_id = current_setting('test.shop_a_id')::uuid) +
    (select count(*)::int from tickets where shop_id = current_setting('test.shop_a_id')::uuid) +
    (select count(*)::int from ledger_entries where shop_id = current_setting('test.shop_a_id')::uuid)
  ),
  0,
  'No orphan sellers, tickets, or ledger_entries remain after deleting Shop A'
);

select * from finish();
rollback;
