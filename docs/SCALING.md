# Storage Monitoring & Scaling Guide (`SCALING.md`)

## 1. How 30-Day Ticket Cleanup Keeps You Within the 500 MB Free Tier

Each physical lottery ticket is stored as one row in `public.tickets` (~180–250 bytes including indexes). A busy shop handling 3,000 tickets/day generates ~90,000 ticket rows/month (~20 MB/month).

To keep database storage flat indefinitely without losing financial or prize history:
- Migration `20261112000006_phase6_ops_and_account_delete.sql` defines `public.cleanup_old_closed_draws()` and schedules it daily at **03:00 AM IST (`30 21 * * *` UTC)** via `pg_cron`.
- Any draw with `status = 'CLOSED'` and `closed_at < now() - interval '30 days'` has its expanded `tickets` and `stock_batches` rows permanently deleted.
- **Preserved forever:**
  - `wins` (`wins.ticket_id` is `ON DELETE SET NULL`, and `wins` stores its own `series`, `number`, `seller_id`, `sold_by`, `amount`, and `claim_status`).
  - `ledger_entries` (append-only seller khata / balance history).
  - `draw_summaries` (permanent per-draw ticket counts, cost, sales, prizes, and per-seller breakdown used by `get_reports_summary()`).

---

## 2. Monitoring Storage Usage (`public.storage_usage`)

Run this query in the **Supabase SQL Editor** at any time to check per-table row counts, disk size, and percentage of the 500 MB Supabase Free Tier limit:

```sql
select
  table_name,
  estimated_rows,
  total_size_pretty,
  pct_of_500mb_limit
from public.storage_usage;
```

To check total usage across all application tables:

```sql
select
  pg_size_pretty(sum(total_bytes)) as total_app_size,
  round(sum(pct_of_500mb_limit), 2) as total_pct_of_500mb
from public.storage_usage;
```

### Alert Thresholds
- **< 50% (< 250 MB):** Healthy normal operation.
- **50% – 75% (250 MB – 375 MB):** Check if old draws are left in `RESULT_ENTERED` or `UPCOMING` status without being closed (`close_draw` sets `closed_at`, which starts the 30-day retention clock).
- **> 80% (> 400 MB):** Close old draws and run `select public.cleanup_old_closed_draws();` followed by `VACUUM ANALYZE public.tickets, public.stock_batches;`, or upgrade to Supabase Pro.

---

## 3. Manual Cleanup & Maintenance Commands

If `pg_cron` was paused or you want to reclaim space immediately after closing old draws:

```sql
-- 1. Run the 30-day closed-draw ticket & batch cleanup manually:
select public.cleanup_old_closed_draws();

-- 2. Reclaim dead tuple space and refresh planner statistics:
vacuum analyze public.tickets;
vacuum analyze public.stock_batches;
```

---

## 4. When to Upgrade to Supabase Pro

Upgrade from the Free Tier to **Supabase Pro** (8 GB disk included + auto-scaling storage, daily automated point-in-time backups, no 7-day inactivity pause) when:
1. Total database size exceeds **350 MB** despite closing draws regularly, or
2. Multiple shops / high-volume wholesale agencies (> 15,000 tickets/day) share the same Supabase project.
