-- SOLO STAGING. No ejecutar en controlhorario-prod ni usar datos reales.
-- Detenerse ante un target ambiguo. Produccion permanece NO-GO.
BEGIN TRANSACTION READ ONLY;

-- Diagnóstico final de lectura para migración 0036 en staging.
-- Archivo de ejecución manual en SQL Editor (sin cambios).

with
edge_function_direct_access as (
  select *
  from (values
    ('public.profiles', 'SELECT', true, 'employee-management,user-provisioning,device-enrollment'::text),
    ('public.roles', 'SELECT', true, 'employee-management,user-provisioning'::text),
    ('public.empleados', 'SELECT', true, 'employee-management,employee-sync,employee-upsert,user-provisioning,device-enrollment'::text),
    ('public.empleados', 'INSERT', true, 'employee-management,employee-upsert'::text),
    ('public.empleados', 'UPDATE', true, 'employee-management,employee-upsert'::text)
  ) as x(table_name, privilege, direct_dependency, consuming_functions)
),

service_role_contract as (
  select *
  from (values
    ('public.profiles'::text, 'SELECT'::text, true),
    ('public.profiles'::text, 'INSERT'::text, false),
    ('public.profiles'::text, 'UPDATE'::text, false),
    ('public.profiles'::text, 'DELETE'::text, false),
    ('public.profiles'::text, 'TRUNCATE'::text, false),
    ('public.profiles'::text, 'REFERENCES'::text, false),
    ('public.profiles'::text, 'TRIGGER'::text, false),
    ('public.roles'::text, 'SELECT'::text, true),
    ('public.roles'::text, 'INSERT'::text, false),
    ('public.roles'::text, 'UPDATE'::text, false),
    ('public.roles'::text, 'DELETE'::text, false),
    ('public.roles'::text, 'TRUNCATE'::text, false),
    ('public.roles'::text, 'REFERENCES'::text, false),
    ('public.roles'::text, 'TRIGGER'::text, false),
    ('public.empleados'::text, 'SELECT'::text, true),
    ('public.empleados'::text, 'INSERT'::text, true),
    ('public.empleados'::text, 'UPDATE'::text, true),
    ('public.empleados'::text, 'DELETE'::text, false),
    ('public.empleados'::text, 'TRUNCATE'::text, false),
    ('public.empleados'::text, 'REFERENCES'::text, false),
    ('public.empleados'::text, 'TRIGGER'::text, false),
    ('public.perfil_sucursales'::text, 'SELECT'::text, false),
    ('public.perfil_sucursales'::text, 'INSERT'::text, false),
    ('public.perfil_sucursales'::text, 'UPDATE'::text, false),
    ('public.perfil_sucursales'::text, 'DELETE'::text, false),
    ('public.perfil_sucursales'::text, 'TRUNCATE'::text, false),
    ('public.perfil_sucursales'::text, 'REFERENCES'::text, false),
    ('public.perfil_sucursales'::text, 'TRIGGER'::text, false),
    ('public.perfil_departamentos'::text, 'SELECT'::text, false),
    ('public.perfil_departamentos'::text, 'INSERT'::text, false),
    ('public.perfil_departamentos'::text, 'UPDATE'::text, false),
    ('public.perfil_departamentos'::text, 'DELETE'::text, false),
    ('public.perfil_departamentos'::text, 'TRUNCATE'::text, false),
    ('public.perfil_departamentos'::text, 'REFERENCES'::text, false),
    ('public.perfil_departamentos'::text, 'TRIGGER'::text, false)
  ) as s(table_name, privilege, expected_effective)
),

service_role_state as (
  select
    s.table_name,
    s.privilege,
    s.expected_effective,
    c.oid as relation_oid,
    (c.oid is not null) as relation_exists,
    case
      when c.oid is null then false
      else has_table_privilege('service_role', c.oid, s.privilege)
    end as current_effective,
    case
      when c.oid is null then false
      else exists (
        select 1
        from pg_class cc
        cross join lateral aclexplode(cc.relacl) acl
        where cc.oid = c.oid
          and acl.grantee = 'service_role'::regrole
          and acl.privilege_type = s.privilege
      )
    end as current_direct,
    case
      when c.oid is null then false
      else coalesce((
        select bool_or(coalesce(acl.is_grantable, false))
        from pg_class cc
        cross join lateral aclexplode(cc.relacl) acl
        where cc.oid = c.oid
          and acl.grantee = 'service_role'::regrole
          and acl.privilege_type = s.privilege
      ), false)
    end as grantable,
    case
      when c.oid is null then false
      else exists (
        select 1
        from pg_class cc
        cross join lateral aclexplode(cc.relacl) acl
        where cc.oid = c.oid
          and acl.grantee = 0
          and acl.privilege_type = s.privilege
      )
    end as granted_to_public,
    coalesce((
      select string_agg(r.rolname, ',')
      from pg_auth_members m
      join pg_roles r on r.oid = m.roleid
      where m.member = 'service_role'::regrole
        and has_table_privilege(r.oid, c.oid, s.privilege)
    ), '') as inherited_roles
  from service_role_contract s
  left join pg_class c
    on c.relnamespace = to_regnamespace(split_part(s.table_name, '.', 1))
   and c.relname = split_part(s.table_name, '.', 2)
   and c.relkind in ('r', 'p')
),

edge_need as (
  select
    d.table_name,
    d.privilege,
    d.direct_dependency,
    d.consuming_functions
  from edge_function_direct_access d
),

service_role_differences as (
  select
    s.table_name,
    s.privilege,
    s.expected_effective,
    s.current_effective,
    s.current_direct,
    s.grantable,
    s.granted_to_public,
    nullif(s.inherited_roles, '') as inherited_roles,
    case
      when s.expected_effective and not s.relation_exists then 'INVESTIGATE'
      when s.expected_effective and not s.current_effective then 'GRANT'
      when not s.expected_effective and s.current_effective then 'REVOKE'
      else 'RETAIN'
    end as planned_action,
    case
      when s.relation_oid is null and s.expected_effective then 'HARD_PRECONDITION'
      when s.grantable then 'HARD_PRECONDITION'
      when s.granted_to_public then 'HARD_PRECONDITION'
      when coalesce(s.inherited_roles, '') <> '' then 'HARD_PRECONDITION'
      when not s.expected_effective and coalesce(e.direct_dependency, false) then 'HARD_PRECONDITION'
      when s.expected_effective is distinct from s.current_effective then 'EXPECTED_REMEDIATION'
      else 'POSTCONDITION'
    end as classification,
    case
      when s.relation_oid is null and s.expected_effective
        then 'missing required table/function contract target'
      when s.grantable
        then 'hard precondition: WITH GRANT OPTION present'
      when s.granted_to_public
        then 'hard precondition: PUBLIC has privilege'
      when coalesce(s.inherited_roles, '') <> ''
        then format('hard precondition: inherited via %s', s.inherited_roles)
      when not s.expected_effective and coalesce(e.direct_dependency, false)
        then format('hard precondition: local Edge Function requires %s on %s', s.privilege, s.table_name)
      when s.expected_effective and not s.current_effective
        then 'expected remediation: migration 0036 grants privilege'
      when s.expected_effective is false and s.current_effective
        then 'expected remediation: migration 0036 revokes privilege'
      else 'within expected contract after applying 0036'
    end as blocking_reason
  from service_role_state s
  left join edge_need e
    on e.table_name = s.table_name
   and e.privilege = s.privilege
  where coalesce(s.current_effective, false) is distinct from s.expected_effective
     or coalesce(s.current_direct, false) is distinct from s.expected_effective
     or s.relation_oid is null and s.expected_effective
),

active_companies as (
  select id as company_id
  from public.companies
  where status = 'active'
),
expected_roles as (
  values ('admin'::text), ('supervisor'::text)
),
canonical_role_scan as (
  select
    ac.company_id,
    er.column1 as canonical_code,
    r.id as canonical_role_id
  from active_companies ac
  cross join expected_roles er
  left join lateral (
    select p.id
    from public.roles p
    where p.company_id = ac.company_id
      and private.normalizar_codigo_rol(p.code) = upper(er.column1)
    order by (case when lower(p.code) = er.column1 then 0 else 1 end),
      (case when p.is_active then 0 else 1 end),
      p.created_at,
      p.id
    limit 1
  ) r on true
),
role_aliases as (
  select count(*) as active_aliases_remaining
  from public.roles ro
  where ro.is_active
    and private.normalizar_codigo_rol(ro.code) in ('ADMIN', 'SUPERVISOR')
    and lower(ro.code) not in ('admin', 'supervisor')
),
req14_tiene as (
  select
    p.oid is not null as exists_now,
    coalesce(p.prosecdef, false) as prosecdef,
    coalesce(p.proretset, false) as proretset,
    coalesce(pg_catalog.format_type(p.prorettype, null), '') as return_type,
    coalesce((
      select bool_or(x is not null)
      from unnest(coalesce(p.proconfig, array[]::text[])) x
      where x like 'search_path=%'
      limit 1
    ), false) as search_path_config,
    case when p.oid is null then false else has_function_privilege('authenticated', p.oid, 'EXECUTE') end as auth_execute,
    case when p.oid is null then false else has_function_privilege('anon', p.oid, 'EXECUTE') end as anon_execute,
    case when p.oid is null then false else has_function_privilege('public', p.oid, 'EXECUTE') end as public_execute
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'tiene_permiso'
    and pg_get_function_identity_arguments(p.oid) = 'text'
),
req14_obtener as (
  select
    p.oid is not null as exists_now,
    coalesce(p.prosecdef, false) as prosecdef,
    coalesce(p.proretset, false) as proretset,
    coalesce(pg_catalog.format_type(p.prorettype, null), '') as return_type,
    coalesce((
      select bool_or(x is not null)
      from unnest(coalesce(p.proconfig, array[]::text[])) x
      where x like 'search_path=%'
      limit 1
    ), false) as search_path_config,
    case when p.oid is null then false else has_function_privilege('authenticated', p.oid, 'EXECUTE') end as auth_execute,
    case when p.oid is null then false else has_function_privilege('anon', p.oid, 'EXECUTE') end as anon_execute,
    case when p.oid is null then false else has_function_privilege('public', p.oid, 'EXECUTE') end as public_execute
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'obtener_departamentos_supervisor_actual'
    and pg_get_function_identity_arguments(p.oid) = ''
),
req11_counts as (
  select
    count(*) filter (where current_effective is distinct from expected_effective) as effective_mismatch,
    count(*) filter (where current_direct is distinct from expected_effective) as direct_mismatch,
    count(*) filter (where current_direct and grantable) as grant_option_mismatch,
    count(*) filter (where current_effective and not expected_effective and granted_to_public) as public_leak,
    count(*) filter (where current_effective and (grantable or coalesce(inherited_roles, '') <> '')) as inherited_or_grantable_mismatch
  from service_role_state
),
service_role_poststate_projection as (
  select
    s.table_name,
    s.privilege,
    s.expected_effective,
    case when s.expected_effective and s.relation_exists then true else false end as poststate_direct,
    case
      when s.relation_oid is null then false
      when s.expected_effective then true
      when coalesce(s.granted_to_public, false) then true
      when coalesce(s.inherited_roles, '') <> '' then true
      else false
    end as poststate_effective,
    s.granted_to_public,
    coalesce(s.inherited_roles, '') as inherited_roles,
    s.grantable,
    s.current_direct,
    s.current_effective
  from service_role_state s
),
service_role_poststate_mismatches as (
  select
    count(*) filter (where poststate_effective is distinct from expected_effective) as service_role_poststate_mismatch,
    count(*) filter (where poststate_direct is distinct from expected_effective) as poststate_direct_mismatch
  from service_role_poststate_projection
),
req15_metrics as (
  select
    coalesce(sum(case when canonical_code = 'admin' and canonical_role_id is null then 1 else 0 end), 0) > 0 as active_exact_admin_missing,
    coalesce(sum(case when canonical_code = 'supervisor' and canonical_role_id is null then 1 else 0 end), 0) > 0 as active_exact_supervisor_missing,
    coalesce((select active_aliases_remaining from role_aliases), 0) as role_aliases_remaining,
    coalesce((select not exists_now from req14_tiene), false) as tiene_permiso_missing_current,
    true::boolean as tiene_permiso_will_be_created,
    coalesce((
      select exists_now
          and coalesce(prosecdef, false) is distinct from true
          or coalesce(proretset, false) is distinct from false
          or coalesce(return_type, '') is distinct from 'boolean'
          or coalesce(search_path_config, false) is distinct from true
          or not coalesce(auth_execute, false)
          or coalesce(anon_execute, false)
          or coalesce(public_execute, false)
      from req14_tiene
    ), false) as tiene_permiso_poststate_mismatch,
    coalesce((select not exists_now from req14_obtener), false) as obtener_missing_current,
    coalesce((
      select exists_now
          and coalesce(prosecdef, false) is distinct from true
          or coalesce(proretset, false) is distinct from true
          or coalesce(return_type, '') is distinct from 'record'
          or coalesce(search_path_config, false) is distinct from true
          or not coalesce(auth_execute, false)
          or coalesce(anon_execute, false)
          or coalesce(public_execute, false)
      from req14_obtener
    ), false) as obtener_poststate_mismatch,
    coalesce((select effective_mismatch from req11_counts), 0) as service_role_effective_mismatch_current,
    coalesce((select direct_mismatch from req11_counts), 0) as service_role_direct_mismatch_current,
    coalesce((select service_role_poststate_mismatch from service_role_poststate_mismatches), 0) as service_role_poststate_mismatch,
    coalesce((select inherited_or_grantable_mismatch > 0 from req11_counts), false) as service_role_inherited_privilege,
    coalesce((select grant_option_mismatch from req11_counts), 0) > 0 as service_role_grant_option
  from canonical_role_scan
),
req11_state as (
  select
    coalesce((select effective_mismatch from req11_counts), 0) as effective_mismatch,
    coalesce((select direct_mismatch from req11_counts), 0) as direct_mismatch,
    coalesce((select inherited_or_grantable_mismatch from req11_counts), 0) as inherited_or_grantable,
    coalesce((select public_leak from req11_counts), 0) as public_leak
),
req14_state as (
  select
    coalesce((select exists_now from req14_tiene), false) as tiene_permiso_exists,
    coalesce((select exists_now from req14_obtener), false) as obtener_exists
),
req15_rows as (
  select
    'active_exact_admin_missing'::text as check_name,
    case when active_exact_admin_missing then 'BLOCKED' else 'PASS' end as status,
    coalesce(active_exact_admin_missing::text, 'false'),
    'false',
    'CRITICAL',
    'Debe existir ADMIN exacto activo en cada empresa activa.'
  from req15_metrics
  union all
  select
    'active_exact_supervisor_missing',
    case when active_exact_supervisor_missing then 'BLOCKED' else 'PASS' end,
    coalesce(active_exact_supervisor_missing::text, 'false'),
    'false',
    'CRITICAL',
    'Debe existir SUPERVISOR exacto activo en cada empresa activa.'
  from req15_metrics
  union all
  select
    'role_aliases_remaining',
    case when role_aliases_remaining = 0 then 'PASS' else 'WARNING' end,
    coalesce(role_aliases_remaining::text, '0'),
    '0',
    'HIGH',
    'No deben quedar aliases activos para ADMIN/SUPERVISOR.'
  from req15_metrics
  union all
  select
    'tiene_permiso_missing_current',
    case when tiene_permiso_missing_current then 'BLOCKED' else 'PASS' end,
    coalesce(tiene_permiso_missing_current::text, 'false'),
    'false',
    'CRITICAL',
    'Estado actual de public.tiene_permiso(text).'
  from req15_metrics
  union all
  select
    'tiene_permiso_will_be_created',
    'PASS',
    coalesce(tiene_permiso_will_be_created::text, 'true'),
    'true',
    'CRITICAL',
    'La migración 0036 crea/reemplaza public.tiene_permiso(text).'
  from req15_metrics
  union all
  select
    'tiene_permiso_poststate_mismatch',
    case when not tiene_permiso_poststate_mismatch then 'PASS' else 'WARNING' end,
    coalesce(tiene_permiso_poststate_mismatch::text, 'false'),
    'false',
    'CRITICAL',
    'Compatibilidad contractual de public.tiene_permiso(text) tras 0036.'
  from req15_metrics
  union all
  select
    'obtener_missing_current',
    case when obtener_missing_current then 'BLOCKED' else 'PASS' end,
    coalesce(obtener_missing_current::text, 'false'),
    'false',
    'CRITICAL',
    'Estado actual de public.obtener_departamentos_supervisor_actual().'
  from req15_metrics
  union all
  select
    'obtener_poststate_mismatch',
    case when not obtener_poststate_mismatch then 'PASS' else 'WARNING' end,
    coalesce(obtener_poststate_mismatch::text, 'false'),
    'false',
    'CRITICAL',
    'Compatibilidad contractual de public.obtener_departamentos_supervisor_actual() tras 0036.'
  from req15_metrics
  union all
  select
    'service_role_effective_mismatch_current',
    case when service_role_effective_mismatch_current = 0 then 'PASS' else 'BLOCKED' end,
    coalesce(service_role_effective_mismatch_current::text, '0'),
    '0',
    'CRITICAL',
    'Diferencias effective actuales respecto al contrato de 0036.'
  from req15_metrics
  union all
  select
    'service_role_direct_mismatch_current',
    case when service_role_direct_mismatch_current = 0 then 'PASS' else 'BLOCKED' end,
    coalesce(service_role_direct_mismatch_current::text, '0'),
    '0',
    'CRITICAL',
    'Diferencias directas actuales respecto al contrato de 0036.'
  from req15_metrics
  union all
  select
    'service_role_poststate_mismatch',
    case when service_role_poststate_mismatch = 0 then 'PASS' else 'WARNING' end,
    coalesce(service_role_poststate_mismatch::text, '0'),
    '0',
    'CRITICAL',
    'Estado posterior esperado de service_role tras 0036 (incluye herencia/public).'
  from req15_metrics
  union all
  select
    'service_role_grant_option',
    case when not service_role_grant_option then 'PASS' else 'BLOCKED' end,
    coalesce(service_role_grant_option::text, 'false'),
    'false',
    'CRITICAL',
    'No debe existir WITH GRANT OPTION en privileges de service_role relevantes.'
  from req15_metrics
  union all
  select
    'service_role_public_leak',
    case when p.service_role_public_leak then 'BLOCKED' else 'PASS' end,
    coalesce(p.service_role_public_leak::text, 'false'),
    'false',
    'CRITICAL',
    'No debe haber privilegio de PUBLIC sobre tablas en contrato 0036.'
  from (
    select
      (coalesce((select public_leak from req11_counts), 0) > 0) as service_role_public_leak
  ) p
  union all
  select
    'service_role_inherited_privilege',
    case when not service_role_inherited_privilege then 'PASS' else 'BLOCKED' end,
    coalesce(service_role_inherited_privilege::text, 'false'),
    'false',
    'CRITICAL',
    'No deben quedar privilegios heredados no esperados para service_role.'
  from req15_metrics
),

req11_rows as (
  select
    'req11_service_role_current_state'::text as check_name,
    case
      when effective_mismatch = 0 and direct_mismatch = 0 and inherited_or_grantable = 0 and public_leak = 0 then 'PASS'
      else 'BLOCKED'
    end as status,
    format(
      'effective_mismatch=%s; direct_mismatch=%s; inherited_or_grantable=%s; public=%s',
      coalesce(effective_mismatch::text, '0'),
      coalesce(direct_mismatch::text, '0'),
      coalesce(inherited_or_grantable::text, '0'),
      coalesce(public_leak::text, '0')
    ),
    'all zero',
    'CRITICAL',
    'Resumen actual de REQ11 (service_role).'
  from req11_state
),

req14_rows as (
  select
    'req14_functions_current_state'::text as check_name,
    case
      when tiene_permiso_exists and obtener_exists then
        case
          when (
            (select not tiene_permiso_poststate_mismatch from req15_metrics) and
            (select not obtener_poststate_mismatch from req15_metrics)
          ) then 'PASS'
          else 'WARNING'
        end
      else 'BLOCKED'
    end as status,
    format('tiene_permiso=%s; obtener=%s', coalesce(tiene_permiso_exists::text, 'false'), coalesce(obtener_exists::text, 'false')),
    'both true and compatible',
    'HIGH',
    'Resumen actual de REQ14 (contratos RPC requeridos).'
  from req14_state
)

select
  d.table_name,
  d.privilege,
  d.expected_effective,
  d.current_effective,
  d.current_direct,
  d.grantable,
  d.granted_to_public,
  d.inherited_roles,
  d.planned_action,
  d.classification,
  d.blocking_reason
from service_role_differences d
order by d.table_name, d.privilege;

select
  r.check_name,
  r.status,
  r.actual_value,
  r.expected_value,
  r.severity,
  r.instruction
from req11_rows
union all
select
  r.check_name,
  r.status,
  r.actual_value,
  r.expected_value,
  r.severity,
  r.instruction
from req15_rows r
union all
select
  c.check_name,
  c.status,
  c.actual_value,
  c.expected_value,
  c.severity,
  c.instruction
from req14_rows c
order by check_name;

ROLLBACK;
