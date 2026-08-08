-- Postflight de 0035. Este archivo contiene exclusivamente sentencias SELECT.
-- Comparar las ACL y huellas de policies con la salida del precheck archivado.

select exists (
  select 1
  from supabase_migrations.schema_migrations
  where version = '0035'
) as migration_0035_recorded;

select
  expected.object_name,
  expected.privilege,
  expected.expected,
  has_table_privilege(
    'service_role',
    expected.object_name,
    expected.privilege
  ) as observed,
  has_table_privilege(
    'service_role',
    expected.object_name,
    expected.privilege
  ) = expected.expected as matches_expected
from (values
  ('public.profiles', 'SELECT', true),
  ('public.profiles', 'INSERT', false),
  ('public.profiles', 'UPDATE', false),
  ('public.profiles', 'DELETE', false),
  ('public.profiles', 'TRUNCATE', false),
  ('public.profiles', 'REFERENCES', false),
  ('public.profiles', 'TRIGGER', false),
  ('public.roles', 'SELECT', true),
  ('public.roles', 'INSERT', false),
  ('public.roles', 'UPDATE', false),
  ('public.roles', 'DELETE', false),
  ('public.roles', 'TRUNCATE', false),
  ('public.roles', 'REFERENCES', false),
  ('public.roles', 'TRIGGER', false),
  ('public.empleados', 'SELECT', true),
  ('public.empleados', 'INSERT', true),
  ('public.empleados', 'UPDATE', true),
  ('public.empleados', 'DELETE', false),
  ('public.empleados', 'TRUNCATE', false),
  ('public.empleados', 'REFERENCES', false),
  ('public.empleados', 'TRIGGER', false),
  ('public.perfil_sucursales', 'INSERT', false),
  ('public.perfil_sucursales', 'UPDATE', false),
  ('public.perfil_sucursales', 'DELETE', false),
  ('public.perfil_departamentos', 'INSERT', false),
  ('public.perfil_departamentos', 'UPDATE', false),
  ('public.perfil_departamentos', 'DELETE', false)
) as expected(object_name, privilege, expected)
order by expected.object_name, expected.privilege;

-- 0035 no toca anon/authenticated. Esta salida debe coincidir exactamente con
-- la preimagen; una diferencia no puede declararse PASS sin baseline.
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
    'anon', 'authenticated'
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

-- 0035 no debe romper contratos RPC ya versionados.
select
  expected.signature,
  p.oid is not null as function_exists,
  case
    when p.oid is null then null
    else has_function_privilege('service_role', p.oid, 'EXECUTE')
  end as service_role_execute
from (values
  ('public.bootstrap_tenant_internal(jsonb)'),
  ('public.provision_user_internal(jsonb)'),
  ('public.crear_acceso_internal(jsonb)'),
  ('public.actualizar_acceso_autorizacion_internal(jsonb)'),
  ('public.obtener_acceso_internal(jsonb)'),
  ('public.cambiar_estado_acceso_internal(jsonb)'),
  ('public.registrar_operacion_acceso_internal(jsonb)'),
  ('public.eliminar_acceso_internal(jsonb)'),
  ('public.listar_accesos_internal(jsonb)'),
  ('public.guardar_alcance_supervisor_internal(jsonb)'),
  ('public.obtener_alcance_supervisor_internal(jsonb)'),
  ('public.crear_acceso_con_alcance_internal(jsonb)'),
  ('public.obtener_creacion_acceso_idempotente_internal(jsonb)'),
  ('public.actualizar_acceso_con_alcance_internal(jsonb)'),
  ('public.obtener_actualizacion_acceso_confirmada_internal(jsonb)'),
  ('public.cambiar_estado_acceso_con_alcance_internal(jsonb)'),
  ('public.preview_next_employee_code_internal(uuid)'),
  ('public.allocate_next_employee_code_internal(uuid,uuid)'),
  ('public.actualizar_auth_sync_ciclo_empleado_internal(uuid,bigint,text,text[],text)'),
  ('public.finalizar_reactivacion_acceso_internal(uuid,bigint)')
) as expected(signature)
left join pg_proc as p on p.oid = to_regprocedure(expected.signature)
order by expected.signature;

select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as rls_forced
from pg_class as c
join pg_namespace as n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in (
    'profiles', 'roles', 'empleados',
    'perfil_sucursales', 'perfil_departamentos'
  )
order by c.relname;

select
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  md5(
    coalesce(cmd, '') || '|' ||
    coalesce(array_to_string(roles, ','), '') || '|' ||
    coalesce(qual, '') || '|' ||
    coalesce(with_check, '')
  ) as policy_fingerprint
from pg_policies
where schemaname = 'public'
  and tablename in (
    'profiles', 'roles', 'empleados',
    'perfil_sucursales', 'perfil_departamentos'
  )
order by tablename, policyname;
