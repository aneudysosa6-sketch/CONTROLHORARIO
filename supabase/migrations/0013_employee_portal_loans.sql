begin;

insert into public.permisos(codigo,nombre,modulo,activo) values
('empleado.perfil_ver','Ver perfil propio','empleado',true),
('empleado.ganancias_ver','Ver ganancias propias','empleado',true),
('empleado.prestamos_ver','Ver prestamos propios','empleado',true),
('empleado.prestamo_solicitar','Solicitar prestamo propio','empleado',true),
('prestamos.solicitudes_ver','Ver solicitudes de prestamos','prestamos',true),
('prestamos.solicitudes_revisar','Revisar solicitudes de prestamos','prestamos',true),
('prestamos.solicitudes_aceptar','Aceptar solicitudes de prestamos','prestamos',true),
('prestamos.solicitudes_denegar','Denegar solicitudes de prestamos','prestamos',true),
('prestamos.entrega_confirmar','Confirmar entrega de prestamos','prestamos',true)
on conflict(codigo) do update set nombre=excluded.nombre,modulo=excluded.modulo,activo=true;

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,case when r.code in('employee','empleado') then 'propio' else 'empresa' end
from public.roles r join public.permisos p on
 (r.code in('employee','empleado') and (p.codigo like 'empleado.%' or p.codigo='portal.acceder')) or
 (r.code='admin' and p.codigo like 'prestamos.%')
where r.is_active
on conflict(rol_id,permiso_id) do update set permitido=true,alcance=excluded.alcance;

create table public.prestamo_solicitudes(
 id uuid primary key default extensions.gen_random_uuid(),
 empresa_id uuid not null references public.companies(id) on delete restrict,
 empleado_id uuid not null,
 monto_solicitado numeric(14,2) not null check(monto_solicitado>0),
 descuento_periodo numeric(14,2) not null check(descuento_periodo>0 and descuento_periodo<=monto_solicitado),
 motivo text not null check(char_length(btrim(motivo)) between 3 and 1000),
 estado text not null default 'PENDIENTE_REVISION' check(estado in('PENDIENTE_REVISION','EN_REVISION','ACEPTADA','DENEGADA','EFECTIVO_CONFIRMADO','CANCELADA')),
 idempotency_key uuid not null,
 origen text not null default 'WEB' check(origen in('WEB','ANDROID')),
 observacion_revision text,
 creada_por uuid not null references public.profiles(id) on delete restrict,
 revisada_por uuid references public.profiles(id) on delete restrict,
 revisada_en timestamptz,
 confirmada_por uuid references public.profiles(id) on delete restrict,
 confirmada_en timestamptz,
 creada_en timestamptz not null default now(),
 actualizada_en timestamptz not null default now(),
 unique(empresa_id,id),unique(empresa_id,empleado_id,idempotency_key),
 foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict
);
create index prestamo_solicitudes_admin_idx on public.prestamo_solicitudes(empresa_id,estado,creada_en desc);

alter table public.nomina_prestamos add column solicitud_id uuid;
alter table public.nomina_prestamos add constraint nomina_prestamos_solicitud_fk foreign key(empresa_id,solicitud_id) references public.prestamo_solicitudes(empresa_id,id) on delete restrict;
create unique index nomina_prestamos_solicitud_uidx on public.nomina_prestamos(empresa_id,solicitud_id) where solicitud_id is not null;

create table public.prestamo_movimientos(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null references public.companies(id) on delete restrict,
 prestamo_id uuid not null,empleado_id uuid not null,descuento_id uuid,nomina_id uuid,periodo_id uuid,
 tipo text not null check(tipo in('ENTREGA','DESCUENTO_NOMINA','CANCELACION')),
 monto numeric(14,2) not null check(monto>=0),saldo_anterior numeric(14,2) not null check(saldo_anterior>=0),saldo_posterior numeric(14,2) not null check(saldo_posterior>=0),
 estado text not null,referencia text,creado_en timestamptz not null default now(),
 unique(empresa_id,id),unique(descuento_id),
 foreign key(empresa_id,prestamo_id) references public.nomina_prestamos(empresa_id,id) on delete restrict,
 foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict,
 foreign key(empresa_id,nomina_id) references public.nominas(empresa_id,id) on delete restrict,
 foreign key(empresa_id,periodo_id) references public.nomina_periodos(empresa_id,id) on delete restrict
);
create index prestamo_movimientos_empleado_idx on public.prestamo_movimientos(empresa_id,empleado_id,creado_en desc);

create table public.prestamo_solicitud_auditoria(
 id bigint generated always as identity primary key,empresa_id uuid not null references public.companies(id) on delete restrict,
 solicitud_id uuid not null,actor_id uuid references public.profiles(id) on delete set null,accion text not null,autorizado boolean not null,
 estado_anterior text,estado_nuevo text,motivo text,origen text not null,fecha timestamptz not null default now(),
 foreign key(empresa_id,solicitud_id) references public.prestamo_solicitudes(empresa_id,id) on delete restrict
);

alter table public.prestamo_solicitudes enable row level security;
alter table public.prestamo_movimientos enable row level security;
alter table public.prestamo_solicitud_auditoria enable row level security;
revoke all on public.prestamo_solicitudes,public.prestamo_movimientos,public.prestamo_solicitud_auditoria from anon,authenticated;
grant select on public.prestamo_solicitudes,public.prestamo_movimientos to authenticated;
grant all on public.prestamo_solicitudes,public.prestamo_movimientos,public.prestamo_solicitud_auditoria to service_role;
create policy prestamo_solicitudes_select on public.prestamo_solicitudes for select to authenticated using(
 empresa_id=public.obtener_empresa_actual() and (empleado_id=public.obtener_empleado_actual_id() or public.tiene_permiso('prestamos.solicitudes_ver'))
);
create policy prestamo_movimientos_select on public.prestamo_movimientos for select to authenticated using(
 empresa_id=public.obtener_empresa_actual() and (empleado_id=public.obtener_empleado_actual_id() or public.tiene_permiso('nomina.prestamos'))
);

create or replace function public.obtener_portal_empleado() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_empleado uuid:=public.obtener_empleado_actual_id();v_fecha date;v_inicio date;v_fin date;v_corte date;v_result jsonb;
begin
 if v_empresa is null or v_empleado is null then raise exception using errcode='42501',message='EMPLOYEE_PROFILE_REQUIRED';end if;
 if not(public.tiene_permiso('empleado.perfil_ver')or public.tiene_permiso('empleado.ganancias_ver')or public.tiene_permiso('empleado.prestamos_ver'))then raise exception using errcode='42501',message='EMPLOYEE_PORTAL_DENIED';end if;
 select (now() at time zone c.timezone)::date into v_fecha from public.companies c where c.id=v_empresa;
 if extract(day from v_fecha)between 1 and 14 then v_inicio:=least((date_trunc('month',v_fecha)-interval '1 month')::date+29,date_trunc('month',v_fecha)::date-1);v_fin:=date_trunc('month',v_fecha)::date+13;
 elsif extract(day from v_fecha)between 15 and 29 then v_inicio:=date_trunc('month',v_fecha)::date+14;v_fin:=date_trunc('month',v_fecha)::date+28;
 else v_inicio:=make_date(extract(year from v_fecha)::int,extract(month from v_fecha)::int,30);v_fin:=(date_trunc('month',v_fecha)+interval '1 month')::date+13;end if;
 v_corte:=least(v_fin,v_fecha-1);
 select jsonb_build_object(
  'perfil',jsonb_build_object('id',e.id,'codigo',e.codigo_empleado,'nombre',e.nombre_completo,'correo',e.correo,'telefono',e.telefono,'estado',e.estado_laboral,'fecha_ingreso',e.fecha_ingreso,'sucursal',b.name,'departamento',d.name,'puesto',po.name),
  'ganancias',jsonb_build_object('periodo_inicio',v_inicio,'periodo_fin',v_fin,'corte',v_corte,'minutos_normales',coalesce(g.normales,0),'minutos_extra',coalesce(g.extras,0),'pago_normal',round(coalesce(g.normales,0)/60*(e.salario/r.dias_divisor_quincenal/r.horas_dia),2),'pago_extra',round(coalesce(g.extras,0)/60*r.valor_hora_extra,2),'incentivo',r.incentivo_periodo,'total',round(coalesce(g.normales,0)/60*(e.salario/r.dias_divisor_quincenal/r.horas_dia)+coalesce(g.extras,0)/60*r.valor_hora_extra+r.incentivo_periodo,2),'formula','RC4_WORKED_MINUTES_V2'),
  'prestamos',coalesce((select jsonb_agg(jsonb_build_object('id',l.id,'monto_total',l.monto_total,'pagado',l.total_pagado,'pendiente',l.pendiente,'descuento_periodo',l.descuento_periodo,'estado',l.estado,'fecha_inicio',l.fecha_inicio,'motivo',l.motivo,'movimientos',coalesce((select jsonb_agg(to_jsonb(m)order by m.creado_en desc)from public.prestamo_movimientos m where m.empresa_id=l.empresa_id and m.prestamo_id=l.id),'[]'::jsonb))order by l.creado_en desc)from public.nomina_prestamos l where l.empresa_id=v_empresa and l.empleado_id=v_empleado),'[]'::jsonb),
  'solicitudes',coalesce((select jsonb_agg(to_jsonb(s)order by s.creada_en desc)from public.prestamo_solicitudes s where s.empresa_id=v_empresa and s.empleado_id=v_empleado),'[]'::jsonb)
 )into v_result
 from public.empleados e left join public.branches b on b.id=e.sucursal_id and b.company_id=e.empresa_id left join public.departments d on d.id=e.departamento_id and d.company_id=e.empresa_id left join public.positions po on po.id=e.puesto_id and po.company_id=e.empresa_id
 join public.nomina_reglas_empleado r on r.empresa_id=e.empresa_id and r.empleado_id=e.id and r.nomina_activa
 left join lateral(select sum(least(j.minutos_trabajados,(r.horas_dia*60)::int)) normales,sum(greatest(j.minutos_trabajados-(r.horas_dia*60)::int,0)) extras from public.jornadas j where j.empresa_id=e.empresa_id and j.empleado_id=e.id and j.fecha_laboral between v_inicio and v_corte and j.estado='FINALIZADA'and not j.revision_pendiente and not exists(select 1 from public.jornada_conflictos c where c.empresa_id=j.empresa_id and c.jornada_id=j.id and c.estado='PENDIENTE'))g on true
 where e.empresa_id=v_empresa and e.id=v_empleado;
 if v_result is null then raise exception 'EMPLOYEE_PAY_CONFIGURATION_REQUIRED';end if;return v_result;
end $$;

create or replace function public.crear_solicitud_prestamo(p_monto numeric,p_descuento numeric,p_motivo text,p_idempotency uuid,p_origen text default 'WEB')returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_empleado uuid:=public.obtener_empleado_actual_id();v_id uuid;v_row public.prestamo_solicitudes;
begin
 if v_empresa is null or v_empleado is null or not public.tiene_permiso('empleado.prestamo_solicitar')then raise exception using errcode='42501',message='EMPLOYEE_LOAN_REQUEST_DENIED';end if;
 if p_monto<=0 or p_descuento<=0 or p_descuento>p_monto or char_length(btrim(coalesce(p_motivo,'')))<3 or p_origen not in('WEB','ANDROID')then raise exception 'INVALID_LOAN_REQUEST';end if;
 insert into public.prestamo_solicitudes(empresa_id,empleado_id,monto_solicitado,descuento_periodo,motivo,idempotency_key,origen,creada_por)
 values(v_empresa,v_empleado,p_monto,p_descuento,btrim(p_motivo),p_idempotency,p_origen,auth.uid()) on conflict(empresa_id,empleado_id,idempotency_key)do nothing returning * into v_row;
 if v_row.id is null then select * into v_row from public.prestamo_solicitudes where empresa_id=v_empresa and empleado_id=v_empleado and idempotency_key=p_idempotency;end if;
 insert into public.prestamo_solicitud_auditoria(empresa_id,solicitud_id,actor_id,accion,autorizado,estado_nuevo,motivo,origen)values(v_empresa,v_row.id,auth.uid(),'CREAR',true,v_row.estado,v_row.motivo,p_origen) on conflict do nothing;
 insert into public.notificaciones_internas(empresa_id,empleado_id,tipo,mensaje,destinatario_perfil_id) select v_empresa,v_empleado,'PRESTAMO_SOLICITADO','Nueva solicitud de prestamo de '||p_monto,p.id from public.profiles p join public.roles r on r.id=p.role_id and r.company_id=p.company_id where p.company_id=v_empresa and p.status='active'and r.code='admin';
 return to_jsonb(v_row);
end $$;

create or replace function public.cancelar_solicitud_prestamo(p_solicitud uuid,p_origen text default 'WEB')returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_empleado uuid:=public.obtener_empleado_actual_id();v_s public.prestamo_solicitudes;
begin
 if v_empresa is null or v_empleado is null or not public.tiene_permiso('empleado.prestamo_solicitar')then raise exception using errcode='42501',message='EMPLOYEE_LOAN_REQUEST_DENIED';end if;
 select * into v_s from public.prestamo_solicitudes where empresa_id=v_empresa and empleado_id=v_empleado and id=p_solicitud for update;if not found then raise exception 'LOAN_REQUEST_NOT_FOUND';end if;
 if v_s.estado not in('PENDIENTE_REVISION','EN_REVISION')then raise exception 'LOAN_REQUEST_NOT_CANCELLABLE';end if;
 update public.prestamo_solicitudes set estado='CANCELADA',actualizada_en=now()where id=v_s.id;
 insert into public.prestamo_solicitud_auditoria(empresa_id,solicitud_id,actor_id,accion,autorizado,estado_anterior,estado_nuevo,motivo,origen)values(v_empresa,v_s.id,auth.uid(),'CANCELAR',true,v_s.estado,'CANCELADA','Cancelada por el empleado',p_origen);
 return jsonb_build_object('id',v_s.id,'estado','CANCELADA');
end $$;

create or replace function public.listar_solicitudes_prestamo_admin(p_estado text default null,p_busqueda text default null)returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_result jsonb;
begin
 if v_empresa is null or not public.tiene_permiso('prestamos.solicitudes_ver')then raise exception using errcode='42501',message='LOAN_REQUEST_LIST_DENIED';end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'empleado_id',s.empleado_id,'codigo',e.codigo_empleado,'empleado',e.nombre_completo,'monto_solicitado',s.monto_solicitado,'descuento_periodo',s.descuento_periodo,'motivo',s.motivo,'estado',s.estado,'origen',s.origen,'observacion_revision',s.observacion_revision,'creada_en',s.creada_en,'actualizada_en',s.actualizada_en,'prestamo_id',l.id)order by s.creada_en desc),'[]'::jsonb)into v_result from public.prestamo_solicitudes s join public.empleados e on e.empresa_id=s.empresa_id and e.id=s.empleado_id left join public.nomina_prestamos l on l.empresa_id=s.empresa_id and l.solicitud_id=s.id where s.empresa_id=v_empresa and(p_estado is null or s.estado=p_estado)and(p_busqueda is null or e.nombre_completo ilike'%'||p_busqueda||'%'or e.codigo_empleado ilike'%'||p_busqueda||'%');return v_result;
end $$;

create or replace function public.gestionar_solicitud_prestamo(p_solicitud uuid,p_accion text,p_motivo text,p_origen text default 'WEB')returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_s public.prestamo_solicitudes;v_nuevo text;v_permiso text;v_prestamo uuid;v_anterior text;
begin
 v_permiso:=case p_accion when'REVISAR'then'prestamos.solicitudes_revisar'when'ACEPTAR'then'prestamos.solicitudes_aceptar'when'DENEGAR'then'prestamos.solicitudes_denegar'when'CONFIRMAR_EFECTIVO'then'prestamos.entrega_confirmar'else null end;
 if v_empresa is null or v_permiso is null or not public.tiene_permiso(v_permiso)then raise exception using errcode='42501',message='LOAN_REQUEST_ACTION_DENIED',detail=coalesce(v_permiso,p_accion);end if;
 select * into v_s from public.prestamo_solicitudes where empresa_id=v_empresa and id=p_solicitud for update;if not found then raise exception 'LOAN_REQUEST_NOT_FOUND';end if;v_anterior:=v_s.estado;
 v_nuevo:=case when p_accion='REVISAR'and v_s.estado='PENDIENTE_REVISION'then'EN_REVISION'when p_accion='ACEPTAR'and v_s.estado in('PENDIENTE_REVISION','EN_REVISION')then'ACEPTADA'when p_accion='DENEGAR'and v_s.estado in('PENDIENTE_REVISION','EN_REVISION')then'DENEGADA'when p_accion='CONFIRMAR_EFECTIVO'and v_s.estado='ACEPTADA'then'EFECTIVO_CONFIRMADO'else null end;
 if v_nuevo is null then raise exception 'INVALID_LOAN_REQUEST_TRANSITION:%->%',v_s.estado,p_accion;end if;
 update public.prestamo_solicitudes set estado=v_nuevo,observacion_revision=nullif(btrim(p_motivo),''),revisada_por=case when p_accion<>'CONFIRMAR_EFECTIVO'then auth.uid()else revisada_por end,revisada_en=case when p_accion<>'CONFIRMAR_EFECTIVO'then now()else revisada_en end,confirmada_por=case when p_accion='CONFIRMAR_EFECTIVO'then auth.uid()else null end,confirmada_en=case when p_accion='CONFIRMAR_EFECTIVO'then now()else null end,actualizada_en=now()where id=v_s.id;
 if p_accion='CONFIRMAR_EFECTIVO'then
  if exists(select 1 from public.nomina_periodos where empresa_id=v_empresa and estado not in('CERRADA','ANULADA')and fecha_fin<(now()at time zone(select c.timezone from public.companies c where c.id=v_empresa))::date)then raise exception 'LOAN_PRIOR_PAYROLL_PERIOD_OPEN';end if;
  insert into public.nomina_prestamos(empresa_id,empleado_id,monto_total,pendiente,descuento_periodo,estado,fecha_inicio,motivo,creado_por,solicitud_id)values(v_empresa,v_s.empleado_id,v_s.monto_solicitado,v_s.monto_solicitado,v_s.descuento_periodo,'ENTREGADO',(now()at time zone(select c.timezone from public.companies c where c.id=v_empresa))::date,v_s.motivo,auth.uid(),v_s.id)returning id into v_prestamo;
  insert into public.prestamo_movimientos(empresa_id,prestamo_id,empleado_id,tipo,monto,saldo_anterior,saldo_posterior,estado,referencia)values(v_empresa,v_prestamo,v_s.empleado_id,'ENTREGA',v_s.monto_solicitado,0,v_s.monto_solicitado,'ENTREGADO','Solicitud '||v_s.id);
 end if;
 insert into public.prestamo_solicitud_auditoria(empresa_id,solicitud_id,actor_id,accion,autorizado,estado_anterior,estado_nuevo,motivo,origen)values(v_empresa,v_s.id,auth.uid(),p_accion,true,v_anterior,v_nuevo,nullif(btrim(p_motivo),''),p_origen);
 insert into public.notificaciones_internas(empresa_id,empleado_id,tipo,mensaje,destinatario_perfil_id)select v_empresa,v_s.empleado_id,'PRESTAMO_'||v_nuevo,'Tu solicitud de prestamo cambio a '||v_nuevo,e.perfil_id from public.empleados e where e.empresa_id=v_empresa and e.id=v_s.empleado_id and e.perfil_id is not null;
 return jsonb_build_object('id',v_s.id,'estado',v_nuevo,'prestamo_id',v_prestamo);
end $$;

create or replace function public.registrar_movimiento_descuento_prestamo()returns trigger language plpgsql security definer set search_path='' as $$
declare v_p public.nomina_prestamos;v_periodo uuid;begin
 if new.aplicado and not old.aplicado and new.prestamo_id is not null then select * into v_p from public.nomina_prestamos where empresa_id=new.empresa_id and id=new.prestamo_id;select periodo_id into v_periodo from public.nominas where empresa_id=new.empresa_id and id=new.nomina_id;insert into public.prestamo_movimientos(empresa_id,prestamo_id,empleado_id,descuento_id,nomina_id,periodo_id,tipo,monto,saldo_anterior,saldo_posterior,estado,referencia)values(new.empresa_id,new.prestamo_id,new.empleado_id,new.id,new.nomina_id,v_periodo,'DESCUENTO_NOMINA',new.monto,least(v_p.monto_total,v_p.pendiente+new.monto),v_p.pendiente,v_p.estado,'Nomina '||new.nomina_id)on conflict(descuento_id)do nothing;end if;return new;end $$;
create trigger nomina_descuento_movimiento_rc5 after update of aplicado on public.nomina_descuentos for each row execute function public.registrar_movimiento_descuento_prestamo();

revoke all on function public.obtener_portal_empleado(),public.crear_solicitud_prestamo(numeric,numeric,text,uuid,text),public.cancelar_solicitud_prestamo(uuid,text),public.listar_solicitudes_prestamo_admin(text,text),public.gestionar_solicitud_prestamo(uuid,text,text,text),public.registrar_movimiento_descuento_prestamo()from public,anon;
grant execute on function public.obtener_portal_empleado(),public.crear_solicitud_prestamo(numeric,numeric,text,uuid,text),public.cancelar_solicitud_prestamo(uuid,text),public.listar_solicitudes_prestamo_admin(text,text),public.gestionar_solicitud_prestamo(uuid,text,text,text)to authenticated;

comment on function public.obtener_portal_empleado()is 'Portal privado resuelto exclusivamente por auth.uid() -> profile -> empleado; excluye hoy y jornadas RC2 no elegibles.';
commit;
