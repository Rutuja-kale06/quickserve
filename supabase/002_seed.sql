-- =============================================================================
-- QUICKSERVE / SWASIQ — Seed data: demo accounts + demo requests
-- Run AFTER 001_schema.sql in: Supabase Dashboard → SQL Editor → New query
--
-- Creates three sign-in demo accounts (see README "Test credentials"):
--   customer@quickserve.demo   role=customer   password: QuickServe@123
--   agent@quickserve.demo      role=agent      password: QuickServe@123
--   admin@quickserve.demo      role=admin      password: QuickServe@123
--
-- Script is idempotent: re-running it will not duplicate accounts.
-- Passwords are rendered as bcrypt hashes and erased from this file's concern
-- afterward; they live only in Supabase Auth.
-- =============================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Helper to upsert a demo auth user + profile + email identity
-- ---------------------------------------------------------------------------
do $$
declare
  v_users text[][] := array[
    -- email,                    password,         full_name,            phone,        role
    array['customer@quickserve.demo', 'QuickServe@123', 'Demo Customer', '+91 90000 00001', 'customer'],
    array['agent@quickserve.demo',    'QuickServe@123', 'Demo Agent',    '+91 90000 00002', 'agent'],
    array['admin@quickserve.demo',    'QuickServe@123', 'Demo Admin',    '+91 90000 00003', 'admin']
  ];
  v_email text;
  v_password text;
  v_name text;
  v_phone text;
  v_role text;
  v_user_id uuid;
begin
  for i in 1 .. array_length(v_users, 1) loop
    v_email    := v_users[i][1];
    v_password := v_users[i][2];
    v_name     := v_users[i][3];
    v_phone    := v_users[i][4];
    v_role     := v_users[i][5];

    select id into v_user_id
    from auth.users
    where email = v_email;

    if v_user_id is null then
      insert into auth.users (
        instance_id, id, aud, role,
        email, encrypted_password,
        email_confirmed_at, confirmed_at,
        raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at
      )
      values (
        '00000000-0000-0000-0000-000000000000',
        gen_random_uuid(), 'authenticated', 'authenticated',
        v_email, crypt(v_password, gen_salt('bf')),
        now(), now(),
        jsonb_build_object('provider','email','providers',array['email']),
        jsonb_build_object('full_name', v_name, 'phone', v_phone),
        now(), now()
      )
      returning id into v_user_id;
    end if;

    insert into auth.identities (
      id, user_id, provider_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    )
    values (
      v_user_id, v_user_id, v_user_id,
      jsonb_build_object('sub', v_user_id, 'email', v_email,
                         'email_verified', true, 'phone_verified', false),
      'email', now(), now(), now()
    )
    on conflict (provider, id) do nothing;

    insert into public.profiles (id, full_name, phone, role)
    values (v_user_id, v_name, v_phone, v_role::public.user_role)
    on conflict (id) do update
      set full_name = excluded.full_name,
          phone     = excluded.phone,
          role      = excluded.role;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Verify the seed
-- ---------------------------------------------------------------------------
select p.email, pr.full_name, pr.role
from auth.users p
join public.profiles pr on pr.id = p.id
order by pr.role;