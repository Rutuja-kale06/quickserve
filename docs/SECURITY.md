# Security Model

## Authentication

Supabase Auth handles email/password authentication and password reset.

The application never stores raw passwords.

## Authorization

Authorization is enforced in PostgreSQL using RLS.

### Customer

A customer may:
- select their own profile
- create a request for themselves
- read their own requests
- cancel their own eligible request

A customer cannot query another customer's requests even if they modify the client-side request ID.

### Agent

An agent may:
- read requests assigned to them
- update assigned requests
- add notes/status changes to assigned work

### Admin

Admins may:
- read all requests
- assign agents
- update operational request state
- read profiles, services, status history and audit logs

## Audit

Database triggers and application code record important operational events.

Never record:
- passwords
- access tokens
- refresh tokens
- service-role keys
- API keys

## Authorization test

A required manual/automated test is:

1. Sign in as Customer A.
2. Obtain Customer B's request UUID from a controlled test fixture.
3. Attempt:
   `select * from service_requests where id = <customer_b_request_id>`
4. RLS should return no rows.
5. Attempting an unauthorized update must also be rejected.

The same principle is applied to agents: an agent cannot update a request assigned to a different agent.

## Production considerations

For a production deployment:
- enable MFA for admins
- configure allowed Auth redirect URLs
- use environment/build secrets
- enable database backups
- add rate limiting/abuse controls
- monitor failed authentication and authorization events
