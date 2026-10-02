# WASA Bhakkar: Vehicle Service Challan & Payment System (Demo)

A working demo for **WASA Bhakkar**. The office creates a challan in 3 taps (WHO → WHERE → WHAT). The customer gets it on WhatsApp with a QR code. The driver completes the job in an Urdu Android app. Payment is **online only**: no role can mark a challan Paid, and only the payment provider (simulated here) can.

- `apps/office`: Flutter Windows desktop + Web app for Admin, Office Operator and Officer (read-only)
- `apps/driver`: Flutter Android app for drivers (Urdu first)
- `packages/core`: models, business rules, Supabase repositories
- `packages/ui`: theme, Urdu/English strings, shared widgets
- `supabase/`: migrations (schema, RLS, functions), seed, tests

See **PLAN.md** for the database design and build phases, and **DECISIONS.md** for the choices made.

> Status: **Phase 1 done** (scaffold, theme, schema + RLS + seed, sign-in with role-based routing). The full Windows set-up guide, demo script and integration notes are written in Phase 7.

## Demo logins (password for all: `Wasa@1234`)
| Username | Role | Name |
|---|---|---|
| `admin` | Admin | Muhammad Asif |
| `operator1`, `operator2` | Office Operator | Rabia Noor, Imran Khalid |
| `officer` | Officer (read-only) | Tariq Mehmood |
| `driver1` … `driver6` | Driver (driver app) | Ghulam Abbas, Muhammad Riaz, Allah Ditta, Zafar Iqbal, Nadeem Akhtar, Shahid Hussain |

The apps add `@wasabhakkar.demo` to the username (Supabase Auth uses e-mail addresses).

## Quick start (Windows PC)
Needs: Node.js LTS, Flutter (stable), and Visual Studio 2022 with "Desktop development with C++" (for the Windows build).

1. **Database + checks, in one script** (from this folder, in PowerShell):
   ```
   powershell -ExecutionPolicy Bypass -File tool\setup_supabase.ps1
   ```
   It writes `apps\office\env.json` and `apps\driver\env.json` (git-ignored), logs in to Supabase (browser), links the project (asks for the **database password**), runs `supabase db push --include-seed`, runs the SQL permission tests on the real project, and signs in as operator1, driver1 and admin to check what each can see, and that none of them can mark Paid.
   For a different project, pass `-ProjectRef`, `-Url` and `-PublishableKey`. Use `-SkipPush` to re-run only the checks.
2. In the Supabase dashboard, under Authentication → Sign In / Providers, turn **off** "Allow new users to sign up".
3. **Run:**
   ```
   flutter pub get
   cd apps\office
   flutter run -d windows --dart-define-from-file=env.json
   ```
   Sign in as `operator1` / `Wasa@1234`. You should land on the Dashboard.

The apps read their keys from `env.json` (Flutter's `--dart-define-from-file`), not from a `.env` file. Only the **publishable** key goes there, never the service key.

## Checks
```
flutter analyze                       # whole workspace
cd packages/core && flutter test      # tariff, numbering, status rules, QR signing
cd apps/office && flutter test        # role routing + login widget test
cd apps/driver && flutter test        # driver routing + Urdu login widget test
tool/db_test.sh                       # migrations + seed + RLS tests on a local PostgreSQL
```
