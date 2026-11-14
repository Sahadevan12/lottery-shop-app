# Database Backup & Restore Guide (`RESTORE.md`)

## 1. Required GitHub Repository Secrets

To enable `.github/workflows/weekly-backup.yml` (which runs automatically every Sunday at `02:00 UTC` / `07:30 AM IST`, or manually via **Actions → Weekly Encrypted Database Backup → Run workflow**), add these two secrets under **GitHub Repository → Settings → Secrets and variables → Actions → New repository secret**:

| Secret Name | Value |
|---|---|
| `SUPABASE_DB_URL` | Your Supabase Postgres connection string (Session Pooler IPv4 URI from **Supabase Dashboard → Connect → Session pooler**, e.g. `postgresql://postgres.<project-ref>:<db-password>@aws-0-ap-south-1.pooler.supabase.com:5432/postgres`) |
| `BACKUP_PASSPHRASE` | A strong passphrase (32+ characters) used by `gpg --symmetric --cipher-algo AES256` to encrypt every `.tar.gz.gpg` archive before it is uploaded to GitHub Actions artifacts. Store this passphrase in your password manager alongside your keystore credentials. |

### What Each Backup Archive Contains
Each encrypted archive (`luckyledger_backup_<TIMESTAMP>.tar.gz.gpg`) contains two SQL dumps in exact restore order:
1. `01_auth_data.sql` — Data dump of `auth.users` and `auth.identities` (`--data-only --column-inserts --on-conflict-do-nothing`), preserving user logins (phone + PIN hashed credentials) and `auth.users.id` UUIDs.
2. `02_public.sql` — Complete `public` schema and data dump (`--schema=public --clean --if-exists`), including `shops` (linked via `owner_id -> auth.users.id`), `sellers`, `draws`, `stock_batches`, `tickets`, `ledger_entries`, `wins`, `draw_summaries`, views, triggers, and RPCs.

---

## 2. How to Download, Decrypt & Extract a Backup

1. Go to **GitHub Repository → Actions → Weekly Encrypted Database Backup**.
2. Click the latest successful workflow run and download the `luckyledger-db-backup-<run_number>` artifact `.zip`.
3. Extract the `.zip` to obtain `luckyledger_backup_<TIMESTAMP>.tar.gz.gpg`.
4. Decrypt and extract the archive using `gpg` and `tar`:

```bash
# 1. Decrypt the AES-256 GPG archive (prompts for BACKUP_PASSPHRASE):
gpg --decrypt --output luckyledger_backup.tar.gz luckyledger_backup_<TIMESTAMP>.tar.gz.gpg

# 2. Extract the tar.gz archive:
tar -xzf luckyledger_backup.tar.gz

# Produces directory: luckyledger_backup_<TIMESTAMP>/
#   ├── 01_auth_data.sql
#   └── 02_public.sql
```

*(On Windows with Git for Windows installed, both `gpg` and `tar` are available in Git Bash.)*

---

## 3. Restore Order (`auth` First, Then `public`)

Always restore `01_auth_data.sql` **before** `02_public.sql` so that `auth.users` rows exist when `public.shops.owner_id` foreign keys are created and populated.

### Step 1: Prepare Target Project (if restoring into a brand-new Supabase project)
If restoring into a newly created Supabase project, first push the tracked migrations so extensions and base schemas are initialized:

```bash
npx supabase link --project-ref <target-project-ref>
npx supabase db push --remote
```

### Step 2: Restore `01_auth_data.sql` (`auth.users` & `auth.identities`)

```bash
DB_URL="postgresql://postgres.<project-ref>:<db-password>@aws-0-ap-south-1.pooler.supabase.com:5432/postgres"

psql "$DB_URL" \
  --single-transaction \
  --file="luckyledger_backup_<TIMESTAMP>/01_auth_data.sql"
```

### Step 3: Restore `02_public.sql` (`public` schema & shop data)

```bash
psql "$DB_URL" \
  --single-transaction \
  --file="luckyledger_backup_<TIMESTAMP>/02_public.sql"
```

---

## 4. How to Verify the Restore

Run the following verification queries in `psql` or the **Supabase SQL Editor** after restoring:

```sql
-- 1. Verify auth users and identities were restored and match shops.owner_id:
select
  (select count(*) from auth.users) as auth_users_count,
  (select count(*) from auth.identities) as auth_identities_count,
  (select count(*) from public.shops) as shops_count,
  (select count(*) from public.shops s join auth.users u on u.id = s.owner_id) as linked_shops_count;
-- Expected: shops_count = linked_shops_count (every shop has a valid auth.users owner).

-- 2. Verify ledger balances reconcile cleanly with ledger_entries:
select
  s.id as seller_id,
  s.name,
  coalesce(sum(le.amount), 0) as ledger_balance
from public.sellers s
left join public.ledger_entries le on le.seller_id = s.id
group by s.id, s.name
order by s.name;

-- 3. Verify table row counts and disk usage across all 13 public tables:
select * from public.storage_usage;
```
