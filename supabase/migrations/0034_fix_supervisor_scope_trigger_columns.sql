-- Corrige la auditoria compartida de alcance sin cambiar tablas, datos ni reglas.
-- Cada rama accede unicamente a las columnas reales del tipo de fila activo.

begin;

-- 0033 instala esta misma definicion antes de su backfill. Se reafirma aqui de
-- forma idempotente para entornos que pudieron ejecutar una version previa.
create or replace function public.auditar_asignacion_supervisor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile uuid;
  v_empresa uuid;
  v_rol text;
  v_entidad uuid;
  v_antes jsonb;
  v_despues jsonb;
begin
  if tg_table_schema <> 'public' then
    raise exception using
      errcode = '55000',
      message = 'SUPERVISOR_SCOPE_AUDIT_TABLE_INVALID';
  end if;

  if tg_table_name = 'perfil_sucursales' then
    if tg_op = 'DELETE' then
      v_profile := old.perfil_id;
      v_entidad := old.sucursal_id;
      v_antes := pg_catalog.to_jsonb(old);
      v_despues := null;
    elsif tg_op = 'INSERT' then
      v_profile := new.perfil_id;
      v_entidad := new.sucursal_id;
      v_antes := null;
      v_despues := pg_catalog.to_jsonb(new);
    elsif tg_op = 'UPDATE' then
      v_profile := new.perfil_id;
      v_entidad := new.sucursal_id;
      v_antes := pg_catalog.to_jsonb(old);
      v_despues := pg_catalog.to_jsonb(new);
    else
      raise exception using
        errcode = '55000',
        message = 'SUPERVISOR_SCOPE_AUDIT_OPERATION_INVALID';
    end if;
  elsif tg_table_name = 'perfil_departamentos' then
    if tg_op = 'DELETE' then
      v_profile := old.perfil_id;
      v_entidad := old.departamento_id;
      v_antes := pg_catalog.to_jsonb(old);
      v_despues := null;
    elsif tg_op = 'INSERT' then
      v_profile := new.perfil_id;
      v_entidad := new.departamento_id;
      v_antes := null;
      v_despues := pg_catalog.to_jsonb(new);
    elsif tg_op = 'UPDATE' then
      v_profile := new.perfil_id;
      v_entidad := new.departamento_id;
      v_antes := pg_catalog.to_jsonb(old);
      v_despues := pg_catalog.to_jsonb(new);
    else
      raise exception using
        errcode = '55000',
        message = 'SUPERVISOR_SCOPE_AUDIT_OPERATION_INVALID';
    end if;
  else
    raise exception using
      errcode = '55000',
      message = 'SUPERVISOR_SCOPE_AUDIT_TABLE_INVALID';
  end if;

  select p.company_id
  into v_empresa
  from public.profiles p
  where p.id = v_profile;

  select r.code
  into v_rol
  from public.profiles p
  join public.roles r
    on r.id = p.role_id
   and r.company_id = p.company_id
  where p.id = (select auth.uid());

  insert into public.supervisor_auditoria(
    empresa_id,
    actor_id,
    actor_rol,
    entidad,
    entidad_id,
    accion,
    antes,
    despues,
    motivo
  ) values (
    v_empresa,
    (select auth.uid()),
    coalesce(v_rol, 'service_role'),
    tg_table_name,
    v_entidad,
    tg_op,
    v_antes,
    v_despues,
    'Asignacion de alcance de supervisor'
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- Conserva la frontera historica: la funcion se ejecuta por trigger, no por clientes.
revoke all on function public.auditar_asignacion_supervisor()
  from public, anon, authenticated;

commit;
