-- CONTROLHORARIO: canonical employee role aliases.
-- role_code_original remains the value stored in public.roles.code.

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
            U&'\00C1\00C9\00CD\00D3\00DA\00DC\00D1\00E1\00E9\00ED\00F3\00FA\00FC\00F1',
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
    when 'EMPLEADOS' then 'EMPLEADO'
    when 'EMPLOYEE' then 'EMPLEADO'
    when 'EMPLOYEES' then 'EMPLEADO'
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

do $migration_check$
begin
  if exists (
    select 1
    from (
      values ('empleado'), ('empleados'), ('employee'), ('employees')
    ) as alias(codigo)
    where private.normalizar_codigo_rol(alias.codigo) is distinct from 'EMPLEADO'
  ) then
    raise exception 'EMPLOYEE_ROLE_CANONICALIZATION_FAILED';
  end if;
end;
$migration_check$;

commit;
