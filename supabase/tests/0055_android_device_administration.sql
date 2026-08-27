begin;
set local search_path = extensions, public, pg_catalog;
set local role postgres;
select * from no_plan();

insert into auth.users(
  id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
 ('55000000-0000-0000-0000-000000000001','authenticated','authenticated','device-admin@p0.test','x',now(),'{}','{}',now(),now()),
 ('55000000-0000-0000-0000-000000000002','authenticated','authenticated','device-scoped@p0.test','x',now(),'{}','{}',now(),now()),
 ('55000000-0000-0000-0000-000000000003','authenticated','authenticated','device-none@p0.test','x',now(),'{}','{}',now(),now());

insert into public.companies(id,name,slug) values
 ('55000000-0000-0000-0000-000000000010','Device Empresa A','device-empresa-a'),
 ('55000000-0000-0000-0000-000000000110','Device Empresa B','device-empresa-b');

insert into public.roles(id,company_id,name,code,is_active) values
 ('55000000-0000-0000-0000-000000000011','55000000-0000-0000-0000-000000000010','Device Admin','device_admin',true),
 ('55000000-0000-0000-0000-000000000012','55000000-0000-0000-0000-000000000010','Device Scoped','device_scoped',true),
 ('55000000-0000-0000-0000-000000000013','55000000-0000-0000-0000-000000000010','Device None','device_none',true);

insert into public.branches(id,company_id,name,code,is_main) values
 ('55000000-0000-0000-0000-000000000020','55000000-0000-0000-0000-000000000010','Device Principal','DEV-1',true),
 ('55000000-0000-0000-0000-000000000021','55000000-0000-0000-0000-000000000010','Device Secundaria','DEV-2',false),
 ('55000000-0000-0000-0000-000000000120','55000000-0000-0000-0000-000000000110','Device Otra Empresa','DEV-B',true);

insert into public.departments(id,company_id,branch_id,name,code) values
 ('55000000-0000-0000-0000-000000000030','55000000-0000-0000-0000-000000000010','55000000-0000-0000-0000-000000000020','Device Ventas','DEV-V'),
 ('55000000-0000-0000-0000-000000000031','55000000-0000-0000-0000-000000000010','55000000-0000-0000-0000-000000000021','Device Caja','DEV-C');

insert into public.profiles(id,company_id,role_id,full_name,status) values
 ('55000000-0000-0000-0000-000000000001','55000000-0000-0000-0000-000000000010','55000000-0000-0000-0000-000000000011','Device Admin','active'),
 ('55000000-0000-0000-0000-000000000002','55000000-0000-0000-0000-000000000010','55000000-0000-0000-0000-000000000012','Device Scoped','active'),
 ('55000000-0000-0000-0000-000000000003','55000000-0000-0000-0000-000000000010','55000000-0000-0000-0000-000000000013','Device None','active');

insert into public.perfil_sucursales(perfil_id,sucursal_id) values
 ('55000000-0000-0000-0000-000000000002','55000000-0000-0000-0000-000000000020');

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select '55000000-0000-0000-0000-000000000011',p.id,true,'empresa'
from public.permisos p
where p.codigo in('dispositivos.ver','dispositivos.registrar','kiosk.face_mode_manage')
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select '55000000-0000-0000-0000-000000000012',p.id,true,'sucursal'
from public.permisos p
where p.codigo in('dispositivos.ver','dispositivos.registrar')
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='sucursal';

insert into public.dispositivos_android(
 id,empresa_id,sucursal_id,nombre,modelo,android_version,app_version,
 instalacion_id,public_key_spki,estado
) values
 ('55000000-0000-0000-0000-000000000401','55000000-0000-0000-0000-000000000010','55000000-0000-0000-0000-000000000020','Terminal Principal','WP23 Plus','14','1.0','55000000-0000-0000-0000-000000000411','device-key-a1','activo'),
 ('55000000-0000-0000-0000-000000000402','55000000-0000-0000-0000-000000000010','55000000-0000-0000-0000-000000000021','Terminal Secundaria','Android','14','1.0','55000000-0000-0000-0000-000000000412','device-key-a2','activo'),
 ('55000000-0000-0000-0000-000000000403','55000000-0000-0000-0000-000000000110','55000000-0000-0000-0000-000000000120','Terminal Empresa B','Android','14','1.0','55000000-0000-0000-0000-000000000413','device-key-b','activo');

set local role authenticated;
select set_config('request.jwt.claim.sub','55000000-0000-0000-0000-000000000001',true);
select is(
  jsonb_array_length(public.listar_dispositivos_android_administracion()->'devices'),
  2,
  'company administrator only lists own-company devices'
);

select lives_ok(
 $$select public.actualizar_dispositivo_android_administracion(
   '55000000-0000-0000-0000-000000000401','OUKITEL Recepcion','inactivo',false,
   '55000000-0000-0000-0000-000000000020','DEPARTMENTS',
   array['55000000-0000-0000-0000-000000000030'::uuid],
   'Android device administration test'
 )$$,
 'administrator configures and deactivates a facial terminal atomically'
);
set local role postgres;

select is(
  (select nombre from public.dispositivos_android where id='55000000-0000-0000-0000-000000000401'),
  'OUKITEL Recepcion',
  'terminal name is persisted'
);
select is(
  (select estado from public.dispositivos_android where id='55000000-0000-0000-0000-000000000401'),
  'inactivo',
  'terminal state is persisted'
);
select is(
  (select voz_habilitada from public.dispositivos_android where id='55000000-0000-0000-0000-000000000401'),
  false,
  'voice setting is persisted'
);
select is(
  (select count(*)::integer from public.dispositivo_departamentos where dispositivo_id='55000000-0000-0000-0000-000000000401'),
  1,
  'department configuration uses the existing terminal contract'
);

set local role authenticated;
select set_config('request.jwt.claim.sub','55000000-0000-0000-0000-000000000001',true);
select lives_ok(
 $$select public.actualizar_dispositivo_android_administracion(
   '55000000-0000-0000-0000-000000000401','OUKITEL Recepcion','activo',true,
   '55000000-0000-0000-0000-000000000020','GENERAL','{}'::uuid[],
   'Reactivate Android terminal'
 )$$,
 'an inactive terminal can be reconfigured and reactivated'
);

select set_config('request.jwt.claim.sub','55000000-0000-0000-0000-000000000002',true);
select is(
  jsonb_array_length(public.listar_dispositivos_android_administracion()->'devices'),
  1,
  'branch-scoped administrator lists only the assigned branch'
);
select throws_ok(
 $$select public.actualizar_dispositivo_android_administracion(
   '55000000-0000-0000-0000-000000000401','Scope Escape','activo',true,
   '55000000-0000-0000-0000-000000000021','GENERAL','{}'::uuid[],
   'Attempt outside assigned branch'
 )$$,
 '42501','DEVICE_ADMIN_SCOPE_DENIED','branch-scoped administrator cannot move a terminal outside scope'
);

select set_config('request.jwt.claim.sub','55000000-0000-0000-0000-000000000003',true);
select throws_ok(
 $$select public.listar_dispositivos_android_administracion()$$,
 '42501','DEVICE_ADMIN_PERMISSION_DENIED','a user without device permission cannot list terminals'
);

set local role postgres;
update public.dispositivos_android set estado='revocado'
where id='55000000-0000-0000-0000-000000000402';
set local role authenticated;
select set_config('request.jwt.claim.sub','55000000-0000-0000-0000-000000000001',true);
select throws_ok(
 $$select public.actualizar_dispositivo_android_administracion(
   '55000000-0000-0000-0000-000000000402','Terminal Revocado','activo',true,
   '55000000-0000-0000-0000-000000000021','GENERAL','{}'::uuid[],
   'Attempt to reactivate revoked device'
 )$$,
 '55000','DEVICE_REVOKED','a revoked device cannot be reactivated through Android administration'
);

set local role postgres;
select * from finish();
rollback;