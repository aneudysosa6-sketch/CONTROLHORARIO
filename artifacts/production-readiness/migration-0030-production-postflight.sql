-- Postflight de produccion para 0030. Solo sentencias SELECT.

select exists (
  select 1
  from supabase_migrations.schema_migrations
  where version = '0030'
) as migration_0030_recorded;

select
  p.oid is not null as function_exists,
  pg_get_function_result(p.oid) as result_type,
  p.provolatile = 'i' as is_immutable,
  not p.prosecdef as is_security_invoker,
  p.proconfig as runtime_config,
  pg_get_userbyid(p.proowner) as owner,
  md5(pg_get_functiondef(p.oid)) as definition_md5
from pg_proc as p
where p.oid = to_regprocedure('private.normalizar_codigo_rol(text)');

select
  samples.input_code,
  samples.expected_result,
  private.normalizar_codigo_rol(samples.input_code) as observed_result,
  private.normalizar_codigo_rol(samples.input_code) = samples.expected_result
    as matches_expected
from (values
  ('EMPLEADO', 'EMPLEADO'),
  ('EMPLEADOS', 'EMPLEADO'),
  ('EMPLOYEES', 'EMPLEADO'),
  ('SUPERVISOR', 'SUPERVISOR'),
  ('ADMIN', 'ADMIN')
) as samples(input_code, expected_result)
order by samples.input_code;
