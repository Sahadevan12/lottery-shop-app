-- Migration: 20261112000001_initial_schema_and_rls.sql
-- Description: Initial schema for LuckyLedger (§6.3), Row Level Security on every table (§6.4),
--              and Phase 1 RPC create_shop_with_defaults (§6.5).

create extension if not exists "pgcrypto";

-- ============================================================================
-- 1. TABLES (§6.3)
-- ============================================================================

-- shops: one per owner (MVP)
create table shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null,
  owner_name text,
  phone text,
  district text,
  agent_code text,               -- optional, their lottery agent/retailer code
  default_language text not null default 'ml' check (default_language in ('ml','ta','en')),
  created_at timestamptz not null default now()
);

create table sellers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  name text not null,
  phone text,
  area text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
create index idx_sellers_shop_id on sellers (shop_id);

create table lotteries (            -- master list, editable by owner
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  name text not null,              -- e.g. 'Win-Win'
  code text,                       -- e.g. 'W'
  default_weekday int,             -- 1=Mon..7=Sun, null for bumper
  default_ticket_price numeric(10,2),
  is_bumper boolean not null default false
);
create index idx_lotteries_shop_id on lotteries (shop_id);

create table prize_templates (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  name text not null
);
create index idx_prize_templates_shop_id on prize_templates (shop_id);

create table prize_template_tiers (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references prize_templates(id) on delete cascade,
  tier_order int not null,           -- 1 = highest
  label text not null,               -- '1st Prize', 'Consolation', '4th Prize'
  amount numeric(12,2) not null,
  match_type text not null check (match_type in ('FULL','CONSOLATION','LAST_4','LAST_3'))
);
create index idx_prize_template_tiers_template_id on prize_template_tiers (template_id);

create table draws (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  lottery_id uuid not null references lotteries(id),
  draw_number text,                  -- e.g. 'W-845'
  draw_date date not null,
  draw_time time not null default '15:00',
  ticket_price numeric(10,2) not null,
  status text not null default 'UPCOMING' check (status in ('UPCOMING','RESULT_ENTERED','CLOSED')),
  closed_at timestamptz,             -- set by close-draw; used by the cleanup job (§6.6)
  created_at timestamptz not null default now()
);
create index idx_draws_shop_date on draws (shop_id, draw_date);

create table draw_prize_tiers (      -- copied from a template when draw is created, then editable
  id uuid primary key default gen_random_uuid(),
  draw_id uuid not null references draws(id) on delete cascade,
  tier_order int not null,
  label text not null,
  amount numeric(12,2) not null,
  match_type text not null check (match_type in ('FULL','CONSOLATION','LAST_4','LAST_3'))
);
create index idx_draw_prize_tiers_draw_id on draw_prize_tiers (draw_id);

create table stock_batches (         -- one purchase entry = one range
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  draw_id uuid not null references draws(id) on delete cascade,
  series text not null,
  start_number char(6) not null,
  end_number char(6) not null,
  quantity int not null,
  cost_per_ticket numeric(10,2),     -- what owner paid (after discount)
  created_at timestamptz not null default now()
);
create index idx_stock_batches_shop_draw on stock_batches (shop_id, draw_id);

create table tickets (               -- expanded from batches, one row per physical ticket
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  draw_id uuid not null references draws(id) on delete cascade,
  batch_id uuid not null references stock_batches(id) on delete cascade,
  series text not null,
  number char(6) not null,
  status text not null default 'IN_STOCK'
    check (status in ('IN_STOCK','WITH_SELLER','SOLD_COUNTER','SOLD_BY_SELLER','RETURNED_UNSOLD')),
  seller_id uuid references sellers(id),
  updated_at timestamptz not null default now(),
  unique (draw_id, series, number)
);
create index idx_tickets_draw_number on tickets (draw_id, number);
create index idx_tickets_draw_last4 on tickets (draw_id, right(number, 4));
create index idx_tickets_shop_draw_status on tickets (shop_id, draw_id, status);

create table ledger_entries (        -- seller khata. positive = seller owes more, negative = seller paid / credit
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  seller_id uuid not null references sellers(id) on delete cascade,
  draw_id uuid references draws(id) on delete set null,
  type text not null check (type in ('ISSUE','RETURN','PAYMENT','PRIZE_PAID_BY_SELLER','ADJUSTMENT')),
  amount numeric(12,2) not null,
  ticket_count int,
  payment_method text check (payment_method in ('CASH','UPI','OTHER')),
  note text,
  created_at timestamptz not null default now()
);
create index idx_ledger_entries_shop_seller on ledger_entries (shop_id, seller_id);

create table draw_results (          -- winning entries entered by the owner
  id uuid primary key default gen_random_uuid(),
  draw_id uuid not null references draws(id) on delete cascade,
  tier_id uuid not null references draw_prize_tiers(id) on delete cascade,
  series text,                       -- required for FULL/CONSOLATION, null for LAST_4/LAST_3
  number text not null               -- 6 digits for FULL/CONSOLATION, 4 or 3 digits for LAST_n
);
create index idx_draw_results_draw_id on draw_results (draw_id);

create table wins (                  -- winning tickets; keeps its own copy of ticket info so it survives ticket cleanup (§6.6)
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references shops(id) on delete cascade,
  draw_id uuid not null references draws(id) on delete cascade,
  ticket_id uuid references tickets(id) on delete set null,
  series text not null,
  number char(6) not null,
  seller_id uuid references sellers(id) on delete set null,
  sold_by text not null check (sold_by in ('COUNTER','SELLER','UNSOLD')),
  tier_id uuid not null references draw_prize_tiers(id),
  amount numeric(12,2) not null,
  claim_status text not null default 'UNCLAIMED'
    check (claim_status in ('UNCLAIMED','PAID_TO_CUSTOMER','CLAIMED_FROM_OFFICE','UNSOLD_WIN')),
  unique (draw_id, series, number)
);
create index idx_wins_shop_draw on wins (shop_id, draw_id);

create table draw_summaries (        -- permanent per-draw numbers for reports, written when a draw is closed
  draw_id uuid primary key references draws(id) on delete cascade,
  shop_id uuid not null references shops(id) on delete cascade,
  total_tickets int not null,
  sold_counter int not null,
  sold_by_sellers int not null,
  returned_unsold int not null,
  total_cost numeric(12,2) not null,
  total_sales numeric(12,2) not null,
  total_prizes numeric(12,2) not null,
  per_seller jsonb not null default '[]'   -- [{seller_id, issued, returned, sold, amount}]
);

-- ============================================================================
-- 2. ROW LEVEL SECURITY (§6.4)
-- ============================================================================

alter table shops enable row level security;
alter table sellers enable row level security;
alter table lotteries enable row level security;
alter table prize_templates enable row level security;
alter table prize_template_tiers enable row level security;
alter table draws enable row level security;
alter table draw_prize_tiers enable row level security;
alter table stock_batches enable row level security;
alter table tickets enable row level security;
alter table ledger_entries enable row level security;
alter table draw_results enable row level security;
alter table wins enable row level security;
alter table draw_summaries enable row level security;

-- shops: direct owner check
create policy "owner access" on shops
  for all
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- Direct shop_id tables
create policy "owner access" on sellers
  for all
  using (shop_id in (select id from shops where owner_id = auth.uid()))
  with check (shop_id in (select id from shops where owner_id = auth.uid()));

create policy "owner access" on lotteries
  for all
  using (shop_id in (select id from shops where owner_id = auth.uid()))
  with check (shop_id in (select id from shops where owner_id = auth.uid()));

create policy "owner access" on prize_templates
  for all
  using (shop_id in (select id from shops where owner_id = auth.uid()))
  with check (shop_id in (select id from shops where owner_id = auth.uid()));

create policy "owner access" on draws
  for all
  using (shop_id in (select id from shops where owner_id = auth.uid()))
  with check (shop_id in (select id from shops where owner_id = auth.uid()));

create policy "owner access" on stock_batches
  for all
  using (shop_id in (select id from shops where owner_id = auth.uid()))
  with check (shop_id in (select id from shops where owner_id = auth.uid()));

create policy "owner access" on tickets
  for all
  using (shop_id in (select id from shops where owner_id = auth.uid()))
  with check (shop_id in (select id from shops where owner_id = auth.uid()));

create policy "owner access" on ledger_entries
  for all
  using (shop_id in (select id from shops where owner_id = auth.uid()))
  with check (shop_id in (select id from shops where owner_id = auth.uid()));

create policy "owner access" on wins
  for all
  using (shop_id in (select id from shops where owner_id = auth.uid()))
  with check (shop_id in (select id from shops where owner_id = auth.uid()));

create policy "owner access" on draw_summaries
  for all
  using (shop_id in (select id from shops where owner_id = auth.uid()))
  with check (shop_id in (select id from shops where owner_id = auth.uid()));

-- Child tables without shop_id
create policy "owner access" on prize_template_tiers
  for all
  using (
    exists (
      select 1 from prize_templates pt
      join shops s on s.id = pt.shop_id
      where pt.id = template_id and s.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from prize_templates pt
      join shops s on s.id = pt.shop_id
      where pt.id = template_id and s.owner_id = auth.uid()
    )
  );

create policy "owner access" on draw_prize_tiers
  for all
  using (
    exists (
      select 1 from draws d
      join shops s on s.id = d.shop_id
      where d.id = draw_id and s.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from draws d
      join shops s on s.id = d.shop_id
      where d.id = draw_id and s.owner_id = auth.uid()
    )
  );

create policy "owner access" on draw_results
  for all
  using (
    exists (
      select 1 from draws d
      join shops s on s.id = d.shop_id
      where d.id = draw_id and s.owner_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from draws d
      join shops s on s.id = d.shop_id
      where d.id = draw_id and s.owner_id = auth.uid()
    )
  );

-- ============================================================================
-- 3. RPC FUNCTIONS — PHASE 1 (§6.5)
-- ============================================================================

create or replace function create_shop_with_defaults(
  p_name text,
  p_owner_name text,
  p_district text,
  p_agent_code text default null,
  p_language text default 'ml',
  p_phone text default null
)
returns uuid
language plpgsql
security invoker
as $$
declare
  v_user_id uuid := auth.uid();
  v_shop_id uuid;
  v_template_id uuid;
begin
  if v_user_id is null then
    raise exception 'UNAUTHORIZED' using detail = 'Authentication required to create a shop.';
  end if;

  if exists (select 1 from shops where owner_id = v_user_id) then
    select id into v_shop_id from shops where owner_id = v_user_id;
    return v_shop_id;
  end if;

  insert into shops (owner_id, name, owner_name, phone, district, agent_code, default_language)
  values (
    v_user_id,
    trim(p_name),
    nullif(trim(coalesce(p_owner_name, '')), ''),
    nullif(trim(coalesce(p_phone, '')), ''),
    nullif(trim(coalesce(p_district, '')), ''),
    nullif(trim(coalesce(p_agent_code, '')), ''),
    coalesce(p_language, 'ml')
  )
  returning id into v_shop_id;

  -- Seed editable default weekly lotteries + 1 bumper placeholder
  insert into lotteries (shop_id, name, code, default_weekday, default_ticket_price, is_bumper)
  values
    (v_shop_id, 'Win-Win',       'W',  1, 40.00, false),
    (v_shop_id, 'Sthree Sakthi', 'SS', 2, 40.00, false),
    (v_shop_id, 'Fifty-Fifty',   'FF', 3, 50.00, false),
    (v_shop_id, 'Karunya Plus',  'KN', 4, 40.00, false),
    (v_shop_id, 'Nirmal',        'NR', 5, 40.00, false),
    (v_shop_id, 'Karunya',       'KR', 6, 40.00, false),
    (v_shop_id, 'Akshaya',       'AK', 7, 40.00, false),
    (v_shop_id, 'Seasonal Bumper', 'BR', null, 250.00, true);

  -- Seed one editable default prize structure template
  insert into prize_templates (shop_id, name)
  values (v_shop_id, 'Regular Weekly Template')
  returning id into v_template_id;

  insert into prize_template_tiers (template_id, tier_order, label, amount, match_type)
  values
    (v_template_id, 1, '1st Prize',         7500000.00, 'FULL'),
    (v_template_id, 2, 'Consolation Prize',    8000.00, 'CONSOLATION'),
    (v_template_id, 3, '2nd Prize',          500000.00, 'FULL'),
    (v_template_id, 4, '3rd Prize',          100000.00, 'FULL'),
    (v_template_id, 5, '4th Prize',            5000.00, 'LAST_4'),
    (v_template_id, 6, '5th Prize',            2000.00, 'LAST_4'),
    (v_template_id, 7, '6th Prize',            1000.00, 'LAST_4'),
    (v_template_id, 8, '7th Prize',             500.00, 'LAST_4'),
    (v_template_id, 9, '8th Prize',             100.00, 'LAST_4');

  return v_shop_id;
end;
$$;
