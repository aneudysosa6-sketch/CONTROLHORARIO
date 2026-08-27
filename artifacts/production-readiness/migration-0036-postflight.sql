-- Migration 0036 postflight.
-- SELECT-only: this file must not change database state.
-- Catalog ACL values are passed directly to aclexplode(); NULL means zero rows.

-- 1) Effective privilege, stored direct ACL, and grant-option matrix.
with target_tables(table_order, table_name, allowed_privileges) as (
  values
    (1, 'profiles'::text, array['SELECT']::text[]),
    (2, 'roles', array['SELECT']::text[]),
    (3, 'empleados', array['SELECT', 'INSERT', 'UPDATE']::text[]),
    (4, 'perfil_sucursales', array[]::text[]),
    (5, 'perfil_departamentos', array[]::text[])
),
privilege_list(privilege_order, privilege_name) as (
  values
    (1, 'SELECT'::text),
    (2, 'INSERT'),
    (3, 'UPDATE'),
    (4, 'DELETE'),
    (5, 'TRUNCATE'),
    (6, 'REFERENCES'),
    (7, 'TRIGGER'),
    (8, 'MAINTAIN')
),
context as (
  select
    pg_catalog.current_setting('server_version_num')::integer >= 170000
      as maintain_supported,
    (
      select r.oid
      from pg_catalog.pg_roles r
      where r.rolname = 'service_role'
    ) as service_role_oid
),
expected as (
  select
    t.table_order,
    t.table_name,
    p.privilege_order,
    p.privilege_name,
    p.privilege_name = any(t.allowed_privileges) as expected_value
  from target_tables t
  cross join privilege_list p
),
observed as (
  select
    e.*,
    x.maintain_supported,
    x.service_role_oid,
    c.oid as table_oid,
    table_owner.rolname as table_owner_name,
    c.relowner = x.service_role_oid as service_role_is_owner,
    not (
      e.privilege_name = 'MAINTAIN'
      and not x.maintain_supported
    ) as applicable,
    case
      when c.oid is null or x.service_role_oid is null then null
      when e.privilege_name = 'MAINTAIN'
        and not x.maintain_supported then null
      else pg_catalog.has_table_privilege(
        x.service_role_oid,
        c.oid,
        e.privilege_name
      )
    end as observed_effective,
    case
      when c.oid is null or x.service_role_oid is null then null
      when e.privilege_name = 'MAINTAIN'
        and not x.maintain_supported then null
      else pg_catalog.has_table_privilege(
        x.service_role_oid,
        c.oid,
        e.privilege_name || ' WITH GRANT OPTION'
      )
    end as observed_effective_grantable,
    case
      when c.oid is null or x.service_role_oid is null then null
      else exists (
        select 1
        from pg_catalog.aclexplode(c.relacl) a
        where a.grantee = x.service_role_oid
          and pg_catalog.upper(a.privilege_type) = e.privilege_name
      )
    end as observed_direct,
    case
      when c.oid is null or x.service_role_oid is null then null
      else exists (
        select 1
        from pg_catalog.aclexplode(c.relacl) a
        where a.grantee = x.service_role_oid
          and pg_catalog.upper(a.privilege_type) = e.privilege_name
          and a.is_grantable
      )
    end as direct_grantable,
    case
      when c.oid is null or x.service_role_oid is null then null
      when e.privilege_name in ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
        then pg_catalog.has_any_column_privilege(
          x.service_role_oid,
          c.oid,
          e.privilege_name
        )
      else null
    end as observed_any_column_effective,
    case
      when c.oid is null or x.service_role_oid is null then null
      when e.privilege_name in ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
        then pg_catalog.has_any_column_privilege(
          x.service_role_oid,
          c.oid,
          e.privilege_name || ' WITH GRANT OPTION'
        )
      else null
    end as observed_any_column_grantable_effective,
    case
      when c.oid is null or x.service_role_oid is null then null
      when e.privilege_name in ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
        then exists (
          select 1
          from pg_catalog.pg_attribute attribute
          cross join lateral pg_catalog.aclexplode(attribute.attacl) column_acl
          where attribute.attrelid = c.oid
            and attribute.attnum > 0
            and not attribute.attisdropped
            and column_acl.grantee = x.service_role_oid
            and pg_catalog.upper(column_acl.privilege_type) = e.privilege_name
        )
      else null
    end as observed_direct_column
  from expected e
  cross join context x
  left join pg_catalog.pg_namespace n
    on n.nspname = 'public'
  left join pg_catalog.pg_class c
    on c.relnamespace = n.oid
   and c.relname = e.table_name
   and c.relkind in ('r', 'p')
  left join pg_catalog.pg_roles table_owner
    on table_owner.oid = c.relowner
),
checked as (
  select
    o.*,
    case
      when not o.applicable then true
      else o.table_oid is not null
        and o.service_role_oid is not null
        and o.observed_effective is not distinct from o.expected_value
        and o.observed_effective_grantable is not distinct from false
        and o.observed_direct is not distinct from o.expected_value
        and o.direct_grantable is not distinct from false
        and (
          o.privilege_name not in ('SELECT', 'INSERT', 'UPDATE', 'REFERENCES')
          or (
            o.observed_any_column_effective
              is not distinct from o.expected_value
            and o.observed_any_column_grantable_effective
              is not distinct from false
            and o.observed_direct_column is not distinct from false
          )
        )
    end as matches_expected
  from observed o
)
select
  c.table_name,
  c.privilege_name,
  c.applicable,
  c.table_owner_name,
  c.service_role_is_owner,
  c.expected_value,
  c.observed_effective,
  c.observed_effective_grantable,
  c.observed_direct,
  c.direct_grantable,
  c.observed_any_column_effective,
  c.observed_any_column_grantable_effective,
  c.observed_direct_column,
  c.matches_expected,
  pg_catalog.bool_and(c.matches_expected) over () as all_privileges_match
from checked c
order by c.table_order, c.privilege_order;

-- 2) The eight 0033 RPCs: existence, direct/effective EXECUTE, owner, and
-- SECURITY DEFINER. Function ACL is read from proacl only; no acldefault().
with required_rpc(function_order, signature) as (
  values
    (1, 'public.guardar_alcance_supervisor_internal(jsonb)'::text),
    (2, 'public.obtener_alcance_supervisor_internal(jsonb)'),
    (3, 'public.listar_accesos_internal(jsonb)'),
    (4, 'public.crear_acceso_con_alcance_internal(jsonb)'),
    (5, 'public.obtener_creacion_acceso_idempotente_internal(jsonb)'),
    (6, 'public.actualizar_acceso_con_alcance_internal(jsonb)'),
    (7, 'public.obtener_actualizacion_acceso_confirmada_internal(jsonb)'),
    (8, 'public.cambiar_estado_acceso_con_alcance_internal(jsonb)')
),
context as (
  select (
    select r.oid
    from pg_catalog.pg_roles r
    where r.rolname = 'service_role'
  ) as service_role_oid
),
observed as (
  select
    r.function_order,
    r.signature,
    x.service_role_oid,
    p.oid as function_oid,
    owner_role.rolname as owner_name,
    p.prosecdef as security_definer,
    p.proconfig,
    case
      when x.service_role_oid is null or p.oid is null then null
      else pg_catalog.has_function_privilege(
        x.service_role_oid,
        p.oid,
        'EXECUTE'
      )
    end as service_role_execute_effective,
    case
      when x.service_role_oid is null or p.oid is null then null
      else exists (
        select 1
        from pg_catalog.aclexplode(p.proacl) a
        where a.grantee = x.service_role_oid
          and pg_catalog.upper(a.privilege_type) = 'EXECUTE'
      )
    end as service_role_execute_direct
  from required_rpc r
  cross join context x
  left join pg_catalog.pg_proc p
    on p.oid = pg_catalog.to_regprocedure(r.signature)
  left join pg_catalog.pg_roles owner_role
    on owner_role.oid = p.proowner
),
checked as (
  select
    o.*,
    o.function_oid is not null
      and o.owner_name is not null
      and o.security_definer is true
      and o.service_role_execute_effective is true
      and o.service_role_execute_direct is true
      as matches_expected
  from observed o
)
select
  c.signature,
  c.function_oid is not null as function_exists,
  c.owner_name,
  c.security_definer,
  c.proconfig,
  c.service_role_execute_effective,
  c.service_role_execute_direct,
  c.matches_expected,
  pg_catalog.bool_and(c.matches_expected) over () as all_rpc_checks_match
from checked c
order by c.function_order;

-- 3) Each RPC owner can perform the direct table operations in that RPC.
-- UPDATE is required for SELECT ... FOR UPDATE even when no row value changes.
with required_privilege(
  function_order,
  requirement_order,
  signature,
  table_schema,
  table_name,
  privilege_name
) as (
  values
    (1, 1, 'public.guardar_alcance_supervisor_internal(jsonb)'::text, 'public'::text, 'profiles'::text, 'SELECT'::text),
    (1, 2, 'public.guardar_alcance_supervisor_internal(jsonb)', 'public', 'profiles', 'UPDATE'),
    (1, 3, 'public.guardar_alcance_supervisor_internal(jsonb)', 'public', 'roles', 'SELECT'),
    (1, 4, 'public.guardar_alcance_supervisor_internal(jsonb)', 'public', 'branches', 'SELECT'),
    (1, 5, 'public.guardar_alcance_supervisor_internal(jsonb)', 'public', 'departments', 'SELECT'),
    (1, 6, 'public.guardar_alcance_supervisor_internal(jsonb)', 'public', 'perfil_sucursales', 'SELECT'),
    (1, 7, 'public.guardar_alcance_supervisor_internal(jsonb)', 'public', 'perfil_sucursales', 'INSERT'),
    (1, 8, 'public.guardar_alcance_supervisor_internal(jsonb)', 'public', 'perfil_sucursales', 'DELETE'),
    (1, 9, 'public.guardar_alcance_supervisor_internal(jsonb)', 'public', 'perfil_departamentos', 'SELECT'),
    (1, 10, 'public.guardar_alcance_supervisor_internal(jsonb)', 'public', 'perfil_departamentos', 'INSERT'),
    (1, 11, 'public.guardar_alcance_supervisor_internal(jsonb)', 'public', 'perfil_departamentos', 'DELETE'),
    (1, 12, 'public.guardar_alcance_supervisor_internal(jsonb)', 'public', 'administracion_auditoria', 'INSERT'),
    (2, 1, 'public.obtener_alcance_supervisor_internal(jsonb)', 'public', 'profiles', 'SELECT'),
    (2, 2, 'public.obtener_alcance_supervisor_internal(jsonb)', 'public', 'roles', 'SELECT'),
    (2, 3, 'public.obtener_alcance_supervisor_internal(jsonb)', 'public', 'branches', 'SELECT'),
    (2, 4, 'public.obtener_alcance_supervisor_internal(jsonb)', 'public', 'departments', 'SELECT'),
    (2, 5, 'public.obtener_alcance_supervisor_internal(jsonb)', 'public', 'perfil_sucursales', 'SELECT'),
    (2, 6, 'public.obtener_alcance_supervisor_internal(jsonb)', 'public', 'perfil_departamentos', 'SELECT'),
    (3, 1, 'public.listar_accesos_internal(jsonb)', 'public', 'profiles', 'SELECT'),
    (3, 2, 'public.listar_accesos_internal(jsonb)', 'public', 'roles', 'SELECT'),
    (3, 3, 'public.listar_accesos_internal(jsonb)', 'public', 'empleados', 'SELECT'),
    (3, 4, 'public.listar_accesos_internal(jsonb)', 'auth', 'users', 'SELECT'),
    (4, 1, 'public.crear_acceso_con_alcance_internal(jsonb)', 'public', 'roles', 'SELECT'),
    (4, 2, 'public.crear_acceso_con_alcance_internal(jsonb)', 'public', 'user_provisioning_audit', 'SELECT'),
    (4, 3, 'public.crear_acceso_con_alcance_internal(jsonb)', 'public', 'user_provisioning_audit', 'UPDATE'),
    (5, 1, 'public.obtener_creacion_acceso_idempotente_internal(jsonb)', 'public', 'user_provisioning_audit', 'SELECT'),
    (5, 2, 'public.obtener_creacion_acceso_idempotente_internal(jsonb)', 'public', 'profiles', 'SELECT'),
    (6, 1, 'public.actualizar_acceso_con_alcance_internal(jsonb)', 'public', 'profiles', 'SELECT'),
    (6, 2, 'public.actualizar_acceso_con_alcance_internal(jsonb)', 'public', 'profiles', 'UPDATE'),
    (6, 3, 'public.actualizar_acceso_con_alcance_internal(jsonb)', 'public', 'roles', 'SELECT'),
    (6, 4, 'public.actualizar_acceso_con_alcance_internal(jsonb)', 'public', 'perfil_sucursales', 'SELECT'),
    (6, 5, 'public.actualizar_acceso_con_alcance_internal(jsonb)', 'public', 'perfil_departamentos', 'SELECT'),
    (6, 6, 'public.actualizar_acceso_con_alcance_internal(jsonb)', 'public', 'administracion_auditoria', 'SELECT'),
    (6, 7, 'public.actualizar_acceso_con_alcance_internal(jsonb)', 'public', 'administracion_auditoria', 'INSERT'),
    (6, 8, 'public.actualizar_acceso_con_alcance_internal(jsonb)', 'public', 'administracion_auditoria', 'UPDATE'),
    (7, 1, 'public.obtener_actualizacion_acceso_confirmada_internal(jsonb)', 'public', 'administracion_auditoria', 'SELECT'),
    (8, 1, 'public.cambiar_estado_acceso_con_alcance_internal(jsonb)', 'public', 'profiles', 'SELECT'),
    (8, 2, 'public.cambiar_estado_acceso_con_alcance_internal(jsonb)', 'public', 'profiles', 'UPDATE'),
    (8, 3, 'public.cambiar_estado_acceso_con_alcance_internal(jsonb)', 'public', 'roles', 'SELECT')
),
resolved as (
  select
    r.*,
    p.oid as function_oid,
    p.proowner as owner_oid,
    owner_role.rolname as owner_name,
    owner_role.rolsuper,
    owner_role.rolbypassrls,
    n.oid as schema_oid,
    c.oid as table_oid,
    c.relowner as table_owner_oid,
    c.relrowsecurity,
    c.relforcerowsecurity,
    r.table_schema = 'public'
      and r.table_name = 'administracion_auditoria'
      and r.privilege_name = 'INSERT'
      as requires_identity_sequence,
    case
      when r.table_schema = 'public'
        and r.table_name = 'administracion_auditoria'
        and r.privilege_name = 'INSERT'
        then pg_catalog.to_regclass(
          pg_catalog.pg_get_serial_sequence(
            'public.administracion_auditoria',
            'id'
          )
        )
      else null
    end as identity_sequence_oid
  from required_privilege r
  left join pg_catalog.pg_proc p
    on p.oid = pg_catalog.to_regprocedure(r.signature)
  left join pg_catalog.pg_roles owner_role
    on owner_role.oid = p.proowner
  left join pg_catalog.pg_namespace n
    on n.nspname = r.table_schema
  left join pg_catalog.pg_class c
    on c.relnamespace = n.oid
   and c.relname = r.table_name
   and c.relkind in ('r', 'p')
),
observed as (
  select
    q.*,
    case
      when q.owner_oid is null or q.table_oid is null then null
      else pg_catalog.has_table_privilege(
        q.owner_oid,
        q.table_oid,
        q.privilege_name
      )
    end as owner_has_privilege,
    case
      when q.owner_oid is null or q.schema_oid is null then null
      else pg_catalog.has_schema_privilege(
        q.owner_oid,
        q.schema_oid,
        'USAGE'
      )
    end as owner_has_schema_usage,
    case
      when q.owner_oid is null or q.table_oid is null then null
      when not q.relrowsecurity then true
      when q.rolsuper or q.rolbypassrls then true
      when q.table_owner_oid = q.owner_oid
        and not q.relforcerowsecurity then true
      else false
    end as owner_bypasses_rls,
    case
      when not q.requires_identity_sequence then true
      when q.owner_oid is null or q.identity_sequence_oid is null then null
      else pg_catalog.has_sequence_privilege(
        q.owner_oid,
        q.identity_sequence_oid,
        'USAGE, UPDATE'
      )
    end as owner_has_identity_sequence_usage
  from resolved q
),
checked as (
  select
    o.*,
    o.function_oid is not null
      and o.owner_oid is not null
      and o.schema_oid is not null
      and o.table_oid is not null
      and o.owner_has_privilege is true
      and o.owner_has_schema_usage is true
      and o.owner_bypasses_rls is true
      and o.owner_has_identity_sequence_usage is true
      as matches_expected
  from observed o
)
select
  c.signature,
  c.owner_name,
  c.table_schema,
  c.table_name,
  c.privilege_name,
  c.owner_has_privilege,
  c.owner_has_schema_usage,
  c.owner_bypasses_rls,
  c.identity_sequence_oid,
  c.owner_has_identity_sequence_usage,
  c.matches_expected,
  pg_catalog.bool_and(c.matches_expected) over ()
    as all_rpc_owner_privileges_match
from checked c
order by c.function_order, c.requirement_order;

-- 4) RLS flags expected from migrations 0001/0002. 0036 must not change them.
with expected(table_order, table_name, row_security, force_row_security) as (
  values
    (1, 'profiles'::text, true, false),
    (2, 'roles', true, false),
    (3, 'empleados', true, false),
    (4, 'perfil_sucursales', true, false),
    (5, 'perfil_departamentos', true, false)
),
checked as (
  select
    e.*,
    c.oid as table_oid,
    c.relrowsecurity as observed_row_security,
    c.relforcerowsecurity as observed_force_row_security,
    c.oid is not null
      and c.relrowsecurity is not distinct from e.row_security
      and c.relforcerowsecurity is not distinct from e.force_row_security
      as matches_expected
  from expected e
  left join pg_catalog.pg_namespace n
    on n.nspname = 'public'
  left join pg_catalog.pg_class c
    on c.relnamespace = n.oid
   and c.relname = e.table_name
   and c.relkind in ('r', 'p')
)
select
  c.table_name,
  c.row_security as expected_row_security,
  c.observed_row_security,
  c.force_row_security as expected_force_row_security,
  c.observed_force_row_security,
  c.matches_expected,
  pg_catalog.bool_and(c.matches_expected) over () as all_rls_flags_match
from checked c
order by c.table_order;

-- 5) Policy names plus a definition fingerprint. Compare policy_fingerprint
-- byte-for-byte with the same query captured immediately before applying 0036.
with expected(table_order, table_name, expected_policy_names) as (
  values
    (1, 'profiles'::text, array['profiles_select_granular']::text[]),
    (2, 'roles', array['roles_manage_by_admin', 'roles_select_own_company']::text[]),
    (3, 'empleados', array[
      'empleados_insert_autorizado',
      'empleados_select_segun_alcance',
      'empleados_update_autorizado'
    ]::text[]),
    (4, 'perfil_sucursales', array[
      'perfil_sucursales_manage',
      'perfil_sucursales_select'
    ]::text[]),
    (5, 'perfil_departamentos', array[
      'perfil_departamentos_manage',
      'perfil_departamentos_select'
    ]::text[])
),
observed as (
  select
    e.table_order,
    e.table_name,
    e.expected_policy_names,
    coalesce(
      pg_catalog.array_agg(p.policyname::text order by p.policyname)
        filter (where p.policyname is not null),
      array[]::text[]
    ) as observed_policy_names,
    pg_catalog.md5(
      coalesce(
        pg_catalog.string_agg(
          pg_catalog.concat_ws(
            E'\x1f',
            p.policyname,
            p.permissive,
            p.roles::text,
            p.cmd,
            coalesce(p.qual, ''),
            coalesce(p.with_check, '')
          ),
          E'\x1e' order by p.policyname
        ) filter (where p.policyname is not null),
        ''
      )
    ) as policy_fingerprint
  from expected e
  left join pg_catalog.pg_policies p
    on p.schemaname = 'public'
   and p.tablename = e.table_name
  group by e.table_order, e.table_name, e.expected_policy_names
),
checked as (
  select
    o.*,
    o.observed_policy_names = o.expected_policy_names
      as policy_names_match
  from observed o
)
select
  c.table_name,
  c.expected_policy_names,
  c.observed_policy_names,
  c.policy_names_match,
  c.policy_fingerprint,
  pg_catalog.bool_and(c.policy_names_match) over ()
    as all_policy_names_match
from checked c
order by c.table_order;

-- 6) Full policy definitions for human review and pre/post comparison.
select
  p.schemaname,
  p.tablename,
  p.policyname,
  p.permissive,
  p.roles,
  p.cmd,
  p.qual,
  p.with_check
from pg_catalog.pg_policies p
where p.schemaname = 'public'
  and p.tablename in (
    'profiles',
    'roles',
    'empleados',
    'perfil_sucursales',
    'perfil_departamentos'
  )
order by p.tablename, p.policyname;
