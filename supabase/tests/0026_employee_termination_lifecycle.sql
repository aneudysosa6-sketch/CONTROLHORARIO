begin;
select plan(71);

select has_column('public','empleados','fecha_desvinculacion');
select has_column('public','empleados','motivo_desvinculacion');
select has_column('public','empleados','observacion_desvinculacion');
select has_column('public','empleados','desvinculado_por');
select has_column('public','empleados','actualizado_por');
select has_table('public','empleado_ciclo_laboral_auditoria');
select has_function('public','desvincular_empleado',array['uuid','date','text','text']);
select has_function('public','reactivar_empleado',array['uuid','text']);
select has_function(
  'public','actualizar_auth_sync_ciclo_empleado_internal',
  array['uuid','bigint','text','text[]','text']
);
select has_function(
  'public','finalizar_reactivacion_acceso_internal',array['uuid','bigint']
);
select function_privs_are(
  'public','desvincular_empleado',array['uuid','date','text','text'],
  'authenticated',array['EXECUTE']
);
select function_privs_are(
  'public','reactivar_empleado',array['uuid','text'],
  'authenticated',array['EXECUTE']
);
select ok(
  not has_column_privilege('authenticated','public.empleados','estado_laboral','update'),
  'authenticated no cambia el ciclo laboral directamente'
);
select ok(
  not has_column_privilege('authenticated','public.empleados','activo','update'),
  'authenticated no cambia activo directamente'
);
select ok(
  has_table_privilege('service_role','public.empleado_ciclo_laboral_auditoria','select')
  and not has_table_privilege(
    'service_role','public.empleado_ciclo_laboral_auditoria','update'
  ),
  'service_role solo lee auditoria y cambia auth sync por CAS'
);
select ok(
  not has_table_privilege('authenticated','public.profiles','update')
  and not has_table_privilege('authenticated','public.profiles','delete'),
  'profiles solo cambia por RPC auditada; no hay hard delete autenticado'
);
select ok(
  position(
    'estado_laboral=''activo''' in lower(pg_get_functiondef(
      'public.registrar_evento_jornada_dispositivo(jsonb)'::regprocedure
    ))
  ) > 0,
  'jornada exige empleado laboralmente activo'
);
select ok(
  exists (
    select 1 from pg_trigger
    where tgrelid='public.profiles'::regclass
      and tgname='profiles_enforce_access_tombstone_before_write'
      and not tgisinternal
  ),
  'profiles protege tombstone y empleado desvinculado'
);
select ok(
  exists (
    select 1 from pg_trigger
    where tgrelid='public.empleados'::regclass
      and tgname='empleados_enforce_profile_lifecycle_before_write'
      and not tgisinternal
  ),
  'empleados impide enlazar acceso activo a una baja'
);
select ok(
  position('access_deleted_at is null' in lower(pg_get_functiondef(
    'private.current_company_id()'::regprocedure
  ))) > 0,
  'RLS base excluye accesos eliminados'
);

insert into auth.users(
  id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
 ('26000000-0000-0000-0000-000000000001','authenticated','authenticated','gestor26@test.invalid','x',now(),'{}','{}',now(),now()),
 ('26000000-0000-0000-0000-000000000002','authenticated','authenticated','empleado26@test.invalid','x',now(),'{}','{}',now(),now()),
 ('26000000-0000-0000-0000-000000000003','authenticated','authenticated','admin26@test.invalid','x',now(),'{}','{}',now(),now()),
 ('26000000-0000-0000-0000-000000000004','authenticated','authenticated','adminb26@test.invalid','x',now(),'{}','{}',now(),now());

insert into public.companies(id,name,slug) values
 ('26000000-0000-0000-0000-000000000010','Empresa Ciclo A','empresa-ciclo-a'),
 ('26000000-0000-0000-0000-000000000110','Empresa Ciclo B','empresa-ciclo-b');

insert into public.roles(id,company_id,name,code,is_active) values
 ('26000000-0000-0000-0000-000000000011','26000000-0000-0000-0000-000000000010','Gestor laboral','lifecycle_manager',true),
 ('26000000-0000-0000-0000-000000000012','26000000-0000-0000-0000-000000000010','Administrador','admin',true),
 ('26000000-0000-0000-0000-000000000013','26000000-0000-0000-0000-000000000010','Empleado','employee',true),
 ('26000000-0000-0000-0000-000000000112','26000000-0000-0000-0000-000000000110','Administrador','admin',true);

insert into public.profiles(
  id,company_id,role_id,full_name,status
) values
 ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-000000000010','26000000-0000-0000-0000-000000000011','Gestor Laboral','active'),
 ('26000000-0000-0000-0000-000000000002','26000000-0000-0000-0000-000000000010','26000000-0000-0000-0000-000000000013','Empleado Objetivo','active'),
 ('26000000-0000-0000-0000-000000000003','26000000-0000-0000-0000-000000000010','26000000-0000-0000-0000-000000000012','Administrador Unico','active'),
 ('26000000-0000-0000-0000-000000000004','26000000-0000-0000-0000-000000000110','26000000-0000-0000-0000-000000000112','Administrador B','active');

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select '26000000-0000-0000-0000-000000000011',p.id,true,'empresa'
from public.permisos p
where p.codigo in('empleados.desactivar','empleados.ver_todos','empleados.ver_propio')
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

insert into public.employee_code_sequences(empresa_id,last_value) values
 ('26000000-0000-0000-0000-000000000010',26000),
 ('26000000-0000-0000-0000-000000000110',26100)
on conflict(empresa_id) do update set last_value=excluded.last_value;

insert into public.empleados(
  id,empresa_id,codigo_empleado,nombre_completo,activo,estado_laboral,
  jornada_habilitada
) values
 ('26000000-0000-0000-0000-000000000021','26000000-0000-0000-0000-000000000010','026001','Empleado Objetivo',true,'activo',false),
 ('26000000-0000-0000-0000-000000000022','26000000-0000-0000-0000-000000000010','026002','Gestor Vinculado',true,'activo',true),
 ('26000000-0000-0000-0000-000000000023','26000000-0000-0000-0000-000000000010','026003','Administrador Unico',true,'activo',true),
 ('26000000-0000-0000-0000-000000000024','26000000-0000-0000-0000-000000000010','026004','Empleado Jornada Abierta',true,'activo',true),
 ('26000000-0000-0000-0000-000000000025','26000000-0000-0000-0000-000000000010','026005','Empleado Constraint',true,'activo',true),
 ('26000000-0000-0000-0000-000000000121','26000000-0000-0000-0000-000000000110','026101','Empleado Otra Empresa',true,'activo',true);

update public.empleados set perfil_id=case id
  when '26000000-0000-0000-0000-000000000021'::uuid then '26000000-0000-0000-0000-000000000002'::uuid
  when '26000000-0000-0000-0000-000000000022'::uuid then '26000000-0000-0000-0000-000000000001'::uuid
  when '26000000-0000-0000-0000-000000000023'::uuid then '26000000-0000-0000-0000-000000000003'::uuid
  when '26000000-0000-0000-0000-000000000121'::uuid then '26000000-0000-0000-0000-000000000004'::uuid
end
where id in(
 '26000000-0000-0000-0000-000000000021',
 '26000000-0000-0000-0000-000000000022',
 '26000000-0000-0000-0000-000000000023',
 '26000000-0000-0000-0000-000000000121'
);

insert into public.jornadas(
  id,empresa_id,empleado_id,fecha_laboral,estado,finalizado_en,
  minutos_trabajados,origen
) values
 ('26000000-0000-0000-0000-000000000031','26000000-0000-0000-0000-000000000010','26000000-0000-0000-0000-000000000021',current_date-1,'FINALIZADA',now(),480,'WEB'),
 ('26000000-0000-0000-0000-000000000032','26000000-0000-0000-0000-000000000010','26000000-0000-0000-0000-000000000024',current_date,'EN_CURSO',null,0,'WEB');

insert into public.jornada_eventos(
  id,jornada_id,empresa_id,empleado_id,accion,ocurrido_en,
  idempotency_key,origen
) values (
  '26000000-0000-0000-0000-000000000033',
  '26000000-0000-0000-0000-000000000032',
  '26000000-0000-0000-0000-000000000010',
  '26000000-0000-0000-0000-000000000024',
  'INICIAR',now(),
  '26000000-0000-0000-0000-000000000034','WEB'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-0000-0000-000000000001',true);

select is(
  public.desvincular_empleado(
    '26000000-0000-0000-0000-000000000021',
    (now() at time zone 'America/Santo_Domingo')::date,
    'Fin de contrato','Validado por Recursos Humanos'
  )->>'estado_laboral',
  'desvinculado','RPC devuelve la baja aplicada'
);
select is(
  (select activo from public.empleados where id='26000000-0000-0000-0000-000000000021'),
  false,'la baja deja activo=false'
);
select is(
  (select fecha_desvinculacion from public.empleados where id='26000000-0000-0000-0000-000000000021'),
  (now() at time zone 'America/Santo_Domingo')::date,
  'persiste fecha efectiva'
);
select is(
  (select status from public.profiles where id='26000000-0000-0000-0000-000000000002'),
  'inactive','bloquea el acceso enlazado sin borrarlo'
);
select is(
  (select count(*)::integer from public.empleado_ciclo_laboral_auditoria
   where empleado_id='26000000-0000-0000-0000-000000000021'
     and evento='EMPLOYEE_TERMINATED'),
  1,'registra EMPLOYEE_TERMINATED una sola vez'
);
select is(
  (select jornada_habilitada_anterior from public.empleado_ciclo_laboral_auditoria
   where empleado_id='26000000-0000-0000-0000-000000000021'
     and evento='EMPLOYEE_TERMINATED'),
  false,'auditoria conserva jornada previamente deshabilitada'
);
select ok(
  exists(select 1 from public.notificaciones_internas
    where empleado_id='26000000-0000-0000-0000-000000000021'
      and tipo='EMPLOYEE_TERMINATED'),
  'publica el evento EMPLOYEE_TERMINATED'
);
select is(
  (select count(*)::integer from public.jornadas
   where id='26000000-0000-0000-0000-000000000031'),
  1,'conserva la jornada historica'
);
select ok(
  not (public.desvincular_empleado(
    '26000000-0000-0000-0000-000000000021',
    (now() at time zone 'America/Santo_Domingo')::date,
    'Reintento controlado',null
  ) ?| array['pin_hash','face_embedding','salario']),
  'respuesta RPC no expone secretos ni salario'
);
select is(
  (select count(*)::integer from public.empleado_ciclo_laboral_auditoria
   where empleado_id='26000000-0000-0000-0000-000000000021'
     and evento='EMPLOYEE_TERMINATED'),
  1,'reintento de baja es idempotente'
);

select set_config('request.jwt.claim.sub','26000000-0000-0000-0000-000000000002',true);
select is(public.obtener_empresa_actual(),null::uuid,'empleado desvinculado no resuelve tenant');
select ok(not public.tiene_permiso('portal.acceder'),'empleado desvinculado no conserva permisos');
select is(
  (select count(*)::integer from public.profiles
   where id='26000000-0000-0000-0000-000000000002'),
  0,'JWT previo tampoco conserva la rama RLS de perfil propio'
);
select set_config('request.jwt.claim.sub','26000000-0000-0000-0000-000000000001',true);

select is(
  public.desvincular_empleado(
    '26000000-0000-0000-0000-000000000024',
    (now() at time zone 'America/Santo_Domingo')::date,
    'Fin de contrato',null
  )->>'estado_laboral',
  'desvinculado','la baja no se bloquea por jornada abierta'
);
select is(
  (select estado from public.jornadas
   where id='26000000-0000-0000-0000-000000000032'),
  'EN_CURSO','conserva estado de jornada abierta'
);
select is(
  (select revision_pendiente from public.jornadas
   where id='26000000-0000-0000-0000-000000000032'),
  true,'marca revision para que nomina no la omita'
);
select is(
  (select severidad from public.jornadas
   where id='26000000-0000-0000-0000-000000000032'),
  'ALTA','marca severidad alta'
);
select is(
  (select version_sync from public.jornadas
   where id='26000000-0000-0000-0000-000000000032'),
  0::bigint,'no altera version_sync de la marcacion'
);
select is(
  (select count(*)::integer from public.jornada_eventos
   where jornada_id='26000000-0000-0000-0000-000000000032'),
  1,'conserva todos los eventos de jornada'
);
select is(
  (select count(*)::integer from public.jornada_incidencias
   where jornada_id='26000000-0000-0000-0000-000000000032'
     and tipo='JORNADA_DESHABILITADA' and not resuelta),
  1,'crea incidencia idempotente de revision'
);
select is(
  (select count(*)::integer from public.jornada_auditoria
   where jornada_id='26000000-0000-0000-0000-000000000032'
     and accion='EMPLOYEE_TERMINATED_REVIEW'),
  1,'audita metadata sin cerrar jornada'
);
select throws_ok(
  $$select public.desvincular_empleado(
    '26000000-0000-0000-0000-000000000121',
    (now() at time zone 'America/Santo_Domingo')::date,
    'Fin de contrato',null
  )$$,
  'P0001','EMPLEADO_NO_ENCONTRADO','no cruza tenants'
);
select throws_ok(
  $$select public.desvincular_empleado(
    '26000000-0000-0000-0000-000000000022',
    (now() at time zone 'America/Santo_Domingo')::date,
    'Fin de contrato',null
  )$$,
  'P0001','AUTO_DESVINCULACION_NO_PERMITIDA','no permite auto desvinculacion'
);
select throws_ok(
  $$select public.desvincular_empleado(
    '26000000-0000-0000-0000-000000000023',
    (now() at time zone 'America/Santo_Domingo')::date,
    'Fin de contrato',null
  )$$,
  'P0001','ULTIMO_ADMINISTRADOR_NO_DESACTIVABLE','protege el ultimo administrador'
);
select throws_ok(
  $$select public.reactivar_empleado(
    '26000000-0000-0000-0000-000000000021','Reingreso autorizado'
  )$$,
  'P0001','EMPLOYEE_AUTH_SYNC_PENDING','espera el bloqueo Auth antes de reactivar'
);

reset role;
select throws_ok(
  $$update public.empleado_ciclo_laboral_auditoria
    set auth_sync_status='BAN_APPLIED',auth_sync_updated_at=now()
    where empleado_id='26000000-0000-0000-0000-000000000021'
      and evento='EMPLOYEE_TERMINATED'$$,
  'P0001','EMPLOYEE_LIFECYCLE_AUDIT_APPEND_ONLY',
  'auditoria no acepta UPDATE directo'
);
select is(
  public.actualizar_auth_sync_ciclo_empleado_internal(
    '26000000-0000-0000-0000-000000000010',
    (select id from public.empleado_ciclo_laboral_auditoria
     where empleado_id='26000000-0000-0000-0000-000000000021'
       and evento='EMPLOYEE_TERMINATED'),
    'EMPLOYEE_TERMINATED',array['PENDING_BAN'],'BAN_REQUESTED'
  ),
  'BAN_REQUESTED','CAS registra solicitud de ban'
);
select is(
  public.actualizar_auth_sync_ciclo_empleado_internal(
    '26000000-0000-0000-0000-000000000010',
    (select id from public.empleado_ciclo_laboral_auditoria
     where empleado_id='26000000-0000-0000-0000-000000000021'
       and evento='EMPLOYEE_TERMINATED'),
    'EMPLOYEE_TERMINATED',array['BAN_REQUESTED'],'BAN_APPLIED'
  ),
  'BAN_APPLIED','CAS confirma ban aplicado'
);
set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-0000-0000-000000000001',true);

select is(
  public.reactivar_empleado(
    '26000000-0000-0000-0000-000000000021','Reingreso autorizado'
  )->>'estado_laboral',
  'activo','RPC devuelve la reactivacion aplicada'
);
select is(
  (select activo from public.empleados where id='26000000-0000-0000-0000-000000000021'),
  true,'reactivacion deja activo=true'
);
select is(
  (select jornada_habilitada from public.empleados where id='26000000-0000-0000-0000-000000000021'),
  false,'restaura exactamente la configuracion previa de jornada'
);
select is(
  (select motivo_desvinculacion from public.empleados where id='26000000-0000-0000-0000-000000000021'),
  null::text,'limpia el estado actual de baja'
);
select is(
  (select status from public.profiles where id='26000000-0000-0000-0000-000000000002'),
  'inactive','mantiene perfil inactivo mientras Auth sigue baneado'
);
select ok(
  exists(
    select 1 from public.empleado_ciclo_laboral_auditoria r
    join public.empleado_ciclo_laboral_auditoria t
      on t.id=r.evento_relacionado_id
    where r.empleado_id='26000000-0000-0000-0000-000000000021'
      and r.evento='EMPLOYEE_REACTIVATED'
      and t.evento='EMPLOYEE_TERMINATED'
  ),
  'reactivacion referencia la baja que revierte'
);
select is(
  (select auth_sync_status from public.empleado_ciclo_laboral_auditoria
   where empleado_id='26000000-0000-0000-0000-000000000021'
     and evento='EMPLOYEE_REACTIVATED'),
  'PENDING_UNBAN','solicita desbanear solo el Auth bloqueado por esta baja'
);

reset role;
select is(
  public.actualizar_auth_sync_ciclo_empleado_internal(
    '26000000-0000-0000-0000-000000000010',
    (select id from public.empleado_ciclo_laboral_auditoria
     where empleado_id='26000000-0000-0000-0000-000000000021'
       and evento='EMPLOYEE_REACTIVATED'),
    'EMPLOYEE_REACTIVATED',array['PENDING_UNBAN'],'UNBAN_REQUESTED'
  ),
  'UNBAN_REQUESTED','CAS registra solicitud de unban'
);
select is(
  public.finalizar_reactivacion_acceso_internal(
    '26000000-0000-0000-0000-000000000010',
    (select id from public.empleado_ciclo_laboral_auditoria
     where empleado_id='26000000-0000-0000-0000-000000000021'
       and evento='EMPLOYEE_REACTIVATED')
  ),
  'UNBAN_APPLIED','finaliza acceso solo despues del unban'
);
select is(
  (select status from public.profiles
   where id='26000000-0000-0000-0000-000000000002'),
  'active','restaura acceso SQL en el segundo paso'
);
set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-0000-0000-000000000001',true);

select is(
  public.reactivar_empleado(
    '26000000-0000-0000-0000-000000000021','Reintento'
  )->>'already_reactivated',
  'true','reintento de reactivacion es idempotente'
);
select is(
  (select count(*)::integer from public.empleado_ciclo_laboral_auditoria
   where empleado_id='26000000-0000-0000-0000-000000000021'
     and evento='EMPLOYEE_REACTIVATED'),
  1,'no duplica evento de reactivacion'
);
select is(
  (select codigo_empleado from public.empleados where id='26000000-0000-0000-0000-000000000021'),
  '026001','conserva el codigo de empleado'
);
select is(
  (select count(*)::integer from public.empleados where id='26000000-0000-0000-0000-000000000021'),
  1,'nunca elimina la fila de empleado'
);
select ok(
  exists(select 1 from public.supervisor_auditoria
    where empleado_id='26000000-0000-0000-0000-000000000021'
      and accion='EMPLOYEE_TERMINATED'),
  'integra la baja con auditoria administrativa existente'
);
select ok(
  exists(select 1 from public.supervisor_auditoria
    where empleado_id='26000000-0000-0000-0000-000000000021'
      and accion='EMPLOYEE_REACTIVATED'),
  'integra la reactivacion con auditoria administrativa existente'
);

reset role;
update public.profiles
set status='inactive',access_deleted_at=now()
where id='26000000-0000-0000-0000-000000000002';
select throws_ok(
  $$update public.profiles set status='active'
    where id='26000000-0000-0000-0000-000000000002'$$,
  '23514','DELETED_ACCESS_MUST_REMAIN_INACTIVE','tombstone no vuelve a active'
);
select throws_ok(
  $$update public.profiles set access_deleted_at=null
    where id='26000000-0000-0000-0000-000000000002'$$,
  '23514','ACCESS_TOMBSTONE_IMMUTABLE','tombstone no puede borrarse'
);
update public.empleados
set activo=false,estado_laboral='suspendido'
where id='26000000-0000-0000-0000-000000000025';
select is(
  (select estado_laboral || ':' || activo::text from public.empleados
   where id='26000000-0000-0000-0000-000000000025'),
  'suspendido:false','suspension no se confunde con desvinculacion'
);
update public.empleados
set activo=true,estado_laboral='activo'
where id='26000000-0000-0000-0000-000000000025';
select throws_ok(
  $$update public.empleados
    set activo=false,estado_laboral='desvinculado'
    where id='26000000-0000-0000-0000-000000000025'$$,
  '23514',null,'baja directa sin metadatos no supera el constraint'
);
select throws_ok(
  $$update public.empleados
    set activo=false,estado_laboral='desvinculado',
        fecha_desvinculacion=(now() at time zone 'America/Santo_Domingo')::date,
        motivo_desvinculacion='Fin de contrato'
    where id='26000000-0000-0000-0000-000000000025'$$,
  '23514',null,'baja no puede conservar jornada habilitada'
);

insert into public.empleado_ciclo_laboral_auditoria(
  empresa_id,empleado_id,evento,fecha_efectiva,motivo,actor_id,
  estado_anterior,estado_nuevo,activo_anterior,activo_nuevo,
  jornada_habilitada_anterior,jornada_habilitada_nueva,auth_sync_status
) values (
  '26000000-0000-0000-0000-000000000110',
  '26000000-0000-0000-0000-000000000121',
  'EMPLOYEE_TERMINATED',
  (now() at time zone 'America/Santo_Domingo')::date,
  'Fixture RLS otra empresa',
  '26000000-0000-0000-0000-000000000004',
  'activo','desvinculado',true,false,true,false,'NOT_APPLICABLE'
);
select is(
  (select count(*)::integer from public.empleado_ciclo_laboral_auditoria),
  4,'fixture contiene evento de otra empresa'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','26000000-0000-0000-0000-000000000001',true);
select is(
  (select count(*)::integer from public.empleado_ciclo_laboral_auditoria),
  3,'RLS muestra solo eventos del tenant actual'
);
reset role;

select * from finish();
rollback;
