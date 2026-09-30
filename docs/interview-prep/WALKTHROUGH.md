# QuickServe — Live Walkthrough Script (~15 min)

> Use this to drill the order and the words. Keep a **shared screen** and open the
> repo on GitHub so you can navigate quickly: `github.com/Rutuja-kale06/quickserve`.

## 0. Framing (30 s)

> "I built QuickServe end to end — a Flutter mobile app, a React admin portal, and a
> Supabase back end. The most important engineering decision was putting **security
> and business rules in the database**, and I'll show you the code and then a live demo."

---

## 1. CODE WALKTHROUGH (~6 min)

### 1a. Repo layout (30 s)
Show top-level: `mobile/`, `admin-web/`, `supabase/`, `tests/`, `docs/`.

### 1b. Mobile app — `mobile/lib/` (~2 min)
- `lib/config.dart` → Supabase URL + **publishable** key (no secrets in the app).
- Flow: `screens/auth_screen.dart` (login/register) → `home_screen.dart` → `my_requests_screen`.dart / `create_request_screen.dart` / `services_screen.dart` / `request_details_screen.dart` / `profile_screen.dart`.
- **Thin service layer** `services/supabase_service.dart` wraps everything:
  - `createRequest()` → calls RPC `create_request` (`supabase_service.dart:36`)
  - `updateRequestStatus()` → RPC `update_request_status` (`:59`)
  - `logEvent()` → RPC `write_audit` (`:83`)
  - `getRequestHistory()` → reads `request_status_history` (`:71`)
- Point: the UI never decides authorization — it just calls the DB.

### 1c. Admin portal — `admin-web/src/` (~1.5 min)
- `App.jsx` layout → `components/Login.jsx`, `Dashboard.jsx`, `RequestsPanel.jsx`, `RequestDetailsModal.jsx`, `People.jsx`, `AuditLog.jsx`.
- `api.js` = single data-access point; `utils.js` = tested search/filter logic.
- `utils.test.js` → unit tests (e.g. filter by customer/status).
- Note: a failed admin sign-in (or agent trying the portal) writes `AUTHORIZATION_FAILED` to audit.

### 1d. Backend — `supabase/001_schema.sql` (~2 min)
Show these, in order (all in the same file):

| Piece | Line | One-liner you say |
|---|---|---|
| enum `user_role` | 26 | roles are a DB type |
| `generate_request_code()` | 109 | `REQ-<year>-<sequence>` via trigger |
| `handle_new_user()` | 154 | profile auto-created on signup, `on conflict do nothing` |
| `current_user_role()` | 182 | SECURITY DEFINER role lookup — **not** from client |
| `write_audit()` | 196 | allow-listed events, never secrets |
| `validate_status_transition()` | 235 | illegal status jumps rejected for all writers |
| `prevent_role_escalation()` | 264 | user can't promote themselves (even via SQL) |
| `record_request_history()` | 291 | history rows written server-side |
| `create_request` RPC | 334 | ownership-enforcing, SECURITY DEFINER |
| `update_request_status` RPC | 391 | role/ownership/transition checks + denial audit |
| RLS enable + policies | 463+ | all 5 tables, `authenticated` only |

---

## 2. ARCHITECTURE (~3 min)

Open `docs/ARCHITECTURE.md` on GitHub (renders the mermaid diagrams).

- **Three tiers:** Flutter (mobile) / React (admin) / Supabase (Postgres + Auth + RLS).
- Show the **data flow** diagram:
  1. Customer `signInWithPassword` → session
  2. `create_request` RPC → INSERT (RLS: `customer_id = auth.uid()`) → returns `REQ-2026-000NNN` + audit
  3. Agent `update_request_status` → transition check + history + audit
  4. Admin raw UPDATE via policy / RPC → `ASSIGNED` + audit
- Show the **ER diagram** — 5 tables: `profiles`, `services`, `service_requests`, `request_status_history`, `audit_logs`.

> Say: "The rule is: the client requests an action, the database decides if it's allowed."

---

## 3. SECURITY / AUTHORIZATION (~4 min)

Open `docs/SECURITY.md` on GitHub.

- **RLS matrix** — walk one row (customer): can read own profile/requests, cancel own request while `created/assigned`, **cannot** raw-update or read others' requests.
- **Deny matrix for `update_request_status`** — agent can `accept/start/complete` only **assigned** work; customer can only **cancel own**; admin any legal.
- **Why SECURITY DEFINER is safe:** fixed function body, `set search_path = public`, parameterized inputs, policy-level restrictions still apply to anything it calls; it never grants a client new privileges beyond the guarded operation.
- **Integrity:** status state machine + immutable role (two layers: RLS *and* trigger).
- **Audit:** allow-listed events; `audit_logs` has zero write policies (server-side only); no tokens/passwords/keys logged.
- **Proof:** `tests/rls-authz.mjs` — briefly show the test that asserts **cross-customer denial** and **role self-escalation denial**. (Run it live only if time/network allows; otherwise state 16/16.)

> Close: "Even if you change the request UUID in the client, you get nothing back —
> the database enforces it."

---

## Timing budget

| Section | Time |
|---|---|
| Framing | 0:30 |
| Code walkthrough | 6:00 |
| Architecture | 3:00 |
| Security / authz | 4:00 |
| **Hand-off to live demo** | ~1:00 buffer |

Keep a buffer — the panel will ask questions mid-walkthrough; that's fine, answer and continue.