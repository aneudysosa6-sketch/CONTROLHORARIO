begin;

alter table public.nomina_reglas_empleado
 alter column dias_divisor_quincenal set default 30,
 alter column horas_dia set default 8;
update public.nomina_reglas_empleado set dias_divisor_quincenal=30 where dias_divisor_quincenal is null or dias_divisor_quincenal=15;
alter table public.nomina_reglas_empleado
 add column valor_hora_extra numeric(14,4) not null default 0 check(valor_hora_extra>=0),
 add column descuento_fijo_quincenal numeric(14,2) not null default 0 check(descuento_fijo_quincenal>=0),
 add column descuento_fijo_motivo text,
 add column descuento_fijo_activo boolean not null default false,
 add column otros_descuentos_fijos numeric(14,2) not null default 0 check(otros_descuentos_fijos>=0),
 add column nomina_activa boolean not null default true;
update public.nomina_reglas_empleado set afp_modo='MONTO',sfs_modo='MONTO',otros_impuestos_modo='MONTO';
alter table public.nomina_detalles
 add column pago_normal numeric(14,2) not null default 0 check(pago_normal>=0),
 add column valor_hora_extra numeric(14,4) not null default 0 check(valor_hora_extra>=0),
 add column descuento_fijo numeric(14,2) not null default 0 check(descuento_fijo>=0);

create or replace function public.obtener_ficha_pago_empleado(p_empleado uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_result jsonb;
begin
 if v_empresa is null or not(public.tiene_permiso('empleados.ver_todos') and public.tiene_permiso('nomina.ver'))then raise exception using errcode='42501',message='PAYROLL_EMPLOYEE_PERMISSION_DENIED';end if;
 if not exists(select 1 from public.empleados where empresa_id=v_empresa and id=p_empleado)then raise exception 'EMPLEADO_NO_ENCONTRADO';end if;
 select jsonb_build_object(
  'config',coalesce((select to_jsonb(r) from public.nomina_reglas_empleado r where r.empresa_id=v_empresa and r.empleado_id=p_empleado),jsonb_build_object('empleado_id',p_empleado,'dias_divisor_quincenal',30,'horas_dia',8,'valor_hora_extra',0,'afp_valor',0,'sfs_valor',0,'otros_impuestos_valor',0,'incentivo_periodo',0,'descuento_fijo_quincenal',0,'descuento_fijo_motivo','','descuento_fijo_activo',false,'otros_descuentos_fijos',0,'nomina_activa',true)),
  'prestamos',coalesce((select jsonb_agg(to_jsonb(x)order by x.creado_en desc)from public.nomina_prestamos x where x.empresa_id=v_empresa and x.empleado_id=p_empleado),'[]'::jsonb),
  'creditos',coalesce((select jsonb_agg(to_jsonb(x)order by x.creado_en desc)from public.nomina_creditos x where x.empresa_id=v_empresa and x.empleado_id=p_empleado),'[]'::jsonb)
 )into v_result;return v_result;
end $$;

create or replace function public.guardar_ficha_pago_empleado(p_empleado uuid,p_config jsonb,p_motivo text)returns void
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_antes jsonb;v_despues jsonb;v_divisor numeric:=coalesce((p_config->>'dias_divisor_quincenal')::numeric,30);v_horas numeric:=coalesce((p_config->>'horas_dia')::numeric,8);
begin
 if v_empresa is null or not(public.tiene_permiso('empleados.editar')and public.tiene_permiso('nomina.editar'))then raise exception using errcode='42501',message='PAYROLL_EMPLOYEE_PERMISSION_DENIED';end if;
 if btrim(coalesce(p_motivo,''))=''or v_divisor<=0 or v_horas<=0 then raise exception 'CONFIGURACION_PAGO_INVALIDA';end if;
 if not exists(select 1 from public.empleados where empresa_id=v_empresa and id=p_empleado)then raise exception 'EMPLEADO_NO_ENCONTRADO';end if;
 select to_jsonb(r)into v_antes from public.nomina_reglas_empleado r where r.empresa_id=v_empresa and r.empleado_id=p_empleado;
 insert into public.nomina_reglas_empleado(empresa_id,empleado_id,dias_divisor_quincenal,horas_dia,porcentaje_extra,porcentaje_nocturno,afp_modo,afp_valor,sfs_modo,sfs_valor,otros_impuestos_modo,otros_impuestos_valor,incentivo_periodo,valor_hora_extra,descuento_fijo_quincenal,descuento_fijo_motivo,descuento_fijo_activo,otros_descuentos_fijos,nomina_activa,actualizada_por)
 values(v_empresa,p_empleado,v_divisor,v_horas,0,0,'MONTO',coalesce((p_config->>'afp_valor')::numeric,0),'MONTO',coalesce((p_config->>'sfs_valor')::numeric,0),'MONTO',coalesce((p_config->>'otros_impuestos_valor')::numeric,0),coalesce((p_config->>'incentivo_periodo')::numeric,0),coalesce((p_config->>'valor_hora_extra')::numeric,0),coalesce((p_config->>'descuento_fijo_quincenal')::numeric,0),nullif(btrim(p_config->>'descuento_fijo_motivo'),''),coalesce((p_config->>'descuento_fijo_activo')::boolean,false),coalesce((p_config->>'otros_descuentos_fijos')::numeric,0),coalesce((p_config->>'nomina_activa')::boolean,true),auth.uid())
 on conflict(empresa_id,empleado_id)do update set dias_divisor_quincenal=excluded.dias_divisor_quincenal,horas_dia=excluded.horas_dia,porcentaje_extra=0,porcentaje_nocturno=0,afp_modo='MONTO',afp_valor=excluded.afp_valor,sfs_modo='MONTO',sfs_valor=excluded.sfs_valor,otros_impuestos_modo='MONTO',otros_impuestos_valor=excluded.otros_impuestos_valor,incentivo_periodo=excluded.incentivo_periodo,valor_hora_extra=excluded.valor_hora_extra,descuento_fijo_quincenal=excluded.descuento_fijo_quincenal,descuento_fijo_motivo=excluded.descuento_fijo_motivo,descuento_fijo_activo=excluded.descuento_fijo_activo,otros_descuentos_fijos=excluded.otros_descuentos_fijos,nomina_activa=excluded.nomina_activa,version=nomina_reglas_empleado.version+1,actualizada_en=now(),actualizada_por=auth.uid() returning to_jsonb(nomina_reglas_empleado)into v_despues;
 update public.nominas set desactualizada=true,actualizada_en=now()where empresa_id=v_empresa and estado in('CALCULADA','EN_REVISION','APROBADA');
 insert into public.nomina_auditoria(empresa_id,empleado_id,actor_id,accion,antes,despues,motivo)values(v_empresa,p_empleado,auth.uid(),'CONFIGURAR_PAGO_EMPLEADO',v_antes,v_despues,btrim(p_motivo));
end $$;

create or replace function public.calcular_nomina(p_periodo uuid)returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.generar');v_p public.nomina_periodos%rowtype;v_n public.nominas%rowtype;v_version int;v_row record;v_detail uuid;v_hour numeric;v_daily numeric;v_normal_minutes numeric;v_extra_minutes numeric;v_normal_pay numeric;v_extra_pay numeric;v_incentive numeric;v_afp numeric;v_sfs numeric;v_tax numeric;v_loan numeric;v_credit numeric;v_fixed numeric;v_break numeric;v_other numeric;v_gross numeric;v_discounts numeric;v_net numeric;v_summary jsonb;v_factor int;
begin
 select * into v_p from public.nomina_periodos where empresa_id=v_empresa and id=p_periodo for update;if not found then raise exception 'PERIODO_NO_ENCONTRADO';end if;
 select * into v_n from public.nominas where empresa_id=v_empresa and periodo_id=p_periodo for update;if v_p.estado in('CERRADA','ANULADA')or(v_p.estado='APROBADA'and not v_n.desactualizada)then raise exception 'PERIODO_NO_RECALCULABLE';end if;
 if exists(select 1 from public.jornadas where empresa_id=v_empresa and fecha_laboral between v_p.fecha_inicio and v_p.fecha_fin and revision_pendiente)then raise exception 'JORNADAS_PENDIENTES';end if;
 if exists(select 1 from public.jornada_conflictos c join public.jornadas j on j.id=c.jornada_id and j.empresa_id=c.empresa_id where c.empresa_id=v_empresa and j.fecha_laboral between v_p.fecha_inicio and v_p.fecha_fin and c.estado='PENDIENTE')then raise exception 'CONFLICTOS_PENDIENTES';end if;
 if exists(select 1 from public.empleados e left join public.nomina_reglas_empleado r on r.empresa_id=e.empresa_id and r.empleado_id=e.id where e.empresa_id=v_empresa and e.activo and(coalesce(e.salario,0)<=0 or r.id is null or not r.nomina_activa or coalesce(r.dias_divisor_quincenal,0)<=0 or coalesce(r.horas_dia,0)<=0))then raise exception 'EMPLEADOS_SIN_CONFIGURACION_SALARIAL';end if;
 v_version:=v_n.version_calculo+1;v_factor:=case when v_p.tipo_periodo='MENSUAL'then 2 else 1 end;
 delete from public.nomina_descuentos where empresa_id=v_empresa and nomina_id=v_n.id and not aplicado;delete from public.nomina_detalles where empresa_id=v_empresa and nomina_id=v_n.id;
 for v_row in select e.*,r.dias_divisor_quincenal divisor,r.horas_dia,r.valor_hora_extra,r.afp_valor,r.sfs_valor,r.otros_impuestos_valor,r.incentivo_periodo,r.descuento_fijo_quincenal,r.descuento_fijo_activo,r.otros_descuentos_fijos from public.empleados e join public.nomina_reglas_empleado r on r.empresa_id=e.empresa_id and r.empleado_id=e.id and r.nomina_activa where e.empresa_id=v_empresa and e.activo and coalesce(e.fecha_ingreso,v_p.fecha_fin)<=v_p.fecha_fin order by e.codigo_empleado loop
  select coalesce(sum(least(j.minutos_trabajados,(v_row.horas_dia*60)::int)),0),coalesce(sum(greatest(j.minutos_trabajados-(v_row.horas_dia*60)::int,0)),0)into v_normal_minutes,v_extra_minutes from public.jornadas j where j.empresa_id=v_empresa and j.empleado_id=v_row.id and j.fecha_laboral between v_p.fecha_inicio and v_p.fecha_fin and j.estado='FINALIZADA'and not j.revision_pendiente and not exists(select 1 from public.jornada_conflictos c where c.empresa_id=j.empresa_id and c.jornada_id=j.id and c.estado='PENDIENTE');
  v_daily:=v_row.salario/v_row.divisor;v_hour:=round(v_daily/v_row.horas_dia,4);v_normal_pay:=round(v_normal_minutes/60*v_hour,2);v_extra_pay:=round(v_extra_minutes/60*v_row.valor_hora_extra,2);
  select coalesce(sum(monto)filter(where tipo='INCENTIVO'),0),coalesce(sum(monto)filter(where tipo='ROTUR/FALT'),0),coalesce(sum(monto)filter(where tipo='OTRO_DESCUENTO'),0)into v_incentive,v_break,v_other from public.nomina_ajustes where empresa_id=v_empresa and periodo_id=p_periodo and empleado_id=v_row.id and activo;
  v_incentive:=round(v_incentive+v_row.incentivo_periodo*v_factor,2);v_gross:=round(v_normal_pay+v_extra_pay+v_incentive,2);v_afp:=round(v_row.afp_valor*v_factor,2);v_sfs:=round(v_row.sfs_valor*v_factor,2);v_tax:=round(v_row.otros_impuestos_valor*v_factor,2);v_fixed:=case when v_row.descuento_fijo_activo then round(v_row.descuento_fijo_quincenal*v_factor,2)else 0 end;v_other:=round(v_other+v_row.otros_descuentos_fijos*v_factor,2);
  select coalesce(sum(least(pendiente,descuento_periodo*v_factor)),0)into v_loan from public.nomina_prestamos where empresa_id=v_empresa and empleado_id=v_row.id and estado='ENTREGADO'and pendiente>0;select coalesce(sum(least(pendiente,descuento_periodo*v_factor)),0)into v_credit from public.nomina_creditos where empresa_id=v_empresa and empleado_id=v_row.id and estado='ACTIVO'and pendiente>0;
  select v_loan+coalesce(sum(monto),0)into v_loan from public.nomina_ajustes where empresa_id=v_empresa and periodo_id=p_periodo and empleado_id=v_row.id and tipo='DESCU-PRES'and activo;select v_credit+coalesce(sum(monto),0)into v_credit from public.nomina_ajustes where empresa_id=v_empresa and periodo_id=p_periodo and empleado_id=v_row.id and tipo='DESCU-CRED'and activo;
  v_discounts:=round(v_afp+v_sfs+v_tax+v_loan+v_credit+v_fixed+v_break+v_other,2);v_net:=round(v_gross-v_discounts,2);if v_net<0 then raise exception 'NETO_NEGATIVO_REQUIERE_AUTORIZACION:%',v_row.codigo_empleado;end if;
  insert into public.nomina_detalles(empresa_id,nomina_id,empleado_id,codigo_empleado,nombre_empleado,tipo_pago,sueldo_base,dias_trabajados,horas_normales,horas_extras,horas_nocturnas,valor_hora,total_horas_extras,total_nocturnas,incentivos,afp,sfs,otros_impuestos,total_impuestos,descuento_prestamo,descuento_credito,rotura_falta,otros_descuentos,total_descuentos,bruto,neto,version_calculo,formula,entradas,resultados,pago_normal,valor_hora_extra,descuento_fijo)
  values(v_empresa,v_n.id,v_row.id,v_row.codigo_empleado,v_row.nombre_completo,v_row.tipo_pago,v_row.salario,round(v_normal_minutes/(v_row.horas_dia*60),2),round(v_normal_minutes/60,2),round(v_extra_minutes/60,2),0,v_hour,v_extra_pay,0,v_incentive,v_afp,v_sfs,v_tax,v_afp+v_sfs+v_tax,v_loan,v_credit,v_break,v_other,v_discounts,v_gross,v_net,v_version,'RC4_WORKED_MINUTES_V2',jsonb_build_object('salario_mensual',v_row.salario,'minutos_normales',v_normal_minutes,'minutos_extra',v_extra_minutes,'dias_divisor',v_row.divisor,'horas_dia',v_row.horas_dia,'valor_hora_extra_manual',v_row.valor_hora_extra),jsonb_build_object('pago_normal',v_normal_pay,'pago_extra',v_extra_pay,'bruto',v_gross,'descuentos',v_discounts,'neto',v_net),v_normal_pay,v_row.valor_hora_extra,v_fixed)returning id into v_detail;
  insert into public.nomina_descuentos(empresa_id,nomina_id,detalle_id,empleado_id,prestamo_id,tipo,monto,origen)select v_empresa,v_n.id,v_detail,v_row.id,id,'DESCU-PRES',least(pendiente,descuento_periodo*v_factor),'MOTOR'from public.nomina_prestamos where empresa_id=v_empresa and empleado_id=v_row.id and estado='ENTREGADO'and pendiente>0;
  insert into public.nomina_descuentos(empresa_id,nomina_id,detalle_id,empleado_id,credito_id,tipo,monto,origen)select v_empresa,v_n.id,v_detail,v_row.id,id,'DESCU-CRED',least(pendiente,descuento_periodo*v_factor),'MOTOR'from public.nomina_creditos where empresa_id=v_empresa and empleado_id=v_row.id and estado='ACTIVO'and pendiente>0;
  insert into public.nomina_descuentos(empresa_id,nomina_id,detalle_id,empleado_id,tipo,monto,origen)select v_empresa,v_n.id,v_detail,v_row.id,x.tipo,x.monto,'MOTOR'from(values('AFP',v_afp),('SFS',v_sfs),('OTRO_IMPUESTO',v_tax),('OTRO_DESCUENTO',v_fixed))x(tipo,monto)where x.monto>0;
  insert into public.nomina_descuentos(empresa_id,nomina_id,detalle_id,empleado_id,ajuste_id,tipo,monto,origen)select v_empresa,v_n.id,v_detail,v_row.id,a.id,a.tipo,a.monto,a.origen from public.nomina_ajustes a where a.empresa_id=v_empresa and a.periodo_id=p_periodo and a.empleado_id=v_row.id and a.activo and a.tipo<>'INCENTIVO'and a.monto>0;
 end loop;
 select jsonb_build_object('empleados',count(*),'total_sueldos',coalesce(sum(pago_normal),0),'total_horas_extras',coalesce(sum(total_horas_extras),0),'total_incentivos',coalesce(sum(incentivos),0),'total_prestamos',coalesce(sum(descuento_prestamo),0),'total_creditos',coalesce(sum(descuento_credito),0),'total_impuestos',coalesce(sum(total_impuestos),0),'total_otros_descuentos',coalesce(sum(rotura_falta+otros_descuentos+descuento_fijo),0),'total_general_pagado',coalesce(sum(neto),0))into v_summary from public.nomina_detalles where empresa_id=v_empresa and nomina_id=v_n.id;
 update public.nominas set estado='CALCULADA',version_calculo=v_version,motor_version=2,formula='RC4_WORKED_MINUTES_V2',desactualizada=false,errores='[]',resumen=v_summary,calculada_en=now(),actualizada_en=now(),jornadas_actualizadas_hasta=(select max(actualizada_en)from public.jornadas where empresa_id=v_empresa and fecha_laboral between v_p.fecha_inicio and v_p.fecha_fin)where id=v_n.id;update public.nomina_periodos set estado='CALCULADA',calculada_en=now()where id=p_periodo;insert into public.nomina_auditoria(empresa_id,periodo_id,nomina_id,actor_id,accion,despues)values(v_empresa,p_periodo,v_n.id,auth.uid(),case when v_version=1 then'CALCULAR'else'RECALCULAR'end,jsonb_build_object('version',v_version,'formula','RC4_WORKED_MINUTES_V2','resumen',v_summary));return jsonb_build_object('periodo_id',p_periodo,'nomina_id',v_n.id,'version',v_version,'resumen',v_summary);
end $$;

revoke all on function public.obtener_ficha_pago_empleado(uuid),public.guardar_ficha_pago_empleado(uuid,jsonb,text)from public,anon;
grant execute on function public.obtener_ficha_pago_empleado(uuid),public.guardar_ficha_pago_empleado(uuid,jsonb,text)to authenticated;
comment on column public.nomina_reglas_empleado.dias_divisor_quincenal is 'Divisor del sueldo mensual; 30 por defecto. Nombre legado conservado para compatibilidad.';
comment on function public.calcular_nomina(uuid)is 'RC4 definitivo: paga exclusivamente minutos trabajados de jornadas RC2 elegibles.';
commit;
