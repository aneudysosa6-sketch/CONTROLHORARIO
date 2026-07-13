begin;

alter table public.empleados add column if not exists jornada_habilitada boolean not null default true;
create unique index if not exists empleados_empresa_id_unique on public.empleados(empresa_id,id);

insert into public.permisos(codigo,nombre,modulo,activo) values
('jornadas.ver_todas','Ver todas las jornadas','jornadas',true),
('jornadas.ver_asignadas','Ver jornadas asignadas','jornadas',true),
('jornadas.corregir','Corregir jornadas','jornadas',true),
('jornadas.aprobar_pendientes','Aprobar jornadas pendientes','jornadas',true),
('jornadas.exportar','Exportar jornadas','jornadas',true),
('jornadas.admin_off_on','Habilitar o deshabilitar jornadas','jornadas',true)
on conflict(codigo) do update set nombre=excluded.nombre,modulo=excluded.modulo,activo=true;

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'empresa' from public.roles r join public.permisos p on p.codigo like 'jornadas.%'
where r.code='admin' and r.is_active
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

create table public.jornadas(
 id uuid primary key default extensions.gen_random_uuid(), empresa_id uuid not null references public.companies(id) on delete restrict,
 empleado_id uuid not null, dispositivo_id uuid, fecha_laboral date not null,
 estado text not null default 'SIN_INICIAR' check(estado in('SIN_INICIAR','EN_CURSO','EN_PAUSA','FINALIZADA')),
 iniciado_en timestamptz, pausa_iniciada_en timestamptz, pausa_finalizada_en timestamptz, finalizado_en timestamptz,
 minutos_trabajados integer not null default 0 check(minutos_trabajados>=0), minutos_pausa integer not null default 0 check(minutos_pausa>=0),
 origen text not null default 'ANDROID', revision_pendiente boolean not null default false,
 severidad text not null default 'NINGUNA' check(severidad in('NINGUNA','INFORMATIVA','MEDIA','ALTA','CRITICA')),
 version_sync bigint not null default 0, creada_en timestamptz not null default now(), actualizada_en timestamptz not null default now(),
 creada_por uuid references public.profiles(id) on delete set null, actualizada_por uuid references public.profiles(id) on delete set null,
 unique(empresa_id,empleado_id,fecha_laboral), unique(empresa_id,id),
 foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict,
 foreign key(empresa_id,dispositivo_id) references public.dispositivos_android(empresa_id,id) on delete restrict
);
create index jornadas_empresa_fecha_idx on public.jornadas(empresa_id,fecha_laboral desc);
create index jornadas_empresa_empleado_idx on public.jornadas(empresa_id,empleado_id,fecha_laboral desc);
create index jornadas_empresa_estado_idx on public.jornadas(empresa_id,estado);
create index jornadas_revision_idx on public.jornadas(empresa_id,revision_pendiente) where revision_pendiente;
create index jornadas_actualizada_idx on public.jornadas(empresa_id,actualizada_en,id);

create table public.jornada_eventos(
 id uuid primary key default extensions.gen_random_uuid(), jornada_id uuid not null, empresa_id uuid not null,
 empleado_id uuid not null, dispositivo_id uuid, accion text not null check(accion in('INICIAR','PAUSAR','REANUDAR','FINALIZAR')),
 ocurrido_en timestamptz not null, idempotency_key uuid not null, payload jsonb not null default '{}'::jsonb,
 origen text not null default 'ANDROID', creado_en timestamptz not null default now(),
 unique(empresa_id,idempotency_key),
 foreign key(empresa_id,jornada_id) references public.jornadas(empresa_id,id) on delete restrict,
 foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict,
 foreign key(empresa_id,dispositivo_id) references public.dispositivos_android(empresa_id,id) on delete restrict
);
create index jornada_eventos_jornada_idx on public.jornada_eventos(empresa_id,jornada_id,ocurrido_en);

create table public.jornada_incidencias(
 id uuid primary key default extensions.gen_random_uuid(), empresa_id uuid not null references public.companies(id) on delete restrict,
 jornada_id uuid not null, empleado_id uuid not null, tipo text not null check(tipo in('TARDANZA','JORNADA_INCOMPLETA','ALMUERZO_EXCEDIDO','SALIDA_ANTICIPADA','CONFLICTO','JORNADA_PENDIENTE','JORNADA_DESHABILITADA','ERROR_SYNC')),
 severidad text not null check(severidad in('INFORMATIVA','MEDIA','ALTA','CRITICA')), minutos integer,
 mensaje text not null, leida boolean not null default false, resuelta boolean not null default false,
 creada_en timestamptz not null default now(), resuelta_en timestamptz, resuelta_por uuid references public.profiles(id) on delete set null,
 foreign key(empresa_id,jornada_id) references public.jornadas(empresa_id,id) on delete restrict,
 foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict
);
create index jornada_incidencias_nuevas_idx on public.jornada_incidencias(empresa_id,leida,resuelta,creada_en desc);

create table public.jornada_conflictos(
 id uuid primary key default extensions.gen_random_uuid(), empresa_id uuid not null references public.companies(id) on delete restrict,
 jornada_id uuid not null, operacion_idempotency_key uuid, snapshot_local jsonb not null, snapshot_remoto jsonb not null,
 motivo text not null, estado text not null default 'PENDIENTE' check(estado in('PENDIENTE','RESUELTO_LOCAL','RESUELTO_REMOTO','RESUELTO_MANUAL')),
 creado_en timestamptz not null default now(), resuelto_en timestamptz, resuelto_por uuid references public.profiles(id) on delete set null,
 foreign key(empresa_id,jornada_id) references public.jornadas(empresa_id,id) on delete restrict
);
create index jornada_conflictos_pendientes_idx on public.jornada_conflictos(empresa_id,estado,creado_en desc);

create table public.jornada_auditoria(
 id bigint generated always as identity primary key, empresa_id uuid not null references public.companies(id) on delete restrict,
 jornada_id uuid not null, actor_id uuid references public.profiles(id) on delete set null, dispositivo_id uuid,
 accion text not null, antes jsonb, despues jsonb, origen text not null, fecha timestamptz not null default now(),
 foreign key(empresa_id,jornada_id) references public.jornadas(empresa_id,id) on delete restrict,
 foreign key(empresa_id,dispositivo_id) references public.dispositivos_android(empresa_id,id) on delete restrict
);
create index jornada_auditoria_idx on public.jornada_auditoria(empresa_id,jornada_id,fecha desc);

alter table public.jornadas enable row level security;
alter table public.jornada_eventos enable row level security;
alter table public.jornada_incidencias enable row level security;
alter table public.jornada_conflictos enable row level security;
alter table public.jornada_auditoria enable row level security;

create or replace function public.puede_ver_jornada(p_empleado uuid) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
 select p_empleado=public.current_employee_id()
 or public.tiene_permiso('jornadas.ver_todas')
 or (public.tiene_permiso('jornadas.ver_asignadas') and exists(
   select 1 from public.empleados e where e.id=p_empleado and e.empresa_id=public.current_company_id() and e.supervisor_id=public.current_employee_id()
 ));
$$;
revoke all on function public.puede_ver_jornada(uuid) from public,anon;
grant execute on function public.puede_ver_jornada(uuid) to authenticated,service_role;

create policy jornadas_select_scope on public.jornadas for select to authenticated using(empresa_id=public.current_company_id() and public.puede_ver_jornada(empleado_id));
create policy jornada_eventos_select_scope on public.jornada_eventos for select to authenticated using(empresa_id=public.current_company_id() and public.puede_ver_jornada(empleado_id));
create policy jornada_incidencias_select_scope on public.jornada_incidencias for select to authenticated using(empresa_id=public.current_company_id() and public.puede_ver_jornada(empleado_id));
create policy jornada_conflictos_select_scope on public.jornada_conflictos for select to authenticated using(empresa_id=public.current_company_id() and exists(select 1 from public.jornadas j where j.id=jornada_id and public.puede_ver_jornada(j.empleado_id)));
create policy jornada_auditoria_select_scope on public.jornada_auditoria for select to authenticated using(empresa_id=public.current_company_id() and exists(select 1 from public.jornadas j where j.id=jornada_id and public.puede_ver_jornada(j.empleado_id)));
grant select on public.jornadas,public.jornada_eventos,public.jornada_incidencias,public.jornada_conflictos,public.jornada_auditoria to authenticated;
grant all on public.jornadas,public.jornada_eventos,public.jornada_incidencias,public.jornada_conflictos,public.jornada_auditoria to service_role;

create or replace function public.registrar_evento_jornada_dispositivo(payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare
 v_empresa uuid:=(payload->>'empresa_id')::uuid; v_empleado uuid:=(payload->>'empleado_id')::uuid; v_dispositivo uuid:=(payload->>'dispositivo_id')::uuid;
 v_fecha date:=(payload->>'fecha_laboral')::date; v_accion text:=payload->>'accion'; v_ocurrido timestamptz:=(payload->>'ocurrido_en')::timestamptz;
 v_key uuid:=(payload->>'idempotency_key')::uuid; v_version bigint:=coalesce((payload->>'version_conocida')::bigint,0); v_jornada public.jornadas%rowtype;
 v_antes jsonb; v_nuevo_estado text; v_elapsed integer:=0; v_duplicate public.jornada_eventos%rowtype;
begin
 if coalesce((payload->>'contract_version')::int,0)<>1 then return jsonb_build_object('result','rejected','error_code','INVALID_CONTRACT'); end if;
 select * into v_duplicate from public.jornada_eventos where empresa_id=v_empresa and idempotency_key=v_key;
 if found then select * into v_jornada from public.jornadas where id=v_duplicate.jornada_id; return jsonb_build_object('result','duplicate','remote',to_jsonb(v_jornada),'sync_version',v_jornada.version_sync); end if;
 if not exists(select 1 from public.dispositivos_android where id=v_dispositivo and empresa_id=v_empresa and estado='activo') then return jsonb_build_object('result','rejected','error_code','DEVICE_REVOKED'); end if;
 if not exists(select 1 from public.empleados where id=v_empleado and empresa_id=v_empresa and activo and jornada_habilitada) then
   if exists(select 1 from public.empleados where id=v_empleado and empresa_id=v_empresa and activo) then return jsonb_build_object('result','rejected','error_code','ATTENDANCE_DISABLED'); end if;
   return jsonb_build_object('result','rejected','error_code','EMPLOYEE_INACTIVE');
 end if;
 select * into v_jornada from public.jornadas where empresa_id=v_empresa and empleado_id=v_empleado and fecha_laboral=v_fecha for update;
 if not found then
   if v_accion<>'INICIAR' then return jsonb_build_object('result','rejected','error_code','INVALID_TRANSITION'); end if;
   insert into public.jornadas(empresa_id,empleado_id,dispositivo_id,fecha_laboral,estado,iniciado_en,origen,version_sync)
   values(v_empresa,v_empleado,v_dispositivo,v_fecha,'EN_CURSO',v_ocurrido,'ANDROID',1) returning * into v_jornada;
   v_antes:=null; v_nuevo_estado:='EN_CURSO';
 else
   v_antes:=to_jsonb(v_jornada);
   if v_jornada.version_sync<>v_version then
     insert into public.jornada_conflictos(empresa_id,jornada_id,operacion_idempotency_key,snapshot_local,snapshot_remoto,motivo)
     values(v_empresa,v_jornada.id,v_key,payload,to_jsonb(v_jornada),'VERSION_CONFLICT');
     insert into public.jornada_incidencias(empresa_id,jornada_id,empleado_id,tipo,severidad,mensaje) values(v_empresa,v_jornada.id,v_empleado,'CONFLICTO','ALTA','Conflicto de versión pendiente de resolución');
     return jsonb_build_object('result','conflict','error_code','VERSION_CONFLICT','remote',to_jsonb(v_jornada),'sync_version',v_jornada.version_sync);
   end if;
   if v_jornada.estado='FINALIZADA' then return jsonb_build_object('result','rejected','error_code','ALREADY_FINALIZED','remote',to_jsonb(v_jornada)); end if;
   v_nuevo_estado:=case when v_jornada.estado='EN_CURSO' and v_accion='PAUSAR' then 'EN_PAUSA' when v_jornada.estado='EN_PAUSA' and v_accion='REANUDAR' then 'EN_CURSO' when v_jornada.estado in('EN_CURSO','EN_PAUSA') and v_accion='FINALIZAR' then 'FINALIZADA' else null end;
   if v_nuevo_estado is null then return jsonb_build_object('result','rejected','error_code','INVALID_TRANSITION','remote',to_jsonb(v_jornada)); end if;
   if v_jornada.estado='EN_CURSO' then v_elapsed:=greatest(0,floor(extract(epoch from(v_ocurrido-coalesce(v_jornada.pausa_finalizada_en,v_jornada.iniciado_en)))/60)::int); end if;
   if v_jornada.estado='EN_PAUSA' and v_jornada.pausa_iniciada_en is not null then v_jornada.minutos_pausa:=v_jornada.minutos_pausa+greatest(0,floor(extract(epoch from(v_ocurrido-v_jornada.pausa_iniciada_en))/60)::int); end if;
   update public.jornadas set estado=v_nuevo_estado, dispositivo_id=v_dispositivo,
    pausa_iniciada_en=case when v_accion='PAUSAR' then v_ocurrido else pausa_iniciada_en end,
    pausa_finalizada_en=case when v_accion='REANUDAR' then v_ocurrido else pausa_finalizada_en end,
    finalizado_en=case when v_accion='FINALIZAR' then v_ocurrido else finalizado_en end,
    minutos_trabajados=minutos_trabajados+v_elapsed, minutos_pausa=v_jornada.minutos_pausa,
    version_sync=version_sync+1,actualizada_en=now() where id=v_jornada.id returning * into v_jornada;
 end if;
 insert into public.jornada_eventos(jornada_id,empresa_id,empleado_id,dispositivo_id,accion,ocurrido_en,idempotency_key,payload)
 values(v_jornada.id,v_empresa,v_empleado,v_dispositivo,v_accion,v_ocurrido,v_key,payload-'empresa_id');
 insert into public.jornada_auditoria(empresa_id,jornada_id,dispositivo_id,accion,antes,despues,origen)
 values(v_empresa,v_jornada.id,v_dispositivo,v_accion,v_antes,to_jsonb(v_jornada),'ANDROID');
 return jsonb_build_object('result','accepted','remote',to_jsonb(v_jornada),'sync_version',v_jornada.version_sync);
exception when unique_violation then
 select * into v_duplicate from public.jornada_eventos where empresa_id=v_empresa and idempotency_key=v_key;
 select * into v_jornada from public.jornadas where id=v_duplicate.jornada_id;
 return jsonb_build_object('result','duplicate','remote',to_jsonb(v_jornada),'sync_version',v_jornada.version_sync);
end $$;
revoke all on function public.registrar_evento_jornada_dispositivo(jsonb) from public,anon,authenticated;
grant execute on function public.registrar_evento_jornada_dispositivo(jsonb) to service_role;

create or replace function public.cerrar_jornadas_incompletas(p_empresa uuid,p_fecha date) returns integer
language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.jornadas%rowtype; n integer:=0; v_sev text; v_msg text;
begin
 for v in select * from public.jornadas where empresa_id=p_empresa and fecha_laboral=p_fecha and estado<>'FINALIZADA' for update loop
   if exists(select 1 from public.jornada_incidencias where jornada_id=v.id and tipo='JORNADA_INCOMPLETA') then continue; end if;
   if v.pausa_iniciada_en is null then v_sev:='CRITICA';v_msg:='Solo registró entrada.';v.minutos_trabajados:=0;
   elsif v.estado='EN_PAUSA' then v_sev:='ALTA';v_msg:='Inició pausa y no regresó.';
   else v_sev:='MEDIA';v_msg:='Regresó de pausa y no finalizó.'; end if;
   update public.jornadas set revision_pendiente=true,severidad=v_sev,minutos_trabajados=v.minutos_trabajados,actualizada_en=now(),version_sync=version_sync+1 where id=v.id;
   insert into public.jornada_incidencias(empresa_id,jornada_id,empleado_id,tipo,severidad,mensaje) values(p_empresa,v.id,v.empleado_id,'JORNADA_INCOMPLETA',v_sev,v_msg); n:=n+1;
 end loop; return n;
end $$;
revoke all on function public.cerrar_jornadas_incompletas(uuid,date) from public,anon,authenticated;
grant execute on function public.cerrar_jornadas_incompletas(uuid,date) to service_role;

create or replace function public.cerrar_jornadas_vencidas() returns integer language plpgsql security definer set search_path=public,pg_temp as $$
declare c record;n integer:=0;v_fecha date;
begin
 for c in select id,timezone from public.companies where status='active' loop
  v_fecha=((now() at time zone c.timezone)::date-1);n:=n+public.cerrar_jornadas_incompletas(c.id,v_fecha);
 end loop;return n;
end $$;
revoke all on function public.cerrar_jornadas_vencidas() from public,anon,authenticated;
grant execute on function public.cerrar_jornadas_vencidas() to service_role;

create or replace function public.evaluar_tardanza_jornada(p_jornada uuid,p_entrada_esperada timestamptz) returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.jornadas%rowtype;v_minutos integer;v_id uuid;
begin
 if p_entrada_esperada is null then return null;end if;select * into v from public.jornadas where id=p_jornada;if not found or v.iniciado_en is null then return null;end if;
 v_minutos:=floor(extract(epoch from(v.iniciado_en-p_entrada_esperada))/60)::int;if v_minutos<15 then return null;end if;
 insert into public.jornada_incidencias(empresa_id,jornada_id,empleado_id,tipo,severidad,minutos,mensaje) values(v.empresa_id,v.id,v.empleado_id,'TARDANZA','MEDIA',v_minutos,'Llegada tarde: '||v_minutos||' minutos') returning id into v_id;return v_id;
end $$;
revoke all on function public.evaluar_tardanza_jornada(uuid,timestamptz) from public,anon,authenticated;
grant execute on function public.evaluar_tardanza_jornada(uuid,timestamptz) to service_role;

create or replace function public.marcar_incidencia_jornada_leida(p_incidencia uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$
begin
 update public.jornada_incidencias i set leida=true where i.id=p_incidencia and i.empresa_id=public.current_company_id() and public.puede_ver_jornada(i.empleado_id);
end $$;
revoke all on function public.marcar_incidencia_jornada_leida(uuid) from public,anon;
grant execute on function public.marcar_incidencia_jornada_leida(uuid) to authenticated;

create or replace function public.resolver_jornada_pendiente(p_jornada uuid,p_decision text,p_motivo text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v public.jornadas%rowtype; v_antes jsonb;
begin
 if not public.tiene_permiso('jornadas.aprobar_pendientes') then raise exception 'PERMISSION_DENIED'; end if;
 if btrim(coalesce(p_motivo,''))='' then raise exception 'MOTIVO_REQUERIDO'; end if;
 if p_decision not in('APROBADA','RECHAZADA','CORREGIDA') then raise exception 'DECISION_INVALIDA'; end if;
 select * into v from public.jornadas where id=p_jornada and empresa_id=public.current_company_id() for update;if not found then raise exception 'JORNADA_NO_ENCONTRADA';end if;v_antes:=to_jsonb(v);
 update public.jornadas set revision_pendiente=false,actualizada_por=auth.uid(),actualizada_en=now(),version_sync=version_sync+1 where id=v.id returning * into v;
 update public.jornada_incidencias set resuelta=true,resuelta_en=now(),resuelta_por=auth.uid() where jornada_id=v.id and not resuelta;
 insert into public.jornada_auditoria(empresa_id,jornada_id,actor_id,accion,antes,despues,origen) values(v.empresa_id,v.id,auth.uid(),'RESOLVER_'||p_decision,v_antes,to_jsonb(v)||jsonb_build_object('motivo',p_motivo),'WEB');
end $$;
revoke all on function public.resolver_jornada_pendiente(uuid,text,text) from public,anon;
grant execute on function public.resolver_jornada_pendiente(uuid,text,text) to authenticated;

create or replace function public.establecer_jornada_habilitada(p_empleado uuid,p_habilitada boolean,p_motivo text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare v_empresa uuid:=public.current_company_id();v_fecha date;v_jornada uuid;v_tz text;
begin
 if not public.tiene_permiso('jornadas.admin_off_on') then raise exception 'PERMISSION_DENIED';end if;
 if btrim(coalesce(p_motivo,''))='' then raise exception 'MOTIVO_REQUERIDO';end if;
 update public.empleados set jornada_habilitada=p_habilitada,updated_at=now() where id=p_empleado and empresa_id=v_empresa;if not found then raise exception 'EMPLEADO_NO_ENCONTRADO';end if;
 if not p_habilitada then select timezone into v_tz from public.companies where id=v_empresa;v_fecha=(now() at time zone coalesce(v_tz,'America/Santo_Domingo'))::date;
  insert into public.jornadas(empresa_id,empleado_id,fecha_laboral,estado,origen) values(v_empresa,p_empleado,v_fecha,'SIN_INICIAR','WEB') on conflict(empresa_id,empleado_id,fecha_laboral)do update set actualizada_en=now() returning id into v_jornada;
  insert into public.jornada_incidencias(empresa_id,jornada_id,empleado_id,tipo,severidad,mensaje) values(v_empresa,v_jornada,p_empleado,'JORNADA_DESHABILITADA','ALTA','Tu registro de jornada está deshabilitado. Motivo: '||p_motivo);
 end if;
end $$;
revoke all on function public.establecer_jornada_habilitada(uuid,boolean,text) from public,anon;
grant execute on function public.establecer_jornada_habilitada(uuid,boolean,text) to authenticated;

commit;
