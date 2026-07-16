begin;
select plan(17);

select ok(exists(select 1 from information_schema.columns where table_schema='public' and table_name='companies' and column_name='logo_url'),'logo_url');
select ok(exists(select 1 from information_schema.columns where table_schema='public' and table_name='companies' and column_name='address'),'address');
select ok(exists(select 1 from information_schema.columns where table_schema='public' and table_name='companies' and column_name='email'),'email');
select ok(exists(select 1 from information_schema.columns where table_schema='public' and table_name='companies' and column_name='phone'),'phone');
select ok(exists(select 1 from information_schema.columns where table_schema='public' and table_name='companies' and column_name='ui_preferences'),'ui_preferences');
select ok(exists(select 1 from information_schema.columns where table_schema='public' and table_name='branches' and column_name='timezone'),'timezone');
select ok(to_regclass('public.administracion_auditoria') is not null,'administracion_auditoria');
select has_function('public','obtener_administracion_sistema',array[]::text[]);
select has_function('public','actualizar_empresa_administracion',array['jsonb','text']);
select has_function('public','guardar_sucursal_administracion',array['uuid','jsonb','text']);
select has_function('public','guardar_departamento_administracion',array['uuid','jsonb','uuid','text']);
select has_function('public','guardar_cargo_administracion',array['uuid','jsonb','text']);
select has_function('public','actualizar_estado_usuario_administracion',array['uuid','text','text']);
select has_function('public','actualizar_apariencia_administracion',array['jsonb','text']);
select ok((select relrowsecurity from pg_class where oid='public.administracion_auditoria'::regclass),'RLS activo en auditoría administrativa');
select is((select count(*)::integer from public.permisos where codigo in('configuracion.ver','configuracion.empresa','configuracion.sucursales','configuracion.departamentos','configuracion.cargos','configuracion.horarios','configuracion.jornadas','configuracion.seguridad','configuracion.apariencia')),9,'catálogo RC3.5 completo');
select is((select count(*)::integer from public.rol_permisos rp join public.roles r on r.id=rp.rol_id join public.permisos p on p.id=rp.permiso_id where r.code='supervisor' and p.codigo like 'configuracion.%' and rp.permitido),0,'supervisor sin administración sensible por defecto');

select * from finish();
rollback;
