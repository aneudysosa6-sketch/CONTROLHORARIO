BEGIN TRANSACTION READ ONLY;

-- 0036-staging-precheck-readonly.sql
-- Objetivo: precheck de solo lectura para ejecutar en SQL Editor de
-- controlhorario-staging antes de autorizar la migraci贸n 0036.
-- No contiene instrucciones DML/DDL/DO/CTE de mutaci贸n ni ejecuci贸n remota.

-- Hash de control de la migraci贸n objetivo:
-- 64CA1931C39B34077E8401B9AA7A7D747E542D06B8320395F35FF4C5F1AA3D04

with
expected_roles as (
  values
    ('admin'::text),
    ('supervisor'::text)
),
required_permissions as (
  select *
  from (values
    ('admin'::text, 'usuarios.administrar'::text, 'empresa'::text),
    ('admin'::text, 'roles.administrar'::text, 'empresa'::text),
    ('admin'::text, 'permisos.administrar'::text, 'empresa'::text),
    ('supervisor'::text, 'portal.ver_dashboard'::text, 'empresa'::text)
  ) as v(canonical_code, permission_code, expected_scope)
),
active_companies as (
  select
    id as company_id
  from public.companies
  where status = 'active'
),
roles_norm as (
  select
    r.id,
    r.company_id,
    r.code,
    r.name,
    r.description,
    r.is_active,
    r.created_at,
    lower(private.normalizar_codigo_rol(r.code)) as normalized_code,
    lower(r.code) as exact_code
  from public.roles r
),
selected_canonical_roles as (
  select
    ac.company_id,
    er.column1 as canonical_code,
    cand.id as canonical_role_id,
    cand.code as canonical_role_code,
    cand.name as canonical_role_name,
    cand.description as canonical_role_description,
    cand.is_active as canonical_role_is_active
  from active_companies ac
  cross join expected_roles er
  left join lateral (
    select r.id, r.code, r.name, r.description, r.is_active
    from roles_norm r
    where r.company_id = ac.company_id
      and r.normalized_code = er.column1
    order by
      (case when lower(r.code) = er.column1 then 0 else 1 end),
      (case when r.is_active then 0 else 1 end),
      r.created_at,
      r.id
    limit 1
  ) cand on true
),
canonical_issues as (
  select
    count(*) filter (where canonical_code = 'admin' and canonical_role_id is null) as missing_admin_canonical,
    count(*) filter (where canonical_code = 'supervisor' and canonical_role_id is null) as missing_supervisor_canonical,
    count(*) as total_missing_canonical
  from selected_canonical_roles
),
canonical_update_candidates as (
  select
    count(*) as roles_needing_canonical_update
  from selected_canonical_roles s
  where s.canonical_role_id is not null
    and (
      lower(s.canonical_role_code) <> s.canonical_code
      or s.canonical_role_name is null
      or s.canonical_role_name = ''
      or s.canonical_role_description is null
      or s.canonical_role_description = ''
      or s.canonical_role_is_active is distinct from true
    )
),
alias_roles as (
  select
    s.company_id,
    s.canonical_code,
    s.canonical_role_id,
    r.id as alias_role_id,
    r.code as alias_code,
    r.is_active as alias_is_active
  from selected_canonical_roles s
  join roles_norm r
    on r.company_id = s.company_id
   and r.normalized_code = s.canonical_code
  where s.canonical_role_id is not null
    and r.id <> s.canonical_role_id
),
alias_role_metrics as (
  select
    count(*) as alias_roles_total,
    count(*) filter (where alias_is_active) as alias_roles_active,
    count(*) filter (where alias_is_active and canonical_code = 'admin') as alias_admin_active,
    count(*) filter (where alias_is_active and canonical_code = 'supervisor') as alias_supervisor_active
  from alias_roles
),
company_role_family as (
  select
    c.id as company_id,
    count(*) filter (
      where lower(rn.normalized_code) = 'admin'
        and rn.is_active
        and lower(rn.code) = 'admin'
    ) as admin_active_exact,
    count(*) filter (
      where lower(rn.normalized_code) = 'admin'
        and rn.is_active
        and lower(rn.code) <> 'admin'
    ) as admin_active_aliases,
    count(*) filter (
      where lower(rn.normalized_code) = 'supervisor'
        and rn.is_active
        and lower(rn.code) = 'supervisor'
    ) as supervisor_active_exact,
    count(*) filter (
      where lower(rn.normalized_code) = 'supervisor'
        and rn.is_active
        and lower(rn.code) <> 'supervisor'
    ) as supervisor_active_aliases
  from public.companies c
  left join roles_norm rn on rn.company_id = c.id
  where c.status = 'active'
  group by c.id
),
company_role_family_metrics as (
  select
    count(*) filter (where admin_active_exact = 0) as companies_without_admin_exact,
    count(*) filter (where admin_active_exact > 1) as companies_with_multi_admin_exact,
    count(*) filter (where supervisor_active_exact = 0) as companies_without_supervisor_exact,
    count(*) filter (where supervisor_active_exact > 1) as companies_with_multi_supervisor_exact,
    sum(admin_active_aliases) as sum_admin_alias_active,
    sum(supervisor_active_aliases) as sum_supervisor_alias_active
  from company_role_family
),
alias_permission_rows as (
  select
    ar.canonical_code,
    ar.company_id,
    ar.canonical_role_id,
    rp.permiso_id,
    rp.permitido,
    rp.alcance
  from alias_roles ar
  join public.rol_permisos rp
    on rp.rol_id = ar.alias_role_id
),
alias_permission_distinct as (
  select
    canonical_code,
    company_id,
    canonical_role_id,
    permiso_id,
    bool_or(coalesce(permitido, false)) as permitido,
    max(alcance) as alcance
  from alias_permission_rows
  group by canonical_code, company_id, canonical_role_id, permiso_id
),
alias_permission_dups as (
  select
    canonical_role_id,
    permiso_id,
    count(*) as source_rows
  from alias_permission_rows
  group by canonical_role_id, permiso_id
  having count(*) > 1
),
alias_permission_plan as (
  select
    count(*) as source_rows,
    count(*) filter (where rp.rol_id is null) as rows_to_insert,
    count(*) filter (
      where rp.rol_id is not null
        and (rp.permitido is distinct from ap.permitido or rp.alcance is distinct from ap.alcance)
    ) as rows_to_update,
    count(*) filter (where duplicate_rows.duplicate_rows is true) as source_conflict_groups
  from alias_permission_distinct ap
  left join public.rol_permisos rp
    on rp.rol_id = ap.canonical_role_id
   and rp.permiso_id = ap.permiso_id
  left join (
    select
      canonical_role_id,
      permiso_id,
      count(*) > 1 as duplicate_rows
    from alias_permission_dups
    group by canonical_role_id, permiso_id
  ) duplicate_rows
    on duplicate_rows.canonical_role_id = ap.canonical_role_id
   and duplicate_rows.permiso_id = ap.permiso_id
),
permission_catalog as (
  select
    rp.canonical_code,
    rp.permission_code,
    rp.expected_scope,
    p.id as permission_id,
    coalesce(p.activo, false) as permission_activa
  from required_permissions rp
  left join public.permisos p
    on p.codigo = rp.permission_code
),
required_perm_stats as (
  select
    count(*) filter (where permission_id is null) as permissions_missing_in_catalog,
    count(*) as permissions_expected
  from permission_catalog
),
required_perm_targets as (
  select
    rpc.canonical_code,
    rpc.permission_code,
    rpc.expected_scope,
    rpc.permission_id,
    rpc.permission_activa,
    s.canonical_role_id
  from permission_catalog rpc
  cross join active_companies ac
  left join selected_canonical_roles s
    on s.company_id = ac.company_id
   and s.canonical_code = rpc.canonical_code
),
required_perm_plan as (
  select
    count(*) as expected_rows,
    count(*) filter (where permission_id is not null and canonical_role_id is null) as targets_missing_role,
    count(*) filter (where permission_id is null) as targets_missing_catalog,
    count(*) filter (
      where permission_id is not null
        and canonical_role_id is not null
        and rp.rol_id is null
    ) as rows_to_insert,
    count(*) filter (
      where permission_id is not null
        and canonical_role_id is not null
        and rp.rol_id is not null
        and (
          rp.permitido is distinct from true
          or coalesce(rp.alcance, '')
             is distinct from rpc.expected_scope
        )
    ) as rows_to_update,
    count(*) filter (
      where permission_id is not null
        and canonical_role_id is not null
        and rp.rol_id is not null
        and rp.permitido is true
        and rp.alcance = rpc.expected_scope
    ) as rows_already_aligned
  from required_perm_targets rpc
  left join public.rol_permisos rp
    on rp.rol_id = rpc.canonical_role_id
   and rp.permiso_id = rpc.permission_id
),
profile_scope_base as (
  select
    p.id,
    p.company_id,
    p.role_id,
    coalesce(r.normalized_code, '') as role_normalized_code,
    r.is_active as role_is_active
  from public.profiles p
  left join roles_norm r
    on r.id = p.role_id
  where p.access_deleted_at is null
),
profile_department_scope as (
  select
    b.id as profile_id,
    b.company_id,
    count(pd.perfil_id) as scope_department_rows,
    count(*) filter (
      where pd.perfil_id is not null
        and d.id is null
    ) as department_orphan_rows,
    count(*) filter (
      where pd.perfil_id is not null
        and d.company_id is not null
        and d.company_id is distinct from b.company_id
    ) as department_wrong_company_rows
  from profile_scope_base b
  left join public.perfil_departamentos pd
    on pd.perfil_id = b.id
  left join public.departments d
    on d.id = pd.departamento_id
  group by b.id, b.company_id
),
profile_branch_scope as (
  select
    b.id as profile_id,
    b.company_id,
    count(ps.perfil_id) as scope_branch_rows,
    count(*) filter (
      where ps.perfil_id is not null
        and br.id is null
    ) as branch_orphan_rows,
    count(*) filter (
      where ps.perfil_id is not null
        and br.company_id is not null
        and br.company_id is distinct from b.company_id
    ) as branch_wrong_company_rows
  from profile_scope_base b
  left join public.perfil_sucursales ps
    on ps.perfil_id = b.id
  left join public.branches br
    on br.id = ps.sucursal_id
  group by b.id, b.company_id
),
profile_scope_metrics as (
  select
    count(*) filter (
      where ((coalesce(d.scope_department_rows, 0) > 0)
             or (coalesce(br.scope_branch_rows, 0) > 0))
    ) as profiles_with_any_scope,
    count(*) filter (
      where b.role_normalized_code <> 'supervisor'
        and ((coalesce(d.scope_department_rows, 0) > 0)
             or (coalesce(br.scope_branch_rows, 0) > 0))
    ) as non_supervisor_with_scope,
    count(*) filter (
      where b.role_normalized_code = ''
        and ((coalesce(d.scope_department_rows, 0) > 0)
             or (coalesce(br.scope_branch_rows, 0) > 0))
    ) as profiles_without_role_with_scope,
    count(*) filter (
      where b.role_normalized_code = 'supervisor'
        and b.role_is_active is not distinct from true
        and coalesce(d.scope_department_rows, 0) = 0
        and coalesce(br.scope_branch_rows, 0) = 0
    ) as active_supervisor_without_scope,
    coalesce(sum(d.department_wrong_company_rows), 0) as total_department_wrong_company,
    coalesce(sum(d.department_orphan_rows), 0) as total_department_orphans,
    coalesce(sum(br.branch_wrong_company_rows), 0) as total_branch_wrong_company,
    coalesce(sum(br.branch_orphan_rows), 0) as total_branch_orphans
  from profile_scope_base b
  left join profile_department_scope d
    on d.profile_id = b.id
  left join profile_branch_scope br
    on br.profile_id = b.id
  group by ()
),
profiles_all as (
  select
    count(*) as profiles_total,
    count(*) filter (where role_id is null) as profiles_role_null,
    count(*) filter (where role_id is not null and p.role_id is not null and r.id is null) as profiles_role_missing,
    count(*) filter (
      where role_id is not null and r.company_id is not null
        and r.company_id is distinct from p.company_id
    ) as profiles_company_mismatch,
    count(*) filter (where role_id is not null and r.id is not null and r.is_active is distinct from true) as profiles_role_inactive,
    count(*) filter (where role_id is not null and ar.alias_role_id is not null) as profiles_remap_candidates
  from public.profiles p
  left join public.roles r
    on r.id = p.role_id
  left join alias_roles ar
    on ar.alias_role_id = p.role_id
),
required_objects as (
  select
    count(*) filter (where missing_schema) as missing_schemas,
    null::bigint as missing_relations,
    null::bigint as missing_columns,
    null::bigint as missing_functions,
    null::bigint as missing_unique_rol_permisos_index
  from (
    select (to_regnamespace(v.schema_name) is null) as missing_schema
    from (values ('public'::text), ('private'::text)) v(schema_name)
  ) x
),
required_relations as (
  select
    rel_name,
    (to_regclass(rel_name) is null) as missing_relation
  from (values
    ('public.companies'::text),
    ('public.roles'::text),
    ('public.profiles'::text),
    ('public.permisos'::text),
    ('public.rol_permisos'::text),
    ('public.perfil_permisos'::text),
    ('public.perfil_sucursales'::text),
    ('public.perfil_departamentos'::text),
    ('public.empleados'::text),
    ('public.departments'::text),
    ('public.branches'::text)
  ) v(rel_name)
),
required_columns as (
  select
    rel_name,
    column_name,
    (pg_attribute.attname is null) as missing_column
  from (values
    ('public.companies'::text, 'id'::text),
    ('public.companies'::text, 'status'::text),
    ('public.roles'::text, 'id'::text),
    ('public.roles'::text, 'company_id'::text),
    ('public.roles'::text, 'code'::text),
    ('public.roles'::text, 'name'::text),
    ('public.roles'::text, 'description'::text),
    ('public.roles'::text, 'is_active'::text),
    ('public.profiles'::text, 'company_id'::text),
    ('public.profiles'::text, 'role_id'::text),
    ('public.profiles'::text, 'status'::text),
    ('public.profiles'::text, 'access_deleted_at'::text),
    ('public.permisos'::text, 'id'::text),
    ('public.permisos'::text, 'codigo'::text),
    ('public.permisos'::text, 'activo'::text),
    ('public.rol_permisos'::text, 'rol_id'::text),
    ('public.rol_permisos'::text, 'permiso_id'::text),
    ('public.rol_permisos'::text, 'permitido'::text),
    ('public.rol_permisos'::text, 'alcance'::text),
    ('public.empleados'::text, 'empresa_id'::text),
    ('public.empleados'::text, 'perfil_id'::text),
    ('public.empleados'::text, 'estado_laboral'::text),
    ('public.empleados'::text, 'activo'::text),
    ('public.perfil_departamentos'::text, 'perfil_id'::text),
    ('public.perfil_departamentos'::text, 'departamento_id'::text),
    ('public.perfil_sucursales'::text, 'perfil_id'::text),
    ('public.perfil_sucursales'::text, 'sucursal_id'::text),
    ('public.departments'::text, 'id'::text),
    ('public.departments'::text, 'company_id'::text),
    ('public.departments'::text, 'branch_id'::text),
    ('public.departments'::text, 'is_active'::text),
    ('public.branches'::text, 'id'::text),
    ('public.branches'::text, 'company_id'::text),
    ('public.branches'::text, 'status'::text)
  ) v(rel_name, column_name)
  left join pg_attribute
    on pg_attribute.attrelid = (to_regclass(v.rel_name))
   and pg_attribute.attname = v.column_name
   and pg_attribute.attnum > 0
   and not pg_attribute.attisdropped
),
required_functions as (
  select
    func_schema,
    func_name,
    func_signature,
    (to_regprocedure(format('%I.%I(%s)', func_schema, func_name, func_signature)) is null) as missing_function
  from (values
    ('private'::text, 'normalizar_codigo_rol'::text, 'text'::text),
    ('public'::text, 'perfil_acceso_utilizable_internal'::text, 'uuid, uuid'::text),
    ('public'::text, 'alcance_supervisor_valido_internal'::text, 'uuid, uuid'::text),
    ('public'::text, 'tiene_permiso'::text, 'text'::text),
    ('public'::text, 'obtener_departamentos_supervisor_actual'::text, ''::text)
  ) v(func_schema, func_name, func_signature)
),
required_unique_index as (
  select exists(
    select 1
    from pg_constraint c
    where c.conrelid = 'public.rol_permisos'::regclass
      and c.contype = 'u'
      and (select a.attnum from pg_attribute a
           where a.attrelid = c.conrelid and a.attname = 'rol_id') = any(c.conkey)
      and (select a.attnum from pg_attribute a
           where a.attrelid = c.conrelid and a.attname = 'permiso_id') = any(c.conkey)
  ) or exists(
    select 1
    from pg_index i
    where i.indrelid = 'public.rol_permisos'::regclass
      and i.indisunique
      and i.indnatts = 2
      and (
        (i.indkey[0] = (select attnum from pg_attribute where attrelid = 'public.rol_permisos'::regclass and attname = 'rol_id')
         and i.indkey[1] = (select attnum from pg_attribute where attrelid = 'public.rol_permisos'::regclass and attname = 'permiso_id'))
        or (i.indkey[0] = (select attnum from pg_attribute where attrelid = 'public.rol_permisos'::regclass and attname = 'permiso_id')
            and i.indkey[1] = (select attnum from pg_attribute where attrelid = 'public.rol_permisos'::regclass and attname = 'rol_id'))
      )
  ) as has_unique_rol_permisos_pair
),
fn_tiene_permiso as (
  select
    p.oid,
    p.prosecdef,
    p.proretset,
    pg_catalog.format_type(p.prorettype, null) as return_type,
    exists (
      select 1 from unnest(coalesce(p.proconfig, array[]::text[])) x where x like 'search_path=%'
    ) as search_path_config,
    has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_execute,
    has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
    has_function_privilege('public', p.oid, 'EXECUTE') as public_execute
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'tiene_permiso'
    and pg_get_function_identity_arguments(p.oid) = 'text'
),
fn_obtener as (
  select
    p.oid,
    p.prosecdef,
    p.proretset,
    pg_catalog.format_type(p.prorettype, null) as return_type,
    exists (
      select 1 from unnest(coalesce(p.proconfig, array[]::text[])) x where x like 'search_path=%'
    ) as search_path_config,
    has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_execute,
    has_function_privilege('anon', p.oid, 'EXECUTE') as anon_execute,
    has_function_privilege('public', p.oid, 'EXECUTE') as public_execute
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'obtener_departamentos_supervisor_actual'
    and pg_get_function_identity_arguments(p.oid) = ''
),
service_role_privilege_matrix as (
  select
    srv.table_name,
    srv.privilege,
    srv.expected_effective,
    srv.severity
  from (
    select *
    from (
      values
        ('public.profiles'::text, 'SELECT'::text, true, 'CRITICAL'::text),
        ('public.profiles'::text, 'INSERT'::text, false, 'CRITICAL'::text),
        ('public.profiles'::text, 'UPDATE'::text, false, 'CRITICAL'::text),
        ('public.profiles'::text, 'DELETE'::text, false, 'CRITICAL'::text),
        ('public.profiles'::text, 'TRUNCATE'::text, false, 'CRITICAL'::text),
        ('public.profiles'::text, 'REFERENCES'::text, false, 'CRITICAL'::text),
        ('public.profiles'::text, 'TRIGGER'::text, false, 'CRITICAL'::text),
        ('public.roles'::text, 'SELECT'::text, true, 'HIGH'::text),
        ('public.roles'::text, 'INSERT'::text, false, 'HIGH'::text),
        ('public.roles'::text, 'UPDATE'::text, false, 'HIGH'::text),
        ('public.roles'::text, 'DELETE'::text, false, 'HIGH'::text),
        ('public.roles'::text, 'TRUNCATE'::text, false, 'HIGH'::text),
        ('public.roles'::text, 'REFERENCES'::text, false, 'HIGH'::text),
        ('public.roles'::text, 'TRIGGER'::text, false, 'HIGH'::text),
        ('public.empleados'::text, 'SELECT'::text, true, 'CRITICAL'::text),
        ('public.empleados'::text, 'INSERT'::text, true, 'CRITICAL'::text),
        ('public.empleados'::text, 'UPDATE'::text, true, 'CRITICAL'::text),
        ('public.empleados'::text, 'DELETE'::text, false, 'CRITICAL'::text),
        ('public.empleados'::text, 'TRUNCATE'::text, false, 'CRITICAL'::text),
        ('public.empleados'::text, 'REFERENCES'::text, false, 'CRITICAL'::text),
        ('public.empleados'::text, 'TRIGGER'::text, false, 'CRITICAL'::text),
        ('public.perfil_sucursales'::text, 'SELECT'::text, false, 'CRITICAL'::text),
        ('public.perfil_sucursales'::text, 'INSERT'::text, false, 'CRITICAL'::text),
        ('public.perfil_sucursales'::text, 'UPDATE'::text, false, 'CRITICAL'::text),
        ('public.perfil_sucursales'::text, 'DELETE'::text, false, 'CRITICAL'::text),
        ('public.perfil_sucursales'::text, 'TRUNCATE'::text, false, 'CRITICAL'::text),
        ('public.perfil_sucursales'::text, 'REFERENCES'::text, false, 'CRITICAL'::text),
        ('public.perfil_sucursales'::text, 'TRIGGER'::text, false, 'CRITICAL'::text),
        ('public.perfil_departamentos'::text, 'SELECT'::text, false, 'CRITICAL'::text),
        ('public.perfil_departamentos'::text, 'INSERT'::text, false, 'CRITICAL'::text),
        ('public.perfil_departamentos'::text, 'UPDATE'::text, false, 'CRITICAL'::text),
        ('public.perfil_departamentos'::text, 'DELETE'::text, false, 'CRITICAL'::text),
        ('public.perfil_departamentos'::text, 'TRUNCATE'::text, false, 'CRITICAL'::text),
        ('public.perfil_departamentos'::text, 'REFERENCES'::text, false, 'CRITICAL'::text),
        ('public.perfil_departamentos'::text, 'TRIGGER'::text, false, 'CRITICAL'::text)
    ) as srv(table_name, privilege, expected_effective, severity)
  ) srv
)
,
service_role_privilege_state as (
  select
    s.table_name,
    s.privilege,
    s.expected_effective,
    s.severity,
    c.oid as relation_oid,
    case when c.oid is null then false else has_table_privilege('service_role', c.oid, s.privilege) end as effective_privilege,
    case when c.oid is null then false else exists (
      select 1
      from pg_class cc
      cross join lateral aclexplode(cc.relacl) acls
      where cc.oid = c.oid
        and acls.grantee = 'service_role'::regrole
        and acls.privilege_type = s.privilege
    ) end as direct_privilege,
    case when c.oid is null then false else coalesce((
      select bool_or(coalesce(acl.is_grantable, false))
      from pg_class cc
      cross join lateral aclexplode(cc.relacl) acl
      where cc.oid = c.oid
        and acl.grantee = 'service_role'::regrole
        and acl.privilege_type = s.privilege
    ), false) end as direct_grantable,
    case when c.oid is null then false else exists (
      select 1
      from pg_class cc
      cross join lateral aclexplode(cc.relacl) acl
      where cc.oid = c.oid
        and acl.grantee = 0
        and acl.privilege_type = s.privilege
    ) end as public_privilege,
    coalesce((
      select string_agg(r.rolname, ',')
      from pg_auth_members m
      join pg_roles r on r.oid = m.roleid
      where m.member = 'service_role'::regrole
        and has_table_privilege(r.oid, c.oid, s.privilege)
    ), '') as inherited_roles
  from service_role_privilege_matrix s
  left join pg_class c
    on c.relnamespace = to_regnamespace(split_part(s.table_name, '.', 1))
   and c.relname = split_part(s.table_name, '.', 2)
   and c.relkind in ('r', 'p')
),
service_role_checks as (
  select
    count(*) filter (where relation_oid is null and expected_effective) as missing_expected_objects,
    count(*) filter (where effective_privilege is distinct from expected_effective) as effective_mismatches,
    count(*) filter (where direct_privilege is distinct from expected_effective) as direct_mismatches,
    count(*) filter (where direct_grantable) as grant_option_mismatches,
    count(*) filter (where public_privilege) as public_leak_count,
    count(*) as total_rows
  from service_role_privilege_state
),
service_role_inherited_issues as (
  select count(*) as inherited_roles_with_priv_count
  from (
    select 1
    from service_role_privilege_state s
    where coalesce(s.inherited_roles, '') <> ''
  ) x
),
raise_conditions as (
  select
    (select missing_admin_canonical > 0 from canonical_issues) as active_exact_admin_missing,
    (select missing_supervisor_canonical > 0 from canonical_issues) as active_exact_supervisor_missing,
    (select coalesce(sum(admin_active_aliases + supervisor_active_aliases), 0) > 0 from company_role_family) as role_canonical_aliases_not_targeted,
    (select not exists (select 1 from fn_tiene_permiso)) as tiene_permiso_missing,
    (select not exists (select 1 from fn_obtener)) as obtener_missing,
    (select coalesce(tiene_permiso.prosecdef,false) is distinct from true
            or coalesce(tiene_permiso.proretset,false) is distinct from false
            or coalesce(tiene_permiso.return_type,'') is distinct from 'boolean'
            or not coalesce(tiene_permiso.search_path_config,false)
            or not coalesce(tiene_permiso.auth_execute,false)
            or coalesce(tiene_permiso.anon_execute,false)
            or coalesce(tiene_permiso.public_execute,false)
     from fn_tiene_permiso tiene_permiso) as tiene_contract_mismatch,
    (select coalesce(obtener.prosecdef,false) is distinct from true
            or coalesce(obtener.proretset,false) is distinct from true
            or coalesce(obtener.return_type,'') is distinct from 'record'
            or not coalesce(obtener.search_path_config,false)
            or not coalesce(obtener.auth_execute,false)
            or coalesce(obtener.anon_execute,false)
            or coalesce(obtener.public_execute,false)
     from fn_obtener obtener) as obtener_contract_mismatch,
    (select service_role_checks.effective_mismatches > 0 from service_role_checks) as service_role_effective_mismatch,
    (select service_role_checks.direct_mismatches > 0 from service_role_checks) as service_role_direct_mismatch,
    (select service_role_checks.grant_option_mismatches > 0 from service_role_checks) as service_role_grant_option_mismatch,
    (select service_role_checks.public_leak_count > 0 from service_role_checks) as service_role_public_leak,
    (select service_role_inherited_issues.inherited_roles_with_priv_count > 0 from service_role_inherited_issues) as service_role_inherited_priv
),
required_object_summary as (
  select
    (select count(*) from required_relations where missing_relation) as missing_relations,
    (select count(*) from required_columns where missing_column) as missing_columns,
    (select count(*) from required_functions where missing_function) as missing_functions,
    (select missing_schemas from required_objects) as missing_schemas,
    (select not has_unique_rol_permisos_pair from required_unique_index) as missing_rol_permisos_unique
),
check_rows as (
  select
    'REQ01_ACTIVE_COMPANIES_SCOPE'::text as check_name,
    'PASS'::text as status,
    (select count(*)::text from active_companies) as actual_value,
    '>= 0'::text as expected_value,
    'INFO'::text as severity,
    'Confirma el alcance de compa帽铆as activas que ser谩n evaluadas por 0036.'::text as instruction
  union all
  select
    'REQ02_CANONICAL_ROLE_EXISTENCE'::text,
    case
      when (select missing_admin_canonical from canonical_issues) = 0
       and (select missing_supervisor_canonical from canonical_issues) = 0 then 'PASS'
      else 'BLOCKED'
    end,
    'missing_admin=' || (select missing_admin_canonical::text from canonical_issues) ||
      '; missing_supervisor=' || (select missing_supervisor_canonical::text from canonical_issues),
    'missing_admin=0; missing_supervisor=0',
    'CRITICAL'::text,
    'Debe existir un rol can贸nico ADMIN y SUPERVISOR por compa帽铆a activa.'
  union all
  select
    'REQ03_ROLE_ALIAS_CANONICALIZATION'::text,
    case
      when (select alias_roles_active from alias_role_metrics) = 0 then 'PASS'
      else 'BLOCKED'
    end,
    'active_alias_roles=' || (select alias_roles_active::text from alias_role_metrics) ||
      '; total_alias_roles=' || (select alias_roles_total::text from alias_role_metrics),
    'active_alias_roles=0',
    'CRITICAL'::text,
    'Los alias can贸nicos con rol activo deben resolverse y no quedarse fuera de la canonicalizaci贸n.'
  union all
  select
    'REQ04_FAMILY_EXACT_COUNT_BY_COMPANY'::text,
    case
      when (select companies_without_admin_exact from company_role_family_metrics) = 0
       and (select companies_with_multi_admin_exact from company_role_family_metrics) = 0
       and (select companies_without_supervisor_exact from company_role_family_metrics) = 0
       and (select companies_with_multi_supervisor_exact from company_role_family_metrics) = 0 then 'PASS'
      else 'BLOCKED'
    end,
    'zero_admin=' || (select companies_without_admin_exact::text from company_role_family_metrics) ||
      '; multi_admin=' || (select companies_with_multi_admin_exact::text from company_role_family_metrics) ||
      '; zero_supervisor=' || (select companies_without_supervisor_exact::text from company_role_family_metrics) ||
      '; multi_supervisor=' || (select companies_with_multi_supervisor_exact::text from company_role_family_metrics),
    'zero=0, multi=0',
    'CRITICAL'::text,
    'Validaci贸n de empresa activa con rol ADMIN/SUPERVISOR exacto.'
  union all
  select
    'REQ05_ROL_PERMISOS_ALIAS_MIGRATION'::text,
    case
      when (select source_conflict_groups from alias_permission_plan) > 0 then 'WARNING'
      else 'PASS'
    end,
    'alias_rows=' || (select source_rows::text from alias_permission_plan) ||
      '; insert=' || (select rows_to_insert::text from alias_permission_plan) ||
      '; update=' || (select rows_to_update::text from alias_permission_plan) ||
      '; conflict_groups=' || (select source_conflict_groups::text from alias_permission_plan),
    'source_conflict_groups=0 recomendado; cambios calculables por alias.',
    'HIGH'::text,
    'Se calcula seg鷑 la reconciliaci髇 de permisos definida por 0036.'
  union all
  select
    'REQ06_PROFILES_ROLE_REMAP'::text,
    case
      when (select profiles_remap_candidates::text from profiles_all) = '0' then 'PASS'
      else 'WARNING'
    end,
    'profiles_remap_candidates=' || (select profiles_remap_candidates::text from profiles_all),
    '0 (sin remapeo) o >0 con impacto previsto',
    'HIGH'::text,
    'Cantidad de perfiles cuyo role_id apunta a alias can贸nico candidato.'
  union all
  select
    'REQ07_PROFILE_ROLE_ID_ANOMALIES'::text,
    case
      when (select profiles_role_null::int from profiles_all) > 0 then 'BLOCKED'
      when (select profiles_role_missing::int from profiles_all) > 0 then 'BLOCKED'
      when (select profiles_company_mismatch::int from profiles_all) > 0 then 'BLOCKED'
      when (select profiles_role_inactive::int from profiles_all) > 0 then 'WARNING'
      else 'PASS'
    end,
    'role_null=' || (select profiles_role_null::text from profiles_all) ||
      '; role_missing=' || (select profiles_role_missing::text from profiles_all) ||
      '; company_mismatch=' || (select profiles_company_mismatch::text from profiles_all) ||
      '; role_inactive=' || (select profiles_role_inactive::text from profiles_all),
    'role_null=0; role_missing=0; company_mismatch=0 (bloqueante); role_inactive=0 preferible',
    'HIGH'::text,
    'Verifica contratos en perfiles que impactar谩 0036.'
  union all
  select
    'REQ08_PORTAL_VER_DASHBOARD_PERMISSION'::text,
    case
      when exists (select 1 from permission_catalog rpc where rpc.permission_code='portal.ver_dashboard' and rpc.permission_id is null) then 'BLOCKED'
      when exists (select 1 from permission_catalog rpc where rpc.permission_code='portal.ver_dashboard' and not rpc.permission_activa) then 'WARNING'
      else 'PASS'
    end,
    'exists=' || (not exists (select 1 from permission_catalog rpc where rpc.permission_code='portal.ver_dashboard' and rpc.permission_id is null))::text ||
      '; active=' || (coalesce((select permission_activa::text from permission_catalog rpc where rpc.permission_code='portal.ver_dashboard' limit 1), 'unknown')),
    'exists=true and activo=true',
    'CRITICAL'::text,
    'Permiso base solicitado por 0036 para objetivos de acceso supervisor.'
  union all
  select
    'REQ09_REQUIRED_PERMISSIONS_TARGET'::text,
    case
      when (select permissions_missing_in_catalog from required_perm_stats) > 0 then 'BLOCKED'
      when (select rows_to_insert + rows_to_update from required_perm_plan) = 0 then 'PASS'
      else 'WARNING'
    end,
    'required_permissions=' || (select permissions_expected::text from required_perm_stats) ||
      '; missing_catalog=' || (select permissions_missing_in_catalog::text from required_perm_stats) ||
      '; to_insert=' || (select rows_to_insert::text from required_perm_plan) ||
      '; to_update=' || (select rows_to_update::text from required_perm_plan) ||
      '; already_aligned=' || (select rows_already_aligned::text from required_perm_plan),
    'missing_catalog=0; to_insert/to_update=0 para estado ya alineado',
    'HIGH'::text,
    'Asegura que 0036 cerrar谩 las diferencias para ADMIN/SUPERVISOR.'
  union all
  select
    'REQ10_TARGET_ASSIGNMENTS_FINAL'::text,
    case
      when (select missing_admin_canonical from canonical_issues) > 0
        or (select missing_supervisor_canonical from canonical_issues) > 0 then 'BLOCKED'
      when (select rows_to_update + rows_to_insert from required_perm_plan) = 0 then 'PASS'
      else 'WARNING'
    end,
    'aligned_admin_supervisor=' || (select rows_already_aligned::text from required_perm_plan) ||
      '; pending=' || ((select rows_to_insert + rows_to_update from required_perm_plan)::text),
    'pending=0 para "ya alineado"',
    'HIGH'::text,
    'Estado esperado final de ADMIN/SUPERVISOR portal.ver_dashboard y permisos base.'
  union all
  select
    'REQ11_SERVICE_ROLE_CURRENT_PRIVILEGES'::text,
    case
      when (select effective_mismatches from service_role_checks) > 0 then 'BLOCKED'
      when (select direct_mismatches from service_role_checks) > 0 then 'BLOCKED'
      when (select grant_option_mismatches from service_role_checks) > 0 then 'BLOCKED'
      when (select public_leak_count from service_role_checks) > 0 then 'BLOCKED'
      when (select missing_expected_objects from service_role_checks) > 0 then 'BLOCKED'
      else 'PASS'
    end,
    'effective_mismatch=' || (select effective_mismatches::text from service_role_checks) ||
      '; direct_mismatch=' || (select direct_mismatches::text from service_role_checks) ||
      '; grant_option=' || (select grant_option_mismatches::text from service_role_checks) ||
      '; public=' || (select public_leak_count::text from service_role_checks),
    'todos = 0',
    'CRITICAL'::text,
    'Valida privileges de service_role frente al contrato del step final de 0036.'
  union all
  select
    'REQ12_SERVICE_ROLE_PRIVILEGE_DELTA'::text,
    case
      when (select effective_mismatches from service_role_checks) = 0
       and (select direct_mismatches from service_role_checks) = 0 then 'PASS'
      else 'WARNING'
    end,
    'to_retain=' || (select count(*)::text from service_role_privilege_state where expected_effective and effective_privilege) ||
      '; to_revoke=' || (select count(*)::text from service_role_privilege_state where not expected_effective and effective_privilege),
    'revocar lo que no cumpla expected=false; conservar expected=true',
    'MEDIUM'::text,
    'Predice cambios potenciales (sin ejecutar) sobre service_role por 0036.'
  union all
  select
    'REQ13_REQUIRED_OBJECTS'::text,
    case
      when (
        (select missing_relations from required_object_summary) > 0
        or (select missing_columns from required_object_summary) > 0
        or (select missing_functions from required_object_summary) > 0
        or (select missing_schemas from required_object_summary) > 0
        or (select missing_rol_permisos_unique from required_object_summary)
      ) then 'BLOCKED'
      else 'PASS'
    end,
    'relations=' || (select missing_relations::text from required_object_summary) ||
      '; columns=' || (select missing_columns::text from required_object_summary) ||
      '; functions=' || (select missing_functions::text from required_object_summary) ||
      '; schemas=' || (select missing_schemas::text from required_object_summary) ||
      '; rol_permisos_unique=' || (select missing_rol_permisos_unique::text from required_object_summary),
    '0 faltantes',
    'CRITICAL'::text,
    'Revisa esquemas/tablas/columnas/funciones necesarias para ejecutar 0036.'
  union all
  select
    'REQ14_FUNCTIONS_CURRENT_STATE'::text,
    case
      when (not exists (select 1 from fn_tiene_permiso)) or (not exists (select 1 from fn_obtener)) then 'BLOCKED'
      when (select coalesce(prosecdef, false) is distinct from true
             or coalesce(proretset, false) is distinct from false
             or coalesce(return_type, '') is distinct from 'boolean'
             from fn_tiene_permiso) then 'WARNING'
      when (select coalesce(prosecdef, false) is distinct from true
             or coalesce(proretset, false) is distinct from true
             or coalesce(return_type, '') is distinct from 'record'
             from fn_obtener) then 'WARNING'
      else 'PASS'
    end,
    'tiene_permiso=' || (exists (select 1 from fn_tiene_permiso))::text ||
      '; obtener=' || (exists (select 1 from fn_obtener))::text,
    'functions exist and contract-compatible',
    'HIGH'::text,
    'Estado actual de public.tiene_permiso(text) y public.obtener_departamentos_supervisor_actual().'
  union all
  select
    'REQ15_PRECHECK_RAISE_EXCEPTIONS'::text,
    case
      when (select active_exact_admin_missing from raise_conditions)
        or (select active_exact_supervisor_missing from raise_conditions)
        or (select role_canonical_aliases_not_targeted from raise_conditions)
        or (select tiene_permiso_missing from raise_conditions)
        or (select obtener_missing from raise_conditions)
        or (select tiene_contract_mismatch from raise_conditions)
        or (select obtener_contract_mismatch from raise_conditions)
        or (select service_role_effective_mismatch from raise_conditions)
        or (select service_role_direct_mismatch from raise_conditions)
        or (select service_role_grant_option_mismatch from raise_conditions)
        or (select service_role_public_leak from raise_conditions)
        or (select service_role_inherited_priv from raise_conditions) then 'BLOCKED'
      else 'PASS'
    end,
    'ACTIVE_EXACT_ADMIN=' || (select active_exact_admin_missing::text from raise_conditions) ||
      '; ACTIVE_EXACT_SUPERVISOR=' || (select active_exact_supervisor_missing::text from raise_conditions) ||
      '; ALIASES=' || (select role_canonical_aliases_not_targeted::text from raise_conditions) ||
      '; FUNC_MISMATCH=' ||
      ((select tiene_contract_mismatch::text from raise_conditions) || ',' || (select obtener_contract_mismatch::text from raise_conditions)) ||
      '; SERVICE_ROLE=' || (select service_role_effective_mismatch::text from raise_conditions),
    'todas las condiciones de bloqueo deben ser false',
    'CRITICAL'::text,
    'Simula exactamente los prechecks del bloque DO de 0036.'
  union all
  select
    'REQ16_SUPERVISOR_SCOPE_0033_0034'::text,
    case
      when (select (total_department_wrong_company + total_department_orphans + total_branch_wrong_company + total_branch_orphans + non_supervisor_with_scope + active_supervisor_without_scope + profiles_without_role_with_scope) from profile_scope_metrics) = 0 then 'PASS'
      else 'WARNING'
    end,
    'dept_wrong_company=' || (select total_department_wrong_company::text from profile_scope_metrics) ||
      '; dept_orphans=' || (select total_department_orphans::text from profile_scope_metrics) ||
      '; branch_wrong_company=' || (select total_branch_wrong_company::text from profile_scope_metrics) ||
      '; branch_orphans=' || (select total_branch_orphans::text from profile_scope_metrics) ||
      '; non_supervisor_with_scope=' || (select non_supervisor_with_scope::text from profile_scope_metrics) ||
      '; supervisor_without_scope=' || (select active_supervisor_without_scope::text from profile_scope_metrics) ||
      '; profiles_without_role_with_scope=' || (select profiles_without_role_with_scope::text from profile_scope_metrics),
    'cero o casos funcionalmente aceptados',
    'MEDIUM'::text,
    'Inconsistencias de alcance post 0033-0034 que impactan contratos 0036.'
)

select
  c.check_name,
  c.status,
  c.actual_value,
  c.expected_value,
  c.severity,
  c.instruction
from check_rows c
order by
  case c.severity
    when 'CRITICAL' then 1
    when 'HIGH' then 2
    when 'MEDIUM' then 3
    when 'LOW' then 4
    else 5
  end,
  c.check_name;

ROLLBACK;
