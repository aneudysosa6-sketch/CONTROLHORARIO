begin;

set local search_path = extensions, public, pg_catalog;
set local role postgres;

create extension if not exists pgtap;
select * from no_plan();

-- Contrato estructural 0044: fundación privada, cutover inactivo y sin automatismos.
select has_table(
  'public', 'nomina_cutover_canonico_empresas',
  '0044 crea cutover por empresa'
);
select has_table(
  'public', 'nomina_identidades_economicas_canonicas',
  '0044 crea identidad económica canónica estable'
);
select has_function(
  'private', 'materializar_objetivo_canonico_0044',
  array[
    'uuid','uuid','date','text','numeric','text',
    'uuid','bigint','text','uuid','text'
  ]
);
select has_function(
  'private', 'reconciliar_objetivos_nomina_canonicos_0044',
  array['uuid','uuid','date','date','uuid','text']
);
select has_trigger(
  'public', 'nomina_movimientos_tiempo_real',
  'nomina_movimientos_tiempo_real_immutable',
  '0044 conserva el guard de inmutabilidad del ledger 0038'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger trigger_row
    where trigger_row.tgrelid = 'public.jornadas'::regclass
      and trigger_row.tgname = 'nomina_devengar_jornada_finalizada'
      and not trigger_row.tgisinternal
  ),
  '0044 conserva el trigger de devengo 0038'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_trigger trigger_row
    where trigger_row.tgrelid = 'public.jornada_conflictos'::regclass
      and trigger_row.tgname = 'nomina_reconciliar_jornada_conflicto'
      and not trigger_row.tgisinternal
  ),
  '0044 conserva el trigger de reconciliación de conflictos 0038'
);
select is(
  (
    select count(*)::integer
    from pg_catalog.pg_trigger trigger_row
    join pg_catalog.pg_proc proc on proc.oid = trigger_row.tgfoid
    where trigger_row.tgrelid in (
      'public.nomina_resoluciones_diarias'::regclass,
      'public.nomina_complementos_convencion_30'::regclass,
      'public.nomina_movimientos_tiempo_real'::regclass
    )
      and proc.proname like '%0044%'
      and not trigger_row.tgisinternal
  ),
  0,
  '0044 no instala triggers automáticos sobre fuentes 0043 ni ledger 0038'
);
select ok(
  (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.nomina_cutover_canonico_empresas'::regclass
  )
  and (
    select relrowsecurity
    from pg_catalog.pg_class
    where oid = 'public.nomina_identidades_economicas_canonicas'::regclass
  ),
  'RLS está habilitado en las tablas públicas nuevas'
);
select ok(
  not pg_catalog.has_table_privilege(
    'authenticated', 'public.nomina_cutover_canonico_empresas', 'SELECT'
  )
  and not pg_catalog.has_table_privilege(
    'authenticated', 'public.nomina_identidades_economicas_canonicas', 'SELECT'
  )
  and not pg_catalog.has_table_privilege(
    'service_role', 'public.nomina_cutover_canonico_empresas', 'SELECT'
  )
  and not pg_catalog.has_table_privilege(
    'service_role', 'public.nomina_identidades_economicas_canonicas', 'SELECT'
  ),
  '0044 no expone las tablas fundacionales a clientes ni service_role'
);
select ok(
  not pg_catalog.has_function_privilege(
    'authenticated',
    'private.materializar_objetivo_canonico_0044(uuid,uuid,date,text,numeric,text,uuid,bigint,text,uuid,text)',
    'EXECUTE'
  )
  and not pg_catalog.has_function_privilege(
    'service_role',
    'private.reconciliar_objetivos_nomina_canonicos_0044(uuid,uuid,date,date,uuid,text)',
    'EXECUTE'
  ),
  'las funciones de fundación siguen privadas'
);
select ok(
  (
    select column_default like '%INACTIVO%'
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'nomina_cutover_canonico_empresas'
      and column_name = 'estado'
  ),
  'el cutover nace INACTIVO'
);

-- Fixture sintético aislado en UUID 44000000. Todo se revierte al final.
insert into auth.users(
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '44000000-0000-0000-0000-000000000101',
  'authenticated', 'authenticated',
  'admin-0044@test.local', 'not-used', now(),
  '{}', '{}', now(), now()
);

insert into public.companies(id, name, slug, timezone, status) values (
  '44000000-0000-0000-0000-000000000001',
  'Empresa Nómina 0044', 'empresa-nomina-0044',
  'America/Santo_Domingo', 'active'
);

insert into public.roles(id, company_id, name, code, is_active) values (
  '44000000-0000-0000-0000-000000000011',
  '44000000-0000-0000-0000-000000000001',
  'Administrador 0044', 'admin', true
);

insert into public.branches(
  id, company_id, name, code, is_main, status
) values (
  '44000000-0000-0000-0000-000000000021',
  '44000000-0000-0000-0000-000000000001',
  'Sucursal 0044', 'S44', true, 'active'
);

insert into public.departments(
  id, company_id, branch_id, name, code, is_active
) values (
  '44000000-0000-0000-0000-000000000031',
  '44000000-0000-0000-0000-000000000001',
  '44000000-0000-0000-0000-000000000021',
  'Operaciones 0044', 'O44', true
);

insert into public.employee_code_sequences(empresa_id, last_value) values (
  '44000000-0000-0000-0000-000000000001', 440000
)
on conflict(empresa_id) do update set last_value = excluded.last_value;

insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id, codigo_empleado,
  nombre_completo, fecha_ingreso, estado_laboral, salario, tipo_pago, activo
) values (
  '44000000-0000-0000-0000-000000000201',
  '44000000-0000-0000-0000-000000000001',
  '44000000-0000-0000-0000-000000000021',
  '44000000-0000-0000-0000-000000000031',
  '440001', 'Empleado Canónico 0044', date '2025-01-01',
  'activo', 3000, 'mensual', true
);

insert into public.profiles(
  id, company_id, role_id, branch_id, department_id, full_name, status
) values (
  '44000000-0000-0000-0000-000000000101',
  '44000000-0000-0000-0000-000000000001',
  '44000000-0000-0000-0000-000000000011',
  '44000000-0000-0000-0000-000000000021',
  '44000000-0000-0000-0000-000000000031',
  'Administrador 0044', 'active'
);

insert into public.nomina_plantillas_horario(
  id, empresa_id, nombre, descripcion, created_by, updated_by
) values (
  '44000000-0000-0000-0000-000000000301',
  '44000000-0000-0000-0000-000000000001',
  'Plantilla 0044', 'Horario sintético 0044',
  '44000000-0000-0000-0000-000000000101',
  '44000000-0000-0000-0000-000000000101'
);

insert into public.nomina_plantilla_horario_versiones(
  id, empresa_id, plantilla_id, revision, descripcion, motivo, created_by
) values (
  '44000000-0000-0000-0000-000000000302',
  '44000000-0000-0000-0000-000000000001',
  '44000000-0000-0000-0000-000000000301',
  1, 'Versión 0044', 'Fixture 0044',
  '44000000-0000-0000-0000-000000000101'
);

insert into public.nomina_plantilla_horario_dias(
  empresa_id, plantilla_version_id, iso_dia, minutos_normales, created_by
)
select
  '44000000-0000-0000-0000-000000000001',
  '44000000-0000-0000-0000-000000000302',
  dia, 480,
  '44000000-0000-0000-0000-000000000101'
from generate_series(1, 7) dia;

insert into public.nomina_asignaciones_horario(
  id, empresa_id, empleado_id, plantilla_version_id,
  vigente_desde, vigente_hasta, motivo, created_by, updated_by
) values (
  '44000000-0000-0000-0000-000000000311',
  '44000000-0000-0000-0000-000000000001',
  '44000000-0000-0000-0000-000000000201',
  '44000000-0000-0000-0000-000000000302',
  date '2025-01-01', date '2025-12-31',
  'Asignación 0044',
  '44000000-0000-0000-0000-000000000101',
  '44000000-0000-0000-0000-000000000101'
);

insert into public.nomina_condiciones_salariales(
  id, empresa_id, empleado_id, sueldo_mensual, valor_hora_extra,
  vigente_desde, vigente_hasta, motivo, created_by, updated_by
) values (
  '44000000-0000-0000-0000-000000000321',
  '44000000-0000-0000-0000-000000000001',
  '44000000-0000-0000-0000-000000000201',
  3000, 25,
  date '2025-01-01', date '2025-12-31',
  'Condición 0044',
  '44000000-0000-0000-0000-000000000101',
  '44000000-0000-0000-0000-000000000101'
);

insert into public.nomina_cutover_canonico_empresas(empresa_id)
values ('44000000-0000-0000-0000-000000000001');

select is(
  (
    select estado
    from public.nomina_cutover_canonico_empresas
    where empresa_id = '44000000-0000-0000-0000-000000000001'
  ),
  'INACTIVO',
  'crear la configuración no activa el cutover'
);

create temporary table ledger_before_source_0044 on commit drop as
select count(*)::bigint cantidad
from public.nomina_movimientos_tiempo_real;

-- Fuente diaria 0043. Insertarla NO debe tocar el ledger hasta reconciliación explícita.
insert into public.nomina_resoluciones_diarias(
  id, empresa_id, empleado_id, fecha_local, revision, estado, formula,
  fuente_economica, timezone, iso_dia,
  minutos_programados, minutos_trabajados,
  minutos_normales_reconocidos, minutos_extra,
  sueldo_mensual, valor_dia, valor_quincena, valor_hora_extra,
  monto_normal_reconocido,
  cobertura_tipo, cobertura_porcentaje,
  es_festivo, es_dia_libre_automatico, es_dia_libre_manual, es_ausencia,
  jornada_id, asignacion_horario_id, plantilla_version_id,
  plantilla_dia_id, condicion_salarial_id,
  dia_libre_id, dia_libre_detalle_id, cobertura_id, festivo_id,
  objetivo_base_nominal, objetivo_ajuste_diario,
  objetivo_hora_extra, objetivo_premium_festivo,
  objetivo_complemento_30_dias,
  snapshot, input_hash, motivo, actor_id
) values (
  '44000000-0000-0000-0000-000000000401',
  '44000000-0000-0000-0000-000000000001',
  '44000000-0000-0000-0000-000000000201',
  date '2025-01-17', 1, 'RESUELTA', 'DAILY_FIXED_SALARY_V1',
  'JORNADA', 'America/Santo_Domingo', 5,
  480, 360, 360, 120,
  3000, 100, 1500, 25, 75,
  null, null,
  true, false, false, false,
  null,
  '44000000-0000-0000-0000-000000000311',
  '44000000-0000-0000-0000-000000000302',
  (
    select dia.id
    from public.nomina_plantilla_horario_dias dia
    where dia.empresa_id = '44000000-0000-0000-0000-000000000001'
      and dia.plantilla_version_id =
        '44000000-0000-0000-0000-000000000302'
      and dia.iso_dia = 5
  ),
  '44000000-0000-0000-0000-000000000321',
  null, null, null, null,
  100, -25, 50, 75, 0,
  '{}'::jsonb, repeat('a', 64), 'Fuente diaria 0044 revisión 1', null
);

select is(
  (select count(*) from public.nomina_movimientos_tiempo_real),
  (select cantidad from ledger_before_source_0044),
  'insertar una resolución 0043 no dispara reconciliación 0044'
);

select lives_ok(
  $$select private.reconciliar_objetivos_nomina_canonicos_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-01-17', date '2025-01-17',
      null, 'Reconciliar fuente diaria 0044'
    )$$,
  'reconciliación explícita materializa los objetivos diarios'
);

select is(
  (
    select count(*)::integer
    from public.nomina_identidades_economicas_canonicas identity_row
    where identity_row.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and identity_row.empleado_id =
        '44000000-0000-0000-0000-000000000201'
      and identity_row.fecha_economica = date '2025-01-17'
  ),
  4,
  'la resolución diaria crea cuatro identidades salariales, no AFP/SFS'
);

select results_eq(
  $$
    select identity_row.concepto,
      round(sum(private.movimiento_nomina_firmado_0044(
        movement.clase, movement.monto
      )), 2) as target
    from public.nomina_identidades_economicas_canonicas identity_row
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = identity_row.empresa_id
     and movement.empleado_id = identity_row.empleado_id
     and movement.source_type = 'CANONICAL_SALARY_DELTA'
     and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
    where identity_row.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and identity_row.empleado_id =
        '44000000-0000-0000-0000-000000000201'
      and identity_row.fecha_economica = date '2025-01-17'
    group by identity_row.concepto
    order by identity_row.concepto
  $$,
  $$
    values
      ('HOLIDAY_NORMAL_PREMIUM'::text, 75::numeric),
      ('SALARY_DAY_ADJUSTMENT'::text, -25::numeric),
      ('SALARY_DAY_BASE'::text, 100::numeric),
      ('SALARY_DAY_OVERTIME'::text, 50::numeric)
  $$,
  'el bridge conserva los objetivos firmados, incluido ajuste negativo'
);

select ok(
  not exists (
    select 1
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and movement.empleado_id =
        '44000000-0000-0000-0000-000000000201'
      and movement.source_type like 'CANONICAL_SALARY_%'
      and private.movimiento_nomina_es_pagable(movement)
  ),
  '0044 queda en shadow: sus movimientos todavía no son pagables por 0038'
);

create temporary table canonical_count_after_first_0044 on commit drop as
select count(*)::bigint cantidad
from public.nomina_movimientos_tiempo_real
where empresa_id = '44000000-0000-0000-0000-000000000001'
  and empleado_id = '44000000-0000-0000-0000-000000000201'
  and source_type like 'CANONICAL_SALARY_%';

select lives_ok(
  $$select private.reconciliar_objetivos_nomina_canonicos_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-01-17', date '2025-01-17',
      null, 'Replay de fuente diaria 0044'
    )$$,
  'repetir la misma reconciliación es válido'
);
select is(
  (
    select count(*)::bigint
    from public.nomina_movimientos_tiempo_real
    where empresa_id = '44000000-0000-0000-0000-000000000001'
      and empleado_id = '44000000-0000-0000-0000-000000000201'
      and source_type like 'CANONICAL_SALARY_%'
  ),
  (select cantidad from canonical_count_after_first_0044),
  'replay no duplica eventos canónicos'
);

-- Revisión 2 con mismo objetivo: registra fuente nueva CONTROL, sin duplicar dinero.
insert into public.nomina_resoluciones_diarias(
  id, empresa_id, empleado_id, fecha_local, revision, estado, formula,
  fuente_economica, timezone, iso_dia,
  minutos_programados, minutos_trabajados,
  minutos_normales_reconocidos, minutos_extra,
  sueldo_mensual, valor_dia, valor_quincena, valor_hora_extra,
  monto_normal_reconocido,
  cobertura_tipo, cobertura_porcentaje,
  es_festivo, es_dia_libre_automatico, es_dia_libre_manual, es_ausencia,
  jornada_id, asignacion_horario_id, plantilla_version_id,
  plantilla_dia_id, condicion_salarial_id,
  dia_libre_id, dia_libre_detalle_id, cobertura_id, festivo_id,
  objetivo_base_nominal, objetivo_ajuste_diario,
  objetivo_hora_extra, objetivo_premium_festivo,
  objetivo_complemento_30_dias,
  snapshot, input_hash, motivo, actor_id
)
select
  '44000000-0000-0000-0000-000000000402'::uuid,
  empresa_id, empleado_id, fecha_local, 2, estado, formula,
  fuente_economica, timezone, iso_dia,
  minutos_programados, minutos_trabajados,
  minutos_normales_reconocidos, minutos_extra,
  sueldo_mensual, valor_dia, valor_quincena, valor_hora_extra,
  monto_normal_reconocido,
  cobertura_tipo, cobertura_porcentaje,
  es_festivo, es_dia_libre_automatico, es_dia_libre_manual, es_ausencia,
  jornada_id, asignacion_horario_id, plantilla_version_id,
  plantilla_dia_id, condicion_salarial_id,
  dia_libre_id, dia_libre_detalle_id, cobertura_id, festivo_id,
  objetivo_base_nominal, objetivo_ajuste_diario,
  objetivo_hora_extra, objetivo_premium_festivo,
  objetivo_complemento_30_dias,
  snapshot, repeat('b', 64), 'Fuente diaria 0044 revisión 2', actor_id
from public.nomina_resoluciones_diarias
where id = '44000000-0000-0000-0000-000000000401';

select lives_ok(
  $$select private.reconciliar_objetivos_nomina_canonicos_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-01-17', date '2025-01-17',
      null, 'Revisión idéntica 0044'
    )$$,
  'una revisión nueva con mismo importe se audita sin delta monetario'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and movement.empleado_id =
        '44000000-0000-0000-0000-000000000201'
      and movement.fecha_devengo = date '2025-01-17'
      and movement.source_type = 'CANONICAL_SALARY_SOURCE'
  ),
  8,
  'cada concepto conserva la revisión fuente nueva mediante CONTROL'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and movement.empleado_id =
        '44000000-0000-0000-0000-000000000201'
      and movement.fecha_devengo = date '2025-01-17'
      and movement.source_type = 'CANONICAL_SALARY_DELTA'
  ),
  4,
  'una revisión económicamente idéntica no duplica dinero'
);

-- Revisión 3 cambia tres de los cuatro conceptos.
insert into public.nomina_resoluciones_diarias(
  id, empresa_id, empleado_id, fecha_local, revision, estado, formula,
  fuente_economica, timezone, iso_dia,
  minutos_programados, minutos_trabajados,
  minutos_normales_reconocidos, minutos_extra,
  sueldo_mensual, valor_dia, valor_quincena, valor_hora_extra,
  monto_normal_reconocido,
  cobertura_tipo, cobertura_porcentaje,
  es_festivo, es_dia_libre_automatico, es_dia_libre_manual, es_ausencia,
  jornada_id, asignacion_horario_id, plantilla_version_id,
  plantilla_dia_id, condicion_salarial_id,
  dia_libre_id, dia_libre_detalle_id, cobertura_id, festivo_id,
  objetivo_base_nominal, objetivo_ajuste_diario,
  objetivo_hora_extra, objetivo_premium_festivo,
  objetivo_complemento_30_dias,
  snapshot, input_hash, motivo, actor_id
)
select
  '44000000-0000-0000-0000-000000000403'::uuid,
  empresa_id, empleado_id, fecha_local, 3, estado, formula,
  fuente_economica, timezone, iso_dia,
  minutos_programados, minutos_trabajados,
  minutos_normales_reconocidos, 0,
  sueldo_mensual, valor_dia, valor_quincena, valor_hora_extra,
  100,
  cobertura_tipo, cobertura_porcentaje,
  es_festivo, es_dia_libre_automatico, es_dia_libre_manual, es_ausencia,
  jornada_id, asignacion_horario_id, plantilla_version_id,
  plantilla_dia_id, condicion_salarial_id,
  dia_libre_id, dia_libre_detalle_id, cobertura_id, festivo_id,
  120, -20, 0, 75, 0,
  snapshot, repeat('c', 64), 'Fuente diaria 0044 revisión 3', actor_id
from public.nomina_resoluciones_diarias
where id = '44000000-0000-0000-0000-000000000402';

select lives_ok(
  $$select private.reconciliar_objetivos_nomina_canonicos_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-01-17', date '2025-01-17',
      null, 'Cambio económico revisión 3 0044'
    )$$,
  'la revisión económica nueva genera solo diferencias'
);
select results_eq(
  $$
    select identity_row.concepto,
      round(sum(private.movimiento_nomina_firmado_0044(
        movement.clase, movement.monto
      )), 2) as target
    from public.nomina_identidades_economicas_canonicas identity_row
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = identity_row.empresa_id
     and movement.empleado_id = identity_row.empleado_id
     and movement.source_type = 'CANONICAL_SALARY_DELTA'
     and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
    where identity_row.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and identity_row.empleado_id =
        '44000000-0000-0000-0000-000000000201'
      and identity_row.fecha_economica = date '2025-01-17'
    group by identity_row.concepto
    order by identity_row.concepto
  $$,
  $$
    values
      ('HOLIDAY_NORMAL_PREMIUM'::text, 75::numeric),
      ('SALARY_DAY_ADJUSTMENT'::text, -20::numeric),
      ('SALARY_DAY_BASE'::text, 120::numeric),
      ('SALARY_DAY_OVERTIME'::text, 0::numeric)
  $$,
  'los deltas convergen exactamente a la revisión 3'
);

-- Complemento febrero: fuente separada y quinto concepto canónico.
create temporary table ledger_before_complement_0044 on commit drop as
select count(*)::bigint cantidad
from public.nomina_movimientos_tiempo_real;

insert into public.nomina_complementos_convencion_30(
  id, empresa_id, empleado_id, anio, fecha_fin_febrero, fecha_ancla,
  revision, estado, formula, timezone, sueldo_mensual, valor_dia,
  condicion_salarial_id, objetivo_complemento_30_dias,
  snapshot, input_hash, motivo, actor_id
) values (
  '44000000-0000-0000-0000-000000000421',
  '44000000-0000-0000-0000-000000000001',
  '44000000-0000-0000-0000-000000000201',
  2025, date '2025-02-28', date '2025-02-28',
  1, 'RESUELTO', 'FEBRUARY_30DAY_COMPLEMENT_V1',
  'America/Santo_Domingo', 3000, 100,
  '44000000-0000-0000-0000-000000000321',
  200, '{}'::jsonb, repeat('d', 64),
  'Complemento febrero 0044', null
);

select is(
  (select count(*) from public.nomina_movimientos_tiempo_real),
  (select cantidad from ledger_before_complement_0044),
  'insertar complemento 0043 tampoco toca el ledger automáticamente'
);
select lives_ok(
  $$select private.reconciliar_objetivos_nomina_canonicos_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-02-28', date '2025-02-28',
      null, 'Reconciliar complemento 30 días 0044'
    )$$,
  'el quinto concepto se reconcilia desde su fuente de febrero'
);
select is(
  (
    select round(sum(private.movimiento_nomina_firmado_0044(
      movement.clase, movement.monto
    )), 2)
    from public.nomina_identidades_economicas_canonicas identity_row
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = identity_row.empresa_id
     and movement.empleado_id = identity_row.empleado_id
     and movement.source_type = 'CANONICAL_SALARY_DELTA'
     and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
    where identity_row.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and identity_row.empleado_id =
        '44000000-0000-0000-0000-000000000201'
      and identity_row.fecha_economica = date '2025-02-28'
      and identity_row.concepto = 'SALARY_30DAY_COMPLEMENT'
  ),
  200::numeric,
  'SALARY_30DAY_COMPLEMENT queda materializado por identidad estable'
);

-- Desaparición y reaparición con el MISMO source hash.
select lives_ok(
  $$select private.materializar_objetivo_canonico_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-03-05', 'SALARY_DAY_BASE', 80,
      'DAILY_RESOLUTION',
      '44000000-0000-0000-0000-000000000451',
      1, repeat('1', 64), null, 'Fuente efímera 0044'
    )$$,
  'se prepara una identidad que luego desaparecerá'
);
select lives_ok(
  $$select private.reconciliar_objetivos_nomina_canonicos_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-03-05', date '2025-03-05',
      null, 'Fuente ausente 0044'
    )$$,
  'una identidad sin fuente vigente reconcilia target cero'
);
select is(
  (
    select round(sum(private.movimiento_nomina_firmado_0044(
      movement.clase, movement.monto
    )), 2)
    from public.nomina_identidades_economicas_canonicas identity_row
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = identity_row.empresa_id
     and movement.empleado_id = identity_row.empleado_id
     and movement.source_type = 'CANONICAL_SALARY_DELTA'
     and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
    where identity_row.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and identity_row.empleado_id =
        '44000000-0000-0000-0000-000000000201'
      and identity_row.fecha_economica = date '2025-03-05'
      and identity_row.concepto = 'SALARY_DAY_BASE'
  ),
  0::numeric,
  'fuente desaparecida revierte a cero sin borrar historial'
);
select lives_ok(
  $$select private.materializar_objetivo_canonico_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-03-05', 'SALARY_DAY_BASE', 80,
      'DAILY_RESOLUTION',
      '44000000-0000-0000-0000-000000000451',
      1, repeat('1', 64), null, 'Reaparece misma fuente 0044'
    )$$,
  'la misma revisión puede reaparecer después de ABSENT'
);
select is(
  (
    select round(sum(private.movimiento_nomina_firmado_0044(
      movement.clase, movement.monto
    )), 2)
    from public.nomina_identidades_economicas_canonicas identity_row
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = identity_row.empresa_id
     and movement.empleado_id = identity_row.empleado_id
     and movement.source_type = 'CANONICAL_SALARY_DELTA'
     and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
    where identity_row.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and identity_row.empleado_id =
        '44000000-0000-0000-0000-000000000201'
      and identity_row.fecha_economica = date '2025-03-05'
      and identity_row.concepto = 'SALARY_DAY_BASE'
  ),
  80::numeric,
  'reaparición con mismo hash crea un evento nuevo por cadena predecesora'
);
select lives_ok(
  $$select private.reconciliar_objetivos_nomina_canonicos_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-03-05', date '2025-03-05',
      null, 'Segunda desaparición 0044'
    )$$,
  'una segunda desaparición también es un evento distinto'
);
select is(
  (
    select max((movement.snapshot ->> 'event_order')::bigint)
    from public.nomina_movimientos_tiempo_real movement
    join public.nomina_identidades_economicas_canonicas identity_row
      on identity_row.empresa_id = movement.empresa_id
     and identity_row.empleado_id = movement.empleado_id
     and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
    where identity_row.fecha_economica = date '2025-03-05'
      and identity_row.concepto = 'SALARY_DAY_BASE'
      and movement.source_type = 'CANONICAL_SALARY_SOURCE'
  ),
  4::bigint,
  'la cadena de fuente conserva orden estable aun dentro de una transacción'
);

-- Un objetivo negativo sin pago real se representa como REVERSO_DEVENGO, no crédito.
select lives_ok(
  $$select private.materializar_objetivo_canonico_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-03-06', 'SALARY_DAY_ADJUSTMENT', -50,
      'DAILY_RESOLUTION',
      '44000000-0000-0000-0000-000000000461',
      1, repeat('2', 64), null, 'Ajuste negativo sin pago 0044'
    )$$,
  'ajuste negativo no pagado se materializa directamente'
);
select ok(
  exists (
    select 1
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and movement.empleado_id =
        '44000000-0000-0000-0000-000000000201'
      and movement.fecha_devengo = date '2025-03-06'
      and movement.source_type = 'CANONICAL_SALARY_DELTA'
      and movement.clase = 'REVERSO_DEVENGO'
      and movement.monto = 50
  )
  and not exists (
    select 1
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and movement.empleado_id =
        '44000000-0000-0000-0000-000000000201'
      and movement.fecha_devengo = date '2025-03-06'
      and movement.source_type = 'CANONICAL_SALARY_CREDIT'
  ),
  'sin dinero consumido no se inventa crédito residual'
);

-- Reducción que cruza dinero ya pagado: el pago histórico queda intacto y
-- el exceso se registra como CONTROL 0 con credit_delta en snapshot.
select lives_ok(
  $$select private.materializar_objetivo_canonico_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-03-07', 'SALARY_DAY_BASE', 600,
      'DAILY_RESOLUTION',
      '44000000-0000-0000-0000-000000000471',
      1, repeat('3', 64), null, 'Base pagable sintética 0044'
    )$$,
  'se materializa base inicial de 600'
);

insert into public.nomina_pagos_tiempo_real(
  id, empresa_id, empleado_id, fecha_desde, fecha_hasta,
  codigo_empleado, nombre_empleado, jornadas,
  monto_bruto, monto_deducciones, monto_pagado,
  formula, calculo, motivo, idempotency_key,
  source_fingerprint, pagado_por
) values (
  '44000000-0000-0000-0000-000000000481',
  '44000000-0000-0000-0000-000000000001',
  '44000000-0000-0000-0000-000000000201',
  date '2025-03-07', date '2025-03-07',
  '440001', 'Empleado Canónico 0044', 0,
  600, 0, 600,
  'CANONICAL_SALARY_BRIDGE_V1', '{}'::jsonb,
  'Pago sintético futuro 0044',
  '44000000-0000-0000-0000-000000000482',
  repeat('4', 64),
  '44000000-0000-0000-0000-000000000101'
);

insert into public.nomina_pago_movimientos(
  empresa_id, pago_id, movimiento_id, empleado_id,
  monto, source_type, source_key
)
select
  movement.empresa_id,
  '44000000-0000-0000-0000-000000000481',
  movement.id,
  movement.empleado_id,
  movement.monto,
  movement.source_type,
  movement.source_key
from public.nomina_movimientos_tiempo_real movement
join public.nomina_identidades_economicas_canonicas identity_row
  on identity_row.empresa_id = movement.empresa_id
 and identity_row.empleado_id = movement.empleado_id
 and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
where identity_row.empresa_id =
    '44000000-0000-0000-0000-000000000001'
  and identity_row.empleado_id =
    '44000000-0000-0000-0000-000000000201'
  and identity_row.fecha_economica = date '2025-03-07'
  and identity_row.concepto = 'SALARY_DAY_BASE'
  and movement.source_type = 'CANONICAL_SALARY_DELTA'
  and movement.clase = 'DEVENGO'
  and movement.monto = 600;

create temporary table payment_before_credit_0044 on commit drop as
select to_jsonb(payment) payload
from public.nomina_pagos_tiempo_real payment
where payment.id = '44000000-0000-0000-0000-000000000481';

select lives_ok(
  $$select private.materializar_objetivo_canonico_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-03-07', 'SALARY_DAY_BASE', 1000,
      'DAILY_RESOLUTION',
      '44000000-0000-0000-0000-000000000472',
      2, repeat('5', 64), null, 'Subir target tras pago 0044'
    )$$,
  'un aumento posterior agrega solo 400 no consumidos'
);
select lives_ok(
  $$select private.materializar_objetivo_canonico_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-03-07', 'SALARY_DAY_BASE', 400,
      'DAILY_RESOLUTION',
      '44000000-0000-0000-0000-000000000473',
      3, repeat('6', 64), null, 'Reducir target bajo lo pagado 0044'
    )$$,
  'reducir target bajo 600 preserva pago y registra crédito'
);

select is(
  (
    select round(sum(private.movimiento_nomina_firmado_0044(
      movement.clase, movement.monto
    )), 2)
    from public.nomina_movimientos_tiempo_real movement
    join public.nomina_identidades_economicas_canonicas identity_row
      on identity_row.empresa_id = movement.empresa_id
     and identity_row.empleado_id = movement.empleado_id
     and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
    where identity_row.fecha_economica = date '2025-03-07'
      and identity_row.concepto = 'SALARY_DAY_BASE'
      and movement.source_type = 'CANONICAL_SALARY_DELTA'
  ),
  600::numeric,
  'el target monetario nunca cae por debajo de los 600 ya pagados'
);
select is(
  (
    select round(sum(
      (movement.snapshot ->> 'credit_delta')::numeric
    ), 2)
    from public.nomina_movimientos_tiempo_real movement
    join public.nomina_identidades_economicas_canonicas identity_row
      on identity_row.empresa_id = movement.empresa_id
     and identity_row.empleado_id = movement.empleado_id
     and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
    where identity_row.fecha_economica = date '2025-03-07'
      and identity_row.concepto = 'SALARY_DAY_BASE'
      and movement.source_type = 'CANONICAL_SALARY_CREDIT'
  ),
  200::numeric,
  'la diferencia pagada de más queda como crédito residual 200'
);
select ok(
  not exists (
    select 1
    from public.nomina_movimientos_tiempo_real movement
    join public.nomina_identidades_economicas_canonicas identity_row
      on identity_row.empresa_id = movement.empresa_id
     and identity_row.empleado_id = movement.empleado_id
     and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
    where identity_row.fecha_economica = date '2025-03-07'
      and identity_row.concepto = 'SALARY_DAY_BASE'
      and movement.source_type = 'CANONICAL_SALARY_CREDIT'
      and (movement.clase <> 'CONTROL' or movement.monto <> 0)
  ),
  'todo crédito residual 0044 usa CONTROL con monto cero'
);
select is(
  (
    select to_jsonb(payment)::text
    from public.nomina_pagos_tiempo_real payment
    where payment.id = '44000000-0000-0000-0000-000000000481'
  ),
  (
    select payload::text
    from payment_before_credit_0044
  ),
  'reconciliar una reducción no reescribe el pago histórico'
);

select lives_ok(
  $$select private.materializar_objetivo_canonico_0044(
      '44000000-0000-0000-0000-000000000001',
      '44000000-0000-0000-0000-000000000201',
      date '2025-03-07', 'SALARY_DAY_BASE', 700,
      'DAILY_RESOLUTION',
      '44000000-0000-0000-0000-000000000474',
      4, repeat('7', 64), null, 'Cancelar crédito antes de aplicarlo 0044'
    )$$,
  'si el target vuelve sobre lo pagado se cancela el residual append-only'
);
select is(
  (
    select round(sum(
      (movement.snapshot ->> 'credit_delta')::numeric
    ), 2)
    from public.nomina_movimientos_tiempo_real movement
    join public.nomina_identidades_economicas_canonicas identity_row
      on identity_row.empresa_id = movement.empresa_id
     and identity_row.empleado_id = movement.empleado_id
     and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
    where identity_row.fecha_economica = date '2025-03-07'
      and identity_row.concepto = 'SALARY_DAY_BASE'
      and movement.source_type = 'CANONICAL_SALARY_CREDIT'
  ),
  0::numeric,
  'la cancelación usa otro CONTROL y deja crédito residual neto cero'
);
select is(
  (
    select round(sum(private.movimiento_nomina_firmado_0044(
      movement.clase, movement.monto
    )), 2)
    from public.nomina_movimientos_tiempo_real movement
    join public.nomina_identidades_economicas_canonicas identity_row
      on identity_row.empresa_id = movement.empresa_id
     and identity_row.empleado_id = movement.empleado_id
     and movement.snapshot ->> 'canonical_identity_id' = identity_row.id::text
    where identity_row.fecha_economica = date '2025-03-07'
      and identity_row.concepto = 'SALARY_DAY_BASE'
      and movement.source_type = 'CANONICAL_SALARY_DELTA'
  ),
  700::numeric,
  'el target monetario converge a 700 tras cancelar el residual'
);

select ok(
  not exists (
    select 1
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and movement.source_type like 'CANONICAL_SALARY_%'
      and movement.concepto in ('AFP', 'SFS')
  ),
  '0044 no materializa AFP ni SFS'
);
select ok(
  not exists (
    select 1
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id =
      '44000000-0000-0000-0000-000000000001'
      and movement.source_type = 'CANONICAL_SALARY_CREDIT'
      and movement.clase = 'DEDUCCION'
  ),
  '0044 registra el residual pero todavía no lo aplica como deducción'
);
select is(
  (
    select estado
    from public.nomina_cutover_canonico_empresas
    where empresa_id = '44000000-0000-0000-0000-000000000001'
  ),
  'INACTIVO',
  'todas las pruebas terminan con cutover INACTIVO'
);

select throws_ok(
  $$update public.nomina_identidades_economicas_canonicas
    set concepto = 'SALARY_DAY_BASE'
    where id = (
      select id
      from public.nomina_identidades_economicas_canonicas
      limit 1
    )$$,
  'P4400', 'CANONICAL_PAYROLL_IDENTITY_IMMUTABLE',
  'la identidad económica no admite UPDATE'
);

select * from finish();
rollback;
