-- Defensa en profundidad para el CRUD de roles administrativo.
-- Conserva el aislamiento por empresa y evita dejar usuarios sin rol activo.
create or replace function public.guardar_rol_administracion(
  p_id uuid,
  p_nombre text,
  p_codigo text,
  p_descripcion text,
  p_activo boolean,
  p_motivo text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.obtener_empresa_actual();
  v_id uuid;
  v_rol public.roles;
  v_antes jsonb;
  v_despues jsonb;
begin
  if not public.tiene_permiso('roles.administrar') then
    raise exception using errcode = '42501', message = 'ADMIN_PERMISSION_DENIED';
  end if;

  if btrim(coalesce(p_nombre, '')) = ''
    or btrim(coalesce(p_codigo, '')) = ''
    or btrim(coalesce(p_motivo, '')) = '' then
    raise exception 'ROL_INVALIDO';
  end if;

  if p_id is null then
    insert into public.roles(company_id, name, code, description, is_active)
    values (
      v_empresa,
      btrim(p_nombre),
      lower(btrim(p_codigo)),
      nullif(btrim(p_descripcion), ''),
      coalesce(p_activo, true)
    )
    returning id, to_jsonb(roles) into v_id, v_despues;
  else
    select *
    into v_rol
    from public.roles
    where company_id = v_empresa
      and id = p_id
    for update;

    if not found then
      raise exception 'ROL_NO_ENCONTRADO';
    end if;

    v_antes := to_jsonb(v_rol);

    if v_rol.is_active and not coalesce(p_activo, true) then
      if upper(translate(
        trim(coalesce(v_rol.code, '')) || ' ' || trim(coalesce(v_rol.name, '')),
        'ÁÉÍÓÚáéíóú',
        'AEIOUaeiou'
      )) like '%ADMIN%' then
        raise exception 'DESACTIVACION_ADMINISTRADOR_NO_PERMITIDA';
      end if;

      if exists (
        select 1
        from public.profiles
        where company_id = v_empresa
          and role_id = p_id
      ) then
        raise exception 'ROL_CON_USUARIOS_ASIGNADOS';
      end if;

      if not exists (
        select 1
        from public.profiles p
        join public.roles r
          on r.id = p.role_id
         and r.company_id = p.company_id
        where p.company_id = v_empresa
          and p.status = 'active'
          and r.is_active
          and r.id <> p_id
          and upper(translate(
            trim(coalesce(r.code, '')) || ' ' || trim(coalesce(r.name, '')),
            'ÁÉÍÓÚáéíóú',
            'AEIOUaeiou'
          )) like '%ADMIN%'
      ) then
        raise exception 'EMPRESA_SIN_ADMIN_ACTIVO';
      end if;
    end if;

    -- El código técnico es inmutable después de la creación.
    update public.roles
    set
      name = btrim(p_nombre),
      description = nullif(btrim(p_descripcion), ''),
      is_active = coalesce(p_activo, true),
      updated_at = now()
    where company_id = v_empresa
      and id = p_id
    returning id, to_jsonb(roles) into v_id, v_despues;
  end if;

  insert into public.administracion_auditoria(
    empresa_id,
    actor_id,
    seccion,
    accion,
    entidad,
    entidad_id,
    antes,
    despues,
    motivo
  )
  values (
    v_empresa,
    auth.uid(),
    'usuarios',
    case when p_id is null then 'CREAR_ROL' else 'ACTUALIZAR_ROL' end,
    'roles',
    v_id::text,
    v_antes,
    v_despues,
    btrim(p_motivo)
  );

  return v_id;
end;
$$;

revoke all on function public.guardar_rol_administracion(uuid, text, text, text, boolean, text)
  from public, anon;
grant execute on function public.guardar_rol_administracion(uuid, text, text, text, boolean, text)
  to authenticated;
