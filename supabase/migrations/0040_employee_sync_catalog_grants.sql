-- Permisos minimos requeridos por employee-sync para resolver
-- nombres de sucursal, departamento y cargo.
-- No altera RLS, policies, ownership ni permisos de usuarios finales.

begin;

-- Partimos de una ACL directa conocida y cerrada.
revoke all privileges on table
  public.branches,
  public.departments,
  public.positions
from service_role;

-- employee-sync solo necesita lectura.
grant select on table
  public.branches,
  public.departments,
  public.positions
to service_role;

-- Validacion fail-closed de la matriz esperada.
do $service_role_employee_sync_catalog_validation$
declare
  v_mismatch text;
begin
  with expected(table_name, privilege_name, expected_value) as (
    values
      ('branches'::text, 'SELECT'::text, true),
      ('branches', 'INSERT', false),
      ('branches', 'UPDATE', false),
      ('branches', 'DELETE', false),
      ('branches', 'TRUNCATE', false),
      ('branches', 'REFERENCES', false),
      ('branches', 'TRIGGER', false),

      ('departments', 'SELECT', true),
      ('departments', 'INSERT', false),
      ('departments', 'UPDATE', false),
      ('departments', 'DELETE', false),
      ('departments', 'TRUNCATE', false),
      ('departments', 'REFERENCES', false),
      ('departments', 'TRIGGER', false),

      ('positions', 'SELECT', true),
      ('positions', 'INSERT', false),
      ('positions', 'UPDATE', false),
      ('positions', 'DELETE', false),
      ('positions', 'TRUNCATE', false),
      ('positions', 'REFERENCES', false),
      ('positions', 'TRIGGER', false)
  ),
  observed as (
    select
      e.table_name,
      e.privilege_name,
      e.expected_value,
      pg_catalog.has_table_privilege(
        'service_role',
        pg_catalog.to_regclass('public.' || e.table_name),
        e.privilege_name
      ) as actual_value,
      pg_catalog.has_table_privilege(
        'service_role',
        pg_catalog.to_regclass('public.' || e.table_name),
        e.privilege_name || ' WITH GRANT OPTION'
      ) as grantable_value
    from expected e
  )
  select pg_catalog.string_agg(
    pg_catalog.format(
      '%I:%s expected=%s actual=%s grantable=%s',
      table_name,
      privilege_name,
      expected_value,
      actual_value,
      grantable_value
    ),
    ', ' order by table_name, privilege_name
  )
  into v_mismatch
  from observed
  where actual_value is distinct from expected_value
     or grantable_value is distinct from false;

  if v_mismatch is not null then
    raise exception using
      errcode = '42501',
      message = 'SERVICE_ROLE_EMPLOYEE_SYNC_CATALOG_MISMATCH',
      detail = v_mismatch;
  end if;
end;
$service_role_employee_sync_catalog_validation$;

commit;