begin;

set local search_path = extensions, public, pg_catalog;
set local role postgres;

select * from no_plan();

select has_table('public'::name, 'nomina_plantillas_horario'::name);
select has_table('public'::name, 'nomina_plantilla_horario_versiones'::name);
select has_table('public'::name, 'nomina_plantilla_horario_dias'::name);
select has_table('public'::name, 'nomina_asignaciones_horario'::name);
select has_table('public'::name, 'nomina_condiciones_salariales'::name);
select has_table('public'::name, 'nomina_dias_libres'::name);
select has_table('public'::name, 'nomina_dia_libre_dias'::name);
select has_table('public'::name, 'nomina_coberturas'::name);
select has_table('public'::name, 'nomina_festivos'::name);
select has_table('public'::name, 'nomina_calendario_auditoria'::name);

select ok(
  exists(
    select 1
    from information_schema.columns columna
    where columna.table_schema = 'public'
      and columna.table_name = 'nomina_dias_libres'
      and columna.column_name = 'vigente_desde'
  )
  and not exists(
    select 1
    from information_schema.columns columna
    where columna.table_schema = 'public'
      and columna.table_name = 'nomina_dias_libres'
      and columna.column_name in ('fecha_desde', 'fecha_hasta')
  ),
  'días libres modela vigencia semanal y no fechas libres continuas'
);

select has_function(
  'public', 'puede_operar_empleado_en_alcance', array['uuid', 'text']
);
select has_function(
  'public', 'asignar_plantilla_horario',
  array['uuid', 'uuid', 'date', 'date', 'text']
);
select has_function(
  'public', 'asignar_dias_libres_semanales',
  array['uuid', 'date', 'date', 'smallint[]', 'text', 'text']
);
select has_function(
  'public', 'registrar_cobertura_empleado',
  array['uuid', 'text', 'date', 'date', 'numeric', 'text', 'text']
);
select has_function(
  'public', 'registrar_festivo_empresa', array['date', 'text', 'text']
);

select is(
  (
    select count(*)::integer
    from public.permisos permiso
    where permiso.codigo = 'recursos_humanos.acceder'
      and permiso.nombre = 'RECURSO HUMANO'
      and permiso.descripcion =
        'Permite acceder y gestionar el módulo de licencias y vacaciones dentro del alcance autorizado.'
      and permiso.modulo = 'recursos_humanos'
      and permiso.activo
  ),
  1,
  'permiso principal RECURSO HUMANO existe una vez, activo y exacto'
);

select is(
  (
    select count(*)::integer
    from public.permisos permiso
    where permiso.codigo in (
      'licencias.ver_asignadas', 'licencias.editar_asignadas',
      'vacaciones.ver_asignadas', 'vacaciones.editar_asignadas'
    )
      and permiso.activo
  ),
  0,
  'RECURSO HUMANO es el único permiso activo visible para licencias y vacaciones'
);

select ok(
  (
    select bool_and(tabla.relrowsecurity)
    from pg_catalog.pg_class tabla
    where tabla.oid = any(array[
      'public.nomina_plantillas_horario'::regclass,
      'public.nomina_plantilla_horario_versiones'::regclass,
      'public.nomina_plantilla_horario_dias'::regclass,
      'public.nomina_asignaciones_horario'::regclass,
      'public.nomina_condiciones_salariales'::regclass,
      'public.nomina_dias_libres'::regclass,
      'public.nomina_dia_libre_dias'::regclass,
      'public.nomina_coberturas'::regclass,
      'public.nomina_festivos'::regclass,
      'public.nomina_calendario_auditoria'::regclass
    ])
  ),
  'RLS está habilitado en todas las tablas 0042'
);

select ok(
  not exists(
    select 1
    from unnest(array[
      'public.nomina_plantillas_horario',
      'public.nomina_plantilla_horario_versiones',
      'public.nomina_plantilla_horario_dias',
      'public.nomina_asignaciones_horario',
      'public.nomina_condiciones_salariales',
      'public.nomina_dias_libres',
      'public.nomina_dia_libre_dias',
      'public.nomina_coberturas',
      'public.nomina_festivos',
      'public.nomina_calendario_auditoria'
    ]) tabla(nombre)
    where has_table_privilege(
      'authenticated', tabla.nombre, 'INSERT,UPDATE,DELETE,TRUNCATE'
    )
  ),
  'authenticated no tiene DML directo sobre tablas 0042'
);

select ok(
  (
    select p.prosecdef
       and coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=%'
    from pg_catalog.pg_proc p
    where p.oid =
      'public.puede_operar_empleado_en_alcance(uuid,text)'::regprocedure
  ),
  'helper común es SECURITY DEFINER con search_path fijo'
);

select ok(
  has_function_privilege(
    'authenticated',
    'public.puede_operar_empleado_en_alcance(uuid,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.puede_operar_empleado_en_alcance(uuid,text)',
    'EXECUTE'
  ),
  'solo authenticated puede ejecutar el helper público de alcance'
);

-- Fixture aislado 42000000. Todos los cambios se revierten al terminar.
insert into auth.users(
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  (
    '42000000-0000-0000-0000-000000000101',
    'authenticated', 'authenticated', 'admin-a-0042@test.local',
    'not-used', now(), '{}', '{}', now(), now()
  ),
  (
    '42000000-0000-0000-0000-000000000102',
    'authenticated', 'authenticated', 'supervisor-a-0042@test.local',
    'not-used', now(), '{}', '{}', now(), now()
  ),
  (
    '42000000-0000-0000-0000-000000000103',
    'authenticated', 'authenticated', 'supervisor-multi-0042@test.local',
    'not-used', now(), '{}', '{}', now(), now()
  ),
  (
    '42000000-0000-0000-0000-000000000104',
    'authenticated', 'authenticated', 'supervisor-noscope-0042@test.local',
    'not-used', now(), '{}', '{}', now(), now()
  ),
  (
    '42000000-0000-0000-0000-000000000105',
    'authenticated', 'authenticated', 'supervisor-noperm-0042@test.local',
    'not-used', now(), '{}', '{}', now(), now()
  ),
  (
    '42000000-0000-0000-0000-000000000106',
    'authenticated', 'authenticated', 'admin-b-0042@test.local',
    'not-used', now(), '{}', '{}', now(), now()
  );

insert into public.companies(id, name, slug, timezone, status) values
  (
    '42000000-0000-0000-0000-000000000001',
    'Empresa A Calendario 0042', 'empresa-a-calendario-0042',
    'America/Santo_Domingo', 'active'
  ),
  (
    '42000000-0000-0000-0000-000000000002',
    'Empresa B Calendario 0042', 'empresa-b-calendario-0042',
    'America/Santo_Domingo', 'active'
  );

insert into public.roles(
  id, company_id, name, code, is_active
) values
  (
    '42000000-0000-0000-0000-000000000011',
    '42000000-0000-0000-0000-000000000001',
    'Administrador A 0042', 'admin', true
  ),
  (
    '42000000-0000-0000-0000-000000000012',
    '42000000-0000-0000-0000-000000000001',
    'Supervisor A 0042', 'supervisor', true
  ),
  (
    '42000000-0000-0000-0000-000000000013',
    '42000000-0000-0000-0000-000000000002',
    'Administrador B 0042', 'admin', true
  );

insert into public.branches(
  id, company_id, name, code, is_main, status
) values
  (
    '42000000-0000-0000-0000-000000000021',
    '42000000-0000-0000-0000-000000000001',
    'Sucursal A 0042', 'SA42', true, 'active'
  ),
  (
    '42000000-0000-0000-0000-000000000022',
    '42000000-0000-0000-0000-000000000002',
    'Sucursal B 0042', 'SB42', true, 'active'
  );

insert into public.departments(
  id, company_id, branch_id, name, code, is_active
) values
  (
    '42000000-0000-0000-0000-000000000031',
    '42000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000021',
    'Cajeras A1 0042', 'CA42', true
  ),
  (
    '42000000-0000-0000-0000-000000000032',
    '42000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000021',
    'Almacén A2 0042', 'AL42', true
  ),
  (
    '42000000-0000-0000-0000-000000000033',
    '42000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000021',
    'Oficina A3 0042', 'OF42', true
  ),
  (
    '42000000-0000-0000-0000-000000000034',
    '42000000-0000-0000-0000-000000000002',
    '42000000-0000-0000-0000-000000000022',
    'Departamento B 0042', 'DB42', true
  );

insert into public.employee_code_sequences(empresa_id, last_value) values
  ('42000000-0000-0000-0000-000000000001', 420000),
  ('42000000-0000-0000-0000-000000000002', 421000)
on conflict(empresa_id) do update set last_value = excluded.last_value;


insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id,
  codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '42000000-0000-0000-0000-000000000201',
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000021',
  '42000000-0000-0000-0000-000000000031',
  '420001', 'Empleado Cajeras A1 0042', date '2040-01-01',
  'activo', 30000, 'mensual', true
);

insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id,
  codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '42000000-0000-0000-0000-000000000202',
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000021',
  '42000000-0000-0000-0000-000000000032',
  '420002', 'Empleado Almacén A2 0042', date '2040-01-01',
  'activo', 30000, 'mensual', true
);

insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id,
  codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '42000000-0000-0000-0000-000000000203',
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000021',
  '42000000-0000-0000-0000-000000000033',
  '420003', 'Empleado Oficina A3 0042', date '2040-01-01',
  'activo', 30000, 'mensual', true
);

insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id,
  codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '42000000-0000-0000-0000-000000000204',
  '42000000-0000-0000-0000-000000000002',
  '42000000-0000-0000-0000-000000000022',
  '42000000-0000-0000-0000-000000000034',
  '421001', 'Empleado Empresa B 0042', date '2040-01-01',
  'activo', 30000, 'mensual', true
);

insert into public.profiles(
  id, company_id, role_id, branch_id, department_id, full_name, status
) values
  (
    '42000000-0000-0000-0000-000000000101',
    '42000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000011',
    '42000000-0000-0000-0000-000000000021',
    '42000000-0000-0000-0000-000000000031',
    'Administrador A 0042', 'active'
  ),
  (
    '42000000-0000-0000-0000-000000000102',
    '42000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000012',
    '42000000-0000-0000-0000-000000000021',
    '42000000-0000-0000-0000-000000000031',
    'Supervisor A 0042', 'active'
  ),
  (
    '42000000-0000-0000-0000-000000000103',
    '42000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000012',
    '42000000-0000-0000-0000-000000000021',
    '42000000-0000-0000-0000-000000000031',
    'Supervisor Múltiple 0042', 'active'
  ),
  (
    '42000000-0000-0000-0000-000000000104',
    '42000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000012',
    '42000000-0000-0000-0000-000000000021',
    '42000000-0000-0000-0000-000000000031',
    'Supervisor Sin Alcance 0042', 'active'
  ),
  (
    '42000000-0000-0000-0000-000000000105',
    '42000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000012',
    '42000000-0000-0000-0000-000000000021',
    '42000000-0000-0000-0000-000000000031',
    'Supervisor Sin Permiso 0042', 'active'
  ),
  (
    '42000000-0000-0000-0000-000000000106',
    '42000000-0000-0000-0000-000000000002',
    '42000000-0000-0000-0000-000000000013',
    '42000000-0000-0000-0000-000000000022',
    '42000000-0000-0000-0000-000000000034',
    'Administrador B 0042', 'active'
  );

insert into public.perfil_sucursales(perfil_id, sucursal_id) values
  (
    '42000000-0000-0000-0000-000000000102',
    '42000000-0000-0000-0000-000000000021'
  ),
  (
    '42000000-0000-0000-0000-000000000103',
    '42000000-0000-0000-0000-000000000021'
  ),
  (
    '42000000-0000-0000-0000-000000000105',
    '42000000-0000-0000-0000-000000000021'
  );

insert into public.perfil_departamentos(perfil_id, departamento_id) values
  (
    '42000000-0000-0000-0000-000000000102',
    '42000000-0000-0000-0000-000000000031'
  ),
  (
    '42000000-0000-0000-0000-000000000103',
    '42000000-0000-0000-0000-000000000031'
  ),
  (
    '42000000-0000-0000-0000-000000000103',
    '42000000-0000-0000-0000-000000000032'
  ),
  (
    '42000000-0000-0000-0000-000000000105',
    '42000000-0000-0000-0000-000000000031'
  );

insert into public.rol_permisos(
  rol_id, permiso_id, permitido, alcance
)
select
  '42000000-0000-0000-0000-000000000011',
  permiso.id, true, 'empresa'
from public.permisos permiso
where permiso.codigo in (
  'horarios.editar_asignados',
  'recursos_humanos.acceder'
)
on conflict(rol_id, permiso_id) do update set
  permitido = true,
  alcance = 'empresa';

insert into public.nomina_plantillas_horario(
  id, empresa_id, nombre, descripcion,
  created_by, updated_by
) values (
  '42000000-0000-0000-0000-000000000301',
  '42000000-0000-0000-0000-000000000001',
  'Plantilla Base 0042', 'Plantilla sintética de prueba',
  '42000000-0000-0000-0000-000000000101',
  '42000000-0000-0000-0000-000000000101'
);

insert into public.nomina_plantilla_horario_versiones(
  id, empresa_id, plantilla_id, revision, descripcion, motivo, created_by
) values (
  '42000000-0000-0000-0000-000000000302',
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000301',
  1, 'Versión inicial 0042', 'Fixture de pruebas 0042',
  '42000000-0000-0000-0000-000000000101'
);

insert into public.nomina_plantilla_horario_dias(
  empresa_id, plantilla_version_id, iso_dia, minutos_normales, created_by
)
select
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000302',
  dia.iso_dia,
  case when dia.iso_dia between 1 and 5 then 480 else 0 end,
  '42000000-0000-0000-0000-000000000101'
from generate_series(1, 7) as dia(iso_dia);

insert into public.nomina_plantilla_horario_versiones(
  id, empresa_id, plantilla_id, revision, descripcion, motivo, created_by
) values (
  '42000000-0000-0000-0000-000000000303',
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000301',
  2, 'Versión para validar relojes', 'Fixture de coherencia horaria',
  '42000000-0000-0000-0000-000000000101'
);

select lives_ok(
  $$insert into public.nomina_plantilla_horario_dias(
      empresa_id, plantilla_version_id, iso_dia, minutos_normales,
      hora_entrada, hora_salida, inicio_almuerzo,
      duracion_almuerzo_min, created_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000303',
      1, 480, time '08:00', time '17:00', time '12:00', 60,
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '480 minutos son coherentes con 08:00-17:00 menos 60 de almuerzo'
);
select throws_ok(
  $$insert into public.nomina_plantilla_horario_dias(
      empresa_id, plantilla_version_id, iso_dia, minutos_normales,
      hora_entrada, hora_salida, created_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000303',
      2, 0, time '08:00', time '17:00',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23514', null,
  'minutos_normales=0 significa día no programado y no admite relojes'
);
select throws_ok(
  $$insert into public.nomina_plantilla_horario_dias(
      empresa_id, plantilla_version_id, iso_dia, minutos_normales,
      hora_entrada, hora_salida, inicio_almuerzo,
      duracion_almuerzo_min, created_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000303',
      3, 480, time '08:00', time '16:00', time '12:00', 60,
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23514', null,
  'relojes contradictorios con minutos_normales son rechazados'
);
select throws_ok(
  $$insert into public.nomina_plantilla_horario_dias(
      empresa_id, plantilla_version_id, iso_dia, minutos_normales,
      hora_entrada, hora_salida, inicio_almuerzo,
      duracion_almuerzo_min, created_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000303',
      4, 480, time '08:00', time '17:00', time '18:00', 60,
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23514', null,
  'almuerzo fuera de la ventana horaria es rechazado'
);
select lives_ok(
  $$insert into public.nomina_plantilla_horario_dias(
      empresa_id, plantilla_version_id, iso_dia, minutos_normales,
      hora_entrada, hora_salida, inicio_almuerzo,
      duracion_almuerzo_min, created_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000303',
      5, 420, time '22:00', time '06:00', time '02:00', 60,
      '42000000-0000-0000-0000-000000000101'
    )$$,
  'turno nocturno conserva 420 minutos como única verdad económica'
);

select lives_ok(
  $$insert into public.nomina_plantilla_horario_dias(
      empresa_id, plantilla_version_id, iso_dia, minutos_normales,
      hora_entrada, hora_salida, duracion_almuerzo_min, created_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000303',
      6, 480, time '08:00', time '17:00', 60,
      '42000000-0000-0000-0000-000000000101'
    )$$,
  'duración de almuerzo puede informarse sin hora de inicio opcional'
);


select ok(
  not exists(
    select 1
    from public.rol_permisos rp
    join public.roles rol on rol.id = rp.rol_id
    join public.permisos permiso on permiso.id = rp.permiso_id
    where rol.is_active
      and private.normalizar_codigo_rol(rol.code) = 'SUPERVISOR'
      and permiso.codigo in (
        'dias_libres.ver_asignados',
        'dias_libres.editar_asignados',
        'recursos_humanos.acceder'
      )
      and rp.permitido
  ),
  'ningún permiso nuevo se autoconcede a SUPERVISOR'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '42000000-0000-0000-0000-000000000102',
  true
);
select throws_ok(
  $$select public.listar_dias_libres_empleado(
    '42000000-0000-0000-0000-000000000201'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'supervisor sin permiso de días libres no puede listar'
);
select throws_ok(
  $$select public.asignar_dias_libres_semanales(
    '42000000-0000-0000-0000-000000000201',
    date '2043-06-01', date '2043-06-30', array[7]::smallint[],
    'Domingo libre sin permiso', 'Validación fail-closed días libres'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'supervisor sin permiso de días libres no puede asignar'
);
select throws_ok(
  $$select public.registrar_cobertura_empleado(
    '42000000-0000-0000-0000-000000000201',
    'LICENCIA', date '2043-01-01', date '2043-01-02',
    20, 'Licencia sin permiso principal', 'Validación fail-closed HR'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'supervisor sin recursos_humanos.acceder = DENEGADO'
);
select throws_ok(
  $$select public.listar_coberturas_empleado(
    '42000000-0000-0000-0000-000000000201', 'LICENCIA'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'listar licencias también exige recursos_humanos.acceder'
);
reset role;
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);

insert into public.rol_permisos(
  rol_id, permiso_id, permitido, alcance
)
select
  '42000000-0000-0000-0000-000000000012',
  permiso.id, true, 'empresa'
from public.permisos permiso
where permiso.codigo in (
  'horarios.editar_asignados',
  'recursos_humanos.acceder'
)
on conflict(rol_id, permiso_id) do update set
  permitido = true,
  alcance = 'empresa';

insert into public.perfil_permisos(
  perfil_id, permiso_id, permitido, alcance
)
select
  '42000000-0000-0000-0000-000000000105',
  permiso.id, false, 'departamento'
from public.permisos permiso
where permiso.codigo in (
  'horarios.editar_asignados',
  'recursos_humanos.acceder'
)
on conflict(perfil_id, permiso_id) do update set
  permitido = false,
  alcance = 'departamento';

insert into public.rol_permisos(
  rol_id, permiso_id, permitido, alcance
)
select
  '42000000-0000-0000-0000-000000000012',
  permiso.id, true, 'empresa'
from public.permisos permiso
where permiso.codigo in (
  'dias_libres.ver_asignados',
  'dias_libres.editar_asignados'
)
on conflict(rol_id, permiso_id) do update set
  permitido = true,
  alcance = 'empresa';

insert into public.perfil_permisos(
  perfil_id, permiso_id, permitido, alcance
)
select
  '42000000-0000-0000-0000-000000000105',
  permiso.id, false, 'departamento'
from public.permisos permiso
where permiso.codigo in (
  'dias_libres.ver_asignados',
  'dias_libres.editar_asignados'
)
on conflict(perfil_id, permiso_id) do update set
  permitido = false,
  alcance = 'departamento';


set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '42000000-0000-0000-0000-000000000102',
  true
);

select ok(
  public.puede_operar_empleado_en_alcance(
    '42000000-0000-0000-0000-000000000201',
    'horarios.editar_asignados'
  ),
  'supervisor A puede operar empleado de su departamento'
);
select ok(
  not public.puede_operar_empleado_en_alcance(
    '42000000-0000-0000-0000-000000000202',
    'horarios.editar_asignados'
  ),
  'supervisor A no puede operar empleado de otro departamento'
);
select lives_ok(
  $$select public.asignar_plantilla_horario(
    '42000000-0000-0000-0000-000000000201',
    '42000000-0000-0000-0000-000000000302',
    date '2042-01-01', date '2042-01-15',
    'Asignación autorizada de prueba 0042'
  )$$,
  'RPC permite asignación dentro del departamento'
);
select throws_ok(
  $$select public.asignar_plantilla_horario(
    '42000000-0000-0000-0000-000000000202',
    '42000000-0000-0000-0000-000000000302',
    date '2042-01-01', date '2042-01-15',
    'Manipulación manual fuera de alcance'
  )$$,
  '42501',
  'ALCANCE_O_PERMISO_DENEGADO',
  'RPC rechaza employee_id manual fuera del departamento'
);
select lives_ok(
  $$select public.asignar_dias_libres_semanales(
    '42000000-0000-0000-0000-000000000201',
    date '2044-01-01', null, array[1,7]::smallint[],
    'Lunes y domingo libres', 'Prueba dentro del alcance'
  )$$,
  'concesión explícita permite asignar días libres dentro del departamento'
);
select lives_ok(
  $$select public.listar_dias_libres_empleado(
    '42000000-0000-0000-0000-000000000201'
  )$$,
  'concesión explícita permite listar días libres dentro del departamento'
);
select throws_ok(
  $$select public.asignar_dias_libres_semanales(
    '42000000-0000-0000-0000-000000000202',
    date '2044-01-01', date '2044-12-31', array[7]::smallint[],
    'Domingo libre semanal', 'employee_id manual fuera de alcance'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'días libres fuera del departamento = DENEGADO'
);
select throws_ok(
  $$select public.listar_dias_libres_empleado(
    '42000000-0000-0000-0000-000000000202'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'listar días libres fuera del departamento = DENEGADO'
);
select lives_ok(
  $$select public.registrar_cobertura_empleado(
    '42000000-0000-0000-0000-000000000201',
    'LICENCIA', date '2044-02-01', date '2044-02-02',
    20, 'Licencia autorizada', 'Prueba dentro del alcance'
  )$$,
  'supervisor con permiso + mismo departamento = puede licencia'
);
select lives_ok(
  $$select public.listar_coberturas_empleado(
    '42000000-0000-0000-0000-000000000201', 'LICENCIA'
  )$$,
  'listar licencia funciona con permiso principal y alcance'
);
select throws_ok(
  $$select public.registrar_cobertura_empleado(
    '42000000-0000-0000-0000-000000000202',
    'LICENCIA', date '2044-02-01', date '2044-02-02',
    20, 'Licencia fuera de alcance', 'employee_id manual fuera de alcance'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'licencia fuera del departamento = DENEGADO'
);
select lives_ok(
  $$select public.registrar_cobertura_empleado(
    '42000000-0000-0000-0000-000000000201',
    'VACACIONES', date '2044-03-01', date '2044-03-02',
    100, 'Vacaciones autorizadas', 'Prueba dentro del alcance'
  )$$,
  'supervisor con permiso + mismo departamento = puede vacaciones'
);
select lives_ok(
  $$select public.revocar_cobertura_empleado(
    (
      select cobertura.id
      from public.nomina_coberturas cobertura
      where cobertura.empleado_id =
        '42000000-0000-0000-0000-000000000201'
        and cobertura.tipo = 'LICENCIA'
        and cobertura.fecha_desde = date '2044-02-01'
    ),
    'Revocación autorizada con permiso principal'
  )$$,
  'revocar licencia exige y acepta el permiso principal'
);
select throws_ok(
  $$select public.registrar_cobertura_empleado(
    '42000000-0000-0000-0000-000000000202',
    'VACACIONES', date '2044-03-01', date '2044-03-02',
    100, 'Vacaciones fuera de alcance', 'employee_id manual fuera de alcance'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'vacaciones fuera del departamento = DENEGADO'
);
select throws_ok(
  $$select public.registrar_cobertura_empleado(
    '42000000-0000-0000-0000-000000000204',
    'LICENCIA', date '2044-04-01', date '2044-04-02',
    20, 'Licencia de otro tenant', 'employee_id manual de otro tenant'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'recursos humanos no atraviesa otro tenant'
);
select throws_ok(
  $$select public.asignar_dias_libres_semanales(
    '42000000-0000-0000-0000-000000000201',
    date '2048-01-01', date '2048-12-31', array[7,7]::smallint[],
    'Día semanal duplicado', 'Validación del detalle semanal'
  )$$,
  '22023', 'DIAS_LIBRES_SEMANALES_INVALIDOS',
  'RPC rechaza días ISO duplicados'
);
select lives_ok(
  $$select public.cerrar_dias_libres_semanales(
    (
      select id
      from public.nomina_dias_libres
      where empleado_id = '42000000-0000-0000-0000-000000000201'
        and vigente_desde = date '2044-01-01'
    ),
    date '2044-12-31', 'Cierre histórico de configuración'
  )$$,
  'configuración semanal abierta puede cerrarse sin alterar su detalle'
);
select lives_ok(
  $$select public.asignar_dias_libres_semanales(
    '42000000-0000-0000-0000-000000000201',
    date '2045-01-01', null, array[6,7]::smallint[],
    'Sábado y domingo libres', 'Nueva configuración histórica'
  )$$,
  'cambio posterior crea otra configuración semanal'
);

reset role;
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '42000000-0000-0000-0000-000000000104',
  true
);
select ok(
  not public.puede_operar_empleado_en_alcance(
    '42000000-0000-0000-0000-000000000201',
    'horarios.editar_asignados'
  ),
  'permiso sin departamentos explícitos es denegado'
);
select throws_ok(
  $$select public.asignar_dias_libres_semanales(
    '42000000-0000-0000-0000-000000000201',
    date '2046-01-01', date '2046-12-31', array[7]::smallint[],
    'Domingo libre semanal', 'Prueba permiso sin alcance'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'permiso sin departamentos = DENEGADO'
);
select throws_ok(
  $$select public.registrar_cobertura_empleado(
    '42000000-0000-0000-0000-000000000201',
    'LICENCIA', date '2046-02-01', date '2046-02-02',
    20, 'Licencia sin alcance explícito', 'Validación fail-closed HR'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'permiso de recursos humanos sin departamentos = DENEGADO'
);

reset role;
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '42000000-0000-0000-0000-000000000105',
  true
);
select ok(
  not public.puede_operar_empleado_en_alcance(
    '42000000-0000-0000-0000-000000000201',
    'horarios.editar_asignados'
  ),
  'alcance departamental sin permiso efectivo es denegado'
);
select throws_ok(
  $$select public.asignar_dias_libres_semanales(
    '42000000-0000-0000-0000-000000000201',
    date '2047-01-01', date '2047-12-31', array[7]::smallint[],
    'Domingo libre semanal', 'Prueba alcance sin permiso'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'alcance sin permiso = DENEGADO'
);
select ok(
  not public.puede_operar_empleado_en_alcance(
    '42000000-0000-0000-0000-000000000201',
    'recursos_humanos.acceder'
  ),
  'override denegado prevalece sobre permiso de rol'
);
select throws_ok(
  $$select public.registrar_cobertura_empleado(
    '42000000-0000-0000-0000-000000000201',
    'LICENCIA', date '2047-02-01', date '2047-02-02',
    20, 'Licencia sin permiso efectivo', 'Validación fail-closed HR'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'alcance sin recursos_humanos.acceder = DENEGADO'
);

reset role;
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '42000000-0000-0000-0000-000000000103',
  true
);
select ok(
  public.puede_operar_empleado_en_alcance(
    '42000000-0000-0000-0000-000000000201',
    'horarios.editar_asignados'
  )
  and public.puede_operar_empleado_en_alcance(
    '42000000-0000-0000-0000-000000000202',
    'horarios.editar_asignados'
  )
  and not public.puede_operar_empleado_en_alcance(
    '42000000-0000-0000-0000-000000000203',
    'horarios.editar_asignados'
  ),
  'múltiples departamentos permiten únicamente A1 y A2'
);

reset role;
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '42000000-0000-0000-0000-000000000101',
  true
);
select ok(
  public.puede_operar_empleado_en_alcance(
    '42000000-0000-0000-0000-000000000203',
    'horarios.editar_asignados'
  ),
  'ADMIN opera empleado de su empresa según permiso empresarial'
);
select ok(
  not public.puede_operar_empleado_en_alcance(
    '42000000-0000-0000-0000-000000000204',
    'horarios.editar_asignados'
  ),
  'ADMIN no atraviesa el tenant aunque tenga alcance empresa'
);
select lives_ok(
  $$select public.registrar_cobertura_empleado(
    '42000000-0000-0000-0000-000000000203',
    'VACACIONES', date '2050-01-01', date '2050-01-02',
    100, 'Vacaciones autorizadas por ADMIN', 'Prueba ADMIN empresarial'
  )$$,
  'ADMIN autorizado puede gestionar recursos humanos de su empresa'
);
select throws_ok(
  $$select public.registrar_cobertura_empleado(
    '42000000-0000-0000-0000-000000000204',
    'LICENCIA', date '2050-01-01', date '2050-01-02',
    20, 'Licencia de empresa ajena', 'Prueba tenant ADMIN'
  )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'ADMIN autorizado no atraviesa otra empresa'
);

reset role;
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);


select throws_ok(
  $$insert into public.nomina_asignaciones_horario(
      empresa_id, empleado_id, plantilla_version_id,
      vigente_desde, vigente_hasta, motivo,
      created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000201',
      '42000000-0000-0000-0000-000000000302',
      date '2042-01-10', date '2042-01-20',
      'Solape de prueba 0042',
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23P01',
  null,
  'solape de vigencia de horario es rechazado'
);

select lives_ok(
  $$insert into public.nomina_asignaciones_horario(
      empresa_id, empleado_id, plantilla_version_id,
      vigente_desde, vigente_hasta, motivo,
      created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000201',
      '42000000-0000-0000-0000-000000000302',
      date '2042-01-16', date '2042-01-31',
      'Vigencia adyacente 0042',
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  'vigencias adyacentes no se consideran solape'
);

select throws_ok(
  $$insert into public.nomina_asignaciones_horario(
      empresa_id, empleado_id, plantilla_version_id,
      vigente_desde, vigente_hasta, motivo,
      created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000202',
      '42000000-0000-0000-0000-000000000302',
      date '2042-02-10', date '2042-02-01',
      'Rango invertido 0042',
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23514',
  null,
  'rango con inicio posterior al fin es rechazado'
);

select throws_ok(
  $$insert into public.nomina_asignaciones_horario(
      empresa_id, empleado_id, plantilla_version_id,
      vigente_desde, vigente_hasta, motivo,
      created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000204',
      '42000000-0000-0000-0000-000000000302',
      date '2042-02-01', date '2042-02-02',
      'Cruce de tenant 0042',
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23503',
  null,
  'FK compuesta impide employee_id de otra empresa'
);

insert into public.nomina_condiciones_salariales(
  empresa_id, empleado_id, sueldo_mensual, valor_hora_extra,
  vigente_desde, vigente_hasta, motivo, created_by, updated_by
) values (
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000201',
  30000, 250, date '2042-01-01', date '2042-06-30',
  'Condición inicial 0042',
  '42000000-0000-0000-0000-000000000101',
  '42000000-0000-0000-0000-000000000101'
);

select throws_ok(
  $$insert into public.nomina_condiciones_salariales(
      empresa_id, empleado_id, sueldo_mensual, valor_hora_extra,
      vigente_desde, vigente_hasta, motivo, created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000201',
      32000, 260, date '2042-06-01', date '2042-07-31',
      'Condición solapada 0042',
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23P01',
  null,
  'condiciones salariales superpuestas son rechazadas'
);

select is(
  (
    select array_agg(detalle.iso_dia order by detalle.iso_dia)
    from public.nomina_dia_libre_dias detalle
    join public.nomina_dias_libres configuracion
      on configuracion.empresa_id = detalle.empresa_id
     and configuracion.id = detalle.configuracion_id
    where configuracion.empleado_id =
      '42000000-0000-0000-0000-000000000201'
      and configuracion.vigente_desde = date '2044-01-01'
  ),
  array[1,7]::smallint[],
  'una configuración conserva varios días libres semanales'
);

select ok(
  (
    select antigua.vigente_hasta = date '2044-12-31'
       and array(
         select detalle.iso_dia
         from public.nomina_dia_libre_dias detalle
         where detalle.configuracion_id = antigua.id
         order by detalle.iso_dia
       ) = array[1,7]::smallint[]
       and array(
         select detalle.iso_dia
         from public.nomina_dia_libre_dias detalle
         join public.nomina_dias_libres nueva
           on nueva.empresa_id = detalle.empresa_id
          and nueva.id = detalle.configuracion_id
         where nueva.empleado_id = antigua.empleado_id
           and nueva.vigente_desde = date '2045-01-01'
         order by detalle.iso_dia
       ) = array[6,7]::smallint[]
    from public.nomina_dias_libres antigua
    where antigua.empleado_id =
      '42000000-0000-0000-0000-000000000201'
      and antigua.vigente_desde = date '2044-01-01'
  ),
  'cambiar días libres crea nueva vigencia y no altera el detalle pasado'
);

insert into public.nomina_dias_libres(
  id, empresa_id, empleado_id, vigente_desde, vigente_hasta,
  descripcion, created_by, updated_by
) values (
  '42000000-0000-0000-0000-000000000410',
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000202',
  date '2042-04-01', date '2042-04-30',
  'Domingo libre durante la vigencia',
  '42000000-0000-0000-0000-000000000101',
  '42000000-0000-0000-0000-000000000101'
);
insert into public.nomina_dia_libre_dias(
  empresa_id, configuracion_id, empleado_id, iso_dia, created_by
) values (
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000410',
  '42000000-0000-0000-0000-000000000202', 7,
  '42000000-0000-0000-0000-000000000101'
);

select throws_ok(
  $$insert into public.nomina_dias_libres(
      empresa_id, empleado_id, vigente_desde, vigente_hasta,
      descripcion, created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000202',
      date '2042-04-15', date '2042-05-15',
      'Configuración semanal solapada',
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23P01', null,
  'configuraciones semanales incompatibles no pueden solaparse'
);

select lives_ok(
  $$insert into public.nomina_dias_libres(
      id, empresa_id, empleado_id, vigente_desde, vigente_hasta,
      descripcion, created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000411',
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000202',
      date '2042-05-01', date '2042-05-31',
      'Configuración semanal adyacente',
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  'vigencias semanales adyacentes son válidas'
);
insert into public.nomina_dia_libre_dias(
  empresa_id, configuracion_id, empleado_id, iso_dia, created_by
) values (
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000411',
  '42000000-0000-0000-0000-000000000202', 6,
  '42000000-0000-0000-0000-000000000101'
);

select throws_ok(
  $$insert into public.nomina_dias_libres(
      empresa_id, empleado_id, vigente_desde, vigente_hasta,
      descripcion, created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000202',
      date '2042-06-10', date '2042-06-01',
      'Vigencia semanal invertida',
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23514', null,
  'vigencia semanal con inicio posterior al fin es rechazada'
);

select throws_ok(
  $$insert into public.nomina_dia_libre_dias(
      empresa_id, configuracion_id, empleado_id, iso_dia, created_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000410',
      '42000000-0000-0000-0000-000000000202', 0,
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23514', null,
  'iso_dia fuera de 1..7 es rechazado'
);

select throws_ok(
  $$insert into public.nomina_dia_libre_dias(
      empresa_id, configuracion_id, empleado_id, iso_dia, created_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000410',
      '42000000-0000-0000-0000-000000000202', 7,
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23505', null,
  'un día semanal no puede duplicarse en la misma configuración'
);

select throws_ok(
  $$update public.nomina_dia_libre_dias
    set iso_dia = 6
    where configuracion_id = '42000000-0000-0000-0000-000000000410'
      and iso_dia = 7$$,
  'P4200', 'NOMINA_0042_HISTORY_IS_APPEND_ONLY',
  'detalle semanal histórico es inmutable'
);

select throws_ok(
  $$insert into public.nomina_coberturas(
      empresa_id, empleado_id, tipo, fecha_desde, fecha_hasta,
      porcentaje, descripcion, estado, aprobado_por, aprobado_en,
      created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000202',
      'LICENCIA', date '2042-03-01', date '2042-03-05',
      101, 'Licencia inválida 0042', 'APROBADA',
      '42000000-0000-0000-0000-000000000101', now(),
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23514',
  null,
  'porcentaje de licencia fuera de 0..100 es rechazado'
);
select throws_ok(
  $$insert into public.nomina_coberturas(
      empresa_id, empleado_id, tipo, fecha_desde, fecha_hasta,
      porcentaje, descripcion, estado, aprobado_por, aprobado_en,
      created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000202',
      'VACACIONES', date '2042-07-01', date '2042-07-05',
      80, 'Vacaciones inválidas 0042', 'APROBADA',
      '42000000-0000-0000-0000-000000000101', now(),
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23514', null,
  'vacaciones exige exactamente 100 por ciento'
);

insert into public.nomina_coberturas(
  id, empresa_id, empleado_id, tipo, fecha_desde, fecha_hasta,
  porcentaje, descripcion, estado, aprobado_por, aprobado_en,
  created_by, updated_by
) values (
  '42000000-0000-0000-0000-000000000401',
  '42000000-0000-0000-0000-000000000001',
  '42000000-0000-0000-0000-000000000202',
  'LICENCIA', date '2042-03-01', date '2042-03-05',
  20, 'Licencia inclusiva 0042', 'APROBADA',
  '42000000-0000-0000-0000-000000000101', now(),
  '42000000-0000-0000-0000-000000000101',
  '42000000-0000-0000-0000-000000000101'
);

select ok(
  (
    select cobertura.periodo @> date '2042-03-01'
       and cobertura.periodo @> date '2042-03-05'
       and not (cobertura.periodo @> date '2042-02-28')
       and not (cobertura.periodo @> date '2042-03-06')
    from public.nomina_coberturas cobertura
    where cobertura.id = '42000000-0000-0000-0000-000000000401'
  ),
  'rango de cobertura almacena ambos extremos inclusivos'
);

select throws_ok(
  $$insert into public.nomina_coberturas(
      empresa_id, empleado_id, tipo, fecha_desde, fecha_hasta,
      porcentaje, descripcion, estado, aprobado_por, aprobado_en,
      created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      '42000000-0000-0000-0000-000000000202',
      'VACACIONES', date '2042-03-04', date '2042-03-08',
      100, 'Vacaciones solapadas 0042', 'APROBADA',
      '42000000-0000-0000-0000-000000000101', now(),
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23P01',
  null,
  'coberturas aprobadas superpuestas son rechazadas'
);

insert into public.nomina_festivos(
  empresa_id, fecha, descripcion, created_by, updated_by
) values (
  '42000000-0000-0000-0000-000000000001',
  date '2042-12-25', 'Navidad Empresa A 0042',
  '42000000-0000-0000-0000-000000000101',
  '42000000-0000-0000-0000-000000000101'
);

select throws_ok(
  $$insert into public.nomina_festivos(
      empresa_id, fecha, descripcion, created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000001',
      date '2042-12-25', 'Festivo duplicado 0042',
      '42000000-0000-0000-0000-000000000101',
      '42000000-0000-0000-0000-000000000101'
    )$$,
  '23505',
  null,
  'festivo duplicado por empresa y fecha es rechazado'
);

select lives_ok(
  $$insert into public.nomina_festivos(
      empresa_id, fecha, descripcion, created_by, updated_by
    ) values (
      '42000000-0000-0000-0000-000000000002',
      date '2042-12-25', 'Navidad Empresa B 0042',
      '42000000-0000-0000-0000-000000000106',
      '42000000-0000-0000-0000-000000000106'
    )$$,
  'la misma fecha festiva es independiente por tenant'
);

select ok(
  exists(
    select 1
    from public.nomina_calendario_auditoria auditoria
    where auditoria.empresa_id =
      '42000000-0000-0000-0000-000000000001'
      and auditoria.entidad = 'nomina_asignaciones_horario'
      and auditoria.accion = 'INSERT'
  )
  and exists(
    select 1
    from public.nomina_calendario_auditoria auditoria
    where auditoria.empresa_id =
      '42000000-0000-0000-0000-000000000001'
      and auditoria.entidad = 'nomina_dias_libres'
      and auditoria.accion in ('INSERT', 'UPDATE')
  )
  and exists(
    select 1
    from public.nomina_calendario_auditoria auditoria
    where auditoria.empresa_id =
      '42000000-0000-0000-0000-000000000001'
      and auditoria.entidad = 'nomina_dia_libre_dias'
      and auditoria.accion = 'INSERT'
  )
  and exists(
    select 1
    from public.nomina_calendario_auditoria auditoria
    where auditoria.empresa_id =
      '42000000-0000-0000-0000-000000000001'
      and auditoria.entidad = 'nomina_coberturas'
      and auditoria.accion = 'INSERT'
  )
  and exists(
    select 1
    from public.nomina_calendario_auditoria auditoria
    where auditoria.empresa_id =
      '42000000-0000-0000-0000-000000000001'
      and auditoria.entidad = 'nomina_festivos'
      and auditoria.accion = 'INSERT'
  ),
  'horarios, días semanales, coberturas y festivos dejan auditoría'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '42000000-0000-0000-0000-000000000102',
  true
);
select ok(
  not exists(
    select 1
    from public.nomina_dias_libres configuracion
    where configuracion.empleado_id =
      '42000000-0000-0000-0000-000000000202'
  )
  and not exists(
    select 1
    from public.nomina_dia_libre_dias detalle
    where detalle.empleado_id =
      '42000000-0000-0000-0000-000000000202'
  )
  and not exists(
    select 1
    from public.nomina_coberturas cobertura
    where cobertura.empleado_id =
      '42000000-0000-0000-0000-000000000202'
  ),
  'RLS oculta configuraciones de empleados fuera del departamento'
);
reset role;
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);

select throws_ok(
  $$delete from public.nomina_festivos
    where empresa_id = '42000000-0000-0000-0000-000000000001'
      and fecha = date '2042-12-25'$$,
  'P4200',
  'NOMINA_0042_HISTORY_IS_APPEND_ONLY',
  'históricos no pueden borrarse'
);

select * from finish();
rollback;
