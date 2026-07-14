begin;

alter table public.companies
 add column if not exists logo_url text,
 add column if not exists address text,
 add column if not exists email text,
 add column if not exists phone text,
 add column if not exists ui_preferences jsonb not null default '{"theme":"dark","density":"comfortable","primary":"#1689ff","accent":"#2dd4a3"}'::jsonb;
alter table public.companies
 add constraint companies_logo_url_length check(logo_url is null or char_length(logo_url)<=2048),
 add constraint companies_address_length check(address is null or char_length(btrim(address))<=500),
 add constraint companies_email_format check(email is null or email~*'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
 add constraint companies_phone_length check(phone is null or char_length(btrim(phone))between 7 and 30),
 add constraint companies_ui_preferences_object check(jsonb_typeof(ui_preferences)='object');

alter table public.branches add column if not exists timezone text;
alter table public.branches add constraint branches_timezone_not_blank check(timezone is null or char_length(btrim(timezone))>0);

insert into public.permisos(codigo,nombre,descripcion,modulo,activo) values
 ('configuracion.ver','Ver administración del sistema','Abre el centro de administración de la empresa.','configuracion',true),
 ('configuracion.empresa','Administrar empresa','Gestiona identidad y contacto de la empresa.','configuracion',true),
 ('configuracion.sucursales','Administrar sucursales','Gestiona sucursales de la empresa.','configuracion',true),
 ('configuracion.departamentos','Administrar departamentos','Gestiona departamentos y supervisores asignados.','configuracion',true),
 ('configuracion.cargos','Administrar cargos','Gestiona cargos laborales.','configuracion',true),
 ('configuracion.horarios','Administrar horarios','Gestiona horarios y calendario laboral.','configuracion',true),
 ('configuracion.jornadas','Administrar reglas de jornadas','Consulta reglas, pendientes e incidencias.','configuracion',true),
 ('configuracion.seguridad','Ver seguridad y auditoría','Consulta sesiones y auditoría administrativa.','configuracion',true),
 ('configuracion.apariencia','Administrar apariencia','Gestiona preferencias visuales de la empresa.','configuracion',true)
on conflict(codigo)do update set nombre=excluded.nombre,descripcion=excluded.descripcion,modulo=excluded.modulo,activo=true;

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'empresa' from public.roles r join public.permisos p on p.codigo like 'configuracion.%'
where r.code='admin'and r.is_active
on conflict(rol_id,permiso_id)do update set permitido=true,alcance='empresa';

create table public.administracion_auditoria(
 id bigint generated always as identity primary key,
 empresa_id uuid not null references public.companies(id)on delete restrict,
 actor_id uuid references public.profiles(id)on delete set null,
 seccion text not null,
 accion text not null,
 entidad text not null,
 entidad_id text,
 antes jsonb,
 despues jsonb,
 motivo text,
 fecha timestamptz not null default now()
);
create index administracion_auditoria_empresa_fecha_idx on public.administracion_auditoria(empresa_id,fecha desc);
alter table public.administracion_auditoria enable row level security;
revoke all on public.administracion_auditoria from public,anon,authenticated;
grant select on public.administracion_auditoria to authenticated;
grant all on public.administracion_auditoria to service_role;
create policy administracion_auditoria_select on public.administracion_auditoria for select to authenticated
 using(empresa_id=public.obtener_empresa_actual()and(public.tiene_permiso('configuracion.seguridad')or public.tiene_permiso('configuracion.administrar')));

create or replace function public.administracion_autorizada(p_permiso text)returns uuid
language plpgsql stable security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();
begin
 if v_empresa is null or not(public.tiene_permiso('configuracion.administrar')or public.tiene_permiso(p_permiso))then
  raise exception using errcode='42501',message='ADMIN_PERMISSION_DENIED',detail=coalesce(p_permiso,'');
 end if;
 return v_empresa;
end $$;
revoke all on function public.administracion_autorizada(text)from public,anon;

create or replace function public.obtener_administracion_sistema()returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_company jsonb;v_result jsonb;
begin
 if v_empresa is null or not(public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.ver'))then raise exception using errcode='42501',message='ADMIN_PERMISSION_DENIED';end if;
 select to_jsonb(c)into v_company from public.companies c where c.id=v_empresa;
 select jsonb_build_object(
  'company',v_company,
  'sections',jsonb_build_object(
   'empresa',public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.empresa'),
   'sucursales',public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.sucursales'),
   'departamentos',public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.departamentos'),
   'cargos',public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.cargos'),
   'usuarios',public.tiene_permiso('usuarios.administrar')or public.tiene_permiso('roles.administrar')or public.tiene_permiso('permisos.administrar'),
   'horarios',public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.horarios'),
   'jornadas',public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.jornadas'),
   'dispositivos',public.tiene_permiso('dispositivos.ver'),
   'seguridad',public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.seguridad'),
   'apariencia',public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.apariencia')
  ),
  'counts',jsonb_build_object(
   'branches',(select count(*)from public.branches where company_id=v_empresa),
   'departments',(select count(*)from public.departments where company_id=v_empresa),
   'positions',(select count(*)from public.positions where company_id=v_empresa),
   'profiles',(select count(*)from public.profiles where company_id=v_empresa),
   'schedules',(select count(*)from public.horarios_empleados where empresa_id=v_empresa and activo),
   'pending_journeys',(select count(*)from public.jornadas where empresa_id=v_empresa and revision_pendiente),
   'devices',(select count(*)from public.dispositivos_android where empresa_id=v_empresa and estado<>'revocado'),
   'audit_events',(select count(*)from public.administracion_auditoria where empresa_id=v_empresa)
  ),
  'session',jsonb_build_object('auth_uid',auth.uid(),'company_id',v_empresa,'role',public.obtener_rol_actual())
 )into v_result;
 return v_result;
end $$;

create or replace function public.actualizar_empresa_administracion(p_datos jsonb,p_motivo text)returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.administracion_autorizada('configuracion.empresa');v_antes jsonb;v_despues jsonb;
begin
 if btrim(coalesce(p_datos->>'name',''))=''or btrim(coalesce(p_datos->>'timezone',''))=''then raise exception 'DATOS_EMPRESA_INVALIDOS';end if;
 if btrim(coalesce(p_motivo,''))=''then raise exception 'MOTIVO_REQUERIDO';end if;
 select to_jsonb(c)into v_antes from public.companies c where id=v_empresa for update;
 update public.companies set name=btrim(p_datos->>'name'),legal_name=nullif(btrim(p_datos->>'legal_name'),''),tax_id=nullif(btrim(p_datos->>'tax_id'),''),logo_url=nullif(btrim(p_datos->>'logo_url'),''),address=nullif(btrim(p_datos->>'address'),''),email=nullif(lower(btrim(p_datos->>'email')),''),phone=nullif(btrim(p_datos->>'phone'),''),timezone=btrim(p_datos->>'timezone'),updated_at=now()where id=v_empresa returning to_jsonb(companies)into v_despues;
 insert into public.administracion_auditoria(empresa_id,actor_id,seccion,accion,entidad,entidad_id,antes,despues,motivo)values(v_empresa,auth.uid(),'empresa','ACTUALIZAR','companies',v_empresa::text,v_antes,v_despues,btrim(p_motivo));
 return v_despues;
end $$;

create or replace function public.guardar_sucursal_administracion(p_id uuid,p_datos jsonb,p_motivo text)returns uuid
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.administracion_autorizada('configuracion.sucursales');v_id uuid;v_antes jsonb;v_despues jsonb;
begin
 if btrim(coalesce(p_datos->>'name',''))=''or btrim(coalesce(p_datos->>'code',''))=''or btrim(coalesce(p_motivo,''))=''then raise exception 'SUCURSAL_INVALIDA';end if;
 if p_id is null then
  insert into public.branches(company_id,name,code,address,phone,email,status,timezone)values(v_empresa,btrim(p_datos->>'name'),upper(btrim(p_datos->>'code')),nullif(btrim(p_datos->>'address'),''),nullif(btrim(p_datos->>'phone'),''),nullif(lower(btrim(p_datos->>'email')),''),coalesce(nullif(p_datos->>'status',''),'active'),nullif(btrim(p_datos->>'timezone'),''))returning id,to_jsonb(branches)into v_id,v_despues;
 else
  select to_jsonb(b)into v_antes from public.branches b where company_id=v_empresa and id=p_id for update;if v_antes is null then raise exception 'SUCURSAL_NO_ENCONTRADA';end if;
  update public.branches set name=btrim(p_datos->>'name'),code=upper(btrim(p_datos->>'code')),address=nullif(btrim(p_datos->>'address'),''),phone=nullif(btrim(p_datos->>'phone'),''),email=nullif(lower(btrim(p_datos->>'email')),''),status=coalesce(nullif(p_datos->>'status',''),'active'),timezone=nullif(btrim(p_datos->>'timezone'),''),updated_at=now()where company_id=v_empresa and id=p_id returning id,to_jsonb(branches)into v_id,v_despues;
 end if;
 insert into public.administracion_auditoria(empresa_id,actor_id,seccion,accion,entidad,entidad_id,antes,despues,motivo)values(v_empresa,auth.uid(),'sucursales',case when p_id is null then'CREAR'else'ACTUALIZAR'end,'branches',v_id::text,v_antes,v_despues,btrim(p_motivo));return v_id;
end $$;

create or replace function public.guardar_departamento_administracion(p_id uuid,p_datos jsonb,p_supervisor uuid,p_motivo text)returns uuid
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.administracion_autorizada('configuracion.departamentos');v_id uuid;v_branch uuid:=nullif(p_datos->>'branch_id','')::uuid;v_antes jsonb;v_despues jsonb;
begin
 if btrim(coalesce(p_datos->>'name',''))=''or btrim(coalesce(p_datos->>'code',''))=''or btrim(coalesce(p_motivo,''))=''then raise exception 'DEPARTAMENTO_INVALIDO';end if;
 if v_branch is not null and not exists(select 1 from public.branches where company_id=v_empresa and id=v_branch)then raise exception 'SUCURSAL_INVALIDA';end if;
 if p_id is null then insert into public.departments(company_id,branch_id,name,code,description,is_active)values(v_empresa,v_branch,btrim(p_datos->>'name'),upper(btrim(p_datos->>'code')),nullif(btrim(p_datos->>'description'),''),coalesce((p_datos->>'is_active')::boolean,true))returning id,to_jsonb(departments)into v_id,v_despues;
 else select to_jsonb(d)into v_antes from public.departments d where company_id=v_empresa and id=p_id for update;if v_antes is null then raise exception 'DEPARTAMENTO_NO_ENCONTRADO';end if;update public.departments set branch_id=v_branch,name=btrim(p_datos->>'name'),code=upper(btrim(p_datos->>'code')),description=nullif(btrim(p_datos->>'description'),''),is_active=coalesce((p_datos->>'is_active')::boolean,true),updated_at=now()where company_id=v_empresa and id=p_id returning id,to_jsonb(departments)into v_id,v_despues;end if;
 delete from public.perfil_departamentos pd using public.profiles pr
 where pd.perfil_id=pr.id and pd.departamento_id=v_id and pr.company_id=v_empresa;
 if p_supervisor is not null then
  if not exists(select 1 from public.profiles p join public.roles r on r.id=p.role_id and r.company_id=p.company_id where p.company_id=v_empresa and p.id=p_supervisor and p.status='active'and r.code='supervisor')then raise exception 'SUPERVISOR_INVALIDO';end if;
  insert into public.perfil_departamentos(perfil_id,departamento_id)values(p_supervisor,v_id)on conflict do nothing;
 end if;
 insert into public.administracion_auditoria(empresa_id,actor_id,seccion,accion,entidad,entidad_id,antes,despues,motivo)values(v_empresa,auth.uid(),'departamentos',case when p_id is null then'CREAR'else'ACTUALIZAR'end,'departments',v_id::text,v_antes,v_despues,btrim(p_motivo));return v_id;
end $$;

create or replace function public.guardar_cargo_administracion(p_id uuid,p_datos jsonb,p_motivo text)returns uuid
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.administracion_autorizada('configuracion.cargos');v_id uuid;v_department uuid:=nullif(p_datos->>'department_id','')::uuid;v_antes jsonb;v_despues jsonb;
begin
 if btrim(coalesce(p_datos->>'name',''))=''or btrim(coalesce(p_datos->>'code',''))=''or btrim(coalesce(p_motivo,''))=''then raise exception 'CARGO_INVALIDO';end if;
 if v_department is not null and not exists(select 1 from public.departments where company_id=v_empresa and id=v_department)then raise exception 'DEPARTAMENTO_INVALIDO';end if;
 if p_id is null then insert into public.positions(company_id,department_id,name,code,description,level,is_active)values(v_empresa,v_department,btrim(p_datos->>'name'),upper(btrim(p_datos->>'code')),nullif(btrim(p_datos->>'description'),''),coalesce((p_datos->>'level')::smallint,1),coalesce((p_datos->>'is_active')::boolean,true))returning id,to_jsonb(positions)into v_id,v_despues;
 else select to_jsonb(p)into v_antes from public.positions p where company_id=v_empresa and id=p_id for update;if v_antes is null then raise exception 'CARGO_NO_ENCONTRADO';end if;update public.positions set department_id=v_department,name=btrim(p_datos->>'name'),code=upper(btrim(p_datos->>'code')),description=nullif(btrim(p_datos->>'description'),''),level=coalesce((p_datos->>'level')::smallint,1),is_active=coalesce((p_datos->>'is_active')::boolean,true),updated_at=now()where company_id=v_empresa and id=p_id returning id,to_jsonb(positions)into v_id,v_despues;end if;
 insert into public.administracion_auditoria(empresa_id,actor_id,seccion,accion,entidad,entidad_id,antes,despues,motivo)values(v_empresa,auth.uid(),'cargos',case when p_id is null then'CREAR'else'ACTUALIZAR'end,'positions',v_id::text,v_antes,v_despues,btrim(p_motivo));return v_id;
end $$;

create or replace function public.actualizar_estado_usuario_administracion(p_perfil uuid,p_estado text,p_motivo text)returns void
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_antes jsonb;v_despues jsonb;
begin
 if not public.tiene_permiso('usuarios.administrar')then raise exception using errcode='42501',message='ADMIN_PERMISSION_DENIED';end if;
 if p_perfil=auth.uid()then raise exception 'AUTO_DESACTIVACION_NO_PERMITIDA';end if;if p_estado not in('active','inactive','suspended')or btrim(coalesce(p_motivo,''))=''then raise exception 'ESTADO_USUARIO_INVALIDO';end if;
 select to_jsonb(p)into v_antes from public.profiles p where company_id=v_empresa and id=p_perfil for update;if v_antes is null then raise exception 'USUARIO_NO_ENCONTRADO';end if;
 update public.profiles set status=p_estado,updated_at=now()where company_id=v_empresa and id=p_perfil returning to_jsonb(profiles)into v_despues;
 insert into public.administracion_auditoria(empresa_id,actor_id,seccion,accion,entidad,entidad_id,antes,despues,motivo)values(v_empresa,auth.uid(),'usuarios','CAMBIAR_ESTADO','profiles',p_perfil::text,v_antes,v_despues,btrim(p_motivo));
end $$;

create or replace function public.guardar_rol_administracion(p_id uuid,p_nombre text,p_codigo text,p_descripcion text,p_activo boolean,p_motivo text)returns uuid
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_id uuid;v_antes jsonb;v_despues jsonb;
begin
 if not public.tiene_permiso('roles.administrar')then raise exception using errcode='42501',message='ADMIN_PERMISSION_DENIED';end if;
 if btrim(coalesce(p_nombre,''))=''or btrim(coalesce(p_codigo,''))=''or btrim(coalesce(p_motivo,''))=''then raise exception 'ROL_INVALIDO';end if;
 if p_id is null then insert into public.roles(company_id,name,code,description,is_active)values(v_empresa,btrim(p_nombre),lower(btrim(p_codigo)),nullif(btrim(p_descripcion),''),coalesce(p_activo,true))returning id,to_jsonb(roles)into v_id,v_despues;
 else select to_jsonb(r)into v_antes from public.roles r where company_id=v_empresa and id=p_id for update;if v_antes is null then raise exception 'ROL_NO_ENCONTRADO';end if;update public.roles set name=btrim(p_nombre),description=nullif(btrim(p_descripcion),''),is_active=coalesce(p_activo,true),updated_at=now()where company_id=v_empresa and id=p_id returning id,to_jsonb(roles)into v_id,v_despues;end if;
 insert into public.administracion_auditoria(empresa_id,actor_id,seccion,accion,entidad,entidad_id,antes,despues,motivo)values(v_empresa,auth.uid(),'usuarios',case when p_id is null then'CREAR_ROL'else'ACTUALIZAR_ROL'end,'roles',v_id::text,v_antes,v_despues,btrim(p_motivo));return v_id;
end $$;

create or replace function public.asignar_permiso_rol_administracion(p_rol uuid,p_permiso uuid,p_permitido boolean,p_motivo text)returns void
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_antes jsonb;v_despues jsonb;
begin
 if not public.tiene_permiso('permisos.administrar')then raise exception using errcode='42501',message='ADMIN_PERMISSION_DENIED';end if;
 if btrim(coalesce(p_motivo,''))=''or not exists(select 1 from public.roles where company_id=v_empresa and id=p_rol)or not exists(select 1 from public.permisos where id=p_permiso and activo)then raise exception 'ASIGNACION_PERMISO_INVALIDA';end if;
 select to_jsonb(rp)into v_antes from public.rol_permisos rp where rol_id=p_rol and permiso_id=p_permiso;
 insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)values(p_rol,p_permiso,p_permitido,'empresa')on conflict(rol_id,permiso_id)do update set permitido=excluded.permitido,alcance=excluded.alcance returning to_jsonb(rol_permisos)into v_despues;
 insert into public.administracion_auditoria(empresa_id,actor_id,seccion,accion,entidad,entidad_id,antes,despues,motivo)values(v_empresa,auth.uid(),'usuarios','ASIGNAR_PERMISO','rol_permisos',p_rol::text||':'||p_permiso::text,v_antes,v_despues,btrim(p_motivo));
end $$;

create or replace function public.actualizar_rol_usuario_administracion(p_perfil uuid,p_rol uuid,p_motivo text)returns void
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_antes jsonb;v_despues jsonb;
begin
 if not public.tiene_permiso('usuarios.administrar')then raise exception using errcode='42501',message='ADMIN_PERMISSION_DENIED';end if;
 if p_perfil=auth.uid()then raise exception 'AUTO_CAMBIO_ROL_NO_PERMITIDO';end if;if btrim(coalesce(p_motivo,''))=''or not exists(select 1 from public.roles where company_id=v_empresa and id=p_rol and is_active)then raise exception 'ROL_USUARIO_INVALIDO';end if;
 select to_jsonb(p)into v_antes from public.profiles p where company_id=v_empresa and id=p_perfil for update;if v_antes is null then raise exception 'USUARIO_NO_ENCONTRADO';end if;
 update public.profiles set role_id=p_rol,updated_at=now()where company_id=v_empresa and id=p_perfil returning to_jsonb(profiles)into v_despues;
 insert into public.administracion_auditoria(empresa_id,actor_id,seccion,accion,entidad,entidad_id,antes,despues,motivo)values(v_empresa,auth.uid(),'usuarios','CAMBIAR_ROL','profiles',p_perfil::text,v_antes,v_despues,btrim(p_motivo));
end $$;

create or replace function public.actualizar_apariencia_administracion(p_preferencias jsonb,p_motivo text)returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.administracion_autorizada('configuracion.apariencia');v_antes jsonb;v_despues jsonb;
begin
 if jsonb_typeof(p_preferencias)<>'object'or coalesce(p_preferencias->>'theme','')not in('dark','system')or coalesce(p_preferencias->>'density','')not in('comfortable','compact')or btrim(coalesce(p_motivo,''))=''then raise exception 'APARIENCIA_INVALIDA';end if;
 select ui_preferences into v_antes from public.companies where id=v_empresa for update;update public.companies set ui_preferences=p_preferencias,updated_at=now()where id=v_empresa returning ui_preferences into v_despues;
 insert into public.administracion_auditoria(empresa_id,actor_id,seccion,accion,entidad,entidad_id,antes,despues,motivo)values(v_empresa,auth.uid(),'apariencia','ACTUALIZAR','companies',v_empresa::text,v_antes,v_despues,btrim(p_motivo));return v_despues;
end $$;

drop policy if exists companies_update_by_admin on public.companies;
create policy companies_update_by_permission on public.companies for update to authenticated using(id=public.obtener_empresa_actual()and(public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.empresa')or public.tiene_permiso('configuracion.apariencia')))with check(id=public.obtener_empresa_actual()and(public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.empresa')or public.tiene_permiso('configuracion.apariencia')));
drop policy if exists branches_manage_by_admin on public.branches;
create policy branches_manage_by_permission on public.branches for all to authenticated using(company_id=public.obtener_empresa_actual()and(public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.sucursales')))with check(company_id=public.obtener_empresa_actual()and(public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.sucursales')));
drop policy if exists departments_manage_by_admin_or_hr on public.departments;
create policy departments_manage_by_permission on public.departments for all to authenticated using(company_id=public.obtener_empresa_actual()and(public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.departamentos')))with check(company_id=public.obtener_empresa_actual()and(public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.departamentos')));
drop policy if exists positions_manage_by_admin_or_hr on public.positions;
create policy positions_manage_by_permission on public.positions for all to authenticated using(company_id=public.obtener_empresa_actual()and(public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.cargos')))with check(company_id=public.obtener_empresa_actual()and(public.tiene_permiso('configuracion.administrar')or public.tiene_permiso('configuracion.cargos')));

revoke all on function public.obtener_administracion_sistema(),public.actualizar_empresa_administracion(jsonb,text),public.guardar_sucursal_administracion(uuid,jsonb,text),public.guardar_departamento_administracion(uuid,jsonb,uuid,text),public.guardar_cargo_administracion(uuid,jsonb,text),public.actualizar_estado_usuario_administracion(uuid,text,text),public.guardar_rol_administracion(uuid,text,text,text,boolean,text),public.asignar_permiso_rol_administracion(uuid,uuid,boolean,text),public.actualizar_rol_usuario_administracion(uuid,uuid,text),public.actualizar_apariencia_administracion(jsonb,text)from public,anon;
grant execute on function public.obtener_administracion_sistema(),public.actualizar_empresa_administracion(jsonb,text),public.guardar_sucursal_administracion(uuid,jsonb,text),public.guardar_departamento_administracion(uuid,jsonb,uuid,text),public.guardar_cargo_administracion(uuid,jsonb,text),public.actualizar_estado_usuario_administracion(uuid,text,text),public.guardar_rol_administracion(uuid,text,text,text,boolean,text),public.asignar_permiso_rol_administracion(uuid,uuid,boolean,text),public.actualizar_rol_usuario_administracion(uuid,uuid,text),public.actualizar_apariencia_administracion(jsonb,text)to authenticated;

commit;
