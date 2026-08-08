-- Contrato de regresion para el orden corregido 0033 -> 0034.
-- La suite recrea transitoriamente el defecto de 0009, reinstala la definicion
-- segura antes del backfill y revierte todo al finalizar. Nunca usar en produccion.

begin;
select plan(57);

-- Contratos estructurales de la correccion.
select has_function('public', 'auditar_asignacion_supervisor', array[]::text[]);
select has_function('public', 'crear_acceso_con_alcance_internal', array['jsonb']);
select has_function('public', 'guardar_alcance_supervisor_internal', array['jsonb']);
select has_function('public', 'cambiar_estado_acceso_con_alcance_internal', array['jsonb']);
select has_function('public', 'actualizar_acceso_con_alcance_internal', array['jsonb']);

select ok(
  (
    select p.prosecdef
    from pg_catalog.pg_proc p
    where p.oid = 'public.auditar_asignacion_supervisor()'::regprocedure
  ),
  'la funcion trigger corregida conserva SECURITY DEFINER'
);

select ok(
  (
    select coalesce(pg_catalog.array_to_string(p.proconfig, ','), '') like '%search_path=%'
    from pg_catalog.pg_proc p
    where p.oid = 'public.auditar_asignacion_supervisor()'::regprocedure
  ),
  'la funcion trigger corregida fija search_path'
);

select ok(
  exists(
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'perfil_sucursales'
      and c.column_name = 'sucursal_id'
  )
  and not exists(
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'perfil_sucursales'
      and c.column_name = 'departamento_id'
  )
  and exists(
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'perfil_departamentos'
      and c.column_name = 'departamento_id'
  )
  and not exists(
    select 1
    from information_schema.columns c
    where c.table_schema = 'public'
      and c.table_name = 'perfil_departamentos'
      and c.column_name = 'sucursal_id'
  ),
  'cada tabla de alcance expone unicamente su columna real de entidad'
);

-- Fixture aislado 34000000.
insert into auth.users(
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '34000000-0000-0000-0000-000000000100', 'authenticated', 'authenticated',
    'admin-0034@scope.test', 'not-used', now(), '{}', '{}', now(), now()
  ),
  (
    '34000000-0000-0000-0000-000000000101', 'authenticated', 'authenticated',
    'supervisor-one-0034@scope.test', 'not-used', now(), '{}', '{}', now(), now()
  ),
  (
    '34000000-0000-0000-0000-000000000102', 'authenticated', 'authenticated',
    'supervisor-many-0034@scope.test', 'not-used', now(), '{}', '{}', now(), now()
  ),
  (
    '34000000-0000-0000-0000-000000000103', 'authenticated', 'authenticated',
    'supervisor-direct-0034@scope.test', 'not-used', now(), '{}', '{}', now(), now()
  ),
  (
    '34000000-0000-0000-0000-000000000109', 'authenticated', 'authenticated',
    'supervisor-retry-0034@scope.test', 'not-used', now(), '{}', '{}', now(), now()
  );

insert into public.companies(id, name, slug, status)
values(
  '34000000-0000-0000-0000-000000000001',
  'Empresa Scope Trigger 0034',
  'empresa-scope-trigger-0034',
  'active'
);

insert into public.roles(id, company_id, name, code, is_active) values
  (
    '34000000-0000-0000-0000-000000000010',
    '34000000-0000-0000-0000-000000000001',
    'Administrador Scope 0034', 'admin', true
  ),
  (
    '34000000-0000-0000-0000-000000000011',
    '34000000-0000-0000-0000-000000000001',
    'Supervisor Scope 0034', 'supervisor', true
  ),
  (
    '34000000-0000-0000-0000-000000000012',
    '34000000-0000-0000-0000-000000000001',
    'Empleado Scope 0034', 'employee', true
  );

insert into public.branches(id, company_id, name, code, is_main, status) values
  (
    '34000000-0000-0000-0000-000000000020',
    '34000000-0000-0000-0000-000000000001',
    'Sucursal A Scope 0034', 'S34A', true, 'active'
  ),
  (
    '34000000-0000-0000-0000-000000000021',
    '34000000-0000-0000-0000-000000000001',
    'Sucursal B Scope 0034', 'S34B', false, 'active'
  );

insert into public.departments(id, company_id, branch_id, name, code, is_active) values
  (
    '34000000-0000-0000-0000-000000000030',
    '34000000-0000-0000-0000-000000000001',
    '34000000-0000-0000-0000-000000000020',
    'Departamento A1 Scope 0034', 'S34A1', true
  ),
  (
    '34000000-0000-0000-0000-000000000031',
    '34000000-0000-0000-0000-000000000001',
    '34000000-0000-0000-0000-000000000020',
    'Departamento A2 Scope 0034', 'S34A2', true
  ),
  (
    '34000000-0000-0000-0000-000000000032',
    '34000000-0000-0000-0000-000000000001',
    '34000000-0000-0000-0000-000000000021',
    'Departamento B1 Scope 0034', 'S34B1', true
  ),
  (
    '34000000-0000-0000-0000-000000000033',
    '34000000-0000-0000-0000-000000000001',
    '34000000-0000-0000-0000-000000000021',
    'Departamento B2 Scope 0034', 'S34B2', true
  );

insert into public.employee_code_sequences(empresa_id, last_value)
values('34000000-0000-0000-0000-000000000001', 340100)
on conflict(empresa_id) do update set last_value = excluded.last_value;

insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id,
  codigo_empleado, nombre_completo, activo
) values (
  '34000000-0000-0000-0000-000000000201',
  '34000000-0000-0000-0000-000000000001',
  '34000000-0000-0000-0000-000000000020',
  '34000000-0000-0000-0000-000000000030',
  '340101', 'Supervisor Uno 0034', true
);

-- El allocator exige continuidad exacta; se insertan en sentencias separadas.
insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id,
  codigo_empleado, nombre_completo, activo
) values (
  '34000000-0000-0000-0000-000000000202',
  '34000000-0000-0000-0000-000000000001',
  '34000000-0000-0000-0000-000000000020',
  '34000000-0000-0000-0000-000000000031',
  '340102', 'Supervisor Varios 0034', true
);

insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id,
  codigo_empleado, nombre_completo, activo
) values (
  '34000000-0000-0000-0000-000000000209',
  '34000000-0000-0000-0000-000000000001',
  '34000000-0000-0000-0000-000000000020',
  '34000000-0000-0000-0000-000000000030',
  '340103', 'Supervisor Reintento 0034', true
);

insert into public.profiles(id, company_id, role_id, full_name, status) values
  (
    '34000000-0000-0000-0000-000000000100',
    '34000000-0000-0000-0000-000000000001',
    '34000000-0000-0000-0000-000000000010',
    'Administrador Scope 0034', 'active'
  ),
  (
    '34000000-0000-0000-0000-000000000103',
    '34000000-0000-0000-0000-000000000001',
    '34000000-0000-0000-0000-000000000011',
    'Supervisor Directo 0034', 'active'
  );

insert into public.permisos(codigo, nombre, modulo, activo)
values('usuarios.administrar', 'Administrar usuarios', 'administracion', true)
on conflict(codigo) do update set activo = true;

insert into public.rol_permisos(rol_id, permiso_id, permitido, alcance)
select
  '34000000-0000-0000-0000-000000000010',
  p.id,
  true,
  'empresa'
from public.permisos p
where p.codigo = 'usuarios.administrar'
on conflict(rol_id, permiso_id)
do update set permitido = true, alcance = 'empresa';

-- Regresion de orden 0033 -> 0034. Se fabrica un candidato historico sin
-- desactivar triggers: primero se asigna el departamento a un rol no
-- supervisor y despues se canonicaliza el rol. La funcion segura final se
-- conserva para reinstalarla antes de ejecutar el backfill real de 0033.
create temporary table safe_scope_audit_function_definition(
  definition text not null
) on commit drop;

insert into safe_scope_audit_function_definition(definition)
select pg_catalog.pg_get_functiondef(
  'public.auditar_asignacion_supervisor()'::regprocedure
);

insert into auth.users(
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '34000000-0000-0000-0000-000000000104',
  'authenticated',
  'authenticated',
  'historical-backfill-0034@scope.test',
  'not-used',
  now(),
  '{}',
  '{}',
  now(),
  now()
);

insert into public.companies(id, name, slug, status)
values(
  '34000000-0000-0000-0000-000000000002',
  'Empresa Historica Scope 0034',
  'empresa-historica-scope-0034',
  'active'
);

insert into public.roles(id, company_id, name, code, is_active)
values(
  '34000000-0000-0000-0000-000000000013',
  '34000000-0000-0000-0000-000000000002',
  'Rol Historico Scope 0034',
  'employee',
  true
);

insert into public.branches(id, company_id, name, code, is_main, status)
values(
  '34000000-0000-0000-0000-000000000022',
  '34000000-0000-0000-0000-000000000002',
  'Sucursal Historica Scope 0034',
  'S34H',
  true,
  'active'
);

insert into public.departments(
  id, company_id, branch_id, name, code, is_active
) values (
  '34000000-0000-0000-0000-000000000034',
  '34000000-0000-0000-0000-000000000002',
  '34000000-0000-0000-0000-000000000022',
  'Departamento Historico Scope 0034',
  'S34H1',
  true
);

insert into public.profiles(id, company_id, role_id, full_name, status)
values(
  '34000000-0000-0000-0000-000000000104',
  '34000000-0000-0000-0000-000000000002',
  '34000000-0000-0000-0000-000000000013',
  'Supervisor Historico Scope 0034',
  'active'
);

insert into public.perfil_departamentos(perfil_id, departamento_id)
values(
  '34000000-0000-0000-0000-000000000104',
  '34000000-0000-0000-0000-000000000034'
);

update public.roles
set code = 'supervisor'
where id = '34000000-0000-0000-0000-000000000013'
  and company_id = '34000000-0000-0000-0000-000000000002';

select is(
  (
    select count(*)::integer
    from public.perfil_departamentos pd
    join public.profiles pr on pr.id = pd.perfil_id
    join public.roles r
      on r.id = pr.role_id
     and r.company_id = pr.company_id
    where pd.perfil_id = '34000000-0000-0000-0000-000000000104'
      and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
      and not exists(
        select 1
        from public.perfil_sucursales ps
        where ps.perfil_id = pd.perfil_id
      )
  ),
  1,
  'el fixture contiene un candidato historico real para el backfill de 0033'
);

-- Reinstala transitoriamente la definicion heredada de 0009 para demostrar la
-- causa exacta. Todo ocurre dentro de la transaccion pgTAP y se revierte.
create or replace function public.auditar_asignacion_supervisor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $legacy_0009$
declare
  v_profile uuid;
  v_empresa uuid;
  v_rol text;
  v_entidad uuid;
begin
  if tg_op = 'DELETE' then
    v_profile := old.perfil_id;
  else
    v_profile := new.perfil_id;
  end if;

  select p.company_id
  into v_empresa
  from public.profiles p
  where p.id = v_profile;

  select r.code
  into v_rol
  from public.profiles p
  join public.roles r
    on r.id = p.role_id
   and r.company_id = p.company_id
  where p.id = (select auth.uid());

  if tg_op = 'DELETE' then
    v_entidad := case
      when tg_table_name = 'perfil_sucursales' then old.sucursal_id
      else old.departamento_id
    end;
  else
    v_entidad := case
      when tg_table_name = 'perfil_sucursales' then new.sucursal_id
      else new.departamento_id
    end;
  end if;

  insert into public.supervisor_auditoria(
    empresa_id, actor_id, actor_rol, entidad, entidad_id,
    accion, antes, despues, motivo
  ) values (
    v_empresa,
    (select auth.uid()),
    coalesce(v_rol, 'service_role'),
    tg_table_name,
    v_entidad,
    tg_op,
    case when tg_op = 'INSERT' then null else pg_catalog.to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else pg_catalog.to_jsonb(new) end,
    'Asignacion de alcance de supervisor'
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$legacy_0009$;

select ok(
  pg_catalog.pg_get_functiondef(
    'public.auditar_asignacion_supervisor()'::regprocedure
  ) ~* 'v_entidad[[:space:]]*:=[[:space:]]*CASE',
  'el estado inicial de regresion reinstala la expresion defectuosa de 0009'
);

select throws_ok(
  $$
    insert into public.perfil_sucursales(perfil_id, sucursal_id)
    select distinct pd.perfil_id, d.branch_id
    from public.perfil_departamentos pd
    join public.profiles pr on pr.id = pd.perfil_id
    join public.roles r
      on r.id = pr.role_id
     and r.company_id = pr.company_id
    join public.departments d
      on d.id = pd.departamento_id
     and d.company_id = pr.company_id
    join public.branches b
      on b.id = d.branch_id
     and b.company_id = pr.company_id
    where private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
      and pd.perfil_id = '34000000-0000-0000-0000-000000000104'
      and d.branch_id is not null
      and not exists(
        select 1
        from public.perfil_sucursales existing
        where existing.perfil_id = pd.perfil_id
          and existing.sucursal_id = d.branch_id
      )
    on conflict(perfil_id, sucursal_id) do nothing
  $$,
  '42703',
  'record "new" has no field "departamento_id"',
  'la definicion heredada reproduce el 42703 del backfill anterior'
);

do $restore_safe_scope_audit$
declare
  v_definition text;
begin
  select definition
  into strict v_definition
  from safe_scope_audit_function_definition;

  execute v_definition;
end;
$restore_safe_scope_audit$;

select ok(
  pg_catalog.pg_get_functiondef(
    'public.auditar_asignacion_supervisor()'::regprocedure
  ) like '%if tg_table_name = ''perfil_sucursales'' then%'
  and pg_catalog.pg_get_functiondef(
    'public.auditar_asignacion_supervisor()'::regprocedure
  ) like '%elsif tg_table_name = ''perfil_departamentos'' then%',
  'la definicion segura se instala antes de reintentar el backfill'
);

select lives_ok(
  $$
    insert into public.perfil_sucursales(perfil_id, sucursal_id)
    select distinct pd.perfil_id, d.branch_id
    from public.perfil_departamentos pd
    join public.profiles pr on pr.id = pd.perfil_id
    join public.roles r
      on r.id = pr.role_id
     and r.company_id = pr.company_id
    join public.departments d
      on d.id = pd.departamento_id
     and d.company_id = pr.company_id
    join public.branches b
      on b.id = d.branch_id
     and b.company_id = pr.company_id
    where private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
      and pd.perfil_id = '34000000-0000-0000-0000-000000000104'
      and d.branch_id is not null
      and not exists(
        select 1
        from public.perfil_sucursales existing
        where existing.perfil_id = pd.perfil_id
          and existing.sucursal_id = d.branch_id
      )
    on conflict(perfil_id, sucursal_id) do nothing
  $$,
  'el backfill de 0033 termina sin 42703 despues de instalar la funcion segura'
);

select ok(
  exists(
    select 1
    from public.perfil_sucursales ps
    join public.profiles pr on pr.id = ps.perfil_id
    join public.branches b on b.id = ps.sucursal_id
    where ps.perfil_id = '34000000-0000-0000-0000-000000000104'
      and ps.sucursal_id = '34000000-0000-0000-0000-000000000022'
      and pr.company_id = '34000000-0000-0000-0000-000000000002'
      and b.company_id = pr.company_id
  )
  and not exists(
    select 1
    from public.perfil_sucursales ps
    join public.branches b on b.id = ps.sucursal_id
    where ps.perfil_id = '34000000-0000-0000-0000-000000000104'
      and b.company_id <> '34000000-0000-0000-0000-000000000002'
  ),
  'el backfill conserva aislamiento por empresa y asigna solo la sucursal valida'
);

select is(
  (
    select count(*)::integer
    from public.supervisor_auditoria sa
    where sa.empresa_id = '34000000-0000-0000-0000-000000000002'
      and sa.entidad = 'perfil_sucursales'
      and sa.entidad_id = '34000000-0000-0000-0000-000000000022'
      and sa.accion = 'INSERT'
      and sa.antes is null
      and sa.despues ->> 'perfil_id'
        = '34000000-0000-0000-0000-000000000104'
  ),
  1,
  'el backfill corregido conserva la auditoria INSERT de la sucursal'
);

-- 1. Crear SUPERVISOR con una sucursal y un departamento.
select lives_ok(
  $$
    select public.crear_acceso_con_alcance_internal(jsonb_build_object(
      'actor_user_id', '34000000-0000-0000-0000-000000000100',
      'user_id', '34000000-0000-0000-0000-000000000101',
      'employee_id', '34000000-0000-0000-0000-000000000201',
      'role_id', '34000000-0000-0000-0000-000000000011',
      'status', 'active',
      'idempotency_key', '34000000-0000-0000-0000-000000001001',
      'branch_id', '34000000-0000-0000-0000-000000000020',
      'department_ids', jsonb_build_array(
        '34000000-0000-0000-0000-000000000030'
      )
    ))
  $$,
  'crear_acceso_con_alcance_internal crea un supervisor con un departamento sin 42703'
);

select is(
  (
    select count(*)::integer
    from public.perfil_sucursales
    where perfil_id = '34000000-0000-0000-0000-000000000101'
  ),
  1,
  'la creacion simple persiste exactamente una sucursal'
);

select is(
  (
    select count(*)::integer
    from public.perfil_departamentos
    where perfil_id = '34000000-0000-0000-0000-000000000101'
  ),
  1,
  'la creacion simple persiste exactamente un departamento'
);

select is(
  (
    select count(*)::integer
    from public.supervisor_auditoria sa
    where coalesce(sa.despues, sa.antes) ->> 'perfil_id'
      = '34000000-0000-0000-0000-000000000101'
      and sa.accion = 'INSERT'
  ),
  2,
  'la creacion simple audita INSERT de sucursal y departamento'
);

-- 2. Crear SUPERVISOR con varios departamentos de la misma sucursal.
select lives_ok(
  $$
    select public.crear_acceso_con_alcance_internal(jsonb_build_object(
      'actor_user_id', '34000000-0000-0000-0000-000000000100',
      'user_id', '34000000-0000-0000-0000-000000000102',
      'employee_id', '34000000-0000-0000-0000-000000000202',
      'role_id', '34000000-0000-0000-0000-000000000011',
      'status', 'active',
      'idempotency_key', '34000000-0000-0000-0000-000000001002',
      'branch_id', '34000000-0000-0000-0000-000000000020',
      'department_ids', jsonb_build_array(
        '34000000-0000-0000-0000-000000000030',
        '34000000-0000-0000-0000-000000000031',
        '34000000-0000-0000-0000-000000000030'
      )
    ))
  $$,
  'crear_acceso_con_alcance_internal crea varios departamentos sin 42703'
);

select is(
  (
    select count(*)::integer
    from public.perfil_sucursales
    where perfil_id = '34000000-0000-0000-0000-000000000102'
  ),
  1,
  'la creacion multiple conserva una sola sucursal'
);

select is(
  (
    select count(*)::integer
    from public.perfil_departamentos
    where perfil_id = '34000000-0000-0000-0000-000000000102'
  ),
  2,
  'la creacion multiple deduplica y persiste dos departamentos'
);

select is(
  (
    select count(*)::integer
    from public.supervisor_auditoria sa
    where coalesce(sa.despues, sa.antes) ->> 'perfil_id'
      = '34000000-0000-0000-0000-000000000102'
      and sa.accion = 'INSERT'
  ),
  3,
  'la creacion multiple audita una sucursal y dos departamentos'
);

-- 3. INSERT directo en perfil_sucursales usa NEW.sucursal_id.
select lives_ok(
  $$
    insert into public.perfil_sucursales(perfil_id, sucursal_id)
    values(
      '34000000-0000-0000-0000-000000000103',
      '34000000-0000-0000-0000-000000000020'
    )
  $$,
  'INSERT de perfil_sucursales no intenta leer NEW.departamento_id'
);

select ok(
  exists(
    select 1
    from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_sucursales'
      and sa.entidad_id = '34000000-0000-0000-0000-000000000020'
      and sa.accion = 'INSERT'
      and sa.antes is null
      and sa.despues ->> 'perfil_id' = '34000000-0000-0000-0000-000000000103'
      and sa.despues ->> 'sucursal_id' = '34000000-0000-0000-0000-000000000020'
  ),
  'la auditoria de sucursal INSERT conserva la entidad real'
);

-- 5. Actualizar asignaciones cubre las columnas OLD/NEW de cada tabla.
-- 5a. UPDATE directo de sucursal.
select lives_ok(
  $$
    update public.perfil_sucursales
    set sucursal_id = '34000000-0000-0000-0000-000000000021'
    where perfil_id = '34000000-0000-0000-0000-000000000103'
      and sucursal_id = '34000000-0000-0000-0000-000000000020'
  $$,
  'UPDATE de perfil_sucursales usa solamente columnas de sucursal'
);

select ok(
  exists(
    select 1
    from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_sucursales'
      and sa.accion = 'UPDATE'
      and sa.antes ->> 'sucursal_id' = '34000000-0000-0000-0000-000000000020'
      and sa.despues ->> 'sucursal_id' = '34000000-0000-0000-0000-000000000021'
      and sa.despues ->> 'perfil_id' = '34000000-0000-0000-0000-000000000103'
  ),
  'la auditoria de sucursal UPDATE conserva antes y despues'
);

-- 4. INSERT directo en perfil_departamentos usa NEW.departamento_id.
select lives_ok(
  $$
    insert into public.perfil_departamentos(perfil_id, departamento_id)
    values(
      '34000000-0000-0000-0000-000000000103',
      '34000000-0000-0000-0000-000000000032'
    )
  $$,
  'INSERT de perfil_departamentos no intenta leer NEW.sucursal_id'
);

select ok(
  exists(
    select 1
    from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_departamentos'
      and sa.entidad_id = '34000000-0000-0000-0000-000000000032'
      and sa.accion = 'INSERT'
      and sa.antes is null
      and sa.despues ->> 'perfil_id' = '34000000-0000-0000-0000-000000000103'
      and sa.despues ->> 'departamento_id' = '34000000-0000-0000-0000-000000000032'
  ),
  'la auditoria de departamento INSERT conserva la entidad real'
);

-- 5b. UPDATE directo de departamento cubre OLD/NEW.departamento_id.
select lives_ok(
  $$
    update public.perfil_departamentos
    set departamento_id = '34000000-0000-0000-0000-000000000033'
    where perfil_id = '34000000-0000-0000-0000-000000000103'
      and departamento_id = '34000000-0000-0000-0000-000000000032'
  $$,
  'UPDATE de perfil_departamentos usa solamente columnas de departamento'
);

select ok(
  exists(
    select 1
    from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_departamentos'
      and sa.accion = 'UPDATE'
      and sa.antes ->> 'departamento_id' = '34000000-0000-0000-0000-000000000032'
      and sa.despues ->> 'departamento_id' = '34000000-0000-0000-0000-000000000033'
      and sa.despues ->> 'perfil_id' = '34000000-0000-0000-0000-000000000103'
  ),
  'la auditoria de departamento UPDATE conserva antes y despues'
);

-- 6. Las asignaciones no tienen is_active: desactivar significa cerrar el perfil.
select lives_ok(
  $$
    select public.cambiar_estado_acceso_con_alcance_internal(jsonb_build_object(
      'actor_user_id', '34000000-0000-0000-0000-000000000100',
      'profile_id', '34000000-0000-0000-0000-000000000103',
      'status', 'inactive'
    ))
  $$,
  'desactivar un supervisor con alcance no ejecuta columnas inexistentes'
);

select is(
  (
    select status
    from public.profiles
    where id = '34000000-0000-0000-0000-000000000103'
  ),
  'inactive',
  'la desactivacion se persiste en profiles'
);

select ok(
  (
    select count(*) = 1
    from public.perfil_sucursales
    where perfil_id = '34000000-0000-0000-0000-000000000103'
  )
  and (
    select count(*) = 1
    from public.perfil_departamentos
    where perfil_id = '34000000-0000-0000-0000-000000000103'
  ),
  'la desactivacion conserva relaciones historicas sin convertirlas en alcance efectivo'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '34000000-0000-0000-0000-000000000103',
  true
);
select is(
  (select count(*)::integer from public.obtener_departamentos_supervisor_actual()),
  0,
  'un supervisor inactivo no recibe departamentos efectivos'
);
reset role;
select set_config('request.jwt.claim.sub', '', true);

select lives_ok(
  $$
    select public.cambiar_estado_acceso_con_alcance_internal(jsonb_build_object(
      'actor_user_id', '34000000-0000-0000-0000-000000000100',
      'profile_id', '34000000-0000-0000-0000-000000000103',
      'status', 'active'
    ))
  $$,
  'reactivar un supervisor con alcance valido permanece operativo'
);

-- 7. Reemplazar alcance recorre DELETE con OLD y luego INSERT con NEW.
select lives_ok(
  $$
    select public.guardar_alcance_supervisor_internal(jsonb_build_object(
      'actor_user_id', '34000000-0000-0000-0000-000000000100',
      'profile_id', '34000000-0000-0000-0000-000000000103',
      'branch_id', '34000000-0000-0000-0000-000000000020',
      'department_ids', jsonb_build_array(
        '34000000-0000-0000-0000-000000000030'
      )
    ))
  $$,
  'reemplazar alcance elimina y crea relaciones sin 42703'
);

select ok(
  (
    select count(*) = 1
    from public.perfil_sucursales ps
    where ps.perfil_id = '34000000-0000-0000-0000-000000000103'
      and ps.sucursal_id = '34000000-0000-0000-0000-000000000020'
  ),
  'el reemplazo conserva exactamente la nueva sucursal'
);

select ok(
  (
    select count(*) = 1
    from public.perfil_departamentos pd
    where pd.perfil_id = '34000000-0000-0000-0000-000000000103'
      and pd.departamento_id = '34000000-0000-0000-0000-000000000030'
  ),
  'el reemplazo conserva exactamente el nuevo departamento'
);

select ok(
  exists(
    select 1
    from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_sucursales'
      and sa.accion = 'DELETE'
      and sa.antes ->> 'perfil_id' = '34000000-0000-0000-0000-000000000103'
      and sa.antes ->> 'sucursal_id' = '34000000-0000-0000-0000-000000000021'
      and sa.despues is null
  )
  and exists(
    select 1
    from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_departamentos'
      and sa.accion = 'DELETE'
      and sa.antes ->> 'perfil_id' = '34000000-0000-0000-0000-000000000103'
      and sa.antes ->> 'departamento_id' = '34000000-0000-0000-0000-000000000033'
      and sa.despues is null
  ),
  'el reemplazo audita DELETE con OLD para ambas tablas'
);

select lives_ok(
  $$
    delete from public.perfil_departamentos
    where perfil_id = '34000000-0000-0000-0000-000000000103'
      and departamento_id = '34000000-0000-0000-0000-000000000030'
  $$,
  'DELETE directo de perfil_departamentos usa OLD.departamento_id'
);

select lives_ok(
  $$
    delete from public.perfil_sucursales
    where perfil_id = '34000000-0000-0000-0000-000000000103'
      and sucursal_id = '34000000-0000-0000-0000-000000000020'
  $$,
  'DELETE directo de perfil_sucursales usa OLD.sucursal_id'
);

select ok(
  not exists(
    select 1 from public.perfil_sucursales
    where perfil_id = '34000000-0000-0000-0000-000000000103'
  )
  and not exists(
    select 1 from public.perfil_departamentos
    where perfil_id = '34000000-0000-0000-0000-000000000103'
  ),
  'la eliminacion directa retira ambas relaciones sin estado parcial'
);

-- 8. Cambio de rol limpia alcance mediante DELETE de ambas tablas.
select lives_ok(
  $$
    select public.actualizar_acceso_con_alcance_internal(jsonb_build_object(
      'actor_user_id', '34000000-0000-0000-0000-000000000100',
      'profile_id', '34000000-0000-0000-0000-000000000101',
      'employee_id', '34000000-0000-0000-0000-000000000201',
      'role_id', '34000000-0000-0000-0000-000000000012',
      'status', 'active',
      'operation_id', '34000000-0000-0000-0000-000000008001'
    ))
  $$,
  'SUPERVISOR a EMPLEADO limpia alcance sin 42703'
);

select is(
  (
    select role_id
    from public.profiles
    where id = '34000000-0000-0000-0000-000000000101'
  ),
  '34000000-0000-0000-0000-000000000012'::uuid,
  'el cambio de rol persiste el rol solicitado'
);

select ok(
  not exists(
    select 1 from public.perfil_sucursales
    where perfil_id = '34000000-0000-0000-0000-000000000101'
  )
  and not exists(
    select 1 from public.perfil_departamentos
    where perfil_id = '34000000-0000-0000-0000-000000000101'
  ),
  'el trigger de cambio de rol elimina sucursal y departamentos'
);

select ok(
  exists(
    select 1
    from public.administracion_auditoria a
    where a.empresa_id = '34000000-0000-0000-0000-000000000001'
      and a.actor_id = '34000000-0000-0000-0000-000000000100'
      and a.accion = 'ACTUALIZAR_ACCESO'
      and a.entidad_id = '34000000-0000-0000-0000-000000000101'
      and a.despues ->> 'operation_id' = '34000000-0000-0000-0000-000000008001'
  ),
  'el cambio de rol conserva su operation_id transaccional'
);

-- 9. Estado DB posterior a Auth compensado: no quedan Auth/profile/auditoria previos.
-- La eliminacion real mediante Auth Admin pertenece a Edge y se valida aparte en staging.
select ok(
  not exists(
    select 1 from auth.users
    where id = '34000000-0000-0000-0000-000000000108'
  )
  and not exists(
    select 1 from public.profiles
    where id = '34000000-0000-0000-0000-000000000108'
  )
  and not exists(
    select 1
    from public.user_provisioning_audit a
    where a.details ->> 'idempotency_key'
      = '34000000-0000-0000-0000-000000009009'
  ),
  'la simulacion poscompensacion no conserva identidad, profile ni marca DB'
);

select lives_ok(
  $$
    select public.crear_acceso_con_alcance_internal(jsonb_build_object(
      'actor_user_id', '34000000-0000-0000-0000-000000000100',
      'user_id', '34000000-0000-0000-0000-000000000109',
      'employee_id', '34000000-0000-0000-0000-000000000209',
      'role_id', '34000000-0000-0000-0000-000000000011',
      'status', 'active',
      'idempotency_key', '34000000-0000-0000-0000-000000009009',
      'branch_id', '34000000-0000-0000-0000-000000000020',
      'department_ids', jsonb_build_array(
        '34000000-0000-0000-0000-000000000030'
      )
    ))
  $$,
  'el reintento con una nueva identidad Auth completa la transaccion sin 42703'
);

select ok(
  (
    select count(*) = 1
    from public.profiles
    where id = '34000000-0000-0000-0000-000000000109'
  )
  and (
    select count(*) = 1
    from public.user_provisioning_audit a
    where a.company_id = '34000000-0000-0000-0000-000000000001'
      and a.actor_user_id = '34000000-0000-0000-0000-000000000100'
      and a.details ->> 'idempotency_key'
        = '34000000-0000-0000-0000-000000009009'
  ),
  'el reintento crea un solo profile y una sola marca idempotente'
);

select ok(
  public.obtener_creacion_acceso_idempotente_internal(jsonb_build_object(
    'actor_user_id', '34000000-0000-0000-0000-000000000100',
    'employee_id', '34000000-0000-0000-0000-000000000209',
    'role_id', '34000000-0000-0000-0000-000000000011',
    'status', 'active',
    'idempotency_key', '34000000-0000-0000-0000-000000009009',
    'branch_id', '34000000-0000-0000-0000-000000000020',
    'department_ids', jsonb_build_array(
      '34000000-0000-0000-0000-000000000030'
    )
  )) is not null,
  'el lookup idempotente confirma la creacion reintentada'
);

select ok(
  (
    select count(*) = 1
    from public.perfil_sucursales
    where perfil_id = '34000000-0000-0000-0000-000000000109'
  )
  and (
    select count(*) = 1
    from public.perfil_departamentos
    where perfil_id = '34000000-0000-0000-0000-000000000109'
  ),
  'el reintento no duplica las asignaciones de alcance'
);

-- 10. La definicion final elimina el CASE defectuoso y cubre las seis ramas DML.
select ok(
  pg_catalog.strpos(
    lower(pg_catalog.pg_get_functiondef(
      'public.auditar_asignacion_supervisor()'::regprocedure
    )),
    'case when tg_table_name'
  ) = 0,
  'la definicion final no conserva el CASE que resolvia campos inexistentes'
);

select ok(
  pg_catalog.pg_get_functiondef(
    'public.auditar_asignacion_supervisor()'::regprocedure
  ) like '%if tg_table_name = ''perfil_sucursales'' then%'
  and pg_catalog.pg_get_functiondef(
    'public.auditar_asignacion_supervisor()'::regprocedure
  ) like '%elsif tg_table_name = ''perfil_departamentos'' then%',
  'la funcion final separa explicitamente ambas tablas'
);

select ok(
  exists(
    select 1 from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_sucursales'
      and sa.accion = 'INSERT'
      and coalesce(sa.despues, sa.antes) ->> 'perfil_id'
        = '34000000-0000-0000-0000-000000000103'
  )
  and exists(
    select 1 from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_sucursales'
      and sa.accion = 'UPDATE'
      and coalesce(sa.despues, sa.antes) ->> 'perfil_id'
        = '34000000-0000-0000-0000-000000000103'
  )
  and exists(
    select 1 from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_sucursales'
      and sa.accion = 'DELETE'
      and coalesce(sa.despues, sa.antes) ->> 'perfil_id'
        = '34000000-0000-0000-0000-000000000103'
  ),
  'perfil_sucursales audita INSERT, UPDATE y DELETE sin 42703'
);

select ok(
  exists(
    select 1 from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_departamentos'
      and sa.accion = 'INSERT'
      and coalesce(sa.despues, sa.antes) ->> 'perfil_id'
        = '34000000-0000-0000-0000-000000000103'
  )
  and exists(
    select 1 from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_departamentos'
      and sa.accion = 'UPDATE'
      and coalesce(sa.despues, sa.antes) ->> 'perfil_id'
        = '34000000-0000-0000-0000-000000000103'
  )
  and exists(
    select 1 from public.supervisor_auditoria sa
    where sa.entidad = 'perfil_departamentos'
      and sa.accion = 'DELETE'
      and coalesce(sa.despues, sa.antes) ->> 'perfil_id'
        = '34000000-0000-0000-0000-000000000103'
  ),
  'perfil_departamentos audita INSERT, UPDATE y DELETE sin 42703'
);

select is(
  (
    select count(*)::integer
    from pg_catalog.pg_trigger t
    where t.tgname in (
      'perfil_sucursales_audit_rc3',
      'perfil_departamentos_audit_rc3'
    )
      and not t.tgisinternal
      and t.tgenabled <> 'D'
      and t.tgfoid = 'public.auditar_asignacion_supervisor()'::regprocedure
      and t.tgrelid in (
        'public.perfil_sucursales'::regclass,
        'public.perfil_departamentos'::regclass
      )
  ),
  2,
  'ambos triggers instalados apuntan a la funcion corregida y estan habilitados'
);

select * from finish();
rollback;
