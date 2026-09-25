-- =============================================================================
-- QUICKSERVE / SWASIQ — Supabase PostgreSQL schema + RLS (hardened)
-- Run this in: Supabase Dashboard → SQL Editor → New query
-- Then run:     002_seed.sql  (services are seeded here as well; seed adds test accounts)
--
-- Security notes:
--  * Row Level Security is enabled on every application table.
--  * Roles are read server-side through the SECURITY DEFINER helper
--    public.current_user_role(); clients can never spoof a role.
--  * Agents and customers NEVER update service_requests directly through the
--    PostgREST UPDATE endpoint. All status changes go through the validated,
--    audited RPC public.update_request_status() (SECURITY DEFINER, checks
--    ownership + role + legal lifecycle transitions).
--  * Non-admin users cannot change a profile's role (trigger + RLS).
--  * audit_logs rows are only ever written by SECURITY DEFINER functions /
--    triggers; clients have no INSERT policy on audit_logs.
--  * No passwords / tokens / secrets are ever stored outside Supabase Auth.
-- =============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Enums (idempotent: DO blocks swallow "already exists" on re-run)
-- ---------------------------------------------------------------------------
do $$ begin
  create type public.user_role as enum ('customer','agent','admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.request_priority as enum ('low','medium','high');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.request_status as enum (
    'created','assigned','accepted','in_progress','completed','cancelled'
  );
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  phone text,
  role public.user_role not null default 'customer',
  created_at timestamptz not null default now()
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.service_requests (
  id uuid primary key default gen_random_uuid(),
  request_code text unique not null,
  customer_id uuid not null references public.profiles(id),
  service_id uuid not null references public.services(id),
  assigned_agent_id uuid references public.profiles(id),
  description text not null,
  preferred_at timestamptz not null,
  address text not null,
  priority public.request_priority not null default 'medium',
  status public.request_status not null default 'created',
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.request_status_history (
  id bigint generated always as identity primary key,
  request_id uuid not null references public.service_requests(id) on delete cascade,
  old_status public.request_status,
  new_status public.request_status not null,
  changed_by uuid references public.profiles(id),
  note text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  request_id uuid references public.service_requests(id) on delete set null,
  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------
create index if not exists idx_requests_customer on public.service_requests(customer_id);
create index if not exists idx_requests_agent on public.service_requests(assigned_agent_id);
create index if not exists idx_requests_status on public.service_requests(status);
create index if not exists idx_requests_created on public.service_requests(created_at desc);
create index if not exists idx_history_request on public.request_status_history(request_id);
create index if not exists idx_history_changed_by on public.request_status_history(changed_by);
create index if not exists idx_audit_created on public.audit_logs(created_at desc);
create index if not exists idx_audit_actor on public.audit_logs(actor_id);
create index if not exists idx_audit_event on public.audit_logs(event_type);

-- ---------------------------------------------------------------------------
-- Request code generator: REQ-YYYY-000001 style (public-facing request ID)
-- ---------------------------------------------------------------------------
create or replace function public.generate_request_code()
returns trigger
language plpgsql
as $$
declare
  next_number bigint;
begin
  if new.request_code is null or new.request_code = '' then
    select coalesce(max(
      case when request_code ~ ('^REQ-' || extract(year from now())::text || '-[0-9]+$')
      then substring(request_code from '[0-9]+$')::bigint else 0 end
    ), 0) + 1
    into next_number
    from public.service_requests;

    new.request_code := 'REQ-' || extract(year from now())::text || '-' ||
                        lpad(next_number::text, 6, '0');
  end if;
  return new;
end;
$$;

drop trigger if exists trg_request_code on public.service_requests;
create trigger trg_request_code
before insert on public.service_requests
for each row execute function public.generate_request_code();

-- ---------------------------------------------------------------------------
-- updated_at maintenance
-- ---------------------------------------------------------------------------
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_request_updated on public.service_requests;
create trigger trg_request_updated
before update on public.service_requests
for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Create profile automatically after Supabase signup (triggers on auth.users)
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, phone, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    new.raw_user_meta_data->>'phone',
    'customer'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Role helper. SECURITY DEFINER => no recursive RLS on profiles.
-- This is the ONLY sanctioned way application code learns the actor's role.
-- ---------------------------------------------------------------------------
create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- ---------------------------------------------------------------------------
-- Audit helper (SECURITY DEFINER). Event names are allow-listed so only
-- meaningful events are stored. Never pass secrets here.
-- ---------------------------------------------------------------------------
create or replace function public.write_audit(
  p_event text,
  p_request uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_event not in (
    'LOGIN_SUCCESS',
    'LOGIN_FAILED',
    'LOGOUT',
    'REQUEST_CREATED',
    'REQUEST_ASSIGNED',
    'REQUEST_UPDATED',
    'REQUEST_CANCELLED',
    'AUTHORIZATION_FAILED',
    'DATABASE_ERROR'
  ) then
    raise exception 'Event type % is not allowed for audit logging', p_event;
  end if;

  insert into public.audit_logs(actor_id, request_id, event_type, metadata)
  values(auth.uid(), p_request, p_event, coalesce(p_metadata,'{}'::jsonb));
end;
$$;

-- ---------------------------------------------------------------------------
-- Status-transition guard. Enforces the lifecycle for EVERY writer (admin RLS
-- updates included) so no one can jump states illegally:
--   created      -> assigned | cancelled
--   assigned     -> accepted | cancelled
--   accepted     -> in_progress
--   in_progress  -> completed
--   completed / cancelled are terminal.
-- ---------------------------------------------------------------------------
create or replace function public.validate_status_transition()
returns trigger
language plpgsql
as $$
begin
  if new.status is distinct from old.status then
    if not (
      (old.status = 'created' and new.status in ('assigned','cancelled')) or
      (old.status = 'assigned' and new.status in ('accepted','cancelled')) or
      (old.status = 'accepted' and new.status = 'in_progress') or
      (old.status = 'in_progress' and new.status = 'completed')
    ) then
      raise exception 'Illegal status transition: % -> %', old.status, new.status;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_status_transition on public.service_requests;
create trigger trg_status_transition
before update on public.service_requests
for each row execute function public.validate_status_transition();

-- ---------------------------------------------------------------------------
-- Prevent non-admins from changing a profile's role (defense in depth on top
-- of the RLS UPDATE policy). Closes the "user promotes themselves to admin"
-- escalation path.
-- ---------------------------------------------------------------------------
create or replace function public.prevent_role_escalation()
returns trigger
language plpgsql
as $$
begin
  if new.role is distinct from old.role then
    -- auth.uid() is NULL in database-admin context (SQL editor, seed scripts) --
    -- which is safe because RLS still blocks anonymous & client access.
    if auth.uid() is not null and not exists (
      select 1 from public.profiles
      where id = auth.uid() and role = 'admin'
    ) then
      raise exception 'Only administrators can change a user role';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_self_role_escalation on public.profiles;
create trigger trg_self_role_escalation
before update on public.profiles
for each row execute function public.prevent_role_escalation();

-- ---------------------------------------------------------------------------
-- Status-history + audit trigger for service_requests
-- ---------------------------------------------------------------------------
create or replace function public.record_request_history()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.request_status_history(request_id, old_status, new_status, changed_by, note)
    values(new.id, null, new.status, auth.uid(), 'Request created');
    insert into public.audit_logs(actor_id, request_id, event_type, metadata)
    values(auth.uid(), new.id, 'REQUEST_CREATED',
           jsonb_build_object('request_code', new.request_code));
    return new;
  end if;

  if old.assigned_agent_id is distinct from new.assigned_agent_id
     and new.assigned_agent_id is not null then
    insert into public.audit_logs(actor_id, request_id, event_type, metadata)
    values(auth.uid(), new.id, 'REQUEST_ASSIGNED',
           jsonb_build_object('agent_id', new.assigned_agent_id));
  end if;

  if old.status is distinct from new.status then
    insert into public.request_status_history(request_id, old_status, new_status, changed_by, note)
    values(new.id, old.status, new.status, auth.uid(), new.notes);
    insert into public.audit_logs(actor_id, request_id, event_type, metadata)
    values(auth.uid(), new.id, 'REQUEST_UPDATED',
           jsonb_build_object('old_status', old.status, 'new_status', new.status));
  end if;
  return new;
end;
$$;

drop trigger if exists trg_request_history on public.service_requests;
create trigger trg_request_history
after insert or update on public.service_requests
for each row execute function public.record_request_history();

-- ---------------------------------------------------------------------------
-- Safe request creation RPC (security invoker => RLS still applies).
-- Validates input, generates the request code, audits failures.
-- ---------------------------------------------------------------------------
create or replace function public.create_request(
  p_service_id uuid,
  p_description text,
  p_preferred_at timestamptz,
  p_address text,
  p_priority public.request_priority
)
returns public.service_requests
language plpgsql
security invoker
set search_path = public
as $$
declare
  result public.service_requests;
begin
  if p_description is null or length(trim(p_description)) < 5 then
    perform public.write_audit('AUTHORIZATION_FAILED', null,
      jsonb_build_object('operation','create_request','reason','invalid_description'));
    raise exception 'Description must contain at least 5 characters';
  end if;
  if p_address is null or length(trim(p_address)) < 5 then
    perform public.write_audit('AUTHORIZATION_FAILED', null,
      jsonb_build_object('operation','create_request','reason','invalid_address'));
    raise exception 'Address is required';
  end if;
  if p_preferred_at is null or p_preferred_at <= now() then
    raise exception 'Preferred time must be in the future';
  end if;

  insert into public.service_requests(
    request_code, customer_id, service_id, description,
    preferred_at, address, priority
  )
  values (
    '', auth.uid(), p_service_id, trim(p_description),
    p_preferred_at, trim(p_address), p_priority
  )
  returning * into result;

  return result;
exception when others then
  perform public.write_audit('DATABASE_ERROR', null,
    jsonb_build_object('operation','create_request','error', sqlerrm));
  raise;
end;
$$;

-- ---------------------------------------------------------------------------
-- Secure status-update RPC (SECURITY DEFINER). The ONLY path by which agents
-- and customers change request status, and the path agents use to save notes.
-- Enforces ownership, role rules and valid lifecycle transitions.
--   agent   : may accept (assigned->accepted), start (accepted->in_progress),
--             complete (in_progress->completed) or cancel (assigned->cancelled)
--             an ASSIGNED request; may save notes on active work.
--   customer: may only cancel their OWN request while created/assigned.
--   admin   : may use it as well (all legal transitions).
-- ---------------------------------------------------------------------------
create or replace function public.update_request_status(
  p_request_id uuid,
  p_new_status public.request_status,
  p_note text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor public.user_role;
  v_row public.service_requests;
begin
  select role into v_actor from public.profiles where id = auth.uid();
  if v_actor is null then
    raise exception 'Profile not found';
  end if;

  select * into v_row
  from public.service_requests where id = p_request_id;

  if v_row.id is null then
    perform public.write_audit('AUTHORIZATION_FAILED', p_request_id,
      jsonb_build_object('operation','update_request_status','reason','request_not_found'));
    raise exception 'Request not found';
  end if;

  -- Authorization matrix
  if v_actor = 'admin' then
    null; -- any legal transition (trigger enforces legality)
  elsif v_actor = 'agent' then
    if v_row.assigned_agent_id is distinct from auth.uid() then
      perform public.write_audit('AUTHORIZATION_FAILED', p_request_id,
        jsonb_build_object('operation','update_request_status','reason','not_assigned'));
      raise exception 'You may only update requests assigned to you';
    end if;
    if v_row.status = 'cancelled' or v_row.status = 'completed' then
      raise exception 'This request is already closed';
    end if;
  elsif v_actor = 'customer' then
    if v_row.customer_id is distinct from auth.uid() then
      perform public.write_audit('AUTHORIZATION_FAILED', p_request_id,
        jsonb_build_object('operation','update_request_status','reason','not_owner'));
      raise exception 'You may only update your own requests';
    end if;
    if p_new_status <> 'cancelled' then
      perform public.write_audit('AUTHORIZATION_FAILED', p_request_id,
        jsonb_build_object('operation','update_request_status','reason','customer_can_only_cancel'));
      raise exception 'Customers may only cancel their requests';
    end if;
    if v_row.status not in ('created','assigned') then
      perform public.write_audit('AUTHORIZATION_FAILED', p_request_id,
        jsonb_build_object('operation','update_request_status','reason','not_cancellable'));
      raise exception 'This request can no longer be cancelled';
    end if;
  else
    perform public.write_audit('AUTHORIZATION_FAILED', p_request_id,
      jsonb_build_object('operation','update_request_status','reason','unknown_role'));
    raise exception 'Unknown role';
  end if;

  update public.service_requests
  set status = p_new_status,
      notes  = case when length(trim(p_note)) > 0 then trim(p_note) else notes end
  where id = p_request_id;
end;
$$;

-- ===========================================================================
-- Row Level Security
-- ===========================================================================
alter table public.profiles enable row level security;
alter table public.services enable row level security;
alter table public.service_requests enable row level security;
alter table public.request_status_history enable row level security;
alter table public.audit_logs enable row level security;

-- Profiles: read own or (as admin) any. Update own or (as admin) any.
-- Role changes are additionally blocked for non-admins by trigger.
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
using (id = auth.uid() or public.current_user_role() = 'admin');

drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update to authenticated
using (id = auth.uid() or public.current_user_role() = 'admin')
with check (id = auth.uid() or public.current_user_role() = 'admin');

-- Services: everyone reads active, admins manage all.
drop policy if exists services_read on public.services;
create policy services_read on public.services for select to authenticated
using (active = true or public.current_user_role() = 'admin');

drop policy if exists services_admin_write on public.services;
create policy services_admin_write on public.services for all to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

-- Requests:
--   Select: customer sees own, agent sees assigned, admin sees all.
--   Insert: customer may create for themselves, admin may create.
--   Update: ADMIN ONLY via raw UPDATE. Agents/customers MUST use the
--           update_request_status() RPC, which enforces role + transitions
--           and writes the audit trail. This removes the "agent can rewrite
--           any column" RLS hole from the basic scaffold.
drop policy if exists requests_select on public.service_requests;
create policy requests_select on public.service_requests for select to authenticated
using (
  customer_id = auth.uid()
  or assigned_agent_id = auth.uid()
  or public.current_user_role() = 'admin'
);

drop policy if exists requests_insert on public.service_requests;
create policy requests_insert on public.service_requests for insert to authenticated
with check (
  customer_id = auth.uid()
  or public.current_user_role() = 'admin'
);

drop policy if exists requests_update on public.service_requests;
drop policy if exists requests_update_admin on public.service_requests;
create policy requests_update_admin on public.service_requests for update to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

-- History: readable by request owner / assigned agent / admin.
drop policy if exists history_select on public.request_status_history;
create policy history_select on public.request_status_history for select to authenticated
using (
  exists (
    select 1 from public.service_requests r
    where r.id = request_id
      and (
        r.customer_id = auth.uid()
        or r.assigned_agent_id = auth.uid()
        or public.current_user_role() = 'admin'
      )
  )
);

-- Audit logs: admin read only. No INSERT policy => rows are written solely by
-- SECURITY DEFINER functions / triggers (write_audit, record_request_history).
drop policy if exists audit_admin_select on public.audit_logs;
create policy audit_admin_select on public.audit_logs for select to authenticated
using (public.current_user_role() = 'admin');

-- ===========================================================================
-- Seed services
-- ===========================================================================
insert into public.services(name, description) values
('AC Servicing','AC cleaning, servicing and basic maintenance'),
('Plumbing','Leakage, pipe, tap and plumbing maintenance'),
('Electrical','Electrical repair, installation and troubleshooting'),
('Cleaning','Home and office cleaning services')
on conflict(name) do nothing;