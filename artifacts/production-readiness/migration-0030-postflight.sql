-- Migración 0030: postflight de solo lectura.
-- Ejecutar únicamente en staging y conservar solo resultados agregados.

select
  current_setting('server_version') as server_version,
  current_database() as database_name,
  current_user as execution_role;

select
  version,
  version = '0030' as migration_0030_recorded
from supabase_migrations.schema_migrations
where version = '0030';

select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as identity_arguments,
  pg_get_function_result(p.oid) as result_type,
  l.lanname as language_name,
  p.provolatile = 'i' as is_immutable,
  p.prosecdef as security_definer,
  p.proconfig as runtime_config
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
join pg_language l on l.oid = p.prolang
where n.nspname = 'private'
  and p.proname = 'normalizar_codigo_rol'
  and pg_get_function_identity_arguments(p.oid) = 'p_codigo text';

select pg_get_functiondef(p.oid) as installed_function_definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'private'
  and p.proname = 'normalizar_codigo_rol'
  and pg_get_function_identity_arguments(p.oid) = 'p_codigo text';

with expected(input_code, expected_code) as (
  values
    ('empleado', 'EMPLEADO'),
    ('empleados', 'EMPLEADO'),
    ('employee', 'EMPLEADO'),
    ('employees', 'EMPLEADO'),
    ('administrador', 'ADMIN'),
    ('supervisor', 'SUPERVISOR'),
    ('recursos humanos', 'RRHH'),
    ('nómina', 'NOMINA'),
    ('auditoría', 'AUDITOR')
)
select
  input_code,
  expected_code,
  private.normalizar_codigo_rol(input_code) as actual_code,
  private.normalizar_codigo_rol(input_code) = expected_code as matches
from expected
order by input_code;

select
  private.normalizar_codigo_rol(null) = '' as null_is_empty,
  private.normalizar_codigo_rol(' EMPLEADOS ') = 'EMPLEADO' as spaces_are_normalized,
  private.normalizar_codigo_rol('employEEs') = 'EMPLEADO' as case_is_normalized;

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
  count(*) filter (where canonical_code = '') as empty_canonical_role_count,
  count(*) filter (where canonical_code = 'EMPLEADO') as canonical_employee_role_count
from normalized_roles;

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
  pg_get_function_result(p.oid) as result_type,
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
