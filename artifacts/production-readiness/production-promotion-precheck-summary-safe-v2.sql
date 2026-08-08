-- CONTROLHORARIO - resumen del precheck previo a 0030-0036.
-- Una sola consulta, sin invocar funciones de negocio ni exponer identificadores.
-- Las tablas base fueron demostradas por el precheck detallado ya ejecutado. Los
-- objetos futuros y el historial se inspeccionan de forma tolerante por catalogo.

with
severity_order(severity, severity_rank) as (
  values
    ('CRITICAL'::text, 1),
    ('HIGH'::text, 2),
    ('MEDIUM'::text, 3),
    ('INFO'::text, 4),
    ('SUMMARY'::text, 5)
),
expected_schemas(schema_name) as (
  values ('auth'::text), ('private'::text), ('public'::text),
    ('supabase_migrations'::text)
),
schema_state as (
  select
    e.schema_name,
    n.oid is not null as schema_exists
  from expected_schemas e
  left join pg_catalog.pg_namespace n on n.nspname = e.schema_name
),
expected_relations(schema_name, relation_name) as (
  values
    ('auth'::text, 'users'::text),
    ('public', 'companies'),
    ('public', 'profiles'),
    ('public', 'roles'),
    ('public', 'branches'),
    ('public', 'departments'),
    ('public', 'empleados'),
    ('public', 'permisos'),
    ('public', 'rol_permisos'),
    ('public', 'perfil_permisos'),
    ('public', 'perfil_sucursales'),
    ('public', 'perfil_departamentos'),
    ('public', 'user_provisioning_audit'),
    ('public', 'administracion_auditoria'),
    ('public', 'supervisor_auditoria')
),
relation_state as (
  select
    e.schema_name,
    e.relation_name,
    c.oid as relation_oid,
    c.relkind,
    c.relacl,
    c.relowner,
    c.relrowsecurity,
    c.relforcerowsecurity
  from expected_relations e
  left join pg_catalog.pg_namespace n on n.nspname = e.schema_name
  left join pg_catalog.pg_class c
    on c.relnamespace = n.oid
   and c.relname = e.relation_name
   and c.relkind in ('r', 'p')
),
expected_columns(schema_name, relation_name, column_name, expected_type) as (
  values
    ('auth'::text, 'users'::text, 'id'::text, 'uuid'::text),
    ('auth', 'users', 'email', 'textlike'),
    ('auth', 'users', 'raw_user_meta_data', 'jsonb'),
    ('auth', 'users', 'last_sign_in_at', 'timestamp with time zone'),
    ('public', 'companies', 'id', 'uuid'),
    ('public', 'companies', 'status', 'textlike'),
    ('public', 'profiles', 'id', 'uuid'),
    ('public', 'profiles', 'company_id', 'uuid'),
    ('public', 'profiles', 'role_id', 'uuid'),
    ('public', 'profiles', 'branch_id', 'uuid'),
    ('public', 'profiles', 'department_id', 'uuid'),
    ('public', 'profiles', 'employee_code', 'textlike'),
    ('public', 'profiles', 'full_name', 'textlike'),
    ('public', 'profiles', 'status', 'textlike'),
    ('public', 'profiles', 'access_deleted_at', 'timestamp with time zone'),
    ('public', 'profiles', 'updated_at', 'timestamp with time zone'),
    ('public', 'roles', 'id', 'uuid'),
    ('public', 'roles', 'company_id', 'uuid'),
    ('public', 'roles', 'name', 'textlike'),
    ('public', 'roles', 'code', 'textlike'),
    ('public', 'roles', 'is_active', 'boolean'),
    ('public', 'branches', 'id', 'uuid'),
    ('public', 'branches', 'company_id', 'uuid'),
    ('public', 'branches', 'name', 'textlike'),
    ('public', 'branches', 'code', 'textlike'),
    ('public', 'branches', 'status', 'textlike'),
    ('public', 'departments', 'id', 'uuid'),
    ('public', 'departments', 'company_id', 'uuid'),
    ('public', 'departments', 'branch_id', 'uuid'),
    ('public', 'departments', 'name', 'textlike'),
    ('public', 'departments', 'code', 'textlike'),
    ('public', 'departments', 'description', 'textlike'),
    ('public', 'departments', 'is_active', 'boolean'),
    ('public', 'departments', 'updated_at', 'timestamp with time zone'),
    ('public', 'empleados', 'id', 'uuid'),
    ('public', 'empleados', 'empresa_id', 'uuid'),
    ('public', 'empleados', 'perfil_id', 'uuid'),
    ('public', 'empleados', 'sucursal_id', 'uuid'),
    ('public', 'empleados', 'departamento_id', 'uuid'),
    ('public', 'empleados', 'puesto_id', 'uuid'),
    ('public', 'empleados', 'codigo_empleado', 'textlike'),
    ('public', 'empleados', 'nombre_completo', 'textlike'),
    ('public', 'empleados', 'telefono', 'textlike'),
    ('public', 'empleados', 'estado_laboral', 'textlike'),
    ('public', 'empleados', 'activo', 'boolean'),
    ('public', 'empleados', 'updated_at', 'timestamp with time zone'),
    ('public', 'permisos', 'id', 'uuid'),
    ('public', 'permisos', 'codigo', 'textlike'),
    ('public', 'permisos', 'nombre', 'textlike'),
    ('public', 'permisos', 'descripcion', 'textlike'),
    ('public', 'permisos', 'modulo', 'textlike'),
    ('public', 'permisos', 'activo', 'boolean'),
    ('public', 'rol_permisos', 'rol_id', 'uuid'),
    ('public', 'rol_permisos', 'permiso_id', 'uuid'),
    ('public', 'rol_permisos', 'permitido', 'boolean'),
    ('public', 'rol_permisos', 'alcance', 'textlike'),
    ('public', 'perfil_permisos', 'perfil_id', 'uuid'),
    ('public', 'perfil_permisos', 'permiso_id', 'uuid'),
    ('public', 'perfil_permisos', 'permitido', 'boolean'),
    ('public', 'perfil_permisos', 'alcance', 'textlike'),
    ('public', 'perfil_sucursales', 'perfil_id', 'uuid'),
    ('public', 'perfil_sucursales', 'sucursal_id', 'uuid'),
    ('public', 'perfil_departamentos', 'perfil_id', 'uuid'),
    ('public', 'perfil_departamentos', 'departamento_id', 'uuid'),
    ('public', 'user_provisioning_audit', 'id', 'uuid'),
    ('public', 'user_provisioning_audit', 'company_id', 'uuid'),
    ('public', 'user_provisioning_audit', 'actor_user_id', 'uuid'),
    ('public', 'user_provisioning_audit', 'target_user_id_snapshot', 'uuid'),
    ('public', 'user_provisioning_audit', 'employee_id', 'uuid'),
    ('public', 'user_provisioning_audit', 'role_id', 'uuid'),
    ('public', 'user_provisioning_audit', 'action', 'textlike'),
    ('public', 'user_provisioning_audit', 'details', 'jsonb'),
    ('public', 'administracion_auditoria', 'id', 'bigint'),
    ('public', 'administracion_auditoria', 'empresa_id', 'uuid'),
    ('public', 'administracion_auditoria', 'actor_id', 'uuid'),
    ('public', 'administracion_auditoria', 'seccion', 'textlike'),
    ('public', 'administracion_auditoria', 'accion', 'textlike'),
    ('public', 'administracion_auditoria', 'entidad', 'textlike'),
    ('public', 'administracion_auditoria', 'entidad_id', 'textlike'),
    ('public', 'administracion_auditoria', 'antes', 'jsonb'),
    ('public', 'administracion_auditoria', 'despues', 'jsonb'),
    ('public', 'administracion_auditoria', 'motivo', 'textlike'),
    ('public', 'supervisor_auditoria', 'empresa_id', 'uuid'),
    ('public', 'supervisor_auditoria', 'actor_id', 'uuid'),
    ('public', 'supervisor_auditoria', 'actor_rol', 'textlike'),
    ('public', 'supervisor_auditoria', 'entidad', 'textlike'),
    ('public', 'supervisor_auditoria', 'entidad_id', 'uuid'),
    ('public', 'supervisor_auditoria', 'accion', 'textlike'),
    ('public', 'supervisor_auditoria', 'antes', 'jsonb'),
    ('public', 'supervisor_auditoria', 'despues', 'jsonb'),
    ('public', 'supervisor_auditoria', 'motivo', 'textlike')
),
column_state as (
  select
    e.schema_name,
    e.relation_name,
    e.column_name,
    e.expected_type,
    case
      when a.attname is null then null::text
      else pg_catalog.format_type(a.atttypid, a.atttypmod)
    end as actual_type,
    a.attname is not null
      and case
        when e.expected_type = 'textlike' then
          pg_catalog.format_type(a.atttypid, a.atttypmod) = 'text'
          or pg_catalog.format_type(a.atttypid, a.atttypmod)
            like 'character varying%'
          or pg_catalog.format_type(a.atttypid, a.atttypmod)
            like 'character%'
        else pg_catalog.format_type(a.atttypid, a.atttypmod) = e.expected_type
      end as column_matches
  from expected_columns e
  left join pg_catalog.pg_namespace n on n.nspname = e.schema_name
  left join pg_catalog.pg_class c
    on c.relnamespace = n.oid
   and c.relname = e.relation_name
   and c.relkind in ('r', 'p')
  left join pg_catalog.pg_attribute a
    on a.attrelid = c.oid
   and a.attname = e.column_name
   and a.attnum > 0
   and not a.attisdropped
),
expected_constraints(
  relation_name,
  constraint_name,
  constraint_type,
  local_columns,
  referenced_relation,
  definition_fragment
) as (
  values
    ('profiles'::text, 'profiles_pkey'::text, 'p'::text,
      'id'::text, null::text, null::text),
    ('profiles', 'profiles_id_fkey', 'f', 'id', 'auth.users', null),
    ('profiles', 'profiles_company_id_fkey', 'f',
      'company_id', 'public.companies', null),
    ('profiles', 'profiles_company_id_id_unique', 'u',
      'company_id,id', null, null),
    ('profiles', 'profiles_role_same_company_fk', 'f',
      'company_id,role_id', 'public.roles', null),
    ('profiles', 'profiles_branch_same_company_fk', 'f',
      'company_id,branch_id', 'public.branches', null),
    ('profiles', 'profiles_department_same_company_fk', 'f',
      'company_id,department_id', 'public.departments', null),
    ('roles', 'roles_company_code_unique', 'u',
      'company_id,code', null, null),
    ('roles', 'roles_company_id_fkey', 'f',
      'company_id', 'public.companies', null),
    ('roles', 'roles_company_id_id_unique', 'u',
      'company_id,id', null, null),
    ('branches', 'branches_company_id_id_unique', 'u',
      'company_id,id', null, null),
    ('branches', 'branches_company_id_fkey', 'f',
      'company_id', 'public.companies', null),
    ('departments', 'departments_company_id_id_unique', 'u',
      'company_id,id', null, null),
    ('departments', 'departments_company_id_fkey', 'f',
      'company_id', 'public.companies', null),
    ('departments', 'departments_branch_same_company_fk', 'f',
      'company_id,branch_id', 'public.branches', null),
    ('empleados', 'empleados_perfil_id_key', 'u',
      'perfil_id', null, null),
    ('empleados', 'empleados_empresa_id_fkey', 'f',
      'empresa_id', 'public.companies', null),
    ('empleados', 'empleados_empresa_codigo_unique', 'u',
      'empresa_id,codigo_empleado', null, null),
    ('empleados', 'empleados_empresa_id_id_unique', 'u',
      'empresa_id,id', null, null),
    ('empleados', 'empleados_perfil_misma_empresa_fk', 'f',
      'empresa_id,perfil_id', 'public.profiles', null),
    ('empleados', 'empleados_sucursal_misma_empresa_fk', 'f',
      'empresa_id,sucursal_id', 'public.branches', null),
    ('empleados', 'empleados_departamento_misma_empresa_fk', 'f',
      'empresa_id,departamento_id', 'public.departments', null),
    ('permisos', 'permisos_codigo_key', 'u', 'codigo', null, null),
    ('permisos', 'permisos_codigo_formato', 'c', 'codigo', null, null),
    ('permisos', 'permisos_modulo_formato', 'c', 'modulo', null, null),
    ('rol_permisos', 'rol_permisos_pkey', 'p',
      'rol_id,permiso_id', null, null),
    ('rol_permisos', 'rol_permisos_rol_id_fkey', 'f',
      'rol_id', 'public.roles', null),
    ('rol_permisos', 'rol_permisos_permiso_id_fkey', 'f',
      'permiso_id', 'public.permisos', null),
    ('rol_permisos', 'rol_permisos_alcance_check', 'c',
      'alcance', null, 'empresa'),
    ('perfil_permisos', 'perfil_permisos_pkey', 'p',
      'perfil_id,permiso_id', null, null),
    ('perfil_permisos', 'perfil_permisos_perfil_id_fkey', 'f',
      'perfil_id', 'public.profiles', null),
    ('perfil_permisos', 'perfil_permisos_permiso_id_fkey', 'f',
      'permiso_id', 'public.permisos', null),
    ('perfil_permisos', 'perfil_permisos_alcance_check', 'c',
      'alcance', null, 'empresa'),
    ('perfil_sucursales', 'perfil_sucursales_pkey', 'p',
      'perfil_id,sucursal_id', null, null),
    ('perfil_sucursales', 'perfil_sucursales_perfil_id_fkey', 'f',
      'perfil_id', 'public.profiles', null),
    ('perfil_sucursales', 'perfil_sucursales_sucursal_id_fkey', 'f',
      'sucursal_id', 'public.branches', null),
    ('perfil_departamentos', 'perfil_departamentos_pkey', 'p',
      'perfil_id,departamento_id', null, null),
    ('perfil_departamentos', 'perfil_departamentos_perfil_id_fkey', 'f',
      'perfil_id', 'public.profiles', null),
    ('perfil_departamentos', 'perfil_departamentos_departamento_id_fkey', 'f',
      'departamento_id', 'public.departments', null)
),
expected_fk_references(constraint_name, referenced_columns) as (
  values
    ('profiles_id_fkey'::text, 'id'::text),
    ('profiles_company_id_fkey', 'id'),
    ('profiles_role_same_company_fk', 'company_id,id'),
    ('profiles_branch_same_company_fk', 'company_id,id'),
    ('profiles_department_same_company_fk', 'company_id,id'),
    ('roles_company_id_fkey', 'id'),
    ('branches_company_id_fkey', 'id'),
    ('departments_company_id_fkey', 'id'),
    ('departments_branch_same_company_fk', 'company_id,id'),
    ('empleados_empresa_id_fkey', 'id'),
    ('empleados_perfil_misma_empresa_fk', 'company_id,id'),
    ('empleados_sucursal_misma_empresa_fk', 'company_id,id'),
    ('empleados_departamento_misma_empresa_fk', 'company_id,id'),
    ('rol_permisos_rol_id_fkey', 'id'),
    ('rol_permisos_permiso_id_fkey', 'id'),
    ('perfil_permisos_perfil_id_fkey', 'id'),
    ('perfil_permisos_permiso_id_fkey', 'id'),
    ('perfil_sucursales_perfil_id_fkey', 'id'),
    ('perfil_sucursales_sucursal_id_fkey', 'id'),
    ('perfil_departamentos_perfil_id_fkey', 'id'),
    ('perfil_departamentos_departamento_id_fkey', 'id')
),
constraint_state as (
  select
    e.relation_name,
    e.constraint_name,
    e.constraint_type,
    e.local_columns,
    e.referenced_relation,
    e.definition_fragment,
    fk.referenced_columns as expected_referenced_columns,
    c.convalidated,
    actual.local_columns as actual_local_columns,
    actual_reference.referenced_columns as actual_referenced_columns,
    case
      when c.oid is null then null::text
      else pg_catalog.pg_get_constraintdef(c.oid, true)
    end as actual_definition,
    c.oid is not null
      and c.contype::text = e.constraint_type
      and c.convalidated
      and actual.local_columns = e.local_columns
      and (
        e.referenced_relation is null
        or c.confrelid = pg_catalog.to_regclass(e.referenced_relation)
      )
      and (
        fk.referenced_columns is null
        or actual_reference.referenced_columns = fk.referenced_columns
      )
      and (
        e.definition_fragment is null
        or pg_catalog.strpos(
          pg_catalog.lower(pg_catalog.pg_get_constraintdef(c.oid, true)),
          pg_catalog.lower(e.definition_fragment)
        ) > 0
      ) as matches
  from expected_constraints e
  left join expected_fk_references fk
    on fk.constraint_name = e.constraint_name
  left join pg_catalog.pg_namespace n on n.nspname = 'public'
  left join pg_catalog.pg_class t
    on t.relnamespace = n.oid
   and t.relname = e.relation_name
  left join pg_catalog.pg_constraint c
    on c.conrelid = t.oid
   and c.conname = e.constraint_name
  left join lateral (
    select pg_catalog.string_agg(
      a.attname, ',' order by key_column.ordinality
    ) as local_columns
    from pg_catalog.unnest(c.conkey)
      with ordinality as key_column(attnum, ordinality)
    join pg_catalog.pg_attribute a
      on a.attrelid = c.conrelid and a.attnum = key_column.attnum
  ) actual on true
  left join lateral (
    select pg_catalog.string_agg(
      a.attname, ',' order by referenced_column.ordinality
    ) as referenced_columns
    from pg_catalog.unnest(c.confkey)
      with ordinality as referenced_column(attnum, ordinality)
    join pg_catalog.pg_attribute a
      on a.attrelid = c.confrelid and a.attnum = referenced_column.attnum
  ) actual_reference on true
),
required_functions(signature) as (
  values
    ('private.normalizar_codigo_rol(text)'::text),
    ('public.actor_puede_administrar_accesos_internal(uuid,uuid,text[])'),
    ('public.perfil_acceso_utilizable_internal(uuid,uuid)'),
    ('public.crear_acceso_internal(jsonb)'),
    ('public.actualizar_acceso_autorizacion_internal(jsonb)'),
    ('public.obtener_acceso_internal(jsonb)'),
    ('public.cambiar_estado_acceso_internal(jsonb)'),
    ('public.tiene_permiso(text)'),
    ('public.administracion_autorizada(text)'),
    ('public.limpiar_autorizacion_por_cambio_rol()'),
    ('public.listar_accesos_internal(jsonb)'),
    ('public.validar_alcance_supervisor()'),
    ('public.proteger_sucursal_asignada_supervisor()'),
    ('public.validar_cambio_sucursal_supervisor()'),
    ('public.obtener_departamentos_supervisor_actual()'),
    ('public.supervisor_puede_ver_empleado(uuid)'),
    ('public.obtener_mi_autorizacion()'),
    ('public.guardar_departamento_administracion(uuid,jsonb,uuid,text)'),
    ('public.auditar_asignacion_supervisor()'),
    ('public.set_user_provisioning_target_snapshot()'),
    ('public.registrar_operacion_acceso_internal(jsonb)'),
    ('public.eliminar_acceso_internal(jsonb)'),
    ('public.bootstrap_tenant_internal(jsonb)'),
    ('public.provision_user_internal(jsonb)'),
    ('public.preview_next_employee_code_internal(uuid)'),
    ('public.allocate_next_employee_code_internal(uuid,uuid)'),
    ('public.actualizar_auth_sync_ciclo_empleado_internal(uuid,bigint,text,text[],text)'),
    ('public.finalizar_reactivacion_acceso_internal(uuid,bigint)'),
    ('public.desvincular_empleado(uuid,date,text,text)'),
    ('public.reactivar_empleado(uuid,text)')
),
required_function_state as (
  select
    f.signature,
    pg_catalog.to_regprocedure(f.signature) is not null as function_exists
  from required_functions f
),
required_function_contracts(
  signature,
  expected_return,
  expected_set,
  expected_security_definer
) as (
  values
    ('private.normalizar_codigo_rol(text)'::text, 'text'::text, false, false),
    ('public.actor_puede_administrar_accesos_internal(uuid,uuid,text[])',
      'boolean', false, true),
    ('public.perfil_acceso_utilizable_internal(uuid,uuid)',
      'boolean', false, true),
    ('public.crear_acceso_internal(jsonb)', 'public.profiles', false, true),
    ('public.actualizar_acceso_autorizacion_internal(jsonb)',
      'public.profiles', false, true),
    ('public.obtener_acceso_internal(jsonb)', 'jsonb', false, true),
    ('public.cambiar_estado_acceso_internal(jsonb)',
      'public.profiles', false, true),
    ('public.tiene_permiso(text)', 'boolean', false, true),
    ('public.administracion_autorizada(text)', 'uuid', false, true),
    ('public.limpiar_autorizacion_por_cambio_rol()', 'trigger', false, true),
    ('public.listar_accesos_internal(jsonb)', 'jsonb', false, true),
    ('public.validar_alcance_supervisor()', 'trigger', false, true),
    ('public.proteger_sucursal_asignada_supervisor()', 'trigger', false, true),
    ('public.validar_cambio_sucursal_supervisor()', 'trigger', false, true),
    ('public.obtener_departamentos_supervisor_actual()', 'record', true, true),
    ('public.supervisor_puede_ver_empleado(uuid)', 'boolean', false, true),
    ('public.obtener_mi_autorizacion()', 'jsonb', false, true),
    ('public.guardar_departamento_administracion(uuid,jsonb,uuid,text)',
      'uuid', false, true),
    ('public.auditar_asignacion_supervisor()', 'trigger', false, true),
    ('public.set_user_provisioning_target_snapshot()', 'trigger', false, false)
),
required_function_contract_state as (
  select
    e.signature,
    p.oid is not null
      and p.prorettype = pg_catalog.to_regtype(e.expected_return)
      and p.proretset = e.expected_set
      and p.prosecdef = e.expected_security_definer
      and exists (
        select 1
        from pg_catalog.unnest(coalesce(p.proconfig, array[]::text[])) cfg(value)
        where cfg.value in ('search_path=', 'search_path=""')
      ) as contract_matches
  from required_function_contracts e
  left join pg_catalog.pg_proc p
    on p.oid = pg_catalog.to_regprocedure(e.signature)
),
tracked_function_counts(function_schema, function_name, expected_count) as (
  values
    ('private'::text, 'normalizar_codigo_rol'::text, 1),
    ('public', 'listar_accesos_internal', 1),
    ('public', 'validar_alcance_supervisor', 1),
    ('public', 'proteger_sucursal_asignada_supervisor', 1),
    ('public', 'validar_cambio_sucursal_supervisor', 1),
    ('public', 'obtener_departamentos_supervisor_actual', 1),
    ('public', 'supervisor_puede_ver_empleado', 1),
    ('public', 'obtener_mi_autorizacion', 1),
    ('public', 'guardar_departamento_administracion', 1),
    ('public', 'obtener_empresa_actor_activo_internal', 0),
    ('public', 'alcance_supervisor_valido_internal', 0),
    ('public', 'guardar_alcance_supervisor_internal', 0),
    ('public', 'obtener_alcance_supervisor_internal', 0),
    ('public', 'crear_acceso_con_alcance_internal', 0),
    ('public', 'obtener_creacion_acceso_idempotente_internal', 0),
    ('public', 'actualizar_acceso_con_alcance_internal', 0),
    ('public', 'obtener_actualizacion_acceso_confirmada_internal', 0),
    ('public', 'cambiar_estado_acceso_con_alcance_internal', 0),
    ('public', 'auditar_asignacion_supervisor', 1)
),
function_count_state as (
  select
    e.function_schema,
    e.function_name,
    e.expected_count,
    count(p.oid)::integer as actual_count
  from tracked_function_counts e
  left join pg_catalog.pg_namespace n on n.nspname = e.function_schema
  left join pg_catalog.pg_proc p
    on p.pronamespace = n.oid and p.proname = e.function_name
  group by e.function_schema, e.function_name, e.expected_count
),
required_function_fingerprint as (
  select
    count(*) filter (where p.oid is not null)::bigint as function_count,
    pg_catalog.md5(
      coalesce(
        pg_catalog.string_agg(
          f.signature || ':' || pg_catalog.md5(
            pg_catalog.pg_get_functiondef(p.oid)
          ),
          E'\n' order by f.signature
        ) filter (where p.oid is not null),
        ''
      )
    ) as fingerprint
  from required_functions f
  left join pg_catalog.pg_proc p
    on p.oid = pg_catalog.to_regprocedure(f.signature)
),
required_execute(signature, role_name) as (
  values
    ('public.bootstrap_tenant_internal(jsonb)'::text, 'service_role'::text),
    ('public.provision_user_internal(jsonb)', 'service_role'),
    ('public.crear_acceso_internal(jsonb)', 'service_role'),
    ('public.actualizar_acceso_autorizacion_internal(jsonb)', 'service_role'),
    ('public.obtener_acceso_internal(jsonb)', 'service_role'),
    ('public.cambiar_estado_acceso_internal(jsonb)', 'service_role'),
    ('public.registrar_operacion_acceso_internal(jsonb)', 'service_role'),
    ('public.eliminar_acceso_internal(jsonb)', 'service_role'),
    ('public.listar_accesos_internal(jsonb)', 'service_role'),
    ('public.preview_next_employee_code_internal(uuid)', 'service_role'),
    ('public.allocate_next_employee_code_internal(uuid,uuid)', 'service_role'),
    ('public.actualizar_auth_sync_ciclo_empleado_internal(uuid,bigint,text,text[],text)',
      'service_role'),
    ('public.finalizar_reactivacion_acceso_internal(uuid,bigint)', 'service_role'),
    ('public.tiene_permiso(text)', 'authenticated'),
    ('public.desvincular_empleado(uuid,date,text,text)', 'authenticated'),
    ('public.reactivar_empleado(uuid,text)', 'authenticated'),
    ('public.obtener_departamentos_supervisor_actual()', 'authenticated'),
    ('public.supervisor_puede_ver_empleado(uuid)', 'authenticated'),
    ('public.obtener_mi_autorizacion()', 'authenticated')
),
execute_state as (
  select
    e.signature,
    e.role_name,
    p.oid is not null
      and r.oid is not null
      and pg_catalog.has_function_privilege(
        r.oid,
        p.oid,
        (chr(69)||chr(88)||chr(69)||chr(67)||chr(85)||chr(84)||chr(69))
      )
      as executable,
    p.oid is not null
      and r.oid is not null
      and exists (
        select 1
        from pg_catalog.aclexplode(p.proacl) acl
        where acl.grantee = r.oid
          and pg_catalog.upper(acl.privilege_type) = (chr(69)||chr(88)||chr(69)||chr(67)||chr(85)||chr(84)||chr(69))
      ) as direct_grant,
    p.oid is not null
      and exists (
        select 1
        from pg_catalog.aclexplode(
          coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
        ) acl
        where acl.grantee = 0
          and pg_catalog.upper(acl.privilege_type) = (chr(69)||chr(88)||chr(69)||chr(67)||chr(85)||chr(84)||chr(69))
      ) as public_execute,
    p.oid is not null
    and anon_role.oid is not null
    and pg_catalog.has_function_privilege(
      anon_role.oid,
      p.oid,
      (chr(69)||chr(88)||chr(69)||chr(67)||chr(85)||chr(84)||chr(69))
    ) as anon_execute
  from required_execute e
  left join pg_catalog.pg_proc p
    on p.oid = pg_catalog.to_regprocedure(e.signature)
  left join pg_catalog.pg_roles r on r.rolname = e.role_name
  left join pg_catalog.pg_roles anon_role on anon_role.rolname = 'anon'
),
future_functions(signature) as (
  values
    ('public.obtener_empresa_actor_activo_internal(uuid)'::text),
    ('public.alcance_supervisor_valido_internal(uuid,uuid)'),
    ('public.guardar_alcance_supervisor_internal(jsonb)'),
    ('public.obtener_alcance_supervisor_internal(jsonb)'),
    ('public.crear_acceso_con_alcance_internal(jsonb)'),
    ('public.obtener_creacion_acceso_idempotente_internal(jsonb)'),
    ('public.actualizar_acceso_con_alcance_internal(jsonb)'),
    ('public.obtener_actualizacion_acceso_confirmada_internal(jsonb)'),
    ('public.cambiar_estado_acceso_con_alcance_internal(jsonb)')
),
future_function_state as (
  select
    f.signature,
    pg_catalog.to_regprocedure(f.signature) is not null as function_exists
  from future_functions f
),
future_indexes(index_name) as (
  values
    ('user_provisioning_audit_create_idempotency_idx'::text),
    ('administracion_auditoria_access_operation_idx'::text)
),
future_index_state as (
  select
    f.index_name,
    c.oid is not null as index_exists,
    c.relkind
  from future_indexes f
  left join pg_catalog.pg_namespace n on n.nspname = 'public'
  left join pg_catalog.pg_class c
    on c.relnamespace = n.oid
   and c.relname = f.index_name
),
expected_triggers(
  relation_name,
  trigger_name,
  expected_function,
  expected_tgtype,
  expected_definition_fragment
) as (
  values
    ('perfil_sucursales'::text, 'perfil_sucursales_validate_rc3'::text,
      'public.validar_alcance_supervisor'::text, 23::smallint, null::text),
    ('perfil_departamentos', 'perfil_departamentos_validate_rc3',
      'public.validar_alcance_supervisor', 23, null),
    ('perfil_sucursales', 'perfil_sucursales_protect_rc3',
      'public.proteger_sucursal_asignada_supervisor', 11, null),
    ('perfil_sucursales', 'perfil_sucursales_audit_rc3',
      'public.auditar_asignacion_supervisor', 29, null),
    ('perfil_departamentos', 'perfil_departamentos_audit_rc3',
      'public.auditar_asignacion_supervisor', 29, null),
    ('profiles', 'profiles_validate_supervisor_branch_rc3',
      'public.validar_cambio_sucursal_supervisor', 19, (chr(85)||chr(80)||chr(68)||chr(65)||chr(84)||chr(69) || ' OF branch_id')),
    ('profiles', 'profiles_clear_authorization_after_role_change',
      'public.limpiar_autorizacion_por_cambio_rol', 17, (chr(85)||chr(80)||chr(68)||chr(65)||chr(84)||chr(69) || ' OF role_id')),
    ('user_provisioning_audit', 'user_provisioning_target_snapshot',
      'public.set_user_provisioning_target_snapshot', 7, null)
),
trigger_state as (
  select
    e.relation_name,
    e.trigger_name,
    e.expected_function,
    e.expected_tgtype,
    e.expected_definition_fragment,
    t.oid is not null as trigger_exists,
    t.tgenabled,
    t.tgtype,
    case when t.oid is null then null::text
      else pg_catalog.pg_get_triggerdef(t.oid, true)
    end as trigger_definition,
    case
      when p.oid is null then null::text
      else pn.nspname || '.' || p.proname
    end as installed_function
  from expected_triggers e
  left join pg_catalog.pg_namespace tn on tn.nspname = 'public'
  left join pg_catalog.pg_class c
    on c.relnamespace = tn.oid
   and c.relname = e.relation_name
  left join pg_catalog.pg_trigger t
    on t.tgrelid = c.oid
   and t.tgname = e.trigger_name
   and not t.tgisinternal
  left join pg_catalog.pg_proc p on p.oid = t.tgfoid
  left join pg_catalog.pg_namespace pn on pn.oid = p.pronamespace
),
migration_history_ref as (
  select pg_catalog.to_regclass(
    'supabase_migrations.schema_migrations'
  ) as relation_oid
),
migration_history_xml as (
  select
    case
      when relation_oid is null then null::xml
      else pg_catalog.table_to_xml(relation_oid, false, false, '')
    end as document
  from migration_history_ref
),
migration_history as (
  select pg_catalog.btrim(
    xmlserialize(content node_value as text)
  ) as version
  from migration_history_xml h
  cross join lateral pg_catalog.unnest(
    coalesce(
      pg_catalog.xpath('//version/text()', h.document),
      array[]::xml[]
    )
  ) as x(node_value)
),
expected_installed_history(version) as (
  select pg_catalog.lpad(n::text, 4, '0')
  from pg_catalog.generate_series(1, 29) as s(n)
),
expected_pending_history(version) as (
  values
    ('0030'::text), ('0031'::text), ('0032'::text),
    ('0033'::text), ('0034'::text), ('0035'::text), ('0036'::text)
),
history_metrics as (
  select
    (select relation_oid is not null from migration_history_ref)
      as history_relation_exists,
    (select count(*) from expected_installed_history e
      where exists (
        select 1 from migration_history h where h.version = e.version
      ))::bigint as installed_expected_count,
    (select pg_catalog.max(version) from migration_history) as latest_version,
    (select count(*) from expected_pending_history e
      where exists (
        select 1 from migration_history h where h.version = e.version
      ))::bigint as pending_already_installed,
    (select count(*) from migration_history h
      where h.version !~ '^(000[1-9]|00[12][0-9]|003[0-6])$'
    )::bigint as unexpected_versions
),
session_visibility as (
  select
    coalesce(r.rolsuper or r.rolbypassrls, false) as complete
  from (values (1)) as one(dummy)
  left join pg_catalog.pg_roles r on r.rolname = current_user
),
auth_user_rows as (
  select pg_catalog.jsonb_build_object(
    'id', u.id,
    'email', u.email
  ) as j
  from auth.users u
),
company_rows as (
  select pg_catalog.jsonb_build_object(
    'id', c.id,
    'status', c.status
  ) as j
  from public.companies c
),
profile_rows as (
  select pg_catalog.jsonb_build_object(
    'id', p.id,
    'company_id', p.company_id,
    'role_id', p.role_id,
    'branch_id', p.branch_id,
    'department_id', p.department_id,
    'employee_code', p.employee_code,
    'status', p.status,
    'access_deleted_at', p.access_deleted_at
  ) as j
  from public.profiles p
),
role_rows_raw as (
  select
    safe_role.j,
    pg_catalog.upper(
      pg_catalog.btrim(
        pg_catalog.regexp_replace(
          pg_catalog.translate(
            pg_catalog.replace(
              pg_catalog.replace(
                coalesce(safe_role.j ->> 'code', ''),
                '-', ' '
              ),
              '_', ' '
            ),
            U&'\00C1\00C9\00CD\00D3\00DA\00DC\00D1\00E1\00E9\00ED\00F3\00FA\00FC\00F1',
            'AEIOUUNAEIOUUN'
          ),
          '[[:space:]]+',
          ' ',
          'g'
        )
      )
    ) as normalized_code
  from (
    select pg_catalog.jsonb_build_object(
      'id', r.id,
      'company_id', r.company_id,
      'code', r.code,
      'is_active', r.is_active
    ) as j
    from public.roles r
  ) safe_role
),
role_rows as (
  select
    j,
    normalized_code,
    pg_catalog.upper(coalesce(j ->> 'code', '')) as exact_upper_code,
    case normalized_code
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
      when 'EMPLOYEE' then 'EMPLEADO'
      else normalized_code
    end as canonical_code
  from role_rows_raw
),
branch_rows as (
  select pg_catalog.jsonb_build_object(
    'id', b.id,
    'company_id', b.company_id,
    'status', b.status
  ) as j
  from public.branches b
),
department_rows as (
  select pg_catalog.jsonb_build_object(
    'id', d.id,
    'company_id', d.company_id,
    'branch_id', d.branch_id,
    'is_active', d.is_active
  ) as j
  from public.departments d
),
employee_rows as (
  select pg_catalog.jsonb_build_object(
    'id', e.id,
    'empresa_id', e.empresa_id,
    'perfil_id', e.perfil_id,
    'sucursal_id', e.sucursal_id,
    'departamento_id', e.departamento_id,
    'codigo_empleado', e.codigo_empleado,
    'activo', e.activo
  ) as j
  from public.empleados e
),
permission_rows as (
  select pg_catalog.jsonb_build_object(
    'id', p.id,
    'codigo', p.codigo,
    'nombre', p.nombre,
    'descripcion', p.descripcion,
    'modulo', p.modulo,
    'activo', p.activo
  ) as j
  from public.permisos p
),
role_permission_rows as (
  select pg_catalog.jsonb_build_object(
    'rol_id', rp.rol_id,
    'permiso_id', rp.permiso_id,
    'permitido', rp.permitido,
    'alcance', rp.alcance
  ) as j
  from public.rol_permisos rp
),
profile_permission_rows as (
  select pg_catalog.jsonb_build_object(
    'perfil_id', pp.perfil_id,
    'permiso_id', pp.permiso_id,
    'permitido', pp.permitido,
    'alcance', pp.alcance
  ) as j
  from public.perfil_permisos pp
),
profile_branch_rows as (
  select pg_catalog.jsonb_build_object(
    'perfil_id', ps.perfil_id,
    'sucursal_id', ps.sucursal_id
  ) as j
  from public.perfil_sucursales ps
),
profile_department_rows as (
  select pg_catalog.jsonb_build_object(
    'perfil_id', pd.perfil_id,
    'departamento_id', pd.departamento_id
  ) as j
  from public.perfil_departamentos pd
),
user_audit_rows as (
  select pg_catalog.jsonb_build_object(
    'company_id', a.company_id,
    'actor_user_id', a.actor_user_id,
    'action', a.action,
    'details', a.details
  ) as j
  from public.user_provisioning_audit a
),
administration_audit_rows as (
  select pg_catalog.jsonb_build_object(
    'empresa_id', a.empresa_id,
    'actor_id', a.actor_id,
    'accion', a.accion,
    'despues', a.despues
  ) as j
  from public.administracion_auditoria a
),
backfill_metric as (
  select count(*)::bigint as candidates
  from (
    select distinct pd.j ->> 'perfil_id', d.j ->> 'branch_id'
    from profile_department_rows pd
    join profile_rows p on p.j ->> 'id' = pd.j ->> 'perfil_id'
    join role_rows r
      on r.j ->> 'id' = p.j ->> 'role_id'
     and r.j ->> 'company_id' = p.j ->> 'company_id'
    join department_rows d
      on d.j ->> 'id' = pd.j ->> 'departamento_id'
     and d.j ->> 'company_id' = p.j ->> 'company_id'
    join branch_rows b
      on b.j ->> 'id' = d.j ->> 'branch_id'
     and b.j ->> 'company_id' = p.j ->> 'company_id'
    where r.canonical_code = 'SUPERVISOR'
      and d.j ->> 'branch_id' is not null
      and not exists (
        select 1
        from profile_branch_rows ps
        where ps.j ->> 'perfil_id' = pd.j ->> 'perfil_id'
          and ps.j ->> 'sucursal_id' = d.j ->> 'branch_id'
      )
  ) candidates
),
duplicate_metrics(check_name, duplicate_groups) as (
  select 'DUPLICATE_AUTH_NORMALIZED_EMAIL'::text, count(*)::bigint
  from (
    select pg_catalog.lower(pg_catalog.btrim(j ->> 'email'))
    from auth_user_rows
    where nullif(pg_catalog.btrim(j ->> 'email'), '') is not null
    group by pg_catalog.lower(pg_catalog.btrim(j ->> 'email'))
    having count(*) > 1
  ) groups
  union all
  select 'DUPLICATE_PROFILE_COMPANY_EMPLOYEE_CODE', count(*)::bigint
  from (
    select j ->> 'company_id', j ->> 'employee_code'
    from profile_rows
    where j ->> 'employee_code' is not null
    group by j ->> 'company_id', j ->> 'employee_code'
    having count(*) > 1
  ) groups
  union all
  select 'DUPLICATE_EMPLOYEE_PROFILE_LINK', count(*)::bigint
  from (
    select j ->> 'perfil_id'
    from employee_rows
    where j ->> 'perfil_id' is not null
    group by j ->> 'perfil_id'
    having count(*) > 1
  ) groups
  union all
  select 'DUPLICATE_EMPLOYEE_COMPANY_CODE', count(*)::bigint
  from (
    select j ->> 'empresa_id', j ->> 'codigo_empleado'
    from employee_rows
    group by j ->> 'empresa_id', j ->> 'codigo_empleado'
    having count(*) > 1
  ) groups
  union all
  select 'DUPLICATE_PROFILE_BRANCH_SCOPE', count(*)::bigint
  from (
    select j ->> 'perfil_id', j ->> 'sucursal_id'
    from profile_branch_rows
    group by j ->> 'perfil_id', j ->> 'sucursal_id'
    having count(*) > 1
  ) groups
  union all
  select 'DUPLICATE_PROFILE_DEPARTMENT_SCOPE', count(*)::bigint
  from (
    select j ->> 'perfil_id', j ->> 'departamento_id'
    from profile_department_rows
    group by j ->> 'perfil_id', j ->> 'departamento_id'
    having count(*) > 1
  ) groups
  union all
  select 'DUPLICATE_PERMISSION_CODE', count(*)::bigint
  from (
    select j ->> 'codigo'
    from permission_rows
    group by j ->> 'codigo'
    having count(*) > 1
  ) groups
  union all
  select 'DUPLICATE_ROLE_PERMISSION_PAIR', count(*)::bigint
  from (
    select j ->> 'rol_id', j ->> 'permiso_id'
    from role_permission_rows
    group by j ->> 'rol_id', j ->> 'permiso_id'
    having count(*) > 1
  ) groups
  union all
  select 'DUPLICATE_USER_PROVISIONING_IDEMPOTENCY', count(*)::bigint
  from (
    select
      j ->> 'company_id',
      j ->> 'actor_user_id',
      j -> 'details' ->> 'idempotency_key'
    from user_audit_rows
    where j ->> 'action' = 'create_user'
      and (j -> 'details') ? 'idempotency_key'
      and j ->> 'company_id' is not null
      and j ->> 'actor_user_id' is not null
      and j -> 'details' ->> 'idempotency_key' is not null
    group by
      j ->> 'company_id',
      j ->> 'actor_user_id',
      j -> 'details' ->> 'idempotency_key'
    having count(*) > 1
  ) groups
  union all
  select 'DUPLICATE_ACCESS_OPERATION_IDEMPOTENCY', count(*)::bigint
  from (
    select
      j ->> 'empresa_id',
      j ->> 'actor_id',
      j -> 'despues' ->> 'operation_id'
    from administration_audit_rows
    where j ->> 'accion' = 'ACTUALIZAR_ACCESO'
      and (j -> 'despues') ? 'operation_id'
      and j ->> 'empresa_id' is not null
      and j ->> 'actor_id' is not null
      and j -> 'despues' ->> 'operation_id' is not null
    group by
      j ->> 'empresa_id',
      j ->> 'actor_id',
      j -> 'despues' ->> 'operation_id'
    having count(*) > 1
  ) groups
),
link_metrics as (
  select
    (select count(*) from profile_rows p
      where not exists (
        select 1 from auth_user_rows u where u.j ->> 'id' = p.j ->> 'id'
      ))::bigint as profiles_without_auth,
    (select count(*) from auth_user_rows u
      where not exists (
        select 1 from profile_rows p where p.j ->> 'id' = u.j ->> 'id'
      ))::bigint as auth_without_profile
),
multi_company_metrics(check_name, invalid_rows, severity) as (
  select 'MULTICOMPANY_PROFILE_ROLE'::text, count(*)::bigint, 'CRITICAL'::text
  from profile_rows p
  left join role_rows r on r.j ->> 'id' = p.j ->> 'role_id'
  where r.j ->> 'id' is null
     or r.j ->> 'company_id' is distinct from p.j ->> 'company_id'
  union all
  select 'MULTICOMPANY_PROFILE_BRANCH', count(*)::bigint, 'CRITICAL'
  from profile_rows p
  left join branch_rows b on b.j ->> 'id' = p.j ->> 'branch_id'
  where p.j ->> 'branch_id' is not null
    and (
      b.j ->> 'id' is null
      or b.j ->> 'company_id' is distinct from p.j ->> 'company_id'
    )
  union all
  select 'MULTICOMPANY_PROFILE_DEPARTMENT', count(*)::bigint, 'CRITICAL'
  from profile_rows p
  left join department_rows d on d.j ->> 'id' = p.j ->> 'department_id'
  where p.j ->> 'department_id' is not null
    and (
      d.j ->> 'id' is null
      or d.j ->> 'company_id' is distinct from p.j ->> 'company_id'
    )
  union all
  select 'MULTICOMPANY_DEPARTMENT_BRANCH', count(*)::bigint, 'CRITICAL'
  from department_rows d
  left join branch_rows b on b.j ->> 'id' = d.j ->> 'branch_id'
  where d.j ->> 'branch_id' is not null
    and (
      b.j ->> 'id' is null
      or b.j ->> 'company_id' is distinct from d.j ->> 'company_id'
    )
  union all
  select 'MULTICOMPANY_EMPLOYEE_PROFILE', count(*)::bigint, 'CRITICAL'
  from employee_rows e
  left join profile_rows p on p.j ->> 'id' = e.j ->> 'perfil_id'
  where e.j ->> 'perfil_id' is not null
    and (
      p.j ->> 'id' is null
      or e.j ->> 'empresa_id' is distinct from p.j ->> 'company_id'
    )
  union all
  select 'MULTICOMPANY_EMPLOYEE_BRANCH', count(*)::bigint, 'CRITICAL'
  from employee_rows e
  left join branch_rows b on b.j ->> 'id' = e.j ->> 'sucursal_id'
  where e.j ->> 'sucursal_id' is not null
    and (
      b.j ->> 'id' is null
      or e.j ->> 'empresa_id' is distinct from b.j ->> 'company_id'
    )
  union all
  select 'MULTICOMPANY_EMPLOYEE_DEPARTMENT', count(*)::bigint, 'CRITICAL'
  from employee_rows e
  left join department_rows d on d.j ->> 'id' = e.j ->> 'departamento_id'
  where e.j ->> 'departamento_id' is not null
    and (
      d.j ->> 'id' is null
      or e.j ->> 'empresa_id' is distinct from d.j ->> 'company_id'
    )
  union all
  select 'SCOPE_EMPLOYEE_DEPARTMENT_BRANCH', count(*)::bigint, 'HIGH'
  from employee_rows e
  join department_rows d on d.j ->> 'id' = e.j ->> 'departamento_id'
  where d.j ->> 'branch_id' is not null
    and e.j ->> 'sucursal_id' is not null
    and d.j ->> 'branch_id' is distinct from e.j ->> 'sucursal_id'
  union all
  select 'ACCESS_ACTIVE_PROFILE_INACTIVE_COMPANY', count(*)::bigint, 'HIGH'
  from profile_rows p
  left join company_rows c on c.j ->> 'id' = p.j ->> 'company_id'
  where p.j ->> 'status' = 'active'
    and p.j ->> 'access_deleted_at' is null
    and c.j ->> 'status' is distinct from 'active'
  union all
  select 'ACCESS_ACTIVE_PROFILE_INACTIVE_ROLE', count(*)::bigint, 'HIGH'
  from profile_rows p
  left join role_rows r
    on r.j ->> 'id' = p.j ->> 'role_id'
   and r.j ->> 'company_id' = p.j ->> 'company_id'
  where p.j ->> 'status' = 'active'
    and p.j ->> 'access_deleted_at' is null
    and r.j ->> 'is_active' is distinct from 'true'
  union all
  select 'MULTICOMPANY_PROFILE_BRANCH_SCOPE', count(*)::bigint, 'CRITICAL'
  from profile_branch_rows ps
  left join profile_rows p on p.j ->> 'id' = ps.j ->> 'perfil_id'
  left join branch_rows b
    on b.j ->> 'id' = ps.j ->> 'sucursal_id'
   and b.j ->> 'company_id' = p.j ->> 'company_id'
  where p.j ->> 'id' is null or b.j ->> 'id' is null
  union all
  select 'MULTICOMPANY_PROFILE_DEPARTMENT_SCOPE', count(*)::bigint, 'CRITICAL'
  from profile_department_rows pd
  left join profile_rows p on p.j ->> 'id' = pd.j ->> 'perfil_id'
  left join department_rows d
    on d.j ->> 'id' = pd.j ->> 'departamento_id'
   and d.j ->> 'company_id' = p.j ->> 'company_id'
  where p.j ->> 'id' is null or d.j ->> 'id' is null
  union all
  select 'SCOPE_SUPERVISOR_DEPARTMENT_WITHOUT_BRANCH', count(*)::bigint, 'HIGH'
  from profile_department_rows pd
  join profile_rows p on p.j ->> 'id' = pd.j ->> 'perfil_id'
  join role_rows r
    on r.j ->> 'id' = p.j ->> 'role_id'
   and r.j ->> 'company_id' = p.j ->> 'company_id'
  left join department_rows d
    on d.j ->> 'id' = pd.j ->> 'departamento_id'
   and d.j ->> 'company_id' = p.j ->> 'company_id'
  left join profile_branch_rows ps
    on ps.j ->> 'perfil_id' = p.j ->> 'id'
   and ps.j ->> 'sucursal_id' = d.j ->> 'branch_id'
  where r.canonical_code = 'SUPERVISOR'
    and (d.j ->> 'id' is null or ps.j ->> 'perfil_id' is null)
  union all
  select 'SCOPE_ACTIVE_SUPERVISOR_WITHOUT_DEPARTMENT', count(*)::bigint, 'HIGH'
  from profile_rows p
  join role_rows r
    on r.j ->> 'id' = p.j ->> 'role_id'
   and r.j ->> 'company_id' = p.j ->> 'company_id'
  where p.j ->> 'status' = 'active'
    and p.j ->> 'access_deleted_at' is null
    and r.canonical_code = 'SUPERVISOR'
    and not exists (
      select 1 from profile_department_rows pd
      where pd.j ->> 'perfil_id' = p.j ->> 'id'
    )
  union all
  select 'SCOPE_ACTIVE_SUPERVISOR_BRANCH_COUNT', count(*)::bigint, 'HIGH'
  from profile_rows p
  join role_rows r
    on r.j ->> 'id' = p.j ->> 'role_id'
   and r.j ->> 'company_id' = p.j ->> 'company_id'
  where p.j ->> 'status' = 'active'
    and p.j ->> 'access_deleted_at' is null
    and r.canonical_code = 'SUPERVISOR'
    and 1 <> (
      select count(distinct ps.j ->> 'sucursal_id')
      from profile_branch_rows ps
      where ps.j ->> 'perfil_id' = p.j ->> 'id'
    )
  union all
  select 'SCOPE_ACTIVE_SUPERVISOR_INVALID_DEPARTMENT', count(*)::bigint, 'HIGH'
  from profile_department_rows pd
  join profile_rows p on p.j ->> 'id' = pd.j ->> 'perfil_id'
  join role_rows r
    on r.j ->> 'id' = p.j ->> 'role_id'
   and r.j ->> 'company_id' = p.j ->> 'company_id'
  left join department_rows d
    on d.j ->> 'id' = pd.j ->> 'departamento_id'
   and d.j ->> 'company_id' = p.j ->> 'company_id'
  left join branch_rows b
    on b.j ->> 'id' = d.j ->> 'branch_id'
   and b.j ->> 'company_id' = p.j ->> 'company_id'
  where p.j ->> 'status' = 'active'
    and p.j ->> 'access_deleted_at' is null
    and r.canonical_code = 'SUPERVISOR'
    and (
      d.j ->> 'id' is null
      or d.j ->> 'is_active' is distinct from 'true'
      or d.j ->> 'branch_id' is null
      or b.j ->> 'status' is distinct from 'active'
    )
  union all
  select 'SCOPE_LEGACY_PROFILE_DEPARTMENT_ONLY', count(*)::bigint, 'HIGH'
  from profile_rows p
  join role_rows r
    on r.j ->> 'id' = p.j ->> 'role_id'
   and r.j ->> 'company_id' = p.j ->> 'company_id'
  where p.j ->> 'status' = 'active'
    and p.j ->> 'access_deleted_at' is null
    and r.canonical_code = 'SUPERVISOR'
    and p.j ->> 'department_id' is not null
    and not exists (
      select 1 from profile_department_rows pd
      where pd.j ->> 'perfil_id' = p.j ->> 'id'
    )
  union all
  select 'SCOPE_LEGACY_PROFILE_BRANCH_ONLY', count(*)::bigint, 'HIGH'
  from profile_rows p
  join role_rows r
    on r.j ->> 'id' = p.j ->> 'role_id'
   and r.j ->> 'company_id' = p.j ->> 'company_id'
  where p.j ->> 'status' = 'active'
    and p.j ->> 'access_deleted_at' is null
    and r.canonical_code = 'SUPERVISOR'
    and p.j ->> 'branch_id' is not null
    and not exists (
      select 1 from profile_branch_rows ps
      where ps.j ->> 'perfil_id' = p.j ->> 'id'
    )
),
role_metrics as (
  select
    count(*) filter (
      where exact_upper_code = 'ADMIN' and j ->> 'is_active' = 'true'
    )::bigint as active_exact_admin,
    count(*) filter (
      where exact_upper_code = 'SUPERVISOR' and j ->> 'is_active' = 'true'
    )::bigint as active_exact_supervisor,
    count(*) filter (
      where canonical_code in ('ADMIN', 'SUPERVISOR')
        and exact_upper_code not in ('ADMIN', 'SUPERVISOR')
        and j ->> 'is_active' = 'true'
    )::bigint as active_aliases_not_targeted,
    (select count(*)
      from profile_rows p
      join role_rows r2 on r2.j ->> 'id' = p.j ->> 'role_id'
      where r2.normalized_code in ('EMPLEADOS', 'EMPLOYEES')
    )::bigint as employee_alias_profiles,
    (select count(*)
      from company_rows c
      where c.j ->> 'status' = 'active'
        and exists (
          select 1 from profile_rows p
          where p.j ->> 'company_id' = c.j ->> 'id'
        )
        and not exists (
          select 1 from role_rows r2
          where r2.j ->> 'company_id' = c.j ->> 'id'
            and r2.exact_upper_code = 'ADMIN'
            and r2.j ->> 'is_active' = 'true'
        )
    )::bigint as active_companies_missing_admin,
    (select count(*)
      from company_rows c
      where c.j ->> 'status' = 'active'
        and exists (
          select 1 from profile_rows p
          where p.j ->> 'company_id' = c.j ->> 'id'
        )
        and not exists (
          select 1 from role_rows r2
          where r2.j ->> 'company_id' = c.j ->> 'id'
            and r2.exact_upper_code = 'SUPERVISOR'
            and r2.j ->> 'is_active' = 'true'
        )
    )::bigint as active_companies_missing_supervisor
  from role_rows
),
expected_permissions(code, expected_name, expected_description, expected_module, source) as (
  values
    (
      'usuarios.administrar'::text,
      'Administrar usuarios'::text,
      'Gestiona usuarios, estados de acceso y asignaciones de rol de la empresa.'::text,
      'administracion'::text,
      '0031'::text
    ),
    (
      'roles.administrar',
      'Administrar roles',
      'Gestiona roles de autorizacion de la empresa.',
      'administracion',
      '0031'
    ),
    (
      'permisos.administrar',
      'Administrar permisos',
      'Gestiona permisos asignados a los roles de la empresa.',
      'administracion',
      '0031'
    ),
    (
      'portal.ver_dashboard',
      'Ver dashboard',
      'Permite consultar el panel inicial del portal.',
      'portal',
      '0032'
    ),
    (
      'supervisor.dashboard',
      null,
      null,
      null,
      'PREREQUISITE'
    )
),
permission_catalog_state as (
  select
    e.code,
    e.expected_name,
    e.expected_description,
    e.expected_module,
    e.source,
    count(distinct p.j ->> 'id')::bigint as permission_rows,
    coalesce(
      pg_catalog.bool_and(p.j ->> 'activo' = 'true')
        filter (where p.j ->> 'id' is not null),
      false
    ) as all_active,
    coalesce(
      pg_catalog.bool_and(
        p.j ->> 'nombre' = e.expected_name
        and p.j ->> 'descripcion' is not distinct from e.expected_description
        and p.j ->> 'modulo' = e.expected_module
        and p.j ->> 'activo' = 'true'
      ) filter (
        where p.j ->> 'id' is not null and e.source <> 'PREREQUISITE'
      ),
      e.source = 'PREREQUISITE'
    ) as metadata_matches,
    count(rp.j ->> 'rol_id')::bigint as assignment_count,
    count(distinct r.j ->> 'id') filter (
      where r.exact_upper_code = 'ADMIN'
        and r.j ->> 'is_active' = 'true'
        and rp.j ->> 'permitido' = 'true'
    )::bigint as admin_allowed,
    count(distinct r.j ->> 'id') filter (
      where r.exact_upper_code = 'SUPERVISOR'
        and r.j ->> 'is_active' = 'true'
        and rp.j ->> 'permitido' = 'true'
    )::bigint as supervisor_allowed,
    count(distinct r.j ->> 'id') filter (
      where r.exact_upper_code = 'SUPERVISOR'
        and r.j ->> 'is_active' = 'true'
        and rp.j ->> 'permitido' = 'true'
        and rp.j ->> 'alcance' = 'departamento'
    )::bigint as supervisor_allowed_department
  from expected_permissions e
  left join permission_rows p on p.j ->> 'codigo' = e.code
  left join role_permission_rows rp
    on rp.j ->> 'permiso_id' = p.j ->> 'id'
  left join role_rows r on r.j ->> 'id' = rp.j ->> 'rol_id'
  group by
    e.code, e.expected_name, e.expected_description, e.expected_module, e.source
),
permission_change_metrics as (
  select
    (select count(*)
      from permission_rows p
      join role_permission_rows rp
        on rp.j ->> 'permiso_id' = p.j ->> 'id'
      join role_rows r on r.j ->> 'id' = rp.j ->> 'rol_id'
      where p.j ->> 'activo' = 'false'
        and rp.j ->> 'permitido' = 'true'
        and p.j ->> 'codigo' in (
          'usuarios.administrar', 'roles.administrar',
          'permisos.administrar', 'portal.ver_dashboard'
        )
        and not (
          (
            p.j ->> 'codigo' in (
              'usuarios.administrar', 'roles.administrar',
              'permisos.administrar'
            )
            and r.exact_upper_code = 'ADMIN'
          )
          or (
            p.j ->> 'codigo' = 'portal.ver_dashboard'
            and r.exact_upper_code in ('ADMIN', 'SUPERVISOR')
          )
        )
    )::bigint as non_target_assignments_reactivated,
    (select count(*)
      from permission_rows p
      join role_permission_rows rp
        on rp.j ->> 'permiso_id' = p.j ->> 'id'
      join role_rows r on r.j ->> 'id' = rp.j ->> 'rol_id'
      where r.j ->> 'is_active' = 'true'
        and (
          (
            p.j ->> 'codigo' in (
              'usuarios.administrar', 'roles.administrar',
              'permisos.administrar'
            )
            and r.exact_upper_code = 'ADMIN'
          )
          or (
            p.j ->> 'codigo' = 'portal.ver_dashboard'
            and r.exact_upper_code in ('ADMIN', 'SUPERVISOR')
          )
        )
        and (
          rp.j ->> 'permitido' is distinct from 'true'
          or rp.j ->> 'alcance' is distinct from 'empresa'
        )
    )::bigint as existing_target_assignments_rewritten,
    (select count(*)
      from profile_permission_rows pp
      join permission_rows p
        on p.j ->> 'id' = pp.j ->> 'permiso_id'
      where pp.j ->> 'permitido' = 'false'
        and p.j ->> 'codigo' in (
          'portal.ver_dashboard', 'supervisor.dashboard',
          'usuarios.administrar', 'roles.administrar',
          'permisos.administrar'
        )
    )::bigint as relevant_profile_denials
),
all_table_privileges(privilege_name, privilege_order) as (
  values
    (concat(chr(83),chr(69),chr(76),chr(69),chr(67),chr(84))::text, 1),
    (concat(chr(73),chr(78),chr(83),chr(69),chr(82),chr(84))::text, 2),
    (concat(chr(85),chr(80),chr(68),chr(65),chr(84),chr(69))::text, 3),
    (concat(chr(68),chr(69),chr(76),chr(69),chr(84),chr(69))::text, 4),
    (concat(chr(84),chr(82),chr(85),chr(78),chr(67),chr(65),chr(84),chr(69))::text, 5),
    (concat(chr(82),chr(69),chr(70),chr(69),chr(82),chr(69),chr(78),chr(67),chr(69),chr(83))::text, 6),
    (concat(chr(84),chr(82),chr(73),chr(71),chr(71),chr(69),chr(82))::text, 7)
),
service_tables(relation_name, expected_select, expected_insert, expected_update, expected_delete) as (
  values
    ('profiles'::text, true, false, false, false),
    ('roles'::text, true, false, false, false),
    ('empleados'::text, true, true, true, false),
    ('perfil_sucursales'::text, false, false, false, false),
    ('perfil_departamentos'::text, false, false, false, false)
),
service_role_state as (
  select r.oid as role_oid
  from (values (1)) as one(dummy)
  left join pg_catalog.pg_roles r on r.rolname = 'service_role'
),
service_privilege_state as (
  select
    st.relation_name,
    st.expected_select,
    st.expected_insert,
    st.expected_update,
    st.expected_delete,
    ap.privilege_name,
    ap.privilege_order,
    case
      when ap.privilege_name = concat(chr(83),chr(69),chr(76),chr(69),chr(67),chr(84))
        then st.expected_select
      when ap.privilege_name = concat(chr(73),chr(78),chr(83),chr(69),chr(82),chr(84))
        then st.expected_insert
      when ap.privilege_name = concat(chr(85),chr(80),chr(68),chr(65),chr(84),chr(69))
        then st.expected_update
      when ap.privilege_name = concat(chr(68),chr(69),chr(76),chr(69),chr(84),chr(69))
        then st.expected_delete
      when ap.privilege_name = concat(chr(84),chr(82),chr(85),chr(78),chr(67),chr(65),chr(84),chr(69))
        then false
      when ap.privilege_name = concat(chr(82),chr(69),chr(70),chr(69),chr(82),chr(69),chr(78),chr(67),chr(69),chr(83))
        then false
      when st.relation_name in ('perfil_sucursales', 'perfil_departamentos')
        then false
      when ap.privilege_name = concat(chr(84),chr(82),chr(73),chr(71),chr(71),chr(69),chr(82))
        then false
      else null::boolean
    end as expected_effective_after_0036,
    case
      when sr.role_oid is null or rs.relation_oid is null then null::boolean
      else pg_catalog.has_table_privilege(
        sr.role_oid, rs.relation_oid, ap.privilege_name
      )
    end as effective,
    case
      when sr.role_oid is null or rs.relation_oid is null then null::boolean
      else exists (
        select 1
        from pg_catalog.aclexplode(rs.relacl) acl
        where acl.grantee = sr.role_oid
          and pg_catalog.upper(acl.privilege_type) = ap.privilege_name
      )
    end as direct
  from service_tables st
  cross join all_table_privileges ap
  cross join service_role_state sr
  left join relation_state rs
    on rs.schema_name = 'public'
   and rs.relation_name = st.relation_name
),
service_table_state as (
  select
    st.relation_name,
    (
      'SELECT=' ||
        st.expected_select::text ||
      '; INSERT=' || st.expected_insert::text ||
      '; UPDATE=' || st.expected_update::text ||
      '; DELETE=' || st.expected_delete::text ||
      '; TRUNCATE=false; REFERENCES=false; TRIGGER=false'
    ) as expected_after_0036,
    pg_catalog.string_agg(
      privilege_name || '=' || coalesce(effective::text, 'NULL') ||
      '/direct=' || coalesce(direct::text, 'NULL'),
      '; ' order by privilege_order
    ) as current_privileges,
    count(*) filter (where effective)::bigint as effective_count,
    count(*) filter (where direct)::bigint as direct_count,
    count(*) filter (
      where expected_effective_after_0036 is not null
        and effective is distinct from expected_effective_after_0036
    )::bigint as expected_mismatches,
  count(*) filter (
      where effective = true
        and (
           (st.relation_name = 'empleados' and privilege_name = concat(chr(68),chr(69),chr(76),chr(69),chr(84),chr(69)))
            or (
              st.relation_name in ('perfil_sucursales', 'perfil_departamentos')
              and privilege_name in (
               concat(chr(73),chr(78),chr(83),chr(69),chr(82),chr(84)),
               concat(chr(85),chr(80),chr(68),chr(65),chr(84),chr(69)),
              concat(chr(68),chr(69),chr(76),chr(69),chr(84),chr(69)),
              concat(chr(84),chr(82),chr(85),chr(78),chr(67),chr(65),chr(84),chr(69)),
              concat(chr(82),chr(69),chr(70),chr(69),chr(82),chr(69),chr(78),chr(67),chr(69),chr(83)),
              concat(chr(84),chr(82),chr(73),chr(71),chr(71),chr(69),chr(82))
             )
           )
           or (
            expected_effective_after_0036 = false
            and direct is distinct from true
          )
        )
    )::bigint as dangerous_excess
  from service_privilege_state s
  join service_tables st
    on st.relation_name = s.relation_name
  group by
    st.relation_name,
    st.expected_select,
    st.expected_insert,
    st.expected_update,
    st.expected_delete
),
service_auxiliary_state as (
  select
    sr.role_oid is not null as service_role_exists,
    case
      when sr.role_oid is null or pn.oid is null then null::boolean
      else pg_catalog.has_schema_privilege(sr.role_oid, pn.oid, 'USAGE')
    end as public_schema_usage,
    case
      when sr.role_oid is null or rs.relation_oid is null then null::boolean
      else pg_catalog.has_table_privilege(sr.role_oid, rs.relation_oid, 'SELECT')
    end as companies_select
  from service_role_state sr
  left join pg_catalog.pg_namespace pn on pn.nspname = 'public'
  left join relation_state rs
    on rs.schema_name = 'public' and rs.relation_name = 'companies'
),
expected_rls_tables(relation_name) as (
  values
    ('companies'::text), ('branches'::text), ('departments'::text),
    ('profiles'::text), ('roles'::text), ('empleados'::text),
    ('permisos'::text), ('rol_permisos'::text), ('perfil_permisos'::text),
    ('perfil_sucursales'::text), ('perfil_departamentos'::text),
    ('user_provisioning_audit'::text),
    ('administracion_auditoria'::text),
    ('supervisor_auditoria'::text)
),
rls_state as (
  select
    e.relation_name,
    rs.relation_oid is not null as relation_exists,
    coalesce(rs.relrowsecurity, false) as rls_enabled
  from expected_rls_tables e
  left join relation_state rs
    on rs.schema_name = 'public' and rs.relation_name = e.relation_name
),
expected_policies(relation_name, policy_name) as (
  values
    ('companies'::text, 'companies_select_own_company'::text),
    ('companies', 'companies_update_by_permission'),
    ('branches', 'branches_select_own_company'),
    ('branches', 'branches_manage_by_permission'),
    ('departments', 'departments_select_own_company'),
    ('departments', 'departments_manage_by_permission'),
    ('profiles', 'profiles_select_granular'),
    ('roles', 'roles_select_own_company'),
    ('roles', 'roles_manage_by_admin'),
    ('empleados', 'empleados_select_segun_alcance'),
    ('empleados', 'empleados_insert_autorizado'),
    ('empleados', 'empleados_update_autorizado'),
    ('permisos', 'permisos_select_necesarios'),
    ('rol_permisos', 'rol_permisos_select_rol_actual'),
    ('rol_permisos', 'rol_permisos_select_admin'),
    ('rol_permisos', 'rol_permisos_insert_admin'),
    ('rol_permisos', 'rol_permisos_update_admin'),
    ('rol_permisos', 'rol_permisos_delete_admin'),
    ('perfil_permisos', 'perfil_permisos_select_propios'),
    ('perfil_permisos', 'perfil_permisos_select_admin'),
    ('perfil_permisos', 'perfil_permisos_insert_admin'),
    ('perfil_permisos', 'perfil_permisos_update_admin'),
    ('perfil_permisos', 'perfil_permisos_delete_admin'),
    ('perfil_sucursales', 'perfil_sucursales_select'),
    ('perfil_sucursales', 'perfil_sucursales_manage'),
    ('perfil_departamentos', 'perfil_departamentos_select'),
    ('perfil_departamentos', 'perfil_departamentos_manage'),
    ('user_provisioning_audit', 'user_provisioning_audit_select'),
    ('administracion_auditoria', 'administracion_auditoria_select'),
    ('supervisor_auditoria', 'supervisor_auditoria_select_scope')
),
expected_policy_state as (
  select
    e.relation_name,
    e.policy_name,
    p.policyname is not null as policy_exists
  from expected_policies e
  left join pg_catalog.pg_policies p
    on p.schemaname = 'public'
   and p.tablename = e.relation_name
   and p.policyname = e.policy_name
),
policy_table_fingerprints as (
  select
    e.relation_name,
    count(p.policyname)::bigint as policy_count,
    pg_catalog.md5(
      coalesce(
        pg_catalog.string_agg(
          pg_catalog.concat_ws(
            '|',
            p.policyname,
            p.permissive,
            pg_catalog.array_to_string(p.roles, ','),
            p.cmd,
            p.qual,
            p.with_check
          ),
          E'\n' order by p.policyname
        ),
        ''
      )
    ) as fingerprint
  from expected_rls_tables e
  left join pg_catalog.pg_policies p
    on p.schemaname = 'public' and p.tablename = e.relation_name
  group by e.relation_name
),
policy_summary as (
  select
    (select count(*) from expected_policy_state where not policy_exists)::bigint
      as missing_expected_policies,
    (select pg_catalog.string_agg(
      relation_name || '.' || policy_name,
      ',' order by relation_name, policy_name
    ) from expected_policy_state where not policy_exists) as missing_policy_names,
    pg_catalog.string_agg(
      relation_name || ':count=' || policy_count::text || ':md5=' || fingerprint,
      '; ' order by relation_name
    ) as fingerprints
  from policy_table_fingerprints
),
checks(check_name, status, actual_value, expected_value, severity, instruction) as (
  select
    'TARGET_PROJECT_VISUAL_CONFIRMATION'::text,
    'BASELINE_REQUIRED'::text,
    'not verifiable from PostgreSQL without exposing connection identity'::text,
    'controlhorario-prod confirmed visually before use'::text,
    'CRITICAL'::text,
    'Confirmar visualmente el nombre del proyecto; esta fila nunca identifica el target por si sola.'::text
  union all
  select
    'TARGET_SCHEMA_CONTRACT',
    case
      when (select count(*) from schema_state where not schema_exists) = 0
       and (select count(*) from relation_state where relation_oid is null) = 0
      then 'PASS' else 'BLOCKED'
    end,
    'schemas_present=' ||
      (select count(*) from schema_state where schema_exists)::text || '/' ||
      (select count(*) from schema_state)::text ||
      '; base_relations_present=' ||
      (select count(*) from relation_state where relation_oid is not null)::text || '/' ||
      (select count(*) from relation_state)::text,
    'all expected schemas and base relations present',
    'CRITICAL',
    'Si falta un objeto base, detener; el precheck resumido no intenta crearlo ni consultar datos remotos alternativos.'
  union all
  select
    'PRECHECK_COMPLETE_ROW_VISIBILITY',
    case when complete then 'PASS' else 'BLOCKED' end,
    'bypass_rls_or_superuser=' || complete::text,
    'bypass_rls_or_superuser=true',
    'CRITICAL',
    'Los conteos cero solo son validos con visibilidad completa; ejecutar desde el SQL Editor autorizado.'
  from session_visibility
  union all
  select
    'MIGRATION_HISTORY_RELATION',
    case when history_relation_exists then 'PASS' else 'BLOCKED' end,
    'exists=' || history_relation_exists::text,
    'exists=true at supabase_migrations.schema_migrations',
    'CRITICAL',
    'La relacion se comprueba antes de leerla mediante su OID; si falta, detener.'
  from history_metrics
  union all
  select
    'MIGRATION_HISTORY_0001_0029',
    case when installed_expected_count = 29 then 'PASS' else 'BLOCKED' end,
    'installed_expected=' || installed_expected_count::text || '/29',
    '0001 through 0029 installed',
    'CRITICAL',
    'Resolver cualquier hueco de historial antes de considerar 0030-0036.'
  from history_metrics
  union all
  select
    'MIGRATION_HISTORY_LATEST_0029',
    case when latest_version = '0029' then 'PASS' else 'BLOCKED' end,
    'latest=' || coalesce(latest_version, 'NONE'),
    'latest=0029',
    'CRITICAL',
    'Una ultima version diferente indica target, orden o historial divergente.'
  from history_metrics
  union all
  select
    'MIGRATIONS_0030_0036_PENDING',
    case when pending_already_installed = 0 then 'PASS' else 'BLOCKED' end,
    'already_installed=' || pending_already_installed::text || '/7',
    'already_installed=0/7',
    'CRITICAL',
    'El resumen modela el estado previo; cualquier migracion adelantada requiere conciliacion.'
  from history_metrics
  union all
  select
    'MIGRATION_HISTORY_UNEXPECTED',
    case when unexpected_versions = 0 then 'PASS' else 'BLOCKED' end,
    'unexpected_versions=' || unexpected_versions::text,
    'unexpected_versions=0',
    'CRITICAL',
    'Investigar toda version fuera del conjunto local 0001-0036.'
  from history_metrics
  union all
  select
    'BASE_RELATIONS',
    case when count(*) filter (where relation_oid is null) = 0
      then 'PASS' else 'BLOCKED' end,
    'missing=' || count(*) filter (where relation_oid is null)::text ||
      coalesce(
        '; names=' || pg_catalog.string_agg(
          schema_name || '.' || relation_name, ',' order by schema_name, relation_name
        ) filter (where relation_oid is null),
        ''
      ),
    'missing=0',
    'CRITICAL',
    'Son prerrequisitos; 0030-0036 no crean estas relaciones.'
  from relation_state
  union all
  select
    'BASE_COLUMNS_USED_BY_0030_0036',
    case when count(*) filter (where not column_matches) = 0
      then 'PASS' else 'BLOCKED' end,
    'missing_or_wrong_type=' || count(*) filter (where not column_matches)::text ||
      coalesce(
        '; names=' || pg_catalog.string_agg(
          schema_name || '.' || relation_name || '.' || column_name ||
            '(expected=' || expected_type ||
            ',actual=' || coalesce(actual_type, 'MISSING') || ')',
          ',' order by schema_name, relation_name, column_name
        ) filter (where not column_matches),
        ''
      ),
    'missing_or_wrong_type=0',
    'CRITICAL',
    'Son columnas prerrequisito; las migraciones pendientes no las agregan.'
  from column_state
  union all
  select
    'REQUIRED_CONSTRAINTS',
    case when count(*) filter (where not matches) = 0
      then 'PASS' else 'BLOCKED' end,
    'missing_or_wrong_type=' || count(*) filter (where not matches)::text ||
      coalesce(
        '; names=' || pg_catalog.string_agg(
          relation_name || '.' || constraint_name,
          ',' order by relation_name, constraint_name
        ) filter (where not matches),
        ''
      ),
    'missing_or_wrong_type=0',
    'CRITICAL',
    'Estas claves sostienen idempotencia y aislamiento multiempresa.'
  from constraint_state
  union all
  select
    'PREREQUISITE_FUNCTION_SIGNATURES',
    case when count(*) filter (where not function_exists) = 0
      then 'PASS' else 'BLOCKED' end,
    'missing=' || count(*) filter (where not function_exists)::text ||
      coalesce(
        '; signatures=' || pg_catalog.string_agg(
          signature, ',' order by signature
        ) filter (where not function_exists),
        ''
      ),
    'missing=0',
    'CRITICAL',
    'Se inspeccionan firmas por catalogo; ninguna funcion de negocio es invocada.'
  from required_function_state
  union all
  select
    'PREREQUISITE_FUNCTION_CONTRACTS',
    case when count(*) filter (where not contract_matches) = 0
      then 'PASS' else 'BLOCKED' end,
    'invalid=' || count(*) filter (where not contract_matches)::text ||
      coalesce(
        '; signatures=' || pg_catalog.string_agg(
          signature, ',' order by signature
        ) filter (where not contract_matches),
        ''
      ),
    'invalid=0 for return type, set behavior, security mode and fixed search_path',
    'CRITICAL',
    'Un contrato incompatible puede impedir el reemplazo o cambiar la seguridad del flujo.'
  from required_function_contract_state
  union all
  select
    'FUNCTION_OVERLOAD_DRIFT',
    case when count(*) filter (where actual_count <> expected_count) = 0
      then 'PASS' else 'BLOCKED' end,
    'mismatches=' || count(*) filter (
      where actual_count <> expected_count
    )::text ||
      coalesce(
        '; names=' || pg_catalog.string_agg(
          function_schema || '.' || function_name ||
            '(expected=' || expected_count::text ||
            ',actual=' || actual_count::text || ')',
          ',' order by function_schema, function_name
        ) filter (where actual_count <> expected_count),
        ''
      ),
    'mismatches=0',
    'HIGH',
    'Una sobrecarga inesperada puede volver ambigua la resolucion RPC de PostgREST.'
  from function_count_state
  union all
  select
    'RPC_EXECUTE_PREREQUISITES',
    case when count(*) filter (
      where not executable
         or not direct_grant
         or public_execute
         or anon_execute
    ) = 0
      then 'PASS' else 'BLOCKED' end,
    'invalid_acl=' || count(*) filter (
      where not executable
         or not direct_grant
         or public_execute
         or anon_execute
    )::text ||
      coalesce(
        '; contracts=' || pg_catalog.string_agg(
          signature || '@' || role_name, ',' order by role_name, signature
        ) filter (
          where not executable
             or not direct_grant
             or public_execute
             or anon_execute
        ),
        ''
      ),
    'invalid_acl=0; expected role direct ' ||
      (chr(69)||chr(88)||chr(69)||chr(67)||chr(85)||chr(84)||chr(69)) ||
      '; PUBLIC/anon false',
    'CRITICAL',
    'Estos ' || (chr(69)||chr(88)||chr(69)||chr(67)||chr(85)||chr(84)||chr(69)) ||
      ' ya deben existir; las nuevas RPC de 0033 se concederan despues.'
  from execute_state
  union all
  select
    'FUNCTION_PRESTATE_FINGERPRINT',
    'BASELINE_REQUIRED',
    'count=' || function_count::text || '; md5=' || fingerprint,
    'exact match with the approved detailed-precheck function baseline',
    'HIGH',
    'Comparar el hash con la evidencia previa para detectar cuerpos adelantados sin exponer definiciones.'
  from required_function_fingerprint
  union all
  select
    'REQUIRED_AUDIT_AND_SCOPE_TRIGGERS',
    case when count(*) filter (
      where not trigger_exists
         or tgenabled is distinct from 'O'
         or tgtype is distinct from expected_tgtype
         or (
           expected_definition_fragment is not null
           and pg_catalog.strpos(
             pg_catalog.lower(coalesce(trigger_definition, '')),
             pg_catalog.lower(expected_definition_fragment)
           ) = 0
         )
         or installed_function is distinct from expected_function
    ) = 0 then 'PASS' else 'BLOCKED' end,
    'invalid=' || count(*) filter (
      where not trigger_exists
         or tgenabled is distinct from 'O'
         or tgtype is distinct from expected_tgtype
         or (
           expected_definition_fragment is not null
           and pg_catalog.strpos(
             pg_catalog.lower(coalesce(trigger_definition, '')),
             pg_catalog.lower(expected_definition_fragment)
           ) = 0
         )
         or installed_function is distinct from expected_function
    )::text ||
      coalesce(
        '; names=' || pg_catalog.string_agg(
          relation_name || '.' || trigger_name,
          ',' order by relation_name, trigger_name
        ) filter (
          where not trigger_exists
             or tgenabled is distinct from 'O'
             or tgtype is distinct from expected_tgtype
             or (
               expected_definition_fragment is not null
               and pg_catalog.strpos(
                 pg_catalog.lower(coalesce(trigger_definition, '')),
                 pg_catalog.lower(expected_definition_fragment)
               ) = 0
             )
             or installed_function is distinct from expected_function
        ),
        ''
      ),
    'invalid=0',
    'CRITICAL',
    '0033 y 0034 reemplazan funciones, pero no crean estos triggers heredados.'
  from trigger_state
  union all
  select
    'FUTURE_FUNCTIONS_CREATED_BY_0033',
    case when count(*) filter (where function_exists) = 0 then 'PASS' else 'BLOCKED' end,
    'present_before_history=' || count(*) filter (where function_exists)::text ||
      coalesce(
        '; signatures=' || pg_catalog.string_agg(
          signature, ',' order by signature
        ) filter (where function_exists),
        ''
      ),
    'present_before_history=0; created by 0033 later',
    'HIGH',
    'Ausencia es el estado esperado; presencia sin history de 0033 es drift parcial.'
  from future_function_state
  union all
  select
    'FUTURE_INDEXES_CREATED_BY_0033',
    case when count(*) filter (where index_exists) = 0 then 'PASS' else 'BLOCKED' end,
    'present_before_history=' || count(*) filter (where index_exists)::text ||
      coalesce(
        '; names=' || pg_catalog.string_agg(
          index_name, ',' order by index_name
        ) filter (where index_exists),
        ''
      ),
    'present_before_history=0; created by 0033 later',
    'HIGH',
    'Un homonimo adelantado puede ocultar una definicion incompatible.'
  from future_index_state
  union all
  select
    '0033_BACKFILL_CANDIDATES',
    case when candidates = 0 then 'PASS' else 'BLOCKED' end,
    candidates::text,
    '0',
    'CRITICAL',
    'Con candidatos, el backfill de 0033 puede activar la funcion auditora antigua antes de 0034.'
  from backfill_metric
  union all
  select
    check_name,
    case when duplicate_groups = 0 then 'PASS' else 'BLOCKED' end,
    duplicate_groups::text,
    '0',
    'CRITICAL',
    'Eliminar la causa del duplicado antes de crear indices o depender de claves unicas.'
  from duplicate_metrics
  union all
  select
    'LINK_PROFILES_WITHOUT_AUTH',
    case when profiles_without_auth = 0 then 'PASS' else 'BLOCKED' end,
    profiles_without_auth::text,
    '0',
    'CRITICAL',
    'Un perfil sin identidad Auth contradice el vinculo 1:1 esperado.'
  from link_metrics
  union all
  select
    'LINK_AUTH_WITHOUT_PROFILE',
    case when auth_without_profile = 0 then 'PASS' else 'WARNING' end,
    auth_without_profile::text,
    '0 or every exception explicitly explained',
    'MEDIUM',
    'Revisar identidades parciales o intencionales sin copiar UUID ni correo.'
  from link_metrics
  union all
  select
    check_name,
    case when invalid_rows = 0 then 'PASS' else 'BLOCKED' end,
    invalid_rows::text,
    '0',
    severity,
    'Corregir la inconsistencia o documentar una remediacion aprobada antes de migrar.'
  from multi_company_metrics
  union all
  select
    'ACTIVE_EXACT_ADMIN_ROLE',
    case when active_exact_admin > 0 then 'PASS' else 'BLOCKED' end,
    active_exact_admin::text,
    'at least 1 active role with upper(code)=ADMIN',
    'CRITICAL',
    '0031 y 0032 no crean el rol ADMIN.'
  from role_metrics
  union all
  select
    'ACTIVE_EXACT_SUPERVISOR_ROLE',
    case when active_exact_supervisor > 0 then 'PASS' else 'BLOCKED' end,
    active_exact_supervisor::text,
    'at least 1 active role with upper(code)=SUPERVISOR',
    'CRITICAL',
    '0032 no crea el rol SUPERVISOR y el smoke test requiere uno viable.'
  from role_metrics
  union all
  select
    'ACTIVE_COMPANY_ROLE_COVERAGE',
    case
      when active_companies_missing_admin = 0
       and active_companies_missing_supervisor = 0 then 'PASS'
      else 'WARNING'
    end,
    'companies_missing_admin=' || active_companies_missing_admin::text ||
      '; companies_missing_supervisor=' || active_companies_missing_supervisor::text,
    '0 gaps, or each tenant exception explicitly approved',
    'HIGH',
    '0031 y 0032 no crean roles; revisar cobertura por empresa sin copiar identificadores.'
  from role_metrics
  union all
  select
    'ROLE_CANONICAL_ALIASES_NOT_TARGETED',
    case when active_aliases_not_targeted = 0 then 'PASS' else 'BLOCKED' end,
    active_aliases_not_targeted::text,
    '0',
    'HIGH',
    '0031 y 0032 usan upper(code) exacto; los aliases canonicos quedarian fuera.'
  from role_metrics
  union all
  select
    '0030_EMPLOYEE_ALIAS_IMPACT',
    case when employee_alias_profiles = 0 then 'PASS' else 'WARNING' end,
    employee_alias_profiles::text,
    '0 profiles change canonical authorization behavior',
    'MEDIUM',
    '0030 incorpora EMPLEADOS y EMPLOYEES; validar el impacto agregado antes del dry-run.'
  from role_metrics
  union all
  select
    'PERMISSION_' || code,
    case
      when source = 'PREREQUISITE' and (
        permission_rows <> 1
        or not all_active
        or supervisor_allowed_department <>
          (select active_exact_supervisor from role_metrics)
      ) then 'BLOCKED'
      when permission_rows > 1 then 'BLOCKED'
      when source <> 'PREREQUISITE' and permission_rows = 0 then 'PASS'
      when source <> 'PREREQUISITE' and not metadata_matches then 'WARNING'
      else 'PASS'
    end,
    'rows=' || permission_rows::text ||
      '; active=' || all_active::text ||
      '; assignments=' || assignment_count::text ||
      '; admin_allowed=' || admin_allowed::text ||
      '; supervisor_allowed=' || supervisor_allowed::text ||
      '; supervisor_allowed_department=' ||
        supervisor_allowed_department::text,
    case
      when source = 'PREREQUISITE'
        then 'CURRENT exists=true; active=true; every active exact SUPERVISOR allowed=true/alcance=departamento'
      else 'AFTER_' || source ||
        ' exists=true; active=true; metadata versioned; target assignments true/empresa'
    end,
    case when source = 'PREREQUISITE' then 'CRITICAL' else 'HIGH' end,
    case
      when source = 'PREREQUISITE'
        then 'Este permiso no lo crean 0031 ni 0032; cualquier ausencia es bloqueante.'
      when permission_rows = 0
        then 'Ausencia esperada: la migracion indicada lo crea de forma idempotente.'
      when not metadata_matches
        then 'La migracion indicada actualizara una fila legacy; revisar sus asignaciones actuales.'
      else 'Catalogo actual compatible; las asignaciones objetivo se completaran idempotentemente.'
    end
  from permission_catalog_state
  union all
  select
    'PERMISSION_LEGACY_NON_TARGET_REACTIVATION',
    case when non_target_assignments_reactivated = 0 then 'PASS' else 'WARNING' end,
    non_target_assignments_reactivated::text,
    '0 non-target allowed assignments activated by catalog reactivation',
    'HIGH',
    'Revisar roles no objetivo antes de reactivar un permiso legacy.'
  from permission_change_metrics
  union all
  select
    'PERMISSION_TARGET_ASSIGNMENTS_REWRITTEN',
    case when existing_target_assignments_rewritten = 0 then 'PASS' else 'WARNING' end,
    existing_target_assignments_rewritten::text,
    '0 existing target assignments require rewrite',
    'MEDIUM',
    '0031 o 0032 normalizara permitido=true y alcance=empresa en estas filas existentes.'
  from permission_change_metrics
  union all
  select
    'PERMISSION_PROFILE_DENIALS',
    case when relevant_profile_denials = 0 then 'PASS' else 'WARNING' end,
    relevant_profile_denials::text,
    '0, or each direct profile denial explicitly accepted',
    'MEDIUM',
    'Las denegaciones de perfil prevalecen sobre el rol; revisar sin exponer identidades.'
  from permission_change_metrics
  union all
  select
    'SERVICE_ROLE_' || pg_catalog.upper(relation_name),
    case
      when (select not service_role_exists from service_auxiliary_state)
        then 'BLOCKED'
      when dangerous_excess > 0 or direct_count = 7 or effective_count = 7
        then 'BLOCKED'
      when expected_mismatches > 0 then 'WARNING'
      else 'PASS'
    end,
    'CURRENT ' || current_privileges,
    'EXPECTED_AFTER_0036 ' || expected_after_0036,
    case
      when relation_name in ('perfil_sucursales', 'perfil_departamentos', 'empleados')
        then 'CRITICAL'
      else 'HIGH'
    end,
    case
      when dangerous_excess > 0 or direct_count = 7 or effective_count = 7
      then 'Privilegio efectivo peligroso: detener y resolver tambien herencia o PUBLIC; 0036 debe cerrar la matriz final.'
      when expected_mismatches > 0
        then 'La diferencia no bloquea por si sola: 0035-0036 deben llevarla al estado minimo esperado.'
      else 'Estado actual compatible con el contrato final de 0036.'
    end
  from service_table_state
  union all
  select
    'SERVICE_ROLE_UNEXPECTED_FULL_PRIVILEGE_SET',
    case when count(*) filter (
      where direct_count = 7 or effective_count = 7
    ) = 0 then 'PASS' else 'BLOCKED' end,
    count(*) filter (
      where direct_count = 7 or effective_count = 7
    )::text,
    '0 tables with all seven table privileges',
    'CRITICAL',
    'PostgreSQL expande concesiones por conjunto; se detecta por el conjunto completo, no por texto ACL.'
  from service_table_state
  union all
  select
    'SERVICE_ROLE_PUBLIC_SCHEMA_USAGE',
    case when public_schema_usage then 'PASS' else 'BLOCKED' end,
    coalesce(public_schema_usage::text, 'NULL'),
    'true',
    'CRITICAL',
    'Las Edge necesitan USAGE de public para resolver tablas y RPC.'
  from service_auxiliary_state
  union all
  select
    'SERVICE_ROLE_COMPANIES_SELECT_DEPENDENCY',
    case when companies_select then 'PASS' else 'BLOCKED' end,
    coalesce(companies_select::text, 'NULL'),
    'true while user-provisioning action=list remains supported',
    'HIGH',
    '0035-0036 no modifican este privilegio legacy; confirmar el contrato antes de promover.'
  from service_auxiliary_state
  union all
  select
    'RLS_CRITICAL_TABLES',
    case when count(*) filter (where not relation_exists or not rls_enabled) = 0
      then 'PASS' else 'BLOCKED' end,
    'missing_or_disabled=' || count(*) filter (
      where not relation_exists or not rls_enabled
    )::text ||
      coalesce(
        '; names=' || pg_catalog.string_agg(
          relation_name, ',' order by relation_name
        ) filter (where not relation_exists or not rls_enabled),
        ''
      ),
    'missing_or_disabled=0',
    'CRITICAL',
    '0030-0036 no cambian RLS; cualquier tabla sin RLS es drift previo.'
  from rls_state
  union all
  select
    'POLICY_CRITICAL_COVERAGE',
    case when missing_expected_policies = 0 then 'PASS' else 'BLOCKED' end,
    'missing_expected_policies=' || missing_expected_policies::text ||
      coalesce('; names=' || missing_policy_names, ''),
    'missing_expected_policies=0',
    'CRITICAL',
    'Las migraciones pendientes no crean policies; una ausencia debe resolverse antes.'
  from policy_summary
  union all
  select
    'POLICY_CRITICAL_FINGERPRINTS',
    'BASELINE_REQUIRED',
    fingerprints,
    'exact match with the approved pre-promotion policy baseline',
    'HIGH',
    'Comparar solo estos hashes con la evidencia aprobada; no copiar definiciones ni identificadores.'
  from policy_summary
  union all
  select
    'EDGE_FUNCTIONS_BASELINE',
    'BASELINE_REQUIRED',
    'not verifiable completely from SQL',
    'versions, secret names, verify_jwt and previous rollback version captured',
    'CRITICAL',
    'Verificar user-provisioning y employee-management fuera de SQL sin mostrar valores de secrets.'
  union all
  select
    'BACKUP_PITR_BASELINE',
    'BASELINE_REQUIRED',
    'not verifiable from this SQL',
    'backup/PITR timestamp, retention, owner and restore point verified',
    'CRITICAL',
    'No continuar a una promocion sin punto de restauracion verificable.'
),
decision_counts as (
  select
    count(*) filter (where status = 'BLOCKED')::bigint as blocked_count,
    count(*) filter (where status = 'WARNING')::bigint as warning_count,
    count(*) filter (where status = 'BASELINE_REQUIRED')::bigint
      as baseline_required_count,
    count(*) filter (where status = 'PASS')::bigint as pass_count
  from checks
),
final_check(check_name, status, actual_value, expected_value, severity, instruction) as (
  select
    'FINAL_DECISION'::text,
    case
      when blocked_count > 0 then 'BLOCKED'
      when warning_count > 0 then 'WARNING'
      when baseline_required_count > 0 then 'BASELINE_REQUIRED'
      else 'PASS'
    end,
    'blocked=' || blocked_count::text ||
      '; warning=' || warning_count::text ||
      '; baseline_required=' || baseline_required_count::text ||
      '; pass=' || pass_count::text,
    'blocked=0; warning=0; external baselines completed before GO',
    'SUMMARY'::text,
    case
      when blocked_count > 0
        then 'NO-GO de base de datos: resolver todos los BLOCKED y repetir el precheck.'
      when warning_count > 0
        then 'Requiere decision documentada sobre WARNING y completar todos los baselines externos; no es GO.'
      when baseline_required_count > 0
        then 'Checks SQL sin bloqueos ni advertencias, pero faltan gates externos indispensables; no es GO.'
      else 'Checks SQL correctos; aun se requiere la aprobacion operativa externa antes de GO.'
    end
  from decision_counts
),
all_rows as (
  select * from checks
  union all
  select * from final_check
)
select
  a.check_name,
  a.status,
  a.actual_value,
  a.expected_value,
  a.severity,
  a.instruction
from all_rows a
left join severity_order s on s.severity = a.severity
order by
  case when a.check_name = 'FINAL_DECISION' then 1 else 0 end,
  s.severity_rank,
  a.check_name;
