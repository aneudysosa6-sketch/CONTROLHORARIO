-- Postflight de 0033. Este archivo contiene exclusivamente sentencias SELECT.
-- Ejecutar solo después de aplicar la migración en el entorno autorizado.

select
  '0033_required_functions' as check_name,
  count(*) filter (where pg_catalog.to_regprocedure(required.signature) is not null) as present_count,
  count(*) as expected_count,
  coalesce(
    array_agg(required.signature order by required.signature)
      filter (where pg_catalog.to_regprocedure(required.signature) is null),
    array[]::text[]
  ) as missing_functions,
  bool_and(pg_catalog.to_regprocedure(required.signature) is not null) as passed
from (values
  ('public.obtener_empresa_actor_activo_internal(uuid)'),
  ('public.alcance_supervisor_valido_internal(uuid,uuid)'),
  ('public.guardar_alcance_supervisor_internal(jsonb)'),
  ('public.obtener_alcance_supervisor_internal(jsonb)'),
  ('public.listar_accesos_internal(jsonb)'),
  ('public.validar_alcance_supervisor()'),
  ('public.proteger_sucursal_asignada_supervisor()'),
  ('public.validar_cambio_sucursal_supervisor()'),
  ('public.obtener_departamentos_supervisor_actual()'),
  ('public.supervisor_puede_ver_empleado(uuid)'),
  ('public.obtener_mi_autorizacion()'),
  ('public.guardar_departamento_administracion(uuid,jsonb,uuid,text)'),
  ('public.crear_acceso_con_alcance_internal(jsonb)'),
  ('public.obtener_creacion_acceso_idempotente_internal(jsonb)'),
  ('public.actualizar_acceso_con_alcance_internal(jsonb)'),
  ('public.obtener_actualizacion_acceso_confirmada_internal(jsonb)'),
  ('public.cambiar_estado_acceso_con_alcance_internal(jsonb)')
) as required(signature);

select
  required.signature,
  p.prosecdef as security_definer,
  coalesce(pg_catalog.array_to_string(p.proconfig, ','), '') as function_config,
  coalesce(pg_catalog.array_to_string(p.proconfig, ','), '') like '%search_path=%' as fixed_search_path
from (values
  ('public.obtener_empresa_actor_activo_internal(uuid)'),
  ('public.alcance_supervisor_valido_internal(uuid,uuid)'),
  ('public.guardar_alcance_supervisor_internal(jsonb)'),
  ('public.obtener_alcance_supervisor_internal(jsonb)'),
  ('public.crear_acceso_con_alcance_internal(jsonb)'),
  ('public.obtener_creacion_acceso_idempotente_internal(jsonb)'),
  ('public.actualizar_acceso_con_alcance_internal(jsonb)'),
  ('public.obtener_actualizacion_acceso_confirmada_internal(jsonb)'),
  ('public.cambiar_estado_acceso_con_alcance_internal(jsonb)'),
  ('public.obtener_departamentos_supervisor_actual()'),
  ('public.supervisor_puede_ver_empleado(uuid)'),
  ('public.obtener_mi_autorizacion()')
) as required(signature)
left join pg_catalog.pg_proc p
  on p.oid = pg_catalog.to_regprocedure(required.signature)
order by required.signature;

select
  required.signature,
  pg_catalog.has_function_privilege('service_role', required.signature, 'EXECUTE') as service_role_execute,
  pg_catalog.has_function_privilege('anon', required.signature, 'EXECUTE') as anon_execute,
  pg_catalog.has_function_privilege('authenticated', required.signature, 'EXECUTE') as authenticated_execute,
  pg_catalog.has_function_privilege('service_role', required.signature, 'EXECUTE')
    and not pg_catalog.has_function_privilege('anon', required.signature, 'EXECUTE')
    and not pg_catalog.has_function_privilege('authenticated', required.signature, 'EXECUTE') as passed
from (values
  ('public.guardar_alcance_supervisor_internal(jsonb)'),
  ('public.obtener_alcance_supervisor_internal(jsonb)'),
  ('public.listar_accesos_internal(jsonb)'),
  ('public.crear_acceso_con_alcance_internal(jsonb)'),
  ('public.obtener_creacion_acceso_idempotente_internal(jsonb)'),
  ('public.actualizar_acceso_con_alcance_internal(jsonb)'),
  ('public.obtener_actualizacion_acceso_confirmada_internal(jsonb)'),
  ('public.cambiar_estado_acceso_con_alcance_internal(jsonb)')
) as required(signature)
order by required.signature;

select
  required.signature,
  pg_catalog.has_function_privilege('authenticated', required.signature, 'EXECUTE') as authenticated_execute,
  not pg_catalog.has_function_privilege('anon', required.signature, 'EXECUTE') as anon_denied,
  pg_catalog.has_function_privilege('authenticated', required.signature, 'EXECUTE')
    and not pg_catalog.has_function_privilege('anon', required.signature, 'EXECUTE') as passed
from (values
  ('public.obtener_departamentos_supervisor_actual()'),
  ('public.supervisor_puede_ver_empleado(uuid)'),
  ('public.obtener_mi_autorizacion()')
) as required(signature)
order by required.signature;

select
  required.table_name,
  required.privilege,
  pg_catalog.has_table_privilege('service_role', 'public.' || required.table_name, required.privilege) as service_role_has_privilege
from (values
  ('profiles', 'SELECT'),
  ('empleados', 'SELECT'),
  ('roles', 'SELECT')
) as required(table_name, privilege)
order by required.table_name;

select
  i.relname as index_name,
  x.indisunique as is_unique,
  pg_catalog.pg_get_indexdef(x.indexrelid) as definition,
  pg_catalog.pg_get_expr(x.indpred, x.indrelid) as predicate,
  x.indisunique
    and pg_catalog.pg_get_expr(x.indpred, x.indrelid) is not null as passed
from pg_catalog.pg_index x
join pg_catalog.pg_class i on i.oid = x.indexrelid
join pg_catalog.pg_namespace n on n.oid = i.relnamespace
where n.nspname = 'public'
  and i.relname in (
    'user_provisioning_audit_create_idempotency_idx',
    'administracion_auditoria_access_operation_idx'
  )
order by i.relname;

select
  required.table_name,
  pg_catalog.has_table_privilege('authenticated', 'public.' || required.table_name, 'SELECT') as authenticated_select,
  pg_catalog.has_table_privilege('authenticated', 'public.' || required.table_name, 'INSERT') as authenticated_insert,
  pg_catalog.has_table_privilege('authenticated', 'public.' || required.table_name, 'UPDATE') as authenticated_update,
  pg_catalog.has_table_privilege('authenticated', 'public.' || required.table_name, 'DELETE') as authenticated_delete,
  pg_catalog.has_table_privilege('anon', 'public.' || required.table_name, 'INSERT') as anon_insert,
  pg_catalog.has_table_privilege('anon', 'public.' || required.table_name, 'UPDATE') as anon_update,
  pg_catalog.has_table_privilege('anon', 'public.' || required.table_name, 'DELETE') as anon_delete,
  pg_catalog.has_table_privilege('authenticated', 'public.' || required.table_name, 'SELECT')
    and not pg_catalog.has_table_privilege('authenticated', 'public.' || required.table_name, 'INSERT')
    and not pg_catalog.has_table_privilege('authenticated', 'public.' || required.table_name, 'UPDATE')
    and not pg_catalog.has_table_privilege('authenticated', 'public.' || required.table_name, 'DELETE')
    and not pg_catalog.has_table_privilege('anon', 'public.' || required.table_name, 'INSERT')
    and not pg_catalog.has_table_privilege('anon', 'public.' || required.table_name, 'UPDATE')
    and not pg_catalog.has_table_privilege('anon', 'public.' || required.table_name, 'DELETE') as passed
from (values
  ('perfil_sucursales'),
  ('perfil_departamentos')
) as required(table_name)
order by required.table_name;

select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('perfil_sucursales', 'perfil_departamentos')
order by c.relname;

select
  p.tablename,
  p.policyname,
  p.cmd,
  p.roles,
  p.qual,
  p.with_check,
  md5(
    coalesce(p.cmd, '') || '|' ||
    coalesce(pg_catalog.array_to_string(p.roles, ','), '') || '|' ||
    coalesce(p.qual, '') || '|' ||
    coalesce(p.with_check, '')
  ) as definition_fingerprint
from pg_catalog.pg_policies p
where p.schemaname = 'public'
  and p.tablename in ('perfil_sucursales', 'perfil_departamentos')
order by p.tablename, p.policyname;

select
  required.table_name,
  required.policy_name,
  p.policyname is not null as present
from (values
  ('perfil_sucursales', 'perfil_sucursales_select'),
  ('perfil_sucursales', 'perfil_sucursales_manage'),
  ('perfil_departamentos', 'perfil_departamentos_select'),
  ('perfil_departamentos', 'perfil_departamentos_manage')
) as required(table_name, policy_name)
left join pg_catalog.pg_policies p
  on p.schemaname = 'public'
 and p.tablename = required.table_name
 and p.policyname = required.policy_name
order by required.table_name, required.policy_name;

select
  required.table_name,
  required.trigger_name,
  t.tgenabled,
  t.oid is not null and t.tgenabled <> 'D' as enabled
from (values
  ('perfil_sucursales', 'perfil_sucursales_validate_rc3'),
  ('perfil_departamentos', 'perfil_departamentos_validate_rc3'),
  ('perfil_sucursales', 'perfil_sucursales_protect_rc3'),
  ('profiles', 'profiles_validate_supervisor_branch_rc3'),
  ('perfil_sucursales', 'perfil_sucursales_audit_rc3'),
  ('perfil_departamentos', 'perfil_departamentos_audit_rc3')
) as required(table_name, trigger_name)
left join pg_catalog.pg_class c
  on c.relname = required.table_name
 and c.relnamespace = 'public'::regnamespace
left join pg_catalog.pg_trigger t
  on t.tgrelid = c.oid
 and t.tgname = required.trigger_name
 and not t.tgisinternal
order by required.table_name, required.trigger_name;

select
  pr.company_id,
  pr.id as profile_id,
  pr.status as profile_status,
  r.code as role_code_original,
  private.normalizar_codigo_rol(r.code) as role_code_canonical,
  (select count(distinct ps.sucursal_id) from public.perfil_sucursales ps where ps.perfil_id = pr.id) as branch_count,
  (select count(*) from public.perfil_departamentos pd where pd.perfil_id = pr.id) as department_count,
  public.alcance_supervisor_valido_internal(pr.id, pr.company_id) as scope_structure_valid,
  pr.status = 'active'
    and public.alcance_supervisor_valido_internal(pr.id, pr.company_id) as effective_scope_valid,
  case
    when pr.status <> 'active' then 'PERFIL_INACTIVO_SIN_ALCANCE_EFECTIVO'
    when public.alcance_supervisor_valido_internal(pr.id, pr.company_id) then 'VALIDO'
    else 'REQUIERE_CONCILIACION_FAIL_CLOSED'
  end as scope_status
from public.profiles pr
join public.roles r
  on r.id = pr.role_id
 and r.company_id = pr.company_id
where private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  and pr.access_deleted_at is null
order by pr.company_id, pr.id;

select
  checks.check_name,
  checks.invalid_rows,
  checks.invalid_rows = 0 as passed
from (
  select
    'branch_assignment_cross_company'::text as check_name,
    count(*)::bigint as invalid_rows
  from public.perfil_sucursales ps
  join public.profiles pr on pr.id = ps.perfil_id
  left join public.branches b
    on b.id = ps.sucursal_id
   and b.company_id = pr.company_id
  where b.id is null
  union all
  select
    'department_assignment_cross_company'::text,
    count(*)::bigint
  from public.perfil_departamentos pd
  join public.profiles pr on pr.id = pd.perfil_id
  left join public.departments d
    on d.id = pd.departamento_id
   and d.company_id = pr.company_id
  where d.id is null
  union all
  select
    'supervisor_department_without_matching_branch'::text,
    count(*)::bigint
  from public.perfil_departamentos pd
  join public.profiles pr on pr.id = pd.perfil_id
  join public.roles r
    on r.id = pr.role_id
   and r.company_id = pr.company_id
  left join public.departments d
    on d.id = pd.departamento_id
   and d.company_id = pr.company_id
  left join public.perfil_sucursales ps
    on ps.perfil_id = pr.id
   and ps.sucursal_id = d.branch_id
  where private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
    and (d.id is null or ps.perfil_id is null)
) as checks
order by checks.check_name;

select
  pr.company_id,
  pr.id as profile_id,
  pr.status,
  array(
    select distinct ps.sucursal_id
    from public.perfil_sucursales ps
    where ps.perfil_id = pr.id
    order by ps.sucursal_id
  ) as branch_ids,
  array(
    select pd.departamento_id
    from public.perfil_departamentos pd
    where pd.perfil_id = pr.id
    order by pd.departamento_id
  ) as department_ids,
  'FAIL_CLOSED_HASTA_CONCILIACION' as expected_runtime_state
from public.profiles pr
join public.roles r
  on r.id = pr.role_id
 and r.company_id = pr.company_id
where private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
  and pr.access_deleted_at is null
  and not public.alcance_supervisor_valido_internal(pr.id, pr.company_id)
order by pr.company_id, pr.id;

select
  'explicit_scope_resolver' as check_name,
  pg_catalog.pg_get_functiondef('public.obtener_departamentos_supervisor_actual()'::regprocedure)
    like '%perfil_departamentos%' as uses_profile_departments,
  pg_catalog.pg_get_functiondef('public.obtener_departamentos_supervisor_actual()'::regprocedure)
    like '%perfil_sucursales%' as uses_profile_branches,
  pg_catalog.pg_get_functiondef('public.obtener_departamentos_supervisor_actual()'::regprocedure)
    like '%alcance_supervisor_valido_internal%' as validates_complete_scope,
  pg_catalog.pg_get_functiondef('public.obtener_mi_autorizacion()'::regprocedure)
    like '%explicit_supervisor_assignments%' as exposes_explicit_source,
  pg_catalog.pg_get_functiondef('public.guardar_alcance_supervisor_internal(jsonb)'::regprocedure)
    like '%SUPERVISOR_PROFILE_INACTIVE%' as inactive_profile_write_rejected,
  pg_catalog.pg_get_functiondef('public.validar_alcance_supervisor()'::regprocedure)
    like '%status <> ''active''%' as inactive_profile_trigger_rejected;

select
  'legacy_department_writer_neutralized' as check_name,
  pg_catalog.pg_get_functiondef(
    'public.guardar_departamento_administracion(uuid,jsonb,uuid,text)'::regprocedure
  ) like '%SUPERVISOR_SCOPE_MANAGED_IN_ACCESS%' as passed;

select
  a.company_id,
  a.actor_user_id,
  a.details ->> 'idempotency_key' as idempotency_key,
  count(*) as occurrences,
  count(*) = 1 as unique_key
from public.user_provisioning_audit a
where a.action = 'create_user'
  and a.details ? 'idempotency_key'
group by a.company_id, a.actor_user_id, a.details ->> 'idempotency_key'
having count(*) > 1
order by a.company_id, a.actor_user_id, a.details ->> 'idempotency_key';

select
  'permisos' as object_name,
  count(*) as row_count,
  md5(coalesce(string_agg(
    p.id::text || '|' || p.codigo || '|' || p.activo::text || '|' || p.modulo,
    E'\n' order by p.id
  ), '')) as postflight_fingerprint
from public.permisos p
union all
select
  'rol_permisos',
  count(*),
  md5(coalesce(string_agg(
    rp.rol_id::text || '|' || rp.permiso_id::text || '|' || rp.permitido::text || '|' || coalesce(rp.alcance, ''),
    E'\n' order by rp.rol_id, rp.permiso_id
  ), ''))
from public.rol_permisos rp;
