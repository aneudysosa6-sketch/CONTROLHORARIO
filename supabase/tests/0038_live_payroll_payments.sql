begin;

set local search_path = extensions, public, pg_catalog;
set local role postgres;

create extension if not exists pgtap;
select * from no_plan();

-- Contrato estructural y de seguridad de 0038.
select has_table(
  'public', 'nomina_pagos_tiempo_real',
  'existe el ledger inmutable de pagos en tiempo real'
);
select has_table(
  'public', 'nomina_pago_jornadas',
  'existe la relacion que consume cada jornada una sola vez'
);
select has_table(
  'public', 'nomina_movimientos_tiempo_real',
  'existe el ledger inmutable de movimientos devengados'
);
select has_table(
  'public', 'nomina_pago_movimientos',
  'existe la relacion que consume cada movimiento una sola vez'
);
select has_table(
  'public', 'nomina_pago_cortes_legacy',
  'existe el corte inmutable que evita volver a ofrecer pagos legacy'
);
select has_column(
  'public', 'nomina_pagos_tiempo_real', 'source_fingerprint',
  'el header conserva el fingerprint confirmado por el usuario'
);

select has_function(
  'public', 'obtener_resumen_pagos_tiempo_real', array['date', 'date']
);
select function_returns(
  'public', 'obtener_resumen_pagos_tiempo_real', array['date', 'date'],
  'jsonb'
);
select has_function(
  'public', 'listar_pagos_pendientes', array['date', 'date']
);
select function_returns(
  'public', 'listar_pagos_pendientes', array['date', 'date'], 'jsonb'
);
select has_function(
  'public', 'registrar_pago_empleado',
  array['uuid', 'date', 'date', 'text', 'uuid', 'text']
);
select hasnt_function(
  'public', 'registrar_pago_empleado',
  array['uuid', 'date', 'date', 'text', 'uuid']
);
select function_returns(
  'public', 'registrar_pago_empleado',
  array['uuid', 'date', 'date', 'text', 'uuid', 'text'], 'jsonb'
);
select has_function(
  'public', 'listar_historial_pagos', array['date', 'date']
);
select function_returns(
  'public', 'listar_historial_pagos', array['date', 'date'], 'jsonb'
);

select ok(
  (
    select pg_catalog.bool_and(p.prosecdef)
    from pg_catalog.pg_proc p
    where p.oid = any(array[
      'public.obtener_resumen_pagos_tiempo_real(date,date)'::regprocedure,
      'public.listar_pagos_pendientes(date,date)'::regprocedure,
      'public.registrar_pago_empleado(uuid,date,date,text,uuid,text)'::regprocedure,
      'public.listar_historial_pagos(date,date)'::regprocedure
    ])
  ),
  'las cuatro RPC son SECURITY DEFINER'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc p
    where p.oid = any(array[
      'public.obtener_resumen_pagos_tiempo_real(date,date)'::regprocedure,
      'public.listar_pagos_pendientes(date,date)'::regprocedure,
      'public.registrar_pago_empleado(uuid,date,date,text,uuid,text)'::regprocedure,
      'public.listar_historial_pagos(date,date)'::regprocedure
    ])
      and coalesce(pg_catalog.array_to_string(p.proconfig, ','), '')
        not like '%search_path=%'
  ),
  'las cuatro RPC fijan search_path'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc p
    where p.oid = any(array[
      'public.obtener_resumen_pagos_tiempo_real(date,date)'::regprocedure,
      'public.listar_pagos_pendientes(date,date)'::regprocedure,
      'public.registrar_pago_empleado(uuid,date,date,text,uuid,text)'::regprocedure,
      'public.listar_historial_pagos(date,date)'::regprocedure
    ])
      and (
        -- A NULL proacl uses PostgreSQL's function default, which grants
        -- EXECUTE to PUBLIC. An explicit ACL must therefore exist and must
        -- not contain grantee 0 (PUBLIC) with EXECUTE.
        p.proacl is null
        or exists (
          select 1
          from pg_catalog.aclexplode(p.proacl) acl
          where acl.grantee = 0::oid
            and acl.privilege_type = 'EXECUTE'
        )
      )
  ),
  'PUBLIC no puede ejecutar las RPC de pagos'
);
select ok(
  not exists (
    select 1
    from pg_catalog.pg_proc p
    where p.oid = any(array[
      'public.obtener_resumen_pagos_tiempo_real(date,date)'::regprocedure,
      'public.listar_pagos_pendientes(date,date)'::regprocedure,
      'public.registrar_pago_empleado(uuid,date,date,text,uuid,text)'::regprocedure,
      'public.listar_historial_pagos(date,date)'::regprocedure
    ])
      and pg_catalog.has_function_privilege('anon', p.oid, 'EXECUTE')
  ),
  'anon no puede ejecutar las RPC de pagos'
);
select ok(
  (
    select pg_catalog.bool_and(
      pg_catalog.has_function_privilege('authenticated', p.oid, 'EXECUTE')
    )
    from pg_catalog.pg_proc p
    where p.oid = any(array[
      'public.obtener_resumen_pagos_tiempo_real(date,date)'::regprocedure,
      'public.listar_pagos_pendientes(date,date)'::regprocedure,
      'public.registrar_pago_empleado(uuid,date,date,text,uuid,text)'::regprocedure,
      'public.listar_historial_pagos(date,date)'::regprocedure
    ])
  ),
  'authenticated ejecuta las RPC y no necesita DML directo'
);

select ok(
  (
    select pg_catalog.bool_and(c.relrowsecurity)
    from pg_catalog.pg_class c
    where c.oid = any(array[
      'public.nomina_pagos_tiempo_real'::regclass,
      'public.nomina_pago_jornadas'::regclass,
      'public.nomina_movimientos_tiempo_real'::regclass,
      'public.nomina_pago_movimientos'::regclass,
      'public.nomina_pago_cortes_legacy'::regclass
    ])
  ),
  'RLS esta activo en las cinco tablas nuevas'
);
select ok(
  not (
    pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pagos_tiempo_real', 'INSERT'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pagos_tiempo_real', 'UPDATE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pagos_tiempo_real', 'DELETE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pagos_tiempo_real', 'TRUNCATE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_jornadas', 'INSERT'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_jornadas', 'UPDATE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_jornadas', 'DELETE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_jornadas', 'TRUNCATE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_movimientos_tiempo_real', 'INSERT'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_movimientos_tiempo_real', 'UPDATE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_movimientos_tiempo_real', 'DELETE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_movimientos_tiempo_real', 'TRUNCATE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_movimientos', 'INSERT'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_movimientos', 'UPDATE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_movimientos', 'DELETE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_movimientos', 'TRUNCATE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_cortes_legacy', 'INSERT'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_cortes_legacy', 'UPDATE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_cortes_legacy', 'DELETE'
    )
    or pg_catalog.has_table_privilege(
      'authenticated', 'public.nomina_pago_cortes_legacy', 'TRUNCATE'
    )
  ),
  'authenticated no recibe DML directo sobre el ledger'
);
select is(
  (
    select count(*)::integer
    from public.permisos p
    where p.codigo = 'nomina.pagar'
      and p.activo
  ),
  1,
  'nomina.pagar existe una sola vez y esta activo'
);
select is(
  (
    select count(*)::integer
    from public.roles r
    where r.is_active
      and private.normalizar_codigo_rol(r.code) in ('ADMIN', 'NOMINA')
      and not exists (
        select 1
        from public.rol_permisos rp
        join public.permisos p on p.id = rp.permiso_id
        where rp.rol_id = r.id
          and p.codigo = 'nomina.pagar'
          and p.activo
          and rp.permitido
          and rp.alcance = 'empresa'
      )
  ),
  0,
  'todo ADMIN o NOMINA canonico activo recibe nomina.pagar a nivel empresa'
);
select col_is_unique(
  'public', 'nomina_pagos_tiempo_real',
  array['empresa_id', 'idempotency_key'],
  'la idempotencia queda aislada por empresa'
);
select col_is_unique(
  'public', 'nomina_pago_jornadas',
  array['empresa_id', 'jornada_id'],
  'una jornada no puede pagarse dos veces'
);
select col_is_unique(
  'public', 'nomina_movimientos_tiempo_real',
  array['empresa_id', 'source_type', 'source_key'],
  'un evento fuente solo puede devengarse una vez dentro de la empresa'
);
select col_is_unique(
  'public', 'nomina_pago_movimientos',
  array['empresa_id', 'movimiento_id'],
  'un movimiento solo puede consumirse por un pago'
);
select ok(
  (
    select pg_catalog.count(*) = 5
    from pg_catalog.pg_trigger t
    where t.tgrelid = any(array[
      'public.nomina_pagos_tiempo_real'::regclass,
      'public.nomina_pago_jornadas'::regclass,
      'public.nomina_movimientos_tiempo_real'::regclass,
      'public.nomina_pago_movimientos'::regclass,
      'public.nomina_pago_cortes_legacy'::regclass
    ])
      and not t.tgisinternal
      and pg_catalog.lower(pg_catalog.pg_get_triggerdef(t.oid)) like '%update%'
      and pg_catalog.lower(pg_catalog.pg_get_triggerdef(t.oid)) like '%delete%'
      and pg_catalog.lower(pg_catalog.pg_get_triggerdef(t.oid)) like '%truncate%'
  ),
  'las cinco tablas del ledger bloquean UPDATE, DELETE y TRUNCATE'
);
select ok(
  position(
    '''nomina.pagar''' in pg_catalog.pg_get_functiondef(
      'public.registrar_pago_empleado(uuid,date,date,text,uuid,text)'::regprocedure
    )
  ) > 0,
  'registrar pago exige exactamente nomina.pagar'
);
select ok(
  (
    select pg_catalog.bool_and(
      position(
        '''nomina.ver''' in pg_catalog.pg_get_functiondef(p.oid)
      ) > 0
    )
    from pg_catalog.pg_proc p
    where p.oid = any(array[
      'public.obtener_resumen_pagos_tiempo_real(date,date)'::regprocedure,
      'public.listar_pagos_pendientes(date,date)'::regprocedure,
      'public.listar_historial_pagos(date,date)'::regprocedure
    ])
  ),
  'las tres lecturas exigen exactamente nomina.ver'
);
select is(
  (
    select count(*)::integer
    from pg_catalog.pg_proc p
    where p.oid = any(array[
      'public.obtener_resumen_pagos_tiempo_real(date,date)'::regprocedure,
      'public.listar_pagos_pendientes(date,date)'::regprocedure,
      'public.listar_historial_pagos(date,date)'::regprocedure
    ])
      and p.provolatile = 's'
  ),
  3,
  'las tres lecturas son STABLE y no materializan devengos'
);

-- Fixtures sinteticos y reversibles. B tiene una jornada desde el inicio para
-- probar que A no recibe filas cruzadas cuando aun no tiene tiempo devengado.
insert into auth.users(
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values
  ('38000000-0000-0000-0000-000000000001', 'authenticated',
   'authenticated', 'admin-a-38@test.invalid', 'not-used', now(), '{}', '{}',
   now(), now()),
  ('38000000-0000-0000-0000-000000000002', 'authenticated',
   'authenticated', 'reader-a-38@test.invalid', 'not-used', now(), '{}', '{}',
   now(), now()),
  ('38000000-0000-0000-0000-000000000003', 'authenticated',
   'authenticated', 'admin-b-38@test.invalid', 'not-used', now(), '{}', '{}',
   now(), now());

insert into public.companies(id, name, slug) values
  ('38000000-0000-0000-0000-000000000010', 'Empresa A Test 0038',
   'empresa-a-test-0038'),
  ('38000000-0000-0000-0000-000000000110', 'Empresa B Test 0038',
   'empresa-b-test-0038');

insert into public.roles(id, company_id, name, code) values
  ('38000000-0000-0000-0000-000000000011',
    '38000000-0000-0000-0000-000000000010', 'Admin A 0038', 'admin'),
  ('38000000-0000-0000-0000-000000000012',
    '38000000-0000-0000-0000-000000000010', 'Lector A 0038', 'auditor'),
  ('38000000-0000-0000-0000-000000000111',
    '38000000-0000-0000-0000-000000000110', 'Admin B 0038', 'admin');

insert into public.profiles(
  id, company_id, role_id, full_name, status
) values
  ('38000000-0000-0000-0000-000000000001',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000011', 'Admin A 0038', 'active'),
  ('38000000-0000-0000-0000-000000000002',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000012', 'Lector A 0038', 'active'),
  ('38000000-0000-0000-0000-000000000003',
   '38000000-0000-0000-0000-000000000110',
   '38000000-0000-0000-0000-000000000111', 'Admin B 0038', 'active');

insert into public.employee_code_sequences(empresa_id, last_value) values
  ('38000000-0000-0000-0000-000000000010', 380020),
  ('38000000-0000-0000-0000-000000000110', 380120)
on conflict(empresa_id) do update set last_value = excluded.last_value;

insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values
  ('38000000-0000-0000-0000-000000000021',
   '38000000-0000-0000-0000-000000000010', '380021',
   'Empleado A 0038', date '2030-01-01', 'activo', 2400, 'quincenal', true),
  ('38000000-0000-0000-0000-000000000121',
   '38000000-0000-0000-0000-000000000110', '380121',
   'Empleado B 0038', date '2030-01-01', 'activo', 2400, 'quincenal', true);

insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values
  ('38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000021', 30, 8,
   'PORCENTAJE', 5, 'PORCENTAJE', 2.5, 'MONTO', 0, 10, 20,
   2, true, 0, true),
  ('38000000-0000-0000-0000-000000000110',
   '38000000-0000-0000-0000-000000000121', 30, 8,
   'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 0, 20, 0, false, 0, true);

insert into public.nomina_prestamos(
  id, empresa_id, empleado_id, monto_total, total_pagado, pendiente,
  descuento_periodo, estado, fecha_inicio, motivo, creado_por
) values (
  '38000000-0000-0000-0000-000000000041',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000021',
  100, 0, 100, 3, 'ENTREGADO', date '2037-12-01',
  'Prestamo sintetico 0038',
  '38000000-0000-0000-0000-000000000001'
);

insert into public.nomina_creditos(
  id, empresa_id, empleado_id, monto_total, total_descontado, pendiente,
  descuento_periodo, estado, fecha_inicio, motivo, creado_por
) values (
  '38000000-0000-0000-0000-000000000042',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000021',
  100, 0, 100, 4, 'ACTIVO', date '2037-12-01',
  'Credito sintetico 0038',
  '38000000-0000-0000-0000-000000000001'
);

insert into public.rol_permisos(rol_id, permiso_id, permitido, alcance)
select r.id, p.id, true, 'empresa'
from public.roles r
join public.permisos p on p.codigo in (
  'nomina.ver', 'nomina.pagar', 'nomina.generar', 'nomina.editar'
)
where r.id in (
  '38000000-0000-0000-0000-000000000011',
  '38000000-0000-0000-0000-000000000111'
)
on conflict(rol_id, permiso_id)
do update set permitido = true, alcance = 'empresa';

insert into public.rol_permisos(rol_id, permiso_id, permitido, alcance)
select '38000000-0000-0000-0000-000000000012'::uuid, p.id, true, 'empresa'
from public.permisos p
where p.codigo = 'nomina.ver'
on conflict(rol_id, permiso_id)
do update set permitido = true, alcance = 'empresa';

insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values
(
  '38000000-0000-0000-0000-000000000030',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000021',
  date '2038-01-02', 'FINALIZADA',
  timestamptz '2038-01-02 08:00:00+00',
  timestamptz '2038-01-02 08:00:00+00',
  0, 0, 'WEB', false
),
(
  '38000000-0000-0000-0000-000000000131',
  '38000000-0000-0000-0000-000000000110',
  '38000000-0000-0000-0000-000000000121',
  date '2038-01-05', 'FINALIZADA',
  timestamptz '2038-01-05 08:00:00+00',
  timestamptz '2038-01-05 16:00:00+00',
  480, 0, 'WEB', false
);

-- El trigger de devengo es diferible en produccion. En esta transaccion pgTAP
-- se fuerza a IMMEDIATE para observar cada evento antes de la siguiente asercion.
set constraints nomina_devengar_jornada_finalizada immediate;
set constraints nomina_reconciliar_jornada_conflicto immediate;

-- A. Una jornada FINALIZADA sin minutos trabajados no crea un pendiente.
select is(
  (
    select count(*)::integer
    from public.jornadas j
    where j.id = '38000000-0000-0000-0000-000000000030'
      and j.estado = 'FINALIZADA'
      and j.minutos_trabajados = 0
  ),
  1,
  'A: el fixture contiene una jornada FINALIZADA de cero minutos'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.jornada_id = '38000000-0000-0000-0000-000000000030'
  ),
  0,
  'A: cero minutos no materializa movimientos'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  pg_catalog.jsonb_typeof(
    public.listar_pagos_pendientes(date '2038-01-01', date '2038-01-15')
  ),
  'array',
  'A: listar pagos pendientes devuelve un array'
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2038-01-01', date '2038-01-15')
  ),
  0,
  'A: cero jornadas produce cero empleados pendientes'
);
select is(
  (
    public.obtener_resumen_pagos_tiempo_real(
      date '2038-01-01', date '2038-01-15'
    ) ->> 'pendiente_a_pagar'
  )::numeric,
  0::numeric,
  'A: el resumen no inventa saldo sin jornadas'
);
reset role;
set local role postgres;

-- B. Una jornada finalizada genera exactamente un pendiente.
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000031',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000021',
  date '2038-01-10', 'FINALIZADA',
  timestamptz '2038-01-10 08:00:00+00',
  timestamptz '2038-01-10 18:00:00+00',
  600, 0, 'WEB', false
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2038-01-01', date '2038-01-15')
  ),
  1,
  'B: la jornada ganada crea un solo pendiente'
);
select is(
  public.listar_pagos_pendientes(
    date '2038-01-01', date '2038-01-15'
  ) -> 0 ->> 'employee_id',
  '38000000-0000-0000-0000-000000000021',
  'B: el pendiente pertenece al empleado correcto'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'journeys'
  )::integer,
  1,
  'B: el pendiente informa una jornada'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  111.25::numeric,
  'B: la jornada genera 130 brutos y 111.25 netos tras deducciones'
);
select is(
  (
    public.obtener_resumen_pagos_tiempo_real(
      date '2038-01-01', date '2038-01-15'
    ) ->> 'empleados_pendientes'
  )::integer,
  1,
  'B: el resumen cuenta un empleado pendiente'
);
reset role;
set local role postgres;

-- H. La vista de pago reutiliza sin divergencias el motor V3 vigente.
select ok(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'overtime_pay'
  )::numeric > 0
  and (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'afp'
  )::numeric > 0
  and (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'sfs'
  )::numeric > 0
  and (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'loan_discount'
  )::numeric > 0
  and (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'credit_discount'
  )::numeric > 0
  and (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'other_discounts'
  )::numeric > 0,
  'H: el fixture ejerce overtime, AFP, SFS, fijo, prestamo y credito'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'gross'
  )::numeric,
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000021',
      date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
    ) ->> 'gross'
  )::numeric,
  'H: bruto coincide con nomina_calculo_empleado_v3'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'overtime_pay'
  )::numeric,
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000021',
      date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
    ) ->> 'overtime_pay'
  )::numeric,
  'H: horas extra coinciden con el motor V3'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'afp'
  )::numeric,
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000021',
      date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
    ) #>> '{deductions,afp,applied}'
  )::numeric,
  'H: AFP coincide con el motor V3'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'sfs'
  )::numeric,
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000021',
      date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
    ) #>> '{deductions,sfs,applied}'
  )::numeric,
  'H: SFS coincide con el motor V3'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'loan_discount'
  )::numeric,
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000021',
      date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
    ) #>> '{deductions,loans,applied}'
  )::numeric,
  'H: descuento de prestamo coincide con el motor V3'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'credit_discount'
  )::numeric,
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000021',
      date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
    ) #>> '{deductions,credits,applied}'
  )::numeric,
  'H: descuento de credito coincide con el motor V3'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'other_discounts'
  )::numeric,
  (
    coalesce((public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000021',
      date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
    ) #>> '{deductions,other_taxes,applied}')::numeric, 0)
    + coalesce((public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000021',
      date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
    ) #>> '{deductions,breakage,applied}')::numeric, 0)
    + coalesce((public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000021',
      date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
    ) #>> '{deductions,other_discounts,applied}')::numeric, 0)
  ),
  'H: descuento fijo agregado coincide con el motor V3'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000021',
      date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
    ) ->> 'net'
  )::numeric,
  'H: total pendiente coincide con el neto autoritativo'
);
select is(
  public.listar_pagos_pendientes(
    date '2038-01-01', date '2038-01-15'
  ) -> 0 ->> 'formula',
  public.nomina_calculo_empleado_v3(
    '38000000-0000-0000-0000-000000000010',
    '38000000-0000-0000-0000-000000000021',
    date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
  ) ->> 'formula',
  'H: formula conserva el identificador autoritativo'
);
select ok(
  exists (
    select 1
    from pg_catalog.jsonb_array_elements(
      public.listar_pagos_pendientes(
        date '2038-01-01', date '2038-01-15'
      ) -> 0 -> 'deduction_items'
    ) item(value)
    where item.value ->> 'type' = 'AFP'
      and (item.value ->> 'applied')::numeric > 0
  )
  and exists (
    select 1
    from pg_catalog.jsonb_array_elements(
      public.listar_pagos_pendientes(
        date '2038-01-01', date '2038-01-15'
      ) -> 0 -> 'deduction_items'
    ) item(value)
    where item.value ->> 'type' = 'SFS'
      and (item.value ->> 'applied')::numeric > 0
  )
  and exists (
    select 1
    from pg_catalog.jsonb_array_elements(
      public.listar_pagos_pendientes(
        date '2038-01-01', date '2038-01-15'
      ) -> 0 -> 'deduction_items'
    ) item(value)
    where item.value ->> 'concept' = 'FIXED'
      and (item.value ->> 'applied')::numeric > 0
  )
  and exists (
    select 1
    from pg_catalog.jsonb_array_elements(
      public.listar_pagos_pendientes(
        date '2038-01-01', date '2038-01-15'
      ) -> 0 -> 'deduction_items'
    ) item(value)
    where item.value ->> 'source_kind' = 'LOAN'
      and (item.value ->> 'applied')::numeric > 0
  )
  and exists (
    select 1
    from pg_catalog.jsonb_array_elements(
      public.listar_pagos_pendientes(
        date '2038-01-01', date '2038-01-15'
      ) -> 0 -> 'deduction_items'
    ) item(value)
    where item.value ->> 'source_kind' = 'CREDIT'
      and (item.value ->> 'applied')::numeric > 0
  ),
  'H: deduction_items conserva las cinco deducciones no triviales'
);
select is(
  (
    select pg_catalog.jsonb_object_agg(
      grouped.item_key, grouped.applied order by grouped.item_key
    )
    from (
      select
        concat(item.value ->> 'type', ':', item.value ->> 'concept') item_key,
        round(sum((item.value ->> 'applied')::numeric), 2) applied
      from pg_catalog.jsonb_array_elements(
        public.listar_pagos_pendientes(
          date '2038-01-01', date '2038-01-15'
        ) -> 0 -> 'deduction_items'
      ) item(value)
      where coalesce((item.value ->> 'applied')::numeric, 0) <> 0
      group by item.value ->> 'type', item.value ->> 'concept'
    ) grouped
  ),
  (
    select pg_catalog.jsonb_object_agg(
      grouped.item_key, grouped.applied order by grouped.item_key
    )
    from (
      select
        concat(item.value ->> 'type', ':', item.value ->> 'concept') item_key,
        round(sum((item.value ->> 'applied')::numeric), 2) applied
      from pg_catalog.jsonb_array_elements(
        public.nomina_calculo_empleado_v3(
          '38000000-0000-0000-0000-000000000010',
          '38000000-0000-0000-0000-000000000021',
          date '2038-01-01', date '2038-01-15', 'QUINCENAL', null
        ) -> 'deduction_items'
      ) item(value)
      where coalesce((item.value ->> 'applied')::numeric, 0) <> 0
      group by item.value ->> 'type', item.value ->> 'concept'
    ) grouped
  ),
  'H: deducciones efectivas agregadas por concepto coinciden con V3'
);

-- El mismo evento y los filtros solapados no crean fuentes nuevas. Incentivo,
-- descuento fijo y cuotas se identifican por fuente/ciclo, nunca por rango UI.
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.ciclo_desde = date '2038-01-01'
      and movement.ciclo_hasta = date '2038-01-15'
      and movement.source_type = 'CYCLE_INCENTIVE'
  ),
  1,
  'ledger: incentivo fijo existe una sola vez en el ciclo'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.ciclo_desde = date '2038-01-01'
      and movement.ciclo_hasta = date '2038-01-15'
      and movement.source_type = 'CYCLE_FIXED_OBLIGATION'
      and movement.concepto = 'FIXED'
  ),
  1,
  'ledger: descuento fijo existe una sola vez en el ciclo'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.ciclo_desde = date '2038-01-01'
      and movement.ciclo_hasta = date '2038-01-15'
      and movement.source_type = 'LOAN_INSTALLMENT_OBLIGATION'
      and movement.prestamo_id = '38000000-0000-0000-0000-000000000041'
  ),
  1,
  'ledger: cuota de prestamo existe una sola vez en el ciclo'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.ciclo_desde = date '2038-01-01'
      and movement.ciclo_hasta = date '2038-01-15'
      and movement.source_type = 'LOAN_INSTALLMENT_APPLICATION'
      and movement.prestamo_id = '38000000-0000-0000-0000-000000000041'
  ),
  1,
  'ledger: la cuota de prestamo tiene una sola aplicacion por devengo'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.ciclo_desde = date '2038-01-01'
      and movement.ciclo_hasta = date '2038-01-15'
      and movement.source_type = 'CREDIT_INSTALLMENT_OBLIGATION'
      and movement.credito_id = '38000000-0000-0000-0000-000000000042'
  ),
  1,
  'ledger: cuota de credito existe una sola vez en el ciclo'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.ciclo_desde = date '2038-01-01'
      and movement.ciclo_hasta = date '2038-01-15'
      and movement.source_type = 'CREDIT_INSTALLMENT_APPLICATION'
      and movement.credito_id = '38000000-0000-0000-0000-000000000042'
  ),
  1,
  'ledger: la cuota de credito tiene una sola aplicacion por devengo'
);
create temporary table test_0038_accrual_replay_snapshot as
select
  count(*)::integer as movement_count,
  pg_catalog.array_agg(movement.id order by movement.id)::text as movement_ids,
  pg_catalog.array_agg(
    concat(movement.source_type, '|', movement.source_key)
    order by movement.source_type, movement.source_key
  )::text as source_keys
from public.nomina_movimientos_tiempo_real movement
where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
  and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
  and movement.ciclo_desde = date '2038-01-01'
  and movement.ciclo_hasta = date '2038-01-15';

select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000031'
    ) ->> 'inserted'
  )::integer,
  0,
  'ledger: repetir el devengo del evento es idempotente'
);
select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000031'
    ) ->> 'inserted'
  )::integer,
  0,
  'ledger: un segundo replay tampoco crea movimientos'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.ciclo_desde = date '2038-01-01'
      and movement.ciclo_hasta = date '2038-01-15'
  ),
  (select movement_count from test_0038_accrual_replay_snapshot),
  'ledger: replay conserva el conteo fisico de movimientos'
);
select is(
  (
    select pg_catalog.array_agg(movement.id order by movement.id)::text
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.ciclo_desde = date '2038-01-01'
      and movement.ciclo_hasta = date '2038-01-15'
  ),
  (select movement_ids from test_0038_accrual_replay_snapshot),
  'ledger: replay conserva exactamente los mismos IDs'
);
select is(
  (
    select pg_catalog.array_agg(
      concat(movement.source_type, '|', movement.source_key)
      order by movement.source_type, movement.source_key
    )::text
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.ciclo_desde = date '2038-01-01'
      and movement.ciclo_hasta = date '2038-01-15'
  ),
  (select source_keys from test_0038_accrual_replay_snapshot),
  'ledger: replay conserva exactamente las mismas identidades fuente'
);


create temporary table test_0038_read_snapshot as
select
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
  ) as movement_count,
  (
    select pg_catalog.array_agg(movement.id order by movement.id)::text
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
  ) as movement_ids,
  (select count(*)::integer from public.nomina_pagos_tiempo_real) as payment_count,
  (select count(*)::integer from public.nomina_pago_cortes_legacy) as cut_count,
  (select count(*)::integer from public.nomina_pago_movimientos) as link_count,
  (
    select loan.pendiente
    from public.nomina_prestamos loan
    where loan.id = '38000000-0000-0000-0000-000000000041'
  ) as loan_balance,
  (
    select credit.pendiente
    from public.nomina_creditos credit
    where credit.id = '38000000-0000-0000-0000-000000000042'
  ) as credit_balance;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-01', date '2038-01-15'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  111.25::numeric,
  'ledger: consulta 01-15 proyecta el saldo exacto'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-05', date '2038-01-20'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  111.25::numeric,
  'ledger: consulta solapada 05-20 no duplica el saldo'
);
select is(
  public.listar_pagos_pendientes(
    date '2038-01-01', date '2038-01-15'
  ) -> 0 ->> 'source_fingerprint',
  public.listar_pagos_pendientes(
    date '2038-01-05', date '2038-01-20'
  ) -> 0 ->> 'source_fingerprint',
  'ledger: rangos solapados conservan el mismo conjunto concreto de fuentes'
);
select lives_ok(
  $$select public.obtener_resumen_pagos_tiempo_real(
    date '2038-01-05', date '2038-01-20'
  )$$,
  'ledger: resumen solapado es SELECT-only'
);
select lives_ok(
  $$select public.listar_historial_pagos(current_date, current_date)$$,
  'ledger: historial es SELECT-only'
);
reset role;
set local role postgres;

select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
  ),
  (select movement_count from test_0038_read_snapshot),
  'ledger: rangos SELECT-only no materializan movimientos'
);
select is(
  (
    select pg_catalog.array_agg(movement.id order by movement.id)::text
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
  ),
  (select movement_ids from test_0038_read_snapshot),
  'ledger: rangos SELECT-only conservan exactamente los mismos IDs'
);
select is(
  (select count(*)::integer from public.nomina_pagos_tiempo_real),
  (select payment_count from test_0038_read_snapshot),
  'ledger: rangos SELECT-only no crean headers de pago'
);
select is(
  (select count(*)::integer from public.nomina_pago_cortes_legacy),
  (select cut_count from test_0038_read_snapshot),
  'ledger: rangos SELECT-only no alteran cortes legacy'
);
select is(
  (select count(*)::integer from public.nomina_pago_movimientos),
  (select link_count from test_0038_read_snapshot),
  'ledger: rangos SELECT-only no consumen movimientos'
);
select is(
  (
    select loan.pendiente
    from public.nomina_prestamos loan
    where loan.id = '38000000-0000-0000-0000-000000000041'
  ),
  (select loan_balance from test_0038_read_snapshot),
  'ledger: rangos SELECT-only no mutan el prestamo'
);
select is(
  (
    select credit.pendiente
    from public.nomina_creditos credit
    where credit.id = '38000000-0000-0000-0000-000000000042'
  ),
  (select credit_balance from test_0038_read_snapshot),
  'ledger: rangos SELECT-only no mutan el credito'
);

create temporary table test_0038_results(
  result_name text primary key,
  payload jsonb not null
) on commit drop;
grant select, insert on test_0038_results to authenticated;

-- C. Registrar el pago consume la jornada y la retira de pendientes.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'pending_before_payment',
  public.listar_pagos_pendientes(
    date '2038-01-01', date '2038-01-15'
  ) -> 0
);
select ok(
  (select payload ->> 'source_fingerprint'
   from test_0038_results where result_name = 'pending_before_payment')
    ~ '^[0-9a-f]{64}$',
  'C: listar entrega fingerprint SHA-256 para confirmar'
);
insert into test_0038_results(result_name, payload)
values (
  'first_payment',
  public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000021',
    date '2038-01-01', date '2038-01-15',
    'Pago quincenal de prueba',
    '38000000-0000-0000-0000-000000000091',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'pending_before_payment')
  )
);
select ok(
  nullif((select payload ->> 'id' from test_0038_results
          where result_name = 'first_payment'), '') is not null,
  'C: registrar pago devuelve un id estable'
);
select is(
  (select payload ->> 'motive' from test_0038_results
   where result_name = 'first_payment'),
  'Pago quincenal de prueba',
  'C: el ledger conserva el motivo'
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2038-01-01', date '2038-01-15')
  ),
  0,
  'C: la jornada pagada desaparece de pendientes'
);
select is(
  (
    public.obtener_resumen_pagos_tiempo_real(
      date '2038-01-01', date '2038-01-15'
    ) ->> 'pendiente_a_pagar'
  )::numeric,
  0::numeric,
  'C: el saldo pendiente queda en cero'
);
select is(
  (
    public.obtener_resumen_pagos_tiempo_real(
      date '2038-01-01', date '2038-01-15'
    ) ->> 'ya_pagado'
  )::numeric,
  0::numeric,
  'C: el resumen no atribuye el pago a la fecha de la jornada'
);
select is(
  (
    public.obtener_resumen_pagos_tiempo_real(
      current_date, current_date
    ) ->> 'ya_pagado'
  )::numeric,
  111.25::numeric,
  'C: el resumen informa 111.25 en la fecha real del pago'
);
reset role;
set local role postgres;

select is(
  (select count(*)::integer from public.nomina_pagos_tiempo_real),
  1,
  'C: existe una sola fila de pago'
);
select is(
  (select count(*)::integer from public.nomina_pago_jornadas),
  1,
  'C: el pago enlaza exactamente la jornada liquidada'
);
select is(
  (
    select count(*)::integer
    from public.nomina_pago_movimientos consumed
    where consumed.empresa_id = '38000000-0000-0000-0000-000000000010'
      and consumed.pago_id = (
        select (payload ->> 'id')::uuid
        from test_0038_results where result_name = 'first_payment'
      )
  ),
  (select movement_count from test_0038_read_snapshot),
  'C: el pago consume exactamente los movimientos preexistentes del rango'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.fecha_devengo between date '2038-01-01' and date '2038-01-15'
      and not exists (
        select 1
        from public.nomina_pago_movimientos consumed
        where consumed.empresa_id = movement.empresa_id
          and consumed.movimiento_id = movement.id
      )
  ),
  0,
  'C: no queda ningun movimiento concreto del pago sin consumir'
);
select is(
  (
    select round(
      coalesce(sum(case movement.clase
        when 'DEVENGO' then movement.monto
        when 'DEDUCCION' then -movement.monto
        else 0
      end), 0),
      2
    )
    from public.nomina_pago_movimientos consumed
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = consumed.empresa_id
     and movement.id = consumed.movimiento_id
    where consumed.empresa_id = '38000000-0000-0000-0000-000000000010'
      and consumed.pago_id = (
        select (payload ->> 'id')::uuid
        from test_0038_results where result_name = 'first_payment'
      )
  ),
  111.25::numeric,
  'C: la suma firmada de movimientos coincide con el pago'
);

-- D. El mismo UUID y payload es replay; no duplica pago ni jornadas.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'payment_replay',
  public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000021',
    date '2038-01-01', date '2038-01-15',
    'Pago quincenal de prueba',
    '38000000-0000-0000-0000-000000000091',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'pending_before_payment')
  )
);
select is(
  (select payload ->> 'id' from test_0038_results
   where result_name = 'payment_replay'),
  (select payload ->> 'id' from test_0038_results
   where result_name = 'first_payment'),
  'D: replay devuelve el mismo id'
);
select throws_ok(
  $$select public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000021',
    date '2038-01-01', date '2038-01-31',
    'Payload distinto',
    '38000000-0000-0000-0000-000000000091',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'pending_before_payment')
  )$$,
  'P0001', 'IDEMPOTENCY_KEY_REUSED',
  'D: la misma key con payload distinto se rechaza'
);
reset role;
set local role postgres;

select is(
  (select count(*)::integer from public.nomina_pagos_tiempo_real),
  1,
  'D: replay no duplica el ledger'
);
select is(
  (select count(*)::integer from public.nomina_pago_jornadas),
  1,
  'D: replay no consume dos veces la jornada'
);
select is(
  (
    select count(*)::integer
    from public.nomina_pago_movimientos consumed
    where consumed.empresa_id = '38000000-0000-0000-0000-000000000010'
      and consumed.pago_id = (
        select (payload ->> 'id')::uuid
        from test_0038_results where result_name = 'first_payment'
      )
  ),
  (select movement_count from test_0038_read_snapshot),
  'D: replay no enlaza un movimiento por segunda vez'
);

-- El lector puede consultar, pero no confirmar pagos.
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000002', true
);
select lives_ok(
  $$select public.listar_pagos_pendientes(
    date '2038-01-01', date '2038-01-31'
  )$$,
  'nomina.ver permite leer pagos'
);
select throws_ok(
  $$select public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000021',
    date '2038-01-01', date '2038-01-31',
    'No autorizado',
    '38000000-0000-0000-0000-000000000092',
    repeat('0', 64)
  )$$,
  '42501', 'NOMINA_PERMISSION_DENIED',
  'nomina.ver sin nomina.pagar no confirma pagos'
);
reset role;
set local role postgres;

-- E. Una jornada posterior al pago vuelve a generar saldo pendiente.
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000032',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000021',
  date '2038-01-20', 'FINALIZADA',
  timestamptz '2038-01-20 08:00:00+00',
  timestamptz '2038-01-20 12:00:00+00',
  240, 0, 'WEB', false
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2038-01-16', date '2038-01-31')
  ),
  1,
  'E: una jornada nueva vuelve a mostrar al empleado'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-16', date '2038-01-31'
    ) -> 0 ->> 'journeys'
  )::integer,
  1,
  'E: solo queda una jornada sin pagar'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-01-16', date '2038-01-31'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  37.25::numeric,
  'E: el ciclo posterior agrega 37.25 netos sin duplicar fuentes'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.source_type = 'CYCLE_INCENTIVE'
  ),
  2,
  'E: incentivo fijo reaparece una sola vez en el ciclo siguiente'
);
select is(
  (
    select count(distinct (movement.ciclo_desde, movement.ciclo_hasta))::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000021'
      and movement.source_type = 'LOAN_INSTALLMENT_OBLIGATION'
      and movement.prestamo_id = '38000000-0000-0000-0000-000000000041'
  ),
  2,
  'E: prestamo tiene exactamente una cuota por cada uno de dos ciclos'
);

-- F. El tenant A nunca ve ni paga jornadas del tenant B.
select ok(
  public.listar_pagos_pendientes(
    date '2038-01-01', date '2038-01-31'
  )::text not like '%38000000-0000-0000-0000-000000000121%',
  'F: A no recibe el empleado de B'
);
select throws_ok(
  $$select public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000121',
    date '2038-01-01', date '2038-01-31',
    'Cruce no permitido',
    '38000000-0000-0000-0000-000000000093',
    repeat('0', 64)
  )$$,
  'P0001', 'EMPLEADO_NO_ENCONTRADO',
  'F: registrar pago de otro tenant no filtra su existencia'
);

-- G. Los filtros de fecha separan pendientes e historial sin solaparlos.
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2038-01-01', date '2038-01-15')
  ),
  0,
  'G: la primera quincena ya pagada no queda pendiente'
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2038-01-16', date '2038-01-31')
  ),
  1,
  'G: la segunda quincena contiene la jornada nueva'
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_historial_pagos(date '2038-01-01', date '2038-01-15')
  ),
  0,
  'G: historial filtra por fecha real de pago, no por fecha de jornada'
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_historial_pagos(current_date, current_date)
  ),
  1,
  'G: historial incluye el pago en su fecha real'
);
select is(
  public.listar_historial_pagos(
    current_date, current_date
  ) -> 0 ->> 'id',
  (select payload ->> 'id' from test_0038_results
   where result_name = 'first_payment'),
  'G: historial devuelve el mismo snapshot inmutable'
);
select ok(
  public.listar_historial_pagos(
    current_date, current_date
  ) -> 0 ?& array[
    'id', 'employee_id', 'paid_at', 'motive', 'formula', 'deduction_items'
  ],
  'G: historial conserva identidad, motivo y formula del pago'
);
reset role;
set local role postgres;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000003', true
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2038-01-01', date '2038-01-31')
  ),
  1,
  'F: B ve su propio pendiente'
);
select is(
  public.listar_pagos_pendientes(
    date '2038-01-01', date '2038-01-31'
  ) -> 0 ->> 'employee_id',
  '38000000-0000-0000-0000-000000000121',
  'F: B recibe solo su empleado'
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_historial_pagos(current_date, current_date)
  ),
  0,
  'F: B no ve el historial de A'
);
reset role;
set local role postgres;
select set_config('request.jwt.claim.sub', '', true);

-- Casos adversariales del ledger por evento. Usan empleados y meses aislados
-- para no alterar A-H.
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values
  ('38000000-0000-0000-0000-000000000023',
   '38000000-0000-0000-0000-000000000010', '380022',
   'Empleado multifila 0038', date '2030-01-01', 'activo',
   2400, 'quincenal', true),
  ('38000000-0000-0000-0000-000000000024',
   '38000000-0000-0000-0000-000000000010', '380023',
   'Empleado cuota parcial 0038', date '2030-01-01', 'activo',
   2400, 'quincenal', true),
  ('38000000-0000-0000-0000-000000000025',
   '38000000-0000-0000-0000-000000000010', '380024',
   'Empleado fail closed 0038', date '2030-01-01', 'activo',
   2400, 'quincenal', true);

insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values
  ('38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000023', 30, 8,
   'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 0, 0, 0, false, 0, true),
  ('38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000024', 30, 8,
   'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 0, 0, 5, true, 0, true),
  ('38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000025', 30, 8,
   'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 0, 0, 0, false, 0, true);

insert into public.nomina_prestamos(
  id, empresa_id, empleado_id, monto_total, total_pagado, pendiente,
  descuento_periodo, estado, fecha_inicio, motivo, creado_por
) values (
  '38000000-0000-0000-0000-000000000043',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000024',
  100, 0, 100, 30, 'ENTREGADO', date '2038-02-01',
  'Prestamo parcial sintetico 0038',
  '38000000-0000-0000-0000-000000000001'
);

-- Dos cierres en el mismo statement deben producir dos eventos fechados, no
-- un acumulado completo atribuido al primer trigger diferido.
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values
  ('38000000-0000-0000-0000-000000000033',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000023',
   date '2038-02-03', 'FINALIZADA',
   timestamptz '2038-02-03 08:00:00+00',
   timestamptz '2038-02-03 12:00:00+00', 240, 0, 'WEB', false),
  ('38000000-0000-0000-0000-000000000034',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000023',
   date '2038-02-10', 'FINALIZADA',
   timestamptz '2038-02-10 08:00:00+00',
   timestamptz '2038-02-10 12:00:00+00', 240, 0, 'WEB', false);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-02-03', date '2038-02-03'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  40::numeric,
  'ledger multifila: primera fecha contiene solo sus cuatro horas'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-02-10', date '2038-02-10'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  40::numeric,
  'ledger multifila: segunda fecha contiene solo sus cuatro horas'
);
insert into test_0038_results(result_name, payload)
values (
  'drift_before_new_source',
  public.listar_pagos_pendientes(
    date '2038-02-01', date '2038-02-15'
  ) -> 0
);
reset role;
set local role postgres;

insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000039',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000023',
  date '2038-02-12', 'FINALIZADA',
  timestamptz '2038-02-12 08:00:00+00',
  timestamptz '2038-02-12 09:00:00+00', 60, 0, 'WEB', false
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select isnt(
  public.listar_pagos_pendientes(
    date '2038-02-01', date '2038-02-15'
  ) -> 0 ->> 'source_fingerprint',
  (select payload ->> 'source_fingerprint'
   from test_0038_results where result_name = 'drift_before_new_source'),
  'fingerprint: un devengo nuevo cambia la confirmacion requerida'
);
select throws_ok(
  $$select public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000023',
    date '2038-02-01', date '2038-02-15',
    'Fingerprint obsoleto',
    '38000000-0000-0000-0000-000000000094',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'drift_before_new_source')
  )$$,
  'P0001', 'PAGO_CAMBIO_REQUIERE_CONFIRMACION',
  'fingerprint: pago rechaza fuentes cambiadas despues de listar'
);
reset role;
set local role postgres;

-- Una cuota inicialmente limitada por net-floor debe completar el target al
-- llegar un segundo devengo, sin volver a solicitar la cuota completa.
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000035',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000024',
  date '2038-03-03', 'FINALIZADA',
  timestamptz '2038-03-03 08:00:00+00',
  timestamptz '2038-03-03 09:00:00+00', 60, 0, 'WEB', false
);
select is(
  (
    select round(coalesce(sum(movement.monto), 0), 2)
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000024'
      and movement.prestamo_id = '38000000-0000-0000-0000-000000000043'
      and movement.ciclo_desde = date '2038-03-01'
      and movement.ciclo_hasta = date '2038-03-15'
  ),
  5::numeric,
  'ledger net-floor: primer devengo aplica solo cinco de la cuota'
);

insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000036',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000024',
  date '2038-03-10', 'FINALIZADA',
  timestamptz '2038-03-10 08:00:00+00',
  timestamptz '2038-03-10 11:00:00+00', 180, 0, 'WEB', false
);
select is(
  (
    select round(coalesce(sum(movement.monto), 0), 2)
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000024'
      and movement.prestamo_id = '38000000-0000-0000-0000-000000000043'
      and movement.ciclo_desde = date '2038-03-01'
      and movement.ciclo_hasta = date '2038-03-15'
  ),
  30::numeric,
  'ledger net-floor: segundo devengo completa, pero no excede, la cuota 30'
);
select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000036'
    ) ->> 'inserted'
  )::integer,
  0,
  'ledger net-floor: replay no vuelve a completar la cuota'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-03-01', date '2038-03-15'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  5::numeric,
  'ledger net-floor: 40 brutos menos fijo 5 y cuota 30 dejan neto 5'
);
reset role;
set local role postgres;

-- Reabrir una jornada o agregar un conflicto pendiente debe cerrar el saldo
-- inmediatamente, aunque el historial de movimientos siga siendo append-only.
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000037',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000025',
  date '2038-04-03', 'FINALIZADA',
  timestamptz '2038-04-03 08:00:00+00',
  timestamptz '2038-04-03 12:00:00+00', 240, 0, 'WEB', false
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2038-04-03', date '2038-04-03')
  ),
  1,
  'ledger fail-closed: jornada valida aparece antes de reabrir'
);
reset role;
set local role postgres;

select throws_ok(
  $$update public.jornadas
    set estado = 'EN_CURSO', finalizado_en = null
    where id = '38000000-0000-0000-0000-000000000037'$$,
  'P0001', 'LIVE_PAYROLL_SOURCE_MUTATION_REQUIRES_REVIEW',
  'ledger fail-closed: una jornada devengada no puede reabrirse'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2038-04-03', date '2038-04-03')
  ),
  1,
  'ledger fail-closed: la mutacion rechazada conserva el devengo original'
);
reset role;
set local role postgres;

insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000038',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000025',
  date '2038-04-05', 'FINALIZADA',
  timestamptz '2038-04-05 08:00:00+00',
  timestamptz '2038-04-05 12:00:00+00', 240, 0, 'WEB', false
);
insert into public.jornada_conflictos(
  empresa_id, jornada_id, snapshot_local, snapshot_remoto, motivo, estado
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000038',
  '{}'::jsonb, '{}'::jsonb, 'Conflicto sintetico 0038', 'PENDIENTE'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2038-04-05', date '2038-04-05')
  ),
  0,
  'ledger fail-closed: conflicto pendiente bloquea el movimiento devengado'
);
reset role;
set local role postgres;

-- Cierre fuera de orden, identidad estable de jornada y reconciliacion de
-- centavos sobre varias fuentes inmutables.
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values
  ('38000000-0000-0000-0000-000000000026',
   '38000000-0000-0000-0000-000000000010', '380025',
   'Empleado cierre tardio 0038', date '2030-01-01', 'activo',
   2400, 'mensual', true),
  ('38000000-0000-0000-0000-000000000027',
   '38000000-0000-0000-0000-000000000010', '380026',
   'Empleado version 0038', date '2030-01-01', 'activo',
   2400, 'quincenal', true),
  ('38000000-0000-0000-0000-000000000028',
   '38000000-0000-0000-0000-000000000010', '380027',
   'Empleado centavos 0038', date '2030-01-01', 'activo',
   1000, 'quincenal', true);

insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values
  ('38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000026', 30, 8,
   'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 0, 0, 0, false, 0, true),
  ('38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000027', 30, 8,
   'PORCENTAJE', 5, 'PORCENTAJE', 2.5, 'MONTO', 0,
   0, 0, 0, false, 0, true),
  ('38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000028', 30, 8,
   'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 0, 0, 0, false, 0, true);

-- En un ciclo mensual, cerrar dia 20 antes que dia 5 no depende del orden de
-- llegada y cada filtro diario conserva exactamente su fuente.
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000040',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000026',
  date '2038-05-20', 'FINALIZADA',
  timestamptz '2038-05-20 08:00:00+00',
  timestamptz '2038-05-20 12:00:00+00', 240, 0, 'WEB', false
);
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000044',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000026',
  date '2038-05-05', 'FINALIZADA',
  timestamptz '2038-05-05 08:00:00+00',
  timestamptz '2038-05-05 12:00:00+00', 240, 0, 'WEB', false
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-05-20', date '2038-05-20'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  40::numeric,
  'ledger fuera de orden: dia 20 conserva solo su jornada'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-05-05', date '2038-05-05'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  40::numeric,
  'ledger fuera de orden: cierre tardio del dia 5 conserva su jornada'
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2038-05-01', date '2038-05-31'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  80::numeric,
  'ledger fuera de orden: el ciclo mensual suma ambas fuentes una vez'
);
reset role;
set local role postgres;
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000026'
      and movement.source_type = 'JOURNEY'
      and movement.ciclo_desde = date '2038-05-01'
      and movement.ciclo_hasta = date '2038-05-31'
  ),
  2,
  'ledger fuera de orden: dos jornadas producen dos controles, sin duplicados'
);

-- Correcciones append-only de jornadas: cada revision genera diferencias
-- inmutables; version_sync no participa en la identidad de correccion.
select has_column(
  'public', 'jornadas', 'revision_nomina',
  'correcciones: jornadas expone revision_nomina monotona'
);

set constraints nomina_devengar_jornada_finalizada immediate;

insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente, version_sync, revision_nomina
) values (
  '38000000-0000-0000-0000-000000000045',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000027',
  date '2038-06-03', 'FINALIZADA',
  timestamptz '2038-06-03 08:00:00+00',
  timestamptz '2038-06-03 10:00:00+00',
  120, 0, 'WEB', false, 0, 0
);

create temporary table test_0038_journey_base_snapshot as
select
  pg_catalog.array_agg(movement.id order by movement.id) movement_ids,
  pg_catalog.jsonb_agg(
    to_jsonb(movement) order by movement.id
  )::text movement_rows
from public.nomina_movimientos_tiempo_real movement
where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
  and movement.jornada_id = '38000000-0000-0000-0000-000000000045';

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'journey_revision_v0',
  public.listar_pagos_pendientes(
    date '2038-06-01', date '2038-06-15'
  ) -> 0
);
reset role;
set local role postgres;

select is(
  (select (payload ->> 'gross')::numeric
   from test_0038_results where result_name = 'journey_revision_v0'),
  20::numeric,
  'correccion A: la jornada original devenga veinte'
);
select is(
  (select (payload ->> 'total_pending')::numeric
   from test_0038_results where result_name = 'journey_revision_v0'),
  18.50::numeric,
  'correccion A: la jornada original conserva neto V3 de 18.50'
);

-- A: correccion no pagada hacia arriba, 120 -> 240 minutos.
select lives_ok(
  $$update public.jornadas
    set minutos_trabajados = 240,
        finalizado_en = timestamptz '2038-06-03 12:00:00+00',
        revision_nomina = revision_nomina + 1
    where id = '38000000-0000-0000-0000-000000000045'$$,
  'correccion A: aumentar una jornada crea una revision compensatoria'
);

select is(
  (select journey.revision_nomina::integer
   from public.jornadas journey
   where journey.id = '38000000-0000-0000-0000-000000000045'),
  1,
  'correccion A: la primera correccion usa revision_nomina uno'
);
select is(
  (select journey.version_sync
   from public.jornadas journey
   where journey.id = '38000000-0000-0000-0000-000000000045'),
  0::bigint,
  'correccion A: corregir nomina no altera version_sync'
);
select is(
  (
    select pg_catalog.jsonb_object_agg(
      movement.concepto,
      jsonb_build_object(
        'clase', movement.clase,
        'monto', movement.monto
      )
    )
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.source_type = 'JOURNEY_CORRECTION'
      and movement.source_key like
        '38000000-0000-0000-0000-000000000045:1:%'
  ),
  jsonb_build_object(
    'NORMAL_PAY', jsonb_build_object(
      'clase', 'DEVENGO', 'monto', 20::numeric
    ),
    'AFP', jsonb_build_object(
      'clase', 'DEDUCCION', 'monto', 1::numeric
    ),
    'SFS', jsonb_build_object(
      'clase', 'DEDUCCION', 'monto', 0.50::numeric
    )
  ),
  'correccion A: revision ascendente guarda solo diferencias V3'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.source_type = 'JOURNEY_REVISION'
      and movement.source_key =
        '38000000-0000-0000-0000-000000000045:1'
  ),
  1,
  'correccion A: revision uno tiene un unico control'
);

insert into test_0038_results(result_name, payload)
values (
  'journey_revision_v1',
  public.listar_pagos_pendientes(
    date '2038-06-01', date '2038-06-15'
  ) -> 0
);

select is(
  (select (payload ->> 'gross')::numeric
   from test_0038_results where result_name = 'journey_revision_v1'),
  40::numeric,
  'correccion A: original mas aumento deja bruto cuarenta'
);
select is(
  (select (payload ->> 'afp')::numeric
   from test_0038_results where result_name = 'journey_revision_v1'),
  2::numeric,
  'correccion A: AFP corregida coincide con V3'
);
select is(
  (select (payload ->> 'sfs')::numeric
   from test_0038_results where result_name = 'journey_revision_v1'),
  1::numeric,
  'correccion A: SFS corregida coincide con V3'
);
select is(
  (select (payload ->> 'total_pending')::numeric
   from test_0038_results where result_name = 'journey_revision_v1'),
  37::numeric,
  'correccion A: saldo ascendente pendiente es treinta y siete'
);
-- A: correccion no pagada hacia abajo, 240 -> 60 minutos.
select lives_ok(
  $$update public.jornadas
    set minutos_trabajados = 60,
        finalizado_en = timestamptz '2038-06-03 09:00:00+00',
        revision_nomina = revision_nomina + 1
    where id = '38000000-0000-0000-0000-000000000045'$$,
  'correccion A: reducir una jornada no pagada crea un reverso compensatorio'
);

select is(
  (
    select pg_catalog.jsonb_object_agg(
      movement.concepto,
      jsonb_build_object('clase', movement.clase, 'monto', movement.monto)
    )
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.source_type = 'JOURNEY_CORRECTION'
      and movement.source_key like
        '38000000-0000-0000-0000-000000000045:2:%'
  ),
  jsonb_build_object(
    'NORMAL_PAY', jsonb_build_object(
      'clase', 'REVERSO_DEVENGO', 'monto', 30::numeric
    ),
    'AFP', jsonb_build_object(
      'clase', 'REVERSO_DEDUCCION', 'monto', 1.50::numeric
    ),
    'SFS', jsonb_build_object(
      'clase', 'REVERSO_DEDUCCION', 'monto', 0.75::numeric
    )
  ),
  'correccion A: bajar jornada guarda reversos positivos por diferencia'
);
select ok(
  (
    select bool_and(movement.monto > 0)
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.source_type = 'JOURNEY_CORRECTION'
      and movement.source_key like
        '38000000-0000-0000-0000-000000000045:2:%'
  ),
  'correccion A: los reversos conservan montos positivos'
);

insert into test_0038_results(result_name, payload)
values (
  'journey_revision_v2',
  public.listar_pagos_pendientes(
    date '2038-06-01', date '2038-06-15'
  ) -> 0
);

select is(
  (select (payload ->> 'gross')::numeric
   from test_0038_results where result_name = 'journey_revision_v2'),
  10::numeric,
  'correccion A: original y ajustes no pagados dejan bruto diez'
);
select is(
  (select (payload ->> 'afp')::numeric
   from test_0038_results where result_name = 'journey_revision_v2'),
  0.50::numeric,
  'correccion A: AFP neta no pagada queda en cincuenta centavos'
);
select is(
  (select (payload ->> 'sfs')::numeric
   from test_0038_results where result_name = 'journey_revision_v2'),
  0.25::numeric,
  'correccion A: SFS neta no pagada queda en veinticinco centavos'
);
select is(
  (select (payload ->> 'total_pending')::numeric
   from test_0038_results where result_name = 'journey_revision_v2'),
  9.25::numeric,
  'correccion A: saldo neto no pagado refleja original mas ajustes'
);

create temporary table test_0038_revision2_replay_snapshot as
select
  count(*)::integer movement_count,
  pg_catalog.array_agg(movement.id order by movement.id)::text movement_ids,
  (
    select count(*)::integer
    from public.nomina_auditoria audit
    where audit.empresa_id = '38000000-0000-0000-0000-000000000010'
      and audit.empleado_id = '38000000-0000-0000-0000-000000000027'
      and audit.accion = 'CORRECCION_JORNADA'
  ) audit_count
from public.nomina_movimientos_tiempo_real movement
where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
  and movement.jornada_id = '38000000-0000-0000-0000-000000000045';

insert into test_0038_results(result_name, payload)
values (
  'journey_revision_v2_replay',
  private.devengar_movimientos_nomina_jornada(
    '38000000-0000-0000-0000-000000000010',
    '38000000-0000-0000-0000-000000000045'
  )
);
select is(
  (select payload ->> 'status'
   from test_0038_results where result_name = 'journey_revision_v2_replay'),
  'REPLAYED_CORRECTION',
  'correccion D: reprocesar revision dos informa replay'
);
select is(
  (select (payload ->> 'inserted')::integer
   from test_0038_results where result_name = 'journey_revision_v2_replay'),
  0,
  'correccion D: reprocesar revision dos no inserta movimientos'
);
select is(
  (
    select pg_catalog.array_agg(movement.id order by movement.id)::text
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.jornada_id = '38000000-0000-0000-0000-000000000045'
  ),
  (select movement_ids from test_0038_revision2_replay_snapshot),
  'correccion D: replay conserva identidades de movimientos'
);
select is(
  (
    select count(*)::integer
    from public.nomina_auditoria audit
    where audit.empresa_id = '38000000-0000-0000-0000-000000000010'
      and audit.empleado_id = '38000000-0000-0000-0000-000000000027'
      and audit.accion = 'CORRECCION_JORNADA'
  ),
  (select audit_count from test_0038_revision2_replay_snapshot),
  'correccion D: replay no duplica auditoria'
);

-- La revision dos aun no pagada se liquida una sola vez.
insert into test_0038_results(result_name, payload)
values (
  'journey_revision_v2_payment',
  public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000027',
    date '2038-06-01', date '2038-06-15',
    'Pago de jornada corregida revision dos',
    '38000000-0000-0000-0000-000000000100',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'journey_revision_v2')
  )
);

select is(
  (
    select jsonb_build_object(
      'gross', payment.monto_bruto,
      'deductions', payment.monto_deducciones,
      'paid', payment.monto_pagado,
      'journeys', payment.jornadas
    )
    from public.nomina_pagos_tiempo_real payment
    where payment.empresa_id = '38000000-0000-0000-0000-000000000010'
      and payment.id = (
        select (payload ->> 'id')::uuid
        from test_0038_results
        where result_name = 'journey_revision_v2_payment'
      )
  ),
  jsonb_build_object(
    'gross', 10::numeric,
    'deductions', 0.75::numeric,
    'paid', 9.25::numeric,
    'journeys', 1
  ),
  'correccion A: pago de revision dos conserva totales V3'
);
select is(
  (
    select round(coalesce(sum(case movement.clase
      when 'DEVENGO' then movement.monto
      when 'REVERSO_DEDUCCION' then movement.monto
      when 'DEDUCCION' then -movement.monto
      when 'REVERSO_DEVENGO' then -movement.monto
      else 0
    end), 0), 2)
    from public.nomina_pago_movimientos consumed
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = consumed.empresa_id
     and movement.id = consumed.movimiento_id
    where consumed.empresa_id = '38000000-0000-0000-0000-000000000010'
      and consumed.pago_id = (
        select (payload ->> 'id')::uuid
        from test_0038_results
        where result_name = 'journey_revision_v2_payment'
      )
  ),
  9.25::numeric,
  'correccion A: pago consume suma firmada exacta de original y ajustes'
);
-- B: tras pagar, una correccion ascendente crea solo la diferencia pendiente.
select lives_ok(
  $$update public.jornadas
    set minutos_trabajados = 240,
        finalizado_en = timestamptz '2038-06-03 12:00:00+00',
        revision_nomina = revision_nomina + 1
    where id = '38000000-0000-0000-0000-000000000045'$$,
  'correccion B: aumentar una jornada pagada crea solo diferencia nueva'
);
insert into test_0038_results(result_name, payload)
values (
  'journey_revision_v3',
  public.listar_pagos_pendientes(
    date '2038-06-01', date '2038-06-15'
  ) -> 0
);

select is(
  (select (payload ->> 'gross')::numeric
   from test_0038_results where result_name = 'journey_revision_v3'),
  30::numeric,
  'correccion B: despues del pago solo queda bruto diferencial treinta'
);
select is(
  (select (payload ->> 'afp')::numeric
   from test_0038_results where result_name = 'journey_revision_v3'),
  1.50::numeric,
  'correccion B: solo AFP diferencial queda pendiente'
);
select is(
  (select (payload ->> 'sfs')::numeric
   from test_0038_results where result_name = 'journey_revision_v3'),
  0.75::numeric,
  'correccion B: solo SFS diferencial queda pendiente'
);
select is(
  (select (payload ->> 'total_pending')::numeric
   from test_0038_results where result_name = 'journey_revision_v3'),
  27.75::numeric,
  'correccion B: solo diferencia positiva neta queda pendiente'
);
select is(
  (select (payload ->> 'journeys')::integer
   from test_0038_results where result_name = 'journey_revision_v3'),
  0,
  'correccion B: diferencia pagable no vuelve a enlazar jornada historica'
);

insert into test_0038_results(result_name, payload)
values (
  'journey_revision_v3_payment',
  public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000027',
    date '2038-06-01', date '2038-06-15',
    'Pago diferencial revision tres',
    '38000000-0000-0000-0000-000000000101',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'journey_revision_v3')
  )
);
insert into test_0038_results(result_name, payload)
values (
  'journey_revision_v3_payment_replay',
  public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000027',
    date '2038-06-01', date '2038-06-15',
    'Pago diferencial revision tres',
    '38000000-0000-0000-0000-000000000101',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'journey_revision_v3')
  )
);

select is(
  (select payload ->> 'id'
   from test_0038_results where result_name = 'journey_revision_v3_payment_replay'),
  (select payload ->> 'id'
   from test_0038_results where result_name = 'journey_revision_v3_payment'),
  'correccion B: replay de pago diferencial devuelve mismo id'
);
select is(
  (
    select jsonb_build_object(
      'gross', payment.monto_bruto,
      'deductions', payment.monto_deducciones,
      'paid', payment.monto_pagado,
      'journeys', payment.jornadas
    )
    from public.nomina_pagos_tiempo_real payment
    where payment.empresa_id = '38000000-0000-0000-0000-000000000010'
      and payment.id = (
        select (payload ->> 'id')::uuid
        from test_0038_results
        where result_name = 'journey_revision_v3_payment'
      )
  ),
  jsonb_build_object(
    'gross', 30::numeric,
    'deductions', 2.25::numeric,
    'paid', 27.75::numeric,
    'journeys', 0
  ),
  'correccion B: pago diferencial no recalcula la jornada historica'
);
select is(
  (
    select count(*)::integer
    from public.nomina_pago_jornadas paid
    where paid.empresa_id = '38000000-0000-0000-0000-000000000010'
      and paid.pago_id = (
        select (payload ->> 'id')::uuid
        from test_0038_results
        where result_name = 'journey_revision_v3_payment'
      )
  ),
  0,
  'correccion B: pago de solo correcciones no duplica enlace de jornada'
);
select is(
  (
    select count(*)::integer
    from public.nomina_pago_movimientos consumed
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = consumed.empresa_id
     and movement.id = consumed.movimiento_id
    where consumed.empresa_id = '38000000-0000-0000-0000-000000000010'
      and consumed.pago_id = (
        select (payload ->> 'id')::uuid
        from test_0038_results
        where result_name = 'journey_revision_v3_payment'
      )
      and movement.source_type = 'JOURNEY_CORRECTION'
      and movement.source_key like
        '38000000-0000-0000-0000-000000000045:3:%'
  ),
  3,
  'correccion B: pago diferencial consume tres movimientos concretos'
);
select is(
  (
    select count(*)::integer
    from public.nomina_pagos_tiempo_real payment
    where payment.empresa_id = '38000000-0000-0000-0000-000000000010'
      and payment.idempotency_key =
        '38000000-0000-0000-0000-000000000101'
  ),
  1,
  'correccion B: replay no duplica encabezado de pago'
);

create temporary table test_0038_correction_history_snapshot as
select
  (
    select pg_catalog.jsonb_agg(
      to_jsonb(payment) order by payment.id
    )::text
    from public.nomina_pagos_tiempo_real payment
    where payment.empresa_id = '38000000-0000-0000-0000-000000000010'
      and payment.empleado_id = '38000000-0000-0000-0000-000000000027'
  ) payment_rows,
  (
    select pg_catalog.jsonb_agg(
      to_jsonb(consumed) order by consumed.pago_id, consumed.movimiento_id
    )::text
    from public.nomina_pago_movimientos consumed
    join public.nomina_pagos_tiempo_real payment
      on payment.empresa_id = consumed.empresa_id
     and payment.id = consumed.pago_id
    where payment.empresa_id = '38000000-0000-0000-0000-000000000010'
      and payment.empleado_id = '38000000-0000-0000-0000-000000000027'
  ) movement_links,
  (
    select pg_catalog.jsonb_agg(
      to_jsonb(paid) order by paid.pago_id, paid.jornada_id
    )::text
    from public.nomina_pago_jornadas paid
    join public.nomina_pagos_tiempo_real payment
      on payment.empresa_id = paid.empresa_id
     and payment.id = paid.pago_id
    where payment.empresa_id = '38000000-0000-0000-0000-000000000010'
      and payment.empleado_id = '38000000-0000-0000-0000-000000000027'
  ) journey_links;
-- C: bajar una jornada ya pagada crea credito; nunca altera pagos historicos.
select lives_ok(
  $$update public.jornadas
    set minutos_trabajados = 0,
        finalizado_en = timestamptz '2038-06-03 08:00:00+00',
        revision_nomina = revision_nomina + 1
    where id = '38000000-0000-0000-0000-000000000045'$$,
  'correccion C: bajar a cero una jornada pagada crea credito compensatorio'
);

select is(
  (
    select pg_catalog.jsonb_object_agg(
      movement.concepto,
      jsonb_build_object('clase', movement.clase, 'monto', movement.monto)
    )
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.source_type = 'JOURNEY_CORRECTION'
      and movement.source_key like
        '38000000-0000-0000-0000-000000000045:4:%'
  ),
  jsonb_build_object(
    'NORMAL_PAY', jsonb_build_object(
      'clase', 'REVERSO_DEVENGO', 'monto', 40::numeric
    ),
    'AFP', jsonb_build_object(
      'clase', 'REVERSO_DEDUCCION', 'monto', 2::numeric
    ),
    'SFS', jsonb_build_object(
      'clase', 'REVERSO_DEDUCCION', 'monto', 1::numeric
    )
  ),
  'correccion C: revision cuatro expresa reversos brutos por clase'
);
select ok(
  (
    select bool_and(movement.monto > 0)
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.source_type = 'JOURNEY_CORRECTION'
      and movement.source_key like
        '38000000-0000-0000-0000-000000000045:4:%'
  ),
  'correccion C: el credito usa movimientos inmutables de monto positivo'
);
select is(
  (
    select jsonb_build_object(
      'net_delta', (revision.snapshot ->> 'net_delta')::numeric,
      'credit_source', (revision.snapshot ->> 'credit_source')::boolean
    )
    from public.nomina_movimientos_tiempo_real revision
    where revision.empresa_id = '38000000-0000-0000-0000-000000000010'
      and revision.source_type = 'JOURNEY_REVISION'
      and revision.source_key =
        '38000000-0000-0000-0000-000000000045:4'
  ),
  jsonb_build_object(
    'net_delta', -37::numeric,
    'credit_source', true
  ),
  'correccion C: revision pagada hacia abajo registra credito neto treinta y siete'
);

select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(
      date '2038-06-01', date '2038-06-15'
    )
  ),
  0,
  'correccion C: empleado con saldo neto no positivo no aparece en pagos'
);
select throws_ok(
  $$select public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000027',
    date '2038-06-01', date '2038-06-15',
    'No debe pagar saldo no positivo',
    '38000000-0000-0000-0000-000000000102',
    repeat('0', 64)
  )$$,
  'P0001', 'PAGO_PENDIENTE_NO_ENCONTRADO',
  'correccion C: registrar pago rechaza saldo neto no positivo'
);

select is(
  (
    select round(
      greatest(
        -(revision.snapshot ->> 'net_delta')::numeric
        - coalesce((
          select sum(application.monto)
          from public.nomina_movimientos_tiempo_real application
          where application.empresa_id = revision.empresa_id
            and application.empleado_id = revision.empleado_id
            and application.source_type = 'CORRECTION_CREDIT_APPLICATION'
            and application.snapshot ->> 'credit_key' = revision.source_key
        ), 0),
        0
      ),
      2
    )
    from public.nomina_movimientos_tiempo_real revision
    where revision.empresa_id = '38000000-0000-0000-0000-000000000010'
      and revision.source_type = 'JOURNEY_REVISION'
      and revision.source_key =
        '38000000-0000-0000-0000-000000000045:4'
  ),
  37::numeric,
  'correccion C: credito empresarial pendiente queda en treinta y siete'
);

create temporary table test_0038_revision4_replay_snapshot as
select
  count(*)::integer movement_count,
  pg_catalog.array_agg(movement.id order by movement.id)::text movement_ids,
  (
    select count(*)::integer
    from public.nomina_auditoria audit
    where audit.empresa_id = '38000000-0000-0000-0000-000000000010'
      and audit.empleado_id = '38000000-0000-0000-0000-000000000027'
      and audit.accion = 'CORRECCION_JORNADA'
  ) audit_count
from public.nomina_movimientos_tiempo_real movement
where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
  and movement.jornada_id = '38000000-0000-0000-0000-000000000045';

insert into test_0038_results(result_name, payload)
values (
  'journey_revision_v4_replay',
  private.devengar_movimientos_nomina_jornada(
    '38000000-0000-0000-0000-000000000010',
    '38000000-0000-0000-0000-000000000045'
  )
);
select is(
  (select payload ->> 'status'
   from test_0038_results where result_name = 'journey_revision_v4_replay'),
  'REPLAYED_CORRECTION',
  'correccion D: reprocesar revision cuatro informa replay'
);
select is(
  (select (payload ->> 'inserted')::integer
   from test_0038_results where result_name = 'journey_revision_v4_replay'),
  0,
  'correccion D: reprocesar revision cuatro no inserta duplicados'
);
select is(
  (
    select pg_catalog.array_agg(movement.id order by movement.id)::text
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.jornada_id = '38000000-0000-0000-0000-000000000045'
  ),
  (select movement_ids from test_0038_revision4_replay_snapshot),
  'correccion D: replay de credito conserva todos los ids'
);
select is(
  (
    select count(*)::integer
    from public.nomina_auditoria audit
    where audit.empresa_id = '38000000-0000-0000-0000-000000000010'
      and audit.empleado_id = '38000000-0000-0000-0000-000000000027'
      and audit.accion = 'CORRECCION_JORNADA'
  ),
  (select audit_count from test_0038_revision4_replay_snapshot),
  'correccion D: replay de credito no repite auditoria'
);
-- E: ganancias futuras absorben el credito y solo exponen saldo neto positivo.
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000071',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000027',
  date '2038-06-20', 'FINALIZADA',
  timestamptz '2038-06-20 08:00:00+00',
  timestamptz '2038-06-20 10:00:00+00',
  120, 0, 'WEB', false
);

select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(
      date '2038-06-16', date '2038-06-30'
    )
  ),
  0,
  'correccion E: primera jornada futura queda oculta al ser absorbida por credito'
);

select is(
  (
    select round(coalesce(sum(application.monto), 0), 2)
    from public.nomina_movimientos_tiempo_real application
    where application.empresa_id = '38000000-0000-0000-0000-000000000010'
      and application.empleado_id = '38000000-0000-0000-0000-000000000027'
      and application.source_type = 'CORRECTION_CREDIT_APPLICATION'
      and application.snapshot ->> 'credit_key' =
        '38000000-0000-0000-0000-000000000045:4'
      and application.snapshot ->> 'target_journey_id' =
        '38000000-0000-0000-0000-000000000071'
  ),
  18.50::numeric,
  'correccion E: jornada futura de 120 minutos consume 18.50 de credito'
);

insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000072',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000027',
  date '2038-06-21', 'FINALIZADA',
  timestamptz '2038-06-21 08:00:00+00',
  timestamptz '2038-06-21 12:00:00+00',
  240, 0, 'WEB', false
);

create temporary table test_0038_future_read_snapshot as
select
  count(*)::integer movement_count,
  pg_catalog.array_agg(movement.id order by movement.id)::text movement_ids
from public.nomina_movimientos_tiempo_real movement
where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
  and movement.empleado_id = '38000000-0000-0000-0000-000000000027';

select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(
      date '2038-06-20', date '2038-06-20'
    )
  ),
  0,
  'correccion E: filtro diario oculta saldo neto cero'
);
insert into test_0038_results(result_name, payload)
values (
  'journey_credit_future_positive',
  public.listar_pagos_pendientes(
    date '2038-06-16', date '2038-06-30'
  ) -> 0
);

select is(
  (select payload ->> 'employee_id'
   from test_0038_results where result_name = 'journey_credit_future_positive'),
  '38000000-0000-0000-0000-000000000027',
  'correccion E: empleado reaparece cuando el neto futuro supera cero'
);
select is(
  (select (payload ->> 'journeys')::integer
   from test_0038_results where result_name = 'journey_credit_future_positive'),
  2,
  'correccion E: rango futuro cuenta sus dos jornadas concretas'
);
select is(
  (select (payload ->> 'gross')::numeric
   from test_0038_results where result_name = 'journey_credit_future_positive'),
  60::numeric,
  'correccion E: bruto futuro suma veinte mas cuarenta'
);
select is(
  (select (payload ->> 'afp')::numeric
   from test_0038_results where result_name = 'journey_credit_future_positive'),
  3::numeric,
  'correccion E: AFP futura mantiene formula V3'
);
select is(
  (select (payload ->> 'sfs')::numeric
   from test_0038_results where result_name = 'journey_credit_future_positive'),
  1.50::numeric,
  'correccion E: SFS futura mantiene formula V3'
);
select is(
  (select (payload ->> 'other_discounts')::numeric
   from test_0038_results where result_name = 'journey_credit_future_positive'),
  37::numeric,
  'correccion E: credito empresarial aparece como descuento futuro acumulado'
);
select is(
  (select (payload ->> 'total_pending')::numeric
   from test_0038_results where result_name = 'journey_credit_future_positive'),
  18.50::numeric,
  'correccion E: solo saldo neto positivo 18.50 queda pendiente'
);
select is(
  (
    select jsonb_build_object(
      'count', count(*)::integer,
      'amount', round(coalesce(sum(application.monto), 0), 2)
    )
    from public.nomina_movimientos_tiempo_real application
    where application.empresa_id = '38000000-0000-0000-0000-000000000010'
      and application.empleado_id = '38000000-0000-0000-0000-000000000027'
      and application.source_type = 'CORRECTION_CREDIT_APPLICATION'
      and application.snapshot ->> 'credit_key' =
        '38000000-0000-0000-0000-000000000045:4'
  ),
  jsonb_build_object('count', 2, 'amount', 37::numeric),
  'correccion E: credito se aplica exactamente una vez por jornada futura'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000027'
  ),
  (select movement_count from test_0038_future_read_snapshot),
  'correccion E: consultar rango futuro no crea movimientos'
);
select is(
  (
    select pg_catalog.array_agg(movement.id order by movement.id)::text
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000027'
  ),
  (select movement_ids from test_0038_future_read_snapshot),
  'correccion E: consultar rango futuro conserva identidades'
);
-- Inmutabilidad: movimientos y pagos historicos siguen byte-a-byte iguales.
select is(
  (
    select pg_catalog.jsonb_agg(
      to_jsonb(movement) order by movement.id
    )::text
    from public.nomina_movimientos_tiempo_real movement
    where movement.id in (
      select unnest(snapshot.movement_ids)
      from test_0038_journey_base_snapshot snapshot
    )
  ),
  (select movement_rows from test_0038_journey_base_snapshot),
  'correcciones: movimiento original nunca se modifica ni borra'
);
select is(
  (
    select pg_catalog.jsonb_agg(
      to_jsonb(payment) order by payment.id
    )::text
    from public.nomina_pagos_tiempo_real payment
    where payment.empresa_id = '38000000-0000-0000-0000-000000000010'
      and payment.empleado_id = '38000000-0000-0000-0000-000000000027'
  ),
  (select payment_rows from test_0038_correction_history_snapshot),
  'correccion C: encabezados de pagos historicos quedan intactos'
);
select is(
  (
    select pg_catalog.jsonb_agg(
      to_jsonb(consumed) order by consumed.pago_id, consumed.movimiento_id
    )::text
    from public.nomina_pago_movimientos consumed
    join public.nomina_pagos_tiempo_real payment
      on payment.empresa_id = consumed.empresa_id
     and payment.id = consumed.pago_id
    where payment.empresa_id = '38000000-0000-0000-0000-000000000010'
      and payment.empleado_id = '38000000-0000-0000-0000-000000000027'
  ),
  (select movement_links from test_0038_correction_history_snapshot),
  'correccion C: enlaces de movimientos pagados quedan intactos'
);
select is(
  (
    select pg_catalog.jsonb_agg(
      to_jsonb(paid) order by paid.pago_id, paid.jornada_id
    )::text
    from public.nomina_pago_jornadas paid
    join public.nomina_pagos_tiempo_real payment
      on payment.empresa_id = paid.empresa_id
     and payment.id = paid.pago_id
    where payment.empresa_id = '38000000-0000-0000-0000-000000000010'
      and payment.empleado_id = '38000000-0000-0000-0000-000000000027'
  ),
  (select journey_links from test_0038_correction_history_snapshot),
  'correccion C: enlace historico de jornada pagada queda intacto'
);
select is(
  (
    select pg_catalog.jsonb_object_agg(
      audit.despues ->> 'revision',
      (audit.despues ->> 'delta')::numeric
      order by (audit.despues ->> 'revision')::integer
    )
    from public.nomina_auditoria audit
    where audit.empresa_id = '38000000-0000-0000-0000-000000000010'
      and audit.empleado_id = '38000000-0000-0000-0000-000000000027'
      and audit.accion = 'CORRECCION_JORNADA'
  ),
  jsonb_build_object(
    '1', 18.50::numeric,
    '2', -27.75::numeric,
    '3', 27.75::numeric,
    '4', -37::numeric
  ),
  'correcciones: auditoria conserva delta de cada revision'
);
select is(
  (
    select count(*)::integer
    from public.nomina_auditoria audit
    where audit.empresa_id = '38000000-0000-0000-0000-000000000010'
      and audit.empleado_id = '38000000-0000-0000-0000-000000000027'
      and audit.actor_id = '38000000-0000-0000-0000-000000000001'
      and audit.accion = 'CORRECCION_JORNADA'
  ),
  4,
  'correcciones: cada revision audita al actor de empresa A una vez'
);

-- F: RLS y la empresa explicita impiden afectar jornadas de otra empresa.
create temporary table test_0038_company_b_correction_snapshot as
select
  (
    select to_jsonb(journey)::text
    from public.jornadas journey
    where journey.empresa_id = '38000000-0000-0000-0000-000000000110'
      and journey.id = '38000000-0000-0000-0000-000000000131'
  ) journey_row,
  (
    select coalesce(
      pg_catalog.jsonb_agg(to_jsonb(movement) order by movement.id),
      '[]'::jsonb
    )::text
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000110'
      and movement.jornada_id = '38000000-0000-0000-0000-000000000131'
  ) movement_rows,
  (
    select count(*)::integer
    from public.nomina_auditoria audit
    where audit.empresa_id = '38000000-0000-0000-0000-000000000110'
      and audit.empleado_id = '38000000-0000-0000-0000-000000000121'
      and audit.accion = 'CORRECCION_JORNADA'
  ) audit_count;

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
set local role postgres;
grant update on public.jornadas to authenticated;
set local role authenticated;
select lives_ok(
  $$update public.jornadas
    set minutos_trabajados = 60,
        finalizado_en = timestamptz '2038-01-05 09:00:00+00',
        revision_nomina = revision_nomina + 1
    where id = '38000000-0000-0000-0000-000000000131'$$,
  'correccion F: RLS hace inocuo el update de A sobre jornada de B'
);
reset role;
set local role postgres;
set local role postgres;
revoke update on public.jornadas from authenticated;
reset role;
set local role postgres;

insert into test_0038_results(result_name, payload)
values (
  'journey_cross_company_replay',
  private.devengar_movimientos_nomina_jornada(
    '38000000-0000-0000-0000-000000000010',
    '38000000-0000-0000-0000-000000000131'
  )
);
select is(
  (select (payload ->> 'inserted')::integer
   from test_0038_results where result_name = 'journey_cross_company_replay'),
  0,
  'correccion F: empresa A no devenga jornada B por llamada interna cruzada'
);
select is(
  (
    select to_jsonb(journey)::text
    from public.jornadas journey
    where journey.empresa_id = '38000000-0000-0000-0000-000000000110'
      and journey.id = '38000000-0000-0000-0000-000000000131'
  ),
  (select journey_row from test_0038_company_b_correction_snapshot),
  'correccion F: jornada de empresa B queda intacta'
);
select is(
  (
    select coalesce(
      pg_catalog.jsonb_agg(to_jsonb(movement) order by movement.id),
      '[]'::jsonb
    )::text
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000110'
      and movement.jornada_id = '38000000-0000-0000-0000-000000000131'
  ),
  (select movement_rows from test_0038_company_b_correction_snapshot),
  'correccion F: movimientos de empresa B quedan intactos'
);
select is(
  (
    select count(*)::integer
    from public.nomina_auditoria audit
    where audit.empresa_id = '38000000-0000-0000-0000-000000000110'
      and audit.empleado_id = '38000000-0000-0000-0000-000000000121'
      and audit.accion = 'CORRECCION_JORNADA'
  ),
  (select audit_count from test_0038_company_b_correction_snapshot),
  'correccion F: empresa A no crea auditoria dentro de B'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.jornada_id = '38000000-0000-0000-0000-000000000131'
  ),
  0,
  'correccion F: ningun movimiento de A referencia jornada de B'
);

-- Dos medias jornadas con tarifa periodica producen 16.67 cada una, pero el
-- motor agregado autoritativo redondea 33.33. El movimiento de reconciliacion
-- debe mantener esa paridad exacta sin una segunda formula.
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values
  ('38000000-0000-0000-0000-000000000046',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000028',
   date '2038-07-03', 'FINALIZADA',
   timestamptz '2038-07-03 08:00:00+00',
   timestamptz '2038-07-03 12:00:00+00', 240, 0, 'WEB', false),
  ('38000000-0000-0000-0000-000000000047',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000028',
   date '2038-07-10', 'FINALIZADA',
   timestamptz '2038-07-10 08:00:00+00',
   timestamptz '2038-07-10 12:00:00+00', 240, 0, 'WEB', false);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'cent_parity_pending',
  public.listar_pagos_pendientes(
    date '2038-07-01', date '2038-07-15'
  ) -> 0
);
reset role;
set local role postgres;
select is(
  (select (payload ->> 'gross')::numeric
   from test_0038_results where result_name = 'cent_parity_pending'),
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000028',
      date '2038-07-01', date '2038-07-15', 'QUINCENAL', null
    ) ->> 'gross'
  )::numeric,
  'ledger centavos: bruto multi-jornada coincide con V3 agregado'
);
select is(
  (select (payload ->> 'total_pending')::numeric
   from test_0038_results where result_name = 'cent_parity_pending'),
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000028',
      date '2038-07-01', date '2038-07-15', 'QUINCENAL', null
    ) ->> 'net'
  )::numeric,
  'ledger centavos: neto multi-jornada coincide con V3 agregado'
);

-- Componentes una-vez-por-ciclo: leer el dia 3 y despues cerrar el dia 10 no
-- vuelve a crear incentivo ni descuento fijo. El saldo agregado sigue siendo
-- exactamente el resultado autoritativo de V3 para las dos fuentes.
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '38000000-0000-0000-0000-000000000029',
  '38000000-0000-0000-0000-000000000010', '380028',
  'Empleado componentes ciclo 0038', date '2030-01-01', 'activo',
  2400, 'quincenal', true
);
insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000029', 30, 8,
  'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 10, 0, 5, true, 0, true
);
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000048',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000029',
  date '2039-01-03', 'FINALIZADA',
  timestamptz '2039-01-03 08:00:00+00',
  timestamptz '2039-01-03 12:00:00+00', 240, 0, 'WEB', false
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'once_cycle_day3',
  public.listar_pagos_pendientes(date '2039-01-03', date '2039-01-03') -> 0
);
reset role;
set local role postgres;
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000049',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000029',
  date '2039-01-10', 'FINALIZADA',
  timestamptz '2039-01-10 08:00:00+00',
  timestamptz '2039-01-10 12:00:00+00', 240, 0, 'WEB', false
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'once_cycle_day3_day10',
  public.listar_pagos_pendientes(date '2039-01-01', date '2039-01-15') -> 0
);
reset role;
set local role postgres;
select isnt(
  (select payload ->> 'source_fingerprint'
   from test_0038_results where result_name = 'once_cycle_day3'),
  (select payload ->> 'source_fingerprint'
   from test_0038_results where result_name = 'once_cycle_day3_day10'),
  'ledger ciclo: una fuente posterior cambia el fingerprint sin mutar la lectura previa'
);
select is(
  (select (payload ->> 'total_pending')::numeric
   from test_0038_results where result_name = 'once_cycle_day3_day10'),
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000029',
      date '2039-01-01', date '2039-01-15', 'QUINCENAL', null
    ) ->> 'net'
  )::numeric,
  'ledger ciclo: dos cierres conservan neto V3 con componentes una sola vez'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000029'
      and movement.ciclo_desde = date '2039-01-01'
      and movement.ciclo_hasta = date '2039-01-15'
      and movement.source_type = 'CYCLE_INCENTIVE'
  ),
  1,
  'ledger ciclo: dos cierres conservan un solo incentivo fijo'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000029'
      and movement.ciclo_desde = date '2039-01-01'
      and movement.ciclo_hasta = date '2039-01-15'
      and movement.source_type = 'CYCLE_FIXED_OBLIGATION'
  ),
  1,
  'ledger ciclo: dos cierres conservan una sola obligacion fija'
);

-- Si el primer evento ya fue pagado, un cierre posterior del mismo ciclo solo
-- ofrece su variable nueva. Incentivo, fijo y cuota consumidos no reaparecen.
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '38000000-0000-0000-0000-000000000030',
  '38000000-0000-0000-0000-000000000010', '380029',
  'Empleado pago intra ciclo 0038', date '2030-01-01', 'activo',
  2400, 'quincenal', true
);
insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000030', 30, 8,
  'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 10, 0, 5, true, 0, true
);
insert into public.nomina_prestamos(
  id, empresa_id, empleado_id, monto_total, total_pagado, pendiente,
  descuento_periodo, estado, fecha_inicio, motivo, creado_por
) values (
  '38000000-0000-0000-0000-000000000044',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000030',
  100, 0, 100, 12, 'ENTREGADO', date '2039-02-01',
  'Prestamo intra ciclo sintetico 0038',
  '38000000-0000-0000-0000-000000000001'
);
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000050',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000030',
  date '2039-02-03', 'FINALIZADA',
  timestamptz '2039-02-03 08:00:00+00',
  timestamptz '2039-02-03 12:00:00+00', 240, 0, 'WEB', false
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'intra_cycle_before_payment',
  public.listar_pagos_pendientes(date '2039-02-03', date '2039-02-03') -> 0
);
insert into test_0038_results(result_name, payload)
values (
  'intra_cycle_first_payment',
  public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000030',
    date '2039-02-03', date '2039-02-03',
    'Primer evento del ciclo',
    '38000000-0000-0000-0000-000000000095',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'intra_cycle_before_payment')
  )
);
reset role;
set local role postgres;
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000051',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000030',
  date '2039-02-10', 'FINALIZADA',
  timestamptz '2039-02-10 08:00:00+00',
  timestamptz '2039-02-10 12:00:00+00', 240, 0, 'WEB', false
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'intra_cycle_after_payment',
  public.listar_pagos_pendientes(date '2039-02-01', date '2039-02-15') -> 0
);
reset role;
set local role postgres;
select is(
  (select (payload ->> 'journeys')::integer
   from test_0038_results where result_name = 'intra_cycle_after_payment'),
  1,
  'ledger pago intra ciclo: solo la jornada posterior queda pendiente'
);
select is(
  (select (payload ->> 'gross')::numeric
   from test_0038_results where result_name = 'intra_cycle_after_payment'),
  40::numeric,
  'ledger pago intra ciclo: no reaparece incentivo ni bruto ya consumido'
);
select is(
  (select (payload ->> 'loan_discount')::numeric
   from test_0038_results where result_name = 'intra_cycle_after_payment'),
  0::numeric,
  'ledger pago intra ciclo: la cuota consumida no vuelve a cobrarse'
);
select is(
  (select (payload ->> 'other_discounts')::numeric
   from test_0038_results where result_name = 'intra_cycle_after_payment'),
  0::numeric,
  'ledger pago intra ciclo: el descuento fijo consumido no vuelve a cobrarse'
);
select is(
  (select (payload ->> 'total_pending')::numeric
   from test_0038_results where result_name = 'intra_cycle_after_payment'),
  40::numeric,
  'ledger pago intra ciclo: el saldo nuevo contiene solo devengo variable'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000030'
      and movement.source_type = 'CYCLE_FIXED_OBLIGATION'
  ),
  1,
  'ledger pago intra ciclo: existe una sola obligacion fija'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000030'
      and movement.source_type = 'LOAN_INSTALLMENT_OBLIGATION'
  ),
  1,
  'ledger pago intra ciclo: existe una sola obligacion de cuota'
);

-- Invalidar una fuente de un ciclo con centavos y deducciones porcentuales no
-- deja vivos movimientos de ciclo sin jornada ni aplicaciones estatutarias de
-- una version obsoleta. Se bloquea cada fuente mediante conflicto, sin mutarla.
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '38000000-0000-0000-0000-000000000031',
  '38000000-0000-0000-0000-000000000010', '380030',
  'Empleado invalidacion ciclo 0038', date '2030-01-01', 'activo',
  1000, 'quincenal', true
);
insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000031', 30, 8,
  'PORCENTAJE', 5, 'PORCENTAJE', 2.5, 'MONTO', 0,
  0, 0, 0, false, 0, true
);
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values
  ('38000000-0000-0000-0000-000000000052',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000031',
   date '2039-03-03', 'FINALIZADA',
   timestamptz '2039-03-03 08:00:00+00',
   timestamptz '2039-03-03 12:00:00+00', 240, 0, 'WEB', false),
  ('38000000-0000-0000-0000-000000000053',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000031',
   date '2039-03-10', 'FINALIZADA',
   timestamptz '2039-03-10 08:00:00+00',
   timestamptz '2039-03-10 12:00:00+00', 240, 0, 'WEB', false);
insert into public.jornada_conflictos(
  empresa_id, jornada_id, snapshot_local, snapshot_remoto, motivo, estado
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000052',
  '{}'::jsonb, '{}'::jsonb, 'Primer conflicto de ciclo sintetico 0038', 'PENDIENTE'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'cycle_after_first_conflict',
  public.listar_pagos_pendientes(date '2039-03-01', date '2039-03-15') -> 0
);
reset role;
set local role postgres;
select is(
  (select (payload ->> 'gross')::numeric
   from test_0038_results where result_name = 'cycle_after_first_conflict'),
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000031',
      date '2039-03-10', date '2039-03-10', 'QUINCENAL', null
    ) ->> 'gross'
  )::numeric,
  'ledger invalidacion: bloquear una fuente elimina rounding de ciclo obsoleto'
);
select is(
  (select (payload ->> 'afp')::numeric
   from test_0038_results where result_name = 'cycle_after_first_conflict'),
  (
    round((public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000031',
      date '2039-03-10', date '2039-03-10', 'QUINCENAL', null
    ) ->> 'gross')::numeric * 0.05, 2)
  ),
  'ledger invalidacion: AFP se reconcilia tras bloquear una fuente'
);
select is(
  (select (payload ->> 'sfs')::numeric
   from test_0038_results where result_name = 'cycle_after_first_conflict'),
  (
    round((public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000031',
      date '2039-03-10', date '2039-03-10', 'QUINCENAL', null
    ) ->> 'gross')::numeric * 0.025, 2)
  ),
  'ledger invalidacion: SFS se reconcilia tras bloquear una fuente'
);
select is(
  (select (payload ->> 'total_pending')::numeric
   from test_0038_results where result_name = 'cycle_after_first_conflict'),
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000031',
      date '2039-03-10', date '2039-03-10', 'QUINCENAL', null
    ) ->> 'net'
  )::numeric,
  'ledger invalidacion: neto conserva V3 con una sola fuente valida'
);

delete from public.jornada_conflictos
where empresa_id = '38000000-0000-0000-0000-000000000010'
  and jornada_id = '38000000-0000-0000-0000-000000000052'
  and estado = 'PENDIENTE';
insert into public.jornada_conflictos(
  empresa_id, jornada_id, snapshot_local, snapshot_remoto, motivo, estado
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000053',
  '{}'::jsonb, '{}'::jsonb, 'Conflicto de ciclo sintetico 0038', 'PENDIENTE'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'cycle_after_conflict',
  public.listar_pagos_pendientes(date '2039-03-01', date '2039-03-15') -> 0
);
reset role;
set local role postgres;
select is(
  (select (payload ->> 'gross')::numeric
   from test_0038_results where result_name = 'cycle_after_conflict'),
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000031',
      date '2039-03-03', date '2039-03-03', 'QUINCENAL', null
    ) ->> 'gross'
  )::numeric,
  'ledger invalidacion: conflicto no deja bruto de ciclo sin fuente'
);
select is(
  (select (payload ->> 'afp')::numeric
   from test_0038_results where result_name = 'cycle_after_conflict'),
  (
    round((public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000031',
      date '2039-03-03', date '2039-03-03', 'QUINCENAL', null
    ) ->> 'gross')::numeric * 0.05, 2)
  ),
  'ledger invalidacion: conflicto no deja AFP de otra fuente'
);
select is(
  (select (payload ->> 'sfs')::numeric
   from test_0038_results where result_name = 'cycle_after_conflict'),
  (
    round((public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000031',
      date '2039-03-03', date '2039-03-03', 'QUINCENAL', null
    ) ->> 'gross')::numeric * 0.025, 2)
  ),
  'ledger invalidacion: conflicto no deja SFS de otra fuente'
);
select is(
  (select (payload ->> 'total_pending')::numeric
   from test_0038_results where result_name = 'cycle_after_conflict'),
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000031',
      date '2039-03-03', date '2039-03-03', 'QUINCENAL', null
    ) ->> 'net'
  )::numeric,
  'ledger invalidacion: conflicto conserva neto V3 de la fuente valida'
);

-- Una fuente nueva valida se reconcilia por evento, no desde el SELECT. La
-- confirmacion observada antes del ajuste queda obsoleta y registrar debe
-- exigir al usuario volver a confirmar el nuevo monto/fingerprint.
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '38000000-0000-0000-0000-000000000032',
  '38000000-0000-0000-0000-000000000010', '380031',
  'Empleado ajuste dinamico 0038', date '2030-01-01', 'activo',
  2400, 'quincenal', true
);
insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000032', 30, 8,
  'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 0, 0, 0, false, 0, true
);
insert into public.nomina_periodos(
  id, empresa_id, fecha_inicio, fecha_fin, tipo_periodo, estado, creada_por
) values (
  '38000000-0000-0000-0000-000000000065',
  '38000000-0000-0000-0000-000000000010',
  date '2039-06-01', date '2039-06-15', 'QUINCENAL', 'BORRADOR',
  '38000000-0000-0000-0000-000000000001'
);
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000055',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000032',
  date '2039-06-03', 'FINALIZADA',
  timestamptz '2039-06-03 08:00:00+00',
  timestamptz '2039-06-03 12:00:00+00', 240, 0, 'WEB', false
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'adjustment_before_insert',
  public.listar_pagos_pendientes(date '2039-06-01', date '2039-06-15') -> 0
);
reset role;
set local role postgres;
insert into public.nomina_ajustes(
  id, empresa_id, periodo_id, empleado_id, tipo, monto, motivo,
  origen, activo, creado_por
) values (
  '38000000-0000-0000-0000-000000000066',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000065',
  '38000000-0000-0000-0000-000000000032',
  'INCENTIVO', 7, 'Ajuste sintetico posterior al listado',
  'MANUAL', true, '38000000-0000-0000-0000-000000000001'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'adjustment_after_insert',
  public.listar_pagos_pendientes(date '2039-06-01', date '2039-06-15') -> 0
);
select isnt(
  (select payload ->> 'source_fingerprint'
   from test_0038_results where result_name = 'adjustment_after_insert'),
  (select payload ->> 'source_fingerprint'
   from test_0038_results where result_name = 'adjustment_before_insert'),
  'ledger ajuste: insertar fuente valida cambia el fingerprint'
);
select is(
  (select (payload ->> 'gross')::numeric
   from test_0038_results where result_name = 'adjustment_after_insert'),
  47::numeric,
  'ledger ajuste: reconciliacion explicita agrega siete al bruto pendiente'
);
select throws_ok(
  $$select public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000032',
    date '2039-06-01', date '2039-06-15',
    'Fingerprint anterior al ajuste',
    '38000000-0000-0000-0000-000000000097',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'adjustment_before_insert')
  )$$,
  'P0001', 'PAGO_CAMBIO_REQUIERE_CONFIRMACION',
  'ledger ajuste: fingerprint anterior no puede confirmar el nuevo saldo'
);
reset role;
set local role postgres;
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000032'
      and movement.ajuste_id = '38000000-0000-0000-0000-000000000066'
      and movement.source_type = 'ADJUSTMENT'
      and private.movimiento_nomina_es_pagable(movement)
  ),
  1,
  'ledger ajuste: la fuente nueva se materializa una sola vez'
);
select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000055'
    ) ->> 'inserted'
  )::integer,
  0,
  'ledger ajuste: repetir el evento no vuelve a devengar el ajuste'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.ajuste_id = '38000000-0000-0000-0000-000000000066'
      and movement.source_type = 'ADJUSTMENT'
  ),
  1,
  'ledger ajuste: el replay conserva una sola identidad fisica'
);
select throws_ok(
  $$update public.nomina_ajustes
    set monto = 9
    where id = '38000000-0000-0000-0000-000000000066'$$,
  'P0001', 'LIVE_PAYROLL_SOURCE_MUTATION_REQUIRES_REVIEW',
  'ledger ajuste: editar una fuente ya materializada falla cerrado'
);
select is(
  (
    select adjustment.monto
    from public.nomina_ajustes adjustment
    where adjustment.id = '38000000-0000-0000-0000-000000000066'
  ),
  7::numeric,
  'ledger ajuste: la mutacion rechazada no altera la fuente confirmable'
);

-- Una deuda ya materializada no admite cambiar silenciosamente identidad o
-- cuota. El trigger debe abortar antes de que un fingerprint viejo pueda pagar
-- una obligacion cuyo contrato fuente ya no coincide.
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '38000000-0000-0000-0000-000000000034',
  '38000000-0000-0000-0000-000000000010', '380032',
  'Empleado deuda inmutable 0038', date '2030-01-01', 'activo',
  2400, 'quincenal', true
);
insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000034', 30, 8,
  'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 0, 0, 0, false, 0, true
);
insert into public.nomina_prestamos(
  id, empresa_id, empleado_id, monto_total, total_pagado, pendiente,
  descuento_periodo, estado, fecha_inicio, motivo, creado_por
) values (
  '38000000-0000-0000-0000-000000000045',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000034',
  100, 0, 100, 10, 'ENTREGADO', date '2039-07-01',
  'Prestamo fuente inmutable 0038',
  '38000000-0000-0000-0000-000000000001'
);
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000056',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000034',
  date '2039-07-03', 'FINALIZADA',
  timestamptz '2039-07-03 08:00:00+00',
  timestamptz '2039-07-03 12:00:00+00', 240, 0, 'WEB', false
);
select throws_ok(
  $$update public.nomina_prestamos
    set descuento_periodo = 20, actualizado_en = now()
    where id = '38000000-0000-0000-0000-000000000045'$$,
  'P0001', 'LIVE_PAYROLL_SOURCE_MUTATION_REQUIRES_REVIEW',
  'ledger deuda: cambiar cuota con movimientos pendientes falla cerrado'
);
select is(
  (
    select loan.descuento_periodo
    from public.nomina_prestamos loan
    where loan.id = '38000000-0000-0000-0000-000000000045'
  ),
  10::numeric,
  'ledger deuda: el trigger revierte completamente la mutacion rechazada'
);

-- Una jornada consumida por pago live no puede volver a entrar en el ledger
-- periodico legacy. El trigger sobre nomina_detalles debe abortar el calculo
-- completo antes de persistir cualquier detalle parcial.
insert into public.nomina_periodos(
  id, empresa_id, fecha_inicio, fecha_fin, tipo_periodo, estado, creada_por
) values (
  '38000000-0000-0000-0000-000000000067',
  '38000000-0000-0000-0000-000000000010',
  date '2039-02-01', date '2039-02-15', 'QUINCENAL', 'BORRADOR',
  '38000000-0000-0000-0000-000000000001'
);
insert into public.nominas(id, empresa_id, periodo_id, estado)
values (
  '38000000-0000-0000-0000-000000000068',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000067', 'BORRADOR'
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select throws_ok(
  $$select public.calcular_nomina(
    '38000000-0000-0000-0000-000000000067'
  )$$,
  'P0001', 'JORNADA_YA_PAGADA_EN_TIEMPO_REAL',
  'guard legacy: nomina periodica no reutiliza una jornada pagada live'
);
reset role;
set local role postgres;
select is(
  (
    select count(*)::integer
    from public.nomina_detalles detail
    where detail.empresa_id = '38000000-0000-0000-0000-000000000010'
      and detail.nomina_id = '38000000-0000-0000-0000-000000000068'
  ),
  0,
  'guard legacy: el calculo abortado no deja detalles parciales'
);

-- Un remanente historico se transforma en una fuente LEGACY_CARRY concreta.
-- Al pagarla, el enlace inmutable y la fila fuente quedan consumidos una vez;
-- el saldo de nomina_descuentos se reduce con la misma identidad y monto.
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '38000000-0000-0000-0000-000000000033',
  '38000000-0000-0000-0000-000000000010', '380033',
  'Empleado carry legacy 0038', date '2030-01-01', 'activo',
  2400, 'quincenal', true
);
insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000033', 30, 8,
  'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 0, 0, 0, false, 0, true
);
insert into public.nomina_periodos(
  id, empresa_id, fecha_inicio, fecha_fin, tipo_periodo, estado,
  creada_por, cerrada_en, cerrada_por
) values (
  '38000000-0000-0000-0000-000000000061',
  '38000000-0000-0000-0000-000000000010',
  date '2039-04-01', date '2039-04-15', 'QUINCENAL', 'CERRADA',
  '38000000-0000-0000-0000-000000000001',
  timestamptz '2039-04-16 00:00:00+00',
  '38000000-0000-0000-0000-000000000001'
);
insert into public.nominas(
  id, empresa_id, periodo_id, estado, version_calculo, motor_version, formula
) values (
  '38000000-0000-0000-0000-000000000062',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000061',
  'CERRADA', 1, 3, 'RC4_SQL_V3_NET_FLOOR'
);
insert into public.nomina_detalles(
  id, empresa_id, nomina_id, empleado_id, codigo_empleado, nombre_empleado,
  tipo_pago, sueldo_base, bruto, neto, version_calculo, formula,
  entradas, resultados
) values (
  '38000000-0000-0000-0000-000000000063',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000062',
  '38000000-0000-0000-0000-000000000033',
  '380033', 'Empleado carry legacy 0038', 'quincenal',
  2400, 4, 4, 1, 'RC4_SQL_V3_NET_FLOOR', '{}'::jsonb, '{}'::jsonb
);
insert into public.nomina_descuentos(
  id, empresa_id, nomina_id, detalle_id, empleado_id,
  tipo, monto, origen, aplicado, monto_solicitado, monto_pendiente, metadata
) values (
  '38000000-0000-0000-0000-000000000064',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000062',
  '38000000-0000-0000-0000-000000000063',
  '38000000-0000-0000-0000-000000000033',
  'AFP', 4, 'MOTOR', false, 12, 8, '{}'::jsonb
);
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000054',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000033',
  date '2039-05-03', 'FINALIZADA',
  timestamptz '2039-05-03 08:00:00+00',
  timestamptz '2039-05-03 12:00:00+00', 240, 0, 'WEB', false
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'carry_before_payment',
  public.listar_pagos_pendientes(date '2039-05-03', date '2039-05-03') -> 0
);
select is(
  (select (payload ->> 'afp')::numeric
   from test_0038_results where result_name = 'carry_before_payment'),
  8::numeric,
  'ledger carry: el saldo historico aparece exactamente una vez'
);
insert into test_0038_results(result_name, payload)
values (
  'carry_payment',
  public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000033',
    date '2039-05-03', date '2039-05-03',
    'Pago con arrastre legacy',
    '38000000-0000-0000-0000-000000000096',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'carry_before_payment')
  )
);
insert into test_0038_results(result_name, payload)
values (
  'carry_payment_replay',
  public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000033',
    date '2039-05-03', date '2039-05-03',
    'Pago con arrastre legacy',
    '38000000-0000-0000-0000-000000000096',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'carry_before_payment')
  )
);
reset role;
set local role postgres;
select is(
  (select payload ->> 'id' from test_0038_results
   where result_name = 'carry_payment_replay'),
  (select payload ->> 'id' from test_0038_results
   where result_name = 'carry_payment'),
  'ledger carry: replay devuelve el mismo pago'
);
select is(
  (
    select count(*)::integer
    from public.nomina_pago_movimientos consumed
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = consumed.empresa_id
     and movement.id = consumed.movimiento_id
    where consumed.empresa_id = '38000000-0000-0000-0000-000000000010'
      and consumed.pago_id = (
        select (payload ->> 'id')::uuid
        from test_0038_results where result_name = 'carry_payment'
      )
      and movement.source_type = 'LEGACY_CARRY_APPLICATION'
      and movement.snapshot ->> 'legacy_discount_id'
        = '38000000-0000-0000-0000-000000000064'
  ),
  1,
  'ledger carry: el pago consume la aplicacion concreta una sola vez'
);
select is(
  (
    select discount.monto_pendiente
    from public.nomina_descuentos discount
    where discount.id = '38000000-0000-0000-0000-000000000064'
  ),
  0::numeric,
  'ledger carry: el saldo pendiente de la fuente queda consumido'
);
select is(
  (
    select discount.monto
    from public.nomina_descuentos discount
    where discount.id = '38000000-0000-0000-0000-000000000064'
  ),
  12::numeric,
  'ledger carry: el monto aplicado avanza exactamente por ocho'
);
select ok(
  (
    select discount.aplicado
      and discount.monto_solicitado
        = discount.monto + discount.monto_pendiente
    from public.nomina_descuentos discount
    where discount.id = '38000000-0000-0000-0000-000000000064'
  ),
  'ledger carry: fuente saldada conserva su invariante y marca aplicado'
);

select ok(
  position(
    'applied.amount > loan.pendiente' in pg_catalog.pg_get_functiondef(
      'public.registrar_pago_empleado(uuid,date,date,text,uuid,text)'::regprocedure
    )
  ) > 0,
  'concurrencia deuda: el pago valida la cuota contra saldo de prestamo vigente'
);
select ok(
  position(
    'applied.amount > credit.pendiente' in pg_catalog.pg_get_functiondef(
      'public.registrar_pago_empleado(uuid,date,date,text,uuid,text)'::regprocedure
    )
  ) > 0,
  'concurrencia deuda: el pago valida la cuota contra saldo de credito vigente'
);
select ok(
  position(
    'monto_pendiente' in pg_catalog.pg_get_functiondef(
      'public.registrar_pago_empleado(uuid,date,date,text,uuid,text)'::regprocedure
    )
  ) > 0,
  'concurrencia carry: registrar pago actualiza la fuente pendiente concreta'
);

-- Dos cuotas de la misma deuda pueden estar devengadas en ciclos distintos.
-- Pagar solo la primera debe actualizar el saldo bajo el guard interno sin
-- invalidar ni consumir la segunda; una mutacion externa sigue fail-closed.
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '38000000-0000-0000-0000-000000000035',
  '38000000-0000-0000-0000-000000000010', '380034',
  'Empleado deuda dos ciclos 0038', date '2030-01-01', 'activo',
  2400, 'quincenal', true
);
insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000035', 30, 8,
  'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 0, 0, 0, false, 0, true
);
insert into public.nomina_prestamos(
  id, empresa_id, empleado_id, monto_total, total_pagado, pendiente,
  descuento_periodo, estado, fecha_inicio, motivo, creado_por
) values (
  '38000000-0000-0000-0000-000000000046',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000035',
  100, 0, 100, 10, 'ENTREGADO', date '2039-08-01',
  'Prestamo dos ciclos sintetico 0038',
  '38000000-0000-0000-0000-000000000001'
);
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values
  ('38000000-0000-0000-0000-000000000057',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000035',
   date '2039-08-03', 'FINALIZADA',
   timestamptz '2039-08-03 08:00:00+00',
   timestamptz '2039-08-03 12:00:00+00', 240, 0, 'WEB', false),
  ('38000000-0000-0000-0000-000000000058',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000035',
   date '2039-08-20', 'FINALIZADA',
   timestamptz '2039-08-20 08:00:00+00',
   timestamptz '2039-08-20 12:00:00+00', 240, 0, 'WEB', false);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values
  (
    'two_cycles_first_before_payment',
    public.listar_pagos_pendientes(
      date '2039-08-01', date '2039-08-15'
    ) -> 0
  ),
  (
    'two_cycles_second_before_payment',
    public.listar_pagos_pendientes(
      date '2039-08-16', date '2039-08-31'
    ) -> 0
  );
select lives_ok(
  $$select public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000035',
    date '2039-08-01', date '2039-08-15',
    'Pago primera cuota de dos ciclos',
    '38000000-0000-0000-0000-000000000098',
    (select payload ->> 'source_fingerprint'
     from test_0038_results
     where result_name = 'two_cycles_first_before_payment')
  )$$,
  'ledger deuda dos ciclos: pagar solo la primera cuota no activa el guard externo'
);
insert into test_0038_results(result_name, payload)
values (
  'two_cycles_second_after_payment',
  public.listar_pagos_pendientes(
    date '2039-08-16', date '2039-08-31'
  ) -> 0
);
reset role;
set local role postgres;
select is(
  (
    select count(*)::integer
    from public.nomina_pagos_tiempo_real payment
    where payment.empresa_id = '38000000-0000-0000-0000-000000000010'
      and payment.idempotency_key = '38000000-0000-0000-0000-000000000098'
  ),
  1,
  'ledger deuda dos ciclos: el primer rango crea exactamente un pago'
);
select is(
  (
    select loan.total_pagado
    from public.nomina_prestamos loan
    where loan.id = '38000000-0000-0000-0000-000000000046'
  ),
  10::numeric,
  'ledger deuda dos ciclos: el pago aplica una sola cuota'
);
select is(
  (
    select loan.pendiente
    from public.nomina_prestamos loan
    where loan.id = '38000000-0000-0000-0000-000000000046'
  ),
  90::numeric,
  'ledger deuda dos ciclos: el saldo disminuye solo por la primera cuota'
);
select is(
  (select (payload ->> 'loan_discount')::numeric
   from test_0038_results where result_name = 'two_cycles_second_after_payment'),
  10::numeric,
  'ledger deuda dos ciclos: la segunda cuota permanece pendiente y pagable'
);
select is(
  (select (payload ->> 'total_pending')::numeric
   from test_0038_results where result_name = 'two_cycles_second_after_payment'),
  30::numeric,
  'ledger deuda dos ciclos: segundo ciclo conserva neto de treinta'
);
select is(
  (select payload ->> 'source_fingerprint'
   from test_0038_results where result_name = 'two_cycles_second_after_payment'),
  (select payload ->> 'source_fingerprint'
   from test_0038_results where result_name = 'two_cycles_second_before_payment'),
  'ledger deuda dos ciclos: pagar otro rango no muta las fuentes del segundo'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.empleado_id = '38000000-0000-0000-0000-000000000035'
      and movement.source_type = 'LOAN_INSTALLMENT_APPLICATION'
      and movement.ciclo_desde = date '2039-08-16'
      and movement.ciclo_hasta = date '2039-08-31'
      and private.movimiento_nomina_es_pagable(movement)
      and not exists (
        select 1 from public.nomina_pago_movimientos consumed
        where consumed.empresa_id = movement.empresa_id
          and consumed.movimiento_id = movement.id
      )
  ),
  1,
  'ledger deuda dos ciclos: queda una aplicacion concreta sin consumir'
);
select throws_ok(
  $$update public.nomina_prestamos
    set descuento_periodo = 11, actualizado_en = now()
    where id = '38000000-0000-0000-0000-000000000046'$$,
  'P0001', 'LIVE_PAYROLL_SOURCE_MUTATION_REQUIRES_REVIEW',
  'ledger deuda dos ciclos: una mutacion externa posterior sigue bloqueada'
);
select is(
  (
    select loan.descuento_periodo
    from public.nomina_prestamos loan
    where loan.id = '38000000-0000-0000-0000-000000000046'
  ),
  10::numeric,
  'ledger deuda dos ciclos: el guard revierte la mutacion externa'
);

-- Orden inverso del cutover: una nomina periodica puede calcularse mientras
-- no exista pago live. Si despues se paga la misma jornada, ninguna transicion
-- del periodo calculado puede avanzar hacia revision/aprobacion/cierre.
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '38000000-0000-0000-0000-000000000036',
  '38000000-0000-0000-0000-000000000010', '380035',
  'Empleado guard inverso 0038', date '2030-01-01', 'activo',
  2400, 'quincenal', true
);
insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000036', 30, 8,
  'MONTO', 0, 'MONTO', 0, 'MONTO', 0, 0, 0, 0, false, 0, true
);
insert into public.nomina_periodos(
  id, empresa_id, fecha_inicio, fecha_fin, tipo_periodo, estado, creada_por
) values (
  '38000000-0000-0000-0000-000000000069',
  '38000000-0000-0000-0000-000000000010',
  date '2039-09-01', date '2039-09-15', 'QUINCENAL', 'BORRADOR',
  '38000000-0000-0000-0000-000000000001'
);
insert into public.nominas(id, empresa_id, periodo_id, estado)
values (
  '38000000-0000-0000-0000-000000000070',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000069', 'BORRADOR'
);
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000059',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000036',
  date '2039-09-03', 'FINALIZADA',
  timestamptz '2039-09-03 08:00:00+00',
  timestamptz '2039-09-03 12:00:00+00', 240, 0, 'WEB', false
);
set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select lives_ok(
  $$select public.calcular_nomina(
    '38000000-0000-0000-0000-000000000069'
  )$$,
  'guard legacy inverso: calcular antes del pago live es valido'
);
select is(
  (
    select period.estado
    from public.nomina_periodos period
    where period.id = '38000000-0000-0000-0000-000000000069'
  ),
  'CALCULADA',
  'guard legacy inverso: el periodo queda calculado antes del pago live'
);
select is(
  (
    select count(*)::integer
    from public.nomina_detalles detail
    where detail.empresa_id = '38000000-0000-0000-0000-000000000010'
      and detail.nomina_id = '38000000-0000-0000-0000-000000000070'
      and detail.empleado_id = '38000000-0000-0000-0000-000000000036'
  ),
  1,
  'guard legacy inverso: existe el detalle periodico previo'
);
insert into test_0038_results(result_name, payload)
values (
  'inverse_guard_pending',
  public.listar_pagos_pendientes(date '2039-09-01', date '2039-09-15') -> 0
);
select lives_ok(
  $$select public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000036',
    date '2039-09-01', date '2039-09-15',
    'Pago live posterior al calculo periodico',
    '38000000-0000-0000-0000-000000000099',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'inverse_guard_pending')
  )$$,
  'guard legacy inverso: pago live previo a la transicion queda registrado'
);
select throws_ok(
  $$select public.cambiar_estado_nomina(
    '38000000-0000-0000-0000-000000000069',
    'EN_REVISION',
    'Intento de avanzar periodo con jornada ya pagada live'
  )$$,
  'P0001', 'JORNADA_YA_PAGADA_EN_TIEMPO_REAL',
  'guard legacy inverso: transicion periodica posterior falla cerrado'
);
reset role;
set local role postgres;
select is(
  (
    select period.estado
    from public.nomina_periodos period
    where period.id = '38000000-0000-0000-0000-000000000069'
  ),
  'CALCULADA',
  'guard legacy inverso: el periodo no avanza tras el rechazo'
);
select is(
  (
    select payroll.estado
    from public.nominas payroll
    where payroll.id = '38000000-0000-0000-0000-000000000070'
  ),
  'CALCULADA',
  'guard legacy inverso: la nomina conserva su estado calculado'
);

-- Configuracion fuente despues de un pago parcial del ciclo: salario y regla
-- no pueden cambiar mientras existen movimientos live del mismo ciclo. Los
-- triggers son explicitos y cada UPDATE rechazado conserva el valor anterior.
select has_trigger(
  'public', 'empleados', 'nomina_guardar_empleado_payroll_source',
  'guard configuracion: empleados protege salario y tipo de pago'
);
select has_trigger(
  'public', 'nomina_reglas_empleado', 'nomina_guardar_regla_source',
  'guard configuracion: reglas de nomina protegen componentes del ciclo'
);
select throws_ok(
  $$update public.empleados
    set salario = 2500
    where id = '38000000-0000-0000-0000-000000000030'$$,
  'P0001', 'LIVE_PAYROLL_SOURCE_MUTATION_REQUIRES_REVIEW',
  'guard configuracion: salario no cambia despues de pago intra ciclo'
);
select is(
  (
    select employee.salario
    from public.empleados employee
    where employee.id = '38000000-0000-0000-0000-000000000030'
  ),
  2400::numeric,
  'guard configuracion: salario conserva el valor confirmado'
);
select throws_ok(
  $$update public.nomina_reglas_empleado
    set incentivo_periodo = 11,
        descuento_fijo_quincenal = 6
    where empresa_id = '38000000-0000-0000-0000-000000000010'
      and empleado_id = '38000000-0000-0000-0000-000000000030'$$,
  'P0001', 'LIVE_PAYROLL_SOURCE_MUTATION_REQUIRES_REVIEW',
  'guard configuracion: incentivo y descuento no cambian tras pago intra ciclo'
);
select is(
  (
    select rule.incentivo_periodo
    from public.nomina_reglas_empleado rule
    where rule.empresa_id = '38000000-0000-0000-0000-000000000010'
      and rule.empleado_id = '38000000-0000-0000-0000-000000000030'
  ),
  10::numeric,
  'guard configuracion: incentivo conserva el valor confirmado'
);
select is(
  (
    select rule.descuento_fijo_quincenal
    from public.nomina_reglas_empleado rule
    where rule.empresa_id = '38000000-0000-0000-0000-000000000010'
      and rule.empleado_id = '38000000-0000-0000-0000-000000000030'
  ),
  5::numeric,
  'guard configuracion: descuento fijo conserva el valor confirmado'
);

-- Ajustes tardios sobre una fuente ya revisada. Los importes se eligieron para
-- que el motor V3 produzca exactamente 1500 por 120 minutos, sin deducciones.
reset role;
set local role postgres;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
set constraints nomina_devengar_jornada_finalizada immediate;

update public.employee_code_sequences
set last_value = 938080
where empresa_id = '38000000-0000-0000-0000-000000000010';

insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values
  ('38000000-0000-0000-0000-000000000081',
   '38000000-0000-0000-0000-000000000010', '938081',
   'Topup A 0038', date '2030-01-01', 'activo',
   180000, 'quincenal', true),
  ('38000000-0000-0000-0000-000000000082',
   '38000000-0000-0000-0000-000000000010', '938082',
   'Topup B 0038', date '2030-01-01', 'activo',
   180000, 'quincenal', true),
  ('38000000-0000-0000-0000-000000000083',
   '38000000-0000-0000-0000-000000000010', '938083',
   'Topup C 0038', date '2030-01-01', 'activo',
   180000, 'quincenal', true);

insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
)
select
  '38000000-0000-0000-0000-000000000010', employee_id, 30, 8,
  'MONTO', 0, 'MONTO', 0, 'MONTO', 0,
  0, 0, 0, false, 0, true
from unnest(array[
  '38000000-0000-0000-0000-000000000081'::uuid,
  '38000000-0000-0000-0000-000000000082'::uuid,
  '38000000-0000-0000-0000-000000000083'::uuid
]) employee_id;

insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values
  ('38000000-0000-0000-0000-000000000084',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000081',
   date '2040-06-03', 'FINALIZADA',
   timestamptz '2040-06-03 08:00:00+00',
   timestamptz '2040-06-03 10:00:00+00',
   120, 0, 'WEB', false),
  ('38000000-0000-0000-0000-000000000085',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000082',
   date '2040-07-03', 'FINALIZADA',
   timestamptz '2040-07-03 08:00:00+00',
   timestamptz '2040-07-03 10:00:00+00',
   120, 0, 'WEB', false),
  ('38000000-0000-0000-0000-000000000086',
   '38000000-0000-0000-0000-000000000010',
   '38000000-0000-0000-0000-000000000083',
   date '2040-08-03', 'FINALIZADA',
   timestamptz '2040-08-03 08:00:00+00',
   timestamptz '2040-08-03 10:00:00+00',
   120, 0, 'WEB', false);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload) values
  ('topup_base_a', public.listar_pagos_pendientes(
    date '2040-06-03', date '2040-06-03'
  ) -> 0),
  ('topup_base_b', public.listar_pagos_pendientes(
    date '2040-07-03', date '2040-07-03'
  ) -> 0),
  ('topup_base_c', public.listar_pagos_pendientes(
    date '2040-08-03', date '2040-08-03'
  ) -> 0);

select is(
  (
    select sum((payload ->> 'total_pending')::numeric)
    from test_0038_results
    where result_name like 'topup_base_%'
  ),
  4500::numeric,
  'topup: tres fuentes V3 parten de 1500'
);

insert into test_0038_results(result_name, payload) values
  ('topup_payment_a', public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000081',
    date '2040-06-03', date '2040-06-03', 'Base A',
    '38000000-0000-0000-0000-000000000180',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'topup_base_a')
  )),
  ('topup_payment_b', public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000082',
    date '2040-07-03', date '2040-07-03', 'Base B',
    '38000000-0000-0000-0000-000000000181',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'topup_base_b')
  )),
  ('topup_payment_c', public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000083',
    date '2040-08-03', date '2040-08-03', 'Base C',
    '38000000-0000-0000-0000-000000000182',
    (select payload ->> 'source_fingerprint'
     from test_0038_results where result_name = 'topup_base_c')
  ));
reset role;
set local role postgres;

create temporary table test_0038_topup_paid_snapshot as
select pg_catalog.jsonb_agg(to_jsonb(payment) order by payment.id)::text rows
from public.nomina_pagos_tiempo_real payment
where payment.empleado_id in (
  '38000000-0000-0000-0000-000000000081',
  '38000000-0000-0000-0000-000000000082',
  '38000000-0000-0000-0000-000000000083'
);

-- A: 1500 pagado, correccion -200 y ajuste tardio +100 dejan credito -100.
update public.jornadas
set minutos_trabajados = 104,
    finalizado_en = timestamptz '2040-06-03 09:44:00+00',
    revision_nomina = revision_nomina + 1
where id = '38000000-0000-0000-0000-000000000084';

select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000084'
    ) ->> 'inserted'
  )::integer,
  0,
  'topup D: replay A1 no duplica'
);

update public.jornadas
set minutos_trabajados = 112,
    finalizado_en = timestamptz '2040-06-03 09:52:00+00',
    revision_nomina = revision_nomina + 1
where id = '38000000-0000-0000-0000-000000000084';

select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000084'
    ) ->> 'inserted'
  )::integer,
  0,
  'topup D: replay A2 no duplica'
);
select is(
  (
    select sum((movement.snapshot ->> 'net_delta')::numeric)
    from public.nomina_movimientos_tiempo_real movement
    where movement.jornada_id = '38000000-0000-0000-0000-000000000084'
      and movement.source_type = 'JOURNEY_REVISION'
  ),
  -100::numeric,
  'topup A: credito logico final es -100'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2040-06-03', date '2040-06-03')
  ),
  0,
  'topup G: saldo no positivo permanece oculto'
);
reset role;
set local role postgres;

-- B: 1500 pagado, correccion -200 y ajuste tardio +300 dejan 100 pendiente.
update public.jornadas
set minutos_trabajados = 104,
    finalizado_en = timestamptz '2040-07-03 09:44:00+00',
    revision_nomina = revision_nomina + 1
where id = '38000000-0000-0000-0000-000000000085';

select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000085'
    ) ->> 'inserted'
  )::integer,
  0,
  'topup D: replay B1 no duplica'
);

update public.jornadas
set minutos_trabajados = 128,
    finalizado_en = timestamptz '2040-07-03 10:08:00+00',
    revision_nomina = revision_nomina + 1
where id = '38000000-0000-0000-0000-000000000085';

select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000085'
    ) ->> 'inserted'
  )::integer,
  0,
  'topup D: replay B2 no duplica'
);
select is(
  (
    select sum((movement.snapshot ->> 'net_delta')::numeric)
    from public.nomina_movimientos_tiempo_real movement
    where movement.jornada_id = '38000000-0000-0000-0000-000000000085'
      and movement.source_type = 'JOURNEY_REVISION'
  ),
  100::numeric,
  'topup B: posicion logica final es +100'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  (
    public.listar_pagos_pendientes(
      date '2040-07-03', date '2040-07-03'
    ) -> 0 ->> 'total_pending'
  )::numeric,
  100::numeric,
  'topup G: al superar cero reaparece solo el neto 100'
);
reset role;
set local role postgres;

-- C: tres revisiones sucesivas convergen al importe canonico final de V3.
update public.jornadas
set minutos_trabajados = 104,
    finalizado_en = timestamptz '2040-08-03 09:44:00+00',
    revision_nomina = revision_nomina + 1
where id = '38000000-0000-0000-0000-000000000086';

select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000086'
    ) ->> 'inserted'
  )::integer,
  0,
  'topup D: replay C1 no duplica'
);

update public.jornadas
set minutos_trabajados = 136,
    finalizado_en = timestamptz '2040-08-03 10:16:00+00',
    revision_nomina = revision_nomina + 1
where id = '38000000-0000-0000-0000-000000000086';

select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000086'
    ) ->> 'inserted'
  )::integer,
  0,
  'topup D: replay C2 no duplica'
);

update public.jornadas
set minutos_trabajados = 116,
    finalizado_en = timestamptz '2040-08-03 09:56:00+00',
    revision_nomina = revision_nomina + 1
where id = '38000000-0000-0000-0000-000000000086';

select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000086'
    ) ->> 'inserted'
  )::integer,
  0,
  'topup D: replay C3 no duplica'
);

select is(
  (
    select round(sum(case movement.clase
      when 'DEVENGO' then movement.monto
      when 'REVERSO_DEVENGO' then -movement.monto
      else 0
    end), 2)
    from public.nomina_movimientos_tiempo_real movement
    where movement.jornada_id = '38000000-0000-0000-0000-000000000086'
      and movement.concepto = 'NORMAL_PAY'
      and movement.source_type in ('JOURNEY_NORMAL', 'JOURNEY_CORRECTION')
  ),
  (
    public.nomina_calculo_empleado_v3(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000083',
      date '2040-08-03', date '2040-08-03', 'QUINCENAL', null
    ) ->> 'normal_pay'
  )::numeric,
  'topup C: tres revisiones convergen al V3 canonico'
);

select is(
  (
    select jsonb_object_agg(grouped.jornada_id::text, grouped.counts)
    from (
      select movement.jornada_id, jsonb_build_object(
        'revisions', count(*) filter (
          where movement.source_type = 'JOURNEY_REVISION'
        ),
        'deltas', count(*) filter (
          where movement.source_type = 'JOURNEY_CORRECTION'
        )
      ) counts
      from public.nomina_movimientos_tiempo_real movement
      where movement.jornada_id in (
        '38000000-0000-0000-0000-000000000084',
        '38000000-0000-0000-0000-000000000085',
        '38000000-0000-0000-0000-000000000086'
      )
      group by movement.jornada_id
    ) grouped
  ),
  jsonb_build_object(
    '38000000-0000-0000-0000-000000000084',
      jsonb_build_object('revisions', 2, 'deltas', 2),
    '38000000-0000-0000-0000-000000000085',
      jsonb_build_object('revisions', 2, 'deltas', 2),
    '38000000-0000-0000-0000-000000000086',
      jsonb_build_object('revisions', 3, 'deltas', 3)
  ),
  'topup D: cada revision produce un unico control y delta'
);

select is(
  (
    select count(*)
    from public.nomina_movimientos_tiempo_real movement
    where movement.jornada_id in (
      '38000000-0000-0000-0000-000000000084',
      '38000000-0000-0000-0000-000000000085',
      '38000000-0000-0000-0000-000000000086'
    )
      and movement.source_type in ('JOURNEY_REVISION', 'JOURNEY_CORRECTION')
  ),
  (
    select count(distinct concat(movement.source_type, ':', movement.source_key))
    from public.nomina_movimientos_tiempo_real movement
    where movement.jornada_id in (
      '38000000-0000-0000-0000-000000000084',
      '38000000-0000-0000-0000-000000000085',
      '38000000-0000-0000-0000-000000000086'
    )
      and movement.source_type in ('JOURNEY_REVISION', 'JOURNEY_CORRECTION')
  ),
  'topup D: ninguna identidad de revision se duplica'
);

-- E: pgTAP conserva todo el caso dentro de una sola transaccion reversible,
-- por lo que no abre una segunda conexion que no veria estos fixtures. La
-- barrera real combina el lock FOR UPDATE con UNIQUE; dos reclamos del mismo
-- estado verifican que, incluso al alcanzar esa barrera, no aparece otro delta.
create temporary table test_0038_topup_race_snapshot as
select count(*) movement_count
from public.nomina_movimientos_tiempo_real movement
where movement.jornada_id = '38000000-0000-0000-0000-000000000086';

create temporary table test_0038_topup_race_attempts as
select attempt,
  private.devengar_movimientos_nomina_jornada(
    '38000000-0000-0000-0000-000000000010',
    case when attempt > 0
      then '38000000-0000-0000-0000-000000000086'::uuid
    end
  ) result
from generate_series(1, 2) attempt;

select is(
  (
    select sum((attempt.result ->> 'inserted')::integer)
    from test_0038_topup_race_attempts attempt
  ),
  0::bigint,
  'topup E: dos reclamos de la misma revision insertan cero duplicados'
);
select is(
  (
    select count(*)
    from public.nomina_movimientos_tiempo_real movement
    where movement.jornada_id = '38000000-0000-0000-0000-000000000086'
  ),
  (select movement_count from test_0038_topup_race_snapshot),
  'topup E: ambos reclamos conservan un solo delta'
);
select ok(
  position(
    'for update' in lower(pg_catalog.pg_get_functiondef(
      'private.devengar_movimientos_nomina_jornada(uuid,uuid,text)'::regprocedure
    ))
  ) > 0,
  'topup E: reconciliacion serializa mediante FOR UPDATE'
);
select col_is_unique(
  'public', 'nomina_movimientos_tiempo_real',
  array['empresa_id', 'source_type', 'source_key'],
  'topup E: UNIQUE arbitra dos inserciones de la misma revision'
);

-- F: aun por llamada interna, una empresa no encuentra la fuente de otra.
select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000131'
    ) ->> 'inserted'
  )::integer,
  0,
  'topup F: empresa A no reconcilia una jornada de B'
);

select is(
  (
    select pg_catalog.jsonb_agg(to_jsonb(payment) order by payment.id)::text
    from public.nomina_pagos_tiempo_real payment
    where payment.empleado_id in (
      '38000000-0000-0000-0000-000000000081',
      '38000000-0000-0000-0000-000000000082',
      '38000000-0000-0000-0000-000000000083'
    )
  ),
  (select rows from test_0038_topup_paid_snapshot),
  'topup: las revisiones no alteran pagos historicos'
);

-- Top-up critico sobre el mismo target_event. Una ganancia futura absorbe la
-- mitad del credito; un ajuste tardio del mismo ciclo reejecuta esa jornada y
-- debe aplicar el remanente con otra identidad append-only.
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo, fecha_ingreso,
  estado_laboral, salario, tipo_pago, activo
) values (
  '38000000-0000-0000-0000-000000000087',
  '38000000-0000-0000-0000-000000000010', '938084',
  'Topup mismo evento 0038', date '2030-01-01', 'activo',
  180000, 'quincenal', true
);
insert into public.nomina_reglas_empleado(
  empresa_id, empleado_id, dias_divisor_quincenal, horas_dia,
  afp_modo, afp_valor, sfs_modo, sfs_valor,
  otros_impuestos_modo, otros_impuestos_valor, incentivo_periodo,
  valor_hora_extra, descuento_fijo_quincenal, descuento_fijo_activo,
  otros_descuentos_fijos, nomina_activa
) values (
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000087', 30, 8,
  'MONTO', 0, 'MONTO', 0, 'MONTO', 0,
  0, 0, 0, false, 0, true
);
insert into public.nomina_periodos(
  id, empresa_id, fecha_inicio, fecha_fin, tipo_periodo, estado, creada_por
) values (
  '38000000-0000-0000-0000-000000000088',
  '38000000-0000-0000-0000-000000000010',
  date '2040-09-01', date '2040-09-15', 'QUINCENAL', 'BORRADOR',
  '38000000-0000-0000-0000-000000000001'
);
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000089',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000087',
  date '2040-09-03', 'FINALIZADA',
  timestamptz '2040-09-03 08:00:00+00',
  timestamptz '2040-09-03 08:08:00+00',
  8, 0, 'WEB', false
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
insert into test_0038_results(result_name, payload)
values (
  'same_event_base',
  public.listar_pagos_pendientes(date '2040-09-03', date '2040-09-03') -> 0
);
select is(
  (
    select (payload ->> 'total_pending')::numeric
    from test_0038_results
    where result_name = 'same_event_base'
  ),
  100::numeric,
  'topup mismo evento: la fuente pagada parte de 100'
);
insert into test_0038_results(result_name, payload)
values (
  'same_event_payment',
  public.registrar_pago_empleado(
    '38000000-0000-0000-0000-000000000087',
    date '2040-09-03', date '2040-09-03',
    'Base para topup sobre mismo evento',
    '38000000-0000-0000-0000-000000000183',
    (
      select payload ->> 'source_fingerprint'
      from test_0038_results
      where result_name = 'same_event_base'
    )
  )
);
reset role;
set local role postgres;

-- La revision pagada a cero origina exactamente 100 de credito empresarial.
update public.jornadas
set minutos_trabajados = 0,
    finalizado_en = timestamptz '2040-09-03 08:00:00+00',
    revision_nomina = revision_nomina + 1
where id = '38000000-0000-0000-0000-000000000089';

select is(
  (
    select -(movement.snapshot ->> 'net_delta')::numeric
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = '38000000-0000-0000-0000-000000000010'
      and movement.jornada_id = '38000000-0000-0000-0000-000000000089'
      and movement.source_type = 'JOURNEY_REVISION'
      and movement.source_key =
        '38000000-0000-0000-0000-000000000089:1'
  ),
  100::numeric,
  'topup mismo evento: la correccion crea credito 100'
);

-- Esta jornada futura ofrece 50 y consume la primera mitad del credito.
insert into public.jornadas(
  id, empresa_id, empleado_id, fecha_laboral, estado,
  iniciado_en, finalizado_en, minutos_trabajados, minutos_pausa,
  origen, revision_pendiente
) values (
  '38000000-0000-0000-0000-000000000090',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000087',
  date '2040-09-05', 'FINALIZADA',
  timestamptz '2040-09-05 08:00:00+00',
  timestamptz '2040-09-05 08:04:00+00',
  4, 0, 'WEB', false
);

select is(
  (
    select jsonb_build_object(
      'count', count(*)::integer,
      'amount', round(coalesce(sum(application.monto), 0), 2)
    )
    from public.nomina_movimientos_tiempo_real application
    where application.empresa_id =
        '38000000-0000-0000-0000-000000000010'
      and application.empleado_id =
        '38000000-0000-0000-0000-000000000087'
      and application.source_type = 'CORRECTION_CREDIT_APPLICATION'
      and application.snapshot ->> 'credit_key' =
        '38000000-0000-0000-0000-000000000089:1'
      and application.snapshot ->> 'target_journey_id' =
        '38000000-0000-0000-0000-000000000090'
  ),
  jsonb_build_object('count', 1, 'amount', 50::numeric),
  'topup mismo evento: primera ejecucion aplica 50'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2040-09-05', date '2040-09-05')
  ),
  0,
  'topup mismo evento: credito inicial oculta el saldo cero'
);
reset role;
set local role postgres;

-- El ajuste se materializa reutilizando la misma jornada y el mismo event_key.
insert into public.nomina_ajustes(
  id, empresa_id, periodo_id, empleado_id, tipo, monto, motivo,
  origen, activo, creado_por
) values (
  '38000000-0000-0000-0000-000000000187',
  '38000000-0000-0000-0000-000000000010',
  '38000000-0000-0000-0000-000000000088',
  '38000000-0000-0000-0000-000000000087',
  'INCENTIVO', 50, 'Topup tardio del mismo evento',
  'MANUAL', true, '38000000-0000-0000-0000-000000000001'
);

select is(
  (
    select jsonb_build_object(
      'count', count(*)::integer,
      'amount', round(coalesce(sum(application.monto), 0), 2),
      'events', count(distinct application.snapshot ->> 'target_event'),
      'revisions', count(distinct application.snapshot ->> 'target_revision')
    )
    from public.nomina_movimientos_tiempo_real application
    where application.empresa_id =
        '38000000-0000-0000-0000-000000000010'
      and application.empleado_id =
        '38000000-0000-0000-0000-000000000087'
      and application.source_type = 'CORRECTION_CREDIT_APPLICATION'
      and application.snapshot ->> 'credit_key' =
        '38000000-0000-0000-0000-000000000089:1'
      and application.snapshot ->> 'target_journey_id' =
        '38000000-0000-0000-0000-000000000090'
  ),
  jsonb_build_object(
    'count', 2,
    'amount', 100::numeric,
    'events', 1,
    'revisions', 1
  ),
  'topup mismo evento: segunda ejecucion completa 100 con otra identidad'
);

set local role authenticated;
select set_config(
  'request.jwt.claim.sub', '38000000-0000-0000-0000-000000000001', true
);
select is(
  pg_catalog.jsonb_array_length(
    public.listar_pagos_pendientes(date '2040-09-05', date '2040-09-05')
  ),
  0,
  'topup mismo evento: neto final cero permanece oculto'
);
reset role;
set local role postgres;

create temporary table test_0038_same_event_replay_snapshot as
select
  count(*)::integer application_count,
  pg_catalog.array_agg(application.id order by application.id)::text ids
from public.nomina_movimientos_tiempo_real application
where application.empresa_id = '38000000-0000-0000-0000-000000000010'
  and application.empleado_id = '38000000-0000-0000-0000-000000000087'
  and application.source_type = 'CORRECTION_CREDIT_APPLICATION'
  and application.snapshot ->> 'credit_key' =
    '38000000-0000-0000-0000-000000000089:1'
  and application.snapshot ->> 'target_journey_id' =
    '38000000-0000-0000-0000-000000000090';

select is(
  (
    private.devengar_movimientos_nomina_jornada(
      '38000000-0000-0000-0000-000000000010',
      '38000000-0000-0000-0000-000000000090'
    ) ->> 'inserted'
  )::integer,
  0,
  'topup mismo evento: replay completo no inserta otro delta'
);
select is(
  (
    select count(*)::integer
    from public.nomina_movimientos_tiempo_real application
    where application.empresa_id =
        '38000000-0000-0000-0000-000000000010'
      and application.empleado_id =
        '38000000-0000-0000-0000-000000000087'
      and application.source_type = 'CORRECTION_CREDIT_APPLICATION'
      and application.snapshot ->> 'credit_key' =
        '38000000-0000-0000-0000-000000000089:1'
      and application.snapshot ->> 'target_journey_id' =
        '38000000-0000-0000-0000-000000000090'
  ),
  (select application_count from test_0038_same_event_replay_snapshot),
  'topup mismo evento: replay conserva dos aplicaciones'
);
select is(
  (
    select pg_catalog.array_agg(application.id order by application.id)::text
    from public.nomina_movimientos_tiempo_real application
    where application.empresa_id =
        '38000000-0000-0000-0000-000000000010'
      and application.empleado_id =
        '38000000-0000-0000-0000-000000000087'
      and application.source_type = 'CORRECTION_CREDIT_APPLICATION'
      and application.snapshot ->> 'credit_key' =
        '38000000-0000-0000-0000-000000000089:1'
      and application.snapshot ->> 'target_journey_id' =
        '38000000-0000-0000-0000-000000000090'
  ),
  (select ids from test_0038_same_event_replay_snapshot),
  'topup mismo evento: replay conserva identidades append-only'
);

select * from finish();
rollback;
