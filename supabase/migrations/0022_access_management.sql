-- Accesos: contratos internos para administrar identidades sin duplicar datos personales.
-- Las funciones de esta migracion solo son invocables por la Edge Function con service_role.
begin;

alter table public.profiles
  add column if not exists access_deleted_at timestamptz;

create index if not exists profiles_company_access_active_idx
  on public.profiles(company_id, status)
  where access_deleted_at is null;

comment on column public.profiles.access_deleted_at is
  'Baja logica del acceso. El profile se conserva para no romper auditoria, nomina, prestamos ni enrolamiento.';

insert into public.permisos(codigo,nombre,descripcion,modulo,activo) values
 ('usuarios.view','Ver accesos','Consulta accesos vinculados a empleados.','administracion',true),
 ('usuarios.create','Crear accesos','Crea accesos vinculados a empleados.','administracion',true),
 ('usuarios.edit','Editar accesos','Edita empleado, usuario, rol y estado de un acceso.','administracion',true)
on conflict(codigo) do update
set nombre=excluded.nombre,descripcion=excluded.descripcion,modulo=excluded.modulo,activo=true;

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'empresa'
from public.roles r
join public.permisos p on p.codigo in('usuarios.view','usuarios.create','usuarios.edit')
where r.is_active
  and (
    upper(translate(trim(coalesce(r.code,'')),'ÁÉÍÓÚáéíóú','AEIOUaeiou'))
      in('ADMIN','ADMINISTRADOR','ADMINISTRATOR')
    or upper(translate(trim(coalesce(r.name,'')),'ÁÉÍÓÚáéíóú','AEIOUaeiou'))
      in('ADMIN','ADMINISTRADOR','ADMINISTRATOR')
  )
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

-- La baja de una identidad Auth debe conservar la auditoria historica. El UUID original
-- queda en una columna inmutable aunque auth.users ya no contenga la identidad.
alter table public.user_provisioning_audit
  add column if not exists target_user_id_snapshot uuid;

update public.user_provisioning_audit
set target_user_id_snapshot = target_user_id
where target_user_id_snapshot is null;

create or replace function public.set_user_provisioning_target_snapshot()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.target_user_id_snapshot := coalesce(new.target_user_id_snapshot, new.target_user_id);
  return new;
end;
$$;

drop trigger if exists user_provisioning_target_snapshot
  on public.user_provisioning_audit;
create trigger user_provisioning_target_snapshot
before insert on public.user_provisioning_audit
for each row execute function public.set_user_provisioning_target_snapshot();

alter table public.user_provisioning_audit
  alter column target_user_id drop not null;

alter table public.user_provisioning_audit
  drop constraint if exists user_provisioning_audit_target_user_id_fkey;

alter table public.user_provisioning_audit
  add constraint user_provisioning_audit_target_user_id_fkey
  foreign key (target_user_id) references auth.users(id) on delete set null;

alter table public.user_provisioning_audit
  alter column target_user_id_snapshot set not null;

comment on column public.user_provisioning_audit.target_user_id_snapshot is
  'UUID historico de la identidad administrada; se conserva despues de eliminar auth.users.';

create or replace function public.actor_puede_administrar_accesos_internal(
  p_actor uuid,
  p_empresa uuid,
  p_codigos text[]
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from unnest(coalesce(p_codigos, array[]::text[])) as requested(codigo)
    where coalesce(
      (
        select pp.permitido
        from public.profiles pr
        join public.permisos pe on pe.codigo = codigo and pe.activo
        join public.perfil_permisos pp
          on pp.perfil_id = pr.id and pp.permiso_id = pe.id
        where pr.id = p_actor
          and pr.company_id = p_empresa
          and pr.status = 'active'
          and pr.access_deleted_at is null
        limit 1
      ),
      (
        select rp.permitido
        from public.profiles pr
        join public.roles r
          on r.id = pr.role_id and r.company_id = pr.company_id and r.is_active
        join public.permisos pe on pe.codigo = codigo and pe.activo
        join public.rol_permisos rp
          on rp.rol_id = r.id and rp.permiso_id = pe.id
        where pr.id = p_actor
          and pr.company_id = p_empresa
          and pr.status = 'active'
          and pr.access_deleted_at is null
        limit 1
      ),
      false
    )
  )
$$;

create or replace function public.actor_puede_administrar_accesos_internal(
  p_actor uuid,
  p_empresa uuid
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.actor_puede_administrar_accesos_internal(
    p_actor,p_empresa,array['usuarios.administrar']::text[]
  )
$$;

create or replace function public.es_rol_administrador_internal(p_rol uuid, p_empresa uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.roles r
    where r.id = p_rol
      and r.company_id = p_empresa
      and r.is_active
      and (
        upper(translate(trim(coalesce(r.code, '')), 'ÁÉÍÓÚáéíóú', 'AEIOUaeiou'))
          in ('ADMIN', 'ADMINISTRADOR', 'ADMINISTRATOR')
        or upper(translate(trim(coalesce(r.name, '')), 'ÁÉÍÓÚáéíóú', 'AEIOUaeiou'))
          in ('ADMIN', 'ADMINISTRADOR', 'ADMINISTRATOR')
      )
  )
$$;

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
        'perfil_id', e.perfil_id
      ) order by e.nombre_completo)
      from public.empleados e
      where e.empresa_id = v_empresa
        and (e.activo or e.perfil_id is not null)
    ), '[]'::jsonb),
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id,
        'name', r.name,
        'code', r.code,
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

create or replace function public.obtener_acceso_internal(payload jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid := nullif(payload ->> 'company_id', '')::uuid;
  v_perfil uuid := nullif(payload ->> 'profile_id', '')::uuid;
  v_permiso text := coalesce(nullif(payload ->> 'required_permission', ''), 'usuarios.administrar');
  v_result jsonb;
begin
  if v_permiso not in ('usuarios.view','usuarios.edit','usuarios.administrar') then
    raise exception using errcode = '42501', message = 'ACCESS_ADMIN_PERMISSION_DENIED';
  end if;
  if v_actor is null or v_empresa is null or v_perfil is null
    or not public.actor_puede_administrar_accesos_internal(
      v_actor,v_empresa,array[v_permiso,'usuarios.administrar']::text[]
    ) then
    raise exception using errcode = '42501', message = 'ACCESS_ADMIN_PERMISSION_DENIED';
  end if;

  select jsonb_build_object(
    'id', pr.id,
    'company_id', pr.company_id,
    'username', coalesce(nullif(btrim(u.raw_user_meta_data ->> 'username'), ''), u.email, ''),
    'email', u.email,
    'employee_id', e.id,
    'employee_name', e.nombre_completo,
    'employee_code', e.codigo_empleado,
    'role_id', pr.role_id,
    'status', pr.status
  ) into v_result
  from public.profiles pr
  join auth.users u on u.id = pr.id
  left join public.empleados e
    on e.empresa_id = pr.company_id
   and e.perfil_id = pr.id
  where pr.company_id = v_empresa
    and pr.id = v_perfil
    and pr.access_deleted_at is null;

  if v_result is null then
    raise exception 'ACCESO_NO_ENCONTRADO';
  end if;
  return v_result;
end;
$$;

create or replace function public.crear_acceso_internal(payload jsonb)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid := nullif(payload ->> 'company_id', '')::uuid;
  v_usuario uuid := nullif(payload ->> 'user_id', '')::uuid;
  v_empleado_id uuid := nullif(payload ->> 'employee_id', '')::uuid;
  v_rol uuid := nullif(payload ->> 'role_id', '')::uuid;
  v_estado text := coalesce(nullif(payload ->> 'status', ''), 'active');
  v_empleado public.empleados;
  v_profile public.profiles;
begin
  if v_actor is null or v_empresa is null
    or not public.actor_puede_administrar_accesos_internal(
      v_actor,v_empresa,array['usuarios.create','usuarios.administrar']::text[]
    ) then
    raise exception using errcode = '42501', message = 'ACCESS_ADMIN_PERMISSION_DENIED';
  end if;
  if v_usuario is null or v_empleado_id is null or v_rol is null then
    raise exception 'ACCESO_DATOS_REQUERIDOS';
  end if;
  if v_estado not in ('active', 'inactive', 'suspended') then
    raise exception 'ESTADO_ACCESO_INVALIDO';
  end if;
  if not exists (select 1 from auth.users u where u.id = v_usuario) then
    raise exception 'USUARIO_AUTH_NO_ENCONTRADO';
  end if;
  if exists (select 1 from public.profiles pr where pr.id = v_usuario) then
    raise exception 'USUARIO_YA_TIENE_ACCESO';
  end if;
  if not exists (
    select 1 from public.roles r
    where r.id = v_rol and r.company_id = v_empresa and r.is_active
  ) then
    raise exception 'ROL_ACCESO_INVALIDO';
  end if;

  select * into v_empleado
  from public.empleados e
  where e.id = v_empleado_id
    and e.empresa_id = v_empresa
    and e.activo
  for update;
  if not found then
    raise exception 'EMPLEADO_ACCESO_INVALIDO';
  end if;
  if v_empleado.perfil_id is not null then
    raise exception 'EMPLEADO_YA_TIENE_ACCESO';
  end if;

  insert into public.profiles(
    id, company_id, role_id, branch_id, department_id, position_id,
    employee_code, full_name, phone, status
  ) values (
    v_usuario, v_empresa, v_rol, v_empleado.sucursal_id,
    v_empleado.departamento_id, v_empleado.puesto_id,
    v_empleado.codigo_empleado, v_empleado.nombre_completo,
    v_empleado.telefono, v_estado
  ) returning * into v_profile;

  update public.empleados
  set perfil_id = v_usuario, updated_at = now()
  where id = v_empleado_id
    and empresa_id = v_empresa
    and perfil_id is null;
  if not found then
    raise exception 'EMPLEADO_YA_TIENE_ACCESO';
  end if;

  insert into public.user_provisioning_audit(
    company_id, actor_user_id, target_user_id, target_user_id_snapshot,
    action, employee_id, role_id, details
  ) values (
    v_empresa, v_actor, v_usuario, v_usuario,
    'create_user', v_empleado_id, v_rol,
    jsonb_build_object('status', v_estado, 'source', 'access_management')
  );
  insert into public.administracion_auditoria(
    empresa_id, actor_id, seccion, accion, entidad, entidad_id, despues, motivo
  ) values (
    v_empresa, v_actor, 'accesos', 'CREAR_ACCESO', 'profiles', v_usuario::text,
    jsonb_build_object('employee_id', v_empleado_id, 'role_id', v_rol, 'status', v_estado),
    'Creacion de acceso vinculada a empleado'
  );
  return v_profile;
end;
$$;

create or replace function public.actualizar_acceso_internal(payload jsonb)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid := nullif(payload ->> 'company_id', '')::uuid;
  v_perfil uuid := nullif(payload ->> 'profile_id', '')::uuid;
  v_empleado_id uuid := nullif(payload ->> 'employee_id', '')::uuid;
  v_rol uuid := nullif(payload ->> 'role_id', '')::uuid;
  v_estado text := nullif(payload ->> 'status', '');
  v_profile_antes public.profiles;
  v_empleado public.empleados;
  v_empleado_anterior uuid;
  v_profile_despues public.profiles;
begin
  if v_actor is null or v_empresa is null
    or not public.actor_puede_administrar_accesos_internal(
      v_actor,v_empresa,array['usuarios.edit','usuarios.administrar']::text[]
    ) then
    raise exception using errcode = '42501', message = 'ACCESS_ADMIN_PERMISSION_DENIED';
  end if;
  if v_perfil is null or v_empleado_id is null or v_rol is null or v_estado is null then
    raise exception 'ACCESO_DATOS_REQUERIDOS';
  end if;
  if v_estado not in ('active', 'inactive', 'suspended') then
    raise exception 'ESTADO_ACCESO_INVALIDO';
  end if;
  if not exists (
    select 1 from public.roles r
    where r.id = v_rol and r.company_id = v_empresa and r.is_active
  ) then
    raise exception 'ROL_ACCESO_INVALIDO';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_empresa::text, 0));
  select * into v_profile_antes
  from public.profiles pr
  where pr.id = v_perfil and pr.company_id = v_empresa
    and pr.access_deleted_at is null
  for update;
  if not found then
    raise exception 'ACCESO_NO_ENCONTRADO';
  end if;
  if v_perfil = v_actor
    and (v_estado <> 'active' or v_rol <> v_profile_antes.role_id) then
    raise exception 'AUTO_CAMBIO_ACCESO_NO_PERMITIDO';
  end if;

  if public.es_rol_administrador_internal(v_profile_antes.role_id, v_empresa)
    and (v_estado <> 'active' or not public.es_rol_administrador_internal(v_rol, v_empresa))
    and not exists (
      select 1
      from public.profiles pr
      join public.roles r on r.id = pr.role_id and r.company_id = pr.company_id and r.is_active
      where pr.company_id = v_empresa
        and pr.id <> v_perfil
        and pr.status = 'active'
        and public.es_rol_administrador_internal(r.id, v_empresa)
    ) then
    raise exception 'ULTIMO_ADMINISTRADOR_NO_MODIFICABLE';
  end if;

  select * into v_empleado
  from public.empleados e
  where e.id = v_empleado_id
    and e.empresa_id = v_empresa
    and e.activo
  for update;
  if not found then
    raise exception 'EMPLEADO_ACCESO_INVALIDO';
  end if;
  if v_empleado.perfil_id is not null and v_empleado.perfil_id <> v_perfil then
    raise exception 'EMPLEADO_YA_TIENE_ACCESO';
  end if;

  select e.id into v_empleado_anterior
  from public.empleados e
  where e.empresa_id = v_empresa and e.perfil_id = v_perfil
  for update;

  if v_empleado_anterior is not null and v_empleado_anterior <> v_empleado_id then
    update public.empleados
    set perfil_id = null, updated_at = now()
    where id = v_empleado_anterior and empresa_id = v_empresa;
  end if;
  update public.empleados
  set perfil_id = v_perfil, updated_at = now()
  where id = v_empleado_id and empresa_id = v_empresa;

  update public.profiles
  set role_id = v_rol,
      branch_id = v_empleado.sucursal_id,
      department_id = v_empleado.departamento_id,
      position_id = v_empleado.puesto_id,
      employee_code = v_empleado.codigo_empleado,
      full_name = v_empleado.nombre_completo,
      phone = v_empleado.telefono,
      status = v_estado,
      updated_at = now()
  where id = v_perfil and company_id = v_empresa
  returning * into v_profile_despues;

  insert into public.administracion_auditoria(
    empresa_id, actor_id, seccion, accion, entidad, entidad_id, antes, despues, motivo
  ) values (
    v_empresa, v_actor, 'accesos', 'ACTUALIZAR_ACCESO', 'profiles', v_perfil::text,
    jsonb_build_object('employee_id', v_empleado_anterior, 'role_id', v_profile_antes.role_id, 'status', v_profile_antes.status),
    jsonb_build_object('employee_id', v_empleado_id, 'role_id', v_rol, 'status', v_estado),
    'Actualizacion de acceso vinculada a empleado'
  );
  return v_profile_despues;
end;
$$;

create or replace function public.cambiar_estado_acceso_internal(payload jsonb)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid := nullif(payload ->> 'company_id', '')::uuid;
  v_perfil uuid := nullif(payload ->> 'profile_id', '')::uuid;
  v_estado text := nullif(payload ->> 'status', '');
  v_antes public.profiles;
  v_despues public.profiles;
begin
  if v_actor is null or v_empresa is null
    or not public.actor_puede_administrar_accesos_internal(
      v_actor,v_empresa,array['usuarios.administrar']::text[]
    ) then
    raise exception using errcode = '42501', message = 'ACCESS_ADMIN_PERMISSION_DENIED';
  end if;
  if v_estado is null or v_estado not in ('active', 'inactive') then
    raise exception 'ESTADO_ACCESO_INVALIDO';
  end if;
  if v_perfil = v_actor and v_estado <> 'active' then
    raise exception 'AUTO_DESACTIVACION_NO_PERMITIDA';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_empresa::text, 0));
  select * into v_antes
  from public.profiles pr
  where pr.id = v_perfil and pr.company_id = v_empresa
    and pr.access_deleted_at is null
  for update;
  if not found then raise exception 'ACCESO_NO_ENCONTRADO'; end if;

  if v_estado <> 'active'
    and v_antes.status = 'active'
    and public.es_rol_administrador_internal(v_antes.role_id, v_empresa)
    and not exists (
      select 1 from public.profiles pr
      where pr.company_id = v_empresa
        and pr.id <> v_perfil
        and pr.status = 'active'
        and public.es_rol_administrador_internal(pr.role_id, v_empresa)
    ) then
    raise exception 'ULTIMO_ADMINISTRADOR_NO_DESACTIVABLE';
  end if;

  update public.profiles
  set status = v_estado, updated_at = now()
  where id = v_perfil and company_id = v_empresa
  returning * into v_despues;
  insert into public.administracion_auditoria(
    empresa_id, actor_id, seccion, accion, entidad, entidad_id, antes, despues, motivo
  ) values (
    v_empresa, v_actor, 'accesos', 'CAMBIAR_ESTADO', 'profiles', v_perfil::text,
    jsonb_build_object('status', v_antes.status), jsonb_build_object('status', v_estado),
    'Cambio de estado de acceso'
  );
  return v_despues;
end;
$$;

create or replace function public.eliminar_acceso_internal(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid := nullif(payload ->> 'company_id', '')::uuid;
  v_perfil uuid := nullif(payload ->> 'profile_id', '')::uuid;
  v_profile public.profiles;
  v_empleado uuid;
begin
  if v_actor is null or v_empresa is null
    or not public.actor_puede_administrar_accesos_internal(
      v_actor,v_empresa,array['usuarios.administrar']::text[]
    ) then
    raise exception using errcode = '42501', message = 'ACCESS_ADMIN_PERMISSION_DENIED';
  end if;
  if v_perfil is null then raise exception 'ACCESO_DATOS_REQUERIDOS'; end if;
  if v_perfil = v_actor then raise exception 'AUTO_ELIMINACION_NO_PERMITIDA'; end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_empresa::text, 0));
  select * into v_profile
  from public.profiles pr
  where pr.id = v_perfil and pr.company_id = v_empresa
    and pr.access_deleted_at is null
  for update;
  if not found then raise exception 'ACCESO_NO_ENCONTRADO'; end if;

  if public.es_rol_administrador_internal(v_profile.role_id, v_empresa)
    and not exists (
      select 1 from public.profiles pr
      where pr.company_id = v_empresa
        and pr.id <> v_perfil
        and pr.status = 'active'
        and public.es_rol_administrador_internal(pr.role_id, v_empresa)
    ) then
    raise exception 'ULTIMO_ADMINISTRADOR_NO_ELIMINABLE';
  end if;

  select e.id into v_empleado
  from public.empleados e
  where e.empresa_id = v_empresa and e.perfil_id = v_perfil
  for update;

  insert into public.administracion_auditoria(
    empresa_id, actor_id, seccion, accion, entidad, entidad_id, antes, motivo
  ) values (
    v_empresa, v_actor, 'accesos', 'ELIMINAR_ACCESO', 'auth.users', v_perfil::text,
    jsonb_build_object('employee_id', v_empleado, 'role_id', v_profile.role_id, 'status', v_profile.status),
    'Eliminacion de acceso; empleado conservado'
  );

  -- El profile no puede borrarse: nomina, prestamos, dispositivos y auditorias lo
  -- referencian con ON DELETE RESTRICT. La baja logica invalida autorizacion, libera
  -- al empleado y permite a la Edge Function bloquear/anomizar la identidad Auth.
  update public.empleados
  set perfil_id = null, updated_at = now()
  where id = v_empleado and empresa_id = v_empresa;
  update public.profiles
  set status = 'inactive',
      employee_code = null,
      access_deleted_at = now(),
      updated_at = now()
  where id = v_perfil and company_id = v_empresa;

  return jsonb_build_object(
    'deleted', true,
    'profile_id', v_perfil,
    'employee_id', v_empleado,
    'employee_preserved', true,
    'auth_cleanup_required', true
  );
end;
$$;

create or replace function public.registrar_operacion_acceso_internal(payload jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid := nullif(payload ->> 'company_id', '')::uuid;
  v_perfil uuid := nullif(payload ->> 'profile_id', '')::uuid;
  v_accion text := nullif(payload ->> 'action', '');
begin
  if v_actor is null or v_empresa is null
    or not public.actor_puede_administrar_accesos_internal(
      v_actor,v_empresa,
      case v_accion
        when 'CAMBIAR_USUARIO' then array['usuarios.edit','usuarios.administrar']::text[]
        else array['usuarios.administrar']::text[]
      end
    ) then
    raise exception using errcode = '42501', message = 'ACCESS_ADMIN_PERMISSION_DENIED';
  end if;
  if v_accion is null or v_accion not in ('CAMBIAR_CONTRASENA', 'CAMBIAR_USUARIO') then
    raise exception 'OPERACION_ACCESO_INVALIDA';
  end if;
  if not exists (
    select 1 from public.profiles pr
    where pr.id = v_perfil and pr.company_id = v_empresa
      and pr.access_deleted_at is null
  ) then
    raise exception 'ACCESO_NO_ENCONTRADO';
  end if;

  insert into public.administracion_auditoria(
    empresa_id, actor_id, seccion, accion, entidad, entidad_id, motivo
  ) values (
    v_empresa, v_actor, 'accesos', v_accion, 'auth.users', v_perfil::text,
    case v_accion
      when 'CAMBIAR_CONTRASENA' then 'Contrasena actualizada; el secreto no se registra'
      else 'Identificador de acceso actualizado; sin datos personales duplicados'
    end
  );
end;
$$;

comment on function public.crear_acceso_internal(jsonb) is
  'Crea profile y enlace 1:1 tomando datos personales exclusivamente de empleados.';
comment on function public.eliminar_acceso_internal(jsonb) is
  'Da de baja el acceso, conserva profile/empleado/auditoria y protege usuario actual y ultimo admin.';

revoke all on function public.actor_puede_administrar_accesos_internal(uuid, uuid) from public, anon, authenticated;
revoke all on function public.actor_puede_administrar_accesos_internal(uuid, uuid, text[]) from public, anon, authenticated;
revoke all on function public.set_user_provisioning_target_snapshot() from public, anon, authenticated;
revoke all on function public.es_rol_administrador_internal(uuid, uuid) from public, anon, authenticated;
revoke all on function public.listar_accesos_internal(jsonb) from public, anon, authenticated;
revoke all on function public.obtener_acceso_internal(jsonb) from public, anon, authenticated;
revoke all on function public.crear_acceso_internal(jsonb) from public, anon, authenticated;
revoke all on function public.actualizar_acceso_internal(jsonb) from public, anon, authenticated;
revoke all on function public.cambiar_estado_acceso_internal(jsonb) from public, anon, authenticated;
revoke all on function public.eliminar_acceso_internal(jsonb) from public, anon, authenticated;
revoke all on function public.registrar_operacion_acceso_internal(jsonb) from public, anon, authenticated;

grant execute on function public.actor_puede_administrar_accesos_internal(uuid, uuid) to service_role;
grant execute on function public.actor_puede_administrar_accesos_internal(uuid, uuid, text[]) to service_role;
grant execute on function public.es_rol_administrador_internal(uuid, uuid) to service_role;
grant execute on function public.listar_accesos_internal(jsonb) to service_role;
grant execute on function public.obtener_acceso_internal(jsonb) to service_role;
grant execute on function public.crear_acceso_internal(jsonb) to service_role;
grant execute on function public.actualizar_acceso_internal(jsonb) to service_role;
grant execute on function public.cambiar_estado_acceso_internal(jsonb) to service_role;
grant execute on function public.eliminar_acceso_internal(jsonb) to service_role;
grant execute on function public.registrar_operacion_acceso_internal(jsonb) to service_role;

commit;
