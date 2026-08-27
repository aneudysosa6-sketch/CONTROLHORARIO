begin;
set local search_path = extensions, public, pg_catalog;
set local role postgres;
select plan(35);

select has_column('public', 'dispositivos_android', 'tipo_uso', 'terminal usage type is persisted');
select has_column('public', 'dispositivos_android', 'configuracion_revision', 'terminal configuration revision is persisted');
select has_table('public', 'dispositivo_departamentos', 'terminal department scope table exists');
select has_table('public', 'dispositivo_empleados_sincronizados', 'terminal sync membership table exists');
select has_function('public', 'configurar_terminal_facial', array['uuid','uuid','text','uuid[]','text'], 'terminal configuration RPC exists');
select has_function('public', 'terminal_empleado_elegible', array['uuid','uuid','uuid'], 'server terminal eligibility exists');
select has_function('public', 'obtener_configuracion_terminal_dispositivo', array['uuid','uuid'], 'device configuration sync RPC exists');
select ok(position('d.tipo_uso = ''GENERAL''' in pg_get_functiondef('public.terminal_empleado_elegible(uuid,uuid,uuid)'::regprocedure)) > 0, 'GENERAL is explicit in server eligibility');
select ok(position('dd.departamento_id = e.departamento_id' in pg_get_functiondef('public.terminal_empleado_elegible(uuid,uuid,uuid)'::regprocedure)) > 0, 'DEPARTMENTS is checked on server');
select ok(position('e.empresa_id = d.empresa_id' in pg_get_functiondef('public.terminal_empleado_elegible(uuid,uuid,uuid)'::regprocedure)) > 0, 'terminal eligibility is company isolated');

select has_column('public', 'profiles', 'authorization_revision', 'authorization revision is persisted');
select has_function('public', 'obtener_revision_autorizacion', array[]::text[], 'authorization revision RPC exists');
select has_function('public', 'validar_autorizacion_actual', array['bigint','text','uuid'], 'authoritative guard RPC exists');
select has_trigger('public', 'perfil_permisos', 'perfil_permisos_authorization_0050', 'permission changes bump authorization');
select has_trigger('public', 'perfil_departamentos', 'perfil_departamentos_authorization_0050', 'department scope changes bump authorization');

select has_table('public', 'licencias_empleado', 'direct license root exists');
select has_table('public', 'licencias_empleado_versiones', 'license history is append only');
select has_table('public', 'licencias_empleado_dias', 'license payroll days exist');
select has_function('public', 'crear_licencia_empleado', array['uuid','date','date','numeric','text','text','uuid'], 'direct license creation RPC exists');
select has_function('public', 'modificar_licencia_empleado', array['uuid','date','date','numeric','text','text','date','text'], 'license edit RPC exists');
select has_function('public', 'cancelar_licencia_empleado', array['uuid','text'], 'license cancellation RPC exists');
select ok(position('/ 30.0' in pg_get_functiondef('private.regenerar_dias_licencia_0050(uuid,date)'::regprocedure)) > 0, 'license daily pay uses salary divided by 30');
select ok(position('generate_series' in pg_get_functiondef('private.regenerar_dias_licencia_0050(uuid,date)'::regprocedure)) > 0, 'license uses calendar days');

select has_table('public', 'nomina_jornadas_incompletas_resueltas', 'NO PAGAR resolution table exists');
select has_function('public', 'resolver_jornada_incompleta_no_pagar', array['uuid','numeric','text'], 'NO PAGAR RPC exists');
select ok(position('p_horas_manual > 8' in pg_get_functiondef('public.resolver_jornada_incompleta_no_pagar(uuid,numeric,text)'::regprocedure)) > 0, 'manual hours are capped at eight');
select ok(position('PAYROLL_PERIOD_CLOSED' in pg_get_functiondef('public.resolver_jornada_incompleta_no_pagar(uuid,numeric,text)'::regprocedure)) > 0, 'closed payroll prevents edits');

select has_table('public', 'nomina_ajustes_anteriores', 'prior adjustments table exists');
select has_trigger('public', 'nomina_resoluciones_diarias', 'capture_prior_adjustment_0050', 'closed-period corrections create adjustments');
select has_function('public', 'calcular_nomina_p0', array['uuid'], 'payroll wrapper applies prior adjustments');
select ok(position('estado = ''APLICADO''' in pg_get_functiondef('private.complete_prior_adjustments_0050()'::regprocedure)) > 0, 'adjustments become applied on payroll closure');

select has_table('public', 'lista_negra_mensual', 'monthly blacklist tracking exists');
select has_function('public', 'refrescar_lista_negra_mensual', array['integer','integer'], 'monthly blacklist refresh exists');
select has_function('public', 'reporte_lista_negra_empleado', array['uuid','integer','integer'], 'individual blacklist report exists');
select ok(position('public.terminal_empleado_elegible' in pg_get_functiondef('public.obtener_mensajes_pendientes_dispositivo(uuid,uuid)'::regprocedure)) > 0, 'offline message preload respects terminal eligibility');

select * from finish();
rollback;
