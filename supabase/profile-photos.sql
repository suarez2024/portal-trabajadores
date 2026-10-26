alter table public.admins add column if not exists photo_url text;
alter table public.clients add column if not exists photo_url text;

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
    'photo_url', c.photo_url,
    'status', c.status,
    'created_at', c.created_at
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
    'username', a.username,
    'photo_url', a.photo_url
  );
$$;

create or replace function public.portal_client_update_photo(p_token text, p_photo_url text)
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

  update public.clients
  set photo_url = nullif(trim(coalesce(p_photo_url, '')), ''),
      updated_at = now()
  where id = v_session.user_id
  returning * into v_client;

  perform public._portal_audit(
    'client', v_session.user_id, 'profile.photo', 'clients', v_session.user_id,
    jsonb_build_object('photo_url', v_client.photo_url)
  );

  return jsonb_build_object('ok', true, 'profile', public._portal_client_json(v_client));
end;
$$;

create or replace function public.portal_assistant_update_photo(p_token text, p_photo_url text)
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

  update public.assistants
  set photo_url = nullif(trim(coalesce(p_photo_url, '')), ''),
      updated_at = now()
  where id = v_session.user_id
  returning * into v_assistant;

  perform public._portal_audit(
    'assistant', v_session.user_id, 'profile.photo', 'assistants', v_session.user_id,
    jsonb_build_object('photo_url', v_assistant.photo_url)
  );

  return jsonb_build_object('ok', true, 'profile', public._portal_assistant_json(v_assistant));
end;
$$;

create or replace function public.portal_admin_update_photo(p_token text, p_photo_url text)
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

  update public.admins
  set photo_url = nullif(trim(coalesce(p_photo_url, '')), ''),
      updated_at = now()
  where id = v_session.user_id
  returning * into v_admin;

  perform public._portal_audit(
    'admin', v_session.user_id, 'profile.photo', 'admins', v_session.user_id,
    jsonb_build_object('photo_url', v_admin.photo_url)
  );

  return jsonb_build_object('ok', true, 'profile', public._portal_admin_json(v_admin));
end;
$$;

revoke execute on function public.portal_client_update_photo(text, text) from public;
revoke execute on function public.portal_assistant_update_photo(text, text) from public;
revoke execute on function public.portal_admin_update_photo(text, text) from public;

grant execute on function public.portal_client_update_photo(text, text) to anon;
grant execute on function public.portal_assistant_update_photo(text, text) to anon;
grant execute on function public.portal_admin_update_photo(text, text) to anon;

notify pgrst, 'reload schema';
