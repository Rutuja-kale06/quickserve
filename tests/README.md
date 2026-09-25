# RLS authorization tests

`rls-authz.mjs` proves the core security requirement of the SWASIQ assignment:
authorization is enforced by **PostgreSQL Row Level Security**, not by hiding UI
buttons. It signs in with real end-user clients (anon key) against your live
Supabase project and asserts both allow- and deny-cases.

## Run

```bash
cd tests
npm install
cp .env.example .env     # then fill in your project URL + keys
npm test
```

The script:

1. Creates fresh fixture accounts (customer, customer, 2 agents, admin) via the
   service-role key, then cleans them up afterwards.
2. Asserts the should-DENY cases fail closed:
   - Customer B cannot read or update Customer A's request
   - A customer cannot self-escalate to `admin`
   - An unassigned agent cannot update a request
   - An illegal lifecycle jump (`assigned → completed`) is rejected
   - A customer cannot cancel a completed request
   - Customers cannot read the audit log
3. Asserts the should-ALLOW cases succeed:
   - Owners create requests; admin assigns; assigned agent Accept → Start → Complete
   - Customer cancels an eligible request; owner reads status history
   - Admin reads all requests and the audit log
4. Exits non-zero if **any** expectation is violated.

> `.env` is git-ignored. Never commit real keys.