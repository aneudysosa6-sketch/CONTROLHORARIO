begin;
select plan(21);

-- Identidades y tenants aislados. Todo el fixture vive en esta transacción y se revierte al finalizar.
insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at) values
 ('00000000-0000-0000-0000-000000000101','authenticated','authenticated','admin-a@security.local','not-used',now(),'{}','{}',now(),now()),
 ('00000000-0000-0000-0000-000000000102','authenticated','authenticated','supervisor-a@security.local','not-used',now(),'{}','{}',now(),now()),
 ('00000000-0000-0000-0000-000000000103','authenticated','authenticated','employee-a@security.local','not-used',now(),'{}','{}',now(),now()),
 ('00000000-0000-0000-0000-000000000104','authenticated','authenticated','inactive-a@security.local','not-used',now(),'{}','{}',now(),now()),
 ('00000000-0000-0000-0000-000000000105','authenticated','authenticated','admin-b@security.local','not-used',now(),'{}','{}',now(),now()),
 ('00000000-0000-0000-0000-000000000106','authenticated','authenticated','employee-b@security.local','not-used',now(),'{}','{}',now(),now());

insert into public.companies(id,name,slug) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','Empresa A Seguridad','empresa-a-seguridad'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2','Empresa B Seguridad','empresa-b-seguridad');
insert into public.roles(id,company_id,name,code) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa101','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','Admin A','admin'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa102','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','Supervisor A','supervisor'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa103','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','Empleado A','employee'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb101','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2','Admin B','admin'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb103','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2','Empleado B','employee');
insert into public.branches(id,company_id,name,code,is_main) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaab01','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','Sucursal A','A-SEC',true),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2','Sucursal B','B-SEC',true);
insert into public.departments(id,company_id,branch_id,name,code) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaad01','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaab01','Departamento A1','A1'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaad02','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaab01','Departamento A2','A2'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbd1','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1','Departamento B1','B1');
insert into public.profiles(id,company_id,role_id,branch_id,department_id,employee_code,full_name,status) values
 ('00000000-0000-0000-0000-000000000101','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa101','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaab01','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaad01','10001','Admin A','active'),
 ('00000000-0000-0000-0000-000000000102','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa102','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaab01','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaad01','10002','Supervisor A','active'),
 ('00000000-0000-0000-0000-000000000103','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa103','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaab01','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaad01','10003','Empleado A','active'),
 ('00000000-0000-0000-0000-000000000104','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaa103','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaab01','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaad01','10004','Inactivo A','inactive'),
 ('00000000-0000-0000-0000-000000000105','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb101','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbd1','20001','Admin B','active'),
 ('00000000-0000-0000-0000-000000000106','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb103','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbd1','20002','Empleado B','active');
insert into public.empleados(id,empresa_id,perfil_id,sucursal_id,departamento_id,codigo_empleado,nombre_completo) values
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaae102','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','00000000-0000-0000-0000-000000000102','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaab01','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaad01','10002','Supervisor A'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaae103','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1','00000000-0000-0000-0000-000000000103','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaab01','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaad01','10003','Empleado A'),
 ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaae104','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',null,'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaab01','aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaad02','10004','Empleado A2'),
 ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb106','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2','00000000-0000-0000-0000-000000000106','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1','bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbd1','20002','Empleado B');
insert into public.permisos(codigo,nombre,modulo,activo) values
 ('portal.acceder','Portal','portal',true),('empleados.ver_todos','Ver todos','empleados',true),('empleados.ver_propio','Ver propio','empleados',true),('empleados.ver_asignados','Ver asignados','supervisor',true),('jornadas.ver_todas','Ver jornadas','jornadas',true),('jornadas.ver_asignadas','Ver jornadas asignadas','supervisor',true),('nomina.ver','Ver nómina','nomina',true),('configuracion.ver','Ver administración','configuracion',true),('empleados.biometria_ver','Ver estado biométrico','empleados',true)
on conflict(codigo) do update set activo=true;
insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'empresa' from public.roles r join public.permisos p on p.codigo in('portal.acceder','empleados.ver_todos','jornadas.ver_todas','nomina.ver','configuracion.ver','empleados.biometria_ver') where r.code='admin'
on conflict(rol_id,permiso_id) do update set permitido=true;
insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'departamento' from public.roles r join public.permisos p on p.codigo in('portal.acceder','empleados.ver_asignados','jornadas.ver_asignadas') where r.company_id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1' and r.code='supervisor'
on conflict(rol_id,permiso_id) do update set permitido=true;
insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'propio' from public.roles r join public.permisos p on p.codigo in('portal.acceder','empleados.ver_propio') where r.code='employee'
on conflict(rol_id,permiso_id) do update set permitido=true;

-- Admin A: lee sólo su tenant y no puede actualizar Empresa B.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000101',true);
select is(public.obtener_empresa_actual(),'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1'::uuid,'Admin A resuelve su empresa');
select is((select count(*)::integer from public.empleados),3,'Admin A no lee empleados de Empresa B');
update public.empleados set nombre_completo='No permitido' where id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb106';
reset role;
select is((select nombre_completo from public.empleados where id='bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbb106'),'Empleado B','Admin A no modifica Empresa B');

-- Admin B: aislamiento simétrico.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000105',true);
select is(public.obtener_empresa_actual(),'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2'::uuid,'Admin B resuelve su empresa');
select is((select count(*)::integer from public.empleados),1,'Admin B no lee empleados de Empresa A');
update public.empleados set nombre_completo='No permitido' where id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaae103';
reset role;
select is((select nombre_completo from public.empleados where id='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaae103'),'Empleado A','Admin B no modifica Empresa A');

-- Supervisor: no recibe expediente directo; su RPC/función sólo ve el departamento asignado.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000102',true);
select ok(public.es_supervisor_actual(),'Supervisor A identificado');
select ok(public.supervisor_puede_ver_empleado('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaae103'),'Supervisor accede empleado de departamento asignado');
select ok(not public.supervisor_puede_ver_empleado('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaae104'),'Supervisor no accede departamento no asignado');
select is((select count(*)::integer from public.empleados),0,'Supervisor no obtiene expediente directo por RLS');
reset role;

-- Empleado e inactivo: sin administración, nómina, datos ajenos ni operación.
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000103',true);
select is((select count(*)::integer from public.empleados),1,'Empleado sólo lee su propio expediente');
select ok(not public.tiene_permiso('nomina.ver'),'Empleado no accede nómina general');
select ok(not public.tiene_permiso('configuracion.ver'),'Empleado no accede administración');
select is((select count(*)::integer from public.listar_estados_biometricos_empleados()),0,'Empleado sin permiso no lee estados biométricos');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000104',true);
select is(public.obtener_empresa_actual(),null::uuid,'Usuario inactivo no resuelve empresa');
select is((select count(*)::integer from public.empleados),0,'Usuario inactivo no lee empleados');
select ok(not public.tiene_permiso('portal.acceder'),'Usuario inactivo no opera permisos');
reset role;

-- Biometría y dispositivos no exponen tablas sensibles a clientes autenticados; anon tampoco las lee.
select ok(not has_table_privilege('authenticated','public.empleado_biometrias','select'),'Biometría no concede SELECT a authenticated');
select ok(not has_table_privilege('authenticated','public.dispositivos_android','select'),'Dispositivos no conceden SELECT a authenticated');
select ok(not has_table_privilege('anon','public.credenciales_dispositivo','select'),'Anon no concede SELECT a credenciales');
select ok(not has_table_privilege('authenticated','public.credenciales_dispositivo','insert'),'Authenticated no escribe credenciales');

select * from finish();
rollback;
