-- Android device administration with server-side permission and scope enforcement.

alter table public.dispositivos_android
  add column if not exists voz_habilitada boolean not null default true;

comment on column public.dispositivos_android.voz_habilitada is
  'Controls voice playback on the enrolled Android terminal after configuration sync.';

create or replace function private.dispositivo_sucursal_en_alcance_0054(
  p_sucursal uuid,
  p_permisos text[],
  p_incluir_departamento boolean default true
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with actor as (
    select pr.id, pr.company_id, pr.branch_id, pr.department_id
    from public.profiles pr
    where pr.id = (select auth.uid())
      and pr.status = 'active'
  ), codigos as (
    select unnest(coalesce(p_permisos, array[]::text[])) as codigo
  )
  select coalesce(exists(
    select 1
    from actor a
    where (
      p_sucursal is null
      or exists(
        select 1
        from public.branches b
        where b.id = p_sucursal
          and b.company_id = a.company_id
      )
    )
    and exists(
      select 1
      from codigos c
      where public.tiene_permiso_en_alcance(c.codigo, array['global', 'empresa'])
         or (
           p_sucursal is not null
           and public.tiene_permiso_en_alcance(c.codigo, array['sucursal'])
           and (
             a.branch_id = p_sucursal
             or exists(
               select 1 from public.perfil_sucursales ps
               where ps.perfil_id = a.id and ps.sucursal_id = p_sucursal
             )
           )
         )
         or (
           p_incluir_departamento
           and p_sucursal is not null
           and public.tiene_permiso_en_alcance(c.codigo, array['departamento'])
           and (
             exists(
               select 1 from public.departments d
               where d.id = a.department_id
                 and d.company_id = a.company_id
                 and d.branch_id = p_sucursal
             )
             or exists(
               select 1
               from public.perfil_departamentos pd
               join public.departments d on d.id = pd.departamento_id
               where pd.perfil_id = a.id
                 and d.company_id = a.company_id
                 and d.branch_id = p_sucursal
             )
           )
         )
    )
  ), false);
$$;

create or replace function private.dispositivo_departamento_en_alcance_0054(
  p_departamento uuid,
  p_permisos text[]
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with actor as (
    select pr.id, pr.company_id, pr.branch_id, pr.department_id
    from public.profiles pr
    where pr.id = (select auth.uid())
      and pr.status = 'active'
  ), objetivo as (
    select d.id, d.company_id, d.branch_id
    from public.departments d
    where d.id = p_departamento
  ), codigos as (
    select unnest(coalesce(p_permisos, array[]::text[])) as codigo
  )
  select coalesce(exists(
    select 1
    from actor a
    join objetivo o on o.company_id = a.company_id
    where exists(
      select 1
      from codigos c
      where public.tiene_permiso_en_alcance(c.codigo, array['global', 'empresa'])
         or (
           public.tiene_permiso_en_alcance(c.codigo, array['sucursal'])
           and (
             a.branch_id = o.branch_id
             or exists(
               select 1 from public.perfil_sucursales ps
               where ps.perfil_id = a.id and ps.sucursal_id = o.branch_id
             )
           )
         )
         or (
           public.tiene_permiso_en_alcance(c.codigo, array['departamento'])
           and (
             a.department_id = o.id
             or exists(
               select 1 from public.perfil_departamentos pd
               where pd.perfil_id = a.id and pd.departamento_id = o.id
             )
           )
         )
    )
  ), false);
$$;

create or replace function public.listar_dispositivos_android_administracion()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_empresa uuid;
  v_permisos constant text[] := array[
    'dispositivos.ver',
    'dispositivos.registrar',
    'dispositivos.revocar',
    'kiosk.face_mode_manage'
  ];
begin
  select pr.company_id into v_empresa
  from public.profiles pr
  where pr.id = (select auth.uid())
    and pr.status = 'active';

  if v_empresa is null then
    raise exception using errcode = '28000', message = 'PROFILE_INACTIVE';
  end if;

  if not public.tiene_permiso('dispositivos.ver')
     and not public.tiene_permiso('dispositivos.registrar')
     and not public.tiene_permiso('dispositivos.revocar')
     and not public.tiene_permiso('kiosk.face_mode_manage')
  then
    raise exception using errcode = '42501', message = 'DEVICE_ADMIN_PERMISSION_DENIED';
  end if;

  return jsonb_build_object(
    'devices', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', da.id,
          'name', da.nombre,
          'model', da.modelo,
          'android_version', da.android_version,
          'app_version', da.app_version,
          'state', da.estado,
          'branch_id', da.sucursal_id,
          'branch_name', b.name,
          'last_connection_at', da.ultima_conexion_at,
          'registered_at', da.registrado_at,
          'usage_type', da.tipo_uso,
          'voice_enabled', da.voz_habilitada,
          'configuration_revision', da.configuracion_revision,
          'department_ids', coalesce((
            select jsonb_agg(dd.departamento_id order by dd.departamento_id)
            from public.dispositivo_departamentos dd
            where dd.empresa_id = da.empresa_id
              and dd.dispositivo_id = da.id
          ), '[]'::jsonb)
        ) order by da.nombre, da.id
      )
      from public.dispositivos_android da
      left join public.branches b
        on b.id = da.sucursal_id and b.company_id = da.empresa_id
      where da.empresa_id = v_empresa
        and private.dispositivo_sucursal_en_alcance_0054(
          da.sucursal_id, v_permisos, true
        )
    ), '[]'::jsonb),
    'branches', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', b.id,
          'name', b.name,
          'active', b.status = 'active'
        ) order by b.name, b.id
      )
      from public.branches b
      where b.company_id = v_empresa
        and private.dispositivo_sucursal_en_alcance_0054(
          b.id, v_permisos, true
        )
    ), '[]'::jsonb),
    'departments', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', d.id,
          'branch_id', d.branch_id,
          'name', d.name,
          'active', d.is_active is true
        ) order by d.name, d.id
      )
      from public.departments d
      where d.company_id = v_empresa
        and private.dispositivo_departamento_en_alcance_0054(
          d.id, v_permisos
        )
    ), '[]'::jsonb)
  );
end;
$$;

create or replace function public.actualizar_dispositivo_android_administracion(
  p_dispositivo uuid,
  p_nombre text,
  p_estado text,
  p_voz_habilitada boolean,
  p_sucursal uuid,
  p_tipo text,
  p_departamentos uuid[] default array[]::uuid[],
  p_motivo text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid;
  v_dispositivo public.dispositivos_android%rowtype;
  v_nombre text := btrim(coalesce(p_nombre, ''));
  v_estado text := lower(btrim(coalesce(p_estado, '')));
  v_tipo text := upper(btrim(coalesce(p_tipo, '')));
  v_motivo text := btrim(coalesce(p_motivo, ''));
  v_permisos constant text[] := array[
    'dispositivos.registrar',
    'kiosk.face_mode_manage'
  ];
  v_configuracion jsonb;
begin
  select pr.company_id into v_empresa
  from public.profiles pr
  where pr.id = (select auth.uid())
    and pr.status = 'active';

  if v_empresa is null then
    raise exception using errcode = '28000', message = 'PROFILE_INACTIVE';
  end if;

  if not public.tiene_permiso('dispositivos.registrar')
     and not public.tiene_permiso('kiosk.face_mode_manage')
  then
    raise exception using errcode = '42501', message = 'DEVICE_ADMIN_PERMISSION_DENIED';
  end if;

  if char_length(v_nombre) not between 2 and 80 then
    raise exception using errcode = '22023', message = 'DEVICE_NAME_INVALID';
  end if;
  if v_estado not in ('activo', 'inactivo') then
    raise exception using errcode = '22023', message = 'DEVICE_STATE_INVALID';
  end if;
  if p_voz_habilitada is null then
    raise exception using errcode = '22004', message = 'DEVICE_VOICE_REQUIRED';
  end if;
  if char_length(v_motivo) not between 5 and 500 then
    raise exception using errcode = '22023', message = 'DEVICE_REASON_REQUIRED';
  end if;

  select da.* into v_dispositivo
  from public.dispositivos_android da
  where da.id = p_dispositivo
    and da.empresa_id = v_empresa
  for update;

  if not found then
    raise exception using errcode = 'P0002', message = 'DEVICE_NOT_FOUND';
  end if;
  if v_dispositivo.estado = 'revocado' then
    raise exception using errcode = '55000', message = 'DEVICE_REVOKED';
  end if;

  if not private.dispositivo_sucursal_en_alcance_0054(
       v_dispositivo.sucursal_id, v_permisos, false
     )
     or not private.dispositivo_sucursal_en_alcance_0054(
       p_sucursal, v_permisos, false
     )
  then
    raise exception using errcode = '42501', message = 'DEVICE_ADMIN_SCOPE_DENIED';
  end if;

  -- The existing facial-terminal contract only accepts active devices. An inactive
  -- terminal is activated inside this transaction, configured, and then left in
  -- the requested final state. No intermediate state is externally visible.
  if v_dispositivo.estado = 'inactivo' then
    update public.dispositivos_android
    set estado = 'activo'
    where id = v_dispositivo.id and empresa_id = v_empresa;
  end if;

  v_configuracion := public.configurar_terminal_facial(
    p_dispositivo,
    p_sucursal,
    v_tipo,
    coalesce(p_departamentos, array[]::uuid[]),
    v_motivo
  );

  update public.dispositivos_android
  set nombre = v_nombre,
      estado = v_estado,
      voz_habilitada = p_voz_habilitada
  where id = v_dispositivo.id
    and empresa_id = v_empresa;

  return jsonb_build_object(
    'id', v_dispositivo.id,
    'name', v_nombre,
    'state', v_estado,
    'voice_enabled', p_voz_habilitada,
    'configuration', v_configuracion
  );
end;
$$;

revoke all on function private.dispositivo_sucursal_en_alcance_0054(uuid, text[], boolean)
  from public, anon, authenticated;
revoke all on function private.dispositivo_departamento_en_alcance_0054(uuid, text[])
  from public, anon, authenticated;
revoke all on function public.listar_dispositivos_android_administracion()
  from public, anon;
revoke all on function public.actualizar_dispositivo_android_administracion(
  uuid, text, text, boolean, uuid, text, uuid[], text
) from public, anon;
grant execute on function public.listar_dispositivos_android_administracion()
  to authenticated;
grant execute on function public.actualizar_dispositivo_android_administracion(
  uuid, text, text, boolean, uuid, text, uuid[], text
) to authenticated;

comment on function public.listar_dispositivos_android_administracion() is
  'Returns Android terminals and catalogs restricted by tenant, effective permission, and organizational scope.';
comment on function public.actualizar_dispositivo_android_administracion(
  uuid, text, text, boolean, uuid, text, uuid[], text
) is
  'Atomically applies the existing facial-terminal configuration contract plus authorized Android metadata and active state.';