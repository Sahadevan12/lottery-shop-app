# MASTER PROMPT — Kerala Lottery Shop Manager App

## 0. Your role & how to work

You are a senior Flutter engineer and product designer building a production-quality mobile app for Kerala State Lottery retailers and agents.

Working rules (follow strictly):
1. **Plan before code.** For every phase, first produce an implementation plan + task list. Wait for my approval before writing code.
2. **One phase at a time.** Never jump ahead. At the end of each phase, stop, summarize what was built, list how to test it, and wait.
3. **Do not invent features** outside this spec. If something is unclear, ask me.
4. **Keep the app runnable after every task.** Run `flutter analyze` and fix all errors/warnings before saying a task is done.
5. **Write unit tests** for all business logic (prize matching, ledger balances, stock counts). These must pass.
6. **Never hard-code secrets.** Supabase URL + anon key go in `--dart-define`; the `service_role` key is never in the app or the repo.
7. Small, focused files. No file over ~300 lines. Feature-first folder structure (see §9).
8. All user-facing strings go through localization (ARB files). No hard-coded UI text.
9. Use the design system in §4 for EVERY screen. No default Material look, no random colors, no random paddings.

---

## 1. Product overview

**Working name:** `LuckyLedger` (placeholder — keep the name in one constant so it can change).

**What it is:** A back-office app for lottery shop owners and agents in Kerala to manage their **physical** Kerala State Lottery ticket business in one place:
- Stock of tickets bought from the lottery office
- Tickets given to sub-sellers (walking sellers) on credit
- Money owed by each seller (khata / kadam ledger)
- Entering draw results and **automatically finding every winning ticket** in their stock
- Daily reports and WhatsApp-shareable winner posters

**Who uses it:**
- **Owner** (shop owner / agent) — full access. This is the only role in the MVP.
- (Later phase) **Seller** — read-only view of their own tickets and balance.

**Core promise:** "After the 3 PM draw, know in 10 seconds which of your tickets won, who sold them, and how much money each seller owes you."

---

## 2. Legal & compliance guardrails (NON-NEGOTIABLE)

- This app is a **business management tool only**. It must NEVER sell, book, reserve, or take payment for lottery tickets online. Kerala lottery tickets are sold only as physical tickets by authorised agents/sellers.
- NO number-guessing, "3-digit", "ezhuthu", prediction, betting, or wallet features of any kind.
- Show this disclaimer on the onboarding screen and in Settings → About:
  > "This app is an independent business tool for lottery retailers. It is not affiliated with the Kerala State Lotteries Department or any government body. It does not sell lottery tickets. Always verify results with the official Kerala State Lotteries website."
- Results entered or fetched in the app must show a "Verify with official result" note.
- Do not use any government logo, emblem, or the name "Kerala State Lotteries" as branding.

---

## 3. Tech stack

| Layer | Choice |
|---|---|
| App | Flutter (latest stable), Dart 3, Android first (min SDK 23), iOS-ready |
| State | `flutter_riverpod` (+ `riverpod_annotation` codegen) |
| Navigation | `go_router` |
| Backend | Supabase (PostgreSQL, Auth, Row Level Security, RPC functions, `pg_cron`) via `supabase_flutter`; Supabase CLI for migrations |
| Local cache | `drift` (SQLite) for offline reads + a pending-writes queue |
| Models | `freezed` + `json_serializable` |
| i18n | `flutter_localizations` + `intl`, ARB files: `en`, `ml` (Malayalam), `ta` (Tamil) |
| Fonts | `Inter` (Latin UI), `Noto Sans Malayalam`, `Noto Sans Tamil`, `JetBrains Mono` (ticket numbers only) — bundled as assets, not fetched at runtime |
| Animation | `flutter_animate`, `lottie` (only for the win celebration) |
| Sharing | `share_plus`, `screenshot` (widget → PNG) |
| PDF | `pdf`, `printing` |
| Push | `firebase_messaging` (Phase 2) |
| Crashes | `firebase_crashlytics` |
| Haptics | `HapticFeedback` (built-in) |

---

## 4. Design system — PREMIUM UI/UX

- **Design direction:** "Calm fintech with a touch of gold."
- **Color tokens:** Defined in `AppColors` `ThemeExtension`. Never use raw hex in widgets.
- **Typography:** Base 16sp, never below 13sp. All numbers use `FontFeature.tabularFigures()`. Ticket numbers in `JetBrains Mono`. Money in Indian format (`₹1,23,450`).
- **Spacing & shape:** 4-pt grid (`xs 4, sm 8, md 12, lg 16, xl 24, xxl 32`). Screen horizontal padding 20. Radius: cards 20, buttons 14, inputs 14, chips 999, bottom sheets 28. Touch targets ≥ 48x48dp, primary buttons 56dp tall.
