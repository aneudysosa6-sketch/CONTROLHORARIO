begin;
select plan(30);

select has_table('public','nomina_periodos');
select has_table('public','nominas');
select has_table('public','nomina_detalles');
select has_table('public','nomina_descuentos');
select has_table('public','nomina_prestamos');
select has_table('public','nomina_creditos');
select has_table('public','nomina_ajustes');
select has_table('public','nomina_auditoria');
select has_table('public','nomina_archivos');
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
select has_trigger('public','jornadas','jornadas_dirty_payroll_rc4');

select * from finish();
rollback;
