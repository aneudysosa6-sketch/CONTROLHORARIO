begin;
set local search_path = extensions, public, pg_catalog;
set local role postgres;
select * from no_plan();

insert into auth.users(
  id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
 ('54540000-0000-0000-0000-000000000001','authenticated','authenticated','admin@p0-finance.test','x',now(),'{}','{}',now(),now()),
 ('54540000-0000-0000-0000-000000000002','authenticated','authenticated','backup@p0-finance.test','x',now(),'{}','{}',now(),now());

insert into public.companies(id,name,slug)
values ('54540000-0000-0000-0000-000000000010','P0 Finance Company','p0-finance-company');
insert into public.roles(id,company_id,name,code,is_active)
values ('54540000-0000-0000-0000-000000000011','54540000-0000-0000-0000-000000000010','P0 Finance Admin','admin',true);
insert into public.branches(id,company_id,name,code,is_main)
values ('54540000-0000-0000-0000-000000000020','54540000-0000-0000-0000-000000000010','P0 Main','P0-FIN',true);
insert into public.departments(id,company_id,branch_id,name,code)
values ('54540000-0000-0000-0000-000000000030','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000020','P0 Payroll','P0-PAY');
insert into public.employee_code_sequences(empresa_id,last_value)
values ('54540000-0000-0000-0000-000000000010',545400)
on conflict(empresa_id) do update set last_value=excluded.last_value;
insert into public.empleados(
  id,empresa_id,sucursal_id,departamento_id,codigo_empleado,nombre_completo,
  activo,estado_laboral,jornada_habilitada,salario,
  fecha_desvinculacion,motivo_desvinculacion
) values (
 '54540000-0000-0000-0000-000000000201','54540000-0000-0000-0000-000000000010',
 '54540000-0000-0000-0000-000000000020','54540000-0000-0000-0000-000000000030',
 '545401','P0 Finance Employee',true,'activo',true,24000,null,null
);
insert into public.profiles(id,company_id,role_id,employee_code,full_name,status) values
 ('54540000-0000-0000-0000-000000000001','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000011','545401','P0 Finance Admin','active'),
 ('54540000-0000-0000-0000-000000000002','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000011',null,'P0 Finance Backup','active');
update public.empleados
set perfil_id='54540000-0000-0000-0000-000000000001'
where id='54540000-0000-0000-0000-000000000201';
insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select '54540000-0000-0000-0000-000000000011',p.id,true,'empresa'
from public.permisos p
where p.codigo in(
  'licencias.gestionar','nomina.no_pagar','nomina.ajustes_anteriores',
  'lista_negra.ver','kiosk.face_mode_manage','dispositivos.registrar'
)
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';
insert into public.dispositivos_android(
 id,empresa_id,sucursal_id,nombre,modelo,android_version,app_version,
 instalacion_id,public_key_spki,estado
) values (
 '54540000-0000-0000-0000-000000000401','54540000-0000-0000-0000-000000000010',
 '54540000-0000-0000-0000-000000000020','P0 Finance Terminal','P0','14','1.0',
 '54540000-0000-0000-0000-000000000411','p0-finance-key','activo'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','54540000-0000-0000-0000-000000000001',true);
select lives_ok(
 $$select public.configurar_terminal_facial(
   '54540000-0000-0000-0000-000000000401',
   '54540000-0000-0000-0000-000000000020','GENERAL','{}'::uuid[],'P0 finance general'
 )$$,
 'GENERAL terminal is configured for the finance fixture'
);
set local role postgres;
select ok(public.terminal_empleado_elegible(
 '54540000-0000-0000-0000-000000000010',
 '54540000-0000-0000-0000-000000000401',
 '54540000-0000-0000-0000-000000000201'
),'employee is initially eligible at the terminal');

create temporary table p0_finance_state(license_id uuid) on commit drop;
grant select on p0_finance_state to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub','54540000-0000-0000-0000-000000000001',true);
select lives_ok(
 $$select public.crear_licencia_empleado(
   '54540000-0000-0000-0000-000000000201',current_date,current_date+2,50,
   'p0/license.pdf','P0 create','54540000-0000-4000-8000-000000000501'
 )$$,
 'license creation succeeds'
);
set local role postgres;
insert into p0_finance_state(license_id)
select id from public.licencias_empleado
where empresa_id='54540000-0000-0000-0000-000000000010'
  and idempotency_key='54540000-0000-4000-8000-000000000501';
select is((select count(*)::integer from public.licencias_empleado_dias
 where licencia_id=(select license_id from p0_finance_state)),3,'license uses all calendar days');
select is((select sum(monto) from public.licencias_empleado_dias
 where licencia_id=(select license_id from p0_finance_state)),1200.00::numeric,'license amount is salary divided by 30 times percentage');
select ok(not public.terminal_empleado_elegible(
 '54540000-0000-0000-0000-000000000010',
 '54540000-0000-0000-0000-000000000401',
 '54540000-0000-0000-0000-000000000201'
),'active license immediately blocks terminal eligibility');
set local role authenticated;
select set_config('request.jwt.claim.sub','54540000-0000-0000-0000-000000000001',true);
select lives_ok(
 $$select public.crear_licencia_empleado(
   '54540000-0000-0000-0000-000000000201',current_date,current_date+2,50,
   'p0/license.pdf','P0 create','54540000-0000-4000-8000-000000000501'
 )$$,
 'license creation retry is idempotent'
);
set local role postgres;
select is((select count(*)::integer from public.licencias_empleado
 where empresa_id='54540000-0000-0000-0000-000000000010'),1,'idempotent retry keeps one license root');
set local role authenticated;
select set_config('request.jwt.claim.sub','54540000-0000-0000-0000-000000000001',true);
select lives_ok(
 $$select public.modificar_licencia_empleado(
   (select license_id from p0_finance_state),current_date,current_date+2,25,
   'p0/license-v2.pdf','HACIA_ADELANTE',current_date+1,'P0 forward edit'
 )$$,
 'forward license edit succeeds'
);
set local role postgres;
select is((select revision_actual from public.licencias_empleado
 where id=(select license_id from p0_finance_state)),2,'license edit appends revision two');
select is((select count(*)::integer from public.licencias_empleado_versiones
 where licencia_id=(select license_id from p0_finance_state)),2,'license history remains append only');
select is((select sum(monto) from public.licencias_empleado_dias
 where licencia_id=(select license_id from p0_finance_state)),800.00::numeric,'forward edit preserves the first day and recalculates later days');
select is((select monto from public.licencias_empleado_dias
 where licencia_id=(select license_id from p0_finance_state) and fecha=current_date),400.00::numeric,'forward edit preserves prior daily amount');
select is((select count(*)::integer from public.licencias_empleado_dias
 where licencia_id=(select license_id from p0_finance_state) and fecha>current_date and revision=2 and monto=200),2,'forward edit regenerates later days at revision two');
set local role authenticated;
select set_config('request.jwt.claim.sub','54540000-0000-0000-0000-000000000001',true);
select lives_ok(
 $$select public.cancelar_licencia_empleado((select license_id from p0_finance_state),'P0 cancellation')$$,
 'license cancellation succeeds'
);
set local role postgres;
select is((select estado from public.licencias_empleado
 where id=(select license_id from p0_finance_state)),'CANCELADA','license is cancelled');
select is((select count(*)::integer from public.licencias_empleado_dias
 where licencia_id=(select license_id from p0_finance_state)),0,'cancellation removes payable license days');
select ok(public.terminal_empleado_elegible(
 '54540000-0000-0000-0000-000000000010',
 '54540000-0000-0000-0000-000000000401',
 '54540000-0000-0000-0000-000000000201'
),'cancellation immediately restores terminal eligibility');

insert into public.jornadas(
 id,empresa_id,empleado_id,fecha_laboral,estado,iniciado_en,
 pausa_iniciada_en,minutos_trabajados,minutos_pausa,origen,revision_pendiente
) values
 ('54540000-0000-0000-0000-000000000601','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','2022-04-01','EN_CURSO','2022-04-01 08:00+00',null,0,0,'WEB',true),
 ('54540000-0000-0000-0000-000000000602','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','2022-04-02','EN_CURSO','2022-04-02 08:00+00',null,0,0,'WEB',true),
 ('54540000-0000-0000-0000-000000000603','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','2022-04-03','EN_PAUSA','2022-04-03 08:00+00','2022-04-03 18:30+00',0,0,'WEB',true),
 ('54540000-0000-0000-0000-000000000604','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','2022-04-04','EN_CURSO','2022-04-04 08:00+00',null,600,30,'WEB',true);
insert into public.jornada_eventos(
 id,jornada_id,empresa_id,empleado_id,accion,ocurrido_en,idempotency_key,payload,origen
) values
 ('54540000-0000-0000-0000-000000000701','54540000-0000-0000-0000-000000000601','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','INICIAR','2022-04-01 08:00+00','54540000-0000-4000-8000-000000000801','{"biometric_verified":true}','WEB'),
 ('54540000-0000-0000-0000-000000000702','54540000-0000-0000-0000-000000000602','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','INICIAR','2022-04-02 08:00+00','54540000-0000-4000-8000-000000000802','{"biometric_verified":true}','WEB'),
 ('54540000-0000-0000-0000-000000000703','54540000-0000-0000-0000-000000000603','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','INICIAR','2022-04-03 08:00+00','54540000-0000-4000-8000-000000000803','{"biometric_verified":true}','WEB'),
 ('54540000-0000-0000-0000-000000000704','54540000-0000-0000-0000-000000000603','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','PAUSAR','2022-04-03 18:30+00','54540000-0000-4000-8000-000000000804','{"biometric_verified":true}','WEB'),
 ('54540000-0000-0000-0000-000000000705','54540000-0000-0000-0000-000000000604','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','INICIAR','2022-04-04 08:00+00','54540000-0000-4000-8000-000000000805','{"biometric_verified":true}','WEB'),
 ('54540000-0000-0000-0000-000000000706','54540000-0000-0000-0000-000000000604','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','PAUSAR','2022-04-04 12:00+00','54540000-0000-4000-8000-000000000806','{"biometric_verified":true}','WEB'),
 ('54540000-0000-0000-0000-000000000707','54540000-0000-0000-0000-000000000604','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','REANUDAR','2022-04-04 12:30+00','54540000-0000-4000-8000-000000000807','{"biometric_verified":true}','WEB');
set local role authenticated;
select set_config('request.jwt.claim.sub','54540000-0000-0000-0000-000000000001',true);
select throws_ok(
 $$select public.resolver_jornada_incompleta_no_pagar('54540000-0000-0000-0000-000000000602',8.01,'P0 invalid manual')$$,
 '22023','NO_PAY_MANUAL_HOURS_OUT_OF_RANGE','manual NO PAY rejects more than eight hours'
);
select lives_ok(
 $$select public.resolver_jornada_incompleta_no_pagar('54540000-0000-0000-0000-000000000601',8,'P0 manual')$$,
 'manual NO PAY accepts eight hours'
);
select lives_ok(
 $$select public.resolver_jornada_incompleta_no_pagar('54540000-0000-0000-0000-000000000603',null,'P0 paused')$$,
 'paused NO PAY resolves from chronology'
);
select lives_ok(
 $$select public.resolver_jornada_incompleta_no_pagar('54540000-0000-0000-0000-000000000604',null,'P0 resumed')$$,
 'resumed NO PAY resolves from accumulated minutes'
);
set local role postgres;
select is((select horas_pagables from public.nomina_jornadas_incompletas_resueltas
 where jornada_id='54540000-0000-0000-0000-000000000601'),8.00::numeric,'manual NO PAY stores eight hours');
select is((select monto from public.nomina_jornadas_incompletas_resueltas
 where jornada_id='54540000-0000-0000-0000-000000000601'),800.00::numeric,'manual NO PAY uses the hourly salary value');
select is((select horas_pagables from public.nomina_jornadas_incompletas_resueltas
 where jornada_id='54540000-0000-0000-0000-000000000603'),8.00::numeric,'paused chronology never pays overtime');
select is((select monto from public.nomina_jornadas_incompletas_resueltas
 where jornada_id='54540000-0000-0000-0000-000000000603'),800.00::numeric,'paused chronology amount is capped at eight hours');
select is((select horas_pagables from public.nomina_jornadas_incompletas_resueltas
 where jornada_id='54540000-0000-0000-0000-000000000604'),8.00::numeric,'resumed chronology never pays overtime');
select is((select count(*)::integer from public.nomina_jornadas_incompletas_resueltas
 where empresa_id='54540000-0000-0000-0000-000000000010' and horas_pagables>8),0,'NO PAY never persists overtime');

insert into public.nomina_periodos(
 id,empresa_id,fecha_inicio,fecha_fin,tipo_periodo,estado,creada_por,cerrada_en,cerrada_por
) values (
 '54540000-0000-0000-0000-000000000901','54540000-0000-0000-0000-000000000010',
 '2021-01-01','2021-01-15','QUINCENAL','CERRADA','54540000-0000-0000-0000-000000000001',
 now(),'54540000-0000-0000-0000-000000000001'
);
insert into public.nominas(id,empresa_id,periodo_id,estado,version_calculo,formula)
values ('54540000-0000-0000-0000-000000000902','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000901','CERRADA',1,'P0_TEST');
insert into public.nomina_detalles(
 id,empresa_id,nomina_id,empleado_id,codigo_empleado,nombre_empleado,sueldo_base,
 bruto,neto,version_calculo,formula,entradas,resultados
) values (
 '54540000-0000-0000-0000-000000000903','54540000-0000-0000-0000-000000000010',
 '54540000-0000-0000-0000-000000000902','54540000-0000-0000-0000-000000000201',
 '545401','P0 Finance Employee',24000,800,800,1,'P0_TEST','{}','{}'
);
insert into public.nomina_periodos(
 id,empresa_id,fecha_inicio,fecha_fin,tipo_periodo,estado,creada_por,aprobada_en,aprobada_por
) values (
 '54540000-0000-0000-0000-000000000904','54540000-0000-0000-0000-000000000010',
 '2021-02-01','2021-02-15','QUINCENAL','APROBADA','54540000-0000-0000-0000-000000000001',
 now(),'54540000-0000-0000-0000-000000000001'
);
insert into public.nominas(id,empresa_id,periodo_id,estado,version_calculo,formula)
values ('54540000-0000-0000-0000-000000000905','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000904','APROBADA',1,'P0_TEST');
insert into public.nomina_detalles(
 id,empresa_id,nomina_id,empleado_id,codigo_empleado,nombre_empleado,sueldo_base,
 bruto,neto,version_calculo,formula,entradas,resultados
) values (
 '54540000-0000-0000-0000-000000000906','54540000-0000-0000-0000-000000000010',
 '54540000-0000-0000-0000-000000000905','54540000-0000-0000-0000-000000000201',
 '545401','P0 Finance Employee',24000,1000,1000,1,'P0_TEST','{}','{}'
);

alter table public.nomina_resoluciones_diarias enable always trigger capture_prior_adjustment_0050;
set local session_replication_role = replica;
insert into public.nomina_resoluciones_diarias(
 id,empresa_id,empleado_id,fecha_local,revision,fuente_economica,timezone,iso_dia,
 minutos_programados,minutos_trabajados,minutos_normales_reconocidos,minutos_extra,
 sueldo_mensual,valor_dia,valor_quincena,valor_hora_extra,monto_normal_reconocido,
 es_festivo,es_dia_libre_automatico,es_dia_libre_manual,es_ausencia,
 asignacion_horario_id,plantilla_version_id,plantilla_dia_id,condicion_salarial_id,
 objetivo_base_nominal,objetivo_ajuste_diario,objetivo_hora_extra,
 objetivo_premium_festivo,objetivo_complemento_30_dias,snapshot,input_hash,motivo,actor_id
) values
 ('54540000-0000-0000-0000-000000000910','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','2021-01-10',1,'JORNADA','UTC',2,
 480,480,480,0,24000,800,12000,0,800,false,false,false,false,
 '54540000-0000-0000-0000-000000000921','54540000-0000-0000-0000-000000000922','54540000-0000-0000-0000-000000000923','54540000-0000-0000-0000-000000000924',
 800,0,0,0,0,'{"jornada":{"minutos_pausa":60},"minutos_tardanza":0}',repeat('a',64),'P0 prior v1','54540000-0000-0000-0000-000000000001'),
 ('54540000-0000-0000-0000-000000000911','54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','2021-01-10',2,'JORNADA','UTC',2,
 480,540,540,0,24000,800,12000,0,900,false,false,false,false,
 '54540000-0000-0000-0000-000000000921','54540000-0000-0000-0000-000000000922','54540000-0000-0000-0000-000000000923','54540000-0000-0000-0000-000000000924',
 900,0,0,0,0,'{"jornada":{"minutos_pausa":30},"minutos_tardanza":5}',repeat('b',64),'P0 prior v2','54540000-0000-0000-0000-000000000001');
set local session_replication_role = origin;
alter table public.nomina_resoluciones_diarias enable trigger capture_prior_adjustment_0050;
select is((select bruto from public.nomina_detalles where id='54540000-0000-0000-0000-000000000903'),800.00::numeric,'closed payroll detail remains frozen after a correction');
select is((select count(*)::integer from public.nomina_ajustes_anteriores
 where resolucion_nueva_id='54540000-0000-0000-0000-000000000911'),1,'one prior-period adjustment is captured');
select is((select monto_bruto from public.nomina_ajustes_anteriores
 where resolucion_nueva_id='54540000-0000-0000-0000-000000000911'),100.00::numeric,'prior-period adjustment stores the economic delta');
select is((select estado from public.nomina_ajustes_anteriores
 where resolucion_nueva_id='54540000-0000-0000-0000-000000000911'),'PENDIENTE','captured adjustment starts pending');
set local role authenticated;
select set_config('request.jwt.claim.sub','54540000-0000-0000-0000-000000000001',true);
select lives_ok(
 $$select public.aplicar_ajustes_anteriores_periodo('54540000-0000-0000-0000-000000000904')$$,
 'prior-period adjustment applies to the next payroll'
);
select lives_ok(
 $$select public.aplicar_ajustes_anteriores_periodo('54540000-0000-0000-0000-000000000904')$$,
 'prior-period adjustment retry is idempotent'
);
set local role postgres;
select is((select bruto from public.nomina_detalles where id='54540000-0000-0000-0000-000000000906'),1100.00::numeric,'next payroll receives the adjustment exactly once');
select is((select estado from public.nomina_ajustes_anteriores
 where resolucion_nueva_id='54540000-0000-0000-0000-000000000911'),'RESERVADO','applied adjustment is reserved until close');
update public.nomina_periodos
set estado='CERRADA',cerrada_en=now(),cerrada_por='54540000-0000-0000-0000-000000000001'
where id='54540000-0000-0000-0000-000000000904';
select is((select estado from public.nomina_ajustes_anteriores
 where resolucion_nueva_id='54540000-0000-0000-0000-000000000911'),'APLICADO','closing payroll completes the prior adjustment');

set local session_replication_role = replica;
insert into public.nomina_resoluciones_diarias(
 empresa_id,empleado_id,fecha_local,revision,fuente_economica,timezone,iso_dia,
 minutos_programados,minutos_trabajados,minutos_normales_reconocidos,minutos_extra,
 sueldo_mensual,valor_dia,valor_quincena,valor_hora_extra,monto_normal_reconocido,
 es_festivo,es_dia_libre_automatico,es_dia_libre_manual,es_ausencia,
 asignacion_horario_id,plantilla_version_id,plantilla_dia_id,condicion_salarial_id,
 objetivo_base_nominal,objetivo_ajuste_diario,objetivo_hora_extra,
 objetivo_premium_festivo,objetivo_complemento_30_dias,snapshot,input_hash,motivo,actor_id
)
select
 '54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201',d::date,1,
 'AUSENCIA','UTC',extract(isodow from d)::smallint,480,0,0,0,24000,800,12000,0,0,
 false,false,false,true,
 '54540000-0000-0000-0000-000000000921','54540000-0000-0000-0000-000000000922','54540000-0000-0000-0000-000000000923','54540000-0000-0000-0000-000000000924',
 800,-800,0,0,0,jsonb_build_object('jornada',jsonb_build_object('minutos_pausa',0),'minutos_tardanza',10),
 encode(extensions.digest(('p0-blacklist-'||d::date)::text,'sha256'),'hex'),'P0 blacklist','54540000-0000-0000-0000-000000000001'
from generate_series('2020-05-01'::date,'2020-05-06'::date,'1 day') d;
insert into public.nomina_resoluciones_diarias(
 empresa_id,empleado_id,fecha_local,revision,fuente_economica,timezone,iso_dia,
 minutos_programados,minutos_trabajados,minutos_normales_reconocidos,minutos_extra,
 sueldo_mensual,valor_dia,valor_quincena,valor_hora_extra,monto_normal_reconocido,
 es_festivo,es_dia_libre_automatico,es_dia_libre_manual,es_ausencia,
 asignacion_horario_id,plantilla_version_id,plantilla_dia_id,condicion_salarial_id,
 objetivo_base_nominal,objetivo_ajuste_diario,objetivo_hora_extra,
 objetivo_premium_festivo,objetivo_complemento_30_dias,snapshot,input_hash,motivo,actor_id
) values (
 '54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201','2020-05-01',2,
 'AUSENCIA','UTC',7,480,0,0,0,24000,800,12000,0,0,false,false,false,true,
 '54540000-0000-0000-0000-000000000921','54540000-0000-0000-0000-000000000922','54540000-0000-0000-0000-000000000923','54540000-0000-0000-0000-000000000924',
 800,-800,0,0,0,'{"jornada":{"minutos_pausa":0},"minutos_tardanza":10}',repeat('c',64),'P0 blacklist revision','54540000-0000-0000-0000-000000000001'
);
set local session_replication_role = origin;
insert into public.jornadas(
 empresa_id,empleado_id,fecha_laboral,estado,iniciado_en,minutos_trabajados,minutos_pausa,origen,revision_pendiente
)
select '54540000-0000-0000-0000-000000000010','54540000-0000-0000-0000-000000000201',d::date,
 'EN_CURSO',(d::date + time '08:00') at time zone 'UTC',0,0,'WEB',true
from generate_series('2020-05-20'::date,'2020-05-25'::date,'1 day') d;
select is((select count(*)::integer from public.nomina_resoluciones_diarias where empresa_id='54540000-0000-0000-0000-000000000010' and fecha_local between '2020-05-01' and '2020-05-31'),7,'blacklist fixture persists seven resolution revisions');
select is((select count(distinct fecha_local)::integer from public.nomina_resoluciones_diarias where empresa_id='54540000-0000-0000-0000-000000000010' and fecha_local between '2020-05-01' and '2020-05-31' and es_ausencia),6,'blacklist fixture has six absence days');
select is((select count(*)::integer from (select empleado_id,fecha_local from public.nomina_resoluciones_diarias where empresa_id='54540000-0000-0000-0000-000000000010' and fecha_local between '2020-05-01' and '2020-05-31' group by empleado_id,fecha_local having max(revision)>1) x),1,'blacklist fixture has one modified day');
select is((select count(*)::integer from public.jornadas where empresa_id='54540000-0000-0000-0000-000000000010' and fecha_laboral between '2020-05-01' and '2020-05-31' and finalizado_en is null),6,'blacklist fixture has six incomplete journeys');
set local role authenticated;
select set_config('request.jwt.claim.sub','54540000-0000-0000-0000-000000000001',true);
select lives_ok($$select public.refrescar_lista_negra_mensual(2020,5)$$,'monthly blacklist refresh succeeds');
set local role postgres;
select is((select count(*)::integer from public.lista_negra_mensual
 where empresa_id='54540000-0000-0000-0000-000000000010' and anio=2020 and mes=5),4,'all four blacklist categories are persisted');
select is((select contador from public.lista_negra_mensual
 where empresa_id='54540000-0000-0000-0000-000000000010' and anio=2020 and mes=5 and categoria='AUSENCIAS'),6,'absence threshold count is retained');
select is((select contador from public.lista_negra_mensual
 where empresa_id='54540000-0000-0000-0000-000000000010' and anio=2020 and mes=5 and categoria='TARDANZA'),6,'late threshold count is retained');
select is((select contador from public.lista_negra_mensual
 where empresa_id='54540000-0000-0000-0000-000000000010' and anio=2020 and mes=5 and categoria='SIN FINALIZAR JORNADA'),6,'unfinished-journey threshold count is retained');
select is((select contador from public.lista_negra_mensual
 where empresa_id='54540000-0000-0000-0000-000000000010' and anio=2020 and mes=5 and categoria='MODIFICADOS'),1,'modified-day category is retained');
set local role authenticated;
select set_config('request.jwt.claim.sub','54540000-0000-0000-0000-000000000001',true);
select is(jsonb_array_length(public.reporte_lista_negra_empleado(
 '54540000-0000-0000-0000-000000000201',2020,5)->'categories'),4,'employee blacklist report exposes four categories');
select lives_ok($$select public.refrescar_lista_negra_mensual(2020,6)$$,'next month refresh succeeds');
set local role postgres;
select is((select count(*)::integer from public.lista_negra_mensual
 where empresa_id='54540000-0000-0000-0000-000000000010' and anio=2020 and mes=5),4,'prior month blacklist rows remain persisted');
select is((select count(*)::integer from public.lista_negra_mensual
 where empresa_id='54540000-0000-0000-0000-000000000010' and anio=2020 and mes=5 and archivado),4,'prior month blacklist rows are archived');
select ok(public.terminal_empleado_elegible(
 '54540000-0000-0000-0000-000000000010',
 '54540000-0000-0000-0000-000000000401',
 '54540000-0000-0000-0000-000000000201'
),'blacklist status does not block attendance eligibility');

select * from finish();
rollback;