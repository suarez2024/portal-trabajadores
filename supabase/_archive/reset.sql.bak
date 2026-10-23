create or replace function public.portal_admin_reiniciar_datos(
  p_token uuid,
  p_confirmacion text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_sesion public.sesiones;
begin
  select * into v_sesion
  from public.sesiones
  where token = p_token
    and expira_en > now()
  limit 1;

  if not found or v_sesion.rol <> 'admin' then
    return jsonb_build_object('ok', false, 'code', 'auth', 'error', 'Sesión no válida. Vuelve a entrar.');
  end if;

  if upper(coalesce(trim(p_confirmacion), '')) <> 'BORRAR TODO' then
    return jsonb_build_object('ok', false, 'error', 'Escribí BORRAR TODO para confirmar.');
  end if;

  delete from public.jornadas;
  delete from public.trabajadores;
  delete from public.clientes;
  delete from public.sesiones;

  return jsonb_build_object('ok', true);
end;
$$;

revoke execute on function public.portal_admin_reiniciar_datos(uuid, text) from public;
grant execute on function public.portal_admin_reiniciar_datos(uuid, text) to anon;

notify pgrst, 'reload schema';
