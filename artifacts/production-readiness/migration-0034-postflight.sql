-- Postflight de 0034. Este archivo contiene exclusivamente sentencias SELECT.
-- Ejecutar solo despues de aplicar la migracion en el entorno autorizado.

-- Columnas reales y orden fisico de las dos tablas de alcance.
select
  c.table_schema,
  c.table_name,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema = 'public'
  and c.table_name in ('perfil_sucursales', 'perfil_departamentos')
order by c.table_name, c.ordinal_position;

-- Contrato exacto de columnas que evita mezclar sucursal_id y departamento_id.
select
  expected.table_name,
  expected.expected_columns,
  coalesce(actual.actual_columns, array[]::text[]) as actual_columns,
  coalesce(actual.actual_columns = expected.expected_columns, false) as passed,
  case
    when actual.actual_columns = expected.expected_columns then 'PASS'
    else 'FAIL'
  end as status
from (values
  (
    'perfil_sucursales'::text,
    array['perfil_id', 'sucursal_id', 'created_at']::text[]
  ),
  (
    'perfil_departamentos'::text,
    array['perfil_id', 'departamento_id', 'created_at']::text[]
  )
) as expected(table_name, expected_columns)
left join (
  select
    c.table_name::text,
    pg_catalog.array_agg(c.column_name::text order by c.ordinal_position)
      as actual_columns
  from information_schema.columns c
  where c.table_schema = 'public'
    and c.table_name in ('perfil_sucursales', 'perfil_departamentos')
  group by c.table_name
) actual on actual.table_name = expected.table_name
order by expected.table_name;

-- Inventario completo de triggers instalados en ambas tablas y su funcion.
select
  table_ns.nspname as table_schema,
  table_class.relname as table_name,
  trigger_row.tgname as trigger_name,
  trigger_row.tgenabled,
  function_ns.nspname as function_schema,
  function_row.proname as function_name,
  pg_catalog.pg_get_function_identity_arguments(function_row.oid)
    as function_arguments,
  function_row.prosecdef as function_security_definer,
  pg_catalog.pg_get_triggerdef(trigger_row.oid, true) as trigger_definition
from pg_catalog.pg_trigger trigger_row
join pg_catalog.pg_class table_class
  on table_class.oid = trigger_row.tgrelid
join pg_catalog.pg_namespace table_ns
  on table_ns.oid = table_class.relnamespace
join pg_catalog.pg_proc function_row
  on function_row.oid = trigger_row.tgfoid
join pg_catalog.pg_namespace function_ns
  on function_ns.oid = function_row.pronamespace
where not trigger_row.tgisinternal
  and table_ns.nspname = 'public'
  and table_class.relname in ('perfil_sucursales', 'perfil_departamentos')
order by table_class.relname, trigger_row.tgname;

-- Triggers esperados, funcion asociada, timing y operaciones cubiertas.
select
  expected.table_name,
  expected.trigger_name,
  expected.function_signature,
  expected.timing as expected_timing,
  trigger_row.oid is not null as trigger_present,
  coalesce(trigger_row.tgenabled <> 'D', false) as trigger_enabled,
  coalesce(
    trigger_row.tgfoid = pg_catalog.to_regprocedure(expected.function_signature),
    false
  ) as expected_function_attached,
  coalesce((trigger_row.tgtype::integer & 1) = 1, false) as row_level,
  coalesce(
    case expected.timing
      when 'BEFORE' then (trigger_row.tgtype::integer & 2) = 2
      when 'AFTER' then
        (trigger_row.tgtype::integer & 2) = 0
        and (trigger_row.tgtype::integer & 64) = 0
      else false
    end,
    false
  ) as expected_timing_present,
  coalesce(
    ((trigger_row.tgtype::integer & 4) = 4) = expected.on_insert,
    false
  ) as insert_event_correct,
  coalesce(
    ((trigger_row.tgtype::integer & 16) = 16) = expected.on_update,
    false
  ) as update_event_correct,
  coalesce(
    ((trigger_row.tgtype::integer & 8) = 8) = expected.on_delete,
    false
  ) as delete_event_correct,
  case
    when trigger_row.oid is not null
      and trigger_row.tgenabled <> 'D'
      and trigger_row.tgfoid = pg_catalog.to_regprocedure(expected.function_signature)
      and (trigger_row.tgtype::integer & 1) = 1
      and case expected.timing
        when 'BEFORE' then (trigger_row.tgtype::integer & 2) = 2
        when 'AFTER' then
          (trigger_row.tgtype::integer & 2) = 0
          and (trigger_row.tgtype::integer & 64) = 0
        else false
      end
      and (((trigger_row.tgtype::integer & 4) = 4) = expected.on_insert)
      and (((trigger_row.tgtype::integer & 16) = 16) = expected.on_update)
      and (((trigger_row.tgtype::integer & 8) = 8) = expected.on_delete)
    then 'PASS'
    else 'FAIL'
  end as status
from (values
  (
    'perfil_sucursales'::text,
    'perfil_sucursales_validate_rc3'::text,
    'public.validar_alcance_supervisor()'::text,
    'BEFORE'::text,
    true,
    true,
    false
  ),
  (
    'perfil_departamentos'::text,
    'perfil_departamentos_validate_rc3'::text,
    'public.validar_alcance_supervisor()'::text,
    'BEFORE'::text,
    true,
    true,
    false
  ),
  (
    'perfil_sucursales'::text,
    'perfil_sucursales_protect_rc3'::text,
    'public.proteger_sucursal_asignada_supervisor()'::text,
    'BEFORE'::text,
    false,
    false,
    true
  ),
  (
    'perfil_sucursales'::text,
    'perfil_sucursales_audit_rc3'::text,
    'public.auditar_asignacion_supervisor()'::text,
    'AFTER'::text,
    true,
    true,
    true
  ),
  (
    'perfil_departamentos'::text,
    'perfil_departamentos_audit_rc3'::text,
    'public.auditar_asignacion_supervisor()'::text,
    'AFTER'::text,
    true,
    true,
    true
  )
) as expected(
  table_name,
  trigger_name,
  function_signature,
  timing,
  on_insert,
  on_update,
  on_delete
)
left join pg_catalog.pg_class table_class
  on table_class.relnamespace = 'public'::pg_catalog.regnamespace
 and table_class.relname = expected.table_name
left join pg_catalog.pg_trigger trigger_row
  on trigger_row.tgrelid = table_class.oid
 and trigger_row.tgname = expected.trigger_name
 and not trigger_row.tgisinternal
order by expected.table_name, expected.trigger_name;

-- Propiedades de seguridad y definicion final de la funcion corregida.
select
  expected.signature,
  function_row.oid is not null as function_present,
  pg_catalog.pg_get_userbyid(function_row.proowner) as owner_name,
  function_row.prosecdef as security_definer,
  coalesce(
    pg_catalog.array_to_string(function_row.proconfig, ','),
    ''
  ) as function_config,
  coalesce(
    exists(
      select 1
      from pg_catalog.unnest(
        coalesce(function_row.proconfig, array[]::text[])
      ) setting(value)
      where setting.value in ('search_path=', 'search_path=""')
    ),
    false
  ) as empty_fixed_search_path,
  function_row.proacl as raw_acl,
  pg_catalog.pg_get_functiondef(function_row.oid) as function_definition,
  case
    when function_row.oid is not null
      and function_row.prosecdef
      and exists(
        select 1
        from pg_catalog.unnest(
          coalesce(function_row.proconfig, array[]::text[])
        ) setting(value)
        where setting.value in ('search_path=', 'search_path=""')
      )
    then 'PASS'
    else 'FAIL'
  end as status
from (values
  ('public.auditar_asignacion_supervisor()'::text)
) as expected(signature)
left join pg_catalog.pg_proc function_row
  on function_row.oid = pg_catalog.to_regprocedure(expected.signature);

-- El cuerpo debe separar tabla y operacion antes de acceder a OLD o NEW.
select
  checks.signature,
  checks.function_present,
  checks.has_public_schema_guard,
  checks.has_branch_table_branch,
  checks.has_department_table_branch,
  checks.handles_insert,
  checks.handles_update,
  checks.handles_delete,
  checks.delete_uses_old_branch,
  checks.write_uses_new_branch,
  checks.delete_uses_old_department,
  checks.write_uses_new_department,
  checks.unsafe_cross_table_case_removed,
  checks.function_present
    and checks.has_public_schema_guard
    and checks.has_branch_table_branch
    and checks.has_department_table_branch
    and checks.handles_insert
    and checks.handles_update
    and checks.handles_delete
    and checks.delete_uses_old_branch
    and checks.write_uses_new_branch
    and checks.delete_uses_old_department
    and checks.write_uses_new_department
    and checks.unsafe_cross_table_case_removed as passed,
  case
    when checks.function_present
      and checks.has_public_schema_guard
      and checks.has_branch_table_branch
      and checks.has_department_table_branch
      and checks.handles_insert
      and checks.handles_update
      and checks.handles_delete
      and checks.delete_uses_old_branch
      and checks.write_uses_new_branch
      and checks.delete_uses_old_department
      and checks.write_uses_new_department
      and checks.unsafe_cross_table_case_removed
    then 'PASS'
    else 'FAIL'
  end as status
from (
  select
    source.signature,
    source.definition is not null as function_present,
    coalesce(source.definition ~* 'tg_table_schema\s*<>\s*''public''', false)
      as has_public_schema_guard,
    coalesce(
      source.definition ~* 'if\s+tg_table_name\s*=\s*''perfil_sucursales''',
      false
    ) as has_branch_table_branch,
    coalesce(
      source.definition ~* 'elsif\s+tg_table_name\s*=\s*''perfil_departamentos''',
      false
    ) as has_department_table_branch,
    coalesce(source.definition ~* 'tg_op\s*=\s*''INSERT''', false)
      as handles_insert,
    coalesce(source.definition ~* 'tg_op\s*=\s*''UPDATE''', false)
      as handles_update,
    coalesce(source.definition ~* 'tg_op\s*=\s*''DELETE''', false)
      as handles_delete,
    coalesce(source.definition ~* 'v_entidad\s*:=\s*old\.sucursal_id', false)
      as delete_uses_old_branch,
    coalesce(source.definition ~* 'v_entidad\s*:=\s*new\.sucursal_id', false)
      as write_uses_new_branch,
    coalesce(
      source.definition ~* 'v_entidad\s*:=\s*old\.departamento_id',
      false
    ) as delete_uses_old_department,
    coalesce(
      source.definition ~* 'v_entidad\s*:=\s*new\.departamento_id',
      false
    ) as write_uses_new_department,
    coalesce(source.definition !~* 'v_entidad\s*:=\s*case', false)
      as unsafe_cross_table_case_removed
  from (
    select
      expected.signature,
      pg_catalog.pg_get_functiondef(
        pg_catalog.to_regprocedure(expected.signature)
      ) as definition
    from (values
      ('public.auditar_asignacion_supervisor()'::text)
    ) as expected(signature)
  ) source
) checks;

-- ACL efectiva de la funcion: ningun cliente publico obtiene EXECUTE.
select
  expected.signature,
  function_row.proacl as raw_acl,
  function_row.oid is not null
    and not exists(
      select 1
      from pg_catalog.aclexplode(
        coalesce(
          function_row.proacl,
          pg_catalog.acldefault('f', function_row.proowner)
        )
      ) acl
      where acl.grantee = 0
        and acl.privilege_type = 'EXECUTE'
    ) as public_execute_denied,
  coalesce(
    not pg_catalog.has_function_privilege(
      anon_role.oid,
      function_row.oid,
      'EXECUTE'
    ),
    false
  ) as anon_execute_denied,
  coalesce(
    not pg_catalog.has_function_privilege(
      authenticated_role.oid,
      function_row.oid,
      'EXECUTE'
    ),
    false
  ) as authenticated_execute_denied,
  case
    when service_role.oid is null or function_row.oid is null then null
    else pg_catalog.has_function_privilege(
      service_role.oid,
      function_row.oid,
      'EXECUTE'
    )
  end as service_role_execute_diagnostic,
  case
    when function_row.oid is not null
      and not exists(
        select 1
        from pg_catalog.aclexplode(
          coalesce(
            function_row.proacl,
            pg_catalog.acldefault('f', function_row.proowner)
          )
        ) acl
        where acl.grantee = 0
          and acl.privilege_type = 'EXECUTE'
      )
      and anon_role.oid is not null
      and not pg_catalog.has_function_privilege(
        anon_role.oid,
        function_row.oid,
        'EXECUTE'
      )
      and authenticated_role.oid is not null
      and not pg_catalog.has_function_privilege(
        authenticated_role.oid,
        function_row.oid,
        'EXECUTE'
      )
    then 'PASS'
    else 'FAIL'
  end as status
from (values
  ('public.auditar_asignacion_supervisor()'::text)
) as expected(signature)
left join pg_catalog.pg_proc function_row
  on function_row.oid = pg_catalog.to_regprocedure(expected.signature)
left join pg_catalog.pg_roles anon_role
  on anon_role.rolname = 'anon'
left join pg_catalog.pg_roles authenticated_role
  on authenticated_role.rolname = 'authenticated'
left join pg_catalog.pg_roles service_role
  on service_role.rolname = 'service_role';

-- Detalle legible de cada entrada ACL de la funcion corregida.
select
  function_ns.nspname as function_schema,
  function_row.proname as function_name,
  case
    when acl.grantee = 0 then 'PUBLIC'
    else pg_catalog.pg_get_userbyid(acl.grantee)
  end as grantee,
  pg_catalog.pg_get_userbyid(acl.grantor) as grantor,
  acl.privilege_type,
  acl.is_grantable
from pg_catalog.pg_proc function_row
join pg_catalog.pg_namespace function_ns
  on function_ns.oid = function_row.pronamespace
cross join lateral pg_catalog.aclexplode(
  coalesce(
    function_row.proacl,
    pg_catalog.acldefault('f', function_row.proowner)
  )
) acl
where function_row.oid = pg_catalog.to_regprocedure(
  'public.auditar_asignacion_supervisor()'
)
order by grantee, acl.privilege_type;

-- RLS debe continuar habilitada en ambas tablas.
select
  expected.table_name,
  table_class.oid is not null as table_present,
  coalesce(table_class.relrowsecurity, false) as rls_enabled,
  coalesce(table_class.relforcerowsecurity, false) as rls_forced,
  case
    when table_class.oid is not null and table_class.relrowsecurity
      then 'PASS'
    else 'FAIL'
  end as status
from (values
  ('perfil_sucursales'::text),
  ('perfil_departamentos'::text)
) as expected(table_name)
left join pg_catalog.pg_class table_class
  on table_class.relnamespace = 'public'::pg_catalog.regnamespace
 and table_class.relname = expected.table_name
order by expected.table_name;

-- Policies actuales y fingerprint para comparar con la preimagen.
select
  policy_row.tablename,
  policy_row.policyname,
  policy_row.permissive,
  policy_row.roles,
  policy_row.cmd,
  policy_row.qual,
  policy_row.with_check,
  pg_catalog.md5(
    coalesce(policy_row.permissive, '') || '|' ||
    coalesce(pg_catalog.array_to_string(policy_row.roles, ','), '') || '|' ||
    coalesce(policy_row.cmd, '') || '|' ||
    coalesce(policy_row.qual, '') || '|' ||
    coalesce(policy_row.with_check, '')
  ) as definition_fingerprint
from pg_catalog.pg_policies policy_row
where policy_row.schemaname = 'public'
  and policy_row.tablename in ('perfil_sucursales', 'perfil_departamentos')
order by policy_row.tablename, policy_row.policyname;

-- Las policies esperadas siguen presentes; 0034 no crea ni reemplaza policies.
select
  expected.table_name,
  expected.policy_name,
  policy_row.policyname is not null as present,
  case when policy_row.policyname is not null then 'PASS' else 'FAIL' end
    as status
from (values
  ('perfil_sucursales'::text, 'perfil_sucursales_select'::text),
  ('perfil_sucursales'::text, 'perfil_sucursales_manage'::text),
  ('perfil_departamentos'::text, 'perfil_departamentos_select'::text),
  ('perfil_departamentos'::text, 'perfil_departamentos_manage'::text)
) as expected(table_name, policy_name)
left join pg_catalog.pg_policies policy_row
  on policy_row.schemaname = 'public'
 and policy_row.tablename = expected.table_name
 and policy_row.policyname = expected.policy_name
order by expected.table_name, expected.policy_name;

-- Privilegios efectivos de clientes sobre las tablas de alcance.
select
  expected.table_name,
  pg_catalog.has_table_privilege(
    'authenticated',
    'public.' || expected.table_name,
    'SELECT'
  ) as authenticated_select,
  pg_catalog.has_table_privilege(
    'authenticated',
    'public.' || expected.table_name,
    'INSERT'
  ) as authenticated_insert,
  pg_catalog.has_table_privilege(
    'authenticated',
    'public.' || expected.table_name,
    'UPDATE'
  ) as authenticated_update,
  pg_catalog.has_table_privilege(
    'authenticated',
    'public.' || expected.table_name,
    'DELETE'
  ) as authenticated_delete,
  pg_catalog.has_table_privilege(
    'anon',
    'public.' || expected.table_name,
    'SELECT'
  ) as anon_select,
  pg_catalog.has_table_privilege(
    'anon',
    'public.' || expected.table_name,
    'INSERT'
  ) as anon_insert,
  pg_catalog.has_table_privilege(
    'anon',
    'public.' || expected.table_name,
    'UPDATE'
  ) as anon_update,
  pg_catalog.has_table_privilege(
    'anon',
    'public.' || expected.table_name,
    'DELETE'
  ) as anon_delete,
  case
    when pg_catalog.has_table_privilege(
      'authenticated',
      'public.' || expected.table_name,
      'SELECT'
    )
      and not pg_catalog.has_table_privilege(
        'authenticated',
        'public.' || expected.table_name,
        'INSERT, UPDATE, DELETE'
      )
      and not pg_catalog.has_table_privilege(
        'anon',
        'public.' || expected.table_name,
        'INSERT, UPDATE, DELETE'
      )
    then 'PASS'
    else 'FAIL'
  end as status
from (values
  ('perfil_sucursales'::text),
  ('perfil_departamentos'::text)
) as expected(table_name)
order by expected.table_name;

-- Visibilidad diagnostica de privilegios service_role; 0034 no los modifica.
select
  expected.table_name,
  pg_catalog.has_table_privilege(
    'service_role',
    'public.' || expected.table_name,
    'SELECT'
  ) as service_role_select,
  pg_catalog.has_table_privilege(
    'service_role',
    'public.' || expected.table_name,
    'INSERT'
  ) as service_role_insert,
  pg_catalog.has_table_privilege(
    'service_role',
    'public.' || expected.table_name,
    'UPDATE'
  ) as service_role_update,
  pg_catalog.has_table_privilege(
    'service_role',
    'public.' || expected.table_name,
    'DELETE'
  ) as service_role_delete
from (values
  ('perfil_sucursales'::text),
  ('perfil_departamentos'::text)
) as expected(table_name)
order by expected.table_name;
