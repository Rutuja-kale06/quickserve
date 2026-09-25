-- QUICK SERVE / SWASIQ
-- Supabase PostgreSQL schema + RLS

create extension if not exists pgcrypto;

create type public.user_role as enum ('customer','agent','admin');
create type public.request_priority as enum ('low','medium','high');
create type public.request_status as enum (
  'created','assigned','accepted','in_progress','completed','cancelled'
);

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

create index if not exists idx_requests_customer on public.service_requests(customer_id);
create index if not exists idx_requests_agent on public.service_requests(assigned_agent_id);
create index if not exists idx_requests_status on public.service_requests(status);
create index if not exists idx_requests_created on public.service_requests(created_at desc);
create index if not exists idx_history_request on public.request_status_history(request_id);
create index if not exists idx_audit_created on public.audit_logs(created_at desc);
create index if not exists idx_audit_actor on public.audit_logs(actor_id);

-- request code generator: REQ-YYYY-000001 style
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

-- updated_at
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

-- Create profile automatically after Supabase signup.
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

-- Role helper. SECURITY DEFINER avoids recursive profile RLS checks.
create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- Generic audit helper
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
  insert into public.audit_logs(actor_id, request_id, event_type, metadata)
  values(auth.uid(), p_request, p_event, coalesce(p_metadata,'{}'::jsonb));
end;
$$;

-- Status history trigger
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

-- Seed services
insert into public.services(name, description) values
('AC Servicing','AC cleaning, servicing and basic maintenance'),
('Plumbing','Leakage, pipe, tap and plumbing maintenance'),
('Electrical','Electrical repair, installation and troubleshooting'),
('Cleaning','Home and office cleaning services')
on conflict(name) do nothing;

-- RLS
alter table public.profiles enable row level security;
alter table public.services enable row level security;
alter table public.service_requests enable row level security;
alter table public.request_status_history enable row level security;
alter table public.audit_logs enable row level security;

-- Profiles
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
using (id = auth.uid() or public.current_user_role() = 'admin');

drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update to authenticated
using (id = auth.uid() or public.current_user_role() = 'admin')
with check (id = auth.uid() or public.current_user_role() = 'admin');

-- Services
drop policy if exists services_read on public.services;
create policy services_read on public.services for select to authenticated
using (active = true or public.current_user_role() = 'admin');

drop policy if exists services_admin_write on public.services;
create policy services_admin_write on public.services for all to authenticated
using (public.current_user_role() = 'admin')
with check (public.current_user_role() = 'admin');

-- Requests
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
create policy requests_update on public.service_requests for update to authenticated
using (
  public.current_user_role() = 'admin'
  or (
    customer_id = auth.uid()
    and status in ('created','assigned')
  )
  or assigned_agent_id = auth.uid()
)
with check (
  public.current_user_role() = 'admin'
  or (
    customer_id = auth.uid()
    and status in ('created','assigned','cancelled')
  )
  or assigned_agent_id = auth.uid()
);

-- History
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

-- Audit logs: admin only
drop policy if exists audit_admin_select on public.audit_logs;
create policy audit_admin_select on public.audit_logs for select to authenticated
using (public.current_user_role() = 'admin');

-- Only trusted DB functions/triggers insert audit logs.
drop policy if exists audit_insert_authenticated on public.audit_logs;
create policy audit_insert_authenticated on public.audit_logs for insert to authenticated
with check (actor_id = auth.uid());

-- RPC for safe request creation + explicit audit error handling can be extended.
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
as $$
declare
  result public.service_requests;
begin
  if p_description is null or length(trim(p_description)) < 5 then
    raise exception 'Description must contain at least 5 characters';
  end if;
  if p_address is null or length(trim(p_address)) < 5 then
    raise exception 'Address is required';
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
  insert into public.audit_logs(actor_id,event_type,metadata)
  values(auth.uid(),'DATABASE_ERROR',jsonb_build_object('operation','create_request'));
  raise;
end;
$$;
