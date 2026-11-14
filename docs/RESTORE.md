# Database Backup & Restore Guide (`RESTORE.md`)

## 1. Required GitHub Repository Secrets

To enable `.github/workflows/weekly-backup.yml` (which runs automatically every Sunday at `02:00 UTC` / `07:30 AM IST`, or manually via **Actions → Weekly Encrypted Database Backup → Run workflow**), add these two secrets under **GitHub Repository → Settings → Secrets and variables → Actions → New repository secret**:

| Secret Name | Value |
|---|---|
| `SUPABASE_DB_URL` | Your Supabase Postgres connection string (Session Pooler IPv4 URI from **Supabase Dashboard → Connect → Session pooler**, e.g. `postgresql://postgres.<project-ref>:<db-password>@aws-0-ap-south-1.pooler.supabase.com:5432/postgres`) |
| `BACKUP_PASSPHRASE` | A strong passphrase (32+ characters) used by `gpg --symmetric --cipher-algo AES256` to encrypt every `.sql.gz.gpg` dump before it is uploaded to GitHub Actions artifacts. Store this passphrase in your password manager alongside your keystore credentials. |

---

## 2. How to Download & Decrypt a Backup

1. Go to **GitHub Repository → Actions → Weekly Encrypted Database Backup**.
2. Click the latest successful workflow run and download the `luckyledger-db-backup-<run_number>` artifact `.zip`.
3. Extract the `.zip` to obtain `luckyledger_<TIMESTAMP>.sql.gz.gpg`.
4. Decrypt and decompress the dump using `gpg` and `gunzip`:

```bash
# 1. Decrypt the AES-256 GPG file (prompts for BACKUP_PASSPHRASE):
gpg --decrypt --output luckyledger_restore.sql.gz luckyledger_<TIMESTAMP>.sql.gz.gpg

# 2. Decompress the gzipped SQL dump:
gunzip luckyledger_restore.sql.gz
# Produces: luckyledger_restore.sql
```

*(On Windows with Git for Windows installed, both `gpg` and `gunzip` are available in Git Bash.)*

---

## 3. How to Restore to a Supabase Database

### Option A: Restore into an existing project (overwrites `public` schema objects)

Because `pg_dump` is run with `--schema=public --clean --if-exists`, you can restore directly over the `public` schema:

```bash
psql "postgresql://postgres.<project-ref>:<db-password>@aws-0-ap-south-1.pooler.supabase.com:5432/postgres" \
  --single-transaction \
  --file=luckyledger_restore.sql
```

### Option B: Restore into a brand-new Supabase project

1. Apply all tracked migrations first so extensions, RLS policies, and triggers are initialized:
   ```bash
   npx supabase link --project-ref <new-project-ref>
   npx supabase db push
   ```
2. Recreate or migrate `auth.users` rows if restoring across projects (since `shops.owner_id` references `auth.users(id)`).
3. Run the `psql` restore command from Option A.
4. Verify row counts and table sizes:
   ```sql
   select * from public.storage_usage;
   ```
