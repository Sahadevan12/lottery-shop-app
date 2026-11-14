# Release Signing, CI Builds & Crashlytics Setup (`RELEASE_SIGNING_AND_CRASHLYTICS.md`)

## 1. Generate Your Upload Keystore (Outside the Repo)

Run this exact command in PowerShell on your machine to create a 2048-bit RSA upload keystore **outside** the repository (so it can never be committed):

```powershell
# 1. Create a private keys directory outside the repo:
New-Item -ItemType Directory -Force -Path "$HOME\.keys"

# 2. Generate the upload keystore (valid for ~27 years / 10,000 days):
keytool -genkeypair -v `
  -keystore "$HOME\.keys\luckyledger-upload.jks" `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

When prompted by `keytool`:
- Enter a strong **keystore password** and **key password** (you can press Enter to use the same password for both).
- Fill in your name / organization / state (`Kerala`) / country code (`IN`).

---

## 2. Create `android/key.properties` Locally (Git-Ignored)

Create `s:\company project\Lottery\android\key.properties` (already ignored by `.gitignore`) using this template:

```properties
storePassword=<YOUR_KEYSTORE_PASSWORD>
keyPassword=<YOUR_KEY_PASSWORD>
keyAlias=upload
storeFile=C:/Users/Saha Devan/.keys/luckyledger-upload.jks
```

*(Note: Use forward slashes `/` in `storeFile` on Windows so Gradle parses the path cleanly.)*

---

## 3. What to Back Up & Play App Signing Note

### What to Back Up (Store in 2 Separate Secure Locations)
Back up all 3 items in your password manager (e.g. Bitwarden / 1Password) **and** on an offline USB drive:
1. The keystore file itself: `C:\Users\Saha Devan\.keys\luckyledger-upload.jks`
2. `storePassword`, `keyPassword`, and `keyAlias` (`upload`)
3. Your `BACKUP_PASSPHRASE` (used for weekly encrypted Supabase database backups)

### Google Play App Signing
- When creating the app in **Google Play Console** (Category: **Business**), enable **Play App Signing** (mandatory for new apps using `.aab`).
- Google holds the **App Signing Key** used to sign APKs delivered to users, while your `luckyledger-upload.jks` acts as the **Upload Key** used to sign `.aab` bundles uploaded to Play Console.
- If your upload key is ever lost or compromised, you can request an **Upload Key Reset** in Play Console without losing your app listing or existing user installs.

---

## 4. GitHub Secrets for `.github/workflows/build-apk.yml`

To build signed split-per-ABI APKs and a signed `.aab` in the cloud via **GitHub Actions → Build Release APKs & Play Store AAB → Run workflow**, add these secrets under **Repository → Settings → Secrets and variables → Actions**:

| Secret Name | How to Get Value |
|---|---|
| `SUPABASE_URL` | Your production Supabase project URL (`https://csmyxwilpriumunmsgzz.supabase.co`) |
| `SUPABASE_ANON_KEY` | Your production Supabase `anon` public key |
| `UPLOAD_KEYSTORE_BASE64` | Base64-encoded upload keystore. In PowerShell, run:<br>`[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\.keys\luckyledger-upload.jks")) \| Set-Clipboard` |
| `KEYSTORE_STORE_PASSWORD` | Your keystore `storePassword` |
| `KEYSTORE_KEY_PASSWORD` | Your key `keyPassword` |
| `KEYSTORE_KEY_ALIAS` | `upload` |

---

## 5. Firebase Crashlytics Setup

`lib/core/crash/crash_reporter.dart` and `lib/main.dart` are wired to report uncaught Flutter framework errors (`FlutterError.onError`) and asynchronous platform errors (`PlatformDispatcher.instance.onError`) to Firebase Crashlytics in release builds, while gracefully skipping initialization until your Firebase config file is added.

### Steps to Enable Crashlytics in Firebase Console
1. Go to [Firebase Console](https://console.firebase.google.com/) → **Create a project** (e.g., `luckyledger-prod`).
2. Add an **Android app** with package name:
   ```text
   app.luckyledger.lucky_ledger
   ```
3. Download `google-services.json` and place it at:
   ```text
   android/app/google-services.json
   ```
   *(This path is git-ignored so Firebase API keys are not committed to a public repo.)*
4. In Firebase Console → **Run → Crashlytics**, click **Enable Crashlytics**.
