create extension if not exists pgcrypto;

create table if not exists public.admins (
  id uuid primary key default gen_random_uuid(),
  usuario text unique not null,
  password_hash text not null,
  creado_en timestamptz not null default now()
);

create table if not exists public.sesiones (
  token uuid primary key default gen_random_uuid(),
  rol text not null check (rol in ('admin', 'cliente', 'trabajador')),
  ref_id uuid,
  expira_en timestamptz not null default (now() + interval '12 hours'),
  creado_en timestamptz not null default now()
);

create index if not exists sesiones_expira_en_idx on public.sesiones (expira_en);

alter table public.trabajadores
  add column if not exists archivado boolean not null default false,
  add column if not exists archivado_en timestamptz;

alter table public.jornadas
  add column if not exists tarifa_hora numeric,
  add column if not exists cliente_id uuid;

update public.jornadas j
set tarifa_hora = coalesce(j.tarifa_hora, t.tarifa_hora),
    cliente_id = coalesce(j.cliente_id, t.cliente_id)
from public.trabajadores t
where t.id = j.trabajador_id
  and (j.tarifa_hora is null or j.cliente_id is null);

create index if not exists trabajadores_archivado_idx on public.trabajadores (archivado);
create index if not exists jornadas_cliente_idx on public.jornadas (cliente_id);

insert into public.admins (usuario, password_hash)
values ('Admin', extensions.crypt('Admin2026', extensions.gen_salt('bf')))
on conflict (usuario) do nothing;

update public.clientes
set password = extensions.crypt(password, extensions.gen_salt('bf'))
where password !~ '^\$2[aby]\$';

update public.trabajadores
set password = extensions.crypt(password, extensions.gen_salt('bf'))
where password !~ '^\$2[aby]\$';

alter table public.clientes enable row level security;
alter table public.trabajadores enable row level security;
alter table public.jornadas enable row level security;
alter table public.admins enable row level security;
alter table public.sesiones enable row level security;

revoke all on table public.clientes from anon, authenticated;
revoke all on table public.trabajadores from anon, authenticated;
revoke all on table public.jornadas from anon, authenticated;
revoke all on table public.admins from anon, authenticated;
revoke all on table public.sesiones from anon, authenticated;

create or replace function public.portal_ping()
returns text
language sql
security definer
set search_path = public, extensions
as $$
  select 'ok'::text;
$$;

create or replace function public.portal_token(p_token uuid)
returns public.sesiones
language sql
security definer
set search_path = public, extensions
as $$
  select *
  from public.sesiones
  where token = p_token
    and expira_en > now()
  limit 1;
$$;

create or replace function public.portal_login(p_email text, p_password text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_trabajador public.trabajadores%rowtype;
  v_cliente public.clientes%rowtype;
  v_token uuid;
begin
  if coalesce(trim(p_email), '') = '' or coalesce(p_password, '') = '' then
    return jsonb_build_object('ok', false, 'error', 'Escribe tu email y contraseña.');
  end if;

  select * into v_trabajador
  from public.trabajadores
  where lower(email) = lower(trim(p_email))
  limit 1;

  if found then
    if v_trabajador.activo is distinct from true or v_trabajador.archivado then
      return jsonb_build_object('ok', false, 'error', 'Tu cuenta está desactivada. Contacta al administrador.');
    end if;
    if v_trabajador.password = crypt(p_password, v_trabajador.password) then
      delete from public.sesiones where expira_en <= now();
      insert into public.sesiones (rol, ref_id)
      values ('trabajador', v_trabajador.id)
      returning token into v_token;
      return jsonb_build_object(
        'ok', true,
        'rol', 'trabajador',
        'token', v_token,
        'usuario', to_jsonb(v_trabajador) - 'password'
      );
    end if;
    return jsonb_build_object('ok', false, 'error', 'Credenciales incorrectas.');
  end if;

  select * into v_cliente
  from public.clientes
  where lower(email) = lower(trim(p_email))
  limit 1;

  if found and v_cliente.password = crypt(p_password, v_cliente.password) then
    delete from public.sesiones where expira_en <= now();
    insert into public.sesiones (rol, ref_id)
    values ('cliente', v_cliente.id)
    returning token into v_token;
    return jsonb_build_object(
      'ok', true,
      'rol', 'cliente',
      'token', v_token,
      'usuario', to_jsonb(v_cliente) - 'password'
    );
  end if;

  return jsonb_build_object('ok', false, 'error', 'Credenciales incorrectas.');
end;
$$;

create or replace function public.portal_admin_login(p_usuario text, p_password text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_admin public.admins%rowtype;
  v_token uuid;
begin
  if coalesce(trim(p_usuario), '') = '' or coalesce(p_password, '') = '' then
    return jsonb_build_object('ok', false, 'error', 'Escribe usuario y contraseña.');
  end if;

  select * into v_admin
  from public.admins
  where lower(usuario) = lower(trim(p_usuario))
  limit 1;

  if found and v_admin.password_hash = crypt(p_password, v_admin.password_hash) then
    delete from public.sesiones where expira_en <= now();
    insert into public.sesiones (rol)
    values ('admin')
    returning token into v_token;
    return jsonb_build_object(
      'ok', true,
      'token', v_token,
      'usuario', jsonb_build_object('nombre', 'Admin', 'usuario', v_admin.usuario)
    );
  end if;

  return jsonb_build_object('ok', false, 'error', 'Credenciales incorrectas.');
end;
$$;

create or replace function public.portal_logout(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  delete from public.sesiones where token = p_token;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.portal_admin_resumen(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;
  if v_sesion.rol <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  return jsonb_build_object(
    'ok', true,
    'clientes', coalesce((
      select jsonb_agg(to_jsonb(c) - 'password' order by c.creado_en)
      from public.clientes c
    ), '[]'::jsonb),
    'trabajadores', coalesce((
      select jsonb_agg(
        (to_jsonb(t) - 'password') || jsonb_build_object('cliente_nombre', coalesce(c.empresa, '—'))
        order by t.creado_en
      )
      from public.trabajadores t
      left join public.clientes c on c.id = t.cliente_id
    ), '[]'::jsonb),
    'jornadas', coalesce((
      select jsonb_agg(
        to_jsonb(j) || jsonb_build_object(
          'trabajador_nombre', t.nombre,
          'tarifa_hora', coalesce(j.tarifa_hora, t.tarifa_hora),
          'cliente_id', coalesce(j.cliente_id, t.cliente_id),
          'cliente_nombre', coalesce(c.empresa, '—')
        )
        order by j.fecha desc, j.creado_en desc
      )
      from public.jornadas j
      join public.trabajadores t on t.id = j.trabajador_id
      left join public.clientes c on c.id = coalesce(j.cliente_id, t.cliente_id)
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.portal_admin_crear_cliente(
  p_token uuid,
  p_nombre text,
  p_empresa text,
  p_email text,
  p_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
  v_cliente public.clientes%rowtype;
  v_email text := lower(trim(p_email));
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  if coalesce(trim(p_nombre), '') = '' or coalesce(trim(p_empresa), '') = ''
     or coalesce(trim(p_email), '') = '' or coalesce(p_password, '') = '' then
    return jsonb_build_object('ok', false, 'error', 'Completa todos los campos.');
  end if;

  if length(p_password) < 6 then
    return jsonb_build_object('ok', false, 'error', 'La contraseña debe tener al menos 6 caracteres.');
  end if;

  if exists (select 1 from public.clientes where lower(email) = v_email)
     or exists (select 1 from public.trabajadores where lower(email) = v_email) then
    return jsonb_build_object('ok', false, 'error', 'Ese email ya está registrado.');
  end if;

  insert into public.clientes (nombre, empresa, email, password)
  values (trim(p_nombre), trim(p_empresa), v_email, crypt(p_password, gen_salt('bf')))
  returning * into v_cliente;

  return jsonb_build_object(
    'ok', true,
    'cliente', to_jsonb(v_cliente) - 'password'
  );
end;
$$;

create or replace function public.portal_admin_crear_trabajador(
  p_token uuid,
  p_nombre text,
  p_email text,
  p_password text,
  p_tarifa numeric,
  p_cliente_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
  v_trabajador public.trabajadores%rowtype;
  v_cliente public.clientes%rowtype;
  v_email text := lower(trim(p_email));
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  if coalesce(trim(p_nombre), '') = '' or coalesce(trim(p_email), '') = ''
     or coalesce(p_password, '') = '' or p_cliente_id is null then
    return jsonb_build_object('ok', false, 'error', 'Completa todos los campos y asigna un cliente.');
  end if;

  if length(p_password) < 6 then
    return jsonb_build_object('ok', false, 'error', 'La contraseña debe tener al menos 6 caracteres.');
  end if;

  if p_tarifa is null or p_tarifa <= 0 then
    return jsonb_build_object('ok', false, 'error', 'La tarifa debe ser mayor que cero.');
  end if;

  select * into v_cliente from public.clientes where id = p_cliente_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'El cliente seleccionado no existe.');
  end if;

  if exists (select 1 from public.clientes where lower(email) = v_email)
     or exists (select 1 from public.trabajadores where lower(email) = v_email) then
    return jsonb_build_object('ok', false, 'error', 'Ese email ya está registrado.');
  end if;

  insert into public.trabajadores (nombre, email, password, tarifa_hora, cliente_id, activo)
  values (trim(p_nombre), v_email, crypt(p_password, gen_salt('bf')), p_tarifa, p_cliente_id, true)
  returning * into v_trabajador;

  return jsonb_build_object(
    'ok', true,
    'trabajador', (to_jsonb(v_trabajador) - 'password') || jsonb_build_object('cliente_nombre', v_cliente.empresa)
  );
end;
$$;

create or replace function public.portal_admin_actualizar_cliente(
  p_token uuid,
  p_cliente_id uuid,
  p_nombre text,
  p_empresa text,
  p_email text,
  p_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
  v_cliente public.clientes%rowtype;
  v_email text := coalesce(lower(trim(p_email)), '');
  v_password text := nullif(trim(p_password), '');
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  if not exists (select 1 from public.clientes where id = p_cliente_id) then
    return jsonb_build_object('ok', false, 'error', 'El cliente no existe.');
  end if;

  if coalesce(trim(p_nombre), '') = '' or coalesce(trim(p_empresa), '') = '' or v_email = '' then
    return jsonb_build_object('ok', false, 'error', 'Completa nombre, empresa y email.');
  end if;

  if v_password is not null and length(v_password) < 6 then
    return jsonb_build_object('ok', false, 'error', 'La contraseña debe tener al menos 6 caracteres.');
  end if;

  if exists (select 1 from public.clientes where lower(email) = v_email and id <> p_cliente_id)
     or exists (select 1 from public.trabajadores where lower(email) = v_email) then
    return jsonb_build_object('ok', false, 'error', 'Ese email ya está registrado.');
  end if;

  update public.clientes
  set nombre = trim(p_nombre),
      empresa = trim(p_empresa),
      email = v_email
  where id = p_cliente_id;

  if v_password is not null then
    update public.clientes
    set password = crypt(v_password, gen_salt('bf'))
    where id = p_cliente_id;
    delete from public.sesiones where rol = 'cliente' and ref_id = p_cliente_id;
  end if;

  select * into v_cliente from public.clientes where id = p_cliente_id;

  return jsonb_build_object('ok', true, 'cliente', to_jsonb(v_cliente) - 'password');
end;
$$;

create or replace function public.portal_admin_actualizar_trabajador(
  p_token uuid,
  p_trabajador_id uuid,
  p_nombre text,
  p_email text,
  p_tarifa numeric,
  p_cliente_id uuid,
  p_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
  v_trabajador public.trabajadores%rowtype;
  v_cliente public.clientes%rowtype;
  v_email text := coalesce(lower(trim(p_email)), '');
  v_password text := nullif(trim(p_password), '');
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  select * into v_trabajador from public.trabajadores where id = p_trabajador_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'El trabajador no existe.');
  end if;

  if coalesce(trim(p_nombre), '') = '' or v_email = '' or p_cliente_id is null then
    return jsonb_build_object('ok', false, 'error', 'Completa nombre, email y cliente.');
  end if;

  if p_tarifa is null or p_tarifa <= 0 then
    return jsonb_build_object('ok', false, 'error', 'La tarifa debe ser mayor que cero.');
  end if;

  if v_password is not null and length(v_password) < 6 then
    return jsonb_build_object('ok', false, 'error', 'La contraseña debe tener al menos 6 caracteres.');
  end if;

  select * into v_cliente from public.clientes where id = p_cliente_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'El cliente seleccionado no existe.');
  end if;

  if exists (select 1 from public.clientes where lower(email) = v_email)
     or exists (select 1 from public.trabajadores where lower(email) = v_email and id <> p_trabajador_id) then
    return jsonb_build_object('ok', false, 'error', 'Ese email ya está registrado.');
  end if;

  update public.trabajadores
  set nombre = trim(p_nombre),
      email = v_email,
      tarifa_hora = p_tarifa,
      cliente_id = p_cliente_id
  where id = p_trabajador_id;

  if v_password is not null then
    update public.trabajadores
    set password = crypt(v_password, gen_salt('bf'))
    where id = p_trabajador_id;
    delete from public.sesiones where rol = 'trabajador' and ref_id = p_trabajador_id;
  end if;

  select * into v_trabajador from public.trabajadores where id = p_trabajador_id;

  return jsonb_build_object(
    'ok', true,
    'trabajador', (to_jsonb(v_trabajador) - 'password') || jsonb_build_object('cliente_nombre', v_cliente.empresa)
  );
end;
$$;

create or replace function public.portal_admin_archivar_trabajador(
  p_token uuid,
  p_trabajador_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
  v_trabajador public.trabajadores%rowtype;
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  select * into v_trabajador from public.trabajadores where id = p_trabajador_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'El trabajador no existe.');
  end if;

  if v_trabajador.archivado then
    return jsonb_build_object('ok', true);
  end if;

  if v_trabajador.activo is distinct from false then
    return jsonb_build_object('ok', false, 'error', 'Desactiva al trabajador antes de archivarlo.');
  end if;

  update public.trabajadores
  set archivado = true,
      archivado_en = now()
  where id = p_trabajador_id;

  delete from public.sesiones where rol = 'trabajador' and ref_id = p_trabajador_id;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.portal_admin_restaurar_trabajador(
  p_token uuid,
  p_trabajador_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  update public.trabajadores
  set archivado = false,
      archivado_en = null
  where id = p_trabajador_id;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'El trabajador no existe.');
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.portal_admin_borrar_cliente(
  p_token uuid,
  p_cliente_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
  v_trabajadores integer;
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  select count(*) into v_trabajadores
  from public.trabajadores
  where cliente_id = p_cliente_id;

  if v_trabajadores > 0 then
    return jsonb_build_object(
      'ok', false,
      'error', format(
        'No se puede eliminar: tiene %s trabajador%s. Reasígnalos a otro cliente primero.',
        v_trabajadores,
        case when v_trabajadores = 1 then '' else 'es' end
      )
    );
  end if;

  delete from public.clientes where id = p_cliente_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'El cliente no existe.');
  end if;

  delete from public.sesiones where rol = 'cliente' and ref_id = p_cliente_id;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.portal_admin_set_activo(
  p_token uuid,
  p_trabajador_id uuid,
  p_activo boolean
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  if coalesce(p_activo, true)
     and exists (select 1 from public.trabajadores where id = p_trabajador_id and archivado) then
    return jsonb_build_object('ok', false, 'error', 'Restaura al trabajador antes de activarlo.');
  end if;

  update public.trabajadores
  set activo = coalesce(p_activo, true)
  where id = p_trabajador_id;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'El trabajador no existe.');
  end if;

  if not coalesce(p_activo, true) then
    delete from public.sesiones where rol = 'trabajador' and ref_id = p_trabajador_id;
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.portal_admin_borrar_jornada(
  p_token uuid,
  p_jornada_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  delete from public.jornadas where id = p_jornada_id;
  if not found then
    return jsonb_build_object('ok', false, 'error', 'La jornada ya no existe.');
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.portal_trabajador_datos(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
  v_trabajador public.trabajadores%rowtype;
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'trabajador' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  select * into v_trabajador from public.trabajadores where id = v_sesion.ref_id;
  if not found or v_trabajador.activo is distinct from true or v_trabajador.archivado then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Tu cuenta ya no está activa.');
  end if;

  return jsonb_build_object(
    'ok', true,
    'usuario', to_jsonb(v_trabajador) - 'password',
    'jornadas', coalesce((
      select jsonb_agg(to_jsonb(j) order by j.fecha desc, j.creado_en desc)
      from public.jornadas j
      where j.trabajador_id = v_trabajador.id
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.portal_trabajador_crear_jornada(
  p_token uuid,
  p_fecha date,
  p_entrada time,
  p_salida time,
  p_lunch integer,
  p_notas text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
  v_trabajador public.trabajadores%rowtype;
  v_jornada public.jornadas%rowtype;
  v_minutos numeric;
  v_horas numeric;
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'trabajador' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  select * into v_trabajador from public.trabajadores where id = v_sesion.ref_id;
  if not found or v_trabajador.activo is distinct from true or v_trabajador.archivado then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Tu cuenta ya no está activa.');
  end if;

  if p_fecha is null or p_entrada is null or p_salida is null then
    return jsonb_build_object('ok', false, 'error', 'Completa fecha, entrada y salida.');
  end if;

  if coalesce(p_lunch, 0) < 0 or coalesce(p_lunch, 0) > 600 then
    return jsonb_build_object('ok', false, 'error', 'Los minutos de lunch deben estar entre 0 y 600.');
  end if;

  v_minutos := extract(epoch from (
    (p_salida - p_entrada)
    + case when p_salida < p_entrada then interval '24 hours' else interval '0' end
  )) / 60 - coalesce(p_lunch, 0);

  v_horas := greatest(0, v_minutos) / 60.0;

  insert into public.jornadas (
    trabajador_id, fecha, hora_entrada, hora_salida, minutos_lunch, horas_calculadas, notas,
    tarifa_hora, cliente_id
  )
  values (
    v_trabajador.id, p_fecha, p_entrada, p_salida, coalesce(p_lunch, 0), v_horas, nullif(trim(p_notas), ''),
    v_trabajador.tarifa_hora, v_trabajador.cliente_id
  )
  returning * into v_jornada;

  return jsonb_build_object('ok', true, 'jornada', to_jsonb(v_jornada));
end;
$$;

create or replace function public.portal_trabajador_borrar_jornada(
  p_token uuid,
  p_jornada_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'trabajador' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  delete from public.jornadas
  where id = p_jornada_id
    and trabajador_id = v_sesion.ref_id;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'La jornada no existe o no te pertenece.');
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.portal_cliente_resumen(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
  v_cliente public.clientes%rowtype;
begin
  select * into v_sesion from public.portal_token(p_token);
  if not found or v_sesion.rol <> 'cliente' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  select * into v_cliente from public.clientes where id = v_sesion.ref_id;
  if not found then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Tu cuenta ya no existe.');
  end if;

  return jsonb_build_object(
    'ok', true,
    'usuario', to_jsonb(v_cliente) - 'password',
    'trabajadores', coalesce((
      select jsonb_agg(
        (to_jsonb(t) - 'password') || jsonb_build_object(
          'cliente_nombre', v_cliente.empresa,
          'historico', (t.cliente_id is distinct from v_cliente.id)
        )
        order by t.nombre
      )
      from public.trabajadores t
      where t.cliente_id = v_cliente.id
         or exists (
           select 1 from public.jornadas j
           where j.trabajador_id = t.id
             and coalesce(j.cliente_id, t.cliente_id) = v_cliente.id
         )
    ), '[]'::jsonb),
    'jornadas', coalesce((
      select jsonb_agg(
        to_jsonb(j) || jsonb_build_object(
          'trabajador_nombre', t.nombre,
          'tarifa_hora', coalesce(j.tarifa_hora, t.tarifa_hora),
          'cliente_id', coalesce(j.cliente_id, t.cliente_id),
          'cliente_nombre', v_cliente.empresa
        )
        order by j.fecha desc, j.creado_en desc
      )
      from public.jornadas j
      join public.trabajadores t on t.id = j.trabajador_id
      where coalesce(j.cliente_id, t.cliente_id) = v_cliente.id
    ), '[]'::jsonb)
  );
end;
$$;

revoke execute on function public.portal_token(uuid) from public, anon, authenticated;
revoke execute on function public.portal_ping() from public;
revoke execute on function public.portal_login(text, text) from public;
revoke execute on function public.portal_admin_login(text, text) from public;
revoke execute on function public.portal_logout(uuid) from public;
revoke execute on function public.portal_admin_resumen(uuid) from public;
revoke execute on function public.portal_admin_crear_cliente(uuid, text, text, text, text) from public;
revoke execute on function public.portal_admin_crear_trabajador(uuid, text, text, text, numeric, uuid) from public;
revoke execute on function public.portal_admin_set_activo(uuid, uuid, boolean) from public;
revoke execute on function public.portal_admin_actualizar_cliente(uuid, uuid, text, text, text, text) from public;
revoke execute on function public.portal_admin_actualizar_trabajador(uuid, uuid, text, text, numeric, uuid, text) from public;
revoke execute on function public.portal_admin_archivar_trabajador(uuid, uuid) from public;
revoke execute on function public.portal_admin_restaurar_trabajador(uuid, uuid) from public;
revoke execute on function public.portal_admin_borrar_cliente(uuid, uuid) from public;
revoke execute on function public.portal_admin_borrar_jornada(uuid, uuid) from public;
revoke execute on function public.portal_trabajador_datos(uuid) from public;
revoke execute on function public.portal_trabajador_crear_jornada(uuid, date, time, time, integer, text) from public;
revoke execute on function public.portal_trabajador_borrar_jornada(uuid, uuid) from public;
revoke execute on function public.portal_cliente_resumen(uuid) from public;

grant execute on function public.portal_ping() to anon;
grant execute on function public.portal_login(text, text) to anon;
grant execute on function public.portal_admin_login(text, text) to anon;
grant execute on function public.portal_logout(uuid) to anon;
grant execute on function public.portal_admin_resumen(uuid) to anon;
grant execute on function public.portal_admin_crear_cliente(uuid, text, text, text, text) to anon;
grant execute on function public.portal_admin_crear_trabajador(uuid, text, text, text, numeric, uuid) to anon;
grant execute on function public.portal_admin_set_activo(uuid, uuid, boolean) to anon;
grant execute on function public.portal_admin_actualizar_cliente(uuid, uuid, text, text, text, text) to anon;
grant execute on function public.portal_admin_actualizar_trabajador(uuid, uuid, text, text, numeric, uuid, text) to anon;
grant execute on function public.portal_admin_archivar_trabajador(uuid, uuid) to anon;
grant execute on function public.portal_admin_restaurar_trabajador(uuid, uuid) to anon;
grant execute on function public.portal_admin_borrar_cliente(uuid, uuid) to anon;
grant execute on function public.portal_admin_borrar_jornada(uuid, uuid) to anon;
grant execute on function public.portal_trabajador_datos(uuid) to anon;
grant execute on function public.portal_trabajador_crear_jornada(uuid, date, time, time, integer, text) to anon;
grant execute on function public.portal_trabajador_borrar_jornada(uuid, uuid) to anon;
grant execute on function public.portal_cliente_resumen(uuid) to anon;

notify pgrst, 'reload schema';
