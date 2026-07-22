begin;
select plan(69);

select has_table('public', 'employee_code_normalization_audit');
select has_table('public', 'employee_code_registry');
select has_table('public', 'employee_code_sequences');
select has_table('public', 'face_first_enrollment_code_normalization_audit');
select has_table('public', 'employee_pin_code_verification_audit');
select has_column('public', 'employee_code_normalization_audit', 'pin_strategy');
select hasnt_column('public', 'empleados', 'pin_is_employee_code');
select hasnt_column('public', 'empleados', 'pin_configured');
select has_trigger(
  'public', 'empleados', 'empleados_sync_code_to_profile_after_write'
);
select has_trigger(
  'public', 'profiles', 'profiles_employee_code_canonical_before_write'
);
select has_trigger(
  'public', 'profiles', 'profiles_register_code_after_write'
);
select has_function(
  'public', 'preview_next_employee_code_internal', array['uuid']
);
select has_function(
  'public', 'allocate_next_employee_code_internal', array['uuid','uuid']
);
select has_function(
  'public', 'claim_next_employee_code_internal', array['uuid','uuid','text']
);
select function_privs_are(
  'public', 'preview_next_employee_code_internal', array['uuid'],
  'authenticated', array[]::text[]
);
select function_privs_are(
  'public', 'preview_next_employee_code_internal', array['uuid'],
  'service_role', array['EXECUTE']
);
select ok(
  not has_table_privilege('service_role', 'public.employee_code_registry', 'update'),
  'service_role no puede alterar el registro permanente directamente'
);
select ok(
  not has_table_privilege('service_role', 'public.employee_code_sequences', 'update'),
  'service_role no puede reducir el contador directamente'
);
select ok(
  not has_table_privilege(
    'service_role', 'public.employee_code_normalization_audit', 'update'
  ),
  'service_role no puede reescribir la auditoria de normalizacion'
);
select ok(
  not has_column_privilege(
    'authenticated', 'public.profiles', 'employee_code', 'update'
  ),
  'authenticated no puede desviar directamente el codigo del profile'
);
select ok(
  not has_table_privilege('authenticated', 'public.profiles', 'insert'),
  'authenticated no puede insertar profiles fuera del RPC confiable'
);
select ok(
  not has_table_privilege('authenticated', 'public.profiles', 'update'),
  'authenticated no puede actualizar profiles fuera del RPC confiable'
);
select ok(
  not has_column_privilege(
    'authenticated', 'public.empleados', 'pin_hash', 'select'
  ),
  'authenticated no puede leer el hash del PIN'
);
select ok(
  not has_column_privilege(
    'authenticated', 'public.empleados', 'face_embedding', 'select'
  ),
  'authenticated no puede leer el embedding facial directamente'
);
select ok(
  not has_column_privilege(
    'anon', 'public.empleados', 'pin_hash', 'select'
  ),
  'anon tampoco puede leer el hash del PIN'
);
select ok(
  not has_table_privilege(
    'authenticated', 'public.employee_pin_code_verification_audit', 'select'
  ),
  'authenticated no puede leer la revision de PIN Argon2'
);
select function_privs_are(
  'public', 'allocate_next_employee_code_internal', array['uuid','uuid'],
  'authenticated', array[]::text[]
);
select function_privs_are(
  'public', 'allocate_next_employee_code_internal', array['uuid','uuid'],
  'service_role', array['EXECUTE']
);
select function_privs_are(
  'public', 'claim_next_employee_code_internal', array['uuid','uuid','text'],
  'authenticated', array[]::text[]
);
select function_privs_are(
  'public', 'claim_next_employee_code_internal', array['uuid','uuid','text'],
  'service_role', array['EXECUTE']
);

select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.empleados'::regclass
      and conname = 'empleados_codigo_formato'
  ) like '%[0-9]{6}%'
  and (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.empleados'::regclass
      and conname = 'empleados_codigo_formato'
  ) like '%000000%',
  'empleados exige seis digitos y excluye 000000'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_employee_code_format'
  ) like '%[0-9]{6}%'
  and (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_employee_code_format'
  ) like '%000000%',
  'profiles permite null o codigo canonico de seis digitos'
);
select ok(
  (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.face_first_enrollment_audit'::regclass
      and conname = 'face_first_enrollment_audit_employee_code_check'
  ) like '%[0-9]{6}%'
  and (
    select pg_get_constraintdef(oid)
    from pg_constraint
    where conrelid = 'public.face_first_enrollment_audit'::regclass
      and conname = 'face_first_enrollment_audit_employee_code_check'
  ) like '%000000%',
  'la auditoria facial guarda el codigo canonico'
);

insert into public.companies(id, name, slug) values
  ('24000000-0000-0000-0000-000000000001', 'Empresa Codigo Seis', 'empresa-codigo-seis'),
  ('24000000-0000-0000-0000-000000000002', 'Empresa Limite Codigo', 'empresa-limite-codigo');

select is(
  public.preview_next_employee_code_internal(
    '24000000-0000-0000-0000-000000000001'
  ),
  '000001',
  'la primera vista previa usa el formato oficial'
);
select is(
  public.allocate_next_employee_code_internal(
    '24000000-0000-0000-0000-000000000001',
    '24000000-0000-0000-0000-000000000011'
  ),
  '000001',
  'la primera reserva es monotonicamente 000001'
);

insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo
) values (
  '24000000-0000-0000-0000-000000000011',
  '24000000-0000-0000-0000-000000000001',
  '000001', 'Empleado Uno'
);

select is(
  (select codigo_empleado from public.empleados
   where id = '24000000-0000-0000-0000-000000000011'),
  '000001',
  '000001 se persiste sin perder ceros'
);
select is(
  (select pin_hash from public.empleados
   where id = '24000000-0000-0000-0000-000000000011'),
  null,
  'un alta nueva no deriva un PIN del codigo canonico'
);
select is(
  (
    select employee_id from public.employee_code_registry
    where empresa_id = '24000000-0000-0000-0000-000000000001'
      and employee_code = '000001'
  ),
  '24000000-0000-0000-0000-000000000011'::uuid,
  'el registro permanente vincula la reserva con el empleado'
);
select is(
  public.preview_next_employee_code_internal(
    '24000000-0000-0000-0000-000000000001'
  ),
  '000002',
  'la vista previa avanza despues de reservar'
);
select is(
  public.allocate_next_employee_code_internal(
    '24000000-0000-0000-0000-000000000001',
    '24000000-0000-0000-0000-000000000012'
  ),
  '000002',
  'la segunda reserva nunca repite la primera'
);
insert into public.empleados(
  id, empresa_id, codigo_empleado, nombre_completo
) values (
  '24000000-0000-0000-0000-000000000012',
  '24000000-0000-0000-0000-000000000001',
  '000002', 'Empleado Dos'
);
select is(
  (select last_value from public.employee_code_sequences
   where empresa_id = '24000000-0000-0000-0000-000000000001'),
  2,
  'el contador conserva el maximo asignado'
);

select is(
  public.allocate_next_employee_code_internal(
    '24000000-0000-0000-0000-000000000001',
    '24000000-0000-0000-0000-000000000018'
  ),
  '000003',
  'el allocator usa contador/registry y limita bcrypt al conjunto legado indexado'
);
insert into public.empleados(
  id,empresa_id,codigo_empleado,nombre_completo
) values (
  '24000000-0000-0000-0000-000000000018',
  '24000000-0000-0000-0000-000000000001',
  '000003','Empleado Tres'
);

insert into auth.users(
  id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '24000000-0000-0000-0000-000000000031',
  'authenticated','authenticated','orphan-profile@code.test','not-used',now(),
  '{}','{}',now(),now()
);
insert into public.roles(id,company_id,name,code,is_active) values (
  '24000000-0000-0000-0000-000000000032',
  '24000000-0000-0000-0000-000000000001',
  'Perfil Codigo','code_profile',true
);
-- Simula un profile huerfano existente antes de 0024. La ruta productiva ya
-- no puede crear este estado; el registry conserva su historia.
alter table public.profiles disable trigger profiles_register_code_after_write;
insert into public.profiles(
  id,company_id,role_id,employee_code,full_name,status
) values (
  '24000000-0000-0000-0000-000000000031',
  '24000000-0000-0000-0000-000000000001',
  '24000000-0000-0000-0000-000000000032',
  '000010','Perfil Huerfano','active'
);
alter table public.profiles enable trigger profiles_register_code_after_write;
insert into public.employee_code_registry(
  empresa_id,employee_code,profile_id,source,consumed_at
) values (
  '24000000-0000-0000-0000-000000000001','000010',
  '24000000-0000-0000-0000-000000000031','PROFILE_MIGRATION',now()
);
update public.employee_code_sequences
set last_value=10
where empresa_id='24000000-0000-0000-0000-000000000001';
select is(
  (
    select profile_id from public.employee_code_registry
    where empresa_id = '24000000-0000-0000-0000-000000000001'
      and employee_code = '000010'
  ),
  '24000000-0000-0000-0000-000000000031'::uuid,
  'un profile huerfano posterior tambien reserva su codigo'
);
alter table public.profiles disable trigger profiles_register_code_after_write;
update public.profiles
set employee_code = '000011'
where id = '24000000-0000-0000-0000-000000000031';
alter table public.profiles enable trigger profiles_register_code_after_write;
insert into public.employee_code_registry(
  empresa_id,employee_code,profile_id,source,consumed_at
) values (
  '24000000-0000-0000-0000-000000000001','000011',
  '24000000-0000-0000-0000-000000000031','PROFILE_MIGRATION',now()
);
update public.employee_code_sequences
set last_value=11
where empresa_id='24000000-0000-0000-0000-000000000001';
insert into auth.users(
  id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values (
  '24000000-0000-0000-0000-000000000036',
  'authenticated','authenticated','new-orphan@code.test','not-used',now(),
  '{}','{}',now(),now()
);
select throws_ok(
  $$insert into public.profiles(
      id,company_id,role_id,employee_code,full_name,status
    ) values (
      '24000000-0000-0000-0000-000000000036',
      '24000000-0000-0000-0000-000000000001',
      '24000000-0000-0000-0000-000000000032',
      '000012','Perfil Huerfano Nuevo','active'
    )$$,
  '23514', 'PROFILE_EMPLOYEE_CODE_REQUIRES_EMPLOYEE',
  'un profile nuevo no puede crear ni adelantar el namespace de empleados'
);
select throws_ok(
  $$insert into public.empleados(
      id,empresa_id,perfil_id,codigo_empleado,nombre_completo
    ) values (
      '24000000-0000-0000-0000-000000000033',
      '24000000-0000-0000-0000-000000000001',
      '24000000-0000-0000-0000-000000000031',
      '000010','Reuso Codigo Viejo Del Perfil'
    )$$,
  '23505', 'EMPLOYEE_CODE_ALREADY_USED',
  'un profile que avanzo de A a B no puede transferir A a un empleado'
);
select is(
  public.preview_next_employee_code_internal(
    '24000000-0000-0000-0000-000000000001'
  ),
  '000012',
  'el allocator no reutiliza el codigo de un profile huerfano'
);
insert into public.empleados(
  id,empresa_id,perfil_id,codigo_empleado,nombre_completo
) values (
  '24000000-0000-0000-0000-000000000033',
  '24000000-0000-0000-0000-000000000001',
  '24000000-0000-0000-0000-000000000031',
  '000011','Empleado Perfil'
);
select is(
  (
    select employee_id from public.employee_code_registry
    where empresa_id = '24000000-0000-0000-0000-000000000001'
      and employee_code = '000011'
  ),
  '24000000-0000-0000-0000-000000000033'::uuid,
  'vincular el empleado transfiere la reserva sin reutilizarla'
);
update public.empleados
set codigo_empleado = '000012'
where id = '24000000-0000-0000-0000-000000000033';
select is(
  (select employee_code from public.profiles
   where id = '24000000-0000-0000-0000-000000000031'),
  '000012',
  'cambiar el codigo del empleado sincroniza el profile vinculado'
);
update public.profiles
set employee_code = '000099'
where id = '24000000-0000-0000-0000-000000000031';
select is(
  (select employee_code from public.profiles
   where id = '24000000-0000-0000-0000-000000000031'),
  '000012',
  'un profile vinculado no puede desviarse del empleado'
);
update public.empleados
set codigo_empleado = '000013'
where id = '24000000-0000-0000-0000-000000000033';
select is(
  (select employee_code from public.profiles
   where id = '24000000-0000-0000-0000-000000000031'),
  '000013',
  'la sincronizacion del profile aplica sin depender de PIN'
);
select lives_ok(
  $$insert into public.empleados(id,empresa_id,codigo_empleado,nombre_completo)
    values(
      '24000000-0000-0000-0000-000000000034',
      '24000000-0000-0000-0000-000000000001',
      '000014','Empleado Catorce'
    )$$,
  'el siguiente codigo depende del registry, no de hashes de PIN'
);
select is(
  (select pin_hash from public.empleados
   where id = '24000000-0000-0000-0000-000000000034'),
  null,
  'un alta SQL tampoco deriva pin_hash del codigo'
);
select is(
  public.allocate_next_employee_code_internal(
    '24000000-0000-0000-0000-000000000001',
    '24000000-0000-0000-0000-000000000035'
  ),
  '000015',
  'el allocator avanza usando solo secuencia y registry'
);
select is(
  public.allocate_next_employee_code_internal(
    '24000000-0000-0000-0000-000000000001',
    '24000000-0000-0000-0000-000000000035'
  ),
  '000015',
  'reintentar el allocator con el mismo UUID devuelve su reserva pendiente'
);

delete from public.empleados
where id = '24000000-0000-0000-0000-000000000011';
select throws_ok(
  $$insert into public.empleados(id,empresa_id,codigo_empleado,nombre_completo)
    values(
      '24000000-0000-0000-0000-000000000019',
      '24000000-0000-0000-0000-000000000001',
      '000001','Intento Reutilizacion'
    )$$,
  '23505', 'EMPLOYEE_CODE_ALREADY_USED',
  'un codigo consumido no se reutiliza aunque el empleado sea borrado'
);
select throws_ok(
  $$insert into public.empleados(id,empresa_id,codigo_empleado,nombre_completo)
    values(
      '24000000-0000-0000-0000-000000000011',
      '24000000-0000-0000-0000-000000000001',
      '000001','Recreacion Mismo UUID'
    )$$,
  '23505', 'EMPLOYEE_CODE_ALREADY_USED',
  'recrear el mismo UUID tampoco recupera un codigo consumido'
);
select throws_ok(
  $$insert into public.profiles(
      id,company_id,role_id,employee_code,full_name,status
    ) values (
      '24000000-0000-0000-0000-000000000036',
      '24000000-0000-0000-0000-000000000001',
      '24000000-0000-0000-0000-000000000032',
      '000001','Perfil De Empleado Eliminado','active'
    )$$,
  '23514', 'PROFILE_EMPLOYEE_CODE_REQUIRES_EMPLOYEE',
  'un profile no puede adoptar el codigo historico de un empleado eliminado'
);
select lives_ok(
  $$update public.empleados
    set codigo_empleado='000016'
    where id='24000000-0000-0000-0000-000000000018'$$,
  'un empleado puede avanzar a un codigo nunca consumido'
);
select throws_ok(
  $$update public.empleados
    set codigo_empleado='000003'
    where id='24000000-0000-0000-0000-000000000018'$$,
  '23505', 'EMPLOYEE_CODE_ALREADY_USED',
  'un cambio A-B-A no reutiliza el codigo anterior'
);
select throws_ok(
  $$insert into public.empleados(id,empresa_id,codigo_empleado,nombre_completo)
    values(
      '24000000-0000-0000-0000-000000000022',
      '24000000-0000-0000-0000-000000000001',
      '000999','Intento Salto De Secuencia'
    )$$,
  '23505', 'EMPLOYEE_CODE_STALE_OR_USED',
  'una escritura directa no puede saltar la asignacion ascendente'
);
select throws_ok(
  $$update public.empleados
    set empresa_id='24000000-0000-0000-0000-000000000002'
    where id='24000000-0000-0000-0000-000000000012'$$,
  '23514', 'EMPLOYEE_COMPANY_IMMUTABLE',
  'un empleado no puede mover un hash o auditoria PIN a otro tenant'
);
select throws_ok(
  $$insert into public.empleados(id,empresa_id,codigo_empleado,nombre_completo)
    values(
      '24000000-0000-0000-0000-000000000014',
      '24000000-0000-0000-0000-000000000001',
      '48575','Codigo Cinco'
    )$$,
  '23514',
  'new row for relation "empleados" violates check constraint "empleados_codigo_formato"',
  'Supabase rechaza valores no normalizados de cinco digitos'
);
select throws_ok(
  $$insert into public.empleados(id,empresa_id,codigo_empleado,nombre_completo)
    values(
      '24000000-0000-0000-0000-000000000015',
      '24000000-0000-0000-0000-000000000001',
      '000000','Codigo Cero'
    )$$,
  '23514',
  'new row for relation "empleados" violates check constraint "empleados_codigo_formato"',
  '000000 no pertenece al rango oficial'
);
select throws_ok(
  $$insert into public.empleados(id,empresa_id,codigo_empleado,nombre_completo)
    values(
      '24000000-0000-0000-0000-000000000016',
      '24000000-0000-0000-0000-000000000001',
      '00A003','Codigo Letras'
    )$$,
  '23514',
  'new row for relation "empleados" violates check constraint "empleados_codigo_formato"',
  'las letras son invalidas'
);
select throws_ok(
  $$insert into public.empleados(id,empresa_id,codigo_empleado,nombre_completo)
    values(
      '24000000-0000-0000-0000-000000000017',
      '24000000-0000-0000-0000-000000000001',
      '1000000','Codigo Siete'
    )$$,
  '23514',
  'new row for relation "empleados" violates check constraint "empleados_codigo_formato"',
  'siete digitos son invalidos'
);

insert into public.employee_code_sequences(empresa_id,last_value)
values('24000000-0000-0000-0000-000000000002',999998)
on conflict(empresa_id) do update set last_value=excluded.last_value;
select lives_ok(
  $$insert into public.empleados(id,empresa_id,codigo_empleado,nombre_completo)
    values(
      '24000000-0000-0000-0000-000000000021',
      '24000000-0000-0000-0000-000000000002',
      '999999','Codigo Maximo'
    )$$,
  '999999 es valido'
);
select is(
  (select pin_hash from public.empleados
   where id = '24000000-0000-0000-0000-000000000021'),
  null,
  'el limite superior tampoco deriva PIN del codigo'
);
select is(
  (
    select count(*)
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'employee_code_normalization_audit'
      and column_name in ('pin','pin_hash','password','password_hash','credential','token')
  ),
  0::bigint,
  'la auditoria de normalizacion no almacena credenciales'
);
select ok(
  not has_table_privilege(
    'authenticated', 'public.employee_code_normalization_audit', 'select'
  ),
  'authenticated no puede leer la auditoria de normalizacion'
);

select * from finish();
rollback;
