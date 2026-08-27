begin;
set local search_path = extensions, public, pg_catalog;
set local role postgres;
select * from no_plan();

insert into auth.users(
  id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
 ('53000000-0000-0000-0000-000000000001','authenticated','authenticated','admin-a@p0.test','x',now(),'{}','{}',now(),now()),
 ('53000000-0000-0000-0000-000000000002','authenticated','authenticated','supervisor-a@p0.test','x',now(),'{}','{}',now(),now()),
 ('53000000-0000-0000-0000-000000000003','authenticated','authenticated','admin-b@p0.test','x',now(),'{}','{}',now(),now()),
 ('53000000-0000-0000-0000-000000000004','authenticated','authenticated','admin-a-backup@p0.test','x',now(),'{}','{}',now(),now());

insert into public.companies(id,name,slug) values
 ('53000000-0000-0000-0000-000000000010','P0 Empresa A','p0-empresa-a'),
 ('53000000-0000-0000-0000-000000000110','P0 Empresa B','p0-empresa-b');

insert into public.roles(id,company_id,name,code,is_active) values
 ('53000000-0000-0000-0000-000000000011','53000000-0000-0000-0000-000000000010','Administrador A','admin',true),
 ('53000000-0000-0000-0000-000000000012','53000000-0000-0000-0000-000000000010','Supervisor A','supervisor',true),
 ('53000000-0000-0000-0000-000000000111','53000000-0000-0000-0000-000000000110','Administrador B','admin',true);

insert into public.branches(id,company_id,name,code,is_main) values
 ('53000000-0000-0000-0000-000000000020','53000000-0000-0000-0000-000000000010','A Principal','A-P0',true),
 ('53000000-0000-0000-0000-000000000021','53000000-0000-0000-0000-000000000010','A Secundaria','A2-P0',false),
 ('53000000-0000-0000-0000-000000000120','53000000-0000-0000-0000-000000000110','B Principal','B-P0',true);

insert into public.departments(id,company_id,branch_id,name,code) values
 ('53000000-0000-0000-0000-000000000030','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000020','Ventas A','VENTAS-A'),
 ('53000000-0000-0000-0000-000000000031','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000020','Caja A','CAJA-A'),
 ('53000000-0000-0000-0000-000000000032','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000021','Almacen A2','ALMACEN-A2'),
 ('53000000-0000-0000-0000-000000000130','53000000-0000-0000-0000-000000000110','53000000-0000-0000-0000-000000000120','Ventas B','VENTAS-B');

insert into public.employee_code_sequences(empresa_id,last_value) values
 ('53000000-0000-0000-0000-000000000010',530000),
 ('53000000-0000-0000-0000-000000000110',540000)
on conflict(empresa_id) do update set last_value=excluded.last_value;

insert into public.empleados(
  id,empresa_id,sucursal_id,departamento_id,codigo_empleado,nombre_completo,
  activo,estado_laboral,jornada_habilitada,salario,
  fecha_desvinculacion,motivo_desvinculacion
) values
 ('53000000-0000-0000-0000-000000000201','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000020','53000000-0000-0000-0000-000000000030','530001','Admin Empleado A',true,'activo',true,24000,null,null),
 ('53000000-0000-0000-0000-000000000202','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000020','53000000-0000-0000-0000-000000000031','530002','Empleado Caja A',true,'activo',true,24000,null,null),
 ('53000000-0000-0000-0000-000000000203','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000021','53000000-0000-0000-0000-000000000032','530003','Empleado Sucursal A2',true,'activo',true,24000,null,null),
 ('53000000-0000-0000-0000-000000000204','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000020','53000000-0000-0000-0000-000000000030','530004','Empleado Inactivo A',false,'desvinculado',false,24000,current_date,'Fixture P0'),
 ('53000000-0000-0000-0000-000000000301','53000000-0000-0000-0000-000000000110','53000000-0000-0000-0000-000000000120','53000000-0000-0000-0000-000000000130','540001','Empleado B',true,'activo',true,24000,null,null);

insert into public.profiles(id,company_id,role_id,employee_code,full_name,status) values
 ('53000000-0000-0000-0000-000000000001','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000011','530001','Administrador A','active'),
 ('53000000-0000-0000-0000-000000000002','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000012','530002','Supervisor A','active'),
 ('53000000-0000-0000-0000-000000000003','53000000-0000-0000-0000-000000000110','53000000-0000-0000-0000-000000000111','540001','Administrador B','active'),
 ('53000000-0000-0000-0000-000000000004','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000011',null,'Administrador A Respaldo','active');

update public.empleados set perfil_id=case id
 when '53000000-0000-0000-0000-000000000201'::uuid then '53000000-0000-0000-0000-000000000001'::uuid
 when '53000000-0000-0000-0000-000000000202'::uuid then '53000000-0000-0000-0000-000000000002'::uuid
 when '53000000-0000-0000-0000-000000000301'::uuid then '53000000-0000-0000-0000-000000000003'::uuid
 end
where id in(
 '53000000-0000-0000-0000-000000000201',
 '53000000-0000-0000-0000-000000000202',
 '53000000-0000-0000-0000-000000000301'
);

insert into public.perfil_sucursales(perfil_id,sucursal_id) values
 ('53000000-0000-0000-0000-000000000002','53000000-0000-0000-0000-000000000020');
insert into public.perfil_departamentos(perfil_id,departamento_id) values
 ('53000000-0000-0000-0000-000000000002','53000000-0000-0000-0000-000000000031');

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select '53000000-0000-0000-0000-000000000011',p.id,true,'empresa'
from public.permisos p
where p.codigo in('kiosk.face_mode_manage','dispositivos.registrar','mensajes.administrar')
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

insert into public.dispositivos_android(
 id,empresa_id,sucursal_id,nombre,modelo,android_version,app_version,
 instalacion_id,public_key_spki,estado
) values
 ('53000000-0000-0000-0000-000000000401','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000020','Terminal A1','P0','14','1.0','53000000-0000-0000-0000-000000000411','p0-key-a1','activo'),
 ('53000000-0000-0000-0000-000000000402','53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000021','Terminal A2','P0','14','1.0','53000000-0000-0000-0000-000000000412','p0-key-a2','activo'),
 ('53000000-0000-0000-0000-000000000403','53000000-0000-0000-0000-000000000110','53000000-0000-0000-0000-000000000120','Terminal B','P0','14','1.0','53000000-0000-0000-0000-000000000413','p0-key-b','activo');

set local role authenticated;
select set_config('request.jwt.claim.sub','53000000-0000-0000-0000-000000000001',true);
select lives_ok(
 $$select public.configurar_terminal_facial(
   '53000000-0000-0000-0000-000000000401',
   '53000000-0000-0000-0000-000000000020',
   'GENERAL','{}'::uuid[],'GENERAL P0'
 )$$,
 'GENERAL configuration is accepted for authorized admin'
);
set local role postgres;

select ok(public.terminal_empleado_elegible(
 '53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000401','53000000-0000-0000-0000-000000000201'),
 'GENERAL accepts active employee from terminal branch');
select ok(public.terminal_empleado_elegible(
 '53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000401','53000000-0000-0000-0000-000000000203'),
 'GENERAL accepts active employee from another branch in same company');
select ok(not public.terminal_empleado_elegible(
 '53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000401','53000000-0000-0000-0000-000000000301'),
 'GENERAL rejects another company');
select ok(not public.terminal_empleado_elegible(
 '53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000401','53000000-0000-0000-0000-000000000204'),
 'GENERAL rejects inactive employee');
select is((select sucursal_id from public.dispositivos_android where id='53000000-0000-0000-0000-000000000401'),
 '53000000-0000-0000-0000-000000000020'::uuid,
 'GENERAL keeps the physical terminal branch');

set local role authenticated;
select set_config('request.jwt.claim.sub','53000000-0000-0000-0000-000000000001',true);
select throws_ok(
 $$select public.configurar_terminal_facial(
   '53000000-0000-0000-0000-000000000401',
   '53000000-0000-0000-0000-000000000020',
   'DEPARTMENTS','{}'::uuid[],'empty scope'
 )$$,
 '22023','TERMINAL_DEPARTMENT_REQUIRED','DEPARTMENTS rejects zero departments'
);
select lives_ok(
 $$select public.configurar_terminal_facial(
   '53000000-0000-0000-0000-000000000401',
   '53000000-0000-0000-0000-000000000020',
   'DEPARTMENTS',array[
     '53000000-0000-0000-0000-000000000030'::uuid,
     '53000000-0000-0000-0000-000000000031'::uuid
   ],'multi department scope'
 )$$,
 'DEPARTMENTS accepts multiple departments in the physical branch'
);
set local role postgres;
select is((select count(*)::integer from public.dispositivo_departamentos where dispositivo_id='53000000-0000-0000-0000-000000000401'),2,'two terminal departments are persisted');
select ok(public.terminal_empleado_elegible('53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000401','53000000-0000-0000-0000-000000000201'),'allowed department employee is eligible');
select ok(not public.terminal_empleado_elegible('53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000401','53000000-0000-0000-0000-000000000203'),'employee outside branch departments is rejected');

set local role authenticated;
select set_config('request.jwt.claim.sub','53000000-0000-0000-0000-000000000001',true);
select lives_ok(
 $$select public.configurar_terminal_facial(
   '53000000-0000-0000-0000-000000000401',
   '53000000-0000-0000-0000-000000000020',
   'DEPARTMENTS',array['53000000-0000-0000-0000-000000000030'::uuid],
   'single department scope'
 )$$,
 'department selection can be narrowed'
);
set local role postgres;
update public.empleados set departamento_id='53000000-0000-0000-0000-000000000031' where id='53000000-0000-0000-0000-000000000201';
select ok(not public.terminal_empleado_elegible('53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000401','53000000-0000-0000-0000-000000000201'),'department change is reflected immediately');
update public.empleados set departamento_id='53000000-0000-0000-0000-000000000030' where id='53000000-0000-0000-0000-000000000201';
select ok(public.terminal_empleado_elegible('53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000401','53000000-0000-0000-0000-000000000201'),'restored allowed department is reflected immediately');

set local role authenticated;
select set_config('request.jwt.claim.sub','53000000-0000-0000-0000-000000000001',true);
select lives_ok(
 $$select public.configurar_terminal_facial(
   '53000000-0000-0000-0000-000000000401',
   '53000000-0000-0000-0000-000000000021',
   'GENERAL','{}'::uuid[],'branch change'
 )$$,
 'changing terminal branch through GENERAL is accepted'
);
set local role postgres;
select is((select count(*)::integer from public.dispositivo_departamentos where dispositivo_id='53000000-0000-0000-0000-000000000401'),0,'branch change clears previous department selection');

create temporary table p0_state(message_id uuid, auth_revision bigint) on commit drop;
grant select on p0_state to authenticated;
insert into p0_state(auth_revision)
select authorization_revision from public.profiles where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','53000000-0000-0000-0000-000000000001',true);
select is(public.validar_autorizacion_actual((select auth_revision from p0_state),'mensajes.administrar','53000000-0000-0000-0000-000000000201')->>'ok','true','current authorization revision is accepted');
set local role postgres;
update public.rol_permisos rp set permitido=false
from public.permisos p
where rp.rol_id='53000000-0000-0000-0000-000000000011'
  and rp.permiso_id=p.id and p.codigo='mensajes.administrar';
set local role authenticated;
select set_config('request.jwt.claim.sub','53000000-0000-0000-0000-000000000001',true);
select throws_ok(
 $$select public.validar_autorizacion_actual((select auth_revision from p0_state),'mensajes.administrar','53000000-0000-0000-0000-000000000201')$$,
 '40001','AUTHORIZATION_STALE','permission removal invalidates the previous revision immediately'
);
select throws_ok(
 $$select public.validar_autorizacion_actual(null,'mensajes.administrar','53000000-0000-0000-0000-000000000201')$$,
 '42501','PERMISSION_REVOKED','backend rejects a revoked permission immediately'
);
set local role postgres;
update public.rol_permisos rp set permitido=true
from public.permisos p
where rp.rol_id='53000000-0000-0000-0000-000000000011'
  and rp.permiso_id=p.id and p.codigo='mensajes.administrar';
select ok((select authorization_revision from public.profiles where id='53000000-0000-0000-0000-000000000001') > (select auth_revision from p0_state),'permission restoration advances authorization revision');

set local role authenticated;
select set_config('request.jwt.claim.sub','53000000-0000-0000-0000-000000000001',true);
select lives_ok(
 $$select public.configurar_terminal_facial(
   '53000000-0000-0000-0000-000000000401',
   '53000000-0000-0000-0000-000000000020','GENERAL','{}'::uuid[],'message general'
 )$$,
 'message terminal is restored to GENERAL'
);
select lives_ok(
 $$select public.configurar_terminal_facial(
   '53000000-0000-0000-0000-000000000402',
   '53000000-0000-0000-0000-000000000021','GENERAL','{}'::uuid[],'second general'
 )$$,
 'second GENERAL terminal is configured'
);
select lives_ok(
 $$select public.crear_mensaje_empleado(
   '53000000-0000-0000-0000-000000000203','TEXTO','Mensaje P0',null,null,
   '53000000-0000-4000-8000-000000000501'
 )$$,
 'authorized user creates one pending message'
);
select throws_ok(
 $$select public.crear_mensaje_empleado(
   '53000000-0000-0000-0000-000000000203','TEXTO','Segundo',null,null,
   '53000000-0000-4000-8000-000000000502'
 )$$,
 'P4903','EMPLOYEE_MESSAGE_ALREADY_PENDING','only one pending message per employee'
);
set local role postgres;
update p0_state set message_id=(select id from public.mensajes_empleados where empleado_id='53000000-0000-0000-0000-000000000203');
select is(jsonb_array_length(public.obtener_mensajes_pendientes_dispositivo('53000000-0000-0000-0000-000000000010','53000000-0000-0000-0000-000000000401')),1,'GENERAL preload includes another-branch employee message');
select is(jsonb_array_length(public.obtener_mensajes_pendientes_dispositivo('53000000-0000-0000-0000-000000000110','53000000-0000-0000-0000-000000000403')),0,'message preload does not leak across companies');
select is(public.confirmar_mensaje_recibido_dispositivo(jsonb_build_object(
 'empresa_id','53000000-0000-0000-0000-000000000010',
 'dispositivo_id','53000000-0000-0000-0000-000000000401',
 'empleado_id','53000000-0000-0000-0000-000000000203',
 'mensaje_id',(select message_id from p0_state),
 'idempotency_key','53000000-0000-4000-8000-000000000503'
))->>'result','accepted','first terminal confirmation wins');
select is((select count(*)::integer from public.mensajes_empleados where id=(select message_id from p0_state)),0,'accepted confirmation removes pending content');
select is(public.confirmar_mensaje_recibido_dispositivo(jsonb_build_object(
 'empresa_id','53000000-0000-0000-0000-000000000010',
 'dispositivo_id','53000000-0000-0000-0000-000000000402',
 'empleado_id','53000000-0000-0000-0000-000000000203',
 'mensaje_id',(select message_id from p0_state),
 'idempotency_key','53000000-0000-4000-8000-000000000504'
))->>'result','duplicate','later terminal confirmation is idempotent');
select is((select count(*)::integer from public.mensajes_empleados_recibidos where mensaje_id=(select message_id from p0_state)),1,'only one receipt tombstone is retained');

update public.profiles set status='inactive' where id='53000000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','53000000-0000-0000-0000-000000000001',true);
select throws_ok(
 $$select public.obtener_revision_autorizacion()$$,
 '28000','PROFILE_INACTIVE','disabled user loses authorization immediately'
);

set local role postgres;
select * from finish();
rollback;