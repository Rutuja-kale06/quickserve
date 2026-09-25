# Supabase setup (QuickServe)

Backend: PostgreSQL database, Auth, Row Level Security, RPCs, triggers and audit
logging. Everything is defined in SQL so it can be applied from the Supabase
SQL editor (or `supabase db push` if you adopt the CLI).

## Apply order

1. Create a project at [supabase.com](https://supabase.com) (free tier).
2. Open **SQL Editor → New query**.
3. Run `001_schema.sql` — creates enums, tables, indexes, triggers, RPCs, RLS
   policies and seeds the four services.
4. Run `002_seed.sql` — creates the demo test accounts (idempotent).
5. **Authentication**: enable *Email* provider (Settings → Authentication →
   Providers). New sign-ups are automatically customers via the
   `handle_new_user()` trigger on `auth.users`.

## Test credentials (from 002_seed.sql)

| Email                   | Role     | Password        |
| ----------------------- | -------- | --------------- |
| customer@quickserve.demo | customer | QuickServe@123 |
| agent@quickserve.demo    | agent    | QuickServe@123 |
| admin@quickserve.demo    | admin    | QuickServe@123 |

Change these passwords before sharing the repository (Settings → Authentication
→ Users).

## Wire the clients

- `mobile/lib/config.dart` → `supabaseUrl` + `supabaseAnonKey` (project API
  settings → **anon/publishable** key — never the service-role key).
- `admin-web/.env` → `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`
  (copy from `.env.example`).

## Compatibility notes

- `002_seed.sql` is **version-safe** for modern Supabase: it omits the now
  generated `auth.users.confirmed_at` column and inserts `auth.identities`
  without a hard-coded unique-constraint name, so it runs unchanged on older
  and newer projects and can be re-run safely.
- If a freshly seeded account cannot sign in on a particular project
  (GoTrue answers `Database error querying schema` / `Database error loading
  user`), the manually inserted auth rows are incompatible with that project's
  Auth build. Delete those auth users (e.g. `delete from auth.users where
  email in (...)` in the SQL editor) and recreate them via
  **Authentication → Users → Add user** (email + password) or the admin API —
  the `handle_new_user()` trigger then fills in their profile automatically.

## Design notes (brief)

- Security model (RLS matrix, roles, audit) → `docs/SECURITY.md`.
- Data model, relationships, indexes → `docs/ARCHITECTURE.md`.
- RLS regression tests → `tests/rls-authz.mjs` (run after wiring a live project).