begin;
select plan(17);

select has_column('public','companies','logo_url');
select has_column('public','companies','address');
select has_column('public','companies','email');
select has_column('public','companies','phone');
select has_column('public','companies','ui_preferences');
select has_column('public','branches','timezone');
select has_table('public','administracion_auditoria');
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
