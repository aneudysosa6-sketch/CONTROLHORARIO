begin;
select plan(25);

select has_table('public', 'face_first_enrollment_audit');
select has_function('public', 'initial_face_enrollment_internal', array['jsonb']);
select function_privs_are(
  'public', 'initial_face_enrollment_internal', array['jsonb'],
  'authenticated', array[]::text[]
);
select function_privs_are(
  'public', 'initial_face_enrollment_internal', array['jsonb'],
  'service_role', array['EXECUTE']
);
select ok(
  not has_table_privilege('authenticated', 'public.face_first_enrollment_audit', 'select'),
  'authenticated no puede leer la auditoria facial'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'face_first_enrollment_audit'
      and column_name in ('face_embedding', 'embedding', 'pin', 'pin_hash', 'photo', 'foto', 'foto_url', 'payload', 'detalle')
  ),
  0::bigint,
  'la auditoria no tiene columnas biometricas, PIN, foto ni payload libre'
);

insert into public.companies(id, name, slug)
values ('23000000-0000-0000-0000-000000000001', 'Empresa Face First', 'empresa-face-first');

insert into public.branches(id, company_id, name, code) values
  ('23000000-0000-0000-0000-000000000011', '23000000-0000-0000-0000-000000000001', 'Sucursal Uno', 'FACE_1'),
  ('23000000-0000-0000-0000-000000000012', '23000000-0000-0000-0000-000000000001', 'Sucursal Dos', 'FACE_2');

insert into public.dispositivos_android(
  id, empresa_id, sucursal_id, nombre, modelo, android_version,
  app_version, instalacion_id, public_key_spki, estado
) values (
  '23000000-0000-0000-0000-000000000021',
  '23000000-0000-0000-0000-000000000001',
  '23000000-0000-0000-0000-000000000011',
  'Telefono prueba', 'Modelo prueba', '14', '1.0',
  '23000000-0000-0000-0000-000000000022', 'test-public-key', 'activo'
);

-- Este contrato prueba biometria, no el allocator. Reserva el prefijo historico
-- del fixture para que sus altas sigan pasando por el claim monotono de 0024.
insert into public.employee_code_sequences(empresa_id,last_value)
values('23000000-0000-0000-0000-000000000001',23000)
on conflict(empresa_id) do update set last_value=excluded.last_value;

insert into public.empleados(
  id, empresa_id, sucursal_id, codigo_empleado, nombre_completo,
  activo, estado_laboral, jornada_habilitada, face_embedding
) values
  ('23000000-0000-0000-0000-000000000031', '23000000-0000-0000-0000-000000000001', '23000000-0000-0000-0000-000000000011', '023001', 'Elegible Face', true, 'activo', true, null),
  ('23000000-0000-0000-0000-000000000032', '23000000-0000-0000-0000-000000000001', '23000000-0000-0000-0000-000000000011', '023002', 'Face Existente', true, 'activo', true, (select jsonb_agg(0.5) from generate_series(1,128))),
  ('23000000-0000-0000-0000-000000000033', '23000000-0000-0000-0000-000000000001', '23000000-0000-0000-0000-000000000012', '023003', 'Otra Sucursal', true, 'activo', true, null),
  ('23000000-0000-0000-0000-000000000034', '23000000-0000-0000-0000-000000000001', '23000000-0000-0000-0000-000000000011', '023004', 'Empleado Inactivo', false, 'desvinculado', true, null),
  ('23000000-0000-0000-0000-000000000035', '23000000-0000-0000-0000-000000000001', '23000000-0000-0000-0000-000000000011', '023005', 'Jornada Deshabilitada', true, 'activo', false, null);

select is(
  public.initial_face_enrollment_internal(jsonb_build_object(
    'company_id', '23000000-0000-0000-0000-000000000001',
    'device_id', '23000000-0000-0000-0000-000000000021',
    'employee_id', '23000000-0000-0000-0000-000000000031',
    'employee_code', '023001',
    'idempotency_key', '23000000-0000-4000-8000-000000000041',
    'validation_mode', 'ONLINE_VERIFIED',
    'occurred_at', now() - interval '2 hours',
    'face_embedding', (select jsonb_agg(n::numeric / 1000) from generate_series(1,128) n)
  )) ->> 'result',
  'accepted',
  'acepta el primer rostro valido'
);
select is(
  (select jsonb_array_length(face_embedding) from public.empleados where codigo_empleado = '023001'),
  128,
  'persiste exactamente 128 elementos'
);
select is(
  public.initial_face_enrollment_internal(jsonb_build_object(
    'company_id', '23000000-0000-0000-0000-000000000001',
    'device_id', '23000000-0000-0000-0000-000000000021',
    'employee_id', '23000000-0000-0000-0000-000000000031',
    'employee_code', '023001',
    'idempotency_key', '23000000-0000-4000-8000-000000000041',
    'validation_mode', 'ONLINE_VERIFIED',
    'occurred_at', now(),
    'face_embedding', (select jsonb_agg(0.9) from generate_series(1,128))
  )) ->> 'result',
  'duplicate',
  'un reintento idempotente no reemplaza el rostro'
);
select is(
  public.initial_face_enrollment_internal(jsonb_build_object(
    'company_id', '23000000-0000-0000-0000-000000000001',
    'device_id', '23000000-0000-0000-0000-000000000021',
    'employee_id', '23000000-0000-0000-0000-000000000032',
    'employee_code', '023002',
    'idempotency_key', '23000000-0000-4000-8000-000000000041',
    'validation_mode', 'ONLINE_VERIFIED',
    'occurred_at', now(),
    'face_embedding', (select jsonb_agg(0.9) from generate_series(1,128))
  )) ->> 'error_code',
  'IDEMPOTENCY_KEY_REUSED',
  'una clave idempotente no puede reutilizarse para otro empleado'
);
select is(
  public.initial_face_enrollment_internal(jsonb_build_object(
    'company_id', '23000000-0000-0000-0000-000000000001',
    'device_id', '23000000-0000-0000-0000-000000000021',
    'employee_id', '23000000-0000-0000-0000-000000000032',
    'employee_code', '023002',
    'idempotency_key', '23000000-0000-4000-8000-000000000042',
    'validation_mode', 'ONLINE_VERIFIED',
    'occurred_at', now(),
    'face_embedding', (select jsonb_agg(0.9) from generate_series(1,128))
  )) ->> 'error_code',
  'FACE_ALREADY_REGISTERED',
  'rechaza un remoto que ya tiene rostro'
);
select is(
  (select face_embedding ->> 0 from public.empleados where codigo_empleado = '023002'),
  '0.5',
  'el rechazo conserva el embedding remoto original'
);
select is(
  public.initial_face_enrollment_internal(jsonb_build_object(
    'company_id', '23000000-0000-0000-0000-000000000001',
    'device_id', '23000000-0000-0000-0000-000000000021',
    'employee_id', '23000000-0000-0000-0000-000000000032',
    'employee_code', '023003',
    'idempotency_key', '23000000-0000-4000-8000-000000000049',
    'validation_mode', 'ONLINE_VERIFIED',
    'occurred_at', now(),
    'face_embedding', (select jsonb_agg(0.7) from generate_series(1,128))
  )) ->> 'error_code',
  'EMPLOYEE_CHANGED',
  'rechaza cuando remote_id y employee_code ya no identifican la misma fila'
);
select ok(
  exists (
    select 1 from public.face_first_enrollment_audit
    where idempotency_key = '23000000-0000-4000-8000-000000000049'
      and outcome = 'EMPLOYEE_CHANGED'
  ),
  'audita la identidad remota cambiada sin registrar el rostro'
);
select is(
  public.initial_face_enrollment_internal(jsonb_build_object(
    'company_id', '23000000-0000-0000-0000-000000000001',
    'device_id', '23000000-0000-0000-0000-000000000021',
    'employee_id', '23000000-0000-0000-0000-000000000033',
    'employee_code', '023003',
    'idempotency_key', '23000000-0000-4000-8000-000000000043',
    'validation_mode', 'ONLINE_VERIFIED',
    'occurred_at', now(),
    'face_embedding', (select jsonb_agg(0.1) from generate_series(1,128))
  )) ->> 'error_code',
  'BRANCH_MISMATCH',
  'valida la sucursal del dispositivo'
);
update public.dispositivos_android
set sucursal_id = null
where id = '23000000-0000-0000-0000-000000000021';
select is(
  public.initial_face_enrollment_internal(jsonb_build_object(
    'company_id', '23000000-0000-0000-0000-000000000001',
    'device_id', '23000000-0000-0000-0000-000000000021',
    'employee_id', '23000000-0000-0000-0000-000000000033',
    'employee_code', '023003',
    'idempotency_key', '23000000-0000-4000-8000-000000000047',
    'validation_mode', 'OFFLINE_CACHED',
    'occurred_at', now() - interval '180 days',
    'face_embedding', (select jsonb_agg(0.2) from generate_series(1,128))
  )) ->> 'result',
  'accepted',
  'un dispositivo sin sucursal conserva alcance de empresa completa'
);
select is(
  (
    select validation_mode || '|' || (occurred_at = now() - interval '180 days')::text
    from public.face_first_enrollment_audit
    where idempotency_key = '23000000-0000-4000-8000-000000000047'
  ),
  'OFFLINE_CACHED|true',
  'conserva modo offline y hora original aunque el outbox sea antiguo'
);
select is(
  public.initial_face_enrollment_internal(jsonb_build_object(
    'company_id', '23000000-0000-0000-0000-000000000001',
    'device_id', '23000000-0000-0000-0000-000000000021',
    'employee_id', '23000000-0000-0000-0000-000000000034',
    'employee_code', '023004',
    'idempotency_key', '23000000-0000-4000-8000-000000000044',
    'validation_mode', 'ONLINE_VERIFIED',
    'occurred_at', now(),
    'face_embedding', (select jsonb_agg(0.1) from generate_series(1,128))
  )) ->> 'error_code',
  'EMPLOYEE_INACTIVE',
  'rechaza empleados inactivos'
);
select is(
  public.initial_face_enrollment_internal(jsonb_build_object(
    'company_id', '23000000-0000-0000-0000-000000000001',
    'device_id', '23000000-0000-0000-0000-000000000021',
    'employee_id', '23000000-0000-0000-0000-000000000035',
    'employee_code', '023005',
    'idempotency_key', '23000000-0000-4000-8000-000000000045',
    'validation_mode', 'ONLINE_VERIFIED',
    'occurred_at', now(),
    'face_embedding', (select jsonb_agg(0.1) from generate_series(1,128))
  )) ->> 'error_code',
  'JOURNEY_DISABLED',
  'rechaza empleados sin jornada habilitada'
);
select is(
  public.initial_face_enrollment_internal(jsonb_build_object(
    'company_id', '23000000-0000-0000-0000-000000000001',
    'device_id', '23000000-0000-0000-0000-000000000021',
    'employee_id', '23000000-0000-0000-0000-000000000035',
    'employee_code', '023005',
    'idempotency_key', '23000000-0000-4000-8000-000000000046',
    'validation_mode', 'ONLINE_VERIFIED',
    'occurred_at', now(),
    'face_embedding', (select jsonb_agg(case when n = 128 then to_jsonb('invalid'::text) else to_jsonb(0.1) end) from generate_series(1,128) n)
  )) ->> 'error_code',
  'INVALID_PAYLOAD',
  'rechaza una dimension con valores no numericos'
);
select is(
  public.initial_face_enrollment_internal(jsonb_build_object(
    'company_id', '23000000-0000-0000-0000-000000000001',
    'device_id', '23000000-0000-0000-0000-000000000021',
    'employee_id', '23000000-0000-0000-0000-000000000035',
    'employee_code', '023005',
    'idempotency_key', '23000000-0000-4000-8000-000000000048',
    'validation_mode', 'ONLINE_VERIFIED',
    'occurred_at', now() + interval '1 day',
    'face_embedding', (select jsonb_agg(0.1) from generate_series(1,128))
  )) ->> 'error_code',
  'INVALID_PAYLOAD',
  'rechaza una hora de registro futura no razonable'
);
select ok(
  exists (
    select 1 from public.face_first_enrollment_audit
    where employee_code = '023001'
      and event_name = 'FACE_FIRST_ENROLLMENT'
      and outcome = 'ENROLLED'
  ),
  'audita el registro inicial aceptado'
);
select ok(
  exists (
    select 1 from public.face_first_enrollment_audit
    where employee_code = '023002'
      and event_name = 'FACE_FIRST_ENROLLMENT'
      and outcome = 'FACE_ALREADY_REGISTERED'
  ),
  'audita una carrera o rostro remoto preexistente'
);
select is(
  (
    select responsible_user || '|' || (occurred_at = now() - interval '2 hours')::text
    from public.face_first_enrollment_audit
    where idempotency_key = '23000000-0000-4000-8000-000000000041'
  ),
  'EMPLOYEE_SELF_SERVICE|true',
  'audita responsable y hora real sin datos biometricos'
);
select is(
  (
    select count(*) from public.employee_upload_idempotency
    where empresa_id = '23000000-0000-0000-0000-000000000001'
      and idempotency_key = '23000000-0000-4000-8000-000000000041'
  ),
  1::bigint,
  'la aceptacion y su idempotencia quedan en una sola transaccion'
);

select * from finish();
rollback;
