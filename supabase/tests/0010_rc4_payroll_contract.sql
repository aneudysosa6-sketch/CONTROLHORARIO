begin;
select plan(30);

select ok(to_regclass('public.nomina_periodos') is not null,'nomina_periodos');
select ok(to_regclass('public.nominas') is not null,'nominas');
select ok(to_regclass('public.nomina_detalles') is not null,'nomina_detalles');
select ok(to_regclass('public.nomina_descuentos') is not null,'nomina_descuentos');
select ok(to_regclass('public.nomina_prestamos') is not null,'nomina_prestamos');
select ok(to_regclass('public.nomina_creditos') is not null,'nomina_creditos');
select ok(to_regclass('public.nomina_ajustes') is not null,'nomina_ajustes');
select ok(to_regclass('public.nomina_auditoria') is not null,'nomina_auditoria');
select ok(to_regclass('public.nomina_archivos') is not null,'nomina_archivos');
select has_function('public','crear_periodo_nomina',array['date','date','text']);
select has_function('public','configurar_regla_nomina',array['uuid','jsonb','text']);
select has_function('public','calcular_nomina',array['uuid']);
select has_function('public','cambiar_estado_nomina',array['uuid','text','text']);
select has_function('public','aplicar_descuentos_nomina',array['uuid','jsonb','text','text']);
select has_function('public','crear_prestamo_nomina',array['uuid','numeric','numeric','date','text']);
select has_function('public','cambiar_estado_prestamo_nomina',array['uuid','text','text']);
select has_function('public','crear_credito_nomina',array['uuid','numeric','numeric','date','text']);
select has_function('public','cancelar_credito_nomina',array['uuid','text']);
select has_function('public','listar_nomina_periodos',array[]::text[]);
select has_function('public','listar_empleados_nomina',array[]::text[]);
select has_function('public','obtener_reglas_nomina',array[]::text[]);
select has_function('public','obtener_nomina',array['uuid']);
select has_function('public','registrar_exportacion_nomina',array['uuid','text','text','jsonb']);
select ok((select bool_and(relrowsecurity) from pg_class where oid in(
 'public.nomina_periodos'::regclass,'public.nominas'::regclass,'public.nomina_detalles'::regclass,'public.nomina_descuentos'::regclass,'public.nomina_prestamos'::regclass,'public.nomina_creditos'::regclass,'public.nomina_ajustes'::regclass,'public.nomina_auditoria'::regclass,'public.nomina_archivos'::regclass
)),'RLS activo en todas las tablas RC4');
select is((select count(*)::integer from public.permisos where codigo in('nomina.ver','nomina.generar','nomina.editar','nomina.aprobar','nomina.cerrar','nomina.anular','nomina.exportar','nomina.prestamos','nomina.creditos','nomina.descuentos')),10,'catálogo RC4 completo');
select is((select count(*)::integer from public.rol_permisos rp join public.roles r on r.id=rp.rol_id join public.permisos p on p.id=rp.permiso_id where r.code='supervisor' and p.codigo like 'nomina.%' and rp.permitido),0,'supervisor bloqueado por defecto');
select col_is_unique('public','nomina_periodos',array['empresa_id','fecha_inicio','fecha_fin','tipo_periodo']);
select col_is_unique('public','nominas',array['empresa_id','periodo_id']);
select col_is_unique('public','nomina_detalles',array['empresa_id','nomina_id','empleado_id']);
select ok(exists(select 1 from pg_trigger where tgrelid='public.jornadas'::regclass and tgname='jornadas_dirty_payroll_rc4' and not tgisinternal),'jornadas_dirty_payroll_rc4');

select * from finish();
rollback;
