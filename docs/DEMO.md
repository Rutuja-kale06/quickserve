# QuickServe — Live Demo Walkthrough

All screenshots below were captured from the **live deployed project**
(`https://jigyedeiyqkzdsbgnjwd.supabase.co`) using the exact flows below. The
data shown is real: the two newest requests (`REQ-2026-000003`, `REQ-2026-000004`)
were created by a real customer **through the app's own `create_request` RPC**,
which recorded their `REQUEST_CREATED` audit entry and status history.

Reproduce everything with the demo accounts (password `QuickServe@123`):

| Email                   | Role     | Where        |
| ----------------------- | -------- | ------------ |
| customer@quickserve.demo | Customer | Flutter app  |
| agent@quickserve.demo    | Agent    | Flutter app  |
| admin@quickserve.demo    | Admin    | Web portal   |

## Customer app (Flutter)

| Screen | What it proves |
| ------ | -------------- |
| `mobile-01-login.png` | Sign-in screen (Email + Password) |
| `mobile-02-home.png` | Home shows request counts, recent requests and stats (4 total, 2 new, 2 completed) |
| `mobile-03-my-requests.png` | Customer sees only their own requests with status + priority |
| `mobile-04-request-details.png` | Full request detail view with lifecycle and notes |
| `mobile-05-services.png` | Browse the four services (AC servicing, plumbing, electrical, cleaning) |
| `mobile-07-agent-home.png` | Agent view: assigned work area with status tabs |

## Admin portal (React)

| Screen | What it proves |
| ------ | -------------- |
| `admin-01-login.png` | Admin sign-in (non-admins are rejected with an audited `AUTHORIZATION_FAILED`) |
| `admin-02-dashboard.png` | Operations dashboard: total, new, assigned, in-progress, completed, cancelled |
| `admin-03-requests.png` | Full requests table: code, customer, service, status badge, priority, assigned agent, in-line status control |
| `admin-04-search.png` | Search / filter across requests |
| `admin-05-request-details.png` | Detail modal with full status history (who changed what, when) |
| `admin-06-people-audit.png` | Customers + agents panels and the audit/activity trail (`LOGIN_SUCCESS`, `REQUEST_CREATED`, ...) |

## Security checks visible in the demo

- Only `admin@quickserve.demo` can open the portal — other roles get
  "This portal is for administrators only" and the attempt is audited.
- Every screen renders data through Supabase **RLS**, not UI hiding; any
  cross-customer access attempt is denied at the database layer
  (proven separately by `tests/rls-authz.mjs` — 16/16 checks pass).
- Status changes flow through the validated `update_request_status` RPC,
  which enforces lifecycle transitions (`ASSIGNED → ACCEPTED → IN_PROGRESS →
  COMPLETED`) and ownership.