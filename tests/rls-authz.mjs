#!/usr/bin/env node
// =============================================================================
// QuickServe — RLS authorization regression test
// -----------------------------------------------------------------------------
// Proves the assignment's central security requirement: authorization is
// enforced by PostgreSQL Row Level Security, NOT by hiding UI buttons.
//
// It signs in as *real* end-user clients (anon key) and attempts cross-customer
// reads/updates, unassigned-agent updates, illegal transitions, customer-only
// operations and role escalation. Every should-DENY case must be denied and
// every should-ALLOW case must succeed, or the script exits non-zero.
//
// Setup:
//   npm install            (in this folder)
//   copy tests/.env.example to tests/.env and fill in your project values
//   npm test
//
// Credentials stop existing in the repo: nothing here is ever committed.
// =============================================================================

import { createClient } from '@supabase/supabase-js';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));

function loadEnv() {
  const env = { ...process.env };
  const file = join(HERE, '.env');
  if (existsSync(file)) {
    for (const line of readFileSync(file, 'utf8').split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (m && !(m[1] in env)) env[m[1]] = m[2];
    }
  }
  return env;
}

const env = loadEnv();
const URL = env.SUPABASE_URL;
const ANON = env.SUPABASE_ANON_KEY;
const SERVICE = env.SUPABASE_SERVICE_ROLE_KEY;

if (!URL || !ANON || !SERVICE) {
  console.log(`
  SKIP: Supabase credentials not configured.
  Copy tests/.env.example to tests/.env and set:
    SUPABASE_URL=...
    SUPABASE_ANON_KEY=...
    SUPABASE_SERVICE_ROLE_KEY=...
  Then run: cd tests && npm install && npm test
  (This test signs in with real end-user clients to prove RLS behaviour.)
`);
  process.exit(0);
}

const anon = createClient(URL, ANON);
const admin = createClient(URL, SERVICE, { auth: { autoRefreshToken: false } });

const TEST_DOMAIN = 'authztest.local';
const PASSWORD = 'AuthzTest123!';
const results = [];
const pass = (name, ok, detail = '') =>
  results.push({ name, ok, detail }) ||
  console.log(`${ok ? '  PASS' : '  FAIL'}  ${name}${detail ? `  (${detail})` : ''}`);

async function expectDenied(name, fn) {
  try {
    await fn();
    pass(name, false, 'operation SHOULD have been denied but succeeded');
  } catch (err) {
    pass(name, true, `denied: ${err?.code ?? err?.message ?? ''}`);
  }
}

async function expectAllowed(name, fn) {
  try {
    await fn();
    pass(name, true);
  } catch (err) {
    pass(name, false, err?.message ?? String(err));
  }
}

async function signInAs(client, email) {
  const { data, error } = await client.auth.signInWithPassword({ email, password: PASSWORD });
  if (error) throw error;
  return data.session;
}

async function listTestUsers() {
  const out = [];
  let page = 1;
  for (;;) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 });
    if (error) throw error;
    for (const u of data.users) {
      if (typeof u.email === 'string' && u.email.toLowerCase().endsWith(`@${TEST_DOMAIN}`)) {
        out.push(u);
      }
    }
    if (data.users.length < 200) break;
    page += 1;
  }
  return out;
}

async function main() {
  console.log(`\nConnecting to ${URL}\n`);

  // ---- cleanup from previous runs --------------------------------------
  for (const u of await listTestUsers()) {
    await admin.auth.admin.deleteUser(u.id);
  }
  await admin.from('services').delete().eq('name', '__AUTHZ_TEST__');

  // ---- fixtures ----------------------------------------------------------
  const users = {};
  for (const [key, fullName, role] of [
    ['customerA', 'Authz Customer A', 'customer'],
    ['customerB', 'Authz Customer B', 'customer'],
    ['agentAssigned', 'Authz Agent 1', 'agent'],
    ['agentRobin', 'Authz Agent 2 (unassigned)', 'agent'],
    ['boss', 'Authz Admin', 'admin'],
  ]) {
    const email = `${key}@${TEST_DOMAIN}`;
    const { data, error } = await admin.auth.admin.createUser({
      email,
      password: PASSWORD,
      email_confirm: true,
      user_metadata: { full_name: fullName },
    });
    if (error) throw error;
    users[key] = { id: data.user.id, email };
    const { error: roleErr } = await admin.from('profiles').update({ role }).eq('id', data.user.id);
    if (roleErr) throw roleErr;
  }

  const { data: svc } = await admin.from('services').select('id').limit(1);
  if (!svc || svc.length === 0) throw new Error('No services seeded — run supabase/001_schema.sql first');
  const serviceId = svc[0].id;

  await signInAs(anon, users.customerA.email);

  // 1. Customer A creates a request ----------------------------------------
  const { data: created, error: createErr } = await anon.rpc('create_request', {
    p_service_id: serviceId,
    p_description: 'Authz test writing a request',
    p_preferred_at: new Date(Date.now() + 86400000).toISOString(),
    p_address: 'Authz test address',
    p_priority: 'medium',
  });
  if (createErr) throw createErr;
  const reqA = created.id;
  pass('1. Customer A can create a request', true, created.request_code);

  // 2. Customer B is blocked from reading Customer A's request --------------
  await signInAs(anon, users.customerB.email);
  const { data: crossRead } = await anon.from('service_requests').select('id').eq('id', reqA);
  pass('2. Customer B cannot READ Customer A\'s request', Array.isArray(crossRead) && crossRead.length === 0,
    `rows returned: ${crossRead?.length ?? 'n/a'}`);

  await expectDenied('3. Customer B cannot UPDATE Customer A\'s request', async () => {
    const { error } = await anon.from('service_requests').update({ status: 'cancelled' }).eq('id', reqA);
    if (error) throw error;
  });

  // 4. Nobody can self-promote to admin (role escalation) --------------------
  await expectDenied('4. Customer cannot escalate their own role to admin', async () => {
    const { error } = await anon.from('profiles').update({ role: 'admin' }).eq('id', users.customerB.id);
    if (error) throw error;
  });

  // 5. Admin assigns the agent ------------------------------------------------
  await signInAs(anon, users.boss.email);
  const { error: assignErr } = await anon.from('service_requests')
    .update({ assigned_agent_id: users.agentAssigned.id, status: 'assigned' })
    .eq('id', reqA);
  if (assignErr) throw assignErr;
  pass('5. Admin can assign an agent', true);

  // 6. Admin can read all requests --------------------------------------------
  const { data: allReqs } = await anon.from('service_requests').select('id');
  pass('6. Admin can read all requests', (allReqs ?? []).length >= 1, `${(allReqs ?? []).length} rows`);

  // 7. Unassigned agent cannot touch Customer A's request ----------------------
  await signInAs(anon, users.agentRobin.email);
  await expectDenied('7. Unassigned agent cannot update the request', async () => {
    const { error } = await anon.rpc('update_request_status', {
      p_request_id: reqA, p_new_status: 'accepted', p_note: '',
    });
    if (error) throw error;
  });

  // 8. Illegal transition rejected even by the assigned agent ------------------
  await signInAs(anon, users.agentAssigned.email);
  await expectDenied('8. Agent cannot jump assigned -> completed (illegal transition)', async () => {
    const { error } = await anon.rpc('update_request_status', {
      p_request_id: reqA, p_new_status: 'completed', p_note: '',
    });
    if (error) throw error;
  });

  // 9. Assigned agent works the request through the lifecycle ------------------
  for (const [next, label] of [
    ['accepted', 'Accept'],
    ['in_progress', 'Start work'],
    ['completed', 'Complete'],
  ]) {
    await expectAllowed(`9. Assigned agent can ${label} (${next})`, async () => {
      const { error } = await anon.rpc('update_request_status', {
        p_request_id: reqA, p_new_status: next, p_note: 'Authz work note',
      });
      if (error) throw error;
    });
  }

  // 10. Customer can cancel an eligible request --------------------------------
  await signInAs(anon, users.customerA.email);
  const { data: req2 } = await anon.rpc('create_request', {
    p_service_id: serviceId,
    p_description: 'Authz test cancellable request',
    p_preferred_at: new Date(Date.now() + 86400000).toISOString(),
    p_address: 'Authz test address 2',
    p_priority: 'high',
  });
  await expectAllowed('10. Customer can cancel an eligible (created) request', async () => {
    const { error } = await anon.rpc('update_request_status', {
      p_request_id: req2.id, p_new_status: 'cancelled', p_note: '',
    });
    if (error) throw error;
  });

  // 11. Customer cannot cancel a completed request ------------------------------
  await expectDenied('11. Customer cannot cancel their completed request', async () => {
    const { error } = await anon.rpc('update_request_status', {
      p_request_id: reqA, p_new_status: 'cancelled', p_note: '',
    });
    if (error) throw error;
  });

  // 12. Customer can read the status history of their own request ----------------
  const { data: hist } = await anon.from('request_status_history').select('id').eq('request_id', reqA);
  pass('12. Customer can read history of own request', (hist ?? []).length >= 5, `${hist?.length ?? 0} entries`);

  // 13. Customers cannot read the audit log (admin-only) ---------------------------
  const { data: auditC } = await anon.from('audit_logs').select('id');
  pass('13. Customer is blocked from the audit log', (auditC ?? []).length === 0,
    `rows: ${auditC?.length ?? 'n/a'}`);

  await signInAs(anon, users.boss.email);
  const { data: auditA } = await anon.from('audit_logs').select('event_type');
  pass('14. Admin can read the audit log', (auditA ?? []).length > 0,
    `${auditA?.length ?? 0} events: ${(auditA ?? []).map((a) => a.event_type).slice(0, 4).join(', ')}…`);

  // ---- tear down test fixtures ----------------------------------------------
  for (const u of await listTestUsers()) {
    await admin.auth.admin.deleteUser(u.id);
  }

  // ---- report -----------------------------------------------------------------
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${results.length - failed.length}/${results.length} checks passed.`);
  if (failed.length) {
    console.log('Failed checks:');
    for (const f of failed) console.log(`  - ${f.name}: ${f.detail}`);
    process.exit(1);
  }
  console.log('RLS authorization model verified against the live project.\n');
}

main().catch((err) => {
  console.error('\nTest harness failed BEFORE assertions:', err?.message ?? err);
  process.exit(1);
});