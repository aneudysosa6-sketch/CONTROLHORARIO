-- CONTROLHORARIO: contrato unificado de autenticacion, autorizacion y alcance.
-- Esta migracion no modifica historia aplicada; reemplaza funciones mediante
-- CREATE OR REPLACE y agrega defensas transaccionales para cambios de rol.

begin;

create or replace function private.normalizar_codigo_rol(p_codigo text)
returns text
language sql
immutable
set search_path = ''
as $$
  with entrada as (
    select upper(
      trim(
        regexp_replace(
          translate(
            replace(replace(coalesce(p_codigo, ''), '-', ' '), '_', ' '),
            'ÁÉÍÓÚÜÑáéíóúüñ',
            'AEIOUUNAEIOUUN'
          ),
          '[[:space:]]+',
          ' ',
          'g'
        )
      )
    ) as codigo
  )
  select case codigo
    when 'ADMIN' then 'ADMIN'
    when 'ADMINISTRADOR' then 'ADMIN'
    when 'ADMINISTRATOR' then 'ADMIN'
    when 'ADM' then 'ADMIN'
    when 'SUPER ADMIN' then 'ADMIN'
    when 'SUP' then 'SUPERVISOR'
    when 'SUPERVISOR' then 'SUPERVISOR'
    when 'SUPERVISOR APP' then 'SUPERVISOR'
    when 'SUPERVISORAPP' then 'SUPERVISOR'
    when 'EMPLEADO' then 'EMPLEADO'
    when 'EMPLOYEE' then 'EMPLEADO'
    when 'RRHH' then 'RRHH'
    when 'RR HH' then 'RRHH'
    when 'RH' then 'RRHH'
    when 'RECURSOS HUMANOS' then 'RRHH'
    when 'HUMAN RESOURCES' then 'RRHH'
    when 'NOMINA' then 'NOMINA'
    when 'PLANILLA' then 'NOMINA'
    when 'PAYROLL' then 'NOMINA'
    when 'NOMINA ADMIN' then 'NOMINA'
    when 'AUDITOR' then 'AUDITOR'
    when 'AUDITORIA' then 'AUDITOR'
    when 'AUDIT' then 'AUDITOR'
    else codigo
  end
  from entrada;
$$;

create or replace function private.es_rol_supervisor_aceptado(p_codigo text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select private.normalizar_codigo_rol(p_codigo) = 'SUPERVISOR';
$$;

-- Toda asignacion conservadora de lectura para alias de Supervisor mantiene
-- alcance departamento. Nunca se concede permiso administrativo o global.
insert into public.rol_permisos(rol_id, permiso_id, permitido, alcance)
select r.id, p.id, true, 'departamento'
from public.roles r
join public.permisos p on p.codigo in (
  'portal.acceder',
  'portal.ver_dashboard',
  'supervisor.dashboard',
  'empleados.ver_asignados',
  'jornadas.ver_asignadas',
  'incidencias.ver_asignadas',
  'horarios.ver_asignados'
)
where r.is_active
  and p.activo
  and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
on conflict(rol_id, permiso_id)
do update set permitido = true, alcance = 'departamento';

create or replace function public.obtener_departamentos_supervisor_actual()
returns table(departamento_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
  select alcance.departamento_id
  from (
    select p.department_id as departamento_id
    from public.profiles p
    join public.roles r
      on r.id = p.role_id
     and r.company_id = p.company_id
     and r.is_active
    join public.departments d
      on d.id = p.department_id
     and d.company_id = p.company_id
     and d.is_active is true
    where p.id = (select auth.uid())
      and p.status = 'active'
      and p.access_deleted_at is null
      and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'

    union

    select pd.departamento_id
    from public.profiles p
    join public.roles r
      on r.id = p.role_id
     and r.company_id = p.company_id
     and r.is_active
    join public.perfil_departamentos pd on pd.perfil_id = p.id
    join public.departments d
      on d.id = pd.departamento_id
     and d.company_id = p.company_id
     and d.is_active is true
    where p.id = (select auth.uid())
      and p.status = 'active'
      and p.access_deleted_at is null
      and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  ) alcance
  where alcance.departamento_id is not null;
$$;
revoke all on function public.obtener_departamentos_supervisor_actual()
  from public, anon;
grant execute on function public.obtener_departamentos_supervisor_actual()
  to authenticated;

create or replace function public.es_supervisor_actual()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.profiles p
    join public.roles r
      on r.id = p.role_id
     and r.company_id = p.company_id
    where p.id = (select auth.uid())
      and p.status = 'active'
      and p.access_deleted_at is null
      and r.is_active
      and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  );
$$;
revoke all on function public.es_supervisor_actual() from public, anon;
grant execute on function public.es_supervisor_actual() to authenticated;

create or replace function public.supervisor_puede_ver_empleado(p_empleado uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.profiles p
    join public.roles r
      on r.id = p.role_id
     and r.company_id = p.company_id
     and r.is_active
    join public.empleados e
      on e.id = p_empleado
     and e.empresa_id = p.company_id
    join public.departments d
      on d.id = e.departamento_id
     and d.company_id = e.empresa_id
     and d.branch_id = e.sucursal_id
    where p.id = (select auth.uid())
      and p.status = 'active'
      and p.access_deleted_at is null
      and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
      and public.tiene_permiso('empleados.ver_asignados')
      and e.activo
      and e.sucursal_id is not null
      and e.departamento_id is not null
      and e.departamento_id in (
        select alcance.departamento_id
        from public.obtener_departamentos_supervisor_actual() alcance
      )
      and (
        e.sucursal_id = p.branch_id
        or exists(
          select 1
          from public.perfil_sucursales ps
          where ps.perfil_id = p.id
            and ps.sucursal_id = e.sucursal_id
        )
      )
  );
$$;
revoke all on function public.supervisor_puede_ver_empleado(uuid)
  from public, anon;
grant execute on function public.supervisor_puede_ver_empleado(uuid)
  to authenticated;

-- Una sola fotografia consistente de identidad y autorizacion. La funcion
-- resuelve permisos con la misma prioridad oficial: perfil > rol > denegacion.
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
  v_employee_id uuid;
  v_permissions jsonb;
  v_departments jsonb;
  v_branches jsonb;
begin
  if v_uid is null then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;

  select *
  into v_profile
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

  select *
  into v_role
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

  select e.id
  into v_employee_id
  from public.empleados e
  where e.empresa_id = v_profile.company_id
    and e.perfil_id = v_profile.id
    and e.activo
    and e.estado_laboral = 'activo'
  limit 1;

  if exists(
    select 1
    from public.empleados e
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

  return jsonb_build_object(
    'auth_user_id', v_uid,
    'profile_id', v_profile.id,
    'company_id', v_profile.company_id,
    'employee_id', v_employee_id,
    'email', coalesce((select auth.jwt() ->> 'email'), ''),
    'nombre', v_profile.full_name,
    'role_id', v_role.id,
    'role_code_original', v_role.code,
    'role_code_canonical', private.normalizar_codigo_rol(v_role.code),
    'role_name', v_role.name,
    'active', true,
    'permission_codes', v_permissions,
    'departamento_principal_id', v_profile.department_id,
    'departamentos_adicionales', v_departments,
    'sucursales', v_branches,
    'authorization_version', transaction_timestamp()
  );
end;
$$;
revoke all on function public.obtener_mi_autorizacion() from public, anon;
grant execute on function public.obtener_mi_autorizacion() to authenticated;

-- Limpiar excepciones y alcance solo cuando cambia la familia canonica.
create or replace function public.limpiar_autorizacion_por_cambio_rol()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_family text;
  v_new_family text;
begin
  if new.role_id is not distinct from old.role_id then
    return new;
  end if;

  select private.normalizar_codigo_rol(r.code)
  into v_old_family
  from public.roles r
  where r.id = old.role_id and r.company_id = old.company_id;

  select private.normalizar_codigo_rol(r.code)
  into v_new_family
  from public.roles r
  where r.id = new.role_id and r.company_id = new.company_id;

  if v_old_family is distinct from v_new_family then
    delete from public.perfil_permisos where perfil_id = new.id;
    delete from public.perfil_departamentos where perfil_id = new.id;
    delete from public.perfil_sucursales where perfil_id = new.id;
  end if;
  return new;
end;
$$;
revoke all on function public.limpiar_autorizacion_por_cambio_rol()
  from public, anon, authenticated;

drop trigger if exists profiles_clear_authorization_after_role_change
  on public.profiles;
create trigger profiles_clear_authorization_after_role_change
after update of role_id on public.profiles
for each row execute function public.limpiar_autorizacion_por_cambio_rol();

-- Contrato interno unico para Edge Function. La limpieza de autorizacion se
-- ejecuta en la misma transaccion mediante el trigger anterior.
create or replace function public.actualizar_acceso_autorizacion_internal(payload jsonb)
returns public.profiles
language sql
security definer
set search_path = ''
as $$
  select public.actualizar_acceso_internal(payload);
$$;
revoke all on function public.actualizar_acceso_autorizacion_internal(jsonb)
  from public, anon, authenticated;
grant execute on function public.actualizar_acceso_autorizacion_internal(jsonb)
  to service_role;

create or replace function public.dashboard_supervisor()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.obtener_empresa_actual();
  v_tz text;
  v_fecha date;
  v_result jsonb;
  v_role_code text;
  v_tiene_permiso boolean;
  v_departamentos_count integer;
  v_resultado_scope text;
begin
  select private.normalizar_codigo_rol(r.code)
  into v_role_code
  from public.profiles p
  join public.roles r
    on r.id = p.role_id
   and r.company_id = p.company_id
  where p.id = (select auth.uid())
    and p.status = 'active'
    and p.access_deleted_at is null
  limit 1;

  v_tiene_permiso := public.tiene_permiso('supervisor.dashboard');
  select count(*)::int
  into v_departamentos_count
  from public.obtener_departamentos_supervisor_actual();

  if v_role_code is null or v_empresa is null then
    v_resultado_scope := 'PERFIL_INCONSISTENTE';
  elseif not v_tiene_permiso then
    v_resultado_scope := 'SIN_PERMISO';
  elseif v_role_code <> 'SUPERVISOR' then
    v_resultado_scope := 'ROL_NO_SUPERVISOR';
  elseif v_departamentos_count = 0 then
    v_resultado_scope := 'SIN_DEPARTAMENTOS';
  else
    v_resultado_scope := 'OK';
  end if;

  if v_resultado_scope <> 'OK' then
    raise exception using
      errcode = 'P0001',
      message = 'ALCANCE_O_PERMISO_DENEGADO',
      detail = jsonb_build_object(
        'user_id_presente', (select auth.uid()) is not null,
        'empresa_id_presente', v_empresa is not null,
        'role_code', coalesce(v_role_code, ''),
        'permiso_solicitado', 'supervisor.dashboard',
        'departamentos_asignados_count', coalesce(v_departamentos_count, 0),
        'resultado_scope', v_resultado_scope
      )::text,
      hint = v_resultado_scope;
  end if;

  select timezone into v_tz
  from public.companies
  where id = v_empresa;
  v_fecha := (now() at time zone coalesce(v_tz, 'America/Santo_Domingo'))::date;

  with equipo as (
    select e.*
    from public.empleados e
    where e.empresa_id = v_empresa
      and public.supervisor_puede_ver_empleado(e.id)
  ),
  dia as (
    select j.*
    from public.jornadas j
    join equipo e on e.id = j.empleado_id
    where j.fecha_laboral = v_fecha
  ),
  inc as (
    select i.*
    from public.jornada_incidencias i
    join equipo e on e.id = i.empleado_id
    where not i.resuelta
  )
  select jsonb_build_object(
    'fecha_laboral', v_fecha,
    'total_empleados', (select count(*) from equipo),
    'activos', (select count(*) from equipo where activo),
    'sin_iniciar', (
      select count(*) from equipo e
      where e.activo and e.jornada_habilitada
        and not exists(select 1 from dia j where j.empleado_id = e.id)
    ),
    'en_curso', (select count(*) from dia where estado = 'EN_CURSO'),
    'en_pausa', (select count(*) from dia where estado = 'EN_PAUSA'),
    'finalizadas', (select count(*) from dia where estado = 'FINALIZADA'),
    'pendientes', (select count(*) from dia where revision_pendiente),
    'incidencias_nuevas', (select count(*) from inc where not leida),
    'jornadas_deshabilitadas', (
      select count(*) from equipo where not jornada_habilitada
    ),
    'sin_iniciar_empleados', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', e.id,
          'codigo', e.codigo_empleado,
          'nombre', e.nombre_completo
        )
        order by e.nombre_completo
      )
      from equipo e
      where e.activo and e.jornada_habilitada
        and not exists(select 1 from dia j where j.empleado_id = e.id)
    ), '[]'::jsonb),
    'recientes', coalesce((
      select jsonb_agg(x order by x ->> 'actualizada_en' desc)
      from (
        select jsonb_build_object(
          'id', j.id,
          'empleado_id', e.id,
          'codigo', e.codigo_empleado,
          'nombre', e.nombre_completo,
          'estado', j.estado,
          'actualizada_en', j.actualizada_en,
          'severidad', j.severidad
        ) x
        from dia j
        join equipo e on e.id = j.empleado_id
        order by j.actualizada_en desc
        limit 10
      ) q
    ), '[]'::jsonb),
    'incidencias', coalesce((
      select jsonb_agg(x order by x ->> 'creada_en' desc)
      from (
        select jsonb_build_object(
          'id', i.id,
          'jornada_id', i.jornada_id,
          'empleado_id', e.id,
          'nombre', e.nombre_completo,
          'tipo', i.tipo,
          'severidad', i.severidad,
          'mensaje', i.mensaje,
          'creada_en', i.creada_en
        ) x
        from inc i
        join equipo e on e.id = i.empleado_id
        order by i.creada_en desc
        limit 10
      ) q
    ), '[]'::jsonb) || coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', e.id,
          'jornada_id', null,
          'empleado_id', e.id,
          'nombre', e.nombre_completo,
          'tipo', 'SIN_INICIAR',
          'severidad', 'ALTA',
          'mensaje', 'Empleado sin iniciar jornada',
          'creada_en', now()
        )
      )
      from equipo e
      where e.activo and e.jornada_habilitada
        and not exists(select 1 from dia j where j.empleado_id = e.id)
    ), '[]'::jsonb)
  )
  into v_result;

  return v_result;
end;
$$;
revoke all on function public.dashboard_supervisor() from public, anon;
grant execute on function public.dashboard_supervisor() to authenticated;

commit;
