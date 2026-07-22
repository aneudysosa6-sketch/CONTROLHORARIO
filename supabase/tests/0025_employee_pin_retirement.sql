begin;
select plan(30);

select has_column('public', 'empleados', 'pin_hash');
select hasnt_column('public', 'empleados', 'pin_is_employee_code');
select hasnt_column('public', 'empleados', 'pin_configured');
select has_table('public', 'employee_pin_code_verification_audit');
select hasnt_function(
  'public', 'employee_pin_matches_code_internal', array['text','text']
);
select ok(
  to_regclass('public.empleados_independent_pin_company_idx') is null,
  'el indice de alias PIN fue retirado'
);
select ok(
  col_description(
    'public.empleados'::regclass,
    (select attnum from pg_attribute
     where attrelid = 'public.empleados'::regclass and attname = 'pin_hash')
  ) like 'DEPRECATED:%',
  'pin_hash queda documentado solo como compatibilidad deprecated'
);
select ok(
  not has_column_privilege(
    'authenticated', 'public.empleados', 'pin_hash', 'select'
  ),
  'authenticated no puede leer el hash historico'
);
select ok(
  not has_column_privilege('anon', 'public.empleados', 'pin_hash', 'select'),
  'anon no puede leer el hash historico'
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
  'public', 'allocate_next_employee_code_internal', array['uuid','uuid'],
  'service_role', array['EXECUTE']
);
select function_privs_are(
  'public', 'allocate_next_employee_code_internal', array['uuid','uuid'],
  'authenticated', array[]::text[]
);

select ok(
  position(
    'pin_' in lower(pg_get_functiondef('public.normalizar_empleado()'::regprocedure))
  ) = 0
  and position(
    'crypt(' in lower(pg_get_functiondef('public.normalizar_empleado()'::regprocedure))
  ) = 0,
  'el normalizador no consulta ni deriva PIN'
);
select ok(
  position(
    'pin_' in lower(pg_get_functiondef(
      'public.claim_next_employee_code_internal(uuid,uuid,text)'::regprocedure
    ))
  ) = 0
  and position(
    'crypt(' in lower(pg_get_functiondef(
      'public.claim_next_employee_code_internal(uuid,uuid,text)'::regprocedure
    ))
  ) = 0,
  'claim depende solo de secuencia y registry'
);
select ok(
  position(
    'pin_' in lower(pg_get_functiondef(
      'public.preview_next_employee_code_internal(uuid)'::regprocedure
    ))
  ) = 0
  and position(
    'crypt(' in lower(pg_get_functiondef(
      'public.preview_next_employee_code_internal(uuid)'::regprocedure
    ))
  ) = 0,
  'preview no usa PIN ni hashes'
);
select ok(
  position(
    'pin_' in lower(pg_get_functiondef(
      'public.allocate_next_employee_code_internal(uuid,uuid)'::regprocedure
    ))
  ) = 0
  and position(
    'crypt(' in lower(pg_get_functiondef(
      'public.allocate_next_employee_code_internal(uuid,uuid)'::regprocedure
    ))
  ) = 0,
  'allocator no usa PIN ni hashes'
);

insert into public.companies(id,name,slug) values (
  '25000000-0000-0000-0000-000000000001',
  'Empresa Sin PIN',
  'empresa-sin-pin'
);

select is(
  public.preview_next_employee_code_internal(
    '25000000-0000-0000-0000-000000000001'
  ),
  '000001',
  'preview inicia en 000001'
);
select is(
  public.allocate_next_employee_code_internal(
    '25000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000011'
  ),
  '000001',
  'Supabase reserva 000001 para el primer empleado'
);

-- Simula un hash heredado cuyo texto original coincide con el siguiente codigo.
-- Se conserva por compatibilidad, pero nunca participa en la asignacion.
insert into public.empleados(
  id,empresa_id,codigo_empleado,nombre_completo,pin_hash
) values (
  '25000000-0000-0000-0000-000000000011',
  '25000000-0000-0000-0000-000000000001',
  '000001','Empleado Legacy',
  extensions.crypt('000002',extensions.gen_salt('bf',12))
);
select is(
  public.allocate_next_employee_code_internal(
    '25000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000011'
  ),
  '000001',
  'el retry posterior al INSERT reutiliza el codigo persistido'
);
select ok(
  (select extensions.crypt('000002',pin_hash) = pin_hash
   from public.empleados
   where id = '25000000-0000-0000-0000-000000000011'),
  'el hash heredado se conserva sin convertirse en autenticacion'
);
select is(
  public.allocate_next_employee_code_internal(
    '25000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000012'
  ),
  '000002',
  'un hash heredado no bloquea ni reserva codigos'
);
insert into public.empleados(
  id,empresa_id,codigo_empleado,nombre_completo
) values (
  '25000000-0000-0000-0000-000000000012',
  '25000000-0000-0000-0000-000000000001',
  '000002','Empleado Nuevo'
);
select is(
  (select pin_hash from public.empleados
   where id = '25000000-0000-0000-0000-000000000012'),
  null,
  'un empleado nuevo no recibe pin_hash derivado'
);
select lives_ok(
  $$update public.empleados
    set codigo_empleado='000003'
    where id='25000000-0000-0000-0000-000000000012'$$,
  'cambiar el codigo no requiere ni recalcula PIN'
);
select is(
  (select pin_hash from public.empleados
   where id = '25000000-0000-0000-0000-000000000012'),
  null,
  'cambiar el codigo mantiene pin_hash nulo'
);

insert into public.employee_pin_code_verification_audit(
  empresa_id,empleado_id,original_employee_code,normalized_employee_code
) values (
  '25000000-0000-0000-0000-000000000001',
  '25000000-0000-0000-0000-000000000011',
  '000001','000001'
);
select is(
  public.preview_next_employee_code_internal(
    '25000000-0000-0000-0000-000000000001'
  ),
  '000004',
  'una revision PIN historica no bloquea el namespace'
);
select is(
  public.allocate_next_employee_code_internal(
    '25000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000013'
  ),
  '000004',
  'allocator reserva el siguiente codigo pese a auditoria PIN historica'
);
select is(
  public.allocate_next_employee_code_internal(
    '25000000-0000-0000-0000-000000000001',
    '25000000-0000-0000-0000-000000000013'
  ),
  '000004',
  'el retry con el mismo UUID conserva la reserva idempotente'
);

delete from public.empleados
where id = '25000000-0000-0000-0000-000000000011';
select is(
  public.preview_next_employee_code_internal(
    '25000000-0000-0000-0000-000000000001'
  ),
  '000005',
  'retirar PIN no altera la regla de no reutilizacion'
);

select * from finish();
rollback;
