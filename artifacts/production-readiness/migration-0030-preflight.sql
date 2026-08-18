-- Migración 0030: preflight de solo lectura.
-- Ejecutar únicamente en staging y conservar solo resultados agregados.

select
  current_setting('server_version') as server_version,
  current_database() as database_name,
  current_user as execution_role;

select version
from supabase_migrations.schema_migrations
where version in ('0029', '0030')
order by version;

select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_function_result(p.oid) as result_type,
  p.provolatile as volatility,
  p.prosecdef as security_definer,
  p.proconfig as runtime_config
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'private'
  and p.proname = 'normalizar_codigo_rol';

select pg_get_functiondef(p.oid) as current_function_definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'private'
  and p.proname = 'normalizar_codigo_rol'
  and pg_get_function_identity_arguments(p.oid) = 'p_codigo text';

select
  dependent_ns.nspname as dependent_schema,
  dependent_proc.proname as dependent_object,
  pg_get_function_identity_arguments(dependent_proc.oid) as dependent_arguments
from pg_depend d
join pg_proc source_proc on source_proc.oid = d.refobjid
join pg_namespace source_ns on source_ns.oid = source_proc.pronamespace
join pg_proc dependent_proc on dependent_proc.oid = d.objid
join pg_namespace dependent_ns on dependent_ns.oid = dependent_proc.pronamespace
where source_ns.nspname = 'private'
  and source_proc.proname = 'normalizar_codigo_rol'
order by dependent_schema, dependent_object, dependent_arguments;

select
  upper(trim(coalesce(code, ''))) as stored_role_code,
  count(*) as role_count,
  count(*) filter (where is_active) as active_role_count
from public.roles
group by upper(trim(coalesce(code, '')))
order by stored_role_code;

select
  count(*) filter (where code is null or trim(code) = '') as null_or_blank_role_codes,
  count(*) filter (
    where upper(trim(coalesce(code, ''))) in
      ('EMPLEADO', 'EMPLEADOS', 'EMPLOYEE', 'EMPLOYEES')
  ) as employee_family_roles,
  count(*) filter (
    where upper(trim(coalesce(code, ''))) in ('EMPLEADOS', 'EMPLOYEES')
  ) as roles_affected_by_0030
from public.roles;

with normalized_roles as (
  select
    id,
    company_id,
    private.normalizar_codigo_rol(code) as canonical_code
  from public.roles
)
select
  count(*) filter (
    where canonical_code not in
      ('ADMIN', 'SUPERVISOR', 'EMPLEADO', 'RRHH', 'NOMINA', 'AUDITOR')
  ) as unrecognized_role_count,
  count(*) filter (where canonical_code = '') as empty_canonical_role_count
from normalized_roles;

with duplicate_groups as (
  select
    company_id,
    upper(trim(coalesce(code, ''))) as stored_role_code
  from public.roles
  group by company_id, upper(trim(coalesce(code, '')))
  having count(*) > 1
)
select count(*) as duplicate_role_code_groups
from duplicate_groups;

select
  count(*) filter (where company_id is null) as profiles_without_company,
  count(*) filter (where role_id is null) as profiles_without_role,
  count(*) filter (
    where status is distinct from 'active' or access_deleted_at is not null
  ) as inactive_or_deleted_profiles
from public.profiles;

select count(*) as profile_role_company_mismatches
from public.profiles p
join public.roles r on r.id = p.role_id
where r.company_id is distinct from p.company_id;

select count(*) as employee_profile_company_mismatches
from public.empleados e
join public.profiles p on p.id = e.perfil_id
where e.empresa_id is distinct from p.company_id;

select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  p.prosecdef as security_definer,
  p.proconfig as runtime_config
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where (n.nspname, p.proname) in (
  ('public', 'obtener_mi_autorizacion'),
  ('public', 'limpiar_autorizacion_por_cambio_rol'),
  ('public', 'actualizar_acceso_autorizacion_internal')
)
order by schema_name, function_name;

select
  routine_schema,
  routine_name,
  grantee,
  privilege_type
from information_schema.routine_privileges
where routine_schema in ('private', 'public')
  and routine_name in (
    'normalizar_codigo_rol',
    'obtener_mi_autorizacion',
    'limpiar_autorizacion_por_cambio_rol',
    'actualizar_acceso_autorizacion_internal'
  )
order by routine_schema, routine_name, grantee, privilege_type;

select
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd
from pg_policies
where schemaname = 'public'
  and tablename in ('profiles', 'roles', 'empleados')
order by tablename, policyname;
