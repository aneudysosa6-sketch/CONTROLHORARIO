begin;

alter table public.jornadas add column sucursal_inicio_id uuid, add column sucursal_fin_id uuid;
alter table public.jornadas add constraint jornadas_inicio_branch_fk foreign key(empresa_id,sucursal_inicio_id) references public.branches(company_id,id) on delete restrict;
alter table public.jornadas add constraint jornadas_fin_branch_fk foreign key(empresa_id,sucursal_fin_id) references public.branches(company_id,id) on delete restrict;
alter table public.jornada_eventos add column sucursal_id uuid, add column comprobante_biometrico_id uuid, add column comprobante_emitido_en timestamptz, add column comprobante_expira_en timestamptz, add column origen_sincronizacion text not null default 'LOCAL' check(origen_sincronizacion in('LOCAL','SINCRONIZADO'));
alter table public.jornada_eventos add constraint jornada_eventos_branch_fk foreign key(empresa_id,sucursal_id) references public.branches(company_id,id) on delete restrict;
create unique index jornada_eventos_comprobante_unico on public.jornada_eventos(empresa_id,comprobante_biometrico_id) where comprobante_biometrico_id is not null;
create or replace function public.trg_completar_evento_jornada_p1() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_branch uuid:=nullif(new.payload->>'branch_id','')::uuid;
begin
 if coalesce(new.payload->>'biometric_verified','false')<>'true' then raise exception 'BIOMETRIC_PROOF_REQUIRED';end if;
 update public.jornada_eventos set sucursal_id=v_branch,comprobante_biometrico_id=(new.payload->>'biometric_proof_id')::uuid,comprobante_emitido_en=(new.payload->>'biometric_proof_issued_at')::timestamptz,comprobante_expira_en=(new.payload->>'biometric_proof_expires_at')::timestamptz,origen_sincronizacion='SINCRONIZADO' where id=new.id;
 update public.jornadas set sucursal_inicio_id=case when new.accion='INICIAR' then v_branch else sucursal_inicio_id end,sucursal_fin_id=case when new.accion='FINALIZAR' then v_branch else sucursal_fin_id end where id=new.jornada_id;
 return new;
end $$;
create trigger jornada_eventos_completar_p1 after insert on public.jornada_eventos for each row execute function public.trg_completar_evento_jornada_p1();

create table public.jornada_ganancias(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null references public.companies(id) on delete restrict,jornada_id uuid not null,empleado_id uuid not null,
 minutos_normales integer not null default 0,minutos_extra integer not null default 0,pago_normal numeric(14,2) not null default 0,pago_extra numeric(14,2) not null default 0,total numeric(14,2) not null default 0,
 estado text not null check(estado in('CALCULADA','REVISION_PENDIENTE')),motivo_revision text,calculada_en timestamptz not null default now(),actualizada_en timestamptz not null default now(),
 unique(empresa_id,jornada_id),foreign key(empresa_id,jornada_id) references public.jornadas(empresa_id,id) on delete restrict,foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict
);
alter table public.jornada_ganancias enable row level security;
create policy jornada_ganancias_select_scope on public.jornada_ganancias for select to authenticated using(empresa_id=public.obtener_empresa_actual() and public.puede_ver_jornada(empleado_id));
grant select on public.jornada_ganancias to authenticated; grant all on public.jornada_ganancias to service_role;

create or replace function public.calcular_ganancia_jornada(p_jornada uuid) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare j public.jornadas%rowtype;e record;r record;v_normal int;v_extra int;v_hour numeric;v_normal_pay numeric;v_extra_pay numeric;
begin
 select * into j from public.jornadas where id=p_jornada for update;if not found or j.estado<>'FINALIZADA' then return;end if;
 select salario into e from public.empleados where empresa_id=j.empresa_id and id=j.empleado_id;
 select dias_divisor_quincenal,horas_dia,valor_hora_extra,nomina_activa into r from public.nomina_reglas_empleado where empresa_id=j.empresa_id and empleado_id=j.empleado_id;
 if coalesce(e.salario,0)<=0 or r is null or not coalesce(r.nomina_activa,false) or coalesce(r.dias_divisor_quincenal,0)<=0 or coalesce(r.horas_dia,0)<=0 or coalesce(r.valor_hora_extra,0)<=0 then
  insert into public.jornada_ganancias(empresa_id,jornada_id,empleado_id,estado,motivo_revision) values(j.empresa_id,j.id,j.empleado_id,'REVISION_PENDIENTE','CONFIGURACION_SALARIAL_INCOMPLETA') on conflict(empresa_id,jornada_id)do update set estado='REVISION_PENDIENTE',motivo_revision='CONFIGURACION_SALARIAL_INCOMPLETA',actualizada_en=now();return;
 end if;
 v_normal:=least(j.minutos_trabajados,(r.horas_dia*60)::int);v_extra:=greatest(j.minutos_trabajados-(r.horas_dia*60)::int,0);v_hour:=round((e.salario/r.dias_divisor_quincenal)/r.horas_dia,4);v_normal_pay:=round(v_normal::numeric/60*v_hour,2);v_extra_pay:=round(v_extra::numeric/60*r.valor_hora_extra,2);
 insert into public.jornada_ganancias(empresa_id,jornada_id,empleado_id,minutos_normales,minutos_extra,pago_normal,pago_extra,total,estado,motivo_revision) values(j.empresa_id,j.id,j.empleado_id,v_normal,v_extra,v_normal_pay,v_extra_pay,v_normal_pay+v_extra_pay,'CALCULADA',null)
 on conflict(empresa_id,jornada_id)do update set minutos_normales=excluded.minutos_normales,minutos_extra=excluded.minutos_extra,pago_normal=excluded.pago_normal,pago_extra=excluded.pago_extra,total=excluded.total,estado='CALCULADA',motivo_revision=null,actualizada_en=now();
end $$;
create or replace function public.trg_calcular_ganancia_jornada() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$begin if new.estado='FINALIZADA' then perform public.calcular_ganancia_jornada(new.id);end if;return new;end $$;
create trigger jornadas_ganancias_al_finalizar after insert or update of estado,minutos_trabajados on public.jornadas for each row execute function public.trg_calcular_ganancia_jornada();

create or replace function public.corregir_jornada_30_dias(p_jornada uuid,p_cambios jsonb,p_motivo text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare j public.jornadas%rowtype;v_antes jsonb;v_tz text;
begin
 if not public.tiene_permiso('jornadas.corregir') then raise exception 'PERMISSION_DENIED';end if;if btrim(coalesce(p_motivo,''))=''then raise exception 'MOTIVO_REQUERIDO';end if;
 select timezone into v_tz from public.companies where id=public.obtener_empresa_actual();select * into j from public.jornadas where id=p_jornada and empresa_id=public.obtener_empresa_actual() for update;if not found then raise exception 'JORNADA_NO_ENCONTRADA';end if;
 if j.fecha_laboral < ((now() at time zone coalesce(v_tz,'America/Santo_Domingo'))::date-30) then raise exception 'JORNADA_FUERA_DE_30_DIAS';end if;v_antes:=to_jsonb(j);
 update public.jornadas set iniciado_en=coalesce((p_cambios->>'iniciado_en')::timestamptz,iniciado_en),finalizado_en=coalesce((p_cambios->>'finalizado_en')::timestamptz,finalizado_en),minutos_trabajados=coalesce((p_cambios->>'minutos_trabajados')::int,minutos_trabajados),minutos_pausa=coalesce((p_cambios->>'minutos_pausa')::int,minutos_pausa),actualizada_por=auth.uid(),actualizada_en=now(),version_sync=version_sync+1 where id=j.id;
 insert into public.jornada_auditoria(empresa_id,jornada_id,actor_id,accion,antes,despues,origen)select j.empresa_id,j.id,auth.uid(),'CORREGIR_30_DIAS',v_antes,to_jsonb(x)||jsonb_build_object('motivo',p_motivo),'WEB' from public.jornadas x where x.id=j.id;perform public.calcular_ganancia_jornada(j.id);
end $$;
revoke all on function public.corregir_jornada_30_dias(uuid,jsonb,text) from public,anon;grant execute on function public.corregir_jornada_30_dias(uuid,jsonb,text) to authenticated;

commit;
