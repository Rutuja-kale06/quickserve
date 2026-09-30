# QuickServe — Anticipated Interview Q&A

Grouped by theme. Drill the bold ones first — they're the most likely.

---

## Product & decisions

**Q: Why Flutter?**
A: One codebase for Android and iOS with native performance, and the Supabase Flutter SDK is first-class. It also targets web/desktop, so the same app runs in a browser for demos without an emulator.

**Q: Why not Firebase?**
A: I needed **Row Level Security** and per-row, per-user authorization on shared tables. Supabase maps directly onto Postgres's RLS, which lets me put the security boundary in the database. Firebase's model is client-side rules and SDK-based authz; Supabase gives me SQL I can test.

**Q: Why a separate admin portal instead of one app?**
A: The admin is a power-user console (search, people, audit) with a heavy table UI a phone doesn't need. Keeping it separate also means tighter scoping — the admin role never ships in the mobile surface.

---

## Security & authorization

**Q: How do you stop a customer from reading another customer's request?**
A: RLS. `requests_select` returns only rows where `customer_id = auth.uid()` (or the assigned agent, or admin). If a client fabricates a UUID, the query simply returns zero rows. The RLS test asserts exactly this.

**Q: What is SECURITY DEFINER, and why doesn't it become a backdoor?**
A: It runs the function with the definer's privileges and bypasses RLS *inside the function*, which is exactly why the function body is tiny, fixed, and parameterized, and sets `search_path = public`. It only does one guarded thing (e.g. transition one request), re-checks role/ownership, and never exposes an arbitrary "run any SQL" path. Unprivileged users can't change the function body.

**Q: How do you know a client can't lie about its role?**
A: Role is never read from the client. Every sensitive path calls `current_user_role()` — a SECURITY DEFINER function that reads `public.profiles` for `auth.uid()`. There's also a trigger (`prevent_role_escalation`) that blocks a user promoting their own role even with direct SQL.

**Q: What happens when something is denied?**
A: `update_request_status` writes an `AUTHORIZATION_FAILED` audit event, then raises. So a denied attempt is visible in the audit trail — I showed that in the demo.

**Q: Why is raw UPDATE admin-only?**
A: Agents/customers go through the RPC which validates transitions and ownership. Only `current_user_role() = 'admin'` can `UPDATE` the table directly — least privilege: nobody can bypass the business rules except the actor who's supposed to administer them.

**Q: What's the difference between the audit tables?**
A: `request_status_history` = per-request technical history (old→new status, changelog, changed_by). `audit_logs` = security and business events (logins, creations, assignments, denials) with JSON metadata. Audit is append-only by policy: no INSERT/UPDATE/DELETE policies exist — writes happen server-side.

**Q: Are secrets ever near the client?**
A: No. The app only gets the publishable/anon key; passwords are bcrypt-managed by Supabase Auth; the service-role key lives only in git-ignored `tests/.env` for the RLS regressions.

---

## Database & engineering

**Q: How does the status state machine work?**
A: A `BEFORE UPDATE` trigger `validate_status_transition` rejects illegal jumps for every writer: `created→assigned|cancelled`, `assigned→accepted|cancelled`, `accepted→in_progress`, `in_progress→completed`, terminal states have no outgoing edges. So even if admin does a raw UPDATE, the transition must be legal.

**Q: How is REQ-2026-000123 generated and why?**
A: `generate_request_code` (BEFORE INSERT trigger) builds `REQ-<year>-<6-digit seq>` using a `nextval`-style sequence — unique, human-readable, and lets customers quote a ticket in one breath. The seeded demo data used the same mechanism.

**Q: What do your tests actually prove?**
A: `tests/rls-authz.mjs` provisions real users against the live project and asserts 16 behaviors — e.g. cross-customer read denial, unassigned-agent denial, role self-escalation denial, illegal transition denial, audit isolation, plus the happy paths for agent/admin. It's a regression suite you can rerun.

**Q: How would you scale this?**
A: RLS and the RPCs sit on Postgres, so read-replicas/connection pooling are the standard levers; indexes cover the hot queries (`customer_id`, `assigned_agent_id`, `status`, `created_at`). Supabase abstracts the infra. The audit table would get retention/partitioning in production.

**Q: What SQL injection surface exists?**
A: None in practice — all app writes go through parameterized RPCs, and functions use fixed SQL with bound parameters, never dynamic SQL built from user input.

---

## Honesty / trade-offs

**Q: What would you improve or regret?**
A: Production hardening, honestly: MFA for admins; sign the release APK with a real keystore (it's debug-signed for sideloading now); rate limiting; backups/PITR; better sign-in anomaly monitoring. Also the email-confirm edge on signup — I hit it during self-testing (white screen), traced it to no live session after signup, and fixed it in `d7d4ec7` so the app shows "check your inbox" instead of crashing.

**Q: What was the hardest bug?**
A: The release build had no INTERNET permission (Flutter only ships it in the debug/profile manifests), so the APK opened but couldn't reach Supabase — and on this machine, building also fought disk space and a broken Kotlin incremental-cache. Both were environment/verification issues, and committing the fix made the demo reproducible.

**Q: Why is the APK debug-signed?**
A: For sideloading a demo build. A Play-releasable version needs a proper keystore and Play integrity — I'd do that before any distribution, not just this evaluation.

---

## Fast-refresh answers

- **Roles enum?** `customer` / `agent` / `admin` — a Postgres enum, not a string.
- **How many tables?** 5 application tables, all RLS-enabled.
- **Live URL?** Supabase project `jigyedeiyqkzdsbgnjwd`; repo `github.com/Rutuja-kale06/quickserve`.
- **Tests passing?** `flutter analyze` clean; 16/16 RLS assertions; admin `utils` unit tests pass.
- **Can credentials change?** Yes — demo accounts only; add/confirm/delete via Supabase Auth panel.