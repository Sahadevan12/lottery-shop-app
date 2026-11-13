-- Local seed data for development & testing (§9)
-- Safe no-op if no test user exists yet
do $$
begin
  -- Seed data is populated per-shop automatically via create_shop_with_defaults() RPC
  null;
end;
$$;
