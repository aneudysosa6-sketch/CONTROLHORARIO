begin;

set local search_path = extensions, public, pg_catalog;
set local role postgres;

select * from no_plan();

select has_table('public'::name, 'nomina_resoluciones_diarias'::name);
select has_table('public'::name, 'nomina_cierres_diarios'::name);
select has_table(
  'public'::name, 'nomina_complementos_convencion_30'::name
);
select has_table('public'::name, 'nomina_suspensiones_laborales'::name);
select has_column('public', 'nomina_cierres_diarios', 'origen', 'existe nomina_cierres_diarios.origen');
select has_column('public', 'nomina_cierres_diarios', 'intento', 'existe nomina_cierres_diarios.intento');
select has_column('public', 'nomina_suspensiones_laborales', 'revision', 'existe nomina_suspensiones_laborales.revision');
select has_column('public', 'nomina_suspensiones_laborales', 'fecha_hasta', 'existe nomina_suspensiones_laborales.fecha_hasta');
select has_column('public', 'nomina_complementos_convencion_30', 'fecha_ancla', 'existe nomina_complementos_convencion_30.fecha_ancla');
select has_column('public', 'nomina_complementos_convencion_30', 'objetivo_complemento_30_dias', 'existe nomina_complementos_convencion_30.objetivo_complemento_30_dias');
select has_column('public', 'nomina_complementos_convencion_30', 'revision', 'existe nomina_complementos_convencion_30.revision');
select has_view(
  'public'::name,
  'nomina_resoluciones_diarias_vigentes'::name
);
select has_view(
  'public'::name,
  'nomina_complementos_convencion_30_vigentes'::name
);
select has_function(
  'public', 'resolver_nomina_dia', array['uuid', 'date', 'text']
);
select has_function(
  'public', 'listar_resoluciones_nomina_diaria',
  array['uuid', 'date', 'date', 'boolean']
);
select has_function(
  'public', 'cerrar_nomina_dia_empresa', array['date', 'text']
);
select has_function(
  'public', 'cerrar_nomina_dias_vencidos', array[]::text[]
);
select has_function(
  'public', 'registrar_suspension_laboral_empleado',
  array['uuid', 'date', 'text', 'text']
);
select has_function(
  'public', 'registrar_suspension_laboral_empleado',
  array['uuid', 'date', 'date', 'text', 'text']
);
select has_function(
  'public', 'finalizar_suspension_laboral_empleado',
  array['uuid', 'date', 'text', 'text']
);
select has_function(
  'public', 'listar_suspensiones_laborales_empleado', array['uuid']
);
select has_function(
  'private', 'empleado_suspendido_en_fecha_nomina_0043',
  array['uuid', 'uuid', 'date']
);
select has_function(
  'private', 'resolucion_cubierta_por_suspension_0043',
  array['uuid', 'uuid', 'date']
);
select has_function(
  'private', 'rango_suspension_dentro_ciclo_laboral_0043',
  array['uuid', 'uuid', 'date', 'date']
);
select has_function(
  'private', 'resolver_complemento_convencion_30_0043',
  array['uuid', 'uuid', 'integer', 'uuid', 'text']
);
select has_function(
  'private', 'complemento_convencion_30_vigente_0043',
  array['uuid', 'uuid', 'integer', 'date', 'date']
);

select ok(
  (
    select bool_and(tabla.relrowsecurity)
    from pg_catalog.pg_class tabla
    where tabla.oid = any(array[
      'public.nomina_resoluciones_diarias'::regclass,
      'public.nomina_cierres_diarios'::regclass,
      'public.nomina_complementos_convencion_30'::regclass,
      'public.nomina_suspensiones_laborales'::regclass
    ])
  ),
  'RLS está habilitado en las tablas 0043'
);

select ok(
  not has_table_privilege(
    'authenticated', 'public.nomina_resoluciones_diarias',
    'INSERT,UPDATE,DELETE,TRUNCATE'
  )
  and not has_table_privilege(
    'authenticated', 'public.nomina_cierres_diarios',
    'INSERT,UPDATE,DELETE,TRUNCATE'
  )
  and not has_table_privilege(
    'authenticated', 'public.nomina_suspensiones_laborales',
    'INSERT,UPDATE,DELETE,TRUNCATE'
  )
  and not has_table_privilege(
    'authenticated', 'public.nomina_complementos_convencion_30',
    'INSERT,UPDATE,DELETE,TRUNCATE'
  ),
  'authenticated no tiene DML directo sobre las tablas economicas 0043'
);

select ok(
  has_table_privilege(
    'authenticated', 'public.nomina_complementos_convencion_30', 'SELECT'
  )
  and not has_table_privilege(
    'anon', 'public.nomina_complementos_convencion_30', 'SELECT'
  ),
  'complemento mensual expone solo SELECT autenticado sujeto a RLS'
);

select ok(
  (
    select bool_and(
      procedimiento.prosecdef
      and coalesce(array_to_string(procedimiento.proconfig, ','), '')
        like '%search_path=%'
    )
    from pg_catalog.pg_proc procedimiento
    where procedimiento.oid = any(array[
      'public.es_supervisor_nomina_0043()'::regprocedure,
      'public.resolver_nomina_dia(uuid,date,text)'::regprocedure,
      'public.listar_resoluciones_nomina_diaria(uuid,date,date,boolean)'::regprocedure,
      'public.cerrar_nomina_dia_empresa(date,text)'::regprocedure,
      'public.cerrar_nomina_dias_vencidos()'::regprocedure,
      'public.registrar_suspension_laboral_empleado(uuid,date,text,text)'::regprocedure,
      'public.registrar_suspension_laboral_empleado(uuid,date,date,text,text)'::regprocedure,
      'public.finalizar_suspension_laboral_empleado(uuid,date,text,text)'::regprocedure,
      'public.listar_suspensiones_laborales_empleado(uuid)'::regprocedure,
      'private.resolver_complemento_convencion_30_0043(uuid,uuid,integer,uuid,text)'::regprocedure,
      'private.complemento_convencion_30_vigente_0043(uuid,uuid,integer,date,date)'::regprocedure,
      'private.resolucion_cubierta_por_suspension_0043(uuid,uuid,date)'::regprocedure,
      'private.rango_suspension_dentro_ciclo_laboral_0043(uuid,uuid,date,date)'::regprocedure
    ])
  ),
  'RPC 0043 son SECURITY DEFINER con search_path fijo'
);

select ok(
  has_function_privilege(
    'authenticated', 'public.resolver_nomina_dia(uuid,date,text)', 'EXECUTE'
  )
  and has_function_privilege(
    'authenticated', 'public.es_supervisor_nomina_0043()', 'EXECUTE'
  )
  and not has_function_privilege(
    'anon', 'public.es_supervisor_nomina_0043()', 'EXECUTE'
  )
  and not has_function_privilege(
    'anon', 'public.resolver_nomina_dia(uuid,date,text)', 'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated', 'public.cerrar_nomina_dias_vencidos()', 'EXECUTE'
  )
  and has_function_privilege(
    'service_role', 'public.cerrar_nomina_dias_vencidos()', 'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.registrar_suspension_laboral_empleado(uuid,date,text,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.registrar_suspension_laboral_empleado(uuid,date,date,text,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.finalizar_suspension_laboral_empleado(uuid,date,text,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'public.listar_suspensiones_laborales_empleado(uuid)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'private.resolucion_cubierta_por_suspension_0043(uuid,uuid,date)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'private.resolucion_cubierta_por_suspension_0043(uuid,uuid,date)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'private.rango_suspension_dentro_ciclo_laboral_0043(uuid,uuid,date,date)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'authenticated',
    'private.resolver_complemento_convencion_30_0043(uuid,uuid,integer,uuid,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'private.resolver_complemento_convencion_30_0043(uuid,uuid,integer,uuid,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'private.resolver_complemento_convencion_30_0043(uuid,uuid,integer,uuid,text)',
    'EXECUTE'
  )
  and has_function_privilege(
    'authenticated',
    'private.complemento_convencion_30_vigente_0043(uuid,uuid,integer,date,date)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'private.complemento_convencion_30_vigente_0043(uuid,uuid,integer,date,date)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'service_role',
    'private.complemento_convencion_30_vigente_0043(uuid,uuid,integer,date,date)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.registrar_suspension_laboral_empleado(uuid,date,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.registrar_suspension_laboral_empleado(uuid,date,date,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon',
    'public.finalizar_suspension_laboral_empleado(uuid,date,text,text)',
    'EXECUTE'
  )
  and not has_function_privilege(
    'anon', 'public.listar_suspensiones_laborales_empleado(uuid)',
    'EXECUTE'
  ),
  'EXECUTE se limita a authenticated o service_role según cada RPC'
);

-- Matriz económica pura, enteramente sintética y sin escribir el ledger.
create temporary table expected_daily_0043(
  caso text primary key,
  fecha date not null,
  minutos_programados integer not null,
  minutos_trabajados integer not null,
  tiene_jornada boolean not null,
  cobertura_tipo text,
  cobertura_porcentaje numeric,
  es_festivo boolean not null,
  es_libre_manual boolean not null,
  base numeric not null,
  ajuste numeric not null,
  extra numeric not null,
  premium numeric not null,
  complemento numeric not null,
  total numeric not null,
  fuente text not null
) on commit drop;

insert into expected_daily_0043 values
  ('01_normal_8_de_8', date '2025-01-02', 480, 480, true, null, null, false, false, 100, 0, 0, 0, 0, 100, 'JORNADA'),
  ('02_normal_6_de_8', date '2025-01-03', 480, 360, true, null, null, false, false, 100, -25, 0, 0, 0, 75, 'JORNADA'),
  ('03_normal_3_de_4', date '2025-01-07', 240, 180, true, null, null, false, false, 100, -25, 0, 0, 0, 75, 'JORNADA'),
  ('04_extra_normal', date '2025-01-04', 480, 600, true, null, null, false, false, 100, 0, 50, 0, 0, 150, 'JORNADA'),
  ('05_libre_auto_sin_trabajo', date '2025-01-01', 0, 0, false, null, null, false, false, 100, 0, 0, 0, 0, 100, 'DIA_LIBRE_AUTOMATICO'),
  ('06_libre_auto_4h', date '2025-01-08', 0, 240, true, null, null, false, false, 100, -50, 0, 0, 0, 50, 'JORNADA'),
  ('07_libre_auto_8h', date '2025-01-15', 0, 480, true, null, null, false, false, 100, 0, 0, 0, 0, 100, 'JORNADA'),
  ('08_libre_auto_10h', date '2025-01-22', 0, 600, true, null, null, false, false, 100, 0, 50, 0, 0, 150, 'JORNADA'),
  ('09_libre_manual_sin_trabajo', date '2025-01-05', 480, 0, false, null, null, false, true, 100, 0, 0, 0, 0, 100, 'DIA_LIBRE_MANUAL'),
  ('10_libre_manual_4h', date '2025-01-12', 480, 240, true, null, null, false, true, 100, -50, 0, 0, 0, 50, 'JORNADA'),
  ('11_libre_manual_8h', date '2025-01-19', 480, 480, true, null, null, false, true, 100, 0, 0, 0, 0, 100, 'JORNADA'),
  ('12_libre_manual_10h', date '2025-01-26', 480, 600, true, null, null, false, true, 100, 0, 50, 0, 0, 150, 'JORNADA'),
  ('13_licencia_20', date '2025-01-06', 480, 0, false, 'LICENCIA', 20, false, false, 100, -80, 0, 0, 0, 20, 'LICENCIA'),
  ('14_vacaciones_100', date '2025-01-09', 480, 0, false, 'VACACIONES', 100, false, false, 100, 0, 0, 0, 0, 100, 'VACACIONES'),
  ('15_licencia_con_trabajo', date '2025-01-10', 480, 360, true, 'LICENCIA', 20, false, false, 100, -25, 0, 0, 0, 75, 'JORNADA'),
  ('16_licencia_festivo_sin_trabajo', date '2025-01-13', 480, 0, false, 'LICENCIA', 20, true, false, 100, -80, 0, 0, 0, 20, 'LICENCIA'),
  ('17_licencia_festivo_6_de_8', date '2025-01-16', 480, 360, true, 'LICENCIA', 20, true, false, 100, -25, 0, 75, 0, 150, 'JORNADA'),
  ('18_festivo_8_de_8', date '2025-01-17', 480, 480, true, null, null, true, false, 100, 0, 0, 100, 0, 200, 'JORNADA'),
  ('19_festivo_6_de_8', date '2025-01-18', 480, 360, true, null, null, true, false, 100, -25, 0, 75, 0, 150, 'JORNADA'),
  ('20_festivo_10_de_8', date '2025-01-20', 480, 600, true, null, null, true, false, 100, 0, 50, 100, 0, 250, 'JORNADA'),
  ('21_dia31_completo', date '2025-01-31', 480, 480, true, null, null, false, false, 0, 0, 0, 0, 0, 0, 'JORNADA'),
  ('22_dia31_parcial', date '2025-03-31', 480, 360, true, null, null, false, false, 0, -25, 0, 0, 0, -25, 'JORNADA'),
  ('23_dia31_ausencia', date '2025-05-31', 480, 0, false, null, null, false, false, 0, -100, 0, 0, 0, -100, 'AUSENCIA');

select results_eq(
  $$select
      caso,
      (calculo -> 'objetivos' ->> 'SALARY_DAY_BASE')::numeric,
      (calculo -> 'objetivos' ->> 'SALARY_DAY_ADJUSTMENT')::numeric,
      (calculo -> 'objetivos' ->> 'SALARY_DAY_OVERTIME')::numeric,
      (calculo -> 'objetivos' ->> 'HOLIDAY_NORMAL_PREMIUM')::numeric,
      (calculo -> 'objetivos' ->> 'SALARY_30DAY_COMPLEMENT')::numeric,
      round(
        (calculo -> 'objetivos' ->> 'SALARY_DAY_BASE')::numeric
        + (calculo -> 'objetivos' ->> 'SALARY_DAY_ADJUSTMENT')::numeric
        + (calculo -> 'objetivos' ->> 'SALARY_DAY_OVERTIME')::numeric
        + (calculo -> 'objetivos' ->> 'HOLIDAY_NORMAL_PREMIUM')::numeric
        + (calculo -> 'objetivos' ->> 'SALARY_30DAY_COMPLEMENT')::numeric,
        2
      ),
      calculo ->> 'fuente_economica'
    from expected_daily_0043 caso_esperado
    cross join lateral (
      select private.calcular_objetivos_nomina_dia_0043(
        caso_esperado.fecha, 3000, 25,
        caso_esperado.minutos_programados,
        caso_esperado.minutos_trabajados,
        caso_esperado.tiene_jornada,
        caso_esperado.cobertura_tipo,
        caso_esperado.cobertura_porcentaje,
        caso_esperado.es_festivo,
        caso_esperado.es_libre_manual
      ) calculo
    ) evaluacion
    order by caso$$,
  $$select caso, base, ajuste, extra, premium, complemento, total, fuente
    from expected_daily_0043 order by caso$$,
  'la matriz diaria conserva todos los componentes económicos congelados'
);

select is(
  (
    select round(sum(private.base_nominal_dia_0043(
      1000.03,
      make_date(2025, 1, indice)
    )), 2)
    from generate_series(1, 15) indice
  ),
  round(1000.03::numeric / 2, 2),
  'redondeo acumulativo: quince días completos suman Q exacto a centavos'
);
select results_eq(
  $$select
      (calculo -> 'objetivos' ->> 'SALARY_DAY_ADJUSTMENT')::numeric
    from (
      select private.calcular_objetivos_nomina_dia_0043(
        date '2025-01-31', 100, 25, 480, 0, false,
        'LICENCIA', 20, false, false
      ) calculo
    ) evaluacion$$,
  $$values (-2.67::numeric)$$,
  'día 31 calcula licencia sobre D exacto antes de redondear'
);
select results_eq(
  $$select
      (calculo -> 'objetivos' ->> 'SALARY_DAY_BASE')::numeric,
      (calculo ->> 'monto_normal_reconocido')::numeric,
      (calculo -> 'objetivos' ->> 'SALARY_DAY_ADJUSTMENT')::numeric,
      round(
        (calculo -> 'objetivos' ->> 'SALARY_DAY_BASE')::numeric
        + (calculo -> 'objetivos' ->> 'SALARY_DAY_ADJUSTMENT')::numeric,
        2
      )
    from (
      select private.calcular_objetivos_nomina_dia_0043(
        date '2025-01-03', 3000.60, 25, 480, 360, true,
        null, null, false, false
      ) calculo
    ) evaluacion$$,
  $$values (100.02::numeric, 75.02::numeric, -25::numeric, 75.02::numeric)$$,
  'días 1..30 mantienen base más ajuste igual al reconocido redondeado'
);
select results_eq(
  $$select
      (calculo ->> 'minutos_normales_reconocidos')::integer,
      (calculo ->> 'minutos_extra')::integer,
      (calculo -> 'objetivos' ->> 'SALARY_DAY_OVERTIME')::numeric,
      (calculo -> 'objetivos' ->> 'HOLIDAY_NORMAL_PREMIUM')::numeric
    from (
      select private.calcular_objetivos_nomina_dia_0043(
        date '2025-01-20', 3000, 25, 480, 600, true,
        null, null, true, false
      ) calculo
    ) evaluacion$$,
  $$values (480, 120, 50::numeric, 100::numeric)$$,
  'festivo limita premium a minutos normales y no duplica dos horas extra'
);

select results_eq(
  $$with fechas as (
      select dia::date fecha
      from generate_series(
        date '2025-02-16', date '2025-02-28', interval '1 day'
      ) dia
    ), calculos as (
      select fecha, private.calcular_objetivos_nomina_dia_0043(
        fecha, 3000, 25, 480,
        case when fecha = date '2025-02-20' then 0 else 480 end,
        fecha <> date '2025-02-20',
        null, null, false, false
      ) calculo
      from fechas
    )
    select
      count(*)::integer,
      round(sum((calculo -> 'objetivos' ->> 'SALARY_DAY_BASE')::numeric), 2),
      round(sum((calculo -> 'objetivos' ->> 'SALARY_DAY_ADJUSTMENT')::numeric), 2),
      round(sum((calculo -> 'objetivos' ->> 'SALARY_30DAY_COMPLEMENT')::numeric), 2),
      round(private.complemento_convencion_30_0043(
        3000, date '2025-02-28'
      ), 2),
      round(
        sum(
          (calculo -> 'objetivos' ->> 'SALARY_DAY_BASE')::numeric
          + (calculo -> 'objetivos' ->> 'SALARY_DAY_ADJUSTMENT')::numeric
          + (calculo -> 'objetivos' ->> 'SALARY_30DAY_COMPLEMENT')::numeric
        ) + private.complemento_convencion_30_0043(
          3000, date '2025-02-28'
        ),
        2
      ),
      min(fecha), max(fecha)
    from calculos$$,
  $$values (
    13, 1300::numeric, -100::numeric, 0::numeric, 200::numeric,
    1400::numeric, date '2025-02-16', date '2025-02-28'
  )$$,
  'febrero separa el complemento mensual y conserva descuento y fechas reales'
);

select results_eq(
  $$with escenarios(nombre, fecha_desde, faltas) as (
      values
        ('completo_dos_faltas'::text, date '2025-02-01',
          array[10, 11]::integer[]),
        ('completo_sin_faltas'::text, date '2025-02-01',
          array[]::integer[]),
        ('ingreso_20_cumple_20_28'::text, date '2025-02-20',
          array[]::integer[]),
        ('ingreso_20_dos_faltas'::text, date '2025-02-20',
          array[20, 21]::integer[])
    ), fechas as (
      select
        escenario.nombre,
        escenario.faltas,
        dia::date as fecha
      from escenarios escenario
      cross join lateral generate_series(
        escenario.fecha_desde, date '2025-02-28', interval '1 day'
      ) dia
    ), calculos as (
      select
        fecha.nombre,
        fecha.fecha,
        private.calcular_objetivos_nomina_dia_0043(
          fecha.fecha, 30000, 0, 480,
          case
            when extract(day from fecha.fecha)::integer = any(fecha.faltas)
              then 0
            else 480
          end,
          not (
            extract(day from fecha.fecha)::integer = any(fecha.faltas)
          ),
          null, null, false, false
        ) as calculo
      from fechas fecha
    )
    select
      nombre,
      count(*)::integer,
      count(*) filter (
        where (calculo ->> 'es_ausencia')::boolean
      )::integer,
      round(sum(
        (calculo -> 'objetivos' ->> 'SALARY_DAY_BASE')::numeric
      ), 2),
      round(sum(
        (calculo -> 'objetivos' ->> 'SALARY_DAY_ADJUSTMENT')::numeric
      ), 2),
      round(sum(
        (calculo -> 'objetivos' ->> 'SALARY_30DAY_COMPLEMENT')::numeric
      ), 2),
      round(private.complemento_convencion_30_0043(
        30000, date '2025-02-28'
      ), 2),
      round(
        sum(
          (calculo -> 'objetivos' ->> 'SALARY_DAY_BASE')::numeric
          + (calculo -> 'objetivos' ->> 'SALARY_DAY_ADJUSTMENT')::numeric
          + (calculo -> 'objetivos' ->> 'SALARY_30DAY_COMPLEMENT')::numeric
        ) + private.complemento_convencion_30_0043(
          30000, date '2025-02-28'
        ),
        2
      ),
      min(fecha), max(fecha)
    from calculos
    group by nombre
    order by nombre$$,
  $$values
      (
        'completo_dos_faltas'::text,
        28, 2, 28000::numeric, -2000::numeric, 0::numeric,
        2000::numeric, 28000::numeric,
        date '2025-02-01', date '2025-02-28'
      ),
      (
        'completo_sin_faltas'::text,
        28, 0, 28000::numeric, 0::numeric, 0::numeric,
        2000::numeric, 30000::numeric,
        date '2025-02-01', date '2025-02-28'
      ),
      (
        'ingreso_20_cumple_20_28'::text,
        9, 0, 9000::numeric, 0::numeric, 0::numeric,
        2000::numeric, 11000::numeric,
        date '2025-02-20', date '2025-02-28'
      ),
      (
        'ingreso_20_dos_faltas'::text,
        9, 2, 9000::numeric, -2000::numeric, 0::numeric,
        2000::numeric, 9000::numeric,
        date '2025-02-20', date '2025-02-28'
      )$$,
  'febrero paga 30D, descuenta faltas y prorratea ingreso desde el dia 20'
);
-- Fixture integrado aislado en el namespace UUID 43000000; todo hace rollback.
insert into auth.users(
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('43000000-0000-0000-0000-000000000101', 'authenticated', 'authenticated', 'admin-a-0043@test.local', 'not-used', now(), '{}', '{}', now(), now()),
  ('43000000-0000-0000-0000-000000000102', 'authenticated', 'authenticated', 'admin-b-0043@test.local', 'not-used', now(), '{}', '{}', now(), now()),
  ('43000000-0000-0000-0000-000000000103', 'authenticated', 'authenticated', 'supervisor-a-0043@test.local', 'not-used', now(), '{}', '{}', now(), now());

insert into public.companies(id, name, slug, timezone, status) values
  ('43000000-0000-0000-0000-000000000001', 'Empresa A Nómina 0043', 'empresa-a-nomina-0043', 'America/Santo_Domingo', 'active'),
  ('43000000-0000-0000-0000-000000000002', 'Empresa B Nómina 0043', 'empresa-b-nomina-0043', 'America/Santo_Domingo', 'active');

insert into public.roles(id, company_id, name, code, is_active) values
  ('43000000-0000-0000-0000-000000000011', '43000000-0000-0000-0000-000000000001', 'Administrador A 0043', 'admin', true),
  ('43000000-0000-0000-0000-000000000012', '43000000-0000-0000-0000-000000000002', 'Administrador B 0043', 'admin', true),
  ('43000000-0000-0000-0000-000000000013', '43000000-0000-0000-0000-000000000001', 'Supervisor A 0043', 'supervisor', true);

insert into public.branches(id, company_id, name, code, is_main, status) values
  ('43000000-0000-0000-0000-000000000021', '43000000-0000-0000-0000-000000000001', 'Sucursal A 0043', 'SA43', true, 'active'),
  ('43000000-0000-0000-0000-000000000022', '43000000-0000-0000-0000-000000000002', 'Sucursal B 0043', 'SB43', true, 'active');

insert into public.departments(id, company_id, branch_id, name, code, is_active) values
  ('43000000-0000-0000-0000-000000000031', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000021', 'Operaciones A 0043', 'OA43', true),
  ('43000000-0000-0000-0000-000000000032', '43000000-0000-0000-0000-000000000002', '43000000-0000-0000-0000-000000000022', 'Operaciones B 0043', 'OB43', true),
  ('43000000-0000-0000-0000-000000000033', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000021', 'Administración A 0043', 'AA43', true);

insert into public.employee_code_sequences(empresa_id, last_value) values
  ('43000000-0000-0000-0000-000000000001', 430000),
  ('43000000-0000-0000-0000-000000000002', 431000)
on conflict(empresa_id) do update set last_value = excluded.last_value;

insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id, codigo_empleado,
  nombre_completo, fecha_ingreso, estado_laboral, salario, tipo_pago, activo
) values (
  '43000000-0000-0000-0000-000000000201',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000021',
  '43000000-0000-0000-0000-000000000031',
  '430001', 'Empleado principal A 0043', date '2025-01-01',
  'activo', 3000, 'mensual', true
);
insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id, codigo_empleado,
  nombre_completo, fecha_ingreso, estado_laboral, salario, tipo_pago, activo
) values (
  '43000000-0000-0000-0000-000000000202',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000021',
  '43000000-0000-0000-0000-000000000031',
  '430002', 'Empleado nuevo A 0043', date '2025-02-20',
  'activo', 3000, 'mensual', true
);
insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id, codigo_empleado,
  nombre_completo, fecha_ingreso, estado_laboral, salario, tipo_pago, activo
) values (
  '43000000-0000-0000-0000-000000000203',
  '43000000-0000-0000-0000-000000000002',
  '43000000-0000-0000-0000-000000000022',
  '43000000-0000-0000-0000-000000000032',
  '431001', 'Empleado B 0043', date '2025-01-01',
  'activo', 3000, 'mensual', true
);
insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id, codigo_empleado,
  nombre_completo, fecha_ingreso, estado_laboral, salario, tipo_pago, activo
) values (
  '43000000-0000-0000-0000-000000000204',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000021',
  '43000000-0000-0000-0000-000000000033',
  '430003', 'Empleado fuera de alcance A 0043', date '2025-04-01',
  'activo', 3000, 'mensual', true
);

insert into public.profiles(
  id, company_id, role_id, branch_id, department_id, full_name, status
) values
  ('43000000-0000-0000-0000-000000000101', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000011', '43000000-0000-0000-0000-000000000021', '43000000-0000-0000-0000-000000000031', 'Administrador A 0043', 'active'),
  ('43000000-0000-0000-0000-000000000102', '43000000-0000-0000-0000-000000000002', '43000000-0000-0000-0000-000000000012', '43000000-0000-0000-0000-000000000022', '43000000-0000-0000-0000-000000000032', 'Administrador B 0043', 'active'),
  ('43000000-0000-0000-0000-000000000103', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000013', '43000000-0000-0000-0000-000000000021', '43000000-0000-0000-0000-000000000031', 'Supervisor A 0043', 'active');

insert into public.perfil_sucursales(perfil_id, sucursal_id) values (
  '43000000-0000-0000-0000-000000000103',
  '43000000-0000-0000-0000-000000000021'
);
insert into public.perfil_departamentos(perfil_id, departamento_id) values (
  '43000000-0000-0000-0000-000000000103',
  '43000000-0000-0000-0000-000000000031'
);

insert into public.rol_permisos(rol_id, permiso_id, permitido, alcance)
select rol.id, permiso.id, true, 'empresa'
from public.roles rol
cross join public.permisos permiso
where rol.id in (
  '43000000-0000-0000-0000-000000000011',
  '43000000-0000-0000-0000-000000000012',
  '43000000-0000-0000-0000-000000000013'
)
  and permiso.codigo in ('nomina.ver', 'nomina.generar')
on conflict(rol_id, permiso_id) do update set
  permitido = excluded.permitido,
  alcance = excluded.alcance;

insert into public.nomina_plantillas_horario(
  id, empresa_id, nombre, descripcion, created_by, updated_by
) values
  ('43000000-0000-0000-0000-000000000301', '43000000-0000-0000-0000-000000000001', 'Plantilla A 0043', 'Horario sintético A', '43000000-0000-0000-0000-000000000101', '43000000-0000-0000-0000-000000000101'),
  ('43000000-0000-0000-0000-000000000303', '43000000-0000-0000-0000-000000000002', 'Plantilla B 0043', 'Horario sintético B', '43000000-0000-0000-0000-000000000102', '43000000-0000-0000-0000-000000000102');

insert into public.nomina_plantilla_horario_versiones(
  id, empresa_id, plantilla_id, revision, descripcion, motivo, created_by
) values
  ('43000000-0000-0000-0000-000000000302', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000301', 1, 'Versión A', 'Fixture 0043 A', '43000000-0000-0000-0000-000000000101'),
  ('43000000-0000-0000-0000-000000000304', '43000000-0000-0000-0000-000000000002', '43000000-0000-0000-0000-000000000303', 1, 'Versión B', 'Fixture 0043 B', '43000000-0000-0000-0000-000000000102');

insert into public.nomina_plantilla_horario_dias(
  empresa_id, plantilla_version_id, iso_dia, minutos_normales, created_by
)
select
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000302',
  dia,
  case dia when 2 then 240 when 3 then 0 else 480 end,
  '43000000-0000-0000-0000-000000000101'
from generate_series(1, 7) dia;
insert into public.nomina_plantilla_horario_dias(
  empresa_id, plantilla_version_id, iso_dia, minutos_normales, created_by
)
select
  '43000000-0000-0000-0000-000000000002',
  '43000000-0000-0000-0000-000000000304',
  dia, 480,
  '43000000-0000-0000-0000-000000000102'
from generate_series(1, 7) dia;

insert into public.nomina_asignaciones_horario(
  id, empresa_id, empleado_id, plantilla_version_id,
  vigente_desde, vigente_hasta, motivo, created_by, updated_by
) values
  ('43000000-0000-0000-0000-000000000311', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000201', '43000000-0000-0000-0000-000000000302', date '2025-01-01', date '2025-12-31', 'Asignación principal 0043', '43000000-0000-0000-0000-000000000101', '43000000-0000-0000-0000-000000000101'),
  ('43000000-0000-0000-0000-000000000312', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000202', '43000000-0000-0000-0000-000000000302', date '2025-02-20', date '2025-12-31', 'Asignación nuevo 0043', '43000000-0000-0000-0000-000000000101', '43000000-0000-0000-0000-000000000101'),
  ('43000000-0000-0000-0000-000000000313', '43000000-0000-0000-0000-000000000002', '43000000-0000-0000-0000-000000000203', '43000000-0000-0000-0000-000000000304', date '2025-01-01', date '2025-12-31', 'Asignación B 0043', '43000000-0000-0000-0000-000000000102', '43000000-0000-0000-0000-000000000102'),
  ('43000000-0000-0000-0000-000000000314', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000204', '43000000-0000-0000-0000-000000000302', date '2025-04-01', date '2025-12-31', 'Asignación fuera de alcance 0043', '43000000-0000-0000-0000-000000000101', '43000000-0000-0000-0000-000000000101');

insert into public.nomina_condiciones_salariales(
  id, empresa_id, empleado_id, sueldo_mensual, valor_hora_extra,
  vigente_desde, vigente_hasta, motivo, created_by, updated_by
) values
  ('43000000-0000-0000-0000-000000000321', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000201', 3000, 25, date '2025-01-01', date '2025-12-31', 'Condición principal 0043', '43000000-0000-0000-0000-000000000101', '43000000-0000-0000-0000-000000000101'),
  ('43000000-0000-0000-0000-000000000322', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000202', 3000, 25, date '2025-02-20', date '2025-12-31', 'Condición nuevo 0043', '43000000-0000-0000-0000-000000000101', '43000000-0000-0000-0000-000000000101'),
  ('43000000-0000-0000-0000-000000000323', '43000000-0000-0000-0000-000000000002', '43000000-0000-0000-0000-000000000203', 3000, 25, date '2025-01-01', date '2025-12-31', 'Condición B 0043', '43000000-0000-0000-0000-000000000102', '43000000-0000-0000-0000-000000000102'),
  ('43000000-0000-0000-0000-000000000324', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000204', 3000, 25, date '2025-04-01', date '2025-12-31', 'Condición fuera de alcance 0043', '43000000-0000-0000-0000-000000000101', '43000000-0000-0000-0000-000000000101');

insert into public.nomina_dias_libres(
  id, empresa_id, empleado_id, vigente_desde, vigente_hasta,
  descripcion, created_by, updated_by
) values (
  '43000000-0000-0000-0000-000000000330',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000201',
  date '2025-01-01', date '2025-12-31', 'Domingo libre 0043',
  '43000000-0000-0000-0000-000000000101',
  '43000000-0000-0000-0000-000000000101'
);
insert into public.nomina_dia_libre_dias(
  id, empresa_id, configuracion_id, empleado_id, iso_dia, created_by
) values (
  '43000000-0000-0000-0000-000000000331',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000330',
  '43000000-0000-0000-0000-000000000201', 7,
  '43000000-0000-0000-0000-000000000101'
);

insert into public.nomina_coberturas(
  id, empresa_id, empleado_id, tipo, fecha_desde, fecha_hasta,
  porcentaje, descripcion, estado, aprobado_por, aprobado_en,
  created_by, updated_by
) values
(
  '43000000-0000-0000-0000-000000000341',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000201',
  'LICENCIA', date '2025-01-06', date '2025-01-06', 20,
  'Licencia sintética 0043', 'APROBADA',
  '43000000-0000-0000-0000-000000000101', now(),
  '43000000-0000-0000-0000-000000000101',
  '43000000-0000-0000-0000-000000000101'
),
(
  '43000000-0000-0000-0000-000000000344',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000201',
  'VACACIONES', date '2025-01-09', date '2025-01-09', 100,
  'Vacaciones sintéticas 0043', 'APROBADA',
  '43000000-0000-0000-0000-000000000101', now(),
  '43000000-0000-0000-0000-000000000101',
  '43000000-0000-0000-0000-000000000101'
);

insert into public.nomina_festivos(
  id, empresa_id, fecha, descripcion, created_by, updated_by
) values (
  '43000000-0000-0000-0000-000000000342',
  '43000000-0000-0000-0000-000000000001', date '2025-01-17',
  'Festivo sintético 0043',
  '43000000-0000-0000-0000-000000000101',
  '43000000-0000-0000-0000-000000000101'
);

insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values
  ('43000000-0000-0000-0000-000000000501', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000201', date '2025-01-02', 'FINALIZADA', timestamptz '2025-01-02 08:00:00-04', timestamptz '2025-01-02 17:00:00-04', 480, 60, 'WEB', false),
  ('43000000-0000-0000-0000-000000000502', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000201', date '2025-01-17', 'FINALIZADA', timestamptz '2025-01-17 08:00:00-04', timestamptz '2025-01-17 16:00:00-04', 480, 0, 'WEB', false),
  ('43000000-0000-0000-0000-000000000503', '43000000-0000-0000-0000-000000000001', '43000000-0000-0000-0000-000000000201', date '2025-01-23', 'FINALIZADA', timestamptz '2025-01-23 08:00:00-04', timestamptz '2025-01-23 14:00:00-04', 360, 0, 'WEB', false),
  ('43000000-0000-0000-0000-000000000504', '43000000-0000-0000-0000-000000000002', '43000000-0000-0000-0000-000000000203', date '2025-01-02', 'FINALIZADA', timestamptz '2025-01-02 08:00:00-04', timestamptz '2025-01-02 16:00:00-04', 480, 0, 'WEB', false);

create temporary table ledger_count_0043 as
select count(*)::bigint cantidad
from public.nomina_movimientos_tiempo_real;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000101', true
);

select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000201', date '2025-01-02',
      'Resolver jornada canónica 0043'
    )$$,
  'jornada finalizada se resuelve explícitamente'
);
select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000201', date '2025-01-01',
      'Resolver día libre automático 0043'
    )$$,
  'horario de cero minutos se resuelve como día libre automático'
);
select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000201', date '2025-01-05',
      'Resolver día libre manual 0043'
    )$$,
  'día libre manual sin trabajo se resuelve'
);
select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000201', date '2025-01-06',
      'Resolver licencia 0043'
    )$$,
  'licencia aprobada se resuelve'
);
select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000201', date '2025-01-09',
      'Resolver vacaciones 0043'
    )$$,
  'vacaciones aprobadas se resuelven al cien por ciento'
);
select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000201', date '2025-01-17',
      'Resolver festivo trabajado 0043'
    )$$,
  'festivo trabajado se resuelve con jornada real'
);
select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000201', date '2025-01-23',
      'Resolver fuente antes del festivo retroactivo'
    )$$,
  'primera resolución retroactiva se inserta'
);

select throws_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000203', date '2025-01-02',
      'Intento cross tenant 0043'
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'empresa A no puede resolver empleado de B'
);
select throws_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000202', date '2025-02-19',
      'Fecha anterior al ingreso 0043'
    )$$,
  'P4301', 'DATE_BEFORE_EMPLOYMENT',
  'nunca se resuelve una fecha anterior al ingreso'
);
select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000202', date '2025-02-20',
      'Ausencia vencida posterior al ingreso'
    )$$,
  'una ausencia vencida posterior al ingreso se resuelve'
);
select throws_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000202',
      (clock_timestamp() at time zone 'America/Santo_Domingo')::date,
      'Ausencia no vencida 0043'
    )$$,
  'P4302', 'DATE_NOT_EXPIRED',
  'la fecha local actual sin jornada no se marca como ausencia'
);

reset role;
set local role postgres;

select results_eq(
  $$select fecha_local, minutos_trabajados,
      (snapshot -> 'fuentes' -> 'jornada' ->> 'minutos_pausa')::integer,
      objetivo_total
    from public.nomina_resoluciones_diarias
    where empleado_id = '43000000-0000-0000-0000-000000000201'
      and fecha_local = date '2025-01-02'$$,
  $$values (date '2025-01-02', 480, 60, 100::numeric)$$,
  '0043 usa jornadas.minutos_trabajados y no resta minutos_pausa otra vez'
);

select ok(
  exists(
    select 1
    from public.nomina_resoluciones_diarias resolucion
    where resolucion.empleado_id = '43000000-0000-0000-0000-000000000201'
      and resolucion.fecha_local = date '2025-01-01'
      and resolucion.fuente_economica = 'DIA_LIBRE_AUTOMATICO'
      and resolucion.objetivo_total = 100
  )
  and
  exists(
    select 1
    from public.nomina_resoluciones_diarias resolucion
    where resolucion.empleado_id = '43000000-0000-0000-0000-000000000201'
      and resolucion.fecha_local = date '2025-01-05'
      and resolucion.dia_libre_id = '43000000-0000-0000-0000-000000000330'
      and resolucion.dia_libre_detalle_id = '43000000-0000-0000-0000-000000000331'
      and resolucion.objetivo_total = 100
  )
  and exists(
    select 1
    from public.nomina_resoluciones_diarias resolucion
    where resolucion.empleado_id = '43000000-0000-0000-0000-000000000201'
      and resolucion.fecha_local = date '2025-01-06'
      and resolucion.cobertura_id = '43000000-0000-0000-0000-000000000341'
      and resolucion.objetivo_total = 20
  )
  and exists(
    select 1
    from public.nomina_resoluciones_diarias resolucion
    where resolucion.empleado_id = '43000000-0000-0000-0000-000000000201'
      and resolucion.fecha_local = date '2025-01-09'
      and resolucion.cobertura_id = '43000000-0000-0000-0000-000000000344'
      and resolucion.cobertura_tipo = 'VACACIONES'
      and resolucion.objetivo_total = 100
  )
  and exists(
    select 1
    from public.nomina_resoluciones_diarias resolucion
    where resolucion.empleado_id = '43000000-0000-0000-0000-000000000201'
      and resolucion.fecha_local = date '2025-01-17'
      and resolucion.jornada_id = '43000000-0000-0000-0000-000000000502'
      and resolucion.festivo_id = '43000000-0000-0000-0000-000000000342'
      and resolucion.objetivo_premium_festivo = 100
      and resolucion.objetivo_total = 200
  ),
  'snapshots fijan horario cero, día libre, coberturas, jornada y festivo'
);

select ok(
  exists(
    select 1
    from public.nomina_resoluciones_diarias resolucion
    where resolucion.empleado_id = '43000000-0000-0000-0000-000000000202'
      and resolucion.fecha_local = date '2025-02-20'
      and resolucion.es_ausencia
  )
  and not exists(
    select 1
    from public.nomina_resoluciones_diarias resolucion
    where resolucion.empleado_id = '43000000-0000-0000-0000-000000000202'
      and (
        resolucion.fecha_local < date '2025-02-20'
        or resolucion.fecha_local >= (
          clock_timestamp() at time zone 'America/Santo_Domingo'
        )::date
      )
      and resolucion.es_ausencia
  ),
  'ausencia no es vacua: existe vencida y ninguna antes de ingreso/hoy/futuro'
);

insert into public.nomina_festivos(
  id, empresa_id, fecha, descripcion, created_by, updated_by
) values (
  '43000000-0000-0000-0000-000000000343',
  '43000000-0000-0000-0000-000000000001', date '2025-01-23',
  'Festivo retroactivo 0043',
  '43000000-0000-0000-0000-000000000101',
  '43000000-0000-0000-0000-000000000101'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000101', true
);
select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000201', date '2025-01-23',
      'Reconciliar festivo retroactivo 0043'
    )$$,
  'cambio retroactivo genera una nueva revisión'
);
select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000201', date '2025-01-23',
      'Repetir reconciliación idéntica 0043'
    )$$,
  'repetir la misma entrada es idempotente'
);
select is(
  jsonb_array_length(public.listar_resoluciones_nomina_diaria(
    '43000000-0000-0000-0000-000000000201',
    date '2025-01-23', date '2025-01-23', false
  )),
  1,
  'listar vigente devuelve solo la revisión canónica actual'
);
select is(
  jsonb_array_length(public.listar_resoluciones_nomina_diaria(
    '43000000-0000-0000-0000-000000000201',
    date '2025-01-23', date '2025-01-23', true
  )),
  2,
  'listar historial devuelve ambas revisiones sin crear otra'
);
reset role;
set local role postgres;

select results_eq(
  $$select revision, objetivo_ajuste_diario,
      objetivo_premium_festivo, objetivo_total,
      festivo_id is not null
    from public.nomina_resoluciones_diarias
    where empleado_id = '43000000-0000-0000-0000-000000000201'
      and fecha_local = date '2025-01-23'
    order by revision$$,
  $$values
      (1::bigint, -25::numeric, 0::numeric, 75::numeric, false),
      (2::bigint, -25::numeric, 75::numeric, 150::numeric, true)$$,
  're-resolución preserva revisión 1, crea revisión 2 y replay no duplica'
);

select is(
  (select count(*) from public.nomina_movimientos_tiempo_real),
  (select cantidad from ledger_count_0043),
  '0043 no crea, actualiza ni borra movimientos del ledger 0038'
);

select throws_ok(
  $$update public.nomina_resoluciones_diarias
    set motivo = 'Intento de mutación histórica'
    where id = (
      select id from public.nomina_resoluciones_diarias limit 1
    )$$,
  'P4300', 'NOMINA_DAILY_HISTORY_IMMUTABLE',
  'resoluciones históricas no admiten UPDATE'
);
select throws_ok(
  $$delete from public.nomina_resoluciones_diarias
    where id = (
      select id from public.nomina_resoluciones_diarias limit 1
    )$$,
  'P4300', 'NOMINA_DAILY_HISTORY_IMMUTABLE',
  'resoluciones históricas no admiten DELETE'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000101', true
);
select ok(
  (
    public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000204', date '2025-05-01',
      'Preparar resolución fuera del alcance supervisor'
    ) ->> 'inserted'
  )::boolean,
  'ADMIN prepara una resolución real en otro departamento'
);
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000103', true
);
select ok(
  public.es_supervisor_nomina_0043(),
  'el actor supervisor se reconoce sin exponer el helper privado'
);
select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000201', date '2025-01-02',
      'Supervisor resuelve dentro de su departamento'
    )$$,
  'SUPERVISOR con alcance empresa puede operar dentro de su departamento'
);
select throws_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000204', date '2025-05-01',
      'Supervisor intenta otro departamento'
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'alcance empresa no permite al SUPERVISOR salir de sus departamentos'
);
select throws_ok(
  $$select public.listar_resoluciones_nomina_diaria(
      '43000000-0000-0000-0000-000000000204',
      date '2025-05-01', date '2025-05-01', true
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'RPC de listado tampoco expone otro departamento al SUPERVISOR'
);
select throws_ok(
  $$select public.cerrar_nomina_dia_empresa(
      date '2025-05-01', 'Supervisor intenta cierre empresarial'
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'SUPERVISOR no puede ejecutar el cierre empresarial'
);
select throws_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000203', date '2025-01-02',
      'Supervisor intenta otro tenant'
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'SUPERVISOR no puede operar empleados de otro tenant'
);
select is(
  (
    select count(*)::integer
    from public.nomina_resoluciones_diarias
    where empleado_id = '43000000-0000-0000-0000-000000000204'
  ),
  0,
  'RLS oculta al SUPERVISOR resoluciones de otro departamento'
);
select ok(
  exists(
    select 1
    from public.nomina_resoluciones_diarias
    where empleado_id = '43000000-0000-0000-0000-000000000201'
  ),
  'RLS permite al SUPERVISOR consultar su departamento explícito'
);

select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000102', true
);
select ok(
  (
    public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000203', date '2025-01-02',
      'Resolver empleado empresa B'
    ) ->> 'inserted'
  )::boolean,
  'empresa B puede resolver su propio empleado'
);
select is(
  (
    select count(*)::integer
    from public.nomina_resoluciones_diarias
    where empresa_id = '43000000-0000-0000-0000-000000000001'
  ),
  0,
  'RLS oculta a empresa B las resoluciones de A'
);

select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000101', true
);
select is(
  (
    select count(*)::integer
    from public.nomina_resoluciones_diarias
    where empresa_id = '43000000-0000-0000-0000-000000000002'
  ),
  0,
  'RLS oculta a empresa A las resoluciones de B'
);

select lives_ok(
  $$select public.cerrar_nomina_dia_empresa(
      date '2025-03-01', 'Cierre explícito de prueba 0043'
    )$$,
  'cierre explícito procesa únicamente una fecha ya vencida'
);
select is(
  (
    select count(*)::integer
    from public.nomina_cierres_diarios cierre
    where cierre.empresa_id =
      '43000000-0000-0000-0000-000000000001'
      and cierre.fecha_local = date '2025-03-01'
  ),
  1,
  'RLS permite al ADMIN consultar el cierre de su propia empresa'
);
reset role;
set local role postgres;

select ok(
  exists(
    select 1
    from public.nomina_cierres_diarios cierre
    where cierre.empresa_id = '43000000-0000-0000-0000-000000000001'
      and cierre.fecha_local = date '2025-03-01'
      and cierre.estado = 'COMPLETADO'
      and cierre.origen = 'MANUAL'
      and cierre.intento = 1
      and cierre.empleados_objetivo = 2
      and cierre.resoluciones_nuevas = 2
      and cierre.errores = 0
  ),
  'cierre server-side deja ejecución auditada por empresa y fecha'
);

-- El automático usa fechas relativas a la zona empresarial y compañías
-- aisladas: C prueba el primer intento, D el catch-up y B error/reintento.
create temporary table fechas_auto_0043 on commit drop as
select
  hoy,
  hoy - 1 as ayer,
  hoy - 2 as omitido,
  hoy - 3 as semilla
from (
  select (
    clock_timestamp() at time zone 'America/Santo_Domingo'
  )::date as hoy
) fecha;

insert into public.companies(id, name, slug, timezone, status) values
  (
    '43000000-0000-0000-0000-000000000003',
    'Empresa C Automático 0043', 'empresa-c-auto-0043',
    'America/Santo_Domingo', 'active'
  ),
  (
    '43000000-0000-0000-0000-000000000004',
    'Empresa D Automático 0043', 'empresa-d-auto-0043',
    'America/Santo_Domingo', 'active'
  );

-- B tiene fuentes solo en la semilla: el siguiente día debe fallar.
insert into public.nomina_asignaciones_horario(
  id, empresa_id, empleado_id, plantilla_version_id,
  vigente_desde, vigente_hasta, motivo, created_by, updated_by
)
select
  '43000000-0000-0000-0000-000000000315',
  '43000000-0000-0000-0000-000000000002',
  '43000000-0000-0000-0000-000000000203',
  '43000000-0000-0000-0000-000000000304',
  fecha.semilla, fecha.semilla, 'Semilla automática B 0043',
  '43000000-0000-0000-0000-000000000102',
  '43000000-0000-0000-0000-000000000102'
from fechas_auto_0043 fecha;
insert into public.nomina_condiciones_salariales(
  id, empresa_id, empleado_id, sueldo_mensual, valor_hora_extra,
  vigente_desde, vigente_hasta, motivo, created_by, updated_by
)
select
  '43000000-0000-0000-0000-000000000325',
  '43000000-0000-0000-0000-000000000002',
  '43000000-0000-0000-0000-000000000203', 3000, 25,
  fecha.semilla, fecha.semilla, 'Condición automática B 0043',
  '43000000-0000-0000-0000-000000000102',
  '43000000-0000-0000-0000-000000000102'
from fechas_auto_0043 fecha;

select lives_ok(
  $$select private.cerrar_nomina_dia_empresa_0043(
      '43000000-0000-0000-0000-000000000002',
      (select semilla from fechas_auto_0043), null,
      'Semilla automática B 0043', 'AUTOMATICO'
    )$$,
  'se prepara un último día automático completado para B'
);
select lives_ok(
  $$select private.cerrar_nomina_dia_empresa_0043(
      '43000000-0000-0000-0000-000000000004',
      (select semilla from fechas_auto_0043), null,
      'Semilla automática D 0043', 'AUTOMATICO'
    )$$,
  'se prepara un último día automático completado para D'
);

set local role service_role;
select lives_ok(
  $$select public.cerrar_nomina_dias_vencidos()$$,
  'primera ejecución y recuperación automática se completan por empresa'
);
reset role;
set local role postgres;

select results_eq(
  $$select cierre.fecha_local, cierre.estado, cierre.empleados_objetivo
    from public.nomina_cierres_diarios cierre
    where cierre.empresa_id =
      '43000000-0000-0000-0000-000000000003'
      and cierre.origen = 'AUTOMATICO'
    order by cierre.fecha_local, cierre.intento$$,
  $$select ayer, 'COMPLETADO'::text, 0
    from fechas_auto_0043$$,
  'la primera ejecución automática procesa únicamente ayer'
);

select results_eq(
  $$select cierre.fecha_local, cierre.estado, cierre.empleados_objetivo
    from public.nomina_cierres_diarios cierre
    where cierre.empresa_id =
      '43000000-0000-0000-0000-000000000004'
      and cierre.origen = 'AUTOMATICO'
    order by cierre.fecha_local, cierre.intento$$,
  $$select semilla, 'COMPLETADO'::text, 0 from fechas_auto_0043
    union all
    select omitido, 'COMPLETADO'::text, 0 from fechas_auto_0043
    union all
    select ayer, 'COMPLETADO'::text, 0 from fechas_auto_0043$$,
  'si el cron omitió dos días, recupera ambos secuencialmente'
);

select results_eq(
  $$select cierre.fecha_local, cierre.intento, cierre.estado,
      cierre.empleados_objetivo, cierre.errores
    from public.nomina_cierres_diarios cierre
    where cierre.empresa_id =
      '43000000-0000-0000-0000-000000000002'
      and cierre.origen = 'AUTOMATICO'
    order by cierre.fecha_local, cierre.intento$$,
  $$select semilla, 1::bigint, 'COMPLETADO'::text, 1, 0
    from fechas_auto_0043
    union all
    select omitido, 1::bigint, 'CON_ERRORES'::text, 1, 1
    from fechas_auto_0043$$,
  'un cierre con error queda registrado y no salta al día siguiente'
);
select ok(
  not exists (
    select 1
    from public.nomina_cierres_diarios cierre
    cross join fechas_auto_0043 fecha
    where cierre.empresa_id =
      '43000000-0000-0000-0000-000000000002'
      and cierre.fecha_local = fecha.ayer
      and cierre.origen = 'AUTOMATICO'
  ),
  'el automático se detiene exactamente en el primer CON_ERRORES'
);

-- Al reparar las fuentes, el siguiente intento reabre el mismo día y continúa.
insert into public.nomina_asignaciones_horario(
  id, empresa_id, empleado_id, plantilla_version_id,
  vigente_desde, vigente_hasta, motivo, created_by, updated_by
)
select
  '43000000-0000-0000-0000-000000000316',
  '43000000-0000-0000-0000-000000000002',
  '43000000-0000-0000-0000-000000000203',
  '43000000-0000-0000-0000-000000000304',
  fecha.omitido, fecha.ayer, 'Reparación automática B 0043',
  '43000000-0000-0000-0000-000000000102',
  '43000000-0000-0000-0000-000000000102'
from fechas_auto_0043 fecha;
insert into public.nomina_condiciones_salariales(
  id, empresa_id, empleado_id, sueldo_mensual, valor_hora_extra,
  vigente_desde, vigente_hasta, motivo, created_by, updated_by
)
select
  '43000000-0000-0000-0000-000000000326',
  '43000000-0000-0000-0000-000000000002',
  '43000000-0000-0000-0000-000000000203', 3000, 25,
  fecha.omitido, fecha.ayer, 'Reparación automática B 0043',
  '43000000-0000-0000-0000-000000000102',
  '43000000-0000-0000-0000-000000000102'
from fechas_auto_0043 fecha;

set local role service_role;
select lives_ok(
  $$select public.cerrar_nomina_dias_vencidos()$$,
  'el cron reintenta el hueco reparado y luego avanza'
);
reset role;
set local role postgres;

select results_eq(
  $$select cierre.fecha_local, cierre.intento, cierre.estado,
      cierre.errores
    from public.nomina_cierres_diarios cierre
    where cierre.empresa_id =
      '43000000-0000-0000-0000-000000000002'
      and cierre.origen = 'AUTOMATICO'
    order by cierre.fecha_local, cierre.intento$$,
  $$select semilla, 1::bigint, 'COMPLETADO'::text, 0
    from fechas_auto_0043
    union all
    select omitido, 1::bigint, 'CON_ERRORES'::text, 1
    from fechas_auto_0043
    union all
    select omitido, 2::bigint, 'COMPLETADO'::text, 0
    from fechas_auto_0043
    union all
    select ayer, 1::bigint, 'COMPLETADO'::text, 0
    from fechas_auto_0043$$,
  'CON_ERRORES se reintenta append-only y después se procesa ayer'
);
select ok(
  (select count(*) from public.nomina_cierres_diarios cierre
    where cierre.empresa_id =
      '43000000-0000-0000-0000-000000000003'
      and cierre.origen = 'AUTOMATICO') = 1
  and
  (select count(*) from public.nomina_cierres_diarios cierre
    where cierre.empresa_id =
      '43000000-0000-0000-0000-000000000004'
      and cierre.origen = 'AUTOMATICO') = 3,
  'repetir el runner no duplica días ya completados'
);
select ok(
  not exists (
    select 1
    from public.nomina_cierres_diarios cierre
    cross join fechas_auto_0043 fecha
    where cierre.empresa_id in (
      '43000000-0000-0000-0000-000000000002',
      '43000000-0000-0000-0000-000000000003',
      '43000000-0000-0000-0000-000000000004'
    )
      and cierre.fecha_local >= fecha.hoy
  )
  and not exists (
    select 1
    from public.nomina_resoluciones_diarias resolucion
    cross join fechas_auto_0043 fecha
    where resolucion.empresa_id =
      '43000000-0000-0000-0000-000000000002'
      and resolucion.fecha_local >= fecha.hoy
  ),
  'el cierre automático nunca procesa hoy ni fechas futuras'
);


-- Suspensiones laborales versionadas: se agregan después del cron para que
-- ningún fixture nuevo altere la recuperación automática ya verificada.
insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id, codigo_empleado,
  nombre_completo, fecha_ingreso, estado_laboral, salario, tipo_pago, activo
) values (
  '43000000-0000-0000-0000-000000000206',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000021',
  '43000000-0000-0000-0000-000000000031',
  '430004', 'Empleado suspensión A 0043', date '2025-04-01',
  'activo', 3000, 'mensual', true
);

insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id, codigo_empleado,
  nombre_completo, fecha_ingreso, estado_laboral, salario, tipo_pago, activo
) values (
  '43000000-0000-0000-0000-000000000207',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000021',
  '43000000-0000-0000-0000-000000000031',
  '430005', 'Empleado suspension directa A 0043', date '2025-10-01',
  'activo', 3000, 'mensual', true
);

create temporary table suspension_ids_0043(
  clave text primary key,
  id uuid not null
) on commit drop;
grant select, insert on suspension_ids_0043 to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000103', true
);
select throws_ok(
  $$select public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000206',
      date '2025-05-10', 'Suspensión sin permiso HR', null
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'supervisor sin recursos_humanos.acceder no registra suspensiones'
);
select throws_ok(
  $$select public.listar_suspensiones_laborales_empleado(
      '43000000-0000-0000-0000-000000000206'
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'supervisor sin recursos_humanos.acceder no lista suspensiones'
);
reset role;
set local role postgres;

select is(
  (select count(*) from public.nomina_suspensiones_laborales
   where empleado_id = '43000000-0000-0000-0000-000000000206'),
  0::bigint,
  'denegar por permiso no deja historia parcial'
);

insert into public.rol_permisos(rol_id, permiso_id, permitido, alcance)
select
  '43000000-0000-0000-0000-000000000013',
  permiso.id, true, 'empresa'
from public.permisos permiso
where permiso.codigo = 'recursos_humanos.acceder'
on conflict(rol_id, permiso_id) do update set
  permitido = true,
  alcance = 'empresa';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000103', true
);
select lives_ok(
  $$insert into suspension_ids_0043(clave, id)
    select 'directo_cerrado', public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000207',
      date '2025-10-10', date '2025-10-18',
      'Suspension cerrada directa 0043', 'Rango inclusivo'
    )$$,
  'overload de cinco argumentos registra un ciclo cerrado atomico'
);
select throws_ok(
  $$select public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000207',
      date '2025-11-18', date '2025-11-10',
      'Rango cerrado invertido 0043', null
    )$$,
  'P4308', 'SUSPENSION_REQUEST_INVALID',
  'overload cerrado rechaza fecha final anterior a la inicial'
);
select is(
  jsonb_array_length(
    public.listar_suspensiones_laborales_empleado(
      '43000000-0000-0000-0000-000000000207'
    )
  ),
  2,
  'overload cerrado lista la revision abierta y la finalizada'
);
reset role;
set local role postgres;

select results_eq(
  $$select revision, estado, fecha_desde, fecha_hasta,
      id = suspension_id, version_anterior_id is null
    from public.nomina_suspensiones_laborales
    where suspension_id = (
      select id from suspension_ids_0043 where clave = 'directo_cerrado'
    )
    order by revision$$,
  $$values
      (1::bigint, 'ABIERTA'::text, date '2025-10-10', null::date, true, true),
      (2::bigint, 'FINALIZADA'::text, date '2025-10-10', date '2025-10-18', false, false)$$,
  'overload cerrado conserva ambas revisiones append-only'
);
select results_eq(
  $$with fechas(fecha) as (
      values
        (date '2025-10-09'), (date '2025-10-10'),
        (date '2025-10-18'), (date '2025-10-19')
    )
    select fecha,
      not private.empleado_suspendido_en_fecha_nomina_0043(
        '43000000-0000-0000-0000-000000000001',
        '43000000-0000-0000-0000-000000000207', fecha
      ) as elegible
    from fechas order by fecha$$,
  $$values
      (date '2025-10-09', true),
      (date '2025-10-10', false),
      (date '2025-10-18', false),
      (date '2025-10-19', true)$$,
  'overload cerrado respeta limites inclusivos y habilita el dia posterior'
);

select throws_ok(
  $$update public.empleados
    set estado_laboral = 'desvinculado',
        activo = false,
        fecha_desvinculacion = date '2025-10-15'
    where id = '43000000-0000-0000-0000-000000000207'$$,
  'P4315', 'EMPLOYEE_OPEN_SUSPENSION_MUST_BE_CLOSED',
  'baja retroactiva no puede cortar una suspension ya finalizada'
);
select results_eq(
  $$select estado_laboral, activo, fecha_desvinculacion
    from public.empleados
    where id = '43000000-0000-0000-0000-000000000207'$$,
  $$values ('activo'::text, true, null::date)$$,
  'rechazar la baja retroactiva conserva intacto al empleado'
);
select results_eq(
  $$select revision, estado, fecha_desde, fecha_hasta
    from public.nomina_suspensiones_laborales
    where suspension_id = (
      select id from suspension_ids_0043 where clave = 'directo_cerrado'
    )
    order by revision$$,
  $$values
      (1::bigint, 'ABIERTA'::text, date '2025-10-10', null::date),
      (2::bigint, 'FINALIZADA'::text, date '2025-10-10', date '2025-10-18')$$,
  'rechazar la baja retroactiva conserva ambas revisiones de suspension'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000103', true
);
select lives_ok(
  $$insert into suspension_ids_0043(clave, id)
    select 'ciclo_1', public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000206',
      date '2025-05-10', 'Suspensión ciclo uno 0043', 'Inicio histórico'
    )$$,
  'supervisor con HR registra suspensión en su departamento'
);
select lives_ok(
  $$insert into suspension_ids_0043(clave, id)
    select 'ciclo_1_fin', public.finalizar_suspension_laboral_empleado(
      (select id from suspension_ids_0043 where clave = 'ciclo_1'),
      date '2025-05-18', 'Finalizar ciclo uno 0043', 'Fin histórico inclusivo'
    )$$,
  'supervisor con HR finaliza suspensión en su departamento'
);
select is(
  jsonb_array_length(
    public.listar_suspensiones_laborales_empleado(
      '43000000-0000-0000-0000-000000000206'
    )
  ),
  2,
  'listar devuelve las dos revisiones del primer ciclo'
);
select ok(
  not (
    (
      public.listar_suspensiones_laborales_empleado(
        '43000000-0000-0000-0000-000000000206'
      ) -> 0
    ) ?| array['empresa_id', 'created_by']
  ),
  'listar suspensiones no expone tenant ni actor interno'
);
select throws_ok(
  $$select public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000204',
      date '2025-11-10', 'Intento fuera de departamento', null
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'supervisor con HR no registra fuera de sus departamentos'
);
select throws_ok(
  $$select public.listar_suspensiones_laborales_empleado(
      '43000000-0000-0000-0000-000000000204'
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'supervisor con HR no lista fuera de sus departamentos'
);
select throws_ok(
  $$select public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000203',
      date '2025-11-10', 'Intento cross tenant', null
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'supervisor con HR no registra en otro tenant'
);
select throws_ok(
  $$select public.listar_suspensiones_laborales_empleado(
      '43000000-0000-0000-0000-000000000203'
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'supervisor con HR no lista otro tenant'
);
select throws_ok(
  $$select public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000206',
      date '2025-05-15', 'Solape con ciclo uno', null
    )$$,
  'P4313', 'EMPLOYEE_SUSPENSION_OVERLAP',
  'no permite solapar una suspensión cerrada'
);
select lives_ok(
  $$insert into suspension_ids_0043(clave, id)
    select 'ciclo_2', public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000206',
      date '2025-07-10', 'Suspensión ciclo dos 0043', null
    )$$,
  'permite un segundo ciclo no solapado'
);
select lives_ok(
  $$insert into suspension_ids_0043(clave, id)
    select 'ciclo_2_fin', public.finalizar_suspension_laboral_empleado(
      (select id from suspension_ids_0043 where clave = 'ciclo_2'),
      date '2025-07-18', 'Finalizar ciclo dos 0043', null
    )$$,
  'finaliza el segundo ciclo sin alterar el primero'
);
select lives_ok(
  $$insert into suspension_ids_0043(clave, id)
    select 'ciclo_3', public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000206',
      date '2025-09-10', 'Suspensión abierta 0043', null
    )$$,
  'registra una suspensión abierta'
);
select throws_ok(
  $$select public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000206',
      date '2025-10-01', 'Segunda suspensión abierta', null
    )$$,
  'P4313', 'EMPLOYEE_SUSPENSION_OVERLAP',
  'no permite dos suspensiones abiertas'
);
select is(
  jsonb_array_length(
    public.listar_suspensiones_laborales_empleado(
      '43000000-0000-0000-0000-000000000206'
    )
  ),
  5,
  'listar conserva tres ciclos y todas sus revisiones'
);
reset role;
set local role postgres;

select throws_ok(
  $$update public.empleados
    set estado_laboral = 'desvinculado', activo = false
    where id = '43000000-0000-0000-0000-000000000206'$$,
  'P4315', 'EMPLOYEE_OPEN_SUSPENSION_MUST_BE_CLOSED',
  'no permite desvincular un empleado con suspension abierta'
);
select ok(
  exists(
    select 1 from public.empleados
    where id = '43000000-0000-0000-0000-000000000206'
      and estado_laboral = 'activo'
      and activo
  ),
  'rechazar la baja conserva intacta la proyeccion del empleado'
);

select results_eq(
  $$select revision, estado, fecha_desde, fecha_hasta,
      id = suspension_id, version_anterior_id is null
    from public.nomina_suspensiones_laborales
    where suspension_id = (
      select id from suspension_ids_0043 where clave = 'ciclo_1'
    )
    order by revision$$,
  $$values
      (1::bigint, 'ABIERTA'::text, date '2025-05-10', null::date, true, true),
      (2::bigint, 'FINALIZADA'::text, date '2025-05-10', date '2025-05-18', false, false)$$,
  'finalizar crea revisión dos y conserva inmutable la revisión abierta'
);
select is(
  (
    select version_anterior_id
    from public.nomina_suspensiones_laborales
    where id = (
      select id from suspension_ids_0043 where clave = 'ciclo_1_fin'
    )
  ),
  (select id from suspension_ids_0043 where clave = 'ciclo_1'),
  'la revisión finalizada referencia exactamente la revisión original'
);

select results_eq(
  $$with fechas(fecha) as (
      values
        (date '2025-05-09'), (date '2025-05-10'),
        (date '2025-05-18'), (date '2025-05-19')
    )
    select fecha,
      not private.empleado_suspendido_en_fecha_nomina_0043(
        '43000000-0000-0000-0000-000000000001',
        '43000000-0000-0000-0000-000000000206', fecha
      ) as elegible
    from fechas order by fecha$$,
  $$values
      (date '2025-05-09', true),
      (date '2025-05-10', false),
      (date '2025-05-18', false),
      (date '2025-05-19', true)$$,
  'suspensión cerrada es inclusiva y el día posterior vuelve a ser elegible'
);
select results_eq(
  $$select
      count(distinct suspension_id)::integer,
      count(*)::integer
    from public.nomina_suspensiones_laborales
    where empleado_id = '43000000-0000-0000-0000-000000000206'$$,
  $$values (3, 5)$$,
  'múltiples ciclos tienen raíces separadas e historial append-only'
);
select results_eq(
  $$with fechas(fecha) as (
      values
        (date '2025-05-15'), (date '2025-06-01'),
        (date '2025-07-15'), (date '2025-08-01')
    )
    select fecha,
      private.empleado_suspendido_en_fecha_nomina_0043(
        '43000000-0000-0000-0000-000000000001',
        '43000000-0000-0000-0000-000000000206', fecha
      )
    from fechas order by fecha$$,
  $$values
      (date '2025-05-15', true),
      (date '2025-06-01', false),
      (date '2025-07-15', true),
      (date '2025-08-01', false)$$,
  'dos ciclos cerrados no contaminan el intervalo entre ambos'
);
select results_eq(
  $$with fechas(fecha) as (
      values
        (date '2025-09-09'), (date '2025-09-10'),
        (date '2025-12-31')
    )
    select fecha,
      private.empleado_suspendido_en_fecha_nomina_0043(
        '43000000-0000-0000-0000-000000000001',
        '43000000-0000-0000-0000-000000000206', fecha
      )
    from fechas order by fecha$$,
  $$values
      (date '2025-09-09', false),
      (date '2025-09-10', true),
      (date '2025-12-31', true)$$,
  'suspensión abierta cubre desde su inicio sin inventar fecha final'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000101', true
);
select throws_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000206', date '2025-05-15',
      'No resolver fecha suspendida'
    )$$,
  'P4312', 'EMPLOYEE_SUSPENDED_ON_DATE',
  'resolver manualmente una fecha suspendida falla con error dedicado'
);
reset role;
set local role postgres;

select is(
  (select count(*) from public.nomina_resoluciones_diarias
   where empleado_id = '43000000-0000-0000-0000-000000000206'
     and fecha_local = date '2025-05-15'),
  0::bigint,
  'resolver suspendido no deja resolución ni ausencia'
);
select lives_ok(
  $$select private.cerrar_nomina_dia_empresa_0043(
      '43000000-0000-0000-0000-000000000001',
      date '2025-05-15',
      '43000000-0000-0000-0000-000000000101',
      'Cierre excluye suspensión 0043', 'MANUAL'
    )$$,
  'cierre diario excluye al empleado suspendido sin fallar'
);
select ok(
  exists(
    select 1
    from public.nomina_cierres_diarios cierre
    where cierre.empresa_id = '43000000-0000-0000-0000-000000000001'
      and cierre.fecha_local = date '2025-05-15'
      and cierre.estado = 'COMPLETADO'
      and cierre.empleados_objetivo = 3
      and cierre.resoluciones_nuevas = 3
      and cierre.errores = 0
  ),
  'suspendido no aumenta objetivo ni genera error de cierre'
);
select is(
  (select count(*) from public.nomina_resoluciones_diarias
   where empleado_id = '43000000-0000-0000-0000-000000000206'
     and fecha_local = date '2025-05-15'),
  0::bigint,
  'cierre no convierte suspensión en ausencia ni descuento'
);

-- El complemento de febrero vive fuera de la resolucion diaria. Este fixture
-- cobra vacaciones del 1 al 27 y queda suspendido solamente el dia 28.
insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id, codigo_empleado,
  nombre_completo, fecha_ingreso, estado_laboral, salario, tipo_pago, activo
) values (
  '43000000-0000-0000-0000-000000000208',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000021',
  '43000000-0000-0000-0000-000000000031',
  '430006', 'Empleado febrero suspendido 0043', date '2025-02-01',
  'activo', 3000, 'mensual', true
);
insert into public.nomina_asignaciones_horario(
  id, empresa_id, empleado_id, plantilla_version_id,
  vigente_desde, vigente_hasta, motivo, created_by, updated_by
) values (
  '43000000-0000-0000-0000-000000000317',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000208',
  '43000000-0000-0000-0000-000000000302',
  date '2025-02-01', date '2025-12-31',
  'Horario febrero suspendido 0043',
  '43000000-0000-0000-0000-000000000101',
  '43000000-0000-0000-0000-000000000101'
);
insert into public.nomina_condiciones_salariales(
  id, empresa_id, empleado_id, sueldo_mensual, valor_hora_extra,
  vigente_desde, vigente_hasta, motivo, created_by, updated_by
) values (
  '43000000-0000-0000-0000-000000000327',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000208',
  3000, 25, date '2025-02-01', date '2025-12-31',
  'Salario febrero suspendido 0043',
  '43000000-0000-0000-0000-000000000101',
  '43000000-0000-0000-0000-000000000101'
);
insert into public.nomina_coberturas(
  id, empresa_id, empleado_id, tipo, fecha_desde, fecha_hasta,
  porcentaje, descripcion, estado, aprobado_por, aprobado_en,
  created_by, updated_by
) values (
  '43000000-0000-0000-0000-000000000345',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000208',
  'VACACIONES', date '2025-02-01', date '2025-02-27', 100,
  'Vacaciones febrero 1 a 27 0043', 'APROBADA',
  '43000000-0000-0000-0000-000000000101', now(),
  '43000000-0000-0000-0000-000000000101',
  '43000000-0000-0000-0000-000000000101'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000103', true
);
select lives_ok(
  $$select public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000208',
      date '2025-02-28', date '2025-02-28',
      'Suspension solamente el 28 de febrero', null
    )$$,
  'supervisor con HR registra la suspension cerrada del dia 28'
);
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000101', true
);
select lives_ok(
  $$select public.resolver_nomina_dia(
      '43000000-0000-0000-0000-000000000208',
      dia::date, 'Resolver vacaciones febrero 0043'
    )
    from generate_series(
      date '2025-02-01', date '2025-02-27', interval '1 day'
    ) dia$$,
  'vacaciones completas generan exactamente los 27 dias elegibles'
);
select lives_ok(
  $$select public.cerrar_nomina_dia_empresa(
      date '2025-02-28', 'Cierre febrero con suspension el 28'
    )$$,
  'primer cierre de febrero resuelve el complemento mensual'
);
select lives_ok(
  $$select public.cerrar_nomina_dia_empresa(
      date '2025-02-28', 'Retry cierre febrero con suspension el 28'
    )$$,
  'retry de febrero reutiliza el complemento mensual'
);
reset role;
set local role postgres;

select results_eq(
  $$select
      count(*)::integer,
      count(*) filter (where fuente_economica = 'VACACIONES')::integer,
      round(sum(objetivo_base_nominal), 2),
      round(sum(objetivo_ajuste_diario), 2),
      round(sum(objetivo_complemento_30_dias), 2),
      round(sum(objetivo_total), 2)
    from public.nomina_resoluciones_diarias
    where empleado_id = '43000000-0000-0000-0000-000000000208'$$,
  $$values (
    27, 27, 2700::numeric, 0::numeric, 0::numeric, 2700::numeric
  )$$,
  'suspendido solo el 28 conserva 27D diarios sin complemento diario'
);
select is(
  (select count(*)
   from public.nomina_resoluciones_diarias
   where empleado_id = '43000000-0000-0000-0000-000000000208'
     and fecha_local = date '2025-02-28'),
  0::bigint,
  'el dia suspendido no crea resolucion diaria ni ausencia'
);
select results_eq(
  $$select
      revision, fecha_fin_febrero, fecha_ancla,
      sueldo_mensual, valor_dia, objetivo_complemento_30_dias
    from public.nomina_complementos_convencion_30
    where empleado_id = '43000000-0000-0000-0000-000000000208'
      and anio = 2025
    order by revision$$,
  $$values (
    1::bigint, date '2025-02-28', date '2025-02-27',
    3000::numeric, 100::numeric, 200::numeric
  )$$,
  'complemento mensual usa el ultimo dia elegible real como ancla'
);
select results_eq(
  $$select
      count(*)::integer,
      min(revision), max(revision),
      round(sum(objetivo_complemento_30_dias), 2)
    from public.nomina_complementos_convencion_30
    where empleado_id = '43000000-0000-0000-0000-000000000208'
      and anio = 2025$$,
  $$values (1, 1::bigint, 1::bigint, 200::numeric)$$,
  'retry conserva una sola fila historica y no duplica el complemento'
);
select is(
  (select round(
      coalesce(sum(objetivo_total), 0)
      + (
        select objetivo_complemento_30_dias
        from public.nomina_complementos_convencion_30
        where empleado_id = '43000000-0000-0000-0000-000000000208'
          and anio = 2025
      ),
      2
    )
   from public.nomina_resoluciones_diarias
   where empleado_id = '43000000-0000-0000-0000-000000000208'),
  2900::numeric,
  '27D diarios mas complemento 2D pagan 29D sin fecha ficticia'
);
select results_eq(
  $$select
      intento, estado, empleados_objetivo,
      resoluciones_nuevas, resoluciones_reutilizadas, errores,
      (detalle ->> 'complementos_convencion_30_errores')::integer
    from public.nomina_cierres_diarios
    where empresa_id = '43000000-0000-0000-0000-000000000001'
      and fecha_local = date '2025-02-28'
    order by intento$$,
  $$values
      (1::bigint, 'COMPLETADO'::text, 2, 2, 0, 0, 0),
      (2::bigint, 'COMPLETADO'::text, 2, 0, 2, 0, 0)$$,
  'suspension excluye objetivo diario y ambos cierres quedan completos'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000103', true
);
select is(
  private.complemento_convencion_30_vigente_0043(
    '43000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000208', 2025,
    date '2025-02-28', date '2025-02-27'
  ),
  true,
  'helper vigente confirma el complemento dentro del departamento'
);
select is(
  (select count(*)
   from public.nomina_complementos_convencion_30_vigentes
   where empleado_id = '43000000-0000-0000-0000-000000000208'),
  1::bigint,
  'RLS y vista vigente exponen una sola fila al supervisor autorizado'
);
select set_config('request.jwt.claim.sub', '', true);
select is(
  private.complemento_convencion_30_vigente_0043(
    '43000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000208', 2025,
    date '2025-02-28', date '2025-02-27'
  ),
  false,
  'helper mensual falla cerrado para authenticated sin JWT'
);
select is(
  (select count(*)
   from public.nomina_complementos_convencion_30_vigentes
   where empleado_id = '43000000-0000-0000-0000-000000000208'),
  0::bigint,
  'vista mensual sin JWT no expone ni sondea filas'
);
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000102', true
);
select is(
  private.complemento_convencion_30_vigente_0043(
    '43000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000208', 2025,
    date '2025-02-28', date '2025-02-27'
  ),
  false,
  'helper mensual no confirma una fila cross tenant'
);
select is(
  (select count(*)
   from public.nomina_complementos_convencion_30_vigentes
   where empleado_id = '43000000-0000-0000-0000-000000000208'),
  0::bigint,
  'RLS mantiene invisible el complemento al otro tenant'
);

select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000103', true
);
select lives_ok(
  $$select public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000202',
      date '2025-02-20', date '2025-02-28',
      'Suspension retroactiva elimina ancla febrero', null
    )$$,
  'suspension retroactiva cubre todo el tramo elegible del ingreso 20'
);
select is(
  private.complemento_convencion_30_vigente_0043(
    '43000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000202', 2025,
    date '2025-02-28', date '2025-02-28'
  ),
  false,
  'helper invalida el complemento cuyo tramo elegible quedo suspendido'
);
select is(
  (select count(*)
   from public.nomina_complementos_convencion_30_vigentes
   where empleado_id = '43000000-0000-0000-0000-000000000202'),
  0::bigint,
  'vista vigente oculta el complemento invalidado retroactivamente'
);
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000101', true
);
select lives_ok(
  $$select public.cerrar_nomina_dia_empresa(
      date '2025-02-28', 'Retry febrero sin ancla elegible'
    )$$,
  'cierre aisla el error mensual por empleado y conserva el intento'
);
reset role;
set local role postgres;

select results_eq(
  $$select
      intento, estado, empleados_objetivo,
      resoluciones_nuevas, resoluciones_reutilizadas, errores,
      (detalle ->> 'complementos_convencion_30_errores')::integer
    from public.nomina_cierres_diarios
    where empresa_id = '43000000-0000-0000-0000-000000000001'
      and fecha_local = date '2025-02-28'
      and intento = 3$$,
  $$values (
    3::bigint, 'CON_ERRORES'::text, 1, 0, 1, 0, 1
  )$$,
  'tercer cierre conserva contadores diarios y reporta un error mensual'
);
select ok(
  exists(
    select 1
    from public.nomina_cierres_diarios cierre
    cross join lateral jsonb_array_elements(
      cierre.detalle -> 'complementos_convencion_30'
    ) item
    where cierre.empresa_id = '43000000-0000-0000-0000-000000000001'
      and cierre.fecha_local = date '2025-02-28'
      and cierre.intento = 3
      and item ->> 'empleado_id' =
        '43000000-0000-0000-0000-000000000202'
      and item ->> 'sqlstate' = 'P4316'
      and item ->> 'error' = 'FEBRUARY_COMPLEMENT_ANCHOR_MISSING'
  ),
  'detalle identifica empleado y P4316 sin omitir silenciosamente el error'
);
select is(
  (select count(*)
   from public.nomina_complementos_convencion_30
   where empleado_id = '43000000-0000-0000-0000-000000000202'
     and anio = 2025),
  1::bigint,
  'fallo de reconciliacion conserva intacta la fila mensual historica'
);

select throws_ok(
  $$update public.nomina_complementos_convencion_30
    set motivo = 'Intento de alterar complemento mensual'
    where empleado_id = '43000000-0000-0000-0000-000000000208'
      and anio = 2025$$,
  'P4300', 'NOMINA_DAILY_HISTORY_IMMUTABLE',
  'historial mensual no admite UPDATE'
);
select throws_ok(
  $$delete from public.nomina_complementos_convencion_30
    where empleado_id = '43000000-0000-0000-0000-000000000208'
      and anio = 2025$$,
  'P4300', 'NOMINA_DAILY_HISTORY_IMMUTABLE',
  'historial mensual no admite DELETE'
);
select is(
  (select count(*)
   from public.nomina_complementos_convencion_30
   where empleado_id = '43000000-0000-0000-0000-000000000208'
     and anio = 2025),
  1::bigint,
  'rechazos de mutacion conservan intacta la unica revision mensual'
);
-- Manipulación manual de una raíz fuera de alcance también queda bloqueada.
insert into public.rol_permisos(rol_id, permiso_id, permitido, alcance)
select rol.id, permiso.id, true, 'empresa'
from public.roles rol
cross join public.permisos permiso
where rol.id in (
  '43000000-0000-0000-0000-000000000011',
  '43000000-0000-0000-0000-000000000012'
)
  and permiso.codigo = 'recursos_humanos.acceder'
on conflict(rol_id, permiso_id) do update set
  permitido = true,
  alcance = 'empresa';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000101', true
);
insert into suspension_ids_0043(clave, id)
select 'fuera_a', public.registrar_suspension_laboral_empleado(
  '43000000-0000-0000-0000-000000000204',
  date '2025-10-10', 'Fixture fuera de alcance A', null
);
insert into suspension_ids_0043(clave, id)
select 'resolucion_retro', public.registrar_suspension_laboral_empleado(
  '43000000-0000-0000-0000-000000000201',
  date '2025-01-02', date '2025-01-02',
  'Suspension retroactiva sobre resolucion', null
);
select ok(
  private.resolucion_cubierta_por_suspension_0043(
    '43000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000201', date '2025-01-02'
  ),
  'helper detecta una resolucion previa cubierta retroactivamente'
);
select is(
  jsonb_array_length(public.listar_resoluciones_nomina_diaria(
    '43000000-0000-0000-0000-000000000201',
    date '2025-01-02', date '2025-01-02', false
  )),
  0,
  'listado vigente oculta una resolucion cubierta por suspension retroactiva'
);
select is(
  jsonb_array_length(public.listar_resoluciones_nomina_diaria(
    '43000000-0000-0000-0000-000000000201',
    date '2025-01-02', date '2025-01-02', true
  )),
  1,
  'listado historico conserva la resolucion cubierta para auditoria'
);
select is(
  (select count(*) from public.nomina_resoluciones_diarias
   where empleado_id = '43000000-0000-0000-0000-000000000201'
     and fecha_local = date '2025-01-02'),
  1::bigint,
  'suspension retroactiva no borra la resolucion append-only'
);
select is(
  (select count(*) from public.nomina_resoluciones_diarias_vigentes
   where empleado_id = '43000000-0000-0000-0000-000000000201'
     and fecha_local = date '2025-01-02'),
  0::bigint,
  'vista vigente excluye la resolucion ahora cubierta'
);
select set_config('request.jwt.claim.sub', '', true);
select is(
  private.resolucion_cubierta_por_suspension_0043(
    '43000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000201', date '2025-01-02'
  ),
  false,
  'helper de vista falla cerrado para authenticated sin JWT'
);
select is(
  (select count(*) from public.nomina_resoluciones_diarias_vigentes
   where empleado_id = '43000000-0000-0000-0000-000000000201'
     and fecha_local = date '2025-01-02'),
  0::bigint,
  'vista sin JWT no expone ni sondea resoluciones'
);
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000102', true
);
select is(
  private.resolucion_cubierta_por_suspension_0043(
    '43000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000201', date '2025-01-02'
  ),
  false,
  'helper de vista no confirma cobertura de otro tenant'
);
select is(
  (select count(*) from public.nomina_resoluciones_diarias_vigentes
   where empleado_id = '43000000-0000-0000-0000-000000000201'
     and fecha_local = date '2025-01-02'),
  0::bigint,
  'RLS y helper mantienen invisible la resolucion cross tenant'
);
insert into suspension_ids_0043(clave, id)
select 'tenant_b', public.registrar_suspension_laboral_empleado(
  '43000000-0000-0000-0000-000000000203',
  date '2025-10-10', 'Fixture suspensión tenant B', null
);
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000103', true
);
select throws_ok(
  $$select public.finalizar_suspension_laboral_empleado(
      (select id from suspension_ids_0043 where clave = 'fuera_a'),
      date '2025-10-18', 'Manipulación fuera de alcance', null
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'supervisor no finaliza una raíz de otro departamento'
);
select throws_ok(
  $$select public.finalizar_suspension_laboral_empleado(
      (select id from suspension_ids_0043 where clave = 'tenant_b'),
      date '2025-10-18', 'Manipulación cross tenant', null
    )$$,
  '42501', 'ALCANCE_O_PERMISO_DENEGADO',
  'supervisor no finaliza una raíz de otro tenant'
);
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000101', true
);
insert into suspension_ids_0043(clave, id)
select 'fuera_a_fin', public.finalizar_suspension_laboral_empleado(
  (select id from suspension_ids_0043 where clave = 'fuera_a'),
  date '2025-10-18', 'Finalizar fixture fuera A', null
);
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000102', true
);
insert into suspension_ids_0043(clave, id)
select 'tenant_b_fin', public.finalizar_suspension_laboral_empleado(
  (select id from suspension_ids_0043 where clave = 'tenant_b'),
  date '2025-10-18', 'Finalizar fixture tenant B', null
);
reset role;
set local role postgres;

select throws_ok(
  $$update public.nomina_suspensiones_laborales
    set motivo = 'Intento de alterar historia'
    where id = (select id from suspension_ids_0043 where clave = 'ciclo_1')$$,
  'P4300', 'NOMINA_DAILY_HISTORY_IMMUTABLE',
  'historial de suspensión no admite UPDATE'
);
select throws_ok(
  $$delete from public.nomina_suspensiones_laborales
    where id = (select id from suspension_ids_0043 where clave = 'ciclo_1_fin')$$,
  'P4300', 'NOMINA_DAILY_HISTORY_IMMUTABLE',
  'historial de suspensión no admite DELETE'
);


-- El historial laboral canónico usa los únicos dos eventos de 0026.
create temporary table ciclo_ids_0043(
  clave text primary key,
  id bigint not null
) on commit drop;
insert into public.empleados(
  id, empresa_id, sucursal_id, departamento_id, codigo_empleado,
  nombre_completo, fecha_ingreso, estado_laboral, salario, tipo_pago, activo
) values (
  '43000000-0000-0000-0000-000000000205',
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000021',
  '43000000-0000-0000-0000-000000000031',
  '430007', 'Empleado suspendido A 0043', date '2025-04-01',
  'suspendido', 3000, 'mensual', false
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000101', true
);
select lives_ok(
  $$insert into suspension_ids_0043(clave, id)
    select 'suspendido_historia_cerrada',
      public.registrar_suspension_laboral_empleado(
        '43000000-0000-0000-0000-000000000205',
        date '2025-04-10', date '2025-04-18',
        'Historia cerrada antigua 0043', null
      )$$,
  'permite sembrar historia cerrada antigua para un suspendido actual'
);
reset role;
set local role postgres;
select results_eq(
  $$select count(distinct suspension_id)::integer, count(*)::integer
    from public.nomina_suspensiones_laborales
    where empleado_id = '43000000-0000-0000-0000-000000000205'$$,
  $$values (1, 2)$$,
  'fixture suspendido conserva dos revisiones cerradas append-only'
);
select throws_ok(
  $$select private.empleado_suspendido_en_fecha_nomina_0043(
      '43000000-0000-0000-0000-000000000001',
      '43000000-0000-0000-0000-000000000205', date '2025-05-01'
    )$$,
  'P4311', 'EMPLOYEE_SUSPENSION_HISTORY_REQUIRED',
  'estado suspendido con historia cerrada sin cobertura actual falla cerrado'
);
with evento as (
  insert into public.empleado_ciclo_laboral_auditoria(
    empresa_id, empleado_id, evento, fecha_efectiva, motivo,
    estado_anterior, estado_nuevo, activo_anterior, activo_nuevo,
    jornada_habilitada_anterior, jornada_habilitada_nueva
  ) values (
    '43000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000204',
    'EMPLOYEE_TERMINATED', date '2025-06-01', 'Baja ciclo uno 0043',
    'activo', 'desvinculado', true, false, true, false
  ) returning id
) insert into ciclo_ids_0043 select 'baja_1', id from evento;
with evento as (
  insert into public.empleado_ciclo_laboral_auditoria(
    empresa_id, empleado_id, evento, fecha_efectiva, motivo,
    estado_anterior, estado_nuevo, activo_anterior, activo_nuevo,
    jornada_habilitada_anterior, jornada_habilitada_nueva,
    evento_relacionado_id
  )
  select
    '43000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000204',
    'EMPLOYEE_REACTIVATED', date '2025-07-01',
    'Reactivación ciclo uno 0043', 'desvinculado', 'activo',
    false, true, false, true, ciclo.id
  from ciclo_ids_0043 ciclo where ciclo.clave = 'baja_1'
  returning id
) insert into ciclo_ids_0043 select 'reactivacion_1', id from evento;
with evento as (
  insert into public.empleado_ciclo_laboral_auditoria(
    empresa_id, empleado_id, evento, fecha_efectiva, motivo,
    estado_anterior, estado_nuevo, activo_anterior, activo_nuevo,
    jornada_habilitada_anterior, jornada_habilitada_nueva
  ) values (
    '43000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000204',
    'EMPLOYEE_TERMINATED', date '2025-08-01', 'Baja ciclo dos 0043',
    'activo', 'desvinculado', true, false, true, false
  ) returning id
) insert into ciclo_ids_0043 select 'baja_2', id from evento;
with evento as (
  insert into public.empleado_ciclo_laboral_auditoria(
    empresa_id, empleado_id, evento, fecha_efectiva, motivo,
    estado_anterior, estado_nuevo, activo_anterior, activo_nuevo,
    jornada_habilitada_anterior, jornada_habilitada_nueva,
    evento_relacionado_id
  )
  select
    '43000000-0000-0000-0000-000000000001',
    '43000000-0000-0000-0000-000000000204',
    'EMPLOYEE_REACTIVATED', date '2025-09-01',
    'Reactivación ciclo dos 0043', 'desvinculado', 'activo',
    false, true, false, true, ciclo.id
  from ciclo_ids_0043 ciclo where ciclo.clave = 'baja_2'
  returning id
) insert into ciclo_ids_0043 select 'reactivacion_2', id from evento;

select results_eq(
  $$with casos(caso, empleado_id, fecha) as (
      values
        ('antes_ingreso',
          '43000000-0000-0000-0000-000000000204'::uuid,
          date '2025-03-31'),
        ('sin_eventos_posteriores',
          '43000000-0000-0000-0000-000000000201'::uuid,
          date '2025-05-01'),
        ('ingreso_sin_evento',
          '43000000-0000-0000-0000-000000000204'::uuid,
          date '2025-04-01'),
        ('baja_inclusiva',
          '43000000-0000-0000-0000-000000000204'::uuid,
          date '2025-06-01'),
        ('baja_vigente',
          '43000000-0000-0000-0000-000000000204'::uuid,
          date '2025-06-30'),
        ('reactivacion_inclusiva',
          '43000000-0000-0000-0000-000000000204'::uuid,
          date '2025-07-01'),
        ('segunda_baja',
          '43000000-0000-0000-0000-000000000204'::uuid,
          date '2025-08-01'),
        ('segunda_reactivacion',
          '43000000-0000-0000-0000-000000000204'::uuid,
          date '2025-09-01')
    )
    select caso,
      private.empleado_vigente_en_fecha_nomina_0043(
        case when empleado_id =
          '43000000-0000-0000-0000-000000000203'::uuid
          then '43000000-0000-0000-0000-000000000002'::uuid
          else '43000000-0000-0000-0000-000000000001'::uuid
        end,
        empleado_id, fecha
      )
    from casos order by caso$$,
  $$values
      ('antes_ingreso'::text, false),
      ('baja_inclusiva'::text, false),
      ('baja_vigente'::text, false),
      ('ingreso_sin_evento'::text, true),
      ('reactivacion_inclusiva'::text, true),
      ('segunda_baja'::text, false),
      ('segunda_reactivacion'::text, true),
      ('sin_eventos_posteriores'::text, true)$$,
  'vigencia laboral usa activo_nuevo del último evento efectivo y múltiples ciclos'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub',
  '43000000-0000-0000-0000-000000000101', true
);
select throws_ok(
  $$select public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000204',
      date '2025-05-20', date '2025-06-10',
      'Intento cerrado que cruza baja', null
    )$$,
  'P4306', 'EMPLOYEE_NOT_ACTIVE_ON_DATE',
  'rango cerrado que cruza una baja laboral se rechaza'
);
select throws_ok(
  $$select public.registrar_suspension_laboral_empleado(
      '43000000-0000-0000-0000-000000000204',
      date '2025-05-20', 'Intento abierto que cruza baja', null
    )$$,
  'P4306', 'EMPLOYEE_NOT_ACTIVE_ON_DATE',
  'rango abierto con una baja posterior se rechaza'
);
reset role;
set local role postgres;
select is(
  (select count(*) from public.nomina_suspensiones_laborales
   where empleado_id = '43000000-0000-0000-0000-000000000204'
     and fecha_desde = date '2025-05-20'),
  0::bigint,
  'rechazos por ciclo laboral no dejan historia parcial'
);

insert into public.empleado_ciclo_laboral_auditoria(
  empresa_id, empleado_id, evento, fecha_efectiva, motivo,
  estado_anterior, estado_nuevo, activo_anterior, activo_nuevo,
  jornada_habilitada_anterior, jornada_habilitada_nueva
) values (
  '43000000-0000-0000-0000-000000000001',
  '43000000-0000-0000-0000-000000000204',
  'EMPLOYEE_TERMINATED', date '2025-07-15',
  'Baja retroactiva inválida 0043',
  'activo', 'desvinculado', true, false, true, false
);
select throws_ok(
  $$select private.empleado_vigente_en_fecha_nomina_0043(
      '43000000-0000-0000-0000-000000000001',
      '43000000-0000-0000-0000-000000000204', date '2025-09-15'
    )$$,
  'P4310', 'EMPLOYEE_LIFECYCLE_HISTORY_INVALID',
  'un historial retroactivo no monotónico falla cerrado'
);

select is(
  (select count(*) from public.nomina_movimientos_tiempo_real),
  (select cantidad from ledger_count_0043),
  'también después de tenant y cierre, 0043 mantiene intacto el ledger 0038'
);

select * from finish();
rollback;
