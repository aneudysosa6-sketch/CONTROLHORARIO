-- CONTROLHORARIO - precheck de promocion a produccion (solo lectura)
--
-- Este archivo no modifica datos ni catalogos. Todas sus sentencias comienzan
-- con SELECT y consultan exclusivamente datos o metadatos.
--
-- IMPORTANTE: PostgreSQL no expone de forma fiable el project-ref de Supabase.
-- La identidad de este primer bloque NO sustituye la doble confirmacion externa
-- del nombre, project-ref y host de produccion descrita en el runbook.

select
  'environment_identity' as check_name,
  current_database() as database_name,
  current_user as current_role,
  session_user as session_role,
  inet_server_addr()::text as server_address,
  inet_server_port() as server_port,
  current_setting('server_version') as server_version,
  current_setting('row_security') as row_security,
  to_regnamespace('public') is not null as public_schema_exists,
  to_regnamespace('private') is not null as private_schema_exists,
  to_regnamespace('auth') is not null as auth_schema_exists,
  to_regclass('supabase_migrations.schema_migrations') is not null
    as migration_history_exists;

-- Historial completo para archivar y comparar con el artefacto aprobado.
select
  version
from supabase_migrations.schema_migrations
order by version;

-- Estado previo esperado: 0029 instalada; 0030-0036 todavia pendientes.
select
  expected.version,
  expected.should_be_installed_before_promotion,
  installed.version is not null as is_installed,
  (installed.version is not null) = expected.should_be_installed_before_promotion
    as matches_expected_pre_state
from (values
  ('0029'::text, true),
  ('0030', false),
  ('0031', false),
  ('0032', false),
  ('0033', false),
  ('0034', false),
  ('0035', false),
  ('0036', false)
) as expected(version, should_be_installed_before_promotion)
left join supabase_migrations.schema_migrations as installed
  on installed.version = expected.version
order by expected.version;

-- Deben existir exactamente las migraciones locales 0001-0029 antes del lote.
select
  expected.version,
  installed.version is not null as is_installed
from (
  select lpad(series.number::text, 4, '0') as version
  from generate_series(1, 29) as series(number)
) as expected
left join supabase_migrations.schema_migrations as installed
  on installed.version = expected.version
order by expected.version;

-- Cualquier version fuera de 0001-0036 exige explicacion y revision NO-GO.
select
  version
from supabase_migrations.schema_migrations
where version !~ '^(000[1-9]|00[12][0-9]|003[0-6])$'
order by version;

-- Tablas necesarias para 0030-0036 y para los dos handlers Edge.
select
  wanted.schema_name,
  wanted.table_name,
  c.oid is not null as exists,
  case c.relkind
    when 'r' then 'table'
    when 'p' then 'partitioned table'
    when 'v' then 'view'
    when 'm' then 'materialized view'
    else c.relkind::text
  end as object_kind,
  pg_get_userbyid(c.relowner) as owner
from (values
  ('auth', 'users'),
  ('public', 'companies'),
  ('public', 'profiles'),
  ('public', 'roles'),
  ('public', 'branches'),
  ('public', 'departments'),
  ('public', 'empleados'),
  ('public', 'permisos'),
  ('public', 'rol_permisos'),
  ('public', 'perfil_permisos'),
  ('public', 'perfil_sucursales'),
  ('public', 'perfil_departamentos'),
  ('public', 'user_provisioning_audit'),
  ('public', 'administracion_auditoria'),
  ('public', 'supervisor_auditoria')
) as wanted(schema_name, table_name)
left join pg_namespace as n on n.nspname = wanted.schema_name
left join pg_class as c
  on c.relnamespace = n.oid
 and c.relname = wanted.table_name
 and c.relkind in ('r', 'p', 'v', 'm')
order by wanted.schema_name, wanted.table_name;

-- Columnas minimas que los cambios leen o escriben.
select
  wanted.table_schema,
  wanted.table_name,
  wanted.column_name,
  columns.column_name is not null as exists,
  columns.data_type,
  columns.udt_name,
  columns.is_nullable,
  columns.column_default
from (values
  ('auth', 'users', 'id'),
  ('public', 'companies', 'id'),
  ('public', 'companies', 'status'),
  ('public', 'profiles', 'id'),
  ('public', 'profiles', 'company_id'),
  ('public', 'profiles', 'role_id'),
  ('public', 'profiles', 'branch_id'),
  ('public', 'profiles', 'department_id'),
  ('public', 'profiles', 'status'),
  ('public', 'profiles', 'access_deleted_at'),
  ('public', 'roles', 'id'),
  ('public', 'roles', 'company_id'),
  ('public', 'roles', 'code'),
  ('public', 'roles', 'is_active'),
  ('public', 'branches', 'id'),
  ('public', 'branches', 'company_id'),
  ('public', 'branches', 'status'),
  ('public', 'departments', 'id'),
  ('public', 'departments', 'company_id'),
  ('public', 'departments', 'branch_id'),
  ('public', 'departments', 'is_active'),
  ('public', 'empleados', 'id'),
  ('public', 'empleados', 'empresa_id'),
  ('public', 'empleados', 'perfil_id'),
  ('public', 'empleados', 'activo'),
  ('public', 'permisos', 'id'),
  ('public', 'permisos', 'codigo'),
  ('public', 'permisos', 'nombre'),
  ('public', 'permisos', 'descripcion'),
  ('public', 'permisos', 'modulo'),
  ('public', 'permisos', 'activo'),
  ('public', 'rol_permisos', 'rol_id'),
  ('public', 'rol_permisos', 'permiso_id'),
  ('public', 'rol_permisos', 'permitido'),
  ('public', 'rol_permisos', 'alcance'),
  ('public', 'perfil_permisos', 'perfil_id'),
  ('public', 'perfil_permisos', 'permiso_id'),
  ('public', 'perfil_permisos', 'permitido'),
  ('public', 'perfil_sucursales', 'perfil_id'),
  ('public', 'perfil_sucursales', 'sucursal_id'),
  ('public', 'perfil_departamentos', 'perfil_id'),
  ('public', 'perfil_departamentos', 'departamento_id'),
  ('public', 'user_provisioning_audit', 'company_id'),
  ('public', 'user_provisioning_audit', 'actor_user_id'),
  ('public', 'user_provisioning_audit', 'action'),
  ('public', 'user_provisioning_audit', 'details'),
  ('public', 'administracion_auditoria', 'empresa_id'),
  ('public', 'administracion_auditoria', 'actor_id'),
  ('public', 'administracion_auditoria', 'accion'),
  ('public', 'administracion_auditoria', 'despues'),
  ('public', 'supervisor_auditoria', 'empresa_id'),
  ('public', 'supervisor_auditoria', 'actor_id'),
  ('public', 'supervisor_auditoria', 'entidad'),
  ('public', 'supervisor_auditoria', 'entidad_id'),
  ('public', 'supervisor_auditoria', 'accion'),
  ('public', 'supervisor_auditoria', 'antes'),
  ('public', 'supervisor_auditoria', 'despues')
) as wanted(table_schema, table_name, column_name)
left join information_schema.columns as columns
  on columns.table_schema = wanted.table_schema
 and columns.table_name = wanted.table_name
 and columns.column_name = wanted.column_name
order by wanted.table_schema, wanted.table_name, wanted.column_name;

-- Inventario completo de columnas y constraints para conservar como baseline.
select
  table_name,
  column_name,
  ordinal_position,
  data_type,
  udt_name,
  is_nullable,
  column_default
from information_schema.columns
where table_schema = 'public'
  and table_name in (
    'companies', 'profiles', 'roles', 'branches', 'departments',
    'empleados', 'permisos', 'rol_permisos', 'perfil_permisos',
    'perfil_sucursales', 'perfil_departamentos',
    'user_provisioning_audit', 'administracion_auditoria',
    'supervisor_auditoria'
  )
order by table_name, ordinal_position;

select
  c.relname as table_name,
  constraints.conname,
  constraints.contype,
  pg_get_constraintdef(constraints.oid, true) as definition
from pg_constraint as constraints
join pg_class as c on c.oid = constraints.conrelid
join pg_namespace as n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'profiles', 'roles', 'empleados', 'permisos', 'rol_permisos',
    'perfil_sucursales', 'perfil_departamentos',
    'user_provisioning_audit', 'administracion_auditoria'
  )
order by c.relname, constraints.conname;

-- Funciones reemplazadas o requeridas. La ausencia de objetos 0033/0034 es
-- normal antes del lote; los prerrequisitos deben existir ya.
select
  wanted.phase,
  wanted.signature,
  p.oid is not null as exists,
  pg_get_function_result(p.oid) as result_type,
  case p.provolatile
    when 'i' then 'IMMUTABLE'
    when 's' then 'STABLE'
    when 'v' then 'VOLATILE'
  end as volatility,
  p.prosecdef as security_definer,
  p.proconfig as runtime_config,
  pg_get_userbyid(p.proowner) as owner,
  case
    when p.oid is null then null
    else md5(pg_get_functiondef(p.oid))
  end as definition_md5
from (values
  ('0030', 'private.normalizar_codigo_rol(text)'),
  ('0033', 'public.obtener_empresa_actor_activo_internal(uuid)'),
  ('0033', 'public.alcance_supervisor_valido_internal(uuid,uuid)'),
  ('0033', 'public.guardar_alcance_supervisor_internal(jsonb)'),
  ('0033', 'public.obtener_alcance_supervisor_internal(jsonb)'),
  ('0033', 'public.listar_accesos_internal(jsonb)'),
  ('0033', 'public.validar_alcance_supervisor()'),
  ('0033', 'public.proteger_sucursal_asignada_supervisor()'),
  ('0033', 'public.validar_cambio_sucursal_supervisor()'),
  ('0033', 'public.obtener_departamentos_supervisor_actual()'),
  ('0033', 'public.supervisor_puede_ver_empleado(uuid)'),
  ('0033', 'public.obtener_mi_autorizacion()'),
  ('0033', 'public.guardar_departamento_administracion(uuid,jsonb,uuid,text)'),
  ('0033', 'public.crear_acceso_con_alcance_internal(jsonb)'),
  ('0033', 'public.obtener_creacion_acceso_idempotente_internal(jsonb)'),
  ('0033', 'public.actualizar_acceso_con_alcance_internal(jsonb)'),
  ('0033', 'public.obtener_actualizacion_acceso_confirmada_internal(jsonb)'),
  ('0033', 'public.cambiar_estado_acceso_con_alcance_internal(jsonb)'),
  ('0034', 'public.auditar_asignacion_supervisor()'),
  ('prerequisite', 'public.actor_puede_administrar_accesos_internal(uuid,uuid,text[])'),
  ('prerequisite', 'public.perfil_acceso_utilizable_internal(uuid,uuid)'),
  ('prerequisite', 'public.crear_acceso_internal(jsonb)'),
  ('prerequisite', 'public.actualizar_acceso_autorizacion_internal(jsonb)'),
  ('prerequisite', 'public.obtener_acceso_internal(jsonb)'),
  ('prerequisite', 'public.cambiar_estado_acceso_internal(jsonb)'),
  ('edge_dependency', 'public.registrar_operacion_acceso_internal(jsonb)'),
  ('edge_dependency', 'public.eliminar_acceso_internal(jsonb)'),
  ('edge_dependency', 'public.bootstrap_tenant_internal(jsonb)'),
  ('edge_dependency', 'public.provision_user_internal(jsonb)'),
  ('edge_dependency', 'public.preview_next_employee_code_internal(uuid)'),
  ('edge_dependency', 'public.allocate_next_employee_code_internal(uuid,uuid)'),
  ('edge_dependency', 'public.actualizar_auth_sync_ciclo_empleado_internal(uuid,bigint,text,text[],text)'),
  ('edge_dependency', 'public.finalizar_reactivacion_acceso_internal(uuid,bigint)'),
  ('edge_dependency', 'public.desvincular_empleado(uuid,date,text,text)'),
  ('edge_dependency', 'public.reactivar_empleado(uuid,text)'),
  ('prerequisite', 'public.tiene_permiso(text)')
) as wanted(phase, signature)
left join pg_proc as p on p.oid = to_regprocedure(wanted.signature)
order by wanted.phase, wanted.signature;

-- Contrato funcional de 0030. Antes del lote los dos aliases nuevos pueden
-- diferir; despues todos los resultados deben coincidir con expected_result.
select
  samples.input_code,
  samples.expected_result,
  private.normalizar_codigo_rol(samples.input_code) as observed_result,
  private.normalizar_codigo_rol(samples.input_code) = samples.expected_result
    as matches_expected_after_0030
from (values
  ('EMPLEADO', 'EMPLEADO'),
  ('EMPLEADOS', 'EMPLEADO'),
  ('EMPLOYEES', 'EMPLEADO'),
  ('SUPERVISOR', 'SUPERVISOR'),
  ('ADMIN', 'ADMIN')
) as samples(input_code, expected_result)
order by samples.input_code;

-- Preimagen completa requerida para una eventual compensacion de 0030.
select
  pg_get_userbyid(p.proowner) as owner,
  p.proacl as function_acl,
  p.proconfig as runtime_config,
  pg_get_functiondef(p.oid) as function_definition
from pg_proc as p
where p.oid = to_regprocedure('private.normalizar_codigo_rol(text)');

-- Overloads no esperados pueden hacer ambiguo el RPC de PostgREST.
select
  n.nspname as function_schema,
  p.proname as function_name,
  count(*) as overload_count,
  array_agg(
    pg_get_function_identity_arguments(p.oid)
    order by pg_get_function_identity_arguments(p.oid)
  ) as overloads
from pg_proc as p
join pg_namespace as n on n.oid = p.pronamespace
where n.nspname in ('public', 'private')
  and p.proname in (
    'normalizar_codigo_rol',
    'obtener_empresa_actor_activo_internal',
    'alcance_supervisor_valido_internal',
    'guardar_alcance_supervisor_internal',
    'obtener_alcance_supervisor_internal',
    'listar_accesos_internal',
    'validar_alcance_supervisor',
    'proteger_sucursal_asignada_supervisor',
    'validar_cambio_sucursal_supervisor',
    'obtener_departamentos_supervisor_actual',
    'supervisor_puede_ver_empleado',
    'obtener_mi_autorizacion',
    'guardar_departamento_administracion',
    'crear_acceso_con_alcance_internal',
    'obtener_creacion_acceso_idempotente_internal',
    'actualizar_acceso_con_alcance_internal',
    'obtener_actualizacion_acceso_confirmada_internal',
    'cambiar_estado_acceso_con_alcance_internal',
    'auditar_asignacion_supervisor'
  )
group by n.nspname, p.proname
order by n.nspname, p.proname;

-- Estado parcial esperado antes del lote. La funcion auditora ya existe desde
-- 0009; los dos indices y el wrapper de alta 0033 todavia no deben existir.
select
  objects.object_name,
  objects.expected_before_promotion,
  objects.object_oid is not null as object_exists,
  (objects.object_oid is not null) = objects.expected_before_promotion
    as matches_expected_pre_state
from (values
  (
    'public.user_provisioning_audit_create_idempotency_idx',
    to_regclass('public.user_provisioning_audit_create_idempotency_idx')::oid,
    false
  ),
  (
    'public.administracion_auditoria_access_operation_idx',
    to_regclass('public.administracion_auditoria_access_operation_idx')::oid,
    false
  ),
  (
    'public.crear_acceso_con_alcance_internal(jsonb)',
    to_regprocedure('public.crear_acceso_con_alcance_internal(jsonb)')::oid,
    false
  ),
  (
    'public.auditar_asignacion_supervisor()',
    to_regprocedure('public.auditar_asignacion_supervisor()')::oid,
    true
  )
) as objects(object_name, object_oid, expected_before_promotion)
order by objects.object_name;

-- Triggers heredados de 0009/0029. 0033 reemplaza funciones, no crea estos
-- triggers; todos deben existir y apuntar a la funcion indicada.
select
  expected.table_name,
  expected.trigger_name,
  expected.expected_function,
  t.oid is not null as trigger_exists,
  t.tgenabled,
  pn.nspname || '.' || p.proname as installed_function,
  pg_get_triggerdef(t.oid, true) as trigger_definition
from (values
  ('perfil_sucursales', 'perfil_sucursales_validate_rc3', 'public.validar_alcance_supervisor'),
  ('perfil_departamentos', 'perfil_departamentos_validate_rc3', 'public.validar_alcance_supervisor'),
  ('perfil_sucursales', 'perfil_sucursales_protect_rc3', 'public.proteger_sucursal_asignada_supervisor'),
  ('perfil_sucursales', 'perfil_sucursales_audit_rc3', 'public.auditar_asignacion_supervisor'),
  ('perfil_departamentos', 'perfil_departamentos_audit_rc3', 'public.auditar_asignacion_supervisor'),
  ('profiles', 'profiles_validate_supervisor_branch_rc3', 'public.validar_cambio_sucursal_supervisor'),
  ('profiles', 'profiles_clear_authorization_after_role_change', 'public.limpiar_autorizacion_por_cambio_rol')
) as expected(table_name, trigger_name, expected_function)
left join pg_class as c
  on c.relnamespace = 'public'::regnamespace
 and c.relname = expected.table_name
left join pg_trigger as t
  on t.tgrelid = c.oid
 and t.tgname = expected.trigger_name
 and not t.tgisinternal
left join pg_proc as p on p.oid = t.tgfoid
left join pg_namespace as pn on pn.oid = p.pronamespace
order by expected.table_name, expected.trigger_name;

-- Baseline exacto de todos los triggers no internos en las tablas afectadas.
select
  c.relname as table_name,
  t.tgname as trigger_name,
  t.tgenabled,
  pn.nspname as function_schema,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as function_arguments,
  pg_get_triggerdef(t.oid, true) as trigger_definition
from pg_trigger as t
join pg_class as c on c.oid = t.tgrelid
join pg_namespace as cn on cn.oid = c.relnamespace
join pg_proc as p on p.oid = t.tgfoid
join pg_namespace as pn on pn.oid = p.pronamespace
where cn.nspname = 'public'
  and not t.tgisinternal
  and c.relname in (
    'profiles', 'roles', 'empleados', 'permisos',
    'perfil_sucursales', 'perfil_departamentos'
  )
order by c.relname, t.tgname;

-- Definicion actual del trigger corregido por 0034. Se archiva antes y despues.
select
  p.oid is not null as exists,
  case when p.oid is null then null else pg_get_functiondef(p.oid) end
    as function_definition
from pg_proc as p
where p.oid = to_regprocedure('public.auditar_asignacion_supervisor()');

-- BLOQUEADOR CRITICO: debe ser 0 con el orden normal 0033 -> 0034. Si hay
-- candidatos, el INSERT inicial de 0033 puede disparar el trigger antiguo y
-- abortar con 42703 antes de que 0034 llegue a corregirlo.
select
  count(*) as migration_0033_backfill_candidates,
  count(*) = 0 as safe_for_0033_before_0034
from (
  select distinct pd.perfil_id, d.branch_id
  from public.perfil_departamentos as pd
  join public.profiles as pr on pr.id = pd.perfil_id
  join public.roles as r
    on r.id = pr.role_id
   and r.company_id = pr.company_id
  join public.departments as d
    on d.id = pd.departamento_id
   and d.company_id = pr.company_id
  join public.branches as b
    on b.id = d.branch_id
   and b.company_id = pr.company_id
  where private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
    and d.branch_id is not null
    and not exists (
      select 1
      from public.perfil_sucursales as existing
      where existing.perfil_id = pd.perfil_id
        and existing.sucursal_id = d.branch_id
    )
) as candidates;

-- Duplicados que impedirian crear los indices unicos parciales de 0033.
select
  'user_provisioning_idempotency_duplicates' as check_name,
  count(*) as duplicate_groups,
  coalesce(sum(groups.occurrences), 0)::bigint as affected_rows
from (
  select count(*)::bigint as occurrences
  from public.user_provisioning_audit
  where action = 'create_user'
    and details ? 'idempotency_key'
  group by company_id, actor_user_id, details ->> 'idempotency_key'
  having count(*) > 1
) as groups
union all
select
  'access_operation_duplicates',
  count(*),
  coalesce(sum(groups.occurrences), 0)::bigint
from (
  select count(*)::bigint as occurrences
  from public.administracion_auditoria
  where accion = 'ACTUALIZAR_ACCESO'
    and despues ? 'operation_id'
  group by empresa_id, actor_id, despues ->> 'operation_id'
  having count(*) > 1
) as groups;

-- IF NOT EXISTS no detecta un indice homonimo con definicion incorrecta.
select
  wanted.index_name,
  c.relkind,
  i.indisunique,
  pg_get_indexdef(i.indexrelid) as definition,
  pg_get_expr(i.indpred, i.indrelid) as predicate
from (values
  ('user_provisioning_audit_create_idempotency_idx'),
  ('administracion_auditoria_access_operation_idx')
) as wanted(index_name)
left join pg_class as c
  on c.relnamespace = 'public'::regnamespace
 and c.relname = wanted.index_name
left join pg_index as i on i.indexrelid = c.oid
order by wanted.index_name;

-- Catalogo relevante y asignaciones existentes. La salida es tambien baseline
-- para demostrar que 0031/0032 no alteraron otros codigos.
select
  wanted.codigo as requested_code,
  p.id as permission_id,
  p.codigo,
  p.nombre,
  p.descripcion,
  p.modulo,
  p.activo,
  count(rp.rol_id) as assignment_count,
  count(rp.rol_id) filter (where rp.permitido) as allowed_assignment_count
from (values
  ('usuarios.administrar'),
  ('roles.administrar'),
  ('permisos.administrar'),
  ('portal.ver_dashboard'),
  ('supervisor.dashboard'),
  ('empleados.ver_asignados'),
  ('jornadas.ver_asignadas'),
  ('configuracion.ver'),
  ('configuracion.administrar')
) as wanted(codigo)
left join public.permisos as p on p.codigo = wanted.codigo
left join public.rol_permisos as rp on rp.permiso_id = p.id
group by
  wanted.codigo, p.id, p.codigo, p.nombre, p.descripcion, p.modulo, p.activo
order by wanted.codigo;

select
  c.id as company_id,
  c.status as company_status,
  r.id as role_id,
  r.code as role_code_original,
  private.normalizar_codigo_rol(r.code) as role_code_canonical,
  r.is_active,
  wanted.codigo,
  p.activo as permission_active,
  rp.permitido,
  rp.alcance
from public.roles as r
join public.companies as c on c.id = r.company_id
cross join (values
  ('configuracion.ver'),
  ('configuracion.administrar'),
  ('usuarios.administrar'),
  ('roles.administrar'),
  ('permisos.administrar'),
  ('portal.ver_dashboard'),
  ('supervisor.dashboard'),
  ('empleados.ver_asignados'),
  ('jornadas.ver_asignadas')
) as wanted(codigo)
left join public.permisos as p on p.codigo = wanted.codigo
left join public.rol_permisos as rp
  on rp.rol_id = r.id
 and rp.permiso_id = p.id
where private.normalizar_codigo_rol(r.code) in ('ADMIN', 'SUPERVISOR')
order by r.company_id, r.id, wanted.codigo;

-- 0031/0032 usan upper(code) exacto; aliases canonicos quedan fuera.
select
  private.normalizar_codigo_rol(code) as canonical_code,
  count(*) as active_roles,
  count(*) filter (
    where upper(code) in ('ADMIN', 'SUPERVISOR')
  ) as exact_target_roles,
  count(*) filter (
    where upper(code) not in ('ADMIN', 'SUPERVISOR')
  ) as canonical_aliases_not_targeted
from public.roles
where is_active
  and private.normalizar_codigo_rol(code) in ('ADMIN', 'SUPERVISOR')
group by private.normalizar_codigo_rol(code)
order by canonical_code;

-- Si un permiso objetivo esta inactivo, el upsert lo reactiva para todas sus
-- asignaciones existentes, incluidas las de roles no objetivo.
select
  p.codigo,
  p.activo as current_permission_active,
  count(*) filter (
    where rp.permitido
      and not (
        (
          p.codigo in (
            'usuarios.administrar', 'roles.administrar',
            'permisos.administrar'
          )
          and upper(r.code) = 'ADMIN'
        )
        or (
          p.codigo = 'portal.ver_dashboard'
          and upper(r.code) in ('ADMIN', 'SUPERVISOR')
        )
      )
  ) as allowed_non_target_assignments_activated_if_catalog_reactivated
from public.permisos as p
left join public.rol_permisos as rp on rp.permiso_id = p.id
left join public.roles as r on r.id = rp.rol_id
where p.codigo in (
  'usuarios.administrar', 'roles.administrar',
  'permisos.administrar', 'portal.ver_dashboard'
)
group by p.codigo, p.activo
order by p.codigo;

-- Denegaciones individuales prevalecen sobre el grant del rol.
select
  pe.codigo,
  count(*) as explicit_profile_denials
from public.perfil_permisos as pp
join public.permisos as pe on pe.id = pp.permiso_id
where not pp.permitido
  and pe.codigo in (
    'configuracion.ver', 'configuracion.administrar',
    'usuarios.administrar', 'roles.administrar',
    'permisos.administrar', 'portal.ver_dashboard',
    'supervisor.dashboard', 'empleados.ver_asignados',
    'jornadas.ver_asignadas'
  )
group by pe.codigo
order by pe.codigo;

-- Baseline determinista para probar que el lote no altero permisos fuera de
-- los cuatro codigos objetivo ni excepciones individuales.
select
  (
    select md5(coalesce(string_agg(
      concat_ws(
        '|', p.id::text, p.codigo, p.nombre,
        coalesce(p.descripcion, '<NULL>'), p.modulo, p.activo::text
      ),
      E'\n' order by p.codigo, p.id
    ), ''))
    from public.permisos as p
    where p.codigo not in (
      'usuarios.administrar', 'roles.administrar',
      'permisos.administrar', 'portal.ver_dashboard'
    )
  ) as non_target_permission_catalog_md5,
  (
    select md5(coalesce(string_agg(
      concat_ws(
        '|', rp.rol_id::text, rp.permiso_id::text,
        rp.permitido::text, rp.alcance
      ),
      E'\n' order by rp.rol_id, rp.permiso_id
    ), ''))
    from public.rol_permisos as rp
    join public.permisos as p on p.id = rp.permiso_id
    where p.codigo not in (
      'usuarios.administrar', 'roles.administrar',
      'permisos.administrar', 'portal.ver_dashboard'
    )
  ) as non_target_role_permissions_md5,
  (
    select md5(coalesce(string_agg(
      concat_ws(
        '|', pp.perfil_id::text, pp.permiso_id::text,
        pp.permitido::text, pp.alcance
      ),
      E'\n' order by pp.perfil_id, pp.permiso_id
    ), ''))
    from public.perfil_permisos as pp
  ) as profile_permission_overrides_md5;

-- Privilegios de esquema y tablas. La columna effective considera PUBLIC y
-- membresias; direct_grant distingue la ACL concedida especificamente al rol.
select
  roles.rolname,
  has_schema_privilege(roles.oid, 'public', 'USAGE') as public_schema_usage
from pg_roles as roles
where roles.rolname in ('service_role', 'anon', 'authenticated')
order by roles.rolname;

select
  expected.grantee,
  expected.object_name,
  expected.privilege,
  expected.expected_after_0036,
  has_table_privilege(
    grantee_role.oid,
    table_object.oid,
    expected.privilege
  ) as effective_privilege,
  exists (
    select 1
    from aclexplode(table_object.relacl) as acl
    where acl.grantee = grantee_role.oid
      and upper(acl.privilege_type) = expected.privilege
  ) as direct_grant
from (values
  ('service_role', 'profiles', 'SELECT', true),
  ('service_role', 'profiles', 'INSERT', false),
  ('service_role', 'profiles', 'UPDATE', false),
  ('service_role', 'profiles', 'DELETE', false),
  ('service_role', 'profiles', 'TRUNCATE', false),
  ('service_role', 'profiles', 'REFERENCES', false),
  ('service_role', 'profiles', 'TRIGGER', false),
  ('service_role', 'roles', 'SELECT', true),
  ('service_role', 'roles', 'INSERT', false),
  ('service_role', 'roles', 'UPDATE', false),
  ('service_role', 'roles', 'DELETE', false),
  ('service_role', 'roles', 'TRUNCATE', false),
  ('service_role', 'roles', 'REFERENCES', false),
  ('service_role', 'roles', 'TRIGGER', false),
  ('service_role', 'empleados', 'SELECT', true),
  ('service_role', 'empleados', 'INSERT', true),
  ('service_role', 'empleados', 'UPDATE', true),
  ('service_role', 'empleados', 'DELETE', false),
  ('service_role', 'empleados', 'TRUNCATE', false),
  ('service_role', 'empleados', 'REFERENCES', false),
  ('service_role', 'empleados', 'TRIGGER', false),
  ('service_role', 'perfil_sucursales', 'SELECT', false),
  ('service_role', 'perfil_sucursales', 'INSERT', false),
  ('service_role', 'perfil_sucursales', 'UPDATE', false),
  ('service_role', 'perfil_sucursales', 'DELETE', false),
  ('service_role', 'perfil_sucursales', 'TRUNCATE', false),
  ('service_role', 'perfil_sucursales', 'REFERENCES', false),
  ('service_role', 'perfil_sucursales', 'TRIGGER', false),
  ('service_role', 'perfil_departamentos', 'SELECT', false),
  ('service_role', 'perfil_departamentos', 'INSERT', false),
  ('service_role', 'perfil_departamentos', 'UPDATE', false),
  ('service_role', 'perfil_departamentos', 'DELETE', false),
  ('service_role', 'perfil_departamentos', 'TRUNCATE', false),
  ('service_role', 'perfil_departamentos', 'REFERENCES', false),
  ('service_role', 'perfil_departamentos', 'TRIGGER', false),
  ('anon', 'profiles', 'SELECT', false),
  ('anon', 'roles', 'SELECT', false),
  ('anon', 'empleados', 'SELECT', false),
  ('anon', 'perfil_sucursales', 'INSERT', false),
  ('anon', 'perfil_departamentos', 'INSERT', false),
  ('authenticated', 'profiles', 'SELECT', true),
  ('authenticated', 'roles', 'SELECT', true),
  ('authenticated', 'empleados', 'SELECT', true),
  ('authenticated', 'perfil_sucursales', 'INSERT', false),
  ('authenticated', 'perfil_sucursales', 'UPDATE', false),
  ('authenticated', 'perfil_sucursales', 'DELETE', false),
  ('authenticated', 'perfil_departamentos', 'INSERT', false),
  ('authenticated', 'perfil_departamentos', 'UPDATE', false),
  ('authenticated', 'perfil_departamentos', 'DELETE', false)
) as expected(grantee, object_name, privilege, expected_after_0036)
left join pg_roles as grantee_role on grantee_role.rolname = expected.grantee
left join pg_class as table_object
  on table_object.relnamespace = 'public'::regnamespace
 and table_object.relname = expected.object_name
order by expected.grantee, expected.object_name, expected.privilege;

-- ACL directa completa de los roles de API. Comparar esta huella antes/despues
-- para confirmar que 0035-0036 no concedieron nada nuevo a anon/authenticated.
select
  c.relname as table_name,
  coalesce(grantee.rolname, 'PUBLIC') as grantee,
  acl.privilege_type,
  acl.is_grantable,
  grantor.rolname as grantor
from pg_class as c
join pg_namespace as n on n.oid = c.relnamespace
cross join lateral aclexplode(c.relacl) as acl
left join pg_roles as grantee on grantee.oid = acl.grantee
left join pg_roles as grantor on grantor.oid = acl.grantor
where n.nspname = 'public'
  and c.relname in (
    'profiles', 'roles', 'empleados',
    'perfil_sucursales', 'perfil_departamentos'
  )
  and (acl.grantee = 0 or grantee.rolname in (
    'service_role', 'anon', 'authenticated'
  ))
order by
  c.relname,
  coalesce(grantee.rolname, 'PUBLIC'),
  acl.privilege_type;

select
  roles.role_name,
  tables.object_name,
  privileges.privilege,
  has_table_privilege(
    roles.role_name,
    tables.object_name,
    privileges.privilege
  ) as effective_privilege
from (values ('anon'), ('authenticated')) as roles(role_name)
cross join (values
  ('public.profiles'),
  ('public.roles'),
  ('public.empleados'),
  ('public.perfil_sucursales'),
  ('public.perfil_departamentos')
) as tables(object_name)
cross join (values
  ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
  ('TRUNCATE'), ('REFERENCES'), ('TRIGGER')
) as privileges(privilege)
order by roles.role_name, tables.object_name, privileges.privilege;

-- Dependencia legacy de user-provisioning action=list. No forma parte de los
-- tres grants manuales de staging ni de 0035-0036; si se exige conservar esa accion,
-- companies SELECT debe ser true o la promocion queda en NO-GO.
select
  has_table_privilege('service_role', 'public.companies', 'SELECT')
    as service_role_can_read_companies_for_legacy_list;

-- EXECUTE de todos los contratos usados por las dos Edge. Antes de 0033 pueden
-- faltar las firmas nuevas; despues del lote todas deben existir y coincidir.
select
  expected.signature,
  expected.grantee,
  p.oid is not null as function_exists,
  case
    when p.oid is null then null
    else has_function_privilege(expected.grantee, p.oid, 'EXECUTE')
  end as execute_privilege,
  expected.expected_after_promotion
from (values
  ('public.bootstrap_tenant_internal(jsonb)', 'service_role', true),
  ('public.provision_user_internal(jsonb)', 'service_role', true),
  ('public.crear_acceso_internal(jsonb)', 'service_role', true),
  ('public.actualizar_acceso_autorizacion_internal(jsonb)', 'service_role', true),
  ('public.obtener_acceso_internal(jsonb)', 'service_role', true),
  ('public.cambiar_estado_acceso_internal(jsonb)', 'service_role', true),
  ('public.registrar_operacion_acceso_internal(jsonb)', 'service_role', true),
  ('public.eliminar_acceso_internal(jsonb)', 'service_role', true),
  ('public.listar_accesos_internal(jsonb)', 'service_role', true),
  ('public.guardar_alcance_supervisor_internal(jsonb)', 'service_role', true),
  ('public.obtener_alcance_supervisor_internal(jsonb)', 'service_role', true),
  ('public.crear_acceso_con_alcance_internal(jsonb)', 'service_role', true),
  ('public.obtener_creacion_acceso_idempotente_internal(jsonb)', 'service_role', true),
  ('public.actualizar_acceso_con_alcance_internal(jsonb)', 'service_role', true),
  ('public.obtener_actualizacion_acceso_confirmada_internal(jsonb)', 'service_role', true),
  ('public.cambiar_estado_acceso_con_alcance_internal(jsonb)', 'service_role', true),
  ('public.preview_next_employee_code_internal(uuid)', 'service_role', true),
  ('public.allocate_next_employee_code_internal(uuid,uuid)', 'service_role', true),
  ('public.actualizar_auth_sync_ciclo_empleado_internal(uuid,bigint,text,text[],text)', 'service_role', true),
  ('public.finalizar_reactivacion_acceso_internal(uuid,bigint)', 'service_role', true),
  ('public.tiene_permiso(text)', 'authenticated', true),
  ('public.desvincular_empleado(uuid,date,text,text)', 'authenticated', true),
  ('public.reactivar_empleado(uuid,text)', 'authenticated', true),
  ('public.obtener_departamentos_supervisor_actual()', 'authenticated', true),
  ('public.supervisor_puede_ver_empleado(uuid)', 'authenticated', true),
  ('public.obtener_mi_autorizacion()', 'authenticated', true)
) as expected(signature, grantee, expected_after_promotion)
left join pg_proc as p on p.oid = to_regprocedure(expected.signature)
order by expected.grantee, expected.signature;

-- RLS debe seguir habilitado. 0030-0036 no lo desactiva.
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class as c
join pg_namespace as n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'profiles', 'roles', 'empleados', 'permisos', 'rol_permisos',
    'perfil_permisos', 'perfil_sucursales', 'perfil_departamentos',
    'user_provisioning_audit', 'administracion_auditoria',
    'supervisor_auditoria'
  )
order by c.relname;

-- Inventario y huella de policies; guardar la salida antes y despues.
select
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check,
  md5(
    coalesce(cmd, '') || '|' ||
    coalesce(array_to_string(roles, ','), '') || '|' ||
    coalesce(qual, '') || '|' ||
    coalesce(with_check, '')
  ) as policy_fingerprint
from pg_policies
where schemaname = 'public'
  and tablename in (
    'profiles', 'roles', 'empleados', 'permisos', 'rol_permisos',
    'perfil_permisos', 'perfil_sucursales', 'perfil_departamentos',
    'user_provisioning_audit', 'administracion_auditoria',
    'supervisor_auditoria'
  )
order by tablename, policyname;

-- Inconsistencias multiempresa y de alcance. Cada invalid_rows debe ser 0 para
-- GO, salvo una excepcion explicitamente analizada y aprobada.
select
  'profile_role_company_mismatch' as check_name,
  count(*)::bigint as invalid_rows
from public.profiles as pr
join public.roles as r on r.id = pr.role_id
where r.company_id is distinct from pr.company_id
union all
select
  'profile_branch_company_mismatch',
  count(*)::bigint
from public.profiles as pr
join public.branches as b on b.id = pr.branch_id
where b.company_id is distinct from pr.company_id
union all
select
  'profile_department_company_mismatch',
  count(*)::bigint
from public.profiles as pr
join public.departments as d on d.id = pr.department_id
where d.company_id is distinct from pr.company_id
union all
select
  'department_branch_company_mismatch',
  count(*)::bigint
from public.departments as d
join public.branches as b on b.id = d.branch_id
where b.company_id is distinct from d.company_id
union all
select
  'employee_profile_company_mismatch',
  count(*)::bigint
from public.empleados as e
join public.profiles as pr on pr.id = e.perfil_id
where e.empresa_id is distinct from pr.company_id
union all
select
  'scope_branch_company_mismatch',
  count(*)::bigint
from public.perfil_sucursales as ps
join public.profiles as pr on pr.id = ps.perfil_id
left join public.branches as b
  on b.id = ps.sucursal_id
 and b.company_id = pr.company_id
where b.id is null
union all
select
  'scope_department_company_mismatch',
  count(*)::bigint
from public.perfil_departamentos as pd
join public.profiles as pr on pr.id = pd.perfil_id
left join public.departments as d
  on d.id = pd.departamento_id
 and d.company_id = pr.company_id
where d.id is null
union all
select
  'supervisor_department_without_matching_branch',
  count(*)::bigint
from public.perfil_departamentos as pd
join public.profiles as pr on pr.id = pd.perfil_id
join public.roles as r
  on r.id = pr.role_id
 and r.company_id = pr.company_id
left join public.departments as d
  on d.id = pd.departamento_id
 and d.company_id = pr.company_id
left join public.perfil_sucursales as ps
  on ps.perfil_id = pr.id
 and ps.sucursal_id = d.branch_id
where private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  and (d.id is null or ps.perfil_id is null)
union all
select
  'active_supervisor_without_department',
  count(*)::bigint
from public.profiles as pr
join public.roles as r
  on r.id = pr.role_id
 and r.company_id = pr.company_id
where pr.status = 'active'
  and pr.access_deleted_at is null
  and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  and not exists (
    select 1
    from public.perfil_departamentos as pd
    where pd.perfil_id = pr.id
  )
union all
select
  'active_supervisor_not_exactly_one_branch',
  count(*)::bigint
from public.profiles as pr
join public.roles as r
  on r.id = pr.role_id
 and r.company_id = pr.company_id
where pr.status = 'active'
  and pr.access_deleted_at is null
  and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  and 1 <> (
    select count(distinct ps.sucursal_id)
    from public.perfil_sucursales as ps
    where ps.perfil_id = pr.id
  )
union all
select
  'active_supervisor_inactive_or_unbranched_department',
  count(*)::bigint
from public.perfil_departamentos as pd
join public.profiles as pr on pr.id = pd.perfil_id
join public.roles as r
  on r.id = pr.role_id
 and r.company_id = pr.company_id
left join public.departments as d
  on d.id = pd.departamento_id
 and d.company_id = pr.company_id
left join public.branches as b
  on b.id = d.branch_id
 and b.company_id = pr.company_id
where pr.status = 'active'
  and pr.access_deleted_at is null
  and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  and (
    d.id is null
    or not d.is_active
    or d.branch_id is null
    or b.status is distinct from 'active'
  );

-- Datos legacy que 0033 deja fail-closed o que necesitan decision previa.
select
  'active_canonical_supervisor_roles_missing' as check_name,
  case
    when count(*) = 0 then 1::bigint
    else 0::bigint
  end as blocking_condition
from public.roles
where is_active
  and private.normalizar_codigo_rol(code) = 'SUPERVISOR'
union all
select
  'active_supervisor_profiles_with_legacy_profile_department_only',
  count(*)::bigint
from public.profiles as pr
join public.roles as r
  on r.id = pr.role_id
 and r.company_id = pr.company_id
where pr.status = 'active'
  and pr.access_deleted_at is null
  and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  and pr.department_id is not null
  and not exists (
    select 1
    from public.perfil_departamentos as pd
    where pd.perfil_id = pr.id
  )
union all
select
  'active_supervisor_profiles_with_legacy_profile_branch_only',
  count(*)::bigint
from public.profiles as pr
join public.roles as r
  on r.id = pr.role_id
 and r.company_id = pr.company_id
where pr.status = 'active'
  and pr.access_deleted_at is null
  and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  and pr.branch_id is not null
  and not exists (
    select 1
    from public.perfil_sucursales as ps
    where ps.perfil_id = pr.id
  );

-- Conteos de impacto, sin PII.
select
  '0030_profiles_employee_aliases_newly_canonicalized' as metric,
  count(*)::bigint as affected
from public.profiles as pr
join public.roles as r on r.id = pr.role_id
where upper(trim(r.code)) in ('EMPLEADOS', 'EMPLOYEES')
union all
select
  '0031_active_exact_admin_roles',
  count(*)::bigint
from public.roles
where is_active and upper(code) = 'ADMIN'
union all
select
  '0032_active_exact_admin_supervisor_roles',
  count(*)::bigint
from public.roles
where is_active and upper(code) in ('ADMIN', 'SUPERVISOR')
union all
select
  '0033_canonical_supervisor_profiles',
  count(*)::bigint
from public.profiles as pr
join public.roles as r
  on r.id = pr.role_id
 and r.company_id = pr.company_id
where private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  and pr.access_deleted_at is null
union all
select 'all_profiles', count(*)::bigint from public.profiles
union all
select 'all_employees', count(*)::bigint from public.empleados
union all
select
  'active_unlinked_employee_candidates',
  count(*)::bigint
from public.empleados
where activo and perfil_id is null;

-- Estado final informativo. La decision GO requiere revisar todas las salidas,
-- el dry-run, el target externo, el backup y la preimagen Edge; no puede
-- inferirse de una unica bandera SQL.
select
  'MANUAL_GO_NO_GO_REQUIRED' as result,
  'Revisar target, history, backfill=0, duplicados=0, drift=0, ACL, RLS, policies, catalogo y consistencia multiempresa.'
    as instruction;
