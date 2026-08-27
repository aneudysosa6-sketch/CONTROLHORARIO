-- Terminal biometric proofs are time-bound in the Edge handler and single-use in PostgreSQL.
alter table public.jornada_eventos
  add column if not exists biometric_proof_id uuid;

update public.jornada_eventos
set biometric_proof_id=(payload->>'biometric_proof_id')::uuid
where biometric_proof_id is null
  and coalesce(payload->>'biometric_proof_id','') ~*
    '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';

create unique index if not exists jornada_eventos_biometric_proof_once_0056
  on public.jornada_eventos(empresa_id,dispositivo_id,biometric_proof_id)
  where biometric_proof_id is not null;

create or replace function public.registrar_evento_jornada_dispositivo(payload jsonb) returns jsonb
language plpgsql security definer set search_path=public,pg_temp as $$
declare
 v_empresa uuid:=(payload->>'empresa_id')::uuid;
 v_empleado uuid:=(payload->>'empleado_id')::uuid;
 v_dispositivo uuid:=(payload->>'dispositivo_id')::uuid;
 v_fecha date:=(payload->>'fecha_laboral')::date;
 v_accion text:=payload->>'accion';
 v_ocurrido timestamptz:=(payload->>'ocurrido_en')::timestamptz;
 v_key uuid:=(payload->>'idempotency_key')::uuid;
 v_version bigint:=coalesce((payload->>'version_conocida')::bigint,0);
 v_proof_text text:=nullif(btrim(payload->>'biometric_proof_id'),'');
 v_proof uuid;
 v_jornada public.jornadas%rowtype;
 v_antes jsonb;
 v_nuevo_estado text;
 v_elapsed integer:=0;
 v_duplicate public.jornada_eventos%rowtype;
begin
 if coalesce((payload->>'contract_version')::int,0)<>1 then
   return jsonb_build_object('result','rejected','error_code','INVALID_CONTRACT');
 end if;

 select * into v_duplicate
 from public.jornada_eventos
 where empresa_id=v_empresa and idempotency_key=v_key;
 if found then
   select * into v_jornada from public.jornadas where id=v_duplicate.jornada_id;
   return jsonb_build_object('result','duplicate','remote',to_jsonb(v_jornada),'sync_version',v_jornada.version_sync);
 end if;

 if (payload->>'biometric_verified') is distinct from 'true'
    or v_proof_text is null
    or v_proof_text !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$' then
   return jsonb_build_object('result','rejected','error_code','BIOMETRIC_PROOF_REQUIRED');
 end if;
 v_proof:=v_proof_text::uuid;

 select * into v_duplicate
 from public.jornada_eventos
 where empresa_id=v_empresa
   and dispositivo_id=v_dispositivo
   and biometric_proof_id=v_proof;
 if found then
   return jsonb_build_object('result','rejected','error_code','BIOMETRIC_PROOF_REPLAY');
 end if;

 if not exists(
   select 1 from public.dispositivos_android
   where id=v_dispositivo and empresa_id=v_empresa and estado='activo'
 ) then
   return jsonb_build_object('result','rejected','error_code','DEVICE_REVOKED');
 end if;

 if not exists(
   select 1 from public.empleados
   where id=v_empleado and empresa_id=v_empresa and activo and jornada_habilitada
 ) then
   if exists(
     select 1 from public.empleados
     where id=v_empleado and empresa_id=v_empresa and activo
   ) then
     return jsonb_build_object('result','rejected','error_code','ATTENDANCE_DISABLED');
   end if;
   return jsonb_build_object('result','rejected','error_code','EMPLOYEE_INACTIVE');
 end if;

 select * into v_jornada
 from public.jornadas
 where empresa_id=v_empresa and empleado_id=v_empleado and fecha_laboral=v_fecha
 for update;

 if not found then
   if v_accion<>'INICIAR' then
     return jsonb_build_object('result','rejected','error_code','INVALID_TRANSITION');
   end if;
   insert into public.jornadas(
     empresa_id,empleado_id,dispositivo_id,fecha_laboral,estado,iniciado_en,origen,version_sync
   ) values(
     v_empresa,v_empleado,v_dispositivo,v_fecha,'EN_CURSO',v_ocurrido,'ANDROID',1
   ) returning * into v_jornada;
   v_antes:=null;
   v_nuevo_estado:='EN_CURSO';
 else
   v_antes:=to_jsonb(v_jornada);
   if v_jornada.version_sync<>v_version then
     insert into public.jornada_conflictos(
       empresa_id,jornada_id,operacion_idempotency_key,snapshot_local,snapshot_remoto,motivo
     ) values(
       v_empresa,v_jornada.id,v_key,payload,to_jsonb(v_jornada),'VERSION_CONFLICT'
     );
     insert into public.jornada_incidencias(
       empresa_id,jornada_id,empleado_id,tipo,severidad,mensaje
     ) values(
       v_empresa,v_jornada.id,v_empleado,'CONFLICTO','ALTA',
       'Conflicto de version pendiente de resolucion'
     );
     return jsonb_build_object(
       'result','conflict','error_code','VERSION_CONFLICT',
       'remote',to_jsonb(v_jornada),'sync_version',v_jornada.version_sync
     );
   end if;
   if v_jornada.estado='FINALIZADA' then
     return jsonb_build_object('result','rejected','error_code','ALREADY_FINALIZED','remote',to_jsonb(v_jornada));
   end if;
   v_nuevo_estado:=case
     when v_jornada.estado='EN_CURSO' and v_accion='PAUSAR' then 'EN_PAUSA'
     when v_jornada.estado='EN_PAUSA' and v_accion='REANUDAR' then 'EN_CURSO'
     when v_jornada.estado in('EN_CURSO','EN_PAUSA') and v_accion='FINALIZAR' then 'FINALIZADA'
     else null
   end;
   if v_nuevo_estado is null then
     return jsonb_build_object('result','rejected','error_code','INVALID_TRANSITION','remote',to_jsonb(v_jornada));
   end if;
   if v_jornada.estado='EN_CURSO' then
     v_elapsed:=greatest(
       0,
       floor(extract(epoch from(v_ocurrido-coalesce(v_jornada.pausa_finalizada_en,v_jornada.iniciado_en)))/60)::int
     );
   end if;
   if v_jornada.estado='EN_PAUSA' and v_jornada.pausa_iniciada_en is not null then
     v_jornada.minutos_pausa:=v_jornada.minutos_pausa+greatest(
       0,
       floor(extract(epoch from(v_ocurrido-v_jornada.pausa_iniciada_en))/60)::int
     );
   end if;
   update public.jornadas set
     estado=v_nuevo_estado,
     dispositivo_id=v_dispositivo,
     pausa_iniciada_en=case when v_accion='PAUSAR' then v_ocurrido else pausa_iniciada_en end,
     pausa_finalizada_en=case when v_accion='REANUDAR' then v_ocurrido else pausa_finalizada_en end,
     finalizado_en=case when v_accion='FINALIZAR' then v_ocurrido else finalizado_en end,
     minutos_trabajados=minutos_trabajados+v_elapsed,
     minutos_pausa=v_jornada.minutos_pausa,
     version_sync=version_sync+1,
     actualizada_en=now()
   where id=v_jornada.id
   returning * into v_jornada;
 end if;

 insert into public.jornada_eventos(
   jornada_id,empresa_id,empleado_id,dispositivo_id,accion,ocurrido_en,
   idempotency_key,payload,biometric_proof_id
 ) values(
   v_jornada.id,v_empresa,v_empleado,v_dispositivo,v_accion,v_ocurrido,
   v_key,payload-'empresa_id',v_proof
 );
 insert into public.jornada_auditoria(
   empresa_id,jornada_id,dispositivo_id,accion,antes,despues,origen
 ) values(
   v_empresa,v_jornada.id,v_dispositivo,v_accion,v_antes,to_jsonb(v_jornada),'ANDROID'
 );
 return jsonb_build_object(
   'result','accepted','remote',to_jsonb(v_jornada),'sync_version',v_jornada.version_sync
 );
exception when unique_violation then
 select * into v_duplicate
 from public.jornada_eventos
 where empresa_id=v_empresa and idempotency_key=v_key;
 if found then
   select * into v_jornada from public.jornadas where id=v_duplicate.jornada_id;
   return jsonb_build_object('result','duplicate','remote',to_jsonb(v_jornada),'sync_version',v_jornada.version_sync);
 end if;
 select * into v_duplicate
 from public.jornada_eventos
 where empresa_id=v_empresa
   and dispositivo_id=v_dispositivo
   and biometric_proof_id=v_proof;
 if found then
   return jsonb_build_object('result','rejected','error_code','BIOMETRIC_PROOF_REPLAY');
 end if;
 raise;
end $$;

revoke all on function public.registrar_evento_jornada_dispositivo(jsonb) from public,anon,authenticated;
grant execute on function public.registrar_evento_jornada_dispositivo(jsonb) to service_role;