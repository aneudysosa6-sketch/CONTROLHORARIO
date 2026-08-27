-- CONTROLHORARIO: supervisor scope across multiple branches.
-- Local migration only. Remote application is intentionally not performed by Codex.

begin;

create or replace function public.validar_alcance_supervisor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_role_code text;
  v_role_active boolean;
begin
  select *
  into strict v_profile
  from public.profiles pr
  where pr.id = new.perfil_id;

  select private.normalizar_codigo_rol(r.code), r.is_active
  into strict v_role_code, v_role_active
  from public.roles r
  where r.id = v_profile.role_id
    and r.company_id = v_profile.company_id;

  if tg_table_name = 'perfil_sucursales' then
    if not exists(
      select 1
      from public.branches b
      where b.id = new.sucursal_id
        and b.company_id = v_profile.company_id
    ) then
      raise exception 'SUPERVISOR_BRANCH_CROSS_COMPANY';
    end if;

    if v_role_code = 'SUPERVISOR' then
      if v_profile.status <> 'active'
        or v_profile.access_deleted_at is not null
        or not v_role_active
        or not exists(
          select 1
          from public.companies c
          where c.id = v_profile.company_id
            and c.status = 'active'
        ) then
        raise exception 'SUPERVISOR_PROFILE_INACTIVE';
      end if;
      if not exists(
        select 1
        from public.branches b
        where b.id = new.sucursal_id
          and b.company_id = v_profile.company_id
          and b.status = 'active'
      ) then
        raise exception 'SUPERVISOR_SCOPE_BRANCH_INVALID';
      end if;
    end if;
  else
    if not exists(
      select 1
      from public.departments d
      where d.id = new.departamento_id
        and d.company_id = v_profile.company_id
    ) then
      raise exception 'SUPERVISOR_DEPARTMENT_CROSS_COMPANY';
    end if;

    if v_role_code = 'SUPERVISOR' then
      if v_profile.status <> 'active'
        or v_profile.access_deleted_at is not null
        or not v_role_active
        or not exists(
          select 1
          from public.companies c
          where c.id = v_profile.company_id
            and c.status = 'active'
        ) then
        raise exception 'SUPERVISOR_PROFILE_INACTIVE';
      end if;
      if not exists(
        select 1
        from public.departments d
        join public.branches b
          on b.id = d.branch_id
         and b.company_id = d.company_id
         and b.status = 'active'
        join public.perfil_sucursales ps
          on ps.perfil_id = new.perfil_id
         and ps.sucursal_id = d.branch_id
        where d.id = new.departamento_id
          and d.company_id = v_profile.company_id
          and d.is_active is true
      ) then
        raise exception 'SUPERVISOR_DEPARTMENT_BRANCH_NOT_AUTHORIZED';
      end if;
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.validar_alcance_supervisor()
  from public, anon, authenticated;

create or replace function public.guardar_alcance_supervisor_internal(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid;
  v_perfil uuid := nullif(payload ->> 'profile_id', '')::uuid;
  v_sucursales uuid[] := array[]::uuid[];
  v_departamentos uuid[] := array[]::uuid[];
  v_estado text;
  v_role_code text;
  v_validos integer := 0;
  v_antes jsonb;
  v_despues jsonb;
begin
  if v_actor is null or v_perfil is null then
    raise exception 'SUPERVISOR_SCOPE_REQUIRED_FIELDS';
  end if;

  v_empresa := public.obtener_empresa_actor_activo_internal(v_actor);
  if not public.actor_puede_administrar_accesos_internal(
    v_actor,
    v_empresa,
    array['usuarios.administrar','roles.administrar','permisos.administrar']::text[]
  ) then
    raise exception using
      errcode = '42501',
      message = 'SUPERVISOR_SCOPE_PERMISSION_DENIED';
  end if;

  if payload ? 'branch_ids' then
    if jsonb_typeof(payload -> 'branch_ids') <> 'array'
      or exists(
        select 1
        from jsonb_array_elements(payload -> 'branch_ids') item(value)
        where jsonb_typeof(item.value) <> 'string'
          or btrim(item.value #>> '{}') = ''
      ) then
      raise exception 'SUPERVISOR_SCOPE_BRANCH_IDS_INVALID';
    end if;
    begin
      select coalesce(array_agg(distinct value::uuid order by value::uuid), array[]::uuid[])
      into v_sucursales
      from jsonb_array_elements_text(payload -> 'branch_ids') ids(value);
    exception
      when invalid_text_representation then
        raise exception 'SUPERVISOR_SCOPE_BRANCH_IDS_INVALID';
    end;
  elsif nullif(payload ->> 'branch_id', '') is not null then
    begin
      v_sucursales := array[(payload ->> 'branch_id')::uuid];
    exception
      when invalid_text_representation then
        raise exception 'SUPERVISOR_SCOPE_BRANCH_IDS_INVALID';
    end;
  end if;

  if jsonb_typeof(coalesce(payload -> 'department_ids', '[]'::jsonb)) <> 'array'
    or exists(
      select 1
      from jsonb_array_elements(coalesce(payload -> 'department_ids', '[]'::jsonb)) item(value)
      where jsonb_typeof(item.value) <> 'string'
        or btrim(item.value #>> '{}') = ''
    ) then
    raise exception 'SUPERVISOR_SCOPE_DEPARTMENT_IDS_INVALID';
  end if;
  begin
    select coalesce(array_agg(distinct value::uuid order by value::uuid), array[]::uuid[])
    into v_departamentos
    from jsonb_array_elements_text(coalesce(payload -> 'department_ids', '[]'::jsonb)) ids(value);
  exception
    when invalid_text_representation then
      raise exception 'SUPERVISOR_SCOPE_DEPARTMENT_IDS_INVALID';
  end;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_empresa::text, 0)
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_perfil::text, 33)
  );

  select pr.status, private.normalizar_codigo_rol(r.code)
  into v_estado, v_role_code
  from public.profiles pr
  join public.roles r
    on r.id = pr.role_id
   and r.company_id = pr.company_id
   and r.is_active
  where pr.id = v_perfil
    and pr.company_id = v_empresa
    and pr.access_deleted_at is null
  for update of pr;

  if not found then
    raise exception 'SUPERVISOR_PROFILE_NOT_FOUND';
  end if;
  if v_role_code <> 'SUPERVISOR' then
    raise exception 'SUPERVISOR_SCOPE_ROLE_INVALID';
  end if;
  if v_estado <> 'active' then
    raise exception 'SUPERVISOR_PROFILE_INACTIVE';
  end if;
  if cardinality(v_sucursales) = 0 then
    raise exception 'SUPERVISOR_SCOPE_BRANCH_REQUIRED';
  end if;
  if cardinality(v_departamentos) = 0 then
    raise exception 'SIN_DEPARTAMENTOS';
  end if;

  select count(*)::integer
  into v_validos
  from public.branches b
  where b.id = any(v_sucursales)
    and b.company_id = v_empresa
    and b.status = 'active';

  if v_validos <> cardinality(v_sucursales) then
    raise exception 'SUPERVISOR_SCOPE_BRANCH_INVALID';
  end if;

  select count(*)::integer
  into v_validos
  from public.departments d
  where d.id = any(v_departamentos)
    and d.company_id = v_empresa
    and d.branch_id = any(v_sucursales)
    and d.is_active is true;

  if v_validos <> cardinality(v_departamentos) then
    raise exception 'SUPERVISOR_SCOPE_DEPARTMENT_INVALID';
  end if;

  select count(distinct d.branch_id)::integer
  into v_validos
  from public.departments d
  where d.id = any(v_departamentos)
    and d.company_id = v_empresa
    and d.branch_id = any(v_sucursales)
    and d.is_active is true;

  if v_validos <> cardinality(v_sucursales) then
    raise exception 'SUPERVISOR_BRANCH_WITHOUT_DEPARTMENTS';
  end if;

  select jsonb_build_object(
    'branch_ids', coalesce((
      select jsonb_agg(ps.sucursal_id order by ps.sucursal_id)
      from public.perfil_sucursales ps
      where ps.perfil_id = v_perfil
    ), '[]'::jsonb),
    'department_ids', coalesce((
      select jsonb_agg(pd.departamento_id order by pd.departamento_id)
      from public.perfil_departamentos pd
      where pd.perfil_id = v_perfil
    ), '[]'::jsonb)
  )
  into v_antes;

  delete from public.perfil_departamentos pd
  where pd.perfil_id = v_perfil
    and not (pd.departamento_id = any(v_departamentos));

  delete from public.perfil_sucursales ps
  where ps.perfil_id = v_perfil
    and not (ps.sucursal_id = any(v_sucursales));

  insert into public.perfil_sucursales(perfil_id, sucursal_id)
  select v_perfil, id
  from unnest(v_sucursales) ids(id)
  on conflict(perfil_id, sucursal_id) do nothing;

  insert into public.perfil_departamentos(perfil_id, departamento_id)
  select v_perfil, id
  from unnest(v_departamentos) ids(id)
  on conflict(perfil_id, departamento_id) do nothing;

  select jsonb_build_object(
    'branch_ids', coalesce((
      select jsonb_agg(ps.sucursal_id order by ps.sucursal_id)
      from public.perfil_sucursales ps
      where ps.perfil_id = v_perfil
    ), '[]'::jsonb),
    'department_ids', coalesce((
      select jsonb_agg(pd.departamento_id order by pd.departamento_id)
      from public.perfil_departamentos pd
      where pd.perfil_id = v_perfil
    ), '[]'::jsonb)
  )
  into v_despues;

  if v_antes is distinct from v_despues then
    insert into public.administracion_auditoria(
      empresa_id, actor_id, seccion, accion, entidad, entidad_id,
      antes, despues, motivo
    ) values (
      v_empresa, v_actor, 'accesos', 'GUARDAR_ALCANCE_SUPERVISOR',
      'profiles', v_perfil::text, v_antes, v_despues,
      'Asignacion explicita de varias sucursales y sus departamentos supervisados'
    );
  end if;

  return jsonb_build_object(
    'profile_id', v_perfil,
    'branch_id', case when cardinality(v_sucursales) = 1 then v_sucursales[1] else null end,
    'branch_ids', to_jsonb(v_sucursales),
    'department_ids', to_jsonb(v_departamentos),
    'changed', v_antes is distinct from v_despues
  );
end;
$$;

revoke all on function public.guardar_alcance_supervisor_internal(jsonb)
  from public, anon, authenticated;
grant execute on function public.guardar_alcance_supervisor_internal(jsonb)
  to service_role;

create or replace function public.obtener_alcance_supervisor_internal(payload jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid;
  v_perfil uuid := nullif(payload ->> 'profile_id', '')::uuid;
  v_role_code text;
  v_status text;
  v_branch_count integer := 0;
  v_department_count integer := 0;
  v_invalid_count integer := 0;
  v_empty_branch_count integer := 0;
  v_branch uuid;
  v_scope jsonb;
begin
  if v_actor is null then
    raise exception 'SUPERVISOR_SCOPE_REQUIRED_FIELDS';
  end if;

  v_empresa := public.obtener_empresa_actor_activo_internal(v_actor);
  if not public.actor_puede_administrar_accesos_internal(
    v_actor,
    v_empresa,
    array['usuarios.administrar','roles.administrar','permisos.administrar']::text[]
  ) then
    raise exception using
      errcode = '42501',
      message = 'SUPERVISOR_SCOPE_PERMISSION_DENIED';
  end if;

  v_scope := jsonb_build_object(
    'profile_id', null,
    'role_code_canonical', null,
    'status', null,
    'branch_id', null,
    'branch_ids', '[]'::jsonb,
    'department_ids', '[]'::jsonb,
    'invalid_department_ids', '[]'::jsonb,
    'requires_reconciliation', false
  );

  if v_perfil is not null then
    select private.normalizar_codigo_rol(r.code), pr.status
    into v_role_code, v_status
    from public.profiles pr
    join public.roles r
      on r.id = pr.role_id
     and r.company_id = pr.company_id
    where pr.id = v_perfil
      and pr.company_id = v_empresa
      and pr.access_deleted_at is null
    limit 1;

    if not found then
      raise exception 'SUPERVISOR_PROFILE_NOT_FOUND';
    end if;

    select count(distinct ps.sucursal_id)::integer
    into v_branch_count
    from public.perfil_sucursales ps
    where ps.perfil_id = v_perfil;

    if v_branch_count = 1 then
      select ps.sucursal_id
      into v_branch
      from public.perfil_sucursales ps
      where ps.perfil_id = v_perfil
      order by ps.sucursal_id
      limit 1;
    end if;

    select count(*)::integer
    into v_department_count
    from public.perfil_departamentos pd
    where pd.perfil_id = v_perfil;

    select count(*)::integer
    into v_invalid_count
    from public.perfil_departamentos pd
    where pd.perfil_id = v_perfil
      and not exists(
        select 1
        from public.departments d
        join public.branches b
          on b.id = d.branch_id
         and b.company_id = d.company_id
         and b.status = 'active'
        join public.perfil_sucursales ps
          on ps.perfil_id = v_perfil
         and ps.sucursal_id = d.branch_id
        where d.id = pd.departamento_id
          and d.company_id = v_empresa
          and d.is_active is true
      );

    select count(*)::integer
    into v_empty_branch_count
    from public.perfil_sucursales ps
    where ps.perfil_id = v_perfil
      and not exists(
        select 1
        from public.perfil_departamentos pd
        join public.departments d
          on d.id = pd.departamento_id
         and d.company_id = v_empresa
         and d.branch_id = ps.sucursal_id
         and d.is_active is true
        where pd.perfil_id = v_perfil
      );

    v_scope := jsonb_build_object(
      'profile_id', v_perfil,
      'role_code_canonical', v_role_code,
      'status', v_status,
      'branch_id', v_branch,
      'branch_ids', coalesce((
        select jsonb_agg(ps.sucursal_id order by ps.sucursal_id)
        from public.perfil_sucursales ps
        where ps.perfil_id = v_perfil
      ), '[]'::jsonb),
      'department_ids', coalesce((
        select jsonb_agg(pd.departamento_id order by pd.departamento_id)
        from public.perfil_departamentos pd
        where pd.perfil_id = v_perfil
      ), '[]'::jsonb),
      'invalid_department_ids', coalesce((
        select jsonb_agg(pd.departamento_id order by pd.departamento_id)
        from public.perfil_departamentos pd
        where pd.perfil_id = v_perfil
          and not exists(
            select 1
            from public.departments d
            join public.branches b
              on b.id = d.branch_id
             and b.company_id = d.company_id
             and b.status = 'active'
            join public.perfil_sucursales ps
              on ps.perfil_id = v_perfil
             and ps.sucursal_id = d.branch_id
            where d.id = pd.departamento_id
              and d.company_id = v_empresa
              and d.is_active is true
          )
      ), '[]'::jsonb),
      'requires_reconciliation',
        v_role_code = 'SUPERVISOR'
        and (
          v_branch_count = 0
          or v_department_count = 0
          or v_invalid_count > 0
          or v_empty_branch_count > 0
        )
    );
  end if;

  return jsonb_build_object(
    'branches', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', b.id,
        'name', b.name,
        'code', b.code,
        'status', b.status
      ) order by b.name)
      from public.branches b
      where b.company_id = v_empresa
        and b.status = 'active'
    ), '[]'::jsonb),
    'departments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', d.id,
        'name', d.name,
        'code', d.code,
        'branch_id', d.branch_id,
        'is_active', d.is_active
      ) order by d.name)
      from public.departments d
      join public.branches b
        on b.id = d.branch_id
       and b.company_id = d.company_id
       and b.status = 'active'
      where d.company_id = v_empresa
        and d.is_active is true
        and d.branch_id is not null
    ), '[]'::jsonb),
    'supervisor_role_ids', coalesce((
      select jsonb_agg(r.id order by r.name)
      from public.roles r
      where r.company_id = v_empresa
        and r.is_active
        and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
    ), '[]'::jsonb),
    'scope', v_scope
  );
end;
$$;

revoke all on function public.obtener_alcance_supervisor_internal(jsonb)
  from public, anon, authenticated;
grant execute on function public.obtener_alcance_supervisor_internal(jsonb)
  to service_role;

commit;