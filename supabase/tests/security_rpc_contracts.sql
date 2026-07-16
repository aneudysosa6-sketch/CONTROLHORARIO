begin;
select plan(16);

-- Todas las funciones SECURITY DEFINER propias deben fijar search_path y no ser ejecutables por PUBLIC.
select ok(not exists(
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in('public','private') and p.prosecdef
    and coalesce(array_to_string(p.proconfig,','),'') not like '%search_path=%'
),'SECURITY DEFINER fija search_path');
select ok(not exists(
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in('public','private') and p.prosecdef and has_function_privilege('public',p.oid,'EXECUTE')
),'SECURITY DEFINER no concede EXECUTE a PUBLIC');
select ok(not exists(
  select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public' and p.prosecdef and p.proacl is null
),'SECURITY DEFINER declara privilegios explícitos');

-- RPC redefinidas: la última firma existe, conserva SECURITY DEFINER y grants esperados.
select ok((select prosecdef from pg_proc where oid='public.puede_ver_jornada(uuid)'::regprocedure),'puede_ver_jornada final es SECURITY DEFINER');
select ok((select prosecdef from pg_proc where oid='public.calcular_nomina(uuid)'::regprocedure),'calcular_nomina final es SECURITY DEFINER');
select function_privs_are('public','puede_ver_jornada',array['uuid'],'authenticated',array['EXECUTE']);
select function_privs_are('public','calcular_nomina',array['uuid'],'authenticated',array['EXECUTE']);
select function_privs_are('public','enroll_android_device_internal',array['jsonb'],'authenticated',array[]::text[]);
select function_privs_are('public','provision_user_internal',array['jsonb'],'authenticated',array[]::text[]);

-- Tablas con datos sensibles deben tener RLS y no DML directo desde authenticated.
select ok((select bool_and(relrowsecurity) from pg_class where oid in(
 'public.empleados'::regclass,'public.jornadas'::regclass,'public.nomina_periodos'::regclass,
 'public.prestamo_solicitudes'::regclass,'public.dispositivos_android'::regclass,'public.empleado_biometrias'::regclass
)),'RLS activo en dominios sensibles');
select ok(not has_table_privilege('authenticated','public.nomina_periodos','insert'),'Nómina no concede INSERT directo');
select ok(not has_table_privilege('authenticated','public.prestamo_solicitudes','insert'),'Préstamos no concede INSERT directo');
select ok(not has_table_privilege('authenticated','public.empleado_biometrias','select'),'Template biométrico no es legible por cliente');
select ok(not has_table_privilege('authenticated','public.dispositivos_android','update'),'Dispositivos no se modifican directamente por cliente');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='empleados' and policyname='empleados_select_segun_alcance'),'Política final de empleados existe');
select ok(exists(select 1 from pg_policies where schemaname='public' and tablename='jornadas' and policyname='jornadas_select_scope'),'Política de jornadas existe');

select * from finish();
rollback;
