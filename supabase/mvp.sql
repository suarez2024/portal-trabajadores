create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
set search_path = public, extensions;

do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in (
        'portal_ping',
        'portal_login',
        'portal_admin_login',
        'portal_logout',
        'portal_admin_resumen',
        'portal_trabajador_datos',
        'portal_cliente_resumen',
        'portal_admin_crear_cliente',
        'portal_admin_crear_trabajador',
        'portal_admin_set_activo',
        'portal_admin_actualizar_cliente',
        'portal_admin_actualizar_trabajador',
        'portal_admin_borrar_cliente',
        'portal_admin_reiniciar_datos',
        'portal_admin_archivar_trabajador',
        'portal_admin_restaurar_trabajador',
        'portal_trabajador_crear_jornada',
        'portal_trabajador_borrar_jornada',
        'portal_admin_borrar_jornada'
      )
  loop
    execute format('drop function if exists %s cascade', r.sig);
  end loop;
end $$;

create table if not exists public.admins (
  id uuid primary key default gen_random_uuid(),
  username text not null,
  password_hash text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_login_at timestamptz
);

create unique index if not exists admins_username_key on public.admins (lower(username));

create table if not exists public.sessions (
  token_hash text primary key,
  role text not null check (role in ('admin', 'client', 'assistant')),
  user_id uuid not null,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create index if not exists sessions_user_idx on public.sessions (role, user_id);
create index if not exists sessions_expires_idx on public.sessions (expires_at);

create table if not exists public.settings (
  key text primary key,
  value text not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  password_hash text not null,
  company text not null,
  contact_name text not null,
  phone text,
  country text,
  timezone text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'suspended')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_at timestamptz,
  last_login_at timestamptz
);

create unique index if not exists clients_email_key on public.clients (lower(email));
create index if not exists clients_status_idx on public.clients (status);

create sequence if not exists public.assistant_code_seq start 1;

create table if not exists public.assistants (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  email text not null,
  password_hash text not null,
  first_name text not null,
  full_name text not null,
  headline text,
  skills text[] not null default '{}',
  languages text[] not null default '{}',
  certifications text[] not null default '{}',
  availability text,
  photo_url text,
  video_url text,
  phone text,
  country text,
  timezone text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected', 'suspended')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  approved_at timestamptz,
  last_login_at timestamptz
);

create unique index if not exists assistants_email_key on public.assistants (lower(email));
create index if not exists assistants_status_idx on public.assistants (status);

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  schedule text,
  assistant_rate numeric(10, 2) not null default 0 check (assistant_rate >= 0),
  client_id uuid references public.clients (id) on delete set null,
  status text not null default 'draft' check (status in ('draft', 'open', 'paused', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists jobs_status_idx on public.jobs (status);
create index if not exists jobs_client_idx on public.jobs (client_id);

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs (id) on delete cascade,
  assistant_id uuid not null references public.assistants (id) on delete cascade,
  client_id uuid references public.clients (id) on delete set null,
  note text,
  status text not null default 'applied' check (status in ('applied', 'shortlisted', 'sent', 'rejected', 'selected', 'hired')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (job_id, assistant_id)
);

create index if not exists applications_status_idx on public.applications (status);
create index if not exists applications_client_idx on public.applications (client_id);
create index if not exists applications_assistant_idx on public.applications (assistant_id);

create table if not exists public.engagements (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references public.clients (id) on delete cascade,
  assistant_id uuid not null references public.assistants (id) on delete cascade,
  job_id uuid references public.jobs (id) on delete set null,
  application_id uuid references public.applications (id) on delete set null,
  client_rate numeric(10, 2) not null check (client_rate >= 0),
  assistant_rate numeric(10, 2) not null check (assistant_rate >= 0),
  work_days integer[] not null default '{1,2,3,4,5}',
  start_date date not null default current_date,
  end_date date,
  status text not null default 'active' check (status in ('active', 'paused', 'ended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists engagements_client_idx on public.engagements (client_id, status);
create index if not exists engagements_assistant_idx on public.engagements (assistant_id, status);

create table if not exists public.time_entries (
  id uuid primary key default gen_random_uuid(),
  engagement_id uuid not null references public.engagements (id) on delete cascade,
  assistant_id uuid not null references public.assistants (id) on delete cascade,
  client_id uuid not null references public.clients (id) on delete cascade,
  work_date date not null,
  start_time time not null,
  end_time time not null,
  minutes integer not null check (minutes > 0),
  note text,
  source text not null default 'assistant' check (source in ('assistant', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists time_entries_assistant_idx on public.time_entries (assistant_id, work_date);
create index if not exists time_entries_client_idx on public.time_entries (client_id, work_date);
create index if not exists time_entries_engagement_idx on public.time_entries (engagement_id, work_date);

create table if not exists public.missing_day_dismissals (
  assistant_id uuid not null references public.assistants (id) on delete cascade,
  engagement_id uuid not null references public.engagements (id) on delete cascade,
  work_date date not null,
  created_at timestamptz not null default now(),
  primary key (assistant_id, engagement_id, work_date)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  role text not null check (role in ('admin', 'client', 'assistant')),
  user_id uuid not null,
  kind text not null,
  data jsonb not null default '{}',
  dedupe_key text,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists notifications_user_idx on public.notifications (role, user_id, created_at desc);
create unique index if not exists notifications_dedupe_key on public.notifications (role, user_id, dedupe_key) where dedupe_key is not null;

create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  actor_role text,
  actor_id uuid,
  action text not null,
  entity text,
  entity_id uuid,
  detail jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists audit_log_created_idx on public.audit_log (created_at desc);

insert into public.settings (key, value)
select 'fx_rate', '18.66'
where not exists (select 1 from public.settings where key = 'fx_rate');

insert into public.settings (key, value)
select 'timezone', 'America/Mexico_City'
where not exists (select 1 from public.settings where key = 'timezone');

insert into public.admins (username, password_hash)
select 'Admin', crypt('Admin2026', gen_salt('bf', 10))
where not exists (select 1 from public.admins where lower(username) = 'admin');

create or replace function public._portal_today(p_timezone text)
returns date
language sql
stable
set search_path = public, extensions
as $$
  select case
    when p_timezone is not null and exists (select 1 from pg_timezone_names where name = p_timezone)
      then (now() at time zone p_timezone)::date
    else current_date
  end;
$$;

create or replace function public._portal_fx()
returns numeric
language sql
stable
security definer
set search_path = public, extensions
as $$
  select coalesce((select value::numeric from public.settings where key = 'fx_rate'), 18.66);
$$;

create or replace function public._portal_client_json(c public.clients)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', c.id,
    'email', c.email,
    'company', c.company,
    'contact_name', c.contact_name,
    'phone', c.phone,
    'country', c.country,
    'timezone', c.timezone,
    'status', c.status,
    'created_at', c.created_at
  );
$$;

create or replace function public._portal_assistant_json(a public.assistants)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', a.id,
    'code', a.code,
    'email', a.email,
    'first_name', a.first_name,
    'full_name', a.full_name,
    'headline', a.headline,
    'skills', a.skills,
    'languages', a.languages,
    'certifications', a.certifications,
    'availability', a.availability,
    'photo_url', a.photo_url,
    'video_url', a.video_url,
    'phone', a.phone,
    'country', a.country,
    'timezone', a.timezone,
    'status', a.status,
    'created_at', a.created_at
  );
$$;

create or replace function public._portal_public_assistant_json(a public.assistants)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', a.id,
    'code', a.code,
    'first_name', a.first_name,
    'headline', a.headline,
    'skills', a.skills,
    'languages', a.languages,
    'certifications', a.certifications,
    'availability', a.availability,
    'photo_url', a.photo_url,
    'video_url', a.video_url
  );
$$;

create or replace function public._portal_admin_json(a public.admins)
returns jsonb
language sql
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', a.id,
    'username', a.username
  );
$$;

create or replace function public._portal_notifications_json(p_role text, p_user_id uuid, p_limit integer default 30)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', x.id,
    'kind', x.kind,
    'data', x.data,
    'read_at', x.read_at,
    'created_at', x.created_at
  ) order by x.created_at desc), '[]'::jsonb)
  from (
    select id, kind, data, read_at, created_at
    from public.notifications
    where role = p_role and user_id = p_user_id
    order by created_at desc
    limit greatest(p_limit, 0)
  ) x;
$$;

create or replace function public._portal_unread(p_role text, p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where role = p_role and user_id = p_user_id and read_at is null;
$$;

create or replace function public._portal_notify(
  p_role text,
  p_user_id uuid,
  p_kind text,
  p_data jsonb default '{}'::jsonb,
  p_dedupe text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (role, user_id, kind, data, dedupe_key)
  values (p_role, p_user_id, p_kind, coalesce(p_data, '{}'::jsonb), p_dedupe)
  on conflict do nothing;
end;
$$;

create or replace function public._portal_notify_admins(
  p_kind text,
  p_data jsonb default '{}'::jsonb,
  p_dedupe text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (role, user_id, kind, data, dedupe_key)
  select 'admin', a.id, p_kind, coalesce(p_data, '{}'::jsonb), p_dedupe
  from public.admins a
  on conflict do nothing;
end;
$$;

create or replace function public._portal_audit(
  p_actor_role text,
  p_actor_id uuid,
  p_action text,
  p_entity text,
  p_entity_id uuid,
  p_detail jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_log (actor_role, actor_id, action, entity, entity_id, detail)
  values (p_actor_role, p_actor_id, p_action, p_entity, p_entity_id, coalesce(p_detail, '{}'::jsonb));
end;
$$;

create or replace function public._portal_new_session(p_role text, p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_token text;
begin
  v_token := encode(gen_random_bytes(32), 'hex');
  insert into public.sessions (token_hash, role, user_id, expires_at)
  values (encode(digest(v_token, 'sha256'), 'hex'), p_role, p_user_id, now() + interval '30 days');
  delete from public.sessions where expires_at < now();
  return v_token;
end;
$$;

create or replace function public._portal_auth(p_token text, p_role text default null)
returns public.sessions
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_status text;
begin
  if p_token is null or length(p_token) < 32 then
    raise exception 'AUTH';
  end if;

  select * into v_session
  from public.sessions
  where token_hash = encode(digest(p_token, 'sha256'), 'hex');

  if not found then
    raise exception 'AUTH';
  end if;

  if v_session.expires_at <= now() then
    delete from public.sessions where token_hash = v_session.token_hash;
    raise exception 'AUTH';
  end if;

  if p_role is not null and v_session.role <> p_role then
    raise exception 'FORBIDDEN';
  end if;

  if v_session.role = 'client' then
    select status into v_status from public.clients where id = v_session.user_id;
    if v_status is null then
      raise exception 'AUTH';
    end if;
    if v_status <> 'approved' then
      raise exception '%', upper(v_status);
    end if;
  elsif v_session.role = 'assistant' then
    select status into v_status from public.assistants where id = v_session.user_id;
    if v_status is null then
      raise exception 'AUTH';
    end if;
    if v_status <> 'approved' then
      raise exception '%', upper(v_status);
    end if;
  elsif v_session.role = 'admin' then
    perform 1 from public.admins where id = v_session.user_id;
    if not found then
      raise exception 'AUTH';
    end if;
  else
    raise exception 'AUTH';
  end if;

  update public.sessions set last_seen_at = now() where token_hash = v_session.token_hash;
  return v_session;
end;
$$;

create or replace function public._portal_email_taken(p_email text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.clients where lower(email) = lower(trim(p_email)))
      or exists (select 1 from public.assistants where lower(email) = lower(trim(p_email)));
$$;

create or replace function public._portal_assert_no_overlap(
  p_assistant_id uuid,
  p_work_date date,
  p_start time,
  p_end time,
  p_exclude uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.time_entries
    where assistant_id = p_assistant_id
      and work_date = p_work_date
      and id is distinct from p_exclude
      and start_time < p_end
      and end_time > p_start
  ) then
    raise exception 'OVERLAP';
  end if;
end;
$$;

create or replace function public._portal_missing_rows(p_assistant_id uuid default null)
returns table (
  work_date date,
  engagement_id uuid,
  assistant_id uuid,
  client_company text,
  assistant_name text
)
language sql
stable
security definer
set search_path = public, extensions
as $$
  select
    gs::date as work_date,
    e.id as engagement_id,
    e.assistant_id,
    c.company as client_company,
    a.first_name as assistant_name
  from public.engagements e
  join public.clients c on c.id = e.client_id
  join public.assistants a on a.id = e.assistant_id
  cross join lateral generate_series(
    greatest(e.start_date, public._portal_today(a.timezone) - 60),
    public._portal_today(a.timezone) - 15,
    interval '1 day'
  ) gs
  where e.status = 'active'
    and (p_assistant_id is null or e.assistant_id = p_assistant_id)
    and extract(isodow from gs) between 1 and 5
    and extract(isodow from gs)::integer = any (e.work_days)
    and not exists (
      select 1 from public.time_entries t
      where t.engagement_id = e.id and t.work_date = gs::date
    )
    and not exists (
      select 1 from public.missing_day_dismissals m
      where m.engagement_id = e.id and m.work_date = gs::date
    )
  order by gs desc;
$$;

create or replace function public.portal_health()
returns jsonb
language sql
stable
security definer
set search_path = public, extensions
as $$
  select jsonb_build_object(
    'ok', true,
    'version', 'mvp-1',
    'fx_rate', public._portal_fx()
  );
$$;

create or replace function public.portal_signup_client(
  p_email text,
  p_password text,
  p_company text,
  p_contact_name text,
  p_phone text default null,
  p_country text default null,
  p_timezone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_client public.clients;
begin
  p_email := lower(trim(coalesce(p_email, '')));
  p_company := trim(coalesce(p_company, ''));
  p_contact_name := trim(coalesce(p_contact_name, ''));

  if p_email = '' or p_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' then
    raise exception 'INVALID';
  end if;
  if p_password is null or length(p_password) < 8 then
    raise exception 'PASSWORD_WEAK';
  end if;
  if p_company = '' or p_contact_name = '' then
    raise exception 'INVALID';
  end if;
  if public._portal_email_taken(p_email) then
    raise exception 'EMAIL_TAKEN';
  end if;

  begin
    insert into public.clients (email, password_hash, company, contact_name, phone, country, timezone)
    values (
      p_email,
      crypt(p_password, gen_salt('bf', 10)),
      p_company,
      p_contact_name,
      nullif(trim(coalesce(p_phone, '')), ''),
      nullif(trim(coalesce(p_country, '')), ''),
      nullif(trim(coalesce(p_timezone, '')), '')
    )
    returning * into v_client;
  exception when unique_violation then
    raise exception 'EMAIL_TAKEN';
  end;

  perform public._portal_notify_admins(
    'PENDING_SIGNUP',
    jsonb_build_object('role', 'client', 'name', v_client.company, 'email', v_client.email, 'id', v_client.id),
    'signup:client:' || v_client.id::text
  );

  return jsonb_build_object('ok', true, 'id', v_client.id);
end;
$$;

create or replace function public.portal_signup_assistant(
  p_email text,
  p_password text,
  p_first_name text,
  p_full_name text,
  p_headline text default null,
  p_skills text[] default '{}',
  p_languages text[] default '{}',
  p_certifications text[] default '{}',
  p_availability text default null,
  p_photo_url text default null,
  p_video_url text default null,
  p_phone text default null,
  p_country text default null,
  p_timezone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_assistant public.assistants;
  v_skills text[];
  v_languages text[];
  v_certifications text[];
  v_code text;
begin
  p_email := lower(trim(coalesce(p_email, '')));
  p_first_name := trim(coalesce(p_first_name, ''));
  p_full_name := trim(coalesce(p_full_name, ''));

  select coalesce(array_agg(distinct trim(s)), '{}')
  into v_skills
  from unnest(coalesce(p_skills, '{}')) s
  where trim(s) <> '';

  select coalesce(array_agg(distinct trim(s)), '{}')
  into v_languages
  from unnest(coalesce(p_languages, '{}')) s
  where trim(s) <> '';

  select coalesce(array_agg(distinct trim(s)), '{}')
  into v_certifications
  from unnest(coalesce(p_certifications, '{}')) s
  where trim(s) <> '';

  if p_email = '' or p_email !~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$' then
    raise exception 'INVALID';
  end if;
  if p_password is null or length(p_password) < 8 then
    raise exception 'PASSWORD_WEAK';
  end if;
  if p_first_name = '' or p_full_name = '' then
    raise exception 'INVALID';
  end if;
  if cardinality(v_skills) = 0 then
    raise exception 'INVALID';
  end if;
  if public._portal_email_taken(p_email) then
    raise exception 'EMAIL_TAKEN';
  end if;

  v_code := 'KG-' || lpad(nextval('public.assistant_code_seq')::text, 4, '0');

  begin
    insert into public.assistants (
      code, email, password_hash, first_name, full_name, headline,
      skills, languages, certifications, availability,
      photo_url, video_url, phone, country, timezone
    )
    values (
      v_code,
      p_email,
      crypt(p_password, gen_salt('bf', 10)),
      p_first_name,
      p_full_name,
      nullif(trim(coalesce(p_headline, '')), ''),
      v_skills,
      v_languages,
      v_certifications,
      nullif(trim(coalesce(p_availability, '')), ''),
      nullif(trim(coalesce(p_photo_url, '')), ''),
      nullif(trim(coalesce(p_video_url, '')), ''),
      nullif(trim(coalesce(p_phone, '')), ''),
      nullif(trim(coalesce(p_country, '')), ''),
      nullif(trim(coalesce(p_timezone, '')), '')
    )
    returning * into v_assistant;
  exception when unique_violation then
    raise exception 'EMAIL_TAKEN';
  end;

  perform public._portal_notify_admins(
    'PENDING_SIGNUP',
    jsonb_build_object('role', 'assistant', 'name', v_assistant.full_name, 'email', v_assistant.email, 'id', v_assistant.id),
    'signup:assistant:' || v_assistant.id::text
  );

  return jsonb_build_object('ok', true, 'id', v_assistant.id, 'code', v_assistant.code);
end;
$$;

create or replace function public.portal_login(p_email text, p_password text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_client public.clients;
  v_assistant public.assistants;
  v_token text;
begin
  if p_email is null or trim(p_email) = '' or p_password is null or p_password = '' then
    raise exception 'INVALID_CREDENTIALS';
  end if;

  select * into v_client
  from public.clients
  where lower(email) = lower(trim(p_email))
  limit 1;

  if found then
    if v_client.password_hash <> crypt(p_password, v_client.password_hash) then
      raise exception 'INVALID_CREDENTIALS';
    end if;
    if v_client.status <> 'approved' then
      raise exception '%', upper(v_client.status);
    end if;
    update public.clients set last_login_at = now() where id = v_client.id;
    v_token := public._portal_new_session('client', v_client.id);
    return jsonb_build_object(
      'ok', true,
      'token', v_token,
      'role', 'client',
      'profile', public._portal_client_json(v_client)
    );
  end if;

  select * into v_assistant
  from public.assistants
  where lower(email) = lower(trim(p_email))
  limit 1;

  if found then
    if v_assistant.password_hash <> crypt(p_password, v_assistant.password_hash) then
      raise exception 'INVALID_CREDENTIALS';
    end if;
    if v_assistant.status <> 'approved' then
      raise exception '%', upper(v_assistant.status);
    end if;
    update public.assistants set last_login_at = now() where id = v_assistant.id;
    v_token := public._portal_new_session('assistant', v_assistant.id);
    return jsonb_build_object(
      'ok', true,
      'token', v_token,
      'role', 'assistant',
      'profile', public._portal_assistant_json(v_assistant)
    );
  end if;

  raise exception 'INVALID_CREDENTIALS';
end;
$$;

create or replace function public.portal_admin_login(p_username text, p_password text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_admin public.admins;
  v_token text;
begin
  if p_username is null or trim(p_username) = '' or p_password is null or p_password = '' then
    raise exception 'INVALID_CREDENTIALS';
  end if;

  select * into v_admin
  from public.admins
  where lower(username) = lower(trim(p_username))
  limit 1;

  if not found then
    raise exception 'INVALID_CREDENTIALS';
  end if;
  if v_admin.password_hash <> crypt(p_password, v_admin.password_hash) then
    raise exception 'INVALID_CREDENTIALS';
  end if;

  update public.admins set last_login_at = now() where id = v_admin.id;
  v_token := public._portal_new_session('admin', v_admin.id);

  return jsonb_build_object(
    'ok', true,
    'token', v_token,
    'role', 'admin',
    'profile', public._portal_admin_json(v_admin)
  );
end;
$$;

create or replace function public.portal_logout(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if p_token is not null and length(p_token) >= 32 then
    delete from public.sessions
    where token_hash = encode(digest(p_token, 'sha256'), 'hex');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.portal_session(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_client public.clients;
  v_assistant public.assistants;
  v_admin public.admins;
begin
  v_session := public._portal_auth(p_token);

  if v_session.role = 'client' then
    select * into v_client from public.clients where id = v_session.user_id;
    return jsonb_build_object('ok', true, 'role', 'client', 'profile', public._portal_client_json(v_client));
  elsif v_session.role = 'assistant' then
    select * into v_assistant from public.assistants where id = v_session.user_id;
    return jsonb_build_object('ok', true, 'role', 'assistant', 'profile', public._portal_assistant_json(v_assistant));
  else
    select * into v_admin from public.admins where id = v_session.user_id;
    return jsonb_build_object('ok', true, 'role', 'admin', 'profile', public._portal_admin_json(v_admin));
  end if;
end;
$$;

create or replace function public.portal_mark_notifications(p_token text, p_ids uuid[] default null)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
begin
  v_session := public._portal_auth(p_token);

  if p_ids is null then
    update public.notifications
    set read_at = now()
    where role = v_session.role and user_id = v_session.user_id and read_at is null;
  else
    update public.notifications
    set read_at = now()
    where role = v_session.role and user_id = v_session.user_id
      and id = any (p_ids) and read_at is null;
  end if;

  return jsonb_build_object(
    'ok', true,
    'unread', public._portal_unread(v_session.role, v_session.user_id)
  );
end;
$$;

create or replace function public.portal_client_profile(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_client public.clients;
begin
  v_session := public._portal_auth(p_token, 'client');
  select * into v_client from public.clients where id = v_session.user_id;
  return jsonb_build_object('ok', true, 'profile', public._portal_client_json(v_client));
end;
$$;

create or replace function public.portal_client_update_profile(
  p_token text,
  p_company text,
  p_contact_name text,
  p_phone text default null,
  p_country text default null,
  p_timezone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_client public.clients;
begin
  v_session := public._portal_auth(p_token, 'client');

  if trim(coalesce(p_company, '')) = '' or trim(coalesce(p_contact_name, '')) = '' then
    raise exception 'INVALID';
  end if;

  update public.clients
  set company = trim(p_company),
      contact_name = trim(p_contact_name),
      phone = nullif(trim(coalesce(p_phone, '')), ''),
      country = nullif(trim(coalesce(p_country, '')), ''),
      timezone = nullif(trim(coalesce(p_timezone, '')), ''),
      updated_at = now()
  where id = v_session.user_id
  returning * into v_client;

  return jsonb_build_object('ok', true, 'profile', public._portal_client_json(v_client));
end;
$$;

create or replace function public.portal_client_dashboard(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_client public.clients;
  v_today date;
  v_from date;
  v_to date;
  v_minutes integer;
  v_amount numeric;
  v_active integer;
  v_candidates integer;
  v_assistants jsonb;
begin
  v_session := public._portal_auth(p_token, 'client');
  select * into v_client from public.clients where id = v_session.user_id;

  v_today := public._portal_today(v_client.timezone);
  v_from := date_trunc('month', v_today)::date;
  v_to := (date_trunc('month', v_today) + interval '1 month - 1 day')::date;

  select count(*)::integer into v_active
  from public.engagements
  where client_id = v_session.user_id and status = 'active';

  select coalesce(sum(t.minutes), 0)::integer,
         coalesce(round(sum(t.minutes / 60.0 * e.client_rate), 2), 0)
  into v_minutes, v_amount
  from public.time_entries t
  join public.engagements e on e.id = t.engagement_id
  where t.client_id = v_session.user_id
    and t.work_date between v_from and v_to;

  select count(*)::integer into v_candidates
  from public.applications
  where client_id = v_session.user_id and status = 'sent';

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'client_rate', e.client_rate,
    'work_days', e.work_days,
    'start_date', e.start_date,
    'end_date', e.end_date,
    'status', e.status,
    'job_title', j.title,
    'assistant', public._portal_public_assistant_json(a)
  ) order by e.created_at desc), '[]'::jsonb)
  into v_assistants
  from public.engagements e
  join public.assistants a on a.id = e.assistant_id
  left join public.jobs j on j.id = e.job_id
  where e.client_id = v_session.user_id and e.status = 'active';

  return jsonb_build_object(
    'ok', true,
    'profile', public._portal_client_json(v_client),
    'period', jsonb_build_object('from', v_from, 'to', v_to),
    'stats', jsonb_build_object(
      'active_assistants', v_active,
      'minutes', v_minutes,
      'amount', v_amount,
      'pending_candidates', v_candidates
    ),
    'assistants', v_assistants,
    'notifications', public._portal_notifications_json('client', v_session.user_id),
    'unread', public._portal_unread('client', v_session.user_id)
  );
end;
$$;

create or replace function public.portal_client_candidates(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_rows jsonb;
begin
  v_session := public._portal_auth(p_token, 'client');

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', app.id,
    'status', app.status,
    'note', app.note,
    'created_at', app.created_at,
    'job_id', j.id,
    'job_title', j.title,
    'job_schedule', j.schedule,
    'assistant', public._portal_public_assistant_json(a)
  ) order by app.updated_at desc), '[]'::jsonb)
  into v_rows
  from public.applications app
  join public.jobs j on j.id = app.job_id
  join public.assistants a on a.id = app.assistant_id
  where app.client_id = v_session.user_id
    and app.status in ('sent', 'selected');

  return jsonb_build_object('ok', true, 'candidates', v_rows);
end;
$$;

create or replace function public.portal_client_select_candidate(p_token text, p_application_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_app public.applications;
  v_job public.jobs;
  v_assistant public.assistants;
  v_client public.clients;
begin
  v_session := public._portal_auth(p_token, 'client');

  select * into v_app
  from public.applications
  where id = p_application_id and client_id = v_session.user_id
  for update;

  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if v_app.status = 'selected' then
    raise exception 'CONFLICT';
  end if;
  if v_app.status <> 'sent' then
    raise exception 'CONFLICT';
  end if;

  update public.applications
  set status = 'selected', updated_at = now()
  where id = v_app.id;

  select * into v_job from public.jobs where id = v_app.job_id;
  select * into v_assistant from public.assistants where id = v_app.assistant_id;
  select * into v_client from public.clients where id = v_session.user_id;

  perform public._portal_notify_admins(
    'CANDIDATE_SELECTED',
    jsonb_build_object(
      'application_id', v_app.id,
      'assistant_name', v_assistant.first_name,
      'job_title', v_job.title,
      'client_name', v_client.company
    ),
    'selected:' || v_app.id::text
  );

  perform public._portal_notify(
    'assistant',
    v_assistant.id,
    'SELECTED_BY_CLIENT',
    jsonb_build_object('job_title', v_job.title),
    'selected-assistant:' || v_app.id::text
  );

  return jsonb_build_object('ok', true, 'status', 'selected');
end;
$$;

create or replace function public.portal_client_engagements(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_rows jsonb;
begin
  v_session := public._portal_auth(p_token, 'client');

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'client_rate', e.client_rate,
    'work_days', e.work_days,
    'start_date', e.start_date,
    'end_date', e.end_date,
    'status', e.status,
    'job_title', j.title,
    'minutes', coalesce((select sum(t.minutes) from public.time_entries t where t.engagement_id = e.id), 0),
    'assistant', public._portal_public_assistant_json(a)
  ) order by e.status, e.created_at desc), '[]'::jsonb)
  into v_rows
  from public.engagements e
  join public.assistants a on a.id = e.assistant_id
  left join public.jobs j on j.id = e.job_id
  where e.client_id = v_session.user_id;

  return jsonb_build_object('ok', true, 'engagements', v_rows);
end;
$$;

create or replace function public.portal_client_time(
  p_token text,
  p_from date default null,
  p_to date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_client public.clients;
  v_today date;
  v_from date;
  v_to date;
  v_rows jsonb;
  v_total integer;
begin
  v_session := public._portal_auth(p_token, 'client');
  select * into v_client from public.clients where id = v_session.user_id;

  v_today := public._portal_today(v_client.timezone);
  v_from := coalesce(p_from, date_trunc('month', v_today)::date);
  v_to := coalesce(p_to, (date_trunc('month', v_today) + interval '1 month - 1 day')::date);

  if v_to < v_from then
    raise exception 'INVALID';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', t.id,
    'date', t.work_date,
    'start_time', t.start_time,
    'end_time', t.end_time,
    'minutes', t.minutes,
    'engagement_id', t.engagement_id,
    'job_title', j.title,
    'assistant', public._portal_public_assistant_json(a)
  ) order by t.work_date desc, t.start_time), '[]'::jsonb),
  coalesce(sum(t.minutes), 0)::integer
  into v_rows, v_total
  from public.time_entries t
  join public.engagements e on e.id = t.engagement_id
  join public.assistants a on a.id = t.assistant_id
  left join public.jobs j on j.id = e.job_id
  where t.client_id = v_session.user_id
    and t.work_date between v_from and v_to;

  return jsonb_build_object(
    'ok', true,
    'from', v_from,
    'to', v_to,
    'entries', v_rows,
    'total_minutes', v_total
  );
end;
$$;

create or replace function public.portal_client_statements(
  p_token text,
  p_from date default null,
  p_to date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_client public.clients;
  v_today date;
  v_from date;
  v_to date;
  v_rows jsonb;
  v_total_minutes integer;
  v_total numeric;
begin
  v_session := public._portal_auth(p_token, 'client');
  select * into v_client from public.clients where id = v_session.user_id;

  v_today := public._portal_today(v_client.timezone);
  v_from := coalesce(p_from, date_trunc('month', v_today)::date);
  v_to := coalesce(p_to, (date_trunc('month', v_today) + interval '1 month - 1 day')::date);

  if v_to < v_from then
    raise exception 'INVALID';
  end if;

  select coalesce(jsonb_agg(row_to_json(x) order by x.assistant_name), '[]'::jsonb),
         coalesce(sum(x.minutes), 0)::integer,
         coalesce(round(sum(x.amount), 2), 0)
  into v_rows, v_total_minutes, v_total
  from (
    select
      e.id as engagement_id,
      a.first_name as assistant_name,
      a.photo_url,
      a.code,
      j.title as job_title,
      e.client_rate,
      sum(t.minutes)::integer as minutes,
      round(sum(t.minutes / 60.0 * e.client_rate), 2) as amount
    from public.time_entries t
    join public.engagements e on e.id = t.engagement_id
    join public.assistants a on a.id = t.assistant_id
    left join public.jobs j on j.id = e.job_id
    where t.client_id = v_session.user_id
      and t.work_date between v_from and v_to
    group by e.id, a.first_name, a.photo_url, a.code, j.title, e.client_rate
  ) x;

  return jsonb_build_object(
    'ok', true,
    'from', v_from,
    'to', v_to,
    'rows', v_rows,
    'total_minutes', v_total_minutes,
    'total', v_total
  );
end;
$$;

create or replace function public.portal_assistant_profile(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_assistant public.assistants;
begin
  v_session := public._portal_auth(p_token, 'assistant');
  select * into v_assistant from public.assistants where id = v_session.user_id;
  return jsonb_build_object('ok', true, 'profile', public._portal_assistant_json(v_assistant));
end;
$$;

create or replace function public.portal_assistant_update_profile(
  p_token text,
  p_first_name text,
  p_full_name text,
  p_headline text default null,
  p_skills text[] default '{}',
  p_languages text[] default '{}',
  p_certifications text[] default '{}',
  p_availability text default null,
  p_photo_url text default null,
  p_video_url text default null,
  p_phone text default null,
  p_country text default null,
  p_timezone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_assistant public.assistants;
  v_skills text[];
  v_languages text[];
  v_certifications text[];
begin
  v_session := public._portal_auth(p_token, 'assistant');

  p_first_name := trim(coalesce(p_first_name, ''));
  p_full_name := trim(coalesce(p_full_name, ''));

  select coalesce(array_agg(distinct trim(s)), '{}')
  into v_skills
  from unnest(coalesce(p_skills, '{}')) s
  where trim(s) <> '';

  select coalesce(array_agg(distinct trim(s)), '{}')
  into v_languages
  from unnest(coalesce(p_languages, '{}')) s
  where trim(s) <> '';

  select coalesce(array_agg(distinct trim(s)), '{}')
  into v_certifications
  from unnest(coalesce(p_certifications, '{}')) s
  where trim(s) <> '';

  if p_first_name = '' or p_full_name = '' or cardinality(v_skills) = 0 then
    raise exception 'INVALID';
  end if;

  update public.assistants
  set first_name = p_first_name,
      full_name = p_full_name,
      headline = nullif(trim(coalesce(p_headline, '')), ''),
      skills = v_skills,
      languages = v_languages,
      certifications = v_certifications,
      availability = nullif(trim(coalesce(p_availability, '')), ''),
      photo_url = nullif(trim(coalesce(p_photo_url, '')), ''),
      video_url = nullif(trim(coalesce(p_video_url, '')), ''),
      phone = nullif(trim(coalesce(p_phone, '')), ''),
      country = nullif(trim(coalesce(p_country, '')), ''),
      timezone = nullif(trim(coalesce(p_timezone, '')), ''),
      updated_at = now()
  where id = v_session.user_id
  returning * into v_assistant;

  return jsonb_build_object('ok', true, 'profile', public._portal_assistant_json(v_assistant));
end;
$$;

create or replace function public.portal_assistant_dashboard(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_assistant public.assistants;
  v_today date;
  v_week_start date;
  v_month_start date;
  v_today_minutes integer;
  v_week_minutes integer;
  v_month_minutes integer;
  v_assignments jsonb;
  v_missing jsonb;
  v_apps integer;
begin
  v_session := public._portal_auth(p_token, 'assistant');
  select * into v_assistant from public.assistants where id = v_session.user_id;

  v_today := public._portal_today(v_assistant.timezone);
  v_week_start := date_trunc('week', v_today)::date;
  v_month_start := date_trunc('month', v_today)::date;

  select coalesce(sum(minutes) filter (where work_date = v_today), 0)::integer,
         coalesce(sum(minutes) filter (where work_date >= v_week_start and work_date <= v_today), 0)::integer,
         coalesce(sum(minutes) filter (where work_date >= v_month_start and work_date <= v_today), 0)::integer
  into v_today_minutes, v_week_minutes, v_month_minutes
  from public.time_entries
  where assistant_id = v_session.user_id;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'client_company', c.company,
    'assistant_rate', e.assistant_rate,
    'work_days', e.work_days,
    'start_date', e.start_date,
    'end_date', e.end_date,
    'status', e.status,
    'job_title', j.title
  ) order by e.created_at desc), '[]'::jsonb)
  into v_assignments
  from public.engagements e
  join public.clients c on c.id = e.client_id
  left join public.jobs j on j.id = e.job_id
  where e.assistant_id = v_session.user_id and e.status = 'active';

  select coalesce(jsonb_agg(jsonb_build_object(
    'date', m.work_date,
    'engagement_id', m.engagement_id,
    'client_company', m.client_company
  ) order by m.work_date desc), '[]'::jsonb)
  into v_missing
  from public._portal_missing_rows(v_session.user_id) m;

  select count(*)::integer into v_apps
  from public.applications
  where assistant_id = v_session.user_id and status in ('applied', 'shortlisted', 'sent', 'selected');

  return jsonb_build_object(
    'ok', true,
    'profile', public._portal_assistant_json(v_assistant),
    'today', v_today,
    'stats', jsonb_build_object(
      'today_minutes', v_today_minutes,
      'week_minutes', v_week_minutes,
      'month_minutes', v_month_minutes,
      'open_applications', v_apps
    ),
    'assignments', v_assignments,
    'missing_days', v_missing,
    'break_reminder', v_today_minutes >= 480,
    'notifications', public._portal_notifications_json('assistant', v_session.user_id),
    'unread', public._portal_unread('assistant', v_session.user_id)
  );
end;
$$;

create or replace function public.portal_assistant_jobs(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_rows jsonb;
begin
  v_session := public._portal_auth(p_token, 'assistant');

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', j.id,
    'title', j.title,
    'description', j.description,
    'schedule', j.schedule,
    'rate', j.assistant_rate,
    'client_company', c.company,
    'created_at', j.created_at,
    'application_status', (
      select a.status from public.applications a
      where a.job_id = j.id and a.assistant_id = v_session.user_id
      limit 1
    )
  ) order by j.created_at desc), '[]'::jsonb)
  into v_rows
  from public.jobs j
  left join public.clients c on c.id = j.client_id
  where j.status = 'open';

  return jsonb_build_object('ok', true, 'jobs', v_rows);
end;
$$;

create or replace function public.portal_assistant_apply(
  p_token text,
  p_job_id uuid,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_job public.jobs;
  v_assistant public.assistants;
  v_app public.applications;
begin
  v_session := public._portal_auth(p_token, 'assistant');

  select * into v_job from public.jobs where id = p_job_id;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if v_job.status <> 'open' then
    raise exception 'JOB_CLOSED';
  end if;

  if exists (
    select 1 from public.applications
    where job_id = p_job_id and assistant_id = v_session.user_id
  ) then
    raise exception 'CONFLICT';
  end if;

  insert into public.applications (job_id, assistant_id, note)
  values (p_job_id, v_session.user_id, nullif(trim(coalesce(p_note, '')), ''))
  returning * into v_app;

  select * into v_assistant from public.assistants where id = v_session.user_id;

  perform public._portal_notify_admins(
    'APPLICATION_RECEIVED',
    jsonb_build_object(
      'application_id', v_app.id,
      'assistant_name', v_assistant.first_name,
      'job_title', v_job.title
    ),
    'application:' || v_app.id::text
  );

  return jsonb_build_object('ok', true, 'id', v_app.id);
end;
$$;

create or replace function public.portal_assistant_applications(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_rows jsonb;
begin
  v_session := public._portal_auth(p_token, 'assistant');

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'status', a.status,
    'note', a.note,
    'created_at', a.created_at,
    'job_id', j.id,
    'job_title', j.title,
    'schedule', j.schedule,
    'rate', j.assistant_rate,
    'client_company', c.company
  ) order by a.created_at desc), '[]'::jsonb)
  into v_rows
  from public.applications a
  join public.jobs j on j.id = a.job_id
  left join public.clients c on c.id = j.client_id
  where a.assistant_id = v_session.user_id;

  return jsonb_build_object('ok', true, 'applications', v_rows);
end;
$$;

create or replace function public.portal_assistant_time(
  p_token text,
  p_from date default null,
  p_to date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_assistant public.assistants;
  v_today date;
  v_from date;
  v_to date;
  v_entries jsonb;
  v_assignments jsonb;
  v_total integer;
begin
  v_session := public._portal_auth(p_token, 'assistant');
  select * into v_assistant from public.assistants where id = v_session.user_id;

  v_today := public._portal_today(v_assistant.timezone);
  v_from := coalesce(p_from, date_trunc('month', v_today)::date);
  v_to := coalesce(p_to, (date_trunc('month', v_today) + interval '1 month - 1 day')::date);

  if v_to < v_from then
    raise exception 'INVALID';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'client_company', c.company,
    'rate', e.assistant_rate,
    'work_days', e.work_days,
    'start_date', e.start_date,
    'job_title', j.title
  ) order by e.created_at desc), '[]'::jsonb)
  into v_assignments
  from public.engagements e
  join public.clients c on c.id = e.client_id
  left join public.jobs j on j.id = e.job_id
  where e.assistant_id = v_session.user_id and e.status = 'active';

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', t.id,
    'date', t.work_date,
    'start_time', t.start_time,
    'end_time', t.end_time,
    'minutes', t.minutes,
    'engagement_id', t.engagement_id,
    'client_company', c.company,
    'job_title', j.title
  ) order by t.work_date desc, t.start_time), '[]'::jsonb),
  coalesce(sum(t.minutes), 0)::integer
  into v_entries, v_total
  from public.time_entries t
  join public.engagements e on e.id = t.engagement_id
  join public.clients c on c.id = e.client_id
  left join public.jobs j on j.id = e.job_id
  where t.assistant_id = v_session.user_id
    and t.work_date between v_from and v_to;

  return jsonb_build_object(
    'ok', true,
    'today', v_today,
    'from', v_from,
    'to', v_to,
    'assignments', v_assignments,
    'entries', v_entries,
    'total_minutes', v_total
  );
end;
$$;

create or replace function public.portal_assistant_add_time(
  p_token text,
  p_date date,
  p_start time,
  p_end time,
  p_engagement_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_assistant public.assistants;
  v_engagement public.engagements;
  v_entry public.time_entries;
  v_today date;
  v_minutes integer;
  v_day_minutes integer;
begin
  v_session := public._portal_auth(p_token, 'assistant');
  select * into v_assistant from public.assistants where id = v_session.user_id;
  v_today := public._portal_today(v_assistant.timezone);

  if p_date is null or p_start is null or p_end is null then
    raise exception 'INVALID';
  end if;
  if p_date > v_today then
    raise exception 'FUTURE_DATE';
  end if;
  if p_end <= p_start then
    raise exception 'INVALID_TIME';
  end if;

  if p_engagement_id is not null then
    select * into v_engagement
    from public.engagements
    where id = p_engagement_id and assistant_id = v_session.user_id and status = 'active';
    if not found then
      raise exception 'NO_ENGAGEMENT';
    end if;
  else
    select * into v_engagement
    from public.engagements
    where assistant_id = v_session.user_id and status = 'active'
    order by start_date desc, created_at desc
    limit 1;
    if not found then
      raise exception 'NO_ENGAGEMENT';
    end if;
  end if;

  perform public._portal_assert_no_overlap(v_session.user_id, p_date, p_start, p_end, null);

  v_minutes := floor(extract(epoch from (p_end - p_start)) / 60)::integer;
  if v_minutes <= 0 then
    raise exception 'INVALID_TIME';
  end if;

  insert into public.time_entries (
    engagement_id, assistant_id, client_id, work_date, start_time, end_time, minutes, source
  )
  values (
    v_engagement.id, v_session.user_id, v_engagement.client_id, p_date, p_start, p_end, v_minutes, 'assistant'
  )
  returning * into v_entry;

  select coalesce(sum(minutes), 0)::integer into v_day_minutes
  from public.time_entries
  where engagement_id = v_engagement.id and work_date = p_date;

  return jsonb_build_object(
    'ok', true,
    'entry', jsonb_build_object(
      'id', v_entry.id,
      'date', v_entry.work_date,
      'start_time', v_entry.start_time,
      'end_time', v_entry.end_time,
      'minutes', v_entry.minutes,
      'engagement_id', v_entry.engagement_id
    ),
    'day_minutes', v_day_minutes,
    'break_reminder', v_day_minutes >= 480
  );
end;
$$;

create or replace function public.portal_assistant_delete_time(p_token text, p_entry_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_entry public.time_entries;
begin
  v_session := public._portal_auth(p_token, 'assistant');

  select * into v_entry
  from public.time_entries
  where id = p_entry_id and assistant_id = v_session.user_id
  for update;

  if not found then
    raise exception 'NOT_FOUND';
  end if;

  delete from public.time_entries where id = v_entry.id;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.portal_assistant_ignore_missing(
  p_token text,
  p_engagement_id uuid,
  p_date date
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
begin
  v_session := public._portal_auth(p_token, 'assistant');

  if not exists (
    select 1 from public.engagements
    where id = p_engagement_id and assistant_id = v_session.user_id
  ) then
    raise exception 'NOT_FOUND';
  end if;

  insert into public.missing_day_dismissals (assistant_id, engagement_id, work_date)
  values (v_session.user_id, p_engagement_id, p_date)
  on conflict do nothing;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.portal_assistant_earnings(
  p_token text,
  p_from date default null,
  p_to date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_assistant public.assistants;
  v_today date;
  v_from date;
  v_to date;
  v_fx numeric;
  v_rows jsonb;
  v_total_minutes integer;
  v_total_usd numeric;
  v_total_mxn numeric;
begin
  v_session := public._portal_auth(p_token, 'assistant');
  select * into v_assistant from public.assistants where id = v_session.user_id;

  v_today := public._portal_today(v_assistant.timezone);
  v_from := coalesce(p_from, date_trunc('month', v_today)::date);
  v_to := coalesce(p_to, (date_trunc('month', v_today) + interval '1 month - 1 day')::date);
  v_fx := public._portal_fx();

  if v_to < v_from then
    raise exception 'INVALID';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'date', x.work_date,
    'engagement_id', x.engagement_id,
    'client_company', x.client_company,
    'job_title', x.job_title,
    'minutes', x.minutes,
    'rate', x.assistant_rate,
    'usd', x.usd,
    'mxn', round(x.usd * v_fx, 2)
  ) order by x.work_date desc, x.client_company), '[]'::jsonb),
  coalesce(sum(x.minutes), 0)::integer,
  coalesce(round(sum(x.usd), 2), 0)
  into v_rows, v_total_minutes, v_total_usd
  from (
    select
      t.work_date,
      e.id as engagement_id,
      c.company as client_company,
      j.title as job_title,
      sum(t.minutes)::integer as minutes,
      e.assistant_rate,
      round(sum(t.minutes / 60.0 * e.assistant_rate), 2) as usd
    from public.time_entries t
    join public.engagements e on e.id = t.engagement_id
    join public.clients c on c.id = e.client_id
    left join public.jobs j on j.id = e.job_id
    where t.assistant_id = v_session.user_id
      and t.work_date between v_from and v_to
    group by t.work_date, e.id, c.company, j.title, e.assistant_rate
  ) x;

  v_total_mxn := round(v_total_usd * v_fx, 2);

  return jsonb_build_object(
    'ok', true,
    'from', v_from,
    'to', v_to,
    'fx_rate', v_fx,
    'rows', v_rows,
    'total_minutes', v_total_minutes,
    'total_usd', v_total_usd,
    'total_mxn', v_total_mxn
  );
end;
$$;

create or replace function public.portal_admin_dashboard(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_today date;
  v_from date;
  v_to date;
  v_pending_clients integer;
  v_pending_assistants integer;
  v_active_clients integer;
  v_active_assistants integer;
  v_open_jobs integer;
  v_applications integer;
  v_minutes integer;
  v_billed numeric;
  v_pay numeric;
  v_missing integer;
  v_pending_clients_list jsonb;
  v_pending_assistants_list jsonb;
begin
  v_session := public._portal_auth(p_token, 'admin');

  v_today := public._portal_today((select value from public.settings where key = 'timezone'));
  v_from := date_trunc('month', v_today)::date;
  v_to := (date_trunc('month', v_today) + interval '1 month - 1 day')::date;

  select count(*)::integer into v_pending_clients from public.clients where status = 'pending';
  select count(*)::integer into v_pending_assistants from public.assistants where status = 'pending';
  select count(*)::integer into v_active_clients from public.clients where status = 'approved';
  select count(*)::integer into v_active_assistants from public.assistants where status = 'approved';
  select count(*)::integer into v_open_jobs from public.jobs where status = 'open';
  select count(*)::integer into v_applications from public.applications where status in ('applied', 'shortlisted');
  select count(*)::integer into v_missing from public._portal_missing_rows(null) m;

  select coalesce(sum(t.minutes), 0)::integer,
         coalesce(round(sum(t.minutes / 60.0 * e.client_rate), 2), 0),
         coalesce(round(sum(t.minutes / 60.0 * e.assistant_rate), 2), 0)
  into v_minutes, v_billed, v_pay
  from public.time_entries t
  join public.engagements e on e.id = t.engagement_id
  where t.work_date between v_from and v_to;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'company', c.company,
    'contact_name', c.contact_name,
    'email', c.email,
    'created_at', c.created_at
  ) order by c.created_at), '[]'::jsonb)
  into v_pending_clients_list
  from (
    select * from public.clients where status = 'pending' order by created_at limit 5
  ) c;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'code', a.code,
    'first_name', a.first_name,
    'full_name', a.full_name,
    'email', a.email,
    'photo_url', a.photo_url,
    'created_at', a.created_at
  ) order by a.created_at), '[]'::jsonb)
  into v_pending_assistants_list
  from (
    select * from public.assistants where status = 'pending' order by created_at limit 5
  ) a;

  return jsonb_build_object(
    'ok', true,
    'period', jsonb_build_object('from', v_from, 'to', v_to),
    'stats', jsonb_build_object(
      'pending_clients', v_pending_clients,
      'pending_assistants', v_pending_assistants,
      'active_clients', v_active_clients,
      'active_assistants', v_active_assistants,
      'open_jobs', v_open_jobs,
      'applications', v_applications,
      'minutes', v_minutes,
      'billed', v_billed,
      'pay', v_pay,
      'margin', round(v_billed - v_pay, 2),
      'missing_days', v_missing
    ),
    'pending_clients', v_pending_clients_list,
    'pending_assistants', v_pending_assistants_list,
    'notifications', public._portal_notifications_json('admin', v_session.user_id),
    'unread', public._portal_unread('admin', v_session.user_id)
  );
end;
$$;

create or replace function public.portal_admin_clients(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_rows jsonb;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id,
    'email', c.email,
    'company', c.company,
    'contact_name', c.contact_name,
    'phone', c.phone,
    'country', c.country,
    'timezone', c.timezone,
    'status', c.status,
    'notes', c.notes,
    'created_at', c.created_at,
    'approved_at', c.approved_at,
    'last_login_at', c.last_login_at,
    'active_assistants', (
      select count(*)::integer from public.engagements e
      where e.client_id = c.id and e.status = 'active'
    )
  ) order by c.created_at desc), '[]'::jsonb)
  into v_rows
  from public.clients c;

  return jsonb_build_object('ok', true, 'clients', v_rows);
end;
$$;

create or replace function public.portal_admin_client_save(
  p_token text,
  p_client_id uuid,
  p_company text,
  p_contact_name text,
  p_phone text default null,
  p_country text default null,
  p_timezone text default null,
  p_status text default null,
  p_notes text default null,
  p_new_password text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_old public.clients;
  v_client public.clients;
  v_status text;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select * into v_old from public.clients where id = p_client_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;

  v_status := coalesce(p_status, v_old.status);
  if v_status not in ('pending', 'approved', 'rejected', 'suspended') then
    raise exception 'INVALID';
  end if;
  if trim(coalesce(p_company, '')) = '' or trim(coalesce(p_contact_name, '')) = '' then
    raise exception 'INVALID';
  end if;
  if p_new_password is not null and p_new_password <> '' and length(p_new_password) < 8 then
    raise exception 'PASSWORD_WEAK';
  end if;

  update public.clients
  set company = trim(p_company),
      contact_name = trim(p_contact_name),
      phone = nullif(trim(coalesce(p_phone, '')), ''),
      country = nullif(trim(coalesce(p_country, '')), ''),
      timezone = nullif(trim(coalesce(p_timezone, '')), ''),
      status = v_status,
      notes = nullif(trim(coalesce(p_notes, '')), ''),
      approved_at = case
        when v_status = 'approved' and v_old.status <> 'approved' then now()
        when v_status <> 'approved' then null
        else v_old.approved_at
      end,
      password_hash = case
        when p_new_password is not null and p_new_password <> '' then crypt(p_new_password, gen_salt('bf', 10))
        else v_old.password_hash
      end,
      updated_at = now()
  where id = p_client_id
  returning * into v_client;

  if v_status <> 'approved' then
    delete from public.sessions where role = 'client' and user_id = p_client_id;
  end if;

  if v_status = 'approved' and v_old.status <> 'approved' then
    perform public._portal_notify(
      'client',
      p_client_id,
      'ACCOUNT_APPROVED',
      '{}'::jsonb,
      'approved:client:' || p_client_id::text
    );
  end if;

  perform public._portal_audit(
    'admin',
    v_session.user_id,
    'client.update',
    'client',
    p_client_id,
    jsonb_build_object(
      'status_before', v_old.status,
      'status_after', v_status,
      'password_reset', (p_new_password is not null and p_new_password <> '')
    )
  );

  return jsonb_build_object(
    'ok', true,
    'client', jsonb_build_object(
      'id', v_client.id,
      'email', v_client.email,
      'company', v_client.company,
      'contact_name', v_client.contact_name,
      'phone', v_client.phone,
      'country', v_client.country,
      'timezone', v_client.timezone,
      'status', v_client.status,
      'notes', v_client.notes,
      'created_at', v_client.created_at,
      'approved_at', v_client.approved_at,
      'last_login_at', v_client.last_login_at,
      'active_assistants', (
        select count(*)::integer from public.engagements e
        where e.client_id = v_client.id and e.status = 'active'
      )
    )
  );
end;
$$;

create or replace function public.portal_admin_assistants(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_rows jsonb;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select coalesce(jsonb_agg(
    public._portal_assistant_json(a) || jsonb_build_object(
      'notes', a.notes,
      'approved_at', a.approved_at,
      'last_login_at', a.last_login_at,
      'active_assignments', (
        select count(*)::integer from public.engagements e
        where e.assistant_id = a.id and e.status = 'active'
      )
    )
    order by a.created_at desc
  ), '[]'::jsonb)
  into v_rows
  from public.assistants a;

  return jsonb_build_object('ok', true, 'assistants', v_rows);
end;
$$;

create or replace function public.portal_admin_assistant_save(
  p_token text,
  p_assistant_id uuid,
  p_first_name text,
  p_full_name text,
  p_headline text default null,
  p_phone text default null,
  p_country text default null,
  p_timezone text default null,
  p_status text default null,
  p_notes text default null,
  p_new_password text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_old public.assistants;
  v_assistant public.assistants;
  v_status text;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select * into v_old from public.assistants where id = p_assistant_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;

  v_status := coalesce(p_status, v_old.status);
  if v_status not in ('pending', 'approved', 'rejected', 'suspended') then
    raise exception 'INVALID';
  end if;
  if trim(coalesce(p_first_name, '')) = '' or trim(coalesce(p_full_name, '')) = '' then
    raise exception 'INVALID';
  end if;
  if p_new_password is not null and p_new_password <> '' and length(p_new_password) < 8 then
    raise exception 'PASSWORD_WEAK';
  end if;

  update public.assistants
  set first_name = trim(p_first_name),
      full_name = trim(p_full_name),
      headline = nullif(trim(coalesce(p_headline, '')), ''),
      phone = nullif(trim(coalesce(p_phone, '')), ''),
      country = nullif(trim(coalesce(p_country, '')), ''),
      timezone = nullif(trim(coalesce(p_timezone, '')), ''),
      status = v_status,
      notes = nullif(trim(coalesce(p_notes, '')), ''),
      approved_at = case
        when v_status = 'approved' and v_old.status <> 'approved' then now()
        when v_status <> 'approved' then null
        else v_old.approved_at
      end,
      password_hash = case
        when p_new_password is not null and p_new_password <> '' then crypt(p_new_password, gen_salt('bf', 10))
        else v_old.password_hash
      end,
      updated_at = now()
  where id = p_assistant_id
  returning * into v_assistant;

  if v_status <> 'approved' then
    delete from public.sessions where role = 'assistant' and user_id = p_assistant_id;
  end if;

  if v_status = 'approved' and v_old.status <> 'approved' then
    perform public._portal_notify(
      'assistant',
      p_assistant_id,
      'ACCOUNT_APPROVED',
      '{}'::jsonb,
      'approved:assistant:' || p_assistant_id::text
    );
  end if;

  perform public._portal_audit(
    'admin',
    v_session.user_id,
    'assistant.update',
    'assistant',
    p_assistant_id,
    jsonb_build_object(
      'status_before', v_old.status,
      'status_after', v_status,
      'password_reset', (p_new_password is not null and p_new_password <> '')
    )
  );

  return jsonb_build_object(
    'ok', true,
    'assistant', public._portal_assistant_json(v_assistant) || jsonb_build_object(
      'notes', v_assistant.notes,
      'approved_at', v_assistant.approved_at,
      'last_login_at', v_assistant.last_login_at,
      'active_assignments', (
        select count(*)::integer from public.engagements e
        where e.assistant_id = v_assistant.id and e.status = 'active'
      )
    )
  );
end;
$$;

create or replace function public.portal_admin_jobs(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_rows jsonb;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', j.id,
    'title', j.title,
    'description', j.description,
    'schedule', j.schedule,
    'rate', j.assistant_rate,
    'client_id', j.client_id,
    'client_company', c.company,
    'status', j.status,
    'created_at', j.created_at,
    'updated_at', j.updated_at,
    'application_count', (
      select count(*)::integer from public.applications a where a.job_id = j.id
    )
  ) order by j.created_at desc), '[]'::jsonb)
  into v_rows
  from public.jobs j
  left join public.clients c on c.id = j.client_id;

  return jsonb_build_object('ok', true, 'jobs', v_rows);
end;
$$;

create or replace function public.portal_admin_job_save(
  p_token text,
  p_job_id uuid,
  p_title text,
  p_client_id uuid default null,
  p_description text default null,
  p_schedule text default null,
  p_rate numeric default 0,
  p_status text default 'draft'
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_job public.jobs;
  v_status text;
begin
  v_session := public._portal_auth(p_token, 'admin');

  p_title := trim(coalesce(p_title, ''));
  v_status := coalesce(p_status, 'draft');

  if p_title = '' then
    raise exception 'INVALID';
  end if;
  if v_status not in ('draft', 'open', 'paused', 'closed') then
    raise exception 'INVALID';
  end if;
  if coalesce(p_rate, 0) < 0 then
    raise exception 'INVALID';
  end if;
  if p_client_id is not null and not exists (select 1 from public.clients where id = p_client_id) then
    raise exception 'NOT_FOUND';
  end if;

  if p_job_id is null then
    insert into public.jobs (title, description, schedule, assistant_rate, client_id, status)
    values (
      p_title,
      nullif(trim(coalesce(p_description, '')), ''),
      nullif(trim(coalesce(p_schedule, '')), ''),
      coalesce(p_rate, 0),
      p_client_id,
      v_status
    )
    returning * into v_job;
  else
    update public.jobs
    set title = p_title,
        description = nullif(trim(coalesce(p_description, '')), ''),
        schedule = nullif(trim(coalesce(p_schedule, '')), ''),
        assistant_rate = coalesce(p_rate, 0),
        client_id = p_client_id,
        status = v_status,
        updated_at = now()
    where id = p_job_id
    returning * into v_job;

    if not found then
      raise exception 'NOT_FOUND';
    end if;
  end if;

  perform public._portal_audit(
    'admin', v_session.user_id, 'job.save', 'job', v_job.id,
    jsonb_build_object('status', v_job.status, 'title', v_job.title)
  );

  return jsonb_build_object(
    'ok', true,
    'job', jsonb_build_object(
      'id', v_job.id,
      'title', v_job.title,
      'description', v_job.description,
      'schedule', v_job.schedule,
      'rate', v_job.assistant_rate,
      'client_id', v_job.client_id,
      'status', v_job.status,
      'created_at', v_job.created_at
    )
  );
end;
$$;

create or replace function public.portal_admin_job_status(p_token text, p_job_id uuid, p_status text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_job public.jobs;
begin
  v_session := public._portal_auth(p_token, 'admin');

  if p_status not in ('draft', 'open', 'paused', 'closed') then
    raise exception 'INVALID';
  end if;

  update public.jobs
  set status = p_status, updated_at = now()
  where id = p_job_id
  returning * into v_job;

  if not found then
    raise exception 'NOT_FOUND';
  end if;

  perform public._portal_audit(
    'admin', v_session.user_id, 'job.status', 'job', v_job.id,
    jsonb_build_object('status', p_status)
  );

  return jsonb_build_object('ok', true, 'status', v_job.status);
end;
$$;

create or replace function public.portal_admin_applications(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_rows jsonb;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id,
    'status', a.status,
    'note', a.note,
    'created_at', a.created_at,
    'updated_at', a.updated_at,
    'client_id', a.client_id,
    'client_company', c.company,
    'job_id', j.id,
    'job_title', j.title,
    'job_schedule', j.schedule,
    'job_rate', j.assistant_rate,
    'job_status', j.status,
    'assistant', public._portal_assistant_json(ast)
  ) order by a.created_at desc), '[]'::jsonb)
  into v_rows
  from public.applications a
  join public.jobs j on j.id = a.job_id
  join public.assistants ast on ast.id = a.assistant_id
  left join public.clients c on c.id = a.client_id;

  return jsonb_build_object('ok', true, 'applications', v_rows);
end;
$$;

create or replace function public.portal_admin_application_status(
  p_token text,
  p_application_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_app public.applications;
  v_job public.jobs;
begin
  v_session := public._portal_auth(p_token, 'admin');

  if p_status not in ('applied', 'shortlisted', 'rejected') then
    raise exception 'INVALID';
  end if;

  update public.applications
  set status = p_status, updated_at = now()
  where id = p_application_id
  returning * into v_app;

  if not found then
    raise exception 'NOT_FOUND';
  end if;

  select * into v_job from public.jobs where id = v_app.job_id;

  perform public._portal_notify(
    'assistant',
    v_app.assistant_id,
    'APPLICATION_UPDATE',
    jsonb_build_object('job_title', v_job.title, 'status', p_status),
    'application-update:' || v_app.id::text || ':' || p_status
  );

  perform public._portal_audit(
    'admin', v_session.user_id, 'application.status', 'application', v_app.id,
    jsonb_build_object('status', p_status)
  );

  return jsonb_build_object('ok', true, 'status', v_app.status);
end;
$$;

create or replace function public.portal_admin_send_candidates(
  p_token text,
  p_application_ids uuid[],
  p_client_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_client public.clients;
  v_app public.applications;
  v_job public.jobs;
  v_assistant public.assistants;
  v_count integer := 0;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select * into v_client from public.clients where id = p_client_id;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if v_client.status <> 'approved' then
    raise exception 'INVALID';
  end if;
  if p_application_ids is null or cardinality(p_application_ids) = 0 then
    raise exception 'INVALID';
  end if;

  for v_app in
    select * from public.applications
    where id = any (p_application_ids)
    for update
  loop
    if v_app.status not in ('applied', 'shortlisted') then
      continue;
    end if;

    update public.applications
    set status = 'sent', client_id = p_client_id, updated_at = now()
    where id = v_app.id;

    select * into v_job from public.jobs where id = v_app.job_id;
    select * into v_assistant from public.assistants where id = v_app.assistant_id;

    perform public._portal_notify(
      'client',
      p_client_id,
      'CANDIDATE_SENT',
      jsonb_build_object(
        'application_id', v_app.id,
        'assistant_name', v_assistant.first_name,
        'job_title', v_job.title
      ),
      'sent:' || v_app.id::text
    );

    perform public._portal_notify(
      'assistant',
      v_app.assistant_id,
      'APPLICATION_UPDATE',
      jsonb_build_object('job_title', v_job.title, 'status', 'sent'),
      'application-update:' || v_app.id::text || ':sent'
    );

    v_count := v_count + 1;
  end loop;

  if v_count = 0 then
    raise exception 'INVALID';
  end if;

  perform public._portal_audit(
    'admin', v_session.user_id, 'application.send', 'client', p_client_id,
    jsonb_build_object('count', v_count)
  );

  return jsonb_build_object('ok', true, 'count', v_count);
end;
$$;

create or replace function public.portal_admin_engagements(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_rows jsonb;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'client_id', e.client_id,
    'client_company', c.company,
    'client_contact', c.contact_name,
    'assistant_id', e.assistant_id,
    'assistant', public._portal_assistant_json(a),
    'job_id', e.job_id,
    'job_title', j.title,
    'client_rate', e.client_rate,
    'assistant_rate', e.assistant_rate,
    'margin', round(e.client_rate - e.assistant_rate, 2),
    'work_days', e.work_days,
    'start_date', e.start_date,
    'end_date', e.end_date,
    'status', e.status,
    'minutes', coalesce((select sum(t.minutes) from public.time_entries t where t.engagement_id = e.id), 0)
  ) order by e.status, e.created_at desc), '[]'::jsonb)
  into v_rows
  from public.engagements e
  join public.clients c on c.id = e.client_id
  join public.assistants a on a.id = e.assistant_id
  left join public.jobs j on j.id = e.job_id;

  return jsonb_build_object('ok', true, 'engagements', v_rows);
end;
$$;

create or replace function public.portal_admin_engagement_create(
  p_token text,
  p_client_id uuid,
  p_assistant_id uuid,
  p_client_rate numeric,
  p_assistant_rate numeric,
  p_work_days integer[] default '{1,2,3,4,5}',
  p_start_date date default null,
  p_end_date date default null,
  p_job_id uuid default null,
  p_application_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_client public.clients;
  v_assistant public.assistants;
  v_engagement public.engagements;
  v_days integer[];
  v_start date;
  v_capacity boolean;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select * into v_client from public.clients where id = p_client_id;
  if not found or v_client.status <> 'approved' then
    raise exception 'NOT_FOUND';
  end if;

  select * into v_assistant from public.assistants where id = p_assistant_id;
  if not found or v_assistant.status <> 'approved' then
    raise exception 'NOT_FOUND';
  end if;

  if coalesce(p_client_rate, -1) < 0 or coalesce(p_assistant_rate, -1) < 0 then
    raise exception 'INVALID';
  end if;
  if p_assistant_rate > p_client_rate then
    raise exception 'INVALID';
  end if;

  select coalesce(array_agg(d order by d), '{}')
  into v_days
  from unnest(coalesce(p_work_days, '{1,2,3,4,5}')) d
  where d between 1 and 7;

  if cardinality(v_days) = 0 then
    raise exception 'INVALID';
  end if;

  v_start := coalesce(p_start_date, public._portal_today(v_client.timezone));
  if p_end_date is not null and p_end_date < v_start then
    raise exception 'INVALID';
  end if;

  v_capacity := exists (
    select 1 from public.engagements
    where assistant_id = p_assistant_id and status = 'active'
  );

  insert into public.engagements (
    client_id, assistant_id, job_id, application_id,
    client_rate, assistant_rate, work_days, start_date, end_date
  )
  values (
    p_client_id, p_assistant_id, p_job_id, p_application_id,
    p_client_rate, p_assistant_rate, v_days, v_start, p_end_date
  )
  returning * into v_engagement;

  if p_application_id is not null then
    update public.applications
    set status = 'hired', client_id = p_client_id, updated_at = now()
    where id = p_application_id;
  end if;

  perform public._portal_notify(
    'assistant',
    p_assistant_id,
    'PLACEMENT_STARTED',
    jsonb_build_object(
      'company', v_client.company,
      'rate', v_engagement.assistant_rate,
      'start_date', v_engagement.start_date
    ),
    'placement:' || v_engagement.id::text
  );

  perform public._portal_notify(
    'client',
    p_client_id,
    'PLACEMENT_CREATED',
    jsonb_build_object(
      'assistant_name', v_assistant.first_name,
      'rate', v_engagement.client_rate,
      'start_date', v_engagement.start_date
    ),
    'placement-client:' || v_engagement.id::text
  );

  perform public._portal_audit(
    'admin', v_session.user_id, 'engagement.create', 'engagement', v_engagement.id,
    jsonb_build_object(
      'client_rate', v_engagement.client_rate,
      'assistant_rate', v_engagement.assistant_rate,
      'capacity_warning', v_capacity
    )
  );

  return jsonb_build_object(
    'ok', true,
    'engagement', jsonb_build_object(
      'id', v_engagement.id,
      'client_id', v_engagement.client_id,
      'assistant_id', v_engagement.assistant_id,
      'client_rate', v_engagement.client_rate,
      'assistant_rate', v_engagement.assistant_rate,
      'work_days', v_engagement.work_days,
      'start_date', v_engagement.start_date,
      'end_date', v_engagement.end_date,
      'status', v_engagement.status
    ),
    'capacity_warning', v_capacity
  );
end;
$$;

create or replace function public.portal_admin_engagement_end(
  p_token text,
  p_engagement_id uuid,
  p_end_date date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_engagement public.engagements;
  v_client public.clients;
  v_assistant public.assistants;
  v_end date;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select * into v_engagement from public.engagements where id = p_engagement_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;

  v_end := coalesce(p_end_date, current_date);
  if v_end < v_engagement.start_date then
    raise exception 'INVALID';
  end if;

  update public.engagements
  set status = 'ended', end_date = v_end, updated_at = now()
  where id = p_engagement_id
  returning * into v_engagement;

  select * into v_client from public.clients where id = v_engagement.client_id;
  select * into v_assistant from public.assistants where id = v_engagement.assistant_id;

  perform public._portal_notify(
    'assistant',
    v_engagement.assistant_id,
    'PLACEMENT_ENDED',
    jsonb_build_object('company', v_client.company, 'end_date', v_engagement.end_date),
    'placement-end:' || v_engagement.id::text
  );

  perform public._portal_notify(
    'client',
    v_engagement.client_id,
    'PLACEMENT_ENDED_CLIENT',
    jsonb_build_object('assistant_name', v_assistant.first_name, 'end_date', v_engagement.end_date),
    'placement-end-client:' || v_engagement.id::text
  );

  perform public._portal_audit(
    'admin', v_session.user_id, 'engagement.end', 'engagement', v_engagement.id,
    jsonb_build_object('end_date', v_engagement.end_date)
  );

  return jsonb_build_object('ok', true, 'status', v_engagement.status, 'end_date', v_engagement.end_date);
end;
$$;

create or replace function public.portal_admin_time(
  p_token text,
  p_from date default null,
  p_to date default null,
  p_assistant_id uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_today date;
  v_from date;
  v_to date;
  v_rows jsonb;
  v_total integer;
begin
  v_session := public._portal_auth(p_token, 'admin');

  v_today := public._portal_today((select value from public.settings where key = 'timezone'));
  v_from := coalesce(p_from, date_trunc('month', v_today)::date);
  v_to := coalesce(p_to, (date_trunc('month', v_today) + interval '1 month - 1 day')::date);

  if v_to < v_from then
    raise exception 'INVALID';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', t.id,
    'date', t.work_date,
    'start_time', t.start_time,
    'end_time', t.end_time,
    'minutes', t.minutes,
    'engagement_id', t.engagement_id,
    'client_company', c.company,
    'job_title', j.title,
    'assistant', public._portal_assistant_json(a)
  ) order by t.work_date desc, t.start_time), '[]'::jsonb),
  coalesce(sum(t.minutes), 0)::integer
  into v_rows, v_total
  from public.time_entries t
  join public.engagements e on e.id = t.engagement_id
  join public.assistants a on a.id = t.assistant_id
  join public.clients c on c.id = t.client_id
  left join public.jobs j on j.id = e.job_id
  where t.work_date between v_from and v_to
    and (p_assistant_id is null or t.assistant_id = p_assistant_id);

  return jsonb_build_object(
    'ok', true,
    'from', v_from,
    'to', v_to,
    'entries', v_rows,
    'total_minutes', v_total
  );
end;
$$;

create or replace function public.portal_admin_time_update(
  p_token text,
  p_entry_id uuid,
  p_date date,
  p_start time,
  p_end time,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_old public.time_entries;
  v_entry public.time_entries;
  v_assistant public.assistants;
  v_today date;
  v_minutes integer;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select * into v_old from public.time_entries where id = p_entry_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;

  if trim(coalesce(p_reason, '')) = '' then
    raise exception 'INVALID';
  end if;

  select * into v_assistant from public.assistants where id = v_old.assistant_id;
  v_today := public._portal_today(v_assistant.timezone);

  if p_date is null or p_start is null or p_end is null then
    raise exception 'INVALID';
  end if;
  if p_date > v_today then
    raise exception 'FUTURE_DATE';
  end if;
  if p_end <= p_start then
    raise exception 'INVALID_TIME';
  end if;

  perform public._portal_assert_no_overlap(v_old.assistant_id, p_date, p_start, p_end, p_entry_id);

  v_minutes := floor(extract(epoch from (p_end - p_start)) / 60)::integer;
  if v_minutes <= 0 then
    raise exception 'INVALID_TIME';
  end if;

  update public.time_entries
  set work_date = p_date,
      start_time = p_start,
      end_time = p_end,
      minutes = v_minutes,
      source = 'admin',
      updated_at = now()
  where id = p_entry_id
  returning * into v_entry;

  perform public._portal_notify(
    'assistant',
    v_entry.assistant_id,
    'HOURS_UPDATED',
    jsonb_build_object('date', v_entry.work_date, 'minutes', v_entry.minutes, 'reason', trim(p_reason)),
    null
  );

  perform public._portal_audit(
    'admin', v_session.user_id, 'time.update', 'time_entry', p_entry_id,
    jsonb_build_object(
      'before', jsonb_build_object('date', v_old.work_date, 'start', v_old.start_time, 'end', v_old.end_time, 'minutes', v_old.minutes),
      'after', jsonb_build_object('date', v_entry.work_date, 'start', v_entry.start_time, 'end', v_entry.end_time, 'minutes', v_entry.minutes),
      'reason', trim(p_reason)
    )
  );

  return jsonb_build_object(
    'ok', true,
    'entry', jsonb_build_object(
      'id', v_entry.id,
      'date', v_entry.work_date,
      'start_time', v_entry.start_time,
      'end_time', v_entry.end_time,
      'minutes', v_entry.minutes
    )
  );
end;
$$;

create or replace function public.portal_admin_time_delete(
  p_token text,
  p_entry_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_entry public.time_entries;
begin
  v_session := public._portal_auth(p_token, 'admin');

  select * into v_entry from public.time_entries where id = p_entry_id for update;
  if not found then
    raise exception 'NOT_FOUND';
  end if;
  if trim(coalesce(p_reason, '')) = '' then
    raise exception 'INVALID';
  end if;

  delete from public.time_entries where id = p_entry_id;

  perform public._portal_notify(
    'assistant',
    v_entry.assistant_id,
    'HOURS_DELETED',
    jsonb_build_object('date', v_entry.work_date, 'minutes', v_entry.minutes, 'reason', trim(p_reason)),
    null
  );

  perform public._portal_audit(
    'admin', v_session.user_id, 'time.delete', 'time_entry', p_entry_id,
    jsonb_build_object(
      'date', v_entry.work_date,
      'start', v_entry.start_time,
      'end', v_entry.end_time,
      'minutes', v_entry.minutes,
      'reason', trim(p_reason)
    )
  );

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.portal_admin_billing(
  p_token text,
  p_from date default null,
  p_to date default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_today date;
  v_from date;
  v_to date;
  v_rows jsonb;
  v_minutes integer;
  v_client_amount numeric;
  v_assistant_pay numeric;
begin
  v_session := public._portal_auth(p_token, 'admin');

  v_today := public._portal_today((select value from public.settings where key = 'timezone'));
  v_from := coalesce(p_from, date_trunc('month', v_today)::date);
  v_to := coalesce(p_to, (date_trunc('month', v_today) + interval '1 month - 1 day')::date);

  if v_to < v_from then
    raise exception 'INVALID';
  end if;

  select coalesce(jsonb_agg(row_to_json(x) order by x.client_company, x.assistant_name), '[]'::jsonb),
         coalesce(sum(x.minutes), 0)::integer,
         coalesce(round(sum(x.client_amount), 2), 0),
         coalesce(round(sum(x.assistant_pay), 2), 0)
  into v_rows, v_minutes, v_client_amount, v_assistant_pay
  from (
    select
      e.id as engagement_id,
      c.company as client_company,
      a.first_name as assistant_name,
      a.code as assistant_code,
      a.photo_url,
      j.title as job_title,
      e.client_rate,
      e.assistant_rate,
      sum(t.minutes)::integer as minutes,
      round(sum(t.minutes / 60.0 * e.client_rate), 2) as client_amount,
      round(sum(t.minutes / 60.0 * e.assistant_rate), 2) as assistant_pay,
      round(sum(t.minutes / 60.0 * (e.client_rate - e.assistant_rate)), 2) as margin
    from public.time_entries t
    join public.engagements e on e.id = t.engagement_id
    join public.clients c on c.id = e.client_id
    join public.assistants a on a.id = e.assistant_id
    left join public.jobs j on j.id = e.job_id
    where t.work_date between v_from and v_to
    group by e.id, c.company, a.first_name, a.code, a.photo_url, j.title, e.client_rate, e.assistant_rate
  ) x;

  return jsonb_build_object(
    'ok', true,
    'from', v_from,
    'to', v_to,
    'rows', v_rows,
    'total_minutes', v_minutes,
    'client_amount', v_client_amount,
    'assistant_pay', v_assistant_pay,
    'margin', round(v_client_amount - v_assistant_pay, 2)
  );
end;
$$;

create or replace function public.portal_admin_settings(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_admin public.admins;
begin
  v_session := public._portal_auth(p_token, 'admin');
  select * into v_admin from public.admins where id = v_session.user_id;

  return jsonb_build_object(
    'ok', true,
    'profile', public._portal_admin_json(v_admin),
    'fx_rate', public._portal_fx(),
    'timezone', (select value from public.settings where key = 'timezone')
  );
end;
$$;

create or replace function public.portal_admin_settings_save(
  p_token text,
  p_fx_rate numeric,
  p_timezone text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_fx numeric;
begin
  v_session := public._portal_auth(p_token, 'admin');

  if p_fx_rate is null or p_fx_rate <= 0 or p_fx_rate > 1000 then
    raise exception 'INVALID';
  end if;
  if p_timezone is not null and trim(p_timezone) <> '' and not exists (
    select 1 from pg_timezone_names where name = trim(p_timezone)
  ) then
    raise exception 'INVALID';
  end if;

  insert into public.settings (key, value, updated_at)
  values ('fx_rate', p_fx_rate::text, now())
  on conflict (key) do update set value = excluded.value, updated_at = now()
  returning value::numeric into v_fx;

  if p_timezone is not null and trim(p_timezone) <> '' then
    insert into public.settings (key, value, updated_at)
    values ('timezone', trim(p_timezone), now())
    on conflict (key) do update set value = excluded.value, updated_at = now();
  end if;

  perform public._portal_audit(
    'admin', v_session.user_id, 'settings.save', 'settings', null,
    jsonb_build_object('fx_rate', v_fx, 'timezone', p_timezone)
  );

  return jsonb_build_object(
    'ok', true,
    'fx_rate', v_fx,
    'timezone', (select value from public.settings where key = 'timezone')
  );
end;
$$;

create or replace function public.portal_admin_change_password(
  p_token text,
  p_current_password text,
  p_new_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_session public.sessions;
  v_admin public.admins;
begin
  v_session := public._portal_auth(p_token, 'admin');
  select * into v_admin from public.admins where id = v_session.user_id;

  if p_current_password is null or v_admin.password_hash <> crypt(p_current_password, v_admin.password_hash) then
    raise exception 'INVALID_CREDENTIALS';
  end if;
  if p_new_password is null or length(p_new_password) < 8 then
    raise exception 'PASSWORD_WEAK';
  end if;

  update public.admins
  set password_hash = crypt(p_new_password, gen_salt('bf', 10)), updated_at = now()
  where id = v_admin.id;

  perform public._portal_audit('admin', v_admin.id, 'admin.password', 'admin', v_admin.id, '{}'::jsonb);

  return jsonb_build_object('ok', true);
end;
$$;

do $$
begin
  if to_regclass('storage.objects') is not null then
    insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    values ('avatars', 'avatars', true, 2097152, array['image/jpeg', 'image/png', 'image/webp'])
    on conflict (id) do update
    set public = excluded.public,
        file_size_limit = excluded.file_size_limit,
        allowed_mime_types = excluded.allowed_mime_types;

    begin
      create policy "kg_avatars_anon_insert" on storage.objects
      for insert to anon
      with check (bucket_id = 'avatars');
    exception when duplicate_object then null;
    end;

    begin
      create policy "kg_avatars_public_read" on storage.objects
      for select to anon, authenticated
      using (bucket_id = 'avatars');
    exception when duplicate_object then null;
    end;
  end if;
end $$;

alter table public.admins enable row level security;
alter table public.sessions enable row level security;
alter table public.settings enable row level security;
alter table public.clients enable row level security;
alter table public.assistants enable row level security;
alter table public.jobs enable row level security;
alter table public.applications enable row level security;
alter table public.engagements enable row level security;
alter table public.time_entries enable row level security;
alter table public.missing_day_dismissals enable row level security;
alter table public.notifications enable row level security;
alter table public.audit_log enable row level security;

revoke all on table public.admins from anon, authenticated;
revoke all on table public.sessions from anon, authenticated;
revoke all on table public.settings from anon, authenticated;
revoke all on table public.clients from anon, authenticated;
revoke all on table public.assistants from anon, authenticated;
revoke all on table public.jobs from anon, authenticated;
revoke all on table public.applications from anon, authenticated;
revoke all on table public.engagements from anon, authenticated;
revoke all on table public.time_entries from anon, authenticated;
revoke all on table public.missing_day_dismissals from anon, authenticated;
revoke all on table public.notifications from anon, authenticated;
revoke all on table public.audit_log from anon, authenticated;
revoke all on sequence public.assistant_code_seq from anon, authenticated;

revoke execute on all functions in schema public from public, anon, authenticated;

grant usage on schema public to anon, authenticated;

grant execute on function public.portal_health() to anon;
grant execute on function public.portal_signup_client(text, text, text, text, text, text, text) to anon;
grant execute on function public.portal_signup_assistant(text, text, text, text, text, text[], text[], text[], text, text, text, text, text, text) to anon;
grant execute on function public.portal_login(text, text) to anon;
grant execute on function public.portal_admin_login(text, text) to anon;
grant execute on function public.portal_logout(text) to anon;
grant execute on function public.portal_session(text) to anon;
grant execute on function public.portal_mark_notifications(text, uuid[]) to anon;

grant execute on function public.portal_client_profile(text) to anon;
grant execute on function public.portal_client_update_profile(text, text, text, text, text, text) to anon;
grant execute on function public.portal_client_dashboard(text) to anon;
grant execute on function public.portal_client_candidates(text) to anon;
grant execute on function public.portal_client_select_candidate(text, uuid) to anon;
grant execute on function public.portal_client_engagements(text) to anon;
grant execute on function public.portal_client_time(text, date, date) to anon;
grant execute on function public.portal_client_statements(text, date, date) to anon;

grant execute on function public.portal_assistant_profile(text) to anon;
grant execute on function public.portal_assistant_update_profile(text, text, text, text, text[], text[], text[], text, text, text, text, text, text) to anon;
grant execute on function public.portal_assistant_dashboard(text) to anon;
grant execute on function public.portal_assistant_jobs(text) to anon;
grant execute on function public.portal_assistant_apply(text, uuid, text) to anon;
grant execute on function public.portal_assistant_applications(text) to anon;
grant execute on function public.portal_assistant_time(text, date, date) to anon;
grant execute on function public.portal_assistant_add_time(text, date, time, time, uuid) to anon;
grant execute on function public.portal_assistant_delete_time(text, uuid) to anon;
grant execute on function public.portal_assistant_ignore_missing(text, uuid, date) to anon;
grant execute on function public.portal_assistant_earnings(text, date, date) to anon;

grant execute on function public.portal_admin_dashboard(text) to anon;
grant execute on function public.portal_admin_clients(text) to anon;
grant execute on function public.portal_admin_client_save(text, uuid, text, text, text, text, text, text, text, text) to anon;
grant execute on function public.portal_admin_assistants(text) to anon;
grant execute on function public.portal_admin_assistant_save(text, uuid, text, text, text, text, text, text, text, text, text) to anon;
grant execute on function public.portal_admin_jobs(text) to anon;
grant execute on function public.portal_admin_job_save(text, uuid, text, uuid, text, text, numeric, text) to anon;
grant execute on function public.portal_admin_job_status(text, uuid, text) to anon;
grant execute on function public.portal_admin_applications(text) to anon;
grant execute on function public.portal_admin_application_status(text, uuid, text) to anon;
grant execute on function public.portal_admin_send_candidates(text, uuid[], uuid) to anon;
grant execute on function public.portal_admin_engagements(text) to anon;
grant execute on function public.portal_admin_engagement_create(text, uuid, uuid, numeric, numeric, integer[], date, date, uuid, uuid) to anon;
grant execute on function public.portal_admin_engagement_end(text, uuid, date) to anon;
grant execute on function public.portal_admin_time(text, date, date, uuid) to anon;
grant execute on function public.portal_admin_time_update(text, uuid, date, time, time, text) to anon;
grant execute on function public.portal_admin_time_delete(text, uuid, text) to anon;
grant execute on function public.portal_admin_billing(text, date, date) to anon;
grant execute on function public.portal_admin_settings(text) to anon;
grant execute on function public.portal_admin_settings_save(text, numeric, text) to anon;
grant execute on function public.portal_admin_change_password(text, text, text) to anon;
