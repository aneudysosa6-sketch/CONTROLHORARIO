begin;
select plan(31);

select has_function('public','listar_accesos_internal',array['jsonb']);
select has_function('public','crear_acceso_internal',array['jsonb']);
select has_function('public','actualizar_acceso_internal',array['jsonb']);
select has_function('public','cambiar_estado_acceso_internal',array['jsonb']);
select has_function('public','eliminar_acceso_internal',array['jsonb']);
select has_function('public','registrar_operacion_acceso_internal',array['jsonb']);
select has_column('public','user_provisioning_audit','target_user_id_snapshot');
select has_column('public','profiles','access_deleted_at');
select col_not_null('public','user_provisioning_audit','target_user_id_snapshot');
select ok(
  exists (
    select 1 from pg_trigger
    where tgrelid = 'public.user_provisioning_audit'::regclass
      and tgname = 'user_provisioning_target_snapshot'
      and not tgisinternal
  ),
  'el trigger conserva el UUID historico en altas legacy'
);
select is(
  (
    select c.confdeltype::text
    from pg_constraint c
    where c.conrelid = 'public.user_provisioning_audit'::regclass
      and c.conname = 'user_provisioning_audit_target_user_id_fkey'
  ),
  'n',
  'la auditoria usa ON DELETE SET NULL y no bloquea la baja Auth'
);
select col_is_unique('public','empleados','perfil_id');
select function_privs_are('public','crear_acceso_internal',array['jsonb'],'authenticated',array[]::text[]);
select function_privs_are('public','eliminar_acceso_internal',array['jsonb'],'authenticated',array[]::text[]);
select is(
  (select count(*)::integer from public.permisos where codigo in('usuarios.view','usuarios.create','usuarios.edit') and activo),
  3,
  'existen permisos granulares para consultar, crear y editar accesos'
);

insert into auth.users(
  id,aud,role,email,encrypted_password,email_confirmed_at,
  raw_app_meta_data,raw_user_meta_data,created_at,updated_at
) values
 ('22000000-0000-0000-0000-000000000001','authenticated','authenticated','gestor@access.test','not-used',now(),'{}','{}',now(),now()),
 ('22000000-0000-0000-0000-000000000002','authenticated','authenticated','admin@access.test','not-used',now(),'{}','{}',now(),now()),
 ('22000000-0000-0000-0000-000000000003','authenticated','authenticated','nuevo@access.test','not-used',now(),'{}','{"username":"nuevo@access.test"}',now(),now()),
 ('22000000-0000-0000-0000-000000000004','authenticated','authenticated','duplicado@access.test','not-used',now(),'{}','{}',now(),now());

insert into public.companies(id,name,slug)
values('22000000-0000-0000-0000-000000000010','Empresa Accesos Test','empresa-accesos-test');

insert into public.roles(id,company_id,name,code,is_active) values
 ('22000000-0000-0000-0000-000000000011','22000000-0000-0000-0000-000000000010','Gestor de accesos','access_manager',true),
 ('22000000-0000-0000-0000-000000000012','22000000-0000-0000-0000-000000000010','Administrador','admin',true),
 ('22000000-0000-0000-0000-000000000013','22000000-0000-0000-0000-000000000010','Empleado','employee',true);

insert into public.employee_code_sequences(empresa_id,last_value)
values('22000000-0000-0000-0000-000000000010',22000)
on conflict(empresa_id) do update set last_value=excluded.last_value;
insert into public.empleados(
  id,empresa_id,codigo_empleado,nombre_completo,telefono,activo
) values
 ('22000000-0000-0000-0000-000000000021','22000000-0000-0000-0000-000000000010','022001','Gestor Accesos','8095550001',true),
 ('22000000-0000-0000-0000-000000000022','22000000-0000-0000-0000-000000000010','022002','Administrador Unico','8095550002',true),
 ('22000000-0000-0000-0000-000000000023','22000000-0000-0000-0000-000000000010','022003','Nombre Oficial Empleado','8095550003',true);
insert into public.profiles(id,company_id,role_id,employee_code,full_name,status) values
 ('22000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000010','22000000-0000-0000-0000-000000000011','022001','Gestor Accesos','active'),
 ('22000000-0000-0000-0000-000000000002','22000000-0000-0000-0000-000000000010','22000000-0000-0000-0000-000000000012','022002','Administrador Unico','active');
update public.empleados
set perfil_id=case id
  when '22000000-0000-0000-0000-000000000021'::uuid
    then '22000000-0000-0000-0000-000000000001'::uuid
  when '22000000-0000-0000-0000-000000000022'::uuid
    then '22000000-0000-0000-0000-000000000002'::uuid
end
where id in(
  '22000000-0000-0000-0000-000000000021',
  '22000000-0000-0000-0000-000000000022'
);

insert into public.permisos(codigo,nombre,modulo,activo)
values('usuarios.administrar','Administrar usuarios','administracion',true)
on conflict(codigo) do update set activo=true;

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select '22000000-0000-0000-0000-000000000011',p.id,true,'empresa'
from public.permisos p where p.codigo='usuarios.administrar'
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

select is(
  (public.crear_acceso_internal(jsonb_build_object(
    'actor_user_id','22000000-0000-0000-0000-000000000001',
    'company_id','22000000-0000-0000-0000-000000000010',
    'user_id','22000000-0000-0000-0000-000000000003',
    'employee_id','22000000-0000-0000-0000-000000000023',
    'role_id','22000000-0000-0000-0000-000000000013',
    'status','active',
    'full_name','DATO CLIENTE NO CONFIABLE'
  ))).id,
  '22000000-0000-0000-0000-000000000003'::uuid,
  'crea el acceso para la identidad Auth indicada'
);
select is(
  (select full_name from public.profiles where id='22000000-0000-0000-0000-000000000003'),
  'Nombre Oficial Empleado',
  'los datos personales proceden del empleado y no del payload'
);
select is(
  (select perfil_id from public.empleados where id='22000000-0000-0000-0000-000000000023'),
  '22000000-0000-0000-0000-000000000003'::uuid,
  'empleado y acceso quedan enlazados 1:1'
);
select throws_ok(
  $$select public.crear_acceso_internal(jsonb_build_object(
    'actor_user_id','22000000-0000-0000-0000-000000000001',
    'company_id','22000000-0000-0000-0000-000000000010',
    'user_id','22000000-0000-0000-0000-000000000004',
    'employee_id','22000000-0000-0000-0000-000000000023',
    'role_id','22000000-0000-0000-0000-000000000013',
    'status','active'
  ))$$,
  'P0001','EMPLEADO_YA_TIENE_ACCESO',
  'un empleado no puede recibir un segundo acceso'
);
select throws_ok(
  $$select public.eliminar_acceso_internal(jsonb_build_object(
    'actor_user_id','22000000-0000-0000-0000-000000000001',
    'company_id','22000000-0000-0000-0000-000000000010',
    'profile_id','22000000-0000-0000-0000-000000000001'
  ))$$,
  'P0001','AUTO_ELIMINACION_NO_PERMITIDA',
  'el usuario actual no puede eliminarse'
);
select throws_ok(
  $$select public.eliminar_acceso_internal(jsonb_build_object(
    'actor_user_id','22000000-0000-0000-0000-000000000001',
    'company_id','22000000-0000-0000-0000-000000000010',
    'profile_id','22000000-0000-0000-0000-000000000002'
  ))$$,
  'P0001','ULTIMO_ADMINISTRADOR_NO_ELIMINABLE',
  'el ultimo administrador activo no puede eliminarse'
);
select is(
  (public.cambiar_estado_acceso_internal(jsonb_build_object(
    'actor_user_id','22000000-0000-0000-0000-000000000001',
    'company_id','22000000-0000-0000-0000-000000000010',
    'profile_id','22000000-0000-0000-0000-000000000003',
    'status','inactive'
  ))).status,
  'inactive',
  'un acceso ajeno puede desactivarse'
);
select is(
  (select status from public.profiles where id='22000000-0000-0000-0000-000000000003'),
  'inactive',
  'el estado se persiste en profiles'
);
select is(
  (public.eliminar_acceso_internal(jsonb_build_object(
    'actor_user_id','22000000-0000-0000-0000-000000000001',
    'company_id','22000000-0000-0000-0000-000000000010',
    'profile_id','22000000-0000-0000-0000-000000000003'
  )) ->> 'employee_preserved')::boolean,
  true,
  'la baja confirma que conserva al empleado'
);
select is((select count(*)::integer from auth.users where id='22000000-0000-0000-0000-000000000003'),1,'conserva Auth para que la Edge lo bloquee y anonimice sin romper historicos');
select is((select count(*)::integer from public.profiles where id='22000000-0000-0000-0000-000000000003' and status='inactive' and access_deleted_at is not null),1,'conserva un profile inactivo como referencia historica');
select is((select count(*)::integer from public.empleados where id='22000000-0000-0000-0000-000000000023'),1,'no elimina al empleado');
select is((select perfil_id from public.empleados where id='22000000-0000-0000-0000-000000000023'),null::uuid,'desvincula el acceso eliminado');
select is((select employee_code from public.profiles where id='22000000-0000-0000-0000-000000000003'),null::text,'libera el codigo para crear un nuevo acceso al mismo empleado');
select ok(
  exists (
    select 1 from public.user_provisioning_audit
    where target_user_id_snapshot='22000000-0000-0000-0000-000000000003'
      and target_user_id='22000000-0000-0000-0000-000000000003'
  ),
  'la auditoria de aprovisionamiento sobrevive a la baja logica'
);
select ok(
  exists (
    select 1 from public.administracion_auditoria
    where empresa_id='22000000-0000-0000-0000-000000000010'
      and accion='ELIMINAR_ACCESO'
      and entidad_id='22000000-0000-0000-0000-000000000003'
  ),
  'la eliminacion queda auditada sin borrar datos laborales'
);

select * from finish();
rollback;
