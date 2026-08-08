-- CONTROLHORARIO: alcance explicito de supervisores por sucursal/departamentos.
-- Reutiliza perfil_sucursales y perfil_departamentos; no crea un modelo paralelo.

begin;

-- El alcance se modifica exclusivamente mediante los contratos protegidos.
-- Se conserva SELECT autenticado para la lectura RLS existente.
revoke insert, update, delete on table public.perfil_sucursales
  from anon, authenticated;
revoke insert, update, delete on table public.perfil_departamentos
  from anon, authenticated;

-- 0009 dejo una funcion de auditoria compartida que intentaba resolver campos
-- de ambas tablas de alcance en una sola expresion. Se instala la definicion
-- segura antes del backfill para que su primer INSERT tambien quede auditado.
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

-- Las asignaciones historicas de departamentos ya eran explicitas. Se completa
-- su sucursal equivalente sin inferir alcance desde profiles.branch_id o
-- profiles.department_id y sin eliminar ninguna fila existente.
insert into public.perfil_sucursales(perfil_id, sucursal_id)
select distinct pd.perfil_id, d.branch_id
from public.perfil_departamentos pd
join public.profiles pr on pr.id = pd.perfil_id
join public.roles r
  on r.id = pr.role_id
 and r.company_id = pr.company_id
join public.departments d
  on d.id = pd.departamento_id
 and d.company_id = pr.company_id
join public.branches b
  on b.id = d.branch_id
 and b.company_id = pr.company_id
where private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  and d.branch_id is not null
  and not exists(
    select 1
    from public.perfil_sucursales existing
    where existing.perfil_id = pd.perfil_id
      and existing.sucursal_id = d.branch_id
  )
on conflict(perfil_id, sucursal_id) do nothing;

-- Permite reconocer de forma estable el resultado de un alta ya completada.
create unique index if not exists user_provisioning_audit_create_idempotency_idx
  on public.user_provisioning_audit(
    company_id,
    actor_user_id,
    ((details ->> 'idempotency_key'))
  )
  where action = 'create_user'
    and details ? 'idempotency_key';

create unique index if not exists administracion_auditoria_access_operation_idx
  on public.administracion_auditoria(
    empresa_id,
    actor_id,
    ((despues ->> 'operation_id'))
  )
  where accion = 'ACTUALIZAR_ACCESO'
    and despues ? 'operation_id';

create or replace function public.obtener_empresa_actor_activo_internal(p_actor uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_empresa uuid;
begin
  select pr.company_id
  into v_empresa
  from public.profiles pr
  join public.companies c
    on c.id = pr.company_id
   and c.status = 'active'
  join public.roles r
    on r.id = pr.role_id
   and r.company_id = pr.company_id
   and r.is_active
  where pr.id = p_actor
    and pr.status = 'active'
    and pr.access_deleted_at is null
    and public.perfil_acceso_utilizable_internal(pr.id, pr.company_id)
  limit 1;

  if v_empresa is null then
    raise exception using
      errcode = '42501',
      message = 'SCOPE_ADMIN_PROFILE_INVALID';
  end if;
  return v_empresa;
end;
$$;
revoke all on function public.obtener_empresa_actor_activo_internal(uuid)
  from public, anon, authenticated, service_role;

create or replace function public.alcance_supervisor_valido_internal(
  p_perfil uuid,
  p_empresa uuid
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  -- Valida la estructura persistida. No exige pr.status='active' porque la usa
  -- cambiar_estado_acceso_con_alcance_internal antes de activar el perfil.
  -- Los escritores y los resolvers efectivos sí exigen un perfil activo.
  select
    exists(
      select 1
      from public.profiles pr
      join public.roles r
        on r.id = pr.role_id
       and r.company_id = pr.company_id
       and r.is_active
      join public.companies c
        on c.id = pr.company_id
       and c.status = 'active'
      join public.perfil_departamentos pd on pd.perfil_id = pr.id
      join public.departments d
        on d.id = pd.departamento_id
       and d.company_id = pr.company_id
       and d.is_active is true
      join public.perfil_sucursales ps
        on ps.perfil_id = pr.id
       and ps.sucursal_id = d.branch_id
      join public.branches b
        on b.id = ps.sucursal_id
       and b.company_id = pr.company_id
       and b.status = 'active'
      where pr.id = p_perfil
        and pr.company_id = p_empresa
        and pr.access_deleted_at is null
        and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
    )
    and 1 = (
      select count(distinct ps.sucursal_id)
      from public.perfil_sucursales ps
      where ps.perfil_id = p_perfil
    )
    and not exists(
      select 1
      from public.perfil_sucursales ps
      left join public.branches b
        on b.id = ps.sucursal_id
       and b.company_id = p_empresa
       and b.status = 'active'
      where ps.perfil_id = p_perfil
        and b.id is null
    )
    and not exists(
      select 1
      from public.perfil_departamentos pd
      left join public.departments d
        on d.id = pd.departamento_id
       and d.company_id = p_empresa
       and d.is_active is true
      left join public.branches b
        on b.id = d.branch_id
       and b.company_id = p_empresa
       and b.status = 'active'
      left join public.perfil_sucursales ps
        on ps.perfil_id = p_perfil
       and ps.sucursal_id = d.branch_id
      where pd.perfil_id = p_perfil
        and (d.id is null or b.id is null or ps.perfil_id is null)
    );
$$;
revoke all on function public.alcance_supervisor_valido_internal(uuid, uuid)
  from public, anon, authenticated, service_role;

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
  v_sucursal uuid := nullif(payload ->> 'branch_id', '')::uuid;
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

  if jsonb_typeof(coalesce(payload -> 'department_ids', '[]'::jsonb)) <> 'array' then
    raise exception 'SUPERVISOR_SCOPE_DEPARTMENT_IDS_INVALID';
  end if;
  if exists(
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

  if v_sucursal is null or cardinality(v_departamentos) = 0 then
    raise exception 'SIN_DEPARTAMENTOS';
  end if;
  if cardinality(v_departamentos) = 0 and v_sucursal is not null then
    raise exception 'SUPERVISOR_SCOPE_EMPTY';
  end if;
  if cardinality(v_departamentos) > 0 and v_sucursal is null then
    raise exception 'SUPERVISOR_SCOPE_BRANCH_REQUIRED';
  end if;

  if v_sucursal is not null and not exists(
    select 1
    from public.branches b
    where b.id = v_sucursal
      and b.company_id = v_empresa
      and b.status = 'active'
  ) then
    raise exception 'SUPERVISOR_SCOPE_BRANCH_INVALID';
  end if;

  if cardinality(v_departamentos) > 0 then
    select count(*)::integer
    into v_validos
    from public.departments d
    where d.id = any(v_departamentos)
      and d.company_id = v_empresa
      and d.branch_id = v_sucursal
      and d.is_active is true;

    if v_validos <> cardinality(v_departamentos) then
      raise exception 'SUPERVISOR_SCOPE_DEPARTMENT_INVALID';
    end if;
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
  ) into v_antes;

  delete from public.perfil_departamentos pd
  where pd.perfil_id = v_perfil
    and not (pd.departamento_id = any(v_departamentos));

  delete from public.perfil_sucursales ps
  where ps.perfil_id = v_perfil
    and (v_sucursal is null or ps.sucursal_id <> v_sucursal);

  if v_sucursal is not null then
    insert into public.perfil_sucursales(perfil_id, sucursal_id)
    values(v_perfil, v_sucursal)
    on conflict(perfil_id, sucursal_id) do nothing;
  end if;

  if cardinality(v_departamentos) > 0 then
    insert into public.perfil_departamentos(perfil_id, departamento_id)
    select v_perfil, id
    from unnest(v_departamentos) ids(id)
    on conflict(perfil_id, departamento_id) do nothing;
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
  ) into v_despues;

  if v_antes is distinct from v_despues then
    insert into public.administracion_auditoria(
      empresa_id, actor_id, seccion, accion, entidad, entidad_id,
      antes, despues, motivo
    ) values (
      v_empresa, v_actor, 'accesos', 'GUARDAR_ALCANCE_SUPERVISOR',
      'profiles', v_perfil::text, v_antes, v_despues,
      'Asignacion explicita de sucursal y departamentos supervisados'
    );
  end if;

  return jsonb_build_object(
    'profile_id', v_perfil,
    'branch_id', v_sucursal,
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
        v_branch_count > 1
        or v_invalid_count > 0
        or (v_department_count > 0 and v_branch_count <> 1)
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

-- El listado entrega la canonicalizacion calculada por SQL. La Web nunca
-- intenta reconocer aliases por nombre o por heuristicas locales.
create or replace function public.listar_accesos_internal(payload jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid := nullif(payload ->> 'company_id', '')::uuid;
  v_result jsonb;
begin
  if v_actor is null or v_empresa is null
    or v_empresa <> public.obtener_empresa_actor_activo_internal(v_actor)
    or not public.actor_puede_administrar_accesos_internal(
      v_actor,v_empresa,array[
        'usuarios.view','usuarios.create','usuarios.edit','usuarios.administrar'
      ]::text[]
    ) then
    raise exception using errcode = '42501', message = 'ACCESS_ADMIN_PERMISSION_DENIED';
  end if;

  select jsonb_build_object(
    'accesses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', pr.id,
        'username', coalesce(nullif(btrim(u.raw_user_meta_data ->> 'username'), ''), u.email, ''),
        'email', u.email,
        'employee_id', e.id,
        'employee_name', e.nombre_completo,
        'employee_code', e.codigo_empleado,
        'role_id', r.id,
        'role_name', r.name,
        'role_code', r.code,
        'role_code_canonical', private.normalizar_codigo_rol(r.code),
        'status', pr.status,
        'last_sign_in_at', u.last_sign_in_at
      ) order by lower(coalesce(e.nombre_completo, u.email, pr.id::text)))
      from public.profiles pr
      join auth.users u on u.id = pr.id
      join public.roles r on r.id = pr.role_id and r.company_id = pr.company_id
      left join public.empleados e
        on e.empresa_id = pr.company_id
       and e.perfil_id = pr.id
      where pr.company_id = v_empresa
        and pr.access_deleted_at is null
    ), '[]'::jsonb),
    'employees', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id,
        'nombre_completo', e.nombre_completo,
        'codigo_empleado', e.codigo_empleado,
        'empresa_id', e.empresa_id,
        'perfil_id', e.perfil_id,
        'activo', e.activo
      ) order by e.nombre_completo)
      from public.empleados e
      where e.empresa_id = v_empresa
        and e.activo
        and e.perfil_id is null
    ), '[]'::jsonb),
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id,
        'name', r.name,
        'code', r.code,
        'role_code_canonical', private.normalizar_codigo_rol(r.code),
        'company_id', r.company_id
      ) order by r.name)
      from public.roles r
      where r.company_id = v_empresa
        and r.is_active
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;
revoke all on function public.listar_accesos_internal(jsonb)
  from public, anon, authenticated;
grant execute on function public.listar_accesos_internal(jsonb)
  to service_role;

-- El trigger conserva las validaciones multiempresa y agrega estado activo,
-- canonicalizacion, sucursal unica y relacion exacta sucursal/departamento.
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
        or v_profile.access_deleted_at is not null or not v_role_active
        or not exists(
          select 1 from public.companies c
          where c.id = v_profile.company_id and c.status = 'active'
        ) then
        raise exception 'SUPERVISOR_PROFILE_INACTIVE';
      end if;
      if not exists(
        select 1 from public.branches b
        where b.id = new.sucursal_id
          and b.company_id = v_profile.company_id
          and b.status = 'active'
      ) then
        raise exception 'SUPERVISOR_SCOPE_BRANCH_INVALID';
      end if;
      if tg_op = 'INSERT' and exists(
        select 1
        from public.perfil_sucursales ps
        where ps.perfil_id = new.perfil_id
          and ps.sucursal_id <> new.sucursal_id
      ) then
        raise exception 'SUPERVISOR_SCOPE_MULTIPLE_BRANCHES';
      end if;
      if tg_op = 'UPDATE' and exists(
        select 1
        from public.perfil_sucursales ps
        where ps.perfil_id = new.perfil_id
          and ps.sucursal_id <> new.sucursal_id
          and ps.sucursal_id <> old.sucursal_id
      ) then
        raise exception 'SUPERVISOR_SCOPE_MULTIPLE_BRANCHES';
      end if;
      if tg_op = 'UPDATE'
        and old.sucursal_id is distinct from new.sucursal_id
        and exists(
          select 1
          from public.perfil_departamentos pd
          join public.departments d
            on d.id = pd.departamento_id
           and d.company_id = v_profile.company_id
          where pd.perfil_id = new.perfil_id
            and d.branch_id is distinct from new.sucursal_id
        ) then
        raise exception 'SUPERVISOR_BRANCH_HAS_ASSIGNED_DEPARTMENTS';
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
        or v_profile.access_deleted_at is not null or not v_role_active
        or not exists(
          select 1 from public.companies c
          where c.id = v_profile.company_id and c.status = 'active'
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

create or replace function public.proteger_sucursal_asignada_supervisor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if exists(
    select 1
    from public.profiles pr
    join public.roles r
      on r.id = pr.role_id
     and r.company_id = pr.company_id
    join public.perfil_departamentos pd on pd.perfil_id = pr.id
    join public.departments d
      on d.id = pd.departamento_id
     and d.company_id = pr.company_id
    where pr.id = old.perfil_id
      and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
      and d.branch_id = old.sucursal_id
  ) then
    raise exception 'SUPERVISOR_BRANCH_HAS_ASSIGNED_DEPARTMENTS';
  end if;
  return old;
end;
$$;
revoke all on function public.proteger_sucursal_asignada_supervisor()
  from public, anon, authenticated;

create or replace function public.validar_cambio_sucursal_supervisor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Las relaciones genéricas de un rol anterior se limpian por el trigger de
  -- cambio de familia. No deben bloquear otro rol -> SUPERVISOR antes de que el
  -- wrapper guarde el nuevo alcance explícito en la misma transacción.
  if not exists(
    select 1
    from public.roles old_role
    where old_role.id = old.role_id
      and old_role.company_id = old.company_id
      and private.normalizar_codigo_rol(old_role.code) = 'SUPERVISOR'
  ) then
    return new;
  end if;

  -- profiles.branch_id es la ubicacion laboral del empleado vinculado. El
  -- alcance supervisor es valido solo si sus relaciones explicitas siguen
  -- siendo coherentes, independientemente de esa ubicacion laboral.
  if exists(
    select 1
    from public.roles r
    join public.perfil_departamentos pd on pd.perfil_id = new.id
    left join public.departments d
      on d.id = pd.departamento_id
     and d.company_id = new.company_id
     and d.is_active is true
    left join public.branches b
      on b.id = d.branch_id
     and b.company_id = new.company_id
     and b.status = 'active'
    left join public.perfil_sucursales ps
      on ps.perfil_id = new.id
     and ps.sucursal_id = d.branch_id
    where r.id = new.role_id
      and r.company_id = new.company_id
      and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
      and (d.id is null or b.id is null or ps.perfil_id is null)
  ) then
    raise exception 'SUPERVISOR_EXPLICIT_SCOPE_INVALID';
  end if;
  return new;
end;
$$;
revoke all on function public.validar_cambio_sucursal_supervisor()
  from public, anon, authenticated;

create or replace function public.obtener_departamentos_supervisor_actual()
returns table(departamento_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select distinct pd.departamento_id
  from public.profiles pr
  join public.companies c
    on c.id = pr.company_id
   and c.status = 'active'
  join public.roles r
    on r.id = pr.role_id
   and r.company_id = pr.company_id
   and r.is_active
  join public.perfil_departamentos pd on pd.perfil_id = pr.id
  join public.departments d
    on d.id = pd.departamento_id
   and d.company_id = pr.company_id
   and d.is_active is true
  join public.perfil_sucursales ps
    on ps.perfil_id = pr.id
   and ps.sucursal_id = d.branch_id
  join public.branches b
    on b.id = ps.sucursal_id
   and b.company_id = pr.company_id
   and b.status = 'active'
  where pr.id = (select auth.uid())
    and pr.status = 'active'
    and pr.access_deleted_at is null
    and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
    and public.alcance_supervisor_valido_internal(pr.id, pr.company_id);
$$;
revoke all on function public.obtener_departamentos_supervisor_actual()
  from public, anon;
grant execute on function public.obtener_departamentos_supervisor_actual()
  to authenticated;

create or replace function public.supervisor_puede_ver_empleado(p_empleado uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.profiles pr
    join public.companies c
      on c.id = pr.company_id
     and c.status = 'active'
    join public.roles r
      on r.id = pr.role_id
     and r.company_id = pr.company_id
     and r.is_active
    join public.empleados e
      on e.id = p_empleado
     and e.empresa_id = pr.company_id
     and e.activo
    join public.departments d
      on d.id = e.departamento_id
     and d.company_id = e.empresa_id
     and d.branch_id = e.sucursal_id
     and d.is_active is true
    join public.branches b
      on b.id = e.sucursal_id
     and b.company_id = e.empresa_id
     and b.status = 'active'
    where pr.id = (select auth.uid())
      and pr.status = 'active'
      and pr.access_deleted_at is null
      and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
      and public.tiene_permiso('empleados.ver_asignados')
      and e.departamento_id in (
        select alcance.departamento_id
        from public.obtener_departamentos_supervisor_actual() alcance
      )
  );
$$;
revoke all on function public.supervisor_puede_ver_empleado(uuid)
  from public, anon;
grant execute on function public.supervisor_puede_ver_empleado(uuid)
  to authenticated;

-- Fotografia de autorizacion: para SUPERVISOR, las listas de alcance salen
-- exclusivamente de las relaciones explicitas. Otros roles conservan el
-- contrato anterior (ubicacion principal + alcances adicionales).
create or replace function public.obtener_mi_autorizacion()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_profile public.profiles%rowtype;
  v_role public.roles%rowtype;
  v_role_canonical text;
  v_employee_id uuid;
  v_permissions jsonb;
  v_departments jsonb;
  v_branches jsonb;
begin
  if v_uid is null then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;

  select * into v_profile
  from public.profiles p
  where p.id = v_uid
  limit 1;
  if not found then
    raise exception using errcode = '42501', message = 'PROFILE_NOT_FOUND';
  end if;
  if v_profile.status <> 'active' or v_profile.access_deleted_at is not null then
    raise exception using errcode = '42501', message = 'PROFILE_INACTIVE';
  end if;
  if not exists(
    select 1 from public.companies c
    where c.id = v_profile.company_id and c.status = 'active'
  ) then
    raise exception using errcode = '42501', message = 'COMPANY_INACTIVE';
  end if;

  select * into v_role
  from public.roles r
  where r.id = v_profile.role_id
    and r.company_id = v_profile.company_id
  limit 1;
  if not found then
    raise exception using errcode = '42501', message = 'ROLE_NOT_FOUND';
  end if;
  if not v_role.is_active then
    raise exception using errcode = '42501', message = 'ROLE_INACTIVE';
  end if;
  v_role_canonical := private.normalizar_codigo_rol(v_role.code);

  select e.id into v_employee_id
  from public.empleados e
  where e.empresa_id = v_profile.company_id
    and e.perfil_id = v_profile.id
    and e.activo
    and e.estado_laboral = 'activo'
  limit 1;

  if exists(
    select 1 from public.empleados e
    where e.empresa_id = v_profile.company_id
      and e.perfil_id = v_profile.id
      and (not e.activo or e.estado_laboral = 'desvinculado')
  ) then
    raise exception using errcode = '42501', message = 'PROFILE_INACTIVE';
  end if;

  select coalesce(jsonb_agg(pe.codigo order by pe.codigo), '[]'::jsonb)
  into v_permissions
  from public.permisos pe
  where pe.activo
    and coalesce(
      (
        select pp.permitido
        from public.perfil_permisos pp
        where pp.perfil_id = v_profile.id
          and pp.permiso_id = pe.id
        limit 1
      ),
      (
        select rp.permitido
        from public.rol_permisos rp
        where rp.rol_id = v_role.id
          and rp.permiso_id = pe.id
        limit 1
      ),
      false
    );

  if v_role_canonical = 'SUPERVISOR' then
    select coalesce(jsonb_agg(x.departamento_id order by x.departamento_id), '[]'::jsonb)
    into v_departments
    from public.obtener_departamentos_supervisor_actual() x;

    select coalesce(jsonb_agg(x.sucursal_id order by x.sucursal_id), '[]'::jsonb)
    into v_branches
    from (
      select distinct d.branch_id as sucursal_id
      from public.departments d
      where d.company_id = v_profile.company_id
        and d.id in (
          select alcance.departamento_id
          from public.obtener_departamentos_supervisor_actual() alcance
        )
    ) x;
  elseif v_role_canonical <> 'SUPERVISOR' then
    select coalesce(jsonb_agg(x.departamento_id order by x.departamento_id), '[]'::jsonb)
    into v_departments
    from (
      select distinct pd.departamento_id
      from public.perfil_departamentos pd
      join public.departments d
        on d.id = pd.departamento_id
       and d.company_id = v_profile.company_id
       and d.is_active is true
      where pd.perfil_id = v_profile.id
    ) x;

    select coalesce(jsonb_agg(x.sucursal_id order by x.sucursal_id), '[]'::jsonb)
    into v_branches
    from (
      select v_profile.branch_id as sucursal_id
      where v_profile.branch_id is not null
      union
      select ps.sucursal_id
      from public.perfil_sucursales ps
      join public.branches b
        on b.id = ps.sucursal_id
       and b.company_id = v_profile.company_id
       and b.status = 'active'
      where ps.perfil_id = v_profile.id
    ) x;
  end if;

  return jsonb_build_object(
    'auth_user_id', v_uid,
    'profile_id', v_profile.id,
    'company_id', v_profile.company_id,
    'employee_id', v_employee_id,
    'email', coalesce((select auth.jwt() ->> 'email'), ''),
    'nombre', v_profile.full_name,
    'role_id', v_role.id,
    'role_code_original', v_role.code,
    'role_code_canonical', v_role_canonical,
    'role_name', v_role.name,
    'active', true,
    'permission_codes', v_permissions,
    'departamento_principal_id', case
      when v_role_canonical = 'SUPERVISOR' then null
      else v_profile.department_id
    end,
    'ubicacion_laboral_departamento_id', v_profile.department_id,
    'departamentos_adicionales', v_departments,
    'sucursales', v_branches,
    'scope_source', case
      when v_role_canonical = 'SUPERVISOR' then 'explicit_supervisor_assignments'
      else 'profile_and_additional_assignments'
    end,
    'authorization_version', transaction_timestamp()
  );
end;
$$;
revoke all on function public.obtener_mi_autorizacion()
  from public, anon;
grant execute on function public.obtener_mi_autorizacion()
  to authenticated;

-- El catalogo de departamentos deja de ser un escritor alternativo del
-- alcance. Se conserva la firma para compatibilidad y se rechaza cualquier
-- intento de asignar supervisor desde esa pantalla.
create or replace function public.guardar_departamento_administracion(
  p_id uuid,
  p_datos jsonb,
  p_supervisor uuid,
  p_motivo text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.administracion_autorizada('configuracion.departamentos');
  v_id uuid;
  v_branch uuid := nullif(p_datos ->> 'branch_id', '')::uuid;
  v_antes jsonb;
  v_despues jsonb;
begin
  if p_supervisor is not null then
    raise exception 'SUPERVISOR_SCOPE_MANAGED_IN_ACCESS';
  end if;
  if btrim(coalesce(p_datos ->> 'name', '')) = ''
    or btrim(coalesce(p_datos ->> 'code', '')) = ''
    or btrim(coalesce(p_motivo, '')) = '' then
    raise exception 'DEPARTAMENTO_INVALIDO';
  end if;
  if v_branch is not null and not exists(
    select 1 from public.branches
    where company_id = v_empresa and id = v_branch
  ) then
    raise exception 'SUCURSAL_INVALIDA';
  end if;

  if p_id is null then
    insert into public.departments(
      company_id, branch_id, name, code, description, is_active
    ) values (
      v_empresa, v_branch, btrim(p_datos ->> 'name'),
      upper(btrim(p_datos ->> 'code')),
      nullif(btrim(p_datos ->> 'description'), ''),
      coalesce((p_datos ->> 'is_active')::boolean, true)
    ) returning id, to_jsonb(departments) into v_id, v_despues;
  else
    select to_jsonb(d) into v_antes
    from public.departments d
    where d.company_id = v_empresa and d.id = p_id
    for update;
    if v_antes is null then raise exception 'DEPARTAMENTO_NO_ENCONTRADO'; end if;

    update public.departments
    set branch_id = v_branch,
        name = btrim(p_datos ->> 'name'),
        code = upper(btrim(p_datos ->> 'code')),
        description = nullif(btrim(p_datos ->> 'description'), ''),
        is_active = coalesce((p_datos ->> 'is_active')::boolean, true),
        updated_at = now()
    where company_id = v_empresa and id = p_id
    returning id, to_jsonb(departments) into v_id, v_despues;
  end if;

  insert into public.administracion_auditoria(
    empresa_id, actor_id, seccion, accion, entidad, entidad_id,
    antes, despues, motivo
  ) values (
    v_empresa, auth.uid(), 'departamentos',
    case when p_id is null then 'CREAR' else 'ACTUALIZAR' end,
    'departments', v_id::text, v_antes, v_despues, btrim(p_motivo)
  );
  return v_id;
end;
$$;

create or replace function public.crear_acceso_con_alcance_internal(payload jsonb)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid;
  v_payload jsonb;
  v_profile public.profiles;
  v_role_code text;
  v_key text := nullif(payload ->> 'idempotency_key', '');
  v_request_signature text;
  v_usuario uuid := nullif(payload ->> 'user_id', '')::uuid;
begin
  if v_actor is null or v_usuario is null then raise exception 'ACCESO_DATOS_REQUERIDOS'; end if;
  v_empresa := public.obtener_empresa_actor_activo_internal(v_actor);
  v_payload := payload || jsonb_build_object('company_id', v_empresa);

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_empresa::text, 0)
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_usuario::text, 33)
  );

  if v_key is null then raise exception 'IDEMPOTENCY_KEY_REQUIRED'; end if;
  begin
    perform v_key::uuid;
  exception when invalid_text_representation then
    raise exception 'IDEMPOTENCY_KEY_INVALID';
  end;
  v_request_signature := jsonb_build_object(
    'employee_id', nullif(payload ->> 'employee_id', ''),
    'role_id', nullif(payload ->> 'role_id', ''),
    'username', lower(btrim(coalesce(payload ->> 'username', ''))),
    'status', coalesce(nullif(payload ->> 'status', ''), 'active'),
    'branch_id', nullif(payload ->> 'branch_id', '')::uuid,
    'department_ids', case
      when jsonb_typeof(coalesce(payload -> 'department_ids', '[]'::jsonb)) = 'array' then
        coalesce((
          select jsonb_agg(ids.value order by ids.value)
          from (
            select distinct value::uuid as value
            from jsonb_array_elements_text(coalesce(payload -> 'department_ids', '[]'::jsonb)) x(value)
          ) ids
        ), '[]'::jsonb)
      else payload -> 'department_ids'
    end
  )::text;

  v_profile := public.crear_acceso_internal(v_payload);
  select private.normalizar_codigo_rol(r.code)
  into v_role_code
  from public.roles r
  where r.id = v_profile.role_id and r.company_id = v_empresa;

  if v_role_code = 'SUPERVISOR' then
    perform public.guardar_alcance_supervisor_internal(
      v_payload || jsonb_build_object('profile_id', v_profile.id)
    );
  elsif payload ? 'branch_id' or payload ? 'department_ids' then
    raise exception 'SUPERVISOR_SCOPE_ROLE_INVALID';
  end if;

  update public.user_provisioning_audit a
  set details = a.details || jsonb_build_object(
    'idempotency_key', v_key,
    'employee_id', payload ->> 'employee_id',
    'role_id', payload ->> 'role_id',
    'request_signature', v_request_signature,
    'scope_atomic', true
  )
  where a.id = (
    select x.id
    from public.user_provisioning_audit x
    where x.company_id = v_empresa
      and x.actor_user_id = v_actor
      and x.target_user_id_snapshot = v_profile.id
      and x.action = 'create_user'
    order by x.id desc
    limit 1
  );
  if not found then raise exception 'CREATE_ACCESS_AUDIT_NOT_FOUND'; end if;

  return v_profile;
end;
$$;
revoke all on function public.crear_acceso_con_alcance_internal(jsonb)
  from public, anon, authenticated;
grant execute on function public.crear_acceso_con_alcance_internal(jsonb)
  to service_role;

create or replace function public.obtener_creacion_acceso_idempotente_internal(payload jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid;
  v_key text := nullif(payload ->> 'idempotency_key', '');
  v_employee text := nullif(payload ->> 'employee_id', '');
  v_role text := nullif(payload ->> 'role_id', '');
  v_request_signature text;
  v_audit public.user_provisioning_audit%rowtype;
  v_result jsonb;
begin
  if v_actor is null or v_key is null then return null; end if;
  v_empresa := public.obtener_empresa_actor_activo_internal(v_actor);
  if not public.actor_puede_administrar_accesos_internal(
    v_actor, v_empresa, array['usuarios.create','usuarios.administrar']::text[]
  ) then
    raise exception using errcode = '42501', message = 'ACCESS_ADMIN_PERMISSION_DENIED';
  end if;
  v_request_signature := jsonb_build_object(
    'employee_id', v_employee,
    'role_id', v_role,
    'username', lower(btrim(coalesce(payload ->> 'username', ''))),
    'status', coalesce(nullif(payload ->> 'status', ''), 'active'),
    'branch_id', nullif(payload ->> 'branch_id', '')::uuid,
    'department_ids', case
      when jsonb_typeof(coalesce(payload -> 'department_ids', '[]'::jsonb)) = 'array' then
        coalesce((
          select jsonb_agg(ids.value order by ids.value)
          from (
            select distinct value::uuid as value
            from jsonb_array_elements_text(coalesce(payload -> 'department_ids', '[]'::jsonb)) x(value)
          ) ids
        ), '[]'::jsonb)
      else payload -> 'department_ids'
    end
  )::text;

  select * into v_audit
  from public.user_provisioning_audit a
  where a.company_id = v_empresa
    and a.actor_user_id = v_actor
    and a.action = 'create_user'
    and a.details ->> 'idempotency_key' = v_key
  limit 1;
  if not found then return null; end if;

  if v_audit.details ->> 'request_signature' is distinct from v_request_signature then
    raise exception 'IDEMPOTENCY_KEY_REUSED';
  end if;

  select jsonb_build_object(
    'id', pr.id,
    'profile_id', pr.id,
    'status', pr.status,
    'idempotency_key', v_key
  ) into v_result
  from public.profiles pr
  where pr.id = v_audit.target_user_id_snapshot
    and pr.company_id = v_empresa
    and pr.access_deleted_at is null;
  return v_result;
end;
$$;
revoke all on function public.obtener_creacion_acceso_idempotente_internal(jsonb)
  from public, anon, authenticated;
grant execute on function public.obtener_creacion_acceso_idempotente_internal(jsonb)
  to service_role;

create or replace function public.actualizar_acceso_con_alcance_internal(payload jsonb)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid;
  v_perfil uuid := nullif(payload ->> 'profile_id', '')::uuid;
  v_payload jsonb;
  v_profile public.profiles;
  v_old_role text;
  v_old_status text;
  v_requested_role text;
  v_new_role text;
  v_operation_id uuid := nullif(payload ->> 'operation_id', '')::uuid;
  v_antes jsonb;
  v_despues jsonb;
begin
  if v_actor is null or v_perfil is null or v_operation_id is null then
    raise exception 'ACCESO_DATOS_REQUERIDOS';
  end if;
  v_empresa := public.obtener_empresa_actor_activo_internal(v_actor);
  v_payload := payload || jsonb_build_object('company_id', v_empresa);

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_empresa::text, 0)
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_perfil::text, 33)
  );

  select private.normalizar_codigo_rol(r.code), pr.status
  into v_old_role, v_old_status
  from public.profiles pr
  join public.roles r on r.id = pr.role_id and r.company_id = pr.company_id
  where pr.id = v_perfil
    and pr.company_id = v_empresa
    and pr.access_deleted_at is null
  for update of pr;
  if not found then raise exception 'ACCESO_NO_ENCONTRADO'; end if;

  select private.normalizar_codigo_rol(r.code)
  into v_requested_role
  from public.roles r
  where r.id = nullif(payload ->> 'role_id', '')::uuid
    and r.company_id = v_empresa
    and r.is_active;

  if v_requested_role = 'SUPERVISOR'
    and nullif(payload ->> 'status', '') is distinct from 'active' then
    raise exception 'SUPERVISOR_PROFILE_INACTIVE';
  end if;

  if v_old_role = 'SUPERVISOR' and not public.actor_puede_administrar_accesos_internal(
    v_actor,
    v_empresa,
    array['usuarios.administrar','roles.administrar','permisos.administrar']::text[]
  ) then
    raise exception using
      errcode = '42501',
      message = 'SUPERVISOR_SCOPE_PERMISSION_DENIED';
  end if;

  select jsonb_build_object(
    'branch_ids', coalesce((
      select jsonb_agg(ps.sucursal_id order by ps.sucursal_id)
      from public.perfil_sucursales ps where ps.perfil_id = v_perfil
    ), '[]'::jsonb),
    'department_ids', coalesce((
      select jsonb_agg(pd.departamento_id order by pd.departamento_id)
      from public.perfil_departamentos pd where pd.perfil_id = v_perfil
    ), '[]'::jsonb)
  ) into v_antes;

  -- Si continúa siendo supervisor, sustituir primero el alcance permite
  -- reconciliar asignaciones históricas inválidas antes del trigger de profile.
  -- Todo sigue dentro de la misma transacción que actualizará el acceso.
  if v_old_role = 'SUPERVISOR' and v_requested_role = 'SUPERVISOR' then
    if v_old_status <> 'active' then
      -- Habilitación transitoria dentro de la transacción: permite sustituir
      -- el alcance de un supervisor inactivo que se está reactivando. Ningún
      -- estado intermedio puede confirmar si el guardado posterior falla.
      update public.profiles pr
      set status = 'active', updated_at = now()
      where pr.id = v_perfil and pr.company_id = v_empresa;
    end if;
    perform public.guardar_alcance_supervisor_internal(v_payload);
  end if;

  v_profile := public.actualizar_acceso_autorizacion_internal(v_payload);
  select private.normalizar_codigo_rol(r.code)
  into v_new_role
  from public.roles r
  where r.id = v_profile.role_id and r.company_id = v_empresa;

  if v_new_role = 'SUPERVISOR' then
    if v_old_role <> 'SUPERVISOR' then
      perform public.guardar_alcance_supervisor_internal(v_payload);
    end if;
  elsif payload ? 'branch_id' or payload ? 'department_ids' then
    raise exception 'SUPERVISOR_SCOPE_ROLE_INVALID';
  end if;

  if v_old_role = 'SUPERVISOR' and v_new_role <> 'SUPERVISOR' then
    select jsonb_build_object(
      'branch_ids', coalesce((
        select jsonb_agg(ps.sucursal_id order by ps.sucursal_id)
        from public.perfil_sucursales ps where ps.perfil_id = v_perfil
      ), '[]'::jsonb),
      'department_ids', coalesce((
        select jsonb_agg(pd.departamento_id order by pd.departamento_id)
        from public.perfil_departamentos pd where pd.perfil_id = v_perfil
      ), '[]'::jsonb)
    ) into v_despues;

    if v_antes is distinct from v_despues then
      insert into public.administracion_auditoria(
        empresa_id, actor_id, seccion, accion, entidad, entidad_id,
        antes, despues, motivo
      ) values (
        v_empresa, v_actor, 'accesos', 'DESACTIVAR_ALCANCE_SUPERVISOR',
        'profiles', v_perfil::text, v_antes, v_despues,
        'Limpieza transaccional por cambio de familia canonica de rol'
      );
    end if;
  end if;

  update public.administracion_auditoria a
  set antes = coalesce(a.antes, '{}'::jsonb)
      || jsonb_build_object('status', v_old_status),
      despues = coalesce(a.despues, '{}'::jsonb)
      || jsonb_build_object('operation_id', v_operation_id)
  where a.id = (
    select x.id
    from public.administracion_auditoria x
    where x.empresa_id = v_empresa
      and x.actor_id = v_actor
      and x.seccion = 'accesos'
      and x.accion = 'ACTUALIZAR_ACCESO'
      and x.entidad = 'profiles'
      and x.entidad_id = v_perfil::text
    order by x.id desc
    limit 1
  );
  if not found then raise exception 'UPDATE_ACCESS_AUDIT_NOT_FOUND'; end if;

  return v_profile;
end;
$$;
revoke all on function public.actualizar_acceso_con_alcance_internal(jsonb)
  from public, anon, authenticated;
grant execute on function public.actualizar_acceso_con_alcance_internal(jsonb)
  to service_role;

create or replace function public.obtener_actualizacion_acceso_confirmada_internal(payload jsonb)
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
  v_operation_id uuid := nullif(payload ->> 'operation_id', '')::uuid;
begin
  if v_actor is null or v_perfil is null or v_operation_id is null then
    raise exception 'ACCESO_DATOS_REQUERIDOS';
  end if;
  v_empresa := public.obtener_empresa_actor_activo_internal(v_actor);
  if not public.actor_puede_administrar_accesos_internal(
    v_actor, v_empresa, array['usuarios.edit','usuarios.administrar']::text[]
  ) then
    raise exception using errcode = '42501', message = 'ACCESS_ADMIN_PERMISSION_DENIED';
  end if;

  if not exists(
    select 1
    from public.administracion_auditoria a
    where a.empresa_id = v_empresa
      and a.actor_id = v_actor
      and a.seccion = 'accesos'
      and a.accion = 'ACTUALIZAR_ACCESO'
      and a.entidad = 'profiles'
      and a.entidad_id = v_perfil::text
      and a.despues ->> 'operation_id' = v_operation_id::text
  ) then
    return null;
  end if;

  return public.obtener_acceso_internal(jsonb_build_object(
    'actor_user_id', v_actor,
    'company_id', v_empresa,
    'profile_id', v_perfil,
    'required_permission', 'usuarios.edit'
  ));
end;
$$;
revoke all on function public.obtener_actualizacion_acceso_confirmada_internal(jsonb)
  from public, anon, authenticated;
grant execute on function public.obtener_actualizacion_acceso_confirmada_internal(jsonb)
  to service_role;

create or replace function public.cambiar_estado_acceso_con_alcance_internal(payload jsonb)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid;
  v_perfil uuid := nullif(payload ->> 'profile_id', '')::uuid;
  v_estado text := nullif(payload ->> 'status', '');
  v_role_code text;
begin
  if v_actor is null or v_perfil is null then raise exception 'ACCESO_DATOS_REQUERIDOS'; end if;
  v_empresa := public.obtener_empresa_actor_activo_internal(v_actor);

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_empresa::text, 0)
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_perfil::text, 33)
  );

  if v_estado = 'active' then
    select private.normalizar_codigo_rol(r.code)
    into v_role_code
    from public.profiles pr
    join public.roles r
      on r.id = pr.role_id
     and r.company_id = pr.company_id
     and r.is_active
    where pr.id = v_perfil
      and pr.company_id = v_empresa
      and pr.access_deleted_at is null
    for update of pr;

    if v_role_code = 'SUPERVISOR'
      and not public.alcance_supervisor_valido_internal(v_perfil, v_empresa) then
      raise exception 'SIN_DEPARTAMENTOS';
    end if;
  end if;

  return public.cambiar_estado_acceso_internal(
    payload || jsonb_build_object('company_id', v_empresa)
  );
end;
$$;
revoke all on function public.cambiar_estado_acceso_con_alcance_internal(jsonb)
  from public, anon, authenticated;
grant execute on function public.cambiar_estado_acceso_con_alcance_internal(jsonb)
  to service_role;

commit;
