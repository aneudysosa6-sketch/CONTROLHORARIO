begin;
select plan(18);

select has_function('private', 'normalizar_codigo_rol', array['text']);
select has_function('public', 'obtener_mi_autorizacion', array[]::text[]);
select has_function('public', 'obtener_departamentos_supervisor_actual', array[]::text[]);
select has_function('public', 'supervisor_puede_ver_empleado', array['uuid']);
select has_function('public', 'dashboard_supervisor', array[]::text[]);
select has_function('public', 'actualizar_acceso_autorizacion_internal', array['jsonb']);

select is(private.normalizar_codigo_rol('sup'), 'SUPERVISOR', 'sup is canonicalized');
select is(private.normalizar_codigo_rol('Supervisor'), 'SUPERVISOR', 'Supervisor is canonicalized');
select is(private.normalizar_codigo_rol('employee'), 'EMPLEADO', 'employee is canonicalized');
select is(private.normalizar_codigo_rol('payroll'), 'NOMINA', 'payroll is canonicalized');
select is(private.normalizar_codigo_rol('audit'), 'AUDITOR', 'audit is canonicalized');
select is(private.normalizar_codigo_rol('admin'), 'ADMIN', 'admin is canonicalized');

select ok(
  exists(
    select 1
    from pg_trigger
    where tgrelid = 'public.profiles'::regclass
      and tgname = 'profiles_clear_authorization_after_role_change'
      and not tgisinternal
  ),
  'role change cleanup trigger exists'
);

select function_privs_are(
  'public',
  'obtener_mi_autorizacion',
  array[]::text[],
  'authenticated',
  array['EXECUTE'],
  'authenticated can load its atomic authorization'
);

select function_privs_are(
  'public',
  'actualizar_acceso_autorizacion_internal',
  array['jsonb'],
  'service_role',
  array['EXECUTE'],
  'only service role contract can update access authorization'
);

select ok(
  not has_function_privilege(
    'authenticated',
    'public.actualizar_acceso_autorizacion_internal(jsonb)',
    'EXECUTE'
  ),
  'authenticated cannot execute the internal access update'
);

select ok(
  pg_get_functiondef('public.dashboard_supervisor()'::regprocedure)
    like '%obtener_departamentos_supervisor_actual%',
  'supervisor dashboard uses the unified department scope'
);

select ok(
  pg_get_functiondef('public.obtener_mi_autorizacion()'::regprocedure)
    like '%authorization_version%',
  'atomic authorization includes its contract version'
);

select * from finish();
rollback;
