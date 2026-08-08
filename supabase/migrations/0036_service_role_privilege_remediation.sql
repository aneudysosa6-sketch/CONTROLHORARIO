-- Remediate table privileges stored directly for service_role.
-- This migration intentionally does not alter RLS, policies, ownership,
-- role memberships, default privileges, function EXECUTE, or schema USAGE.

begin;

-- REVOKE ALL is deliberate here: it narrows access rather than widening it. On
-- PostgreSQL 17+ it also removes MAINTAIN without making this file fail to
-- parse on older PostgreSQL versions.
revoke all privileges on table
  public.profiles,
  public.roles,
  public.empleados,
  public.perfil_sucursales,
  public.perfil_departamentos
from service_role;

grant select on table
  public.profiles,
  public.roles
to service_role;

grant select, insert, update on table
  public.empleados
to service_role;

-- Fail closed unless both the effective privileges and the ACL entries stored
-- directly for service_role match the required matrix. A NULL ACL produces no
-- rows in aclexplode(); acldefault() must not be used here because it would
-- synthesize owner privileges and misclassify them as direct grants.
do $service_role_privilege_validation$
declare
  v_service_role oid;
  v_privileges text[] := array[
    'SELECT',
    'INSERT',
    'UPDATE',
    'DELETE',
    'TRUNCATE',
    'REFERENCES',
    'TRIGGER'
  ];
  v_mismatches text;
  v_unexpected_direct_acl text;
  v_unexpected_direct_column_acl text;
begin
  select r.oid
  into v_service_role
  from pg_catalog.pg_roles r
  where r.rolname = 'service_role';

  if v_service_role is null then
    raise exception using
      errcode = '42704',
      message = 'SERVICE_ROLE_NOT_FOUND';
  end if;

  if pg_catalog.current_setting('server_version_num')::integer >= 170000 then
    v_privileges := pg_catalog.array_append(v_privileges, 'MAINTAIN');
  end if;

  with target_tables(table_name, relation_oid) as (
    values
      ('profiles'::text, pg_catalog.to_regclass('public.profiles')),
      ('roles', pg_catalog.to_regclass('public.roles')),
      ('empleados', pg_catalog.to_regclass('public.empleados')),
      ('perfil_sucursales', pg_catalog.to_regclass('public.perfil_sucursales')),
      ('perfil_departamentos', pg_catalog.to_regclass('public.perfil_departamentos'))
  ),
  expected as (
    select
      t.table_name,
      t.relation_oid,
      p.privilege_name,
      case
        when t.table_name in ('profiles', 'roles')
          and p.privilege_name = 'SELECT'
          then true
        when t.table_name = 'empleados'
          and p.privilege_name in ('SELECT', 'INSERT', 'UPDATE')
          then true
        else false
      end as expected_value
    from target_tables t
    cross join pg_catalog.unnest(v_privileges) p(privilege_name)
  ),
  observed as (
    select
      e.table_name,
      e.relation_oid,
      e.privilege_name,
      e.expected_value,
      case
        when e.relation_oid is null then null
        else pg_catalog.has_table_privilege(
          v_service_role,
          e.relation_oid,
          e.privilege_name
        )
      end as effective_value,
      case
        when e.relation_oid is null then null
        else pg_catalog.has_table_privilege(
          v_service_role,
          e.relation_oid,
          e.privilege_name || ' WITH GRANT OPTION'
        )
      end as effective_grantable,
      case
        when e.relation_oid is null then null
        else exists (
          select 1
          from pg_catalog.pg_class c
          cross join lateral pg_catalog.aclexplode(c.relacl) a
          where c.oid = e.relation_oid
            and a.grantee = v_service_role
            and pg_catalog.upper(a.privilege_type) = e.privilege_name
        )
      end as direct_value,
      case
        when e.relation_oid is null then null
        else exists (
          select 1
          from pg_catalog.pg_class c
          cross join lateral pg_catalog.aclexplode(c.relacl) a
          where c.oid = e.relation_oid
            and a.grantee = v_service_role
            and pg_catalog.upper(a.privilege_type) = e.privilege_name
            and a.is_grantable
        )
      end as direct_grantable,
      case
        when e.relation_oid is null then null
        when e.privilege_name in ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
          then pg_catalog.has_any_column_privilege(
            v_service_role,
            e.relation_oid,
            e.privilege_name
          )
        else null
      end as any_column_effective,
      case
        when e.relation_oid is null then null
        when e.privilege_name in ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
          then pg_catalog.has_any_column_privilege(
            v_service_role,
            e.relation_oid,
            e.privilege_name || ' WITH GRANT OPTION'
          )
        else null
      end as any_column_grantable_effective
    from expected e
  )
  select pg_catalog.string_agg(
    pg_catalog.format(
      '%I:%s expected=%s effective=%s effective_grantable=%s direct=%s direct_grantable=%s any_column=%s any_column_grantable=%s',
      o.table_name,
      o.privilege_name,
      o.expected_value,
      coalesce(o.effective_value::text, 'NULL'),
      coalesce(o.effective_grantable::text, 'NULL'),
      coalesce(o.direct_value::text, 'NULL'),
      coalesce(o.direct_grantable::text, 'NULL'),
      coalesce(o.any_column_effective::text, 'N/A'),
      coalesce(o.any_column_grantable_effective::text, 'N/A')
    ),
    ', ' order by o.table_name, o.privilege_name
  )
  into v_mismatches
  from observed o
  where o.relation_oid is null
     or o.effective_value is distinct from o.expected_value
     or o.effective_grantable is distinct from false
     or o.direct_value is distinct from o.expected_value
     or o.direct_grantable is distinct from false
     or (
       o.privilege_name in ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
       and o.any_column_effective is distinct from o.expected_value
     )
     or (
       o.privilege_name in ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
       and o.any_column_grantable_effective is distinct from false
     );

  if v_mismatches is not null then
    raise exception using
      errcode = '42501',
      message = 'SERVICE_ROLE_PRIVILEGE_REMEDIATION_MISMATCH',
      detail = v_mismatches;
  end if;

  -- Reject any direct table privilege type outside the explicit allow-list.
  -- This also guarantees that the two scope tables have no direct table ACL.
  with target_tables(table_name, relation_oid) as (
    values
      ('profiles'::text, pg_catalog.to_regclass('public.profiles')),
      ('roles', pg_catalog.to_regclass('public.roles')),
      ('empleados', pg_catalog.to_regclass('public.empleados')),
      ('perfil_sucursales', pg_catalog.to_regclass('public.perfil_sucursales')),
      ('perfil_departamentos', pg_catalog.to_regclass('public.perfil_departamentos'))
  )
  select pg_catalog.string_agg(
    pg_catalog.format(
      '%I:%s grantable=%s',
      t.table_name,
      pg_catalog.upper(a.privilege_type),
      a.is_grantable
    ),
    ', ' order by t.table_name, a.privilege_type
  )
  into v_unexpected_direct_acl
  from target_tables t
  join pg_catalog.pg_class c on c.oid = t.relation_oid
  cross join lateral pg_catalog.aclexplode(c.relacl) a
  where a.grantee = v_service_role
    and not (
      not a.is_grantable
      and (
        (t.table_name in ('profiles', 'roles')
          and pg_catalog.upper(a.privilege_type) = 'SELECT')
        or
        (t.table_name = 'empleados'
          and pg_catalog.upper(a.privilege_type) in ('SELECT', 'INSERT', 'UPDATE'))
      )
    );

  if v_unexpected_direct_acl is not null then
    raise exception using
      errcode = '42501',
      message = 'SERVICE_ROLE_UNEXPECTED_DIRECT_ACL',
      detail = v_unexpected_direct_acl;
  end if;

  -- Table-level REVOKE also removes corresponding column grants issued by the
  -- same grantor. Fail if a direct column ACL from another route remains.
  with target_tables(table_name, relation_oid) as (
    values
      ('profiles'::text, pg_catalog.to_regclass('public.profiles')),
      ('roles', pg_catalog.to_regclass('public.roles')),
      ('empleados', pg_catalog.to_regclass('public.empleados')),
      ('perfil_sucursales', pg_catalog.to_regclass('public.perfil_sucursales')),
      ('perfil_departamentos', pg_catalog.to_regclass('public.perfil_departamentos'))
  )
  select pg_catalog.string_agg(
    pg_catalog.format(
      '%I.%I:%s grantable=%s',
      t.table_name,
      attribute.attname,
      pg_catalog.upper(column_acl.privilege_type),
      column_acl.is_grantable
    ),
    ', ' order by t.table_name, attribute.attnum, column_acl.privilege_type
  )
  into v_unexpected_direct_column_acl
  from target_tables t
  join pg_catalog.pg_attribute attribute
    on attribute.attrelid = t.relation_oid
   and attribute.attnum > 0
   and not attribute.attisdropped
  cross join lateral pg_catalog.aclexplode(attribute.attacl) column_acl
  where column_acl.grantee = v_service_role;

  if v_unexpected_direct_column_acl is not null then
    raise exception using
      errcode = '42501',
      message = 'SERVICE_ROLE_UNEXPECTED_DIRECT_COLUMN_ACL',
      detail = v_unexpected_direct_column_acl;
  end if;
end;
$service_role_privilege_validation$;

-- 0033 is the required replacement for direct scope-table DML. Guard that its
-- complete Edge Function contract is still present and SECURITY DEFINER, and
-- that its scope writer's owner can perform every table operation it contains.
do $service_role_rpc_validation$
declare
  v_service_role oid;
  v_rpc_mismatches text;
  v_writer_oid oid;
  v_writer_owner oid;
  v_owner_mismatches text;
begin
  select r.oid
  into v_service_role
  from pg_catalog.pg_roles r
  where r.rolname = 'service_role';

  with required_rpc(signature) as (
    values
      ('public.guardar_alcance_supervisor_internal(jsonb)'::text),
      ('public.obtener_alcance_supervisor_internal(jsonb)'),
      ('public.listar_accesos_internal(jsonb)'),
      ('public.crear_acceso_con_alcance_internal(jsonb)'),
      ('public.obtener_creacion_acceso_idempotente_internal(jsonb)'),
      ('public.actualizar_acceso_con_alcance_internal(jsonb)'),
      ('public.obtener_actualizacion_acceso_confirmada_internal(jsonb)'),
      ('public.cambiar_estado_acceso_con_alcance_internal(jsonb)')
  ),
  observed as (
    select
      r.signature,
      p.oid as function_oid,
      p.prosecdef as security_definer,
      case
        when p.oid is null then null
        else pg_catalog.has_function_privilege(
          v_service_role,
          p.oid,
          'EXECUTE'
        )
      end as service_role_can_execute,
      case
        when p.oid is null then null
        else exists (
          select 1
          from pg_catalog.aclexplode(p.proacl) a
          where a.grantee = v_service_role
            and pg_catalog.upper(a.privilege_type) = 'EXECUTE'
        )
      end as service_role_execute_direct
    from required_rpc r
    left join pg_catalog.pg_proc p
      on p.oid = pg_catalog.to_regprocedure(r.signature)
  )
  select pg_catalog.string_agg(
    pg_catalog.format(
      '%s exists=%s security_definer=%s execute=%s direct_execute=%s',
      o.signature,
      (o.function_oid is not null),
      coalesce(o.security_definer::text, 'NULL'),
      coalesce(o.service_role_can_execute::text, 'NULL'),
      coalesce(o.service_role_execute_direct::text, 'NULL')
    ),
    ', ' order by o.signature
  )
  into v_rpc_mismatches
  from observed o
  where o.function_oid is null
     or o.security_definer is distinct from true
     or o.service_role_can_execute is distinct from true
     or o.service_role_execute_direct is distinct from true;

  if v_rpc_mismatches is not null then
    raise exception using
      errcode = '42501',
      message = 'SERVICE_ROLE_RPC_CONTRACT_MISMATCH',
      detail = v_rpc_mismatches;
  end if;

  v_writer_oid := pg_catalog.to_regprocedure(
    'public.guardar_alcance_supervisor_internal(jsonb)'
  );

  select p.proowner
  into v_writer_owner
  from pg_catalog.pg_proc p
  where p.oid = v_writer_oid;

  with required_owner_privilege(table_name, privilege_name) as (
    values
      ('profiles'::text, 'SELECT'::text),
      ('profiles', 'UPDATE'),
      ('roles', 'SELECT'),
      ('branches', 'SELECT'),
      ('departments', 'SELECT'),
      ('perfil_sucursales', 'SELECT'),
      ('perfil_sucursales', 'INSERT'),
      ('perfil_sucursales', 'DELETE'),
      ('perfil_departamentos', 'SELECT'),
      ('perfil_departamentos', 'INSERT'),
      ('perfil_departamentos', 'DELETE'),
      ('administracion_auditoria', 'INSERT')
  ),
  observed as (
    select
      r.table_name,
      r.privilege_name,
      n.oid as schema_oid,
      c.oid as relation_oid,
      c.relowner,
      c.relrowsecurity,
      c.relforcerowsecurity,
      r.table_name = 'administracion_auditoria'
        and r.privilege_name = 'INSERT'
        as requires_identity_sequence,
      case
        when r.table_name = 'administracion_auditoria'
          and r.privilege_name = 'INSERT'
          then pg_catalog.to_regclass(
            pg_catalog.pg_get_serial_sequence(
              'public.administracion_auditoria',
              'id'
            )
          )
        else null
      end as identity_sequence_oid
    from required_owner_privilege r
    left join pg_catalog.pg_namespace n
      on n.nspname = 'public'
    left join pg_catalog.pg_class c
      on c.relnamespace = n.oid
     and c.relname = r.table_name
     and c.relkind in ('r', 'p')
  ),
  checked as (
    select
      o.table_name,
      o.privilege_name,
      o.schema_oid,
      o.relation_oid,
      case
        when v_writer_owner is null or o.relation_oid is null then null
        else pg_catalog.has_table_privilege(
          v_writer_owner,
          o.relation_oid,
          o.privilege_name
        )
      end as owner_has_privilege,
      case
        when v_writer_owner is null or o.schema_oid is null then null
        else pg_catalog.has_schema_privilege(
          v_writer_owner,
          o.schema_oid,
          'USAGE'
        )
      end as owner_has_schema_usage,
      case
        when v_writer_owner is null or o.relation_oid is null then null
        when not o.relrowsecurity then true
        when owner_role.rolsuper or owner_role.rolbypassrls then true
        when o.relowner = v_writer_owner and not o.relforcerowsecurity then true
        else false
      end as owner_bypasses_rls,
      case
        when not o.requires_identity_sequence then true
        when v_writer_owner is null or o.identity_sequence_oid is null then null
        else pg_catalog.has_sequence_privilege(
          v_writer_owner,
          o.identity_sequence_oid,
          'USAGE, UPDATE'
        )
      end as owner_has_identity_sequence_usage
    from observed o
    left join pg_catalog.pg_roles owner_role
      on owner_role.oid = v_writer_owner
  )
  select pg_catalog.string_agg(
    pg_catalog.format(
      '%I:%s table=%s schema_usage=%s rls_bypass=%s identity_sequence_usage=%s',
      c.table_name,
      c.privilege_name,
      coalesce(c.owner_has_privilege::text, 'NULL'),
      coalesce(c.owner_has_schema_usage::text, 'NULL'),
      coalesce(c.owner_bypasses_rls::text, 'NULL'),
      coalesce(c.owner_has_identity_sequence_usage::text, 'NULL')
    ),
    ', ' order by c.table_name, c.privilege_name
  )
  into v_owner_mismatches
  from checked c
  where c.schema_oid is null
     or c.relation_oid is null
     or c.owner_has_privilege is distinct from true
     or c.owner_has_schema_usage is distinct from true
     or c.owner_bypasses_rls is distinct from true
     or c.owner_has_identity_sequence_usage is distinct from true;

  if v_owner_mismatches is not null then
    raise exception using
      errcode = '42501',
      message = 'SUPERVISOR_SCOPE_RPC_OWNER_PRIVILEGE_MISMATCH',
      detail = v_owner_mismatches;
  end if;
end;
$service_role_rpc_validation$;

commit;
