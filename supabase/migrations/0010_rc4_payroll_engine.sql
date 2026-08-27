begin;

insert into public.permisos(codigo,nombre,modulo,activo) values
('nomina.ver','Ver módulo de nómina','nomina',true),
('nomina.generar','Generar y recalcular nómina','nomina',true),
('nomina.editar','Editar nómina en revisión','nomina',true),
('nomina.aprobar','Aprobar nómina','nomina',true),
('nomina.cerrar','Cerrar nómina','nomina',true),
('nomina.anular','Anular nómina','nomina',true),
('nomina.exportar','Exportar nómina','nomina',true),
('nomina.prestamos','Administrar préstamos de nómina','nomina',true),
('nomina.creditos','Administrar créditos de nómina','nomina',true),
('nomina.descuentos','Administrar descuentos de nómina','nomina',true)
on conflict(codigo) do update set nombre=excluded.nombre,modulo=excluded.modulo,activo=true;

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'empresa' from public.roles r join public.permisos p on p.codigo like 'nomina.%'
where r.code in('admin','payroll') and r.is_active
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

create table public.nomina_reglas(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null references public.companies(id) on delete restrict,
 dias_divisor_quincenal numeric(6,2) not null default 15 check(dias_divisor_quincenal>0),horas_dia numeric(5,2) not null default 8 check(horas_dia>0),
 porcentaje_extra numeric(7,4) not null default 0 check(porcentaje_extra>=0),porcentaje_nocturno numeric(7,4) not null default 0 check(porcentaje_nocturno>=0),
 afp_modo text not null default 'MONTO' check(afp_modo in('MONTO','PORCENTAJE')),afp_valor numeric(14,4) not null default 0 check(afp_valor>=0),
 sfs_modo text not null default 'MONTO' check(sfs_modo in('MONTO','PORCENTAJE')),sfs_valor numeric(14,4) not null default 0 check(sfs_valor>=0),
 otros_impuestos_modo text not null default 'MONTO' check(otros_impuestos_modo in('MONTO','PORCENTAJE')),otros_impuestos_valor numeric(14,4) not null default 0 check(otros_impuestos_valor>=0),
 incentivo_periodo numeric(14,2) not null default 0 check(incentivo_periodo>=0),version integer not null default 1 check(version>0),
 creada_en timestamptz not null default now(),actualizada_en timestamptz not null default now(),actualizada_por uuid references public.profiles(id) on delete set null,
 unique(empresa_id),unique(empresa_id,id)
);

create table public.nomina_reglas_empleado(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null,empleado_id uuid not null,
 dias_divisor_quincenal numeric(6,2) check(dias_divisor_quincenal>0),horas_dia numeric(5,2) check(horas_dia>0),porcentaje_extra numeric(7,4) check(porcentaje_extra>=0),porcentaje_nocturno numeric(7,4) check(porcentaje_nocturno>=0),
 afp_modo text check(afp_modo in('MONTO','PORCENTAJE')),afp_valor numeric(14,4) check(afp_valor>=0),sfs_modo text check(sfs_modo in('MONTO','PORCENTAJE')),sfs_valor numeric(14,4) check(sfs_valor>=0),
 otros_impuestos_modo text check(otros_impuestos_modo in('MONTO','PORCENTAJE')),otros_impuestos_valor numeric(14,4) check(otros_impuestos_valor>=0),incentivo_periodo numeric(14,2) check(incentivo_periodo>=0),
 version integer not null default 1 check(version>0),actualizada_en timestamptz not null default now(),actualizada_por uuid references public.profiles(id) on delete set null,
 unique(empresa_id,empleado_id),unique(empresa_id,id),foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict
);

create table public.nomina_periodos(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null references public.companies(id) on delete restrict,
 fecha_inicio date not null,fecha_fin date not null,tipo_periodo text not null check(tipo_periodo in('QUINCENAL','MENSUAL')),
 estado text not null default 'BORRADOR' check(estado in('BORRADOR','CALCULADA','EN_REVISION','APROBADA','CERRADA','ANULADA')),
 creada_en timestamptz not null default now(),calculada_en timestamptz,aprobada_en timestamptz,cerrada_en timestamptz,anulada_en timestamptz,
 creada_por uuid not null references public.profiles(id) on delete restrict,aprobada_por uuid references public.profiles(id) on delete restrict,cerrada_por uuid references public.profiles(id) on delete restrict,anulada_por uuid references public.profiles(id) on delete restrict,
 constraint nomina_periodo_fechas check(fecha_fin>=fecha_inicio),unique(empresa_id,fecha_inicio,fecha_fin,tipo_periodo),unique(empresa_id,id)
);

create table public.nominas(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null,periodo_id uuid not null,
 estado text not null default 'BORRADOR' check(estado in('BORRADOR','CALCULADA','EN_REVISION','APROBADA','CERRADA','ANULADA')),
 version_calculo integer not null default 0 check(version_calculo>=0),motor_version integer not null default 1 check(motor_version>0),formula text not null default 'RC4_SQL_V1',
 desactualizada boolean not null default false,errores jsonb not null default '[]'::jsonb,resumen jsonb not null default '{}'::jsonb,
 entradas_hash text,jornadas_actualizadas_hasta timestamptz,calculada_en timestamptz,actualizada_en timestamptz not null default now(),
 unique(empresa_id,periodo_id),unique(empresa_id,id),foreign key(empresa_id,periodo_id) references public.nomina_periodos(empresa_id,id) on delete restrict
);

create table public.nomina_detalles(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null,nomina_id uuid not null,empleado_id uuid not null,
 codigo_empleado text not null,nombre_empleado text not null,tipo_pago text,sueldo_base numeric(14,2) not null check(sueldo_base>=0),dias_trabajados numeric(8,2) not null default 0 check(dias_trabajados>=0),
 horas_normales numeric(10,2) not null default 0 check(horas_normales>=0),horas_extras numeric(10,2) not null default 0 check(horas_extras>=0),horas_nocturnas numeric(10,2) not null default 0 check(horas_nocturnas>=0),
 valor_hora numeric(14,4) not null default 0 check(valor_hora>=0),total_horas_extras numeric(14,2) not null default 0 check(total_horas_extras>=0),total_nocturnas numeric(14,2) not null default 0 check(total_nocturnas>=0),
 incentivos numeric(14,2) not null default 0 check(incentivos>=0),afp numeric(14,2) not null default 0 check(afp>=0),sfs numeric(14,2) not null default 0 check(sfs>=0),otros_impuestos numeric(14,2) not null default 0 check(otros_impuestos>=0),total_impuestos numeric(14,2) not null default 0 check(total_impuestos>=0),
 descuento_prestamo numeric(14,2) not null default 0 check(descuento_prestamo>=0),descuento_credito numeric(14,2) not null default 0 check(descuento_credito>=0),rotura_falta numeric(14,2) not null default 0 check(rotura_falta>=0),otros_descuentos numeric(14,2) not null default 0 check(otros_descuentos>=0),total_descuentos numeric(14,2) not null default 0 check(total_descuentos>=0),
 bruto numeric(14,2) not null check(bruto>=0),neto numeric(14,2) not null check(neto>=0),observaciones text,version_calculo integer not null check(version_calculo>0),formula text not null,entradas jsonb not null,resultados jsonb not null,calculado_en timestamptz not null default now(),
 unique(empresa_id,nomina_id,empleado_id),unique(empresa_id,id),foreign key(empresa_id,nomina_id) references public.nominas(empresa_id,id) on delete restrict,foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict
);

create table public.nomina_prestamos(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null,empleado_id uuid not null,
 monto_total numeric(14,2) not null check(monto_total>0),total_pagado numeric(14,2) not null default 0 check(total_pagado>=0),pendiente numeric(14,2) not null check(pendiente>=0),descuento_periodo numeric(14,2) not null check(descuento_periodo>0),
 estado text not null default 'PENDIENTE' check(estado in('PENDIENTE','APROBADO','ENTREGADO','PAGADO','CANCELADO')),fecha_inicio date not null,fecha_final date,motivo text not null,
 creado_por uuid not null references public.profiles(id) on delete restrict,creado_en timestamptz not null default now(),actualizado_en timestamptz not null default now(),
 constraint prestamo_saldos check(total_pagado<=monto_total and pendiente=monto_total-total_pagado),unique(empresa_id,id),foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict
);

create table public.nomina_creditos(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null,empleado_id uuid not null,
 monto_total numeric(14,2) not null check(monto_total>0),total_descontado numeric(14,2) not null default 0 check(total_descontado>=0),pendiente numeric(14,2) not null,descuento_periodo numeric(14,2) not null check(descuento_periodo>0),
 estado text not null default 'ACTIVO' check(estado in('ACTIVO','PAGADO','CANCELADO')),fecha_inicio date not null,fecha_final date,motivo text not null,
 creado_por uuid not null references public.profiles(id) on delete restrict,creado_en timestamptz not null default now(),actualizado_en timestamptz not null default now(),
 constraint credito_saldos check(total_descontado<=monto_total and pendiente>=0 and pendiente=monto_total-total_descontado),unique(empresa_id,id),foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict
);

create table public.nomina_ajustes(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null,periodo_id uuid not null,empleado_id uuid not null,
 tipo text not null check(tipo in('DESCU-PRES','DESCU-CRED','ROTUR/FALT','OTRO_DESCUENTO','INCENTIVO')),monto numeric(14,2) not null check(monto>=0),motivo text not null,origen text not null check(origen in('MANUAL','EXCEL')),
 lote_id uuid,activo boolean not null default true,creado_por uuid not null references public.profiles(id) on delete restrict,creado_en timestamptz not null default now(),
 unique(empresa_id,id),foreign key(empresa_id,periodo_id) references public.nomina_periodos(empresa_id,id) on delete restrict,foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict
);

create table public.nomina_descuentos(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null,nomina_id uuid not null,detalle_id uuid,empleado_id uuid not null,prestamo_id uuid,credito_id uuid,ajuste_id uuid,
 tipo text not null check(tipo in('DESCU-PRES','DESCU-CRED','ROTUR/FALT','OTRO_DESCUENTO','AFP','SFS','OTRO_IMPUESTO')),monto numeric(14,2) not null check(monto>=0),origen text not null check(origen in('MOTOR','MANUAL','EXCEL')),aplicado boolean not null default false,
 creado_en timestamptz not null default now(),unique(empresa_id,id),foreign key(empresa_id,nomina_id) references public.nominas(empresa_id,id) on delete restrict,foreign key(empresa_id,detalle_id) references public.nomina_detalles(empresa_id,id) on delete restrict,
 foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict,foreign key(empresa_id,prestamo_id) references public.nomina_prestamos(empresa_id,id) on delete restrict,foreign key(empresa_id,credito_id) references public.nomina_creditos(empresa_id,id) on delete restrict,foreign key(empresa_id,ajuste_id) references public.nomina_ajustes(empresa_id,id) on delete restrict
);

create table public.nomina_auditoria(
 id bigint generated always as identity primary key,empresa_id uuid not null references public.companies(id) on delete restrict,periodo_id uuid,nomina_id uuid,empleado_id uuid,
 actor_id uuid references public.profiles(id) on delete set null,accion text not null,antes jsonb,despues jsonb,motivo text,fecha timestamptz not null default now(),
 foreign key(empresa_id,periodo_id) references public.nomina_periodos(empresa_id,id) on delete restrict,foreign key(empresa_id,nomina_id) references public.nominas(empresa_id,id) on delete restrict,foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict
);

create table public.nomina_archivos(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null,periodo_id uuid not null,nomina_id uuid,
 tipo text not null check(tipo in('PLANTILLA','IMPORTACION','EXCEL_FINAL','PDF_FINAL')),nombre text not null,mime text not null,storage_path text,sha256 text,tamano bigint check(tamano is null or tamano>=0),estado text not null default 'GENERADO' check(estado in('CARGADO','VALIDADO','RECHAZADO','GENERADO')),
 metadata jsonb not null default '{}'::jsonb,creado_por uuid not null references public.profiles(id) on delete restrict,creado_en timestamptz not null default now(),unique(empresa_id,id),foreign key(empresa_id,periodo_id) references public.nomina_periodos(empresa_id,id) on delete restrict,foreign key(empresa_id,nomina_id) references public.nominas(empresa_id,id) on delete restrict
);

create index nomina_periodos_estado_idx on public.nomina_periodos(empresa_id,estado,fecha_inicio desc);
create index nomina_detalles_nomina_idx on public.nomina_detalles(empresa_id,nomina_id,codigo_empleado);
create index nomina_prestamos_activos_idx on public.nomina_prestamos(empresa_id,empleado_id,estado) where estado='ENTREGADO';
create index nomina_creditos_activos_idx on public.nomina_creditos(empresa_id,empleado_id,estado) where estado='ACTIVO';
create index nomina_ajustes_periodo_idx on public.nomina_ajustes(empresa_id,periodo_id,empleado_id) where activo;
create index nomina_auditoria_scope_idx on public.nomina_auditoria(empresa_id,periodo_id,fecha desc);
create unique index nomina_ajustes_unico_idx on public.nomina_ajustes(empresa_id,periodo_id,empleado_id,tipo,origen) where activo and tipo in('DESCU-PRES','DESCU-CRED','ROTUR/FALT');

create or replace function public.nomina_empresa_autorizada(p_permiso text) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();
begin
 if v_empresa is null or not public.tiene_permiso(p_permiso) then raise exception using errcode='42501',message='NOMINA_PERMISSION_DENIED',detail=coalesce(p_permiso,'');end if;
 return v_empresa;
end $$;
revoke all on function public.nomina_empresa_autorizada(text) from public,anon;
grant execute on function public.nomina_empresa_autorizada(text) to authenticated;

create or replace function public.crear_periodo_nomina(p_inicio date,p_fin date,p_tipo text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.generar');v_periodo uuid;v_nomina uuid;
begin
 if p_inicio is null or p_fin is null or p_fin<p_inicio then raise exception 'PERIODO_INVALIDO';end if;
 if p_tipo not in('QUINCENAL','MENSUAL') then raise exception 'TIPO_PERIODO_INVALIDO';end if;
 insert into public.nomina_periodos(empresa_id,fecha_inicio,fecha_fin,tipo_periodo,creada_por) values(v_empresa,p_inicio,p_fin,p_tipo,auth.uid()) returning id into v_periodo;
 insert into public.nominas(empresa_id,periodo_id) values(v_empresa,v_periodo) returning id into v_nomina;
 insert into public.nomina_auditoria(empresa_id,periodo_id,nomina_id,actor_id,accion,despues) values(v_empresa,v_periodo,v_nomina,auth.uid(),'CREAR_PERIODO',jsonb_build_object('inicio',p_inicio,'fin',p_fin,'tipo',p_tipo));
 return v_periodo;
exception when unique_violation then raise exception using errcode='23505',message='PERIODO_DUPLICADO';
end $$;

create or replace function public.configurar_regla_nomina(p_empleado uuid,p_config jsonb,p_motivo text) returns void
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.editar');v_antes jsonb;v_despues jsonb;
begin
 if btrim(coalesce(p_motivo,''))='' then raise exception 'MOTIVO_REQUERIDO';end if;
 if p_empleado is null then
  select to_jsonb(r) into v_antes from public.nomina_reglas r where empresa_id=v_empresa;
  insert into public.nomina_reglas(empresa_id,dias_divisor_quincenal,horas_dia,porcentaje_extra,porcentaje_nocturno,afp_modo,afp_valor,sfs_modo,sfs_valor,otros_impuestos_modo,otros_impuestos_valor,incentivo_periodo,actualizada_por)
  values(v_empresa,coalesce((p_config->>'dias_divisor_quincenal')::numeric,15),coalesce((p_config->>'horas_dia')::numeric,8),coalesce((p_config->>'porcentaje_extra')::numeric,0),coalesce((p_config->>'porcentaje_nocturno')::numeric,0),coalesce(p_config->>'afp_modo','MONTO'),coalesce((p_config->>'afp_valor')::numeric,0),coalesce(p_config->>'sfs_modo','MONTO'),coalesce((p_config->>'sfs_valor')::numeric,0),coalesce(p_config->>'otros_impuestos_modo','MONTO'),coalesce((p_config->>'otros_impuestos_valor')::numeric,0),coalesce((p_config->>'incentivo_periodo')::numeric,0),auth.uid())
  on conflict(empresa_id) do update set dias_divisor_quincenal=excluded.dias_divisor_quincenal,horas_dia=excluded.horas_dia,porcentaje_extra=excluded.porcentaje_extra,porcentaje_nocturno=excluded.porcentaje_nocturno,afp_modo=excluded.afp_modo,afp_valor=excluded.afp_valor,sfs_modo=excluded.sfs_modo,sfs_valor=excluded.sfs_valor,otros_impuestos_modo=excluded.otros_impuestos_modo,otros_impuestos_valor=excluded.otros_impuestos_valor,incentivo_periodo=excluded.incentivo_periodo,version=nomina_reglas.version+1,actualizada_en=now(),actualizada_por=auth.uid() returning to_jsonb(nomina_reglas) into v_despues;
 else
  if not exists(select 1 from public.empleados where empresa_id=v_empresa and id=p_empleado) then raise exception 'EMPLEADO_NO_ENCONTRADO';end if;
  select to_jsonb(r) into v_antes from public.nomina_reglas_empleado r where empresa_id=v_empresa and empleado_id=p_empleado;
  insert into public.nomina_reglas_empleado(empresa_id,empleado_id,dias_divisor_quincenal,horas_dia,porcentaje_extra,porcentaje_nocturno,afp_modo,afp_valor,sfs_modo,sfs_valor,otros_impuestos_modo,otros_impuestos_valor,incentivo_periodo,actualizada_por)
  values(v_empresa,p_empleado,(p_config->>'dias_divisor_quincenal')::numeric,(p_config->>'horas_dia')::numeric,(p_config->>'porcentaje_extra')::numeric,(p_config->>'porcentaje_nocturno')::numeric,p_config->>'afp_modo',(p_config->>'afp_valor')::numeric,p_config->>'sfs_modo',(p_config->>'sfs_valor')::numeric,p_config->>'otros_impuestos_modo',(p_config->>'otros_impuestos_valor')::numeric,(p_config->>'incentivo_periodo')::numeric,auth.uid())
  on conflict(empresa_id,empleado_id) do update set dias_divisor_quincenal=excluded.dias_divisor_quincenal,horas_dia=excluded.horas_dia,porcentaje_extra=excluded.porcentaje_extra,porcentaje_nocturno=excluded.porcentaje_nocturno,afp_modo=excluded.afp_modo,afp_valor=excluded.afp_valor,sfs_modo=excluded.sfs_modo,sfs_valor=excluded.sfs_valor,otros_impuestos_modo=excluded.otros_impuestos_modo,otros_impuestos_valor=excluded.otros_impuestos_valor,incentivo_periodo=excluded.incentivo_periodo,version=nomina_reglas_empleado.version+1,actualizada_en=now(),actualizada_por=auth.uid() returning to_jsonb(nomina_reglas_empleado) into v_despues;
 end if;
 update public.nominas set desactualizada=true,actualizada_en=now() where empresa_id=v_empresa and estado in('CALCULADA','EN_REVISION','APROBADA');
 insert into public.nomina_auditoria(empresa_id,empleado_id,actor_id,accion,antes,despues,motivo) values(v_empresa,p_empleado,auth.uid(),'CONFIGURAR_REGLA',v_antes,v_despues,btrim(p_motivo));
end $$;

create or replace function public.crear_prestamo_nomina(p_empleado uuid,p_total numeric,p_descuento numeric,p_fecha date,p_motivo text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.prestamos');v_id uuid;
begin
 if p_total<=0 or p_descuento<=0 or btrim(coalesce(p_motivo,''))='' then raise exception 'PRESTAMO_INVALIDO';end if;
 insert into public.nomina_prestamos(empresa_id,empleado_id,monto_total,pendiente,descuento_periodo,fecha_inicio,motivo,creado_por) select v_empresa,id,p_total,p_total,p_descuento,coalesce(p_fecha,current_date),btrim(p_motivo),auth.uid() from public.empleados where empresa_id=v_empresa and id=p_empleado returning id into v_id;
 if v_id is null then raise exception 'EMPLEADO_NO_ENCONTRADO';end if;
 insert into public.nomina_auditoria(empresa_id,empleado_id,actor_id,accion,despues,motivo) values(v_empresa,p_empleado,auth.uid(),'CREAR_PRESTAMO',jsonb_build_object('id',v_id,'total',p_total,'descuento',p_descuento),btrim(p_motivo));return v_id;
end $$;

create or replace function public.crear_credito_nomina(p_empleado uuid,p_total numeric,p_descuento numeric,p_fecha date,p_motivo text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.creditos');v_id uuid;
begin
 if p_total<=0 or p_descuento<=0 or btrim(coalesce(p_motivo,''))='' then raise exception 'CREDITO_INVALIDO';end if;
 insert into public.nomina_creditos(empresa_id,empleado_id,monto_total,pendiente,descuento_periodo,fecha_inicio,motivo,creado_por) select v_empresa,id,p_total,p_total,p_descuento,coalesce(p_fecha,current_date),btrim(p_motivo),auth.uid() from public.empleados where empresa_id=v_empresa and id=p_empleado returning id into v_id;
 if v_id is null then raise exception 'EMPLEADO_NO_ENCONTRADO';end if;
 update public.nominas n set desactualizada=true,actualizada_en=now() from public.nomina_periodos p where n.empresa_id=v_empresa and p.empresa_id=n.empresa_id and p.id=n.periodo_id and p.fecha_fin>=coalesce(p_fecha,current_date) and n.estado in('CALCULADA','EN_REVISION','APROBADA');
 insert into public.nomina_auditoria(empresa_id,empleado_id,actor_id,accion,despues,motivo) values(v_empresa,p_empleado,auth.uid(),'CREAR_CREDITO',jsonb_build_object('id',v_id,'total',p_total,'descuento',p_descuento),btrim(p_motivo));return v_id;
end $$;

create or replace function public.cambiar_estado_prestamo_nomina(p_prestamo uuid,p_estado text,p_motivo text) returns void
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.prestamos');v_actual public.nomina_prestamos%rowtype;
begin
 select * into v_actual from public.nomina_prestamos where empresa_id=v_empresa and id=p_prestamo for update;
 if not found then raise exception 'PRESTAMO_NO_ENCONTRADO';end if;
 if btrim(coalesce(p_motivo,''))='' then raise exception 'MOTIVO_REQUERIDO';end if;
 if not((v_actual.estado='PENDIENTE' and p_estado in('APROBADO','CANCELADO'))or(v_actual.estado='APROBADO' and p_estado in('ENTREGADO','CANCELADO')))then raise exception 'TRANSICION_PRESTAMO_INVALIDA';end if;
 update public.nomina_prestamos set estado=p_estado,actualizado_en=now(),fecha_final=case when p_estado='CANCELADO'then current_date else fecha_final end where empresa_id=v_empresa and id=p_prestamo;
 if p_estado='ENTREGADO'then update public.nominas n set desactualizada=true,actualizada_en=now() from public.nomina_periodos p where n.empresa_id=v_empresa and p.empresa_id=n.empresa_id and p.id=n.periodo_id and p.fecha_fin>=v_actual.fecha_inicio and n.estado in('CALCULADA','EN_REVISION','APROBADA');end if;
 insert into public.nomina_auditoria(empresa_id,empleado_id,actor_id,accion,antes,despues,motivo) values(v_empresa,v_actual.empleado_id,auth.uid(),'ESTADO_PRESTAMO',to_jsonb(v_actual),jsonb_build_object('id',p_prestamo,'estado',p_estado),btrim(p_motivo));
end $$;

create or replace function public.cancelar_credito_nomina(p_credito uuid,p_motivo text) returns void
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.creditos');v_actual public.nomina_creditos%rowtype;
begin
 select * into v_actual from public.nomina_creditos where empresa_id=v_empresa and id=p_credito for update;
 if not found then raise exception 'CREDITO_NO_ENCONTRADO';end if;
 if v_actual.estado<>'ACTIVO' then raise exception 'CREDITO_NO_CANCELABLE';end if;
 if btrim(coalesce(p_motivo,''))='' then raise exception 'MOTIVO_REQUERIDO';end if;
 update public.nomina_creditos set estado='CANCELADO',fecha_final=current_date,actualizado_en=now() where empresa_id=v_empresa and id=p_credito;
 update public.nominas n set desactualizada=true,actualizada_en=now() from public.nomina_periodos p where n.empresa_id=v_empresa and p.empresa_id=n.empresa_id and p.id=n.periodo_id and p.fecha_fin>=v_actual.fecha_inicio and n.estado in('CALCULADA','EN_REVISION','APROBADA');
 insert into public.nomina_auditoria(empresa_id,empleado_id,actor_id,accion,antes,despues,motivo) values(v_empresa,v_actual.empleado_id,auth.uid(),'CANCELAR_CREDITO',to_jsonb(v_actual),jsonb_build_object('id',p_credito,'estado','CANCELADO'),btrim(p_motivo));
end $$;

create or replace function public.aplicar_descuentos_nomina(p_periodo uuid,p_filas jsonb,p_origen text,p_motivo text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.descuentos');v_estado text;v_lote uuid:=extensions.gen_random_uuid();v_fila jsonb;v_empleado uuid;v_errores jsonb:='[]'::jsonb;v_count int:=0;v_codigo text;v_tipo text;v_monto numeric;
begin
 if coalesce(jsonb_typeof(p_filas),'')<>'array' or jsonb_array_length(p_filas)=0 then raise exception 'FILAS_REQUERIDAS';end if;if p_origen not in('MANUAL','EXCEL') then raise exception 'ORIGEN_INVALIDO';end if;if btrim(coalesce(p_motivo,''))='' then raise exception 'MOTIVO_REQUERIDO';end if;
 select estado into v_estado from public.nomina_periodos where empresa_id=v_empresa and id=p_periodo for update;if v_estado not in('BORRADOR','CALCULADA','EN_REVISION') then raise exception 'PERIODO_NO_EDITABLE';end if;
 if exists(select 1 from jsonb_array_elements(p_filas)v group by btrim(v->>'codigo'),v->>'tipo' having count(*)>1)then v_errores:=v_errores||jsonb_build_array(jsonb_build_object('codigo','LOTE','error','AJUSTE_DUPLICADO_EN_LOTE'));end if;
 for v_fila in select value from jsonb_array_elements(p_filas) loop
  v_codigo:=btrim(v_fila->>'codigo');v_tipo:=v_fila->>'tipo';v_monto:=case when coalesce(v_fila->>'monto','')~'^[0-9]+([.][0-9]{1,4})?$'then(v_fila->>'monto')::numeric else null end;
  select id into v_empleado from public.empleados where empresa_id=v_empresa and codigo_empleado=v_codigo;
  if v_empleado is null then v_errores:=v_errores||jsonb_build_array(jsonb_build_object('codigo',v_codigo,'error','EMPLEADO_NO_ENCONTRADO'));
  elsif v_tipo not in('DESCU-PRES','DESCU-CRED','ROTUR/FALT','OTRO_DESCUENTO','INCENTIVO') then v_errores:=v_errores||jsonb_build_array(jsonb_build_object('codigo',v_codigo,'error','TIPO_INVALIDO'));
  elsif v_monto is null or v_monto<0 then v_errores:=v_errores||jsonb_build_array(jsonb_build_object('codigo',v_codigo,'error','MONTO_INVALIDO'));
  elsif exists(select 1 from public.nomina_ajustes where empresa_id=v_empresa and periodo_id=p_periodo and empleado_id=v_empleado and tipo=v_tipo and origen=p_origen and activo) then v_errores:=v_errores||jsonb_build_array(jsonb_build_object('codigo',v_codigo,'error','AJUSTE_DUPLICADO'));
  end if;
 end loop;
 if jsonb_array_length(v_errores)>0 then return jsonb_build_object('aplicado',false,'errores',v_errores);end if;
 for v_fila in select value from jsonb_array_elements(p_filas) loop
  select id into v_empleado from public.empleados where empresa_id=v_empresa and codigo_empleado=btrim(v_fila->>'codigo');
  insert into public.nomina_ajustes(empresa_id,periodo_id,empleado_id,tipo,monto,motivo,origen,lote_id,creado_por) values(v_empresa,p_periodo,v_empleado,v_fila->>'tipo',(v_fila->>'monto')::numeric,btrim(p_motivo),p_origen,v_lote,auth.uid());v_count:=v_count+1;
 end loop;
 update public.nominas set desactualizada=true,actualizada_en=now() where empresa_id=v_empresa and periodo_id=p_periodo and estado in('CALCULADA','EN_REVISION');
 insert into public.nomina_auditoria(empresa_id,periodo_id,actor_id,accion,despues,motivo) values(v_empresa,p_periodo,auth.uid(),case when p_origen='EXCEL' then 'CARGAR_EXCEL' else 'AJUSTE_MANUAL' end,jsonb_build_object('lote_id',v_lote,'filas',v_count),btrim(p_motivo));
 return jsonb_build_object('aplicado',true,'lote_id',v_lote,'filas',v_count,'errores','[]'::jsonb);
end $$;

create or replace function public.calcular_nomina(p_periodo uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.generar');v_p public.nomina_periodos%rowtype;v_n public.nominas%rowtype;v_reg public.nomina_reglas%rowtype;v_version int;v_tz text;v_row record;v_detail uuid;v_base numeric;v_day numeric;v_hour numeric;v_normal numeric;v_extra numeric;v_night numeric;v_extra_total numeric;v_night_total numeric;v_incentive numeric;v_afp numeric;v_sfs numeric;v_other_tax numeric;v_loan numeric;v_credit numeric;v_break numeric;v_other_disc numeric;v_gross numeric;v_taxes numeric;v_discounts numeric;v_net numeric;v_summary jsonb;
begin
 select * into v_p from public.nomina_periodos where empresa_id=v_empresa and id=p_periodo for update;if not found then raise exception 'PERIODO_NO_ENCONTRADO';end if;
 select * into v_n from public.nominas where empresa_id=v_empresa and periodo_id=p_periodo for update;
 if v_p.estado in('CERRADA','ANULADA')or(v_p.estado='APROBADA'and not v_n.desactualizada)then raise exception 'PERIODO_NO_RECALCULABLE';end if;
 if exists(select 1 from public.jornadas where empresa_id=v_empresa and fecha_laboral between v_p.fecha_inicio and v_p.fecha_fin and revision_pendiente) then raise exception 'JORNADAS_PENDIENTES';end if;
 if exists(select 1 from public.jornada_conflictos c join public.jornadas j on j.id=c.jornada_id and j.empresa_id=c.empresa_id where c.empresa_id=v_empresa and j.fecha_laboral between v_p.fecha_inicio and v_p.fecha_fin and c.estado='PENDIENTE') then raise exception 'CONFLICTOS_PENDIENTES';end if;
 if exists(select 1 from public.empleados where empresa_id=v_empresa and activo and (salario is null or salario<=0 or tipo_pago not in('quincenal','mensual'))) then raise exception 'EMPLEADOS_SIN_CONFIGURACION_SALARIAL';end if;
 select * into v_reg from public.nomina_reglas where empresa_id=v_empresa;if not found then insert into public.nomina_reglas(empresa_id,actualizada_por) values(v_empresa,auth.uid()) returning * into v_reg;end if;
 select timezone into v_tz from public.companies where id=v_empresa;v_version:=v_n.version_calculo+1;
 delete from public.nomina_descuentos where empresa_id=v_empresa and nomina_id=v_n.id and not aplicado;delete from public.nomina_detalles where empresa_id=v_empresa and nomina_id=v_n.id;
 for v_row in
  with eligible as(select e.*,coalesce(re.dias_divisor_quincenal,v_reg.dias_divisor_quincenal) divisor,coalesce(re.horas_dia,v_reg.horas_dia) horas_dia,coalesce(re.porcentaje_extra,v_reg.porcentaje_extra) pct_extra,coalesce(re.porcentaje_nocturno,v_reg.porcentaje_nocturno) pct_night,coalesce(re.afp_modo,v_reg.afp_modo) afp_mode,coalesce(re.afp_valor,v_reg.afp_valor) afp_value,coalesce(re.sfs_modo,v_reg.sfs_modo) sfs_mode,coalesce(re.sfs_valor,v_reg.sfs_valor) sfs_value,coalesce(re.otros_impuestos_modo,v_reg.otros_impuestos_modo) other_tax_mode,coalesce(re.otros_impuestos_valor,v_reg.otros_impuestos_valor) other_tax_value,coalesce(re.incentivo_periodo,v_reg.incentivo_periodo) incentive from public.empleados e left join public.nomina_reglas_empleado re on re.empresa_id=e.empresa_id and re.empleado_id=e.id where e.empresa_id=v_empresa and e.activo and coalesce(e.fecha_ingreso,v_p.fecha_fin)<=v_p.fecha_fin),
  work as(
   select e.*,coalesce(w.days,0)::numeric days,coalesce(w.hours,0)::numeric hours,coalesce(w.night_hours,0)::numeric night_hours
   from eligible e left join lateral(
    with local_journeys as(
     select
      j.minutos_trabajados::numeric worked_minutes,
      j.fecha_laboral::timestamp work_date,
      j.iniciado_en at time zone coalesce(v_tz,'America/Santo_Domingo') started_local,
      j.finalizado_en at time zone coalesce(v_tz,'America/Santo_Domingo') finished_local
     from public.jornadas j
     where j.empresa_id=e.empresa_id and j.empleado_id=e.id
      and j.fecha_laboral between v_p.fecha_inicio and v_p.fecha_fin
      and j.estado='FINALIZADA' and not j.revision_pendiente
    ),night_windows as(
     select
      worked_minutes,
      greatest(0,extract(epoch from(
       least(finished_local,work_date+interval '7 hour')
       -greatest(started_local,work_date)
      ))/60) early_night_minutes,
      greatest(0,extract(epoch from(
       least(finished_local,work_date+interval '1 day 7 hour')
       -greatest(started_local,work_date+interval '21 hour')
      ))/60) late_night_minutes
     from local_journeys
    )
    select
     count(*) days,
     coalesce(sum(worked_minutes),0)::numeric/60 hours,
     coalesce(sum(least(worked_minutes,early_night_minutes+late_night_minutes)),0)::numeric/60 night_hours
    from night_windows
   )w on true
  )
  select * from work order by codigo_empleado
 loop
  v_base:=round(case when v_row.tipo_pago='quincenal' and v_p.tipo_periodo='QUINCENAL' then v_row.salario when v_row.tipo_pago='mensual' and v_p.tipo_periodo='MENSUAL' then v_row.salario when v_row.tipo_pago='mensual' and v_p.tipo_periodo='QUINCENAL' then v_row.salario/2 when v_row.tipo_pago='quincenal' and v_p.tipo_periodo='MENSUAL' then v_row.salario*2 else 0 end,2);
  v_day:=v_base/v_row.divisor;v_hour:=round(v_day/v_row.horas_dia,4);v_normal:=round(least(v_row.hours,v_row.days*v_row.horas_dia),2);v_extra:=round(greatest(0,v_row.hours-v_row.days*v_row.horas_dia),2);v_night:=round(least(v_row.night_hours,v_row.hours),2);
  v_extra_total:=round(v_extra*v_hour*(1+v_row.pct_extra/100),2);v_night_total:=round(v_night*v_hour*(1+v_row.pct_night/100),2);
  select coalesce(sum(monto) filter(where tipo='INCENTIVO'),0),coalesce(sum(monto) filter(where tipo='ROTUR/FALT'),0),coalesce(sum(monto) filter(where tipo='OTRO_DESCUENTO'),0) into v_incentive,v_break,v_other_disc from public.nomina_ajustes where empresa_id=v_empresa and periodo_id=p_periodo and empleado_id=v_row.id and activo;
  v_incentive:=round(v_incentive+v_row.incentive,2);v_gross:=round(v_base+v_extra_total+v_night_total+v_incentive,2);v_afp:=round(case when v_row.afp_mode='PORCENTAJE' then v_gross*v_row.afp_value/100 else v_row.afp_value end,2);v_sfs:=round(case when v_row.sfs_mode='PORCENTAJE' then v_gross*v_row.sfs_value/100 else v_row.sfs_value end,2);v_other_tax:=round(case when v_row.other_tax_mode='PORCENTAJE' then v_gross*v_row.other_tax_value/100 else v_row.other_tax_value end,2);
  select coalesce(sum(least(pendiente,descuento_periodo)),0) into v_loan from public.nomina_prestamos where empresa_id=v_empresa and empleado_id=v_row.id and estado='ENTREGADO' and pendiente>0;
  select coalesce(sum(least(pendiente,descuento_periodo)),0) into v_credit from public.nomina_creditos where empresa_id=v_empresa and empleado_id=v_row.id and estado='ACTIVO' and pendiente>0;
  select v_loan+coalesce(sum(monto),0) into v_loan from public.nomina_ajustes where empresa_id=v_empresa and periodo_id=p_periodo and empleado_id=v_row.id and tipo='DESCU-PRES' and activo;
  select v_credit+coalesce(sum(monto),0) into v_credit from public.nomina_ajustes where empresa_id=v_empresa and periodo_id=p_periodo and empleado_id=v_row.id and tipo='DESCU-CRED' and activo;
  v_taxes:=v_afp+v_sfs+v_other_tax;v_discounts:=round(v_taxes+v_loan+v_credit+v_break+v_other_disc,2);v_net:=round(v_gross-v_discounts,2);if v_net<0 then raise exception 'NETO_NEGATIVO:%',v_row.codigo_empleado;end if;
  insert into public.nomina_detalles(empresa_id,nomina_id,empleado_id,codigo_empleado,nombre_empleado,tipo_pago,sueldo_base,dias_trabajados,horas_normales,horas_extras,horas_nocturnas,valor_hora,total_horas_extras,total_nocturnas,incentivos,afp,sfs,otros_impuestos,total_impuestos,descuento_prestamo,descuento_credito,rotura_falta,otros_descuentos,total_descuentos,bruto,neto,version_calculo,formula,entradas,resultados)
  values(v_empresa,v_n.id,v_row.id,v_row.codigo_empleado,v_row.nombre_completo,v_row.tipo_pago,v_base,v_row.days,v_normal,v_extra,v_night,v_hour,v_extra_total,v_night_total,v_incentive,v_afp,v_sfs,v_other_tax,v_taxes,v_loan,v_credit,v_break,v_other_disc,v_discounts,v_gross,v_net,v_version,'RC4_SQL_V1',jsonb_build_object('salario',v_row.salario,'tipo_pago',v_row.tipo_pago,'minutos',v_row.hours*60,'dias_divisor',v_row.divisor,'horas_dia',v_row.horas_dia,'extra_pct',v_row.pct_extra,'nocturno_pct',v_row.pct_night),jsonb_build_object('bruto',v_gross,'descuentos',v_discounts,'neto',v_net)) returning id into v_detail;
  insert into public.nomina_descuentos(empresa_id,nomina_id,detalle_id,empleado_id,prestamo_id,tipo,monto,origen) select v_empresa,v_n.id,v_detail,v_row.id,id,'DESCU-PRES',least(pendiente,descuento_periodo),'MOTOR' from public.nomina_prestamos where empresa_id=v_empresa and empleado_id=v_row.id and estado='ENTREGADO' and pendiente>0;
  insert into public.nomina_descuentos(empresa_id,nomina_id,detalle_id,empleado_id,credito_id,tipo,monto,origen) select v_empresa,v_n.id,v_detail,v_row.id,id,'DESCU-CRED',least(pendiente,descuento_periodo),'MOTOR' from public.nomina_creditos where empresa_id=v_empresa and empleado_id=v_row.id and estado='ACTIVO' and pendiente>0;
  insert into public.nomina_descuentos(empresa_id,nomina_id,detalle_id,empleado_id,tipo,monto,origen)
  select v_empresa,v_n.id,v_detail,v_row.id,x.tipo,x.monto,'MOTOR' from(values('AFP',v_afp),('SFS',v_sfs),('OTRO_IMPUESTO',v_other_tax))x(tipo,monto) where x.monto>0;
  insert into public.nomina_descuentos(empresa_id,nomina_id,detalle_id,empleado_id,ajuste_id,tipo,monto,origen)
  select v_empresa,v_n.id,v_detail,v_row.id,a.id,a.tipo,a.monto,a.origen from public.nomina_ajustes a where a.empresa_id=v_empresa and a.periodo_id=p_periodo and a.empleado_id=v_row.id and a.activo and a.tipo<>'INCENTIVO' and a.monto>0;
 end loop;
 select jsonb_build_object('empleados',count(*),'total_sueldos',coalesce(sum(sueldo_base),0),'total_horas_extras',coalesce(sum(total_horas_extras),0),'total_incentivos',coalesce(sum(incentivos),0),'total_prestamos',coalesce(sum(descuento_prestamo),0),'total_creditos',coalesce(sum(descuento_credito),0),'total_impuestos',coalesce(sum(total_impuestos),0),'total_otros_descuentos',coalesce(sum(rotura_falta+otros_descuentos),0),'total_general_pagado',coalesce(sum(neto),0)) into v_summary from public.nomina_detalles where empresa_id=v_empresa and nomina_id=v_n.id;
 update public.nominas set estado='CALCULADA',version_calculo=v_version,motor_version=1,formula='RC4_SQL_V1',desactualizada=false,errores='[]',resumen=v_summary,calculada_en=now(),actualizada_en=now(),jornadas_actualizadas_hasta=(select max(actualizada_en) from public.jornadas where empresa_id=v_empresa and fecha_laboral between v_p.fecha_inicio and v_p.fecha_fin) where id=v_n.id;
 update public.nomina_periodos set estado='CALCULADA',calculada_en=now() where id=p_periodo;
 insert into public.nomina_auditoria(empresa_id,periodo_id,nomina_id,actor_id,accion,despues) values(v_empresa,p_periodo,v_n.id,auth.uid(),case when v_version=1 then 'CALCULAR' else 'RECALCULAR' end,jsonb_build_object('version',v_version,'resumen',v_summary));return jsonb_build_object('periodo_id',p_periodo,'nomina_id',v_n.id,'version',v_version,'resumen',v_summary);
end $$;

create or replace function public.cambiar_estado_nomina(p_periodo uuid,p_estado text,p_motivo text) returns void
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_p public.nomina_periodos%rowtype;v_n public.nominas%rowtype;v_perm text;v_antes jsonb;
begin
 select * into v_p from public.nomina_periodos where empresa_id=v_empresa and id=p_periodo for update;if not found then raise exception 'PERIODO_NO_ENCONTRADO';end if;select * into v_n from public.nominas where empresa_id=v_empresa and periodo_id=p_periodo for update;v_antes:=to_jsonb(v_p);
 v_perm:=case p_estado when 'EN_REVISION' then 'nomina.editar' when 'APROBADA' then 'nomina.aprobar' when 'CERRADA' then 'nomina.cerrar' when 'ANULADA' then 'nomina.anular' else null end;if v_perm is null then raise exception 'ESTADO_DESTINO_INVALIDO';end if;perform public.nomina_empresa_autorizada(v_perm);if btrim(coalesce(p_motivo,''))='' then raise exception 'MOTIVO_REQUERIDO';end if;
 if not((v_p.estado='CALCULADA' and p_estado='EN_REVISION') or(v_p.estado='EN_REVISION' and p_estado='APROBADA')or(v_p.estado='APROBADA' and p_estado='CERRADA')or(v_p.estado in('BORRADOR','CALCULADA','EN_REVISION','APROBADA')and p_estado='ANULADA')) then raise exception 'TRANSICION_NOMINA_INVALIDA';end if;
 if p_estado in('APROBADA','CERRADA') and(v_n.desactualizada or jsonb_array_length(v_n.errores)>0)then raise exception 'NOMINA_DESACTUALIZADA_O_CON_ERRORES';end if;
 if p_estado='CERRADA' then
  update public.nomina_prestamos p set total_pagado=least(p.monto_total,p.total_pagado+d.monto),pendiente=greatest(0,p.pendiente-d.monto),estado=case when greatest(0,p.pendiente-d.monto)=0 then 'PAGADO' else p.estado end,fecha_final=case when greatest(0,p.pendiente-d.monto)=0 then current_date else p.fecha_final end,actualizado_en=now() from public.nomina_descuentos d where d.empresa_id=v_empresa and d.nomina_id=v_n.id and d.prestamo_id=p.id and not d.aplicado;
  update public.nomina_creditos c set total_descontado=least(c.monto_total,c.total_descontado+d.monto),pendiente=greatest(0,c.pendiente-d.monto),estado=case when greatest(0,c.pendiente-d.monto)=0 then 'PAGADO' else c.estado end,fecha_final=case when greatest(0,c.pendiente-d.monto)=0 then current_date else c.fecha_final end,actualizado_en=now() from public.nomina_descuentos d where d.empresa_id=v_empresa and d.nomina_id=v_n.id and d.credito_id=c.id and not d.aplicado;
  update public.nomina_descuentos set aplicado=true where empresa_id=v_empresa and nomina_id=v_n.id;
 end if;
 update public.nomina_periodos set estado=p_estado,aprobada_en=case when p_estado='APROBADA'then now()else aprobada_en end,aprobada_por=case when p_estado='APROBADA'then auth.uid()else aprobada_por end,cerrada_en=case when p_estado='CERRADA'then now()else cerrada_en end,cerrada_por=case when p_estado='CERRADA'then auth.uid()else cerrada_por end,anulada_en=case when p_estado='ANULADA'then now()else anulada_en end,anulada_por=case when p_estado='ANULADA'then auth.uid()else anulada_por end where id=p_periodo;
 update public.nominas set estado=p_estado,actualizada_en=now() where id=v_n.id;insert into public.nomina_auditoria(empresa_id,periodo_id,nomina_id,actor_id,accion,antes,despues,motivo) values(v_empresa,p_periodo,v_n.id,auth.uid(),p_estado,v_antes,jsonb_build_object('estado',p_estado),btrim(p_motivo));
end $$;

create or replace function public.listar_nomina_periodos() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.ver');v_result jsonb;
begin select coalesce(jsonb_agg(to_jsonb(x) order by x.fecha_inicio desc),'[]'::jsonb) into v_result from(select p.id,p.fecha_inicio,p.fecha_fin,p.tipo_periodo,p.estado,n.id nomina_id,n.version_calculo,n.desactualizada,n.errores,n.resumen from public.nomina_periodos p join public.nominas n on n.empresa_id=p.empresa_id and n.periodo_id=p.id where p.empresa_id=v_empresa)x;return v_result;end $$;

create or replace function public.listar_empleados_nomina() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.ver');v_result jsonb;
begin
 select coalesce(jsonb_agg(jsonb_build_object('id',e.id,'codigo',e.codigo_empleado,'nombre',e.nombre_completo,'salario',e.salario,'tipo_pago',e.tipo_pago) order by e.codigo_empleado),'[]'::jsonb)
 into v_result from public.empleados e where e.empresa_id=v_empresa and e.activo;
 return v_result;
end $$;

create or replace function public.obtener_reglas_nomina() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.ver');v_result jsonb;
begin
 select jsonb_build_object(
  'global',coalesce((select to_jsonb(r) from public.nomina_reglas r where r.empresa_id=v_empresa),jsonb_build_object('dias_divisor_quincenal',15,'horas_dia',8,'porcentaje_extra',0,'porcentaje_nocturno',0,'afp_modo','MONTO','afp_valor',0,'sfs_modo','MONTO','sfs_valor',0,'otros_impuestos_modo','MONTO','otros_impuestos_valor',0,'incentivo_periodo',0,'version',0)),
  'empleados',coalesce((select jsonb_agg(to_jsonb(r) order by r.empleado_id)from public.nomina_reglas_empleado r where r.empresa_id=v_empresa),'[]'::jsonb)
 )into v_result;
 return v_result;
end $$;

create or replace function public.obtener_nomina(p_periodo uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.ver');v_result jsonb;
begin select jsonb_build_object('periodo',to_jsonb(p),'nomina',to_jsonb(n),'detalles',coalesce((select jsonb_agg(to_jsonb(d) order by d.codigo_empleado)from public.nomina_detalles d where d.empresa_id=v_empresa and d.nomina_id=n.id),'[]'::jsonb),'ajustes',coalesce((select jsonb_agg(to_jsonb(a) order by a.creado_en desc)from public.nomina_ajustes a where a.empresa_id=v_empresa and a.periodo_id=p.id and a.activo),'[]'::jsonb),'prestamos',coalesce((select jsonb_agg(to_jsonb(l) order by l.creado_en desc)from public.nomina_prestamos l where l.empresa_id=v_empresa),'[]'::jsonb),'creditos',coalesce((select jsonb_agg(to_jsonb(c) order by c.creado_en desc)from public.nomina_creditos c where c.empresa_id=v_empresa),'[]'::jsonb),'auditoria',coalesce((select jsonb_agg(to_jsonb(a) order by a.fecha desc)from(select * from public.nomina_auditoria where empresa_id=v_empresa and periodo_id=p.id order by fecha desc limit 100)a),'[]'::jsonb)) into v_result from public.nomina_periodos p join public.nominas n on n.empresa_id=p.empresa_id and n.periodo_id=p.id where p.empresa_id=v_empresa and p.id=p_periodo;if v_result is null then raise exception 'PERIODO_NO_ENCONTRADO';end if;return v_result;end $$;

create or replace function public.registrar_exportacion_nomina(p_periodo uuid,p_tipo text,p_nombre text,p_metadata jsonb default '{}'::jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.nomina_empresa_autorizada('nomina.exportar');v_nomina uuid;v_id uuid;
begin if p_tipo not in('PLANTILLA','IMPORTACION','EXCEL_FINAL','PDF_FINAL')then raise exception 'TIPO_ARCHIVO_INVALIDO';end if;select id into v_nomina from public.nominas where empresa_id=v_empresa and periodo_id=p_periodo;insert into public.nomina_archivos(empresa_id,periodo_id,nomina_id,tipo,nombre,mime,metadata,creado_por)values(v_empresa,p_periodo,v_nomina,p_tipo,btrim(p_nombre),case when p_tipo='PDF_FINAL'then'application/pdf'else'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'end,coalesce(p_metadata,'{}'),auth.uid())returning id into v_id;insert into public.nomina_auditoria(empresa_id,periodo_id,nomina_id,actor_id,accion,despues)values(v_empresa,p_periodo,v_nomina,auth.uid(),'EXPORTAR_'||p_tipo,jsonb_build_object('archivo_id',v_id,'nombre',p_nombre));return v_id;end $$;

create or replace function public.marcar_nomina_desactualizada() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid;v_fecha date;
begin
 if tg_op='DELETE'then v_empresa:=old.empresa_id;v_fecha:=old.fecha_laboral;else v_empresa:=new.empresa_id;v_fecha:=new.fecha_laboral;end if;
 with afectadas as(
  update public.nominas n set desactualizada=true,actualizada_en=now() from public.nomina_periodos p
  where n.empresa_id=v_empresa and p.empresa_id=n.empresa_id and p.id=n.periodo_id and v_fecha between p.fecha_inicio and p.fecha_fin and n.estado in('CALCULADA','EN_REVISION','APROBADA')
  returning n.empresa_id,n.periodo_id,n.id
 )
 insert into public.nomina_auditoria(empresa_id,periodo_id,nomina_id,accion,despues)
 select empresa_id,periodo_id,id,'JORNADA_CAMBIADA',jsonb_build_object('fecha_laboral',v_fecha,'operacion',tg_op) from afectadas;
 if tg_op='DELETE'then return old;else return new;end if;
end $$;
revoke all on function public.marcar_nomina_desactualizada() from public,anon,authenticated;
create trigger jornadas_dirty_payroll_rc4 after insert or update or delete on public.jornadas for each row execute function public.marcar_nomina_desactualizada();

do $$declare t text;begin foreach t in array array['nomina_reglas','nomina_reglas_empleado','nomina_periodos','nominas','nomina_detalles','nomina_descuentos','nomina_prestamos','nomina_creditos','nomina_ajustes','nomina_auditoria','nomina_archivos'] loop execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);execute format('grant all on public.%I to service_role',t);execute format('create policy %I on public.%I for select to authenticated using(empresa_id=public.obtener_empresa_actual() and public.tiene_permiso(''nomina.ver''))',t||'_select_rc4',t);end loop;end $$;

revoke all on function public.crear_periodo_nomina(date,date,text),public.configurar_regla_nomina(uuid,jsonb,text),public.crear_prestamo_nomina(uuid,numeric,numeric,date,text),public.crear_credito_nomina(uuid,numeric,numeric,date,text),public.cambiar_estado_prestamo_nomina(uuid,text,text),public.cancelar_credito_nomina(uuid,text),public.aplicar_descuentos_nomina(uuid,jsonb,text,text),public.calcular_nomina(uuid),public.cambiar_estado_nomina(uuid,text,text),public.listar_nomina_periodos(),public.listar_empleados_nomina(),public.obtener_reglas_nomina(),public.obtener_nomina(uuid),public.registrar_exportacion_nomina(uuid,text,text,jsonb) from public,anon;
grant execute on function public.crear_periodo_nomina(date,date,text),public.configurar_regla_nomina(uuid,jsonb,text),public.crear_prestamo_nomina(uuid,numeric,numeric,date,text),public.crear_credito_nomina(uuid,numeric,numeric,date,text),public.cambiar_estado_prestamo_nomina(uuid,text,text),public.cancelar_credito_nomina(uuid,text),public.aplicar_descuentos_nomina(uuid,jsonb,text,text),public.calcular_nomina(uuid),public.cambiar_estado_nomina(uuid,text,text),public.listar_nomina_periodos(),public.listar_empleados_nomina(),public.obtener_reglas_nomina(),public.obtener_nomina(uuid),public.registrar_exportacion_nomina(uuid,text,text,jsonb) to authenticated;

commit;
