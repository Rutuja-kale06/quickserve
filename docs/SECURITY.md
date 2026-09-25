# QuickServe — Security model

## Principles

1. **Authorization is enforced by the database** (RLS + SECURITY DEFINER RPCs),
   never by hiding UI elements.
2. **Roles are server-side.** Application code reads role via `current_user_role()`
   (a `SECURITY DEFINER` SQL function that reads `public.profiles`), so a tampered
   client cannot claim a role.
3. **Least privilege on writes.** Raw `UPDATE` on `service_requests` is admin-only;
   agents/customers must use the validated `update_request_status` RPC.
4. **No secrets in the app, repo or logs.** Passwords live only in Supabase Auth
   (bcrypt). Anon/publishable keys are project configuration; the service-role
   key is confined to server-side tooling (`tests/`).

## Authentication

- Supabase Auth, **Email** provider.
- Password hashing handled by Supabase (bcrypt-family) — the application never
  sees or stores plaintext passwords.
- Password reset via `resetPasswordForEmail` (mobile).
- Session persistence via the Supabase mobile/web SDKs (refresh tokens).

## Authorization — RLS matrix

RLS is enabled on all five application tables. `authenticated` role only.

| Operation | Customer | Agent (assigned) | Admin |
| --------- | -------- | ---------------- | ----- |
| Read own profile | ✅ | ✅ | ✅ all |
| Change own profile (incl. role) | own ✓, **role ✗** | own ✓, role ✗ | ✅ |
| Create request (self) | ✅ | ✗ | ✅ |
| Read requests | own | assigned only | all |
| Update request (raw SQL) | ✗ | ✗ | ✅ |
| Status change | cancel own (created/assigned) via RPC | accept/start/complete/cancel via RPC | via SQL/RPC |
| Read `request_status_history` | own requests | assigned | all |
| Read `audit_logs` | ✗ | ✗ | ✅ |
| Write audit | ✗ (server-only) | ✗ | ✓ (server-side only) |

### Key policies (`001_schema.sql`)

- `profiles_select/update`: `id = auth.uid() OR current_user_role() = 'admin'`.
  Self role-change additionally blocked by `prevent_role_escalation()` trigger.
- `requests_select`: `customer_id = uid OR assigned_agent_id = uid OR admin`.
- `requests_insert`: `customer_id = auth.uid() OR admin`.
- `requests_update_admin`: `current_user_role() = 'admin'` only.
- `history_select`: request visible to its owner / assigned agent / admin.
- `audit_admin_select`: admin only. **No insert/update/delete policies exist.**
- `services_read`: active services (admin sees all); writes admin-only.

Even if a customer modifies the request UUID in the client, the `requests_select`
policy returns zero rows for another customer's request.

## The `update_request_status(request_id, new_status, note)` RPC

`SECURITY DEFINER`; the only sanctioned mutation path for agents/customers:

| Actor | Allowed | Denied |
| ----- | ------- | ------ |
| Agent | accept/start/complete/save-notes on **assigned** work | unassigned request; any column besides status/notes; closed requests |
| Customer | cancel **own** request while created/assigned | other requests; non-cancel changes; completed/cancelled |
| Admin | any legal transition | illegal transitions (trigger) |

Every denial persists an `AUTHORIZATION_FAILED` audit event before raising.

## Lifecycle integrity

`validate_status_transition()` trigger runs `BEFORE UPDATE` on
`service_requests` and rejects every illegal jump for **all** writers:

- `created → assigned|cancelled`
- `assigned → accepted|cancelled`
- `accepted → in_progress`
- `in_progress → completed`
- terminal states have no outgoing edges

## Audit & logging

Allow-listed events (enforced inside `write_audit`):

`LOGIN_SUCCESS`, `LOGIN_FAILED`, `LOGOUT`, `REQUEST_CREATED`, `REQUEST_ASSIGNED`,
`REQUEST_UPDATED`, `REQUEST_CANCELLED`, `AUTHORIZATION_FAILED`, `DATABASE_ERROR`.

**Never logged:** passwords, access tokens, refresh tokens, anon/service API
keys, or any secret material. `metadata` carries only business facts (request
codes, agent ids, statuses, emails) — see `0001_schema.sql` triggers for the
exact payloads.

## Error handling

- Mobile: friendly SnackBar messages with safe error mapping; failures write
  `AUTHORIZATION_FAILED`/`DATABASE_ERROR` events where sensible.
- Admin: toast UI instead of raw `alert()`; requests/RLS failures are surfaced
  to the operator without leaking internals.

## Authorization test (required by the assignment)

`tests/rls-authz.mjs` provisions real users against a live Supabase project and
asserts, among others:

> **A customer attempting to access another customer's request must be denied**

plus: unassigned-agent denial, role self-escalation denial, illegal-transition
denial, audit-log isolation, and the positive agent/admin paths. See
`tests/README.md`.

## Production hardening notes

Already in place: RLS everywhere, SECURITY DEFINER helpers with locked
`search_path`, allow-listed audit events, parametrized RPCs (no SQL injection
surface), no client-writable audit/history.

Recommended for a real deployment: MFA for admins, allow-listed Auth redirect
URLs, database backups / PITR, rate limiting and fraud/abuse monitoring,
sign-in activity monitoring, and CI secrets for the RLS test suite.