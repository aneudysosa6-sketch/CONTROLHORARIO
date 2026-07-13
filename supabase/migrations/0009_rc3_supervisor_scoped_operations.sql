-- RC3: operaciones de supervisor limitadas por empresa, sucursal y departamento.
begin;

insert into public.permisos(codigo,nombre,modulo,activo) values
 ('supervisor.dashboard','Ver dashboard del equipo','supervisor',true),
 ('empleados.ver_asignados','Ver empleados asignados','supervisor',true),
 ('empleados.ver_telefono_asignado','Ver telefono operativo asignado','supervisor',true),
 ('jornadas.corregir_asignadas','Corregir jornadas asignadas','supervisor',true),
 ('jornadas.aprobar_pendientes_asignadas','Aprobar pendientes asignadas','supervisor',true),
 ('incidencias.ver_asignadas','Ver incidencias asignadas','supervisor',true),
 ('incidencias.resolver_asignadas','Resolver incidencias asignadas','supervisor',true),
 ('horarios.ver_asignados','Ver horarios asignados','supervisor',true),
 ('horarios.editar_asignados','Editar horarios asignados','supervisor',true)
on conflict(codigo) do update set nombre=excluded.nombre,modulo=excluded.modulo,activo=true;

-- Base conservadora: el rol supervisor recibe lectura. Las mutaciones requieren
-- concesion explicita en perfil_permisos. El administrador conserva acceso total.
insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'departamento'
from public.roles r join public.permisos p on p.codigo in(
 'portal.acceder','portal.ver_dashboard','supervisor.dashboard','empleados.ver_asignados','jornadas.ver_asignadas',
 'incidencias.ver_asignadas','horarios.ver_asignados')
where r.code='supervisor' and r.is_active
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='departamento';

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'empresa'
from public.roles r join public.permisos p on p.codigo in(
 'jornadas.corregir_asignadas','jornadas.aprobar_pendientes_asignadas',
 'incidencias.resolver_asignadas','horarios.editar_asignados')
where r.code='admin' and r.is_active
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

create or replace function public.es_supervisor_actual() returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.profiles p join public.roles r
   on r.id=p.role_id and r.company_id=p.company_id
  where p.id=(select auth.uid()) and p.status='active'
    and r.code='supervisor' and r.is_active
 )
$$;
revoke all on function public.es_supervisor_actual() from public,anon;
grant execute on function public.es_supervisor_actual() to authenticated;

create or replace function public.supervisor_puede_ver_empleado(p_empleado uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(
  select 1
  from public.profiles p
  join public.roles r on r.id=p.role_id and r.company_id=p.company_id and r.code='supervisor' and r.is_active
  join public.empleados e on e.id=p_empleado and e.empresa_id=p.company_id
  join public.departments d on d.id=e.departamento_id and d.company_id=e.empresa_id and d.branch_id=e.sucursal_id
  where p.id=(select auth.uid()) and p.status='active'
   and public.tiene_permiso('empleados.ver_asignados')
   and e.sucursal_id is not null and e.departamento_id is not null
   and (
    e.sucursal_id=p.branch_id or exists(
     select 1 from public.perfil_sucursales ps where ps.perfil_id=p.id and ps.sucursal_id=e.sucursal_id
    )
   )
   and (
    e.departamento_id=p.department_id or exists(
     select 1 from public.perfil_departamentos pd where pd.perfil_id=p.id and pd.departamento_id=e.departamento_id
    )
   )
 )
$$;
revoke all on function public.supervisor_puede_ver_empleado(uuid) from public,anon;
grant execute on function public.supervisor_puede_ver_empleado(uuid) to authenticated;

create or replace function public.validar_alcance_supervisor() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_profile public.profiles%rowtype;v_department public.departments%rowtype;v_role text;
begin
 select * into strict v_profile from public.profiles where id=new.perfil_id;
 select code into strict v_role from public.roles where id=v_profile.role_id and company_id=v_profile.company_id;
 if tg_table_name='perfil_sucursales' then
  if not exists(select 1 from public.branches b where b.id=new.sucursal_id and b.company_id=v_profile.company_id) then
   raise exception 'SUPERVISOR_BRANCH_CROSS_COMPANY';
  end if;
 else
  select * into strict v_department from public.departments where id=new.departamento_id and company_id=v_profile.company_id;
  if v_role<>'supervisor' then return new;end if;
  if v_department.branch_id is null then raise exception 'SUPERVISOR_DEPARTMENT_REQUIRES_BRANCH';end if;
  if v_department.branch_id<>v_profile.branch_id and not exists(
   select 1 from public.perfil_sucursales ps where ps.perfil_id=new.perfil_id and ps.sucursal_id=v_department.branch_id
  ) then raise exception 'SUPERVISOR_DEPARTMENT_BRANCH_NOT_AUTHORIZED';end if;
 end if;
 return new;
end $$;
revoke all on function public.validar_alcance_supervisor() from public,anon,authenticated;
create trigger perfil_sucursales_validate_rc3 before insert or update on public.perfil_sucursales
 for each row execute function public.validar_alcance_supervisor();
create trigger perfil_departamentos_validate_rc3 before insert or update on public.perfil_departamentos
 for each row execute function public.validar_alcance_supervisor();

create or replace function public.proteger_sucursal_asignada_supervisor() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(
  select 1 from public.profiles p join public.roles r on r.id=p.role_id and r.company_id=p.company_id and r.code='supervisor'
  join public.perfil_departamentos pd on pd.perfil_id=p.id join public.departments d on d.id=pd.departamento_id and d.company_id=p.company_id
  where p.id=old.perfil_id and d.branch_id=old.sucursal_id and p.branch_id is distinct from old.sucursal_id
 ) then raise exception 'SUPERVISOR_BRANCH_HAS_ASSIGNED_DEPARTMENTS';end if;
 return old;
end $$;
revoke all on function public.proteger_sucursal_asignada_supervisor() from public,anon,authenticated;
create trigger perfil_sucursales_protect_rc3 before delete on public.perfil_sucursales for each row execute function public.proteger_sucursal_asignada_supervisor();

create or replace function public.validar_cambio_sucursal_supervisor() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.branch_id is distinct from old.branch_id and exists(
  select 1 from public.roles r join public.perfil_departamentos pd on pd.perfil_id=new.id
  join public.departments d on d.id=pd.departamento_id and d.company_id=new.company_id
  where r.id=new.role_id and r.company_id=new.company_id and r.code='supervisor'
   and d.branch_id is distinct from new.branch_id
   and not exists(select 1 from public.perfil_sucursales ps where ps.perfil_id=new.id and ps.sucursal_id=d.branch_id)
 ) then raise exception 'SUPERVISOR_PRIMARY_BRANCH_INVALIDATES_DEPARTMENTS';end if;
 return new;
end $$;
revoke all on function public.validar_cambio_sucursal_supervisor() from public,anon,authenticated;
create trigger profiles_validate_supervisor_branch_rc3 before update of branch_id on public.profiles for each row execute function public.validar_cambio_sucursal_supervisor();

-- El rol supervisor no obtiene el expediente completo de empleados. Usa las RPC RC3.
drop policy if exists empleados_select_segun_alcance on public.empleados;
create policy empleados_select_segun_alcance on public.empleados for select to authenticated using(
 empresa_id=public.obtener_empresa_actual() and not public.es_supervisor_actual() and (
  (public.es_empleado_actual(id) and public.tiene_permiso('empleados.ver_propio'))
  or public.tiene_permiso('empleados.ver_todos')
  or (public.tiene_permiso('empleados.ver_departamento') and departamento_id is not null and departamento_id=(select p.department_id from public.profiles p where p.id=auth.uid()))
 )
);

create or replace function public.puede_ver_jornada(p_empleado uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select (p_empleado=public.obtener_empleado_actual_id())
 or public.tiene_permiso('jornadas.ver_todas')
 or (public.tiene_permiso('jornadas.ver_asignadas') and public.supervisor_puede_ver_empleado(p_empleado))
$$;
revoke all on function public.puede_ver_jornada(uuid) from public,anon;
grant execute on function public.puede_ver_jornada(uuid) to authenticated,service_role;

create table public.horarios_empleados(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null references public.companies(id) on delete restrict,
 empleado_id uuid not null,fecha_vigencia date not null default current_date,fecha_fin date,
 hora_entrada time not null,hora_salida time not null,inicio_almuerzo time,duracion_almuerzo_min integer not null default 60,
 dias_laborales smallint[] not null default array[1,2,3,4,5]::smallint[],tolerancia_min integer not null default 15,
 activo boolean not null default true,creado_por uuid references public.profiles(id),actualizado_por uuid references public.profiles(id),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now(),
 unique(empresa_id,empleado_id,fecha_vigencia),unique(empresa_id,id),
 foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict,
 check(fecha_fin is null or fecha_fin>=fecha_vigencia),check(hora_salida>hora_entrada),
 check(duracion_almuerzo_min between 0 and 240),check(tolerancia_min between 0 and 120),
 check(inicio_almuerzo is null or (inicio_almuerzo>hora_entrada and inicio_almuerzo<hora_salida and inicio_almuerzo+(duracion_almuerzo_min*interval '1 minute')<=hora_salida)),
 check(cardinality(dias_laborales) between 1 and 7)
);
create index horarios_empleados_scope_idx on public.horarios_empleados(empresa_id,empleado_id,fecha_vigencia desc);

create table public.notificaciones_internas(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null references public.companies(id) on delete restrict,
 empleado_id uuid,jornada_id uuid,tipo text not null,severidad text not null default 'INFORMATIVA',mensaje text not null,
 destinatario_perfil_id uuid references public.profiles(id) on delete cascade,leida boolean not null default false,
 creada_en timestamptz not null default now(),leida_en timestamptz,
 foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict,
 foreign key(empresa_id,jornada_id) references public.jornadas(empresa_id,id) on delete restrict
);
create index notificaciones_internas_scope_idx on public.notificaciones_internas(empresa_id,destinatario_perfil_id,leida,creada_en desc);

create table public.supervisor_auditoria(
 id bigint generated always as identity primary key,empresa_id uuid not null references public.companies(id) on delete restrict,
 actor_id uuid references public.profiles(id) on delete set null,actor_rol text not null,empleado_id uuid,jornada_id uuid,
 entidad text not null,entidad_id uuid,accion text not null,antes jsonb,despues jsonb,motivo text not null,origen text not null default 'WEB',fecha timestamptz not null default now(),
 foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict,
 foreign key(empresa_id,jornada_id) references public.jornadas(empresa_id,id) on delete restrict
);
create index supervisor_auditoria_scope_idx on public.supervisor_auditoria(empresa_id,empleado_id,fecha desc);

create or replace function public.auditar_asignacion_supervisor() returns trigger
language plpgsql security definer set search_path='' as $$
declare v_profile uuid;v_empresa uuid;v_rol text;v_entidad uuid;
begin
 if tg_op='DELETE' then v_profile:=old.perfil_id;else v_profile:=new.perfil_id;end if;
 select p.company_id into v_empresa from public.profiles p where p.id=v_profile;
 select r.code into v_rol from public.profiles p join public.roles r on r.id=p.role_id and r.company_id=p.company_id where p.id=auth.uid();
 if tg_op='DELETE' then
  v_entidad:=case when tg_table_name='perfil_sucursales' then old.sucursal_id else old.departamento_id end;
 else
  v_entidad:=case when tg_table_name='perfil_sucursales' then new.sucursal_id else new.departamento_id end;
 end if;
 insert into public.supervisor_auditoria(empresa_id,actor_id,actor_rol,entidad,entidad_id,accion,antes,despues,motivo)
 values(v_empresa,auth.uid(),coalesce(v_rol,'service_role'),tg_table_name,v_entidad,tg_op,
  case when tg_op='INSERT' then null else to_jsonb(old) end,case when tg_op='DELETE' then null else to_jsonb(new) end,'Asignacion de alcance de supervisor');
 if tg_op='DELETE' then return old;end if;return new;
end $$;
revoke all on function public.auditar_asignacion_supervisor() from public,anon,authenticated;
create trigger perfil_sucursales_audit_rc3 after insert or update or delete on public.perfil_sucursales for each row execute function public.auditar_asignacion_supervisor();
create trigger perfil_departamentos_audit_rc3 after insert or update or delete on public.perfil_departamentos for each row execute function public.auditar_asignacion_supervisor();

alter table public.horarios_empleados enable row level security;
alter table public.notificaciones_internas enable row level security;
alter table public.supervisor_auditoria enable row level security;
create policy horarios_select_scope on public.horarios_empleados for select to authenticated using(
 empresa_id=public.obtener_empresa_actual() and (public.tiene_permiso('horarios.ver_todos') or (public.tiene_permiso('horarios.ver_asignados') and public.supervisor_puede_ver_empleado(empleado_id)))
);
create policy notificaciones_select_scope on public.notificaciones_internas for select to authenticated using(
 empresa_id=public.obtener_empresa_actual() and (destinatario_perfil_id=auth.uid() or (empleado_id is not null and public.puede_ver_jornada(empleado_id)))
);
create policy supervisor_auditoria_select_scope on public.supervisor_auditoria for select to authenticated using(
 empresa_id=public.obtener_empresa_actual() and (public.tiene_permiso('jornadas.ver_todas') or (empleado_id is not null and public.supervisor_puede_ver_empleado(empleado_id)))
);
revoke all on public.horarios_empleados,public.notificaciones_internas,public.supervisor_auditoria from anon,authenticated;
grant select on public.horarios_empleados,public.notificaciones_internas,public.supervisor_auditoria to authenticated;
grant all on public.horarios_empleados,public.notificaciones_internas,public.supervisor_auditoria to service_role;

create or replace function public.puede_operar_empleado_rc3(p_empleado uuid,p_permiso text) returns boolean
language sql stable security definer set search_path='' as $$
 select public.tiene_permiso(p_permiso) and (
  (not public.es_supervisor_actual() and exists(select 1 from public.empleados e where e.id=p_empleado and e.empresa_id=public.obtener_empresa_actual()))
  or public.supervisor_puede_ver_empleado(p_empleado)
 )
$$;
revoke all on function public.puede_operar_empleado_rc3(uuid,text) from public,anon;
grant execute on function public.puede_operar_empleado_rc3(uuid,text) to authenticated;

create or replace function public.listar_empleados_supervisor() returns table(
 id uuid,codigo text,nombre text,sucursal_id uuid,sucursal text,departamento_id uuid,departamento text,cargo text,
 estado_laboral text,jornada_habilitada boolean,telefono text,estado_jornada text,ultima_accion timestamptz,incidencias_abiertas bigint,
 horario_resumen text
) language sql stable security definer set search_path='' as $$
 select e.id,e.codigo_empleado,e.nombre_completo,e.sucursal_id,b.name,e.departamento_id,d.name,coalesce(po.name,''),
  e.estado_laboral,e.jornada_habilitada,case when public.tiene_permiso('empleados.ver_telefono_asignado') then e.telefono else null end,
  coalesce(j.estado,'SIN_INICIAR'),coalesce(j.actualizada_en,j.iniciado_en),
  (select count(*) from public.jornada_incidencias i where i.jornada_id=j.id and not i.resuelta),
  case when h.id is null then '' else to_char(h.hora_entrada,'HH24:MI')||' - '||to_char(h.hora_salida,'HH24:MI') end
 from public.empleados e
 join public.branches b on b.id=e.sucursal_id and b.company_id=e.empresa_id
 join public.departments d on d.id=e.departamento_id and d.company_id=e.empresa_id
 left join public.positions po on po.id=e.puesto_id and po.company_id=e.empresa_id
 left join lateral(select * from public.jornadas x where x.empresa_id=e.empresa_id and x.empleado_id=e.id order by x.fecha_laboral desc limit 1)j on true
 left join lateral(select * from public.horarios_empleados x where x.empresa_id=e.empresa_id and x.empleado_id=e.id and x.activo order by x.fecha_vigencia desc limit 1)h on true
 where e.empresa_id=public.obtener_empresa_actual() and public.supervisor_puede_ver_empleado(e.id)
 order by e.nombre_completo
$$;
revoke all on function public.listar_empleados_supervisor() from public,anon;
grant execute on function public.listar_empleados_supervisor() to authenticated;

create or replace function public.listar_jornadas_supervisor(p_fecha date default null) returns table(
 id uuid,empleado_id uuid,codigo text,nombre text,sucursal text,departamento text,fecha_laboral date,estado text,
 iniciado_en timestamptz,pausa_iniciada_en timestamptz,pausa_finalizada_en timestamptz,finalizado_en timestamptz,
 minutos_trabajados integer,minutos_pausa integer,revision_pendiente boolean,severidad text,version_sync bigint,
 incidencias jsonb,conflictos jsonb
) language sql stable security definer set search_path='' as $$
 select j.id,j.empleado_id,e.codigo_empleado,e.nombre_completo,b.name,d.name,j.fecha_laboral,j.estado,
  j.iniciado_en,j.pausa_iniciada_en,j.pausa_finalizada_en,j.finalizado_en,j.minutos_trabajados,j.minutos_pausa,j.revision_pendiente,j.severidad,j.version_sync,
  coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'tipo',i.tipo,'severidad',i.severidad,'mensaje',i.mensaje,'leida',i.leida,'resuelta',i.resuelta,'minutos',i.minutos,'creada_en',i.creada_en) order by i.creada_en desc) from public.jornada_incidencias i where i.jornada_id=j.id),'[]'::jsonb),
  coalesce((select jsonb_agg(jsonb_build_object('id',c.id,'motivo',c.motivo,'estado',c.estado,'creado_en',c.creado_en) order by c.creado_en desc) from public.jornada_conflictos c where c.jornada_id=j.id),'[]'::jsonb)
 from public.jornadas j join public.empleados e on e.id=j.empleado_id and e.empresa_id=j.empresa_id
 join public.branches b on b.id=e.sucursal_id and b.company_id=e.empresa_id
 join public.departments d on d.id=e.departamento_id and d.company_id=e.empresa_id
 where j.empresa_id=public.obtener_empresa_actual() and public.supervisor_puede_ver_empleado(e.id)
  and (p_fecha is null or j.fecha_laboral=p_fecha)
 order by j.fecha_laboral desc,j.actualizada_en desc
$$;
revoke all on function public.listar_jornadas_supervisor(date) from public,anon;
grant execute on function public.listar_jornadas_supervisor(date) to authenticated;

create or replace function public.listar_incidencias_supervisor() returns table(
 id uuid,jornada_id uuid,empleado_id uuid,codigo text,nombre text,sucursal text,departamento text,tipo text,severidad text,
 minutos integer,mensaje text,leida boolean,resuelta boolean,creada_en timestamptz
) language sql stable security definer set search_path='' as $$
 select i.id,i.jornada_id,i.empleado_id,e.codigo_empleado,e.nombre_completo,b.name,d.name,i.tipo,i.severidad,i.minutos,i.mensaje,i.leida,i.resuelta,i.creada_en
 from public.jornada_incidencias i join public.empleados e on e.id=i.empleado_id and e.empresa_id=i.empresa_id
 join public.branches b on b.id=e.sucursal_id and b.company_id=e.empresa_id
 join public.departments d on d.id=e.departamento_id and d.company_id=e.empresa_id
 where i.empresa_id=public.obtener_empresa_actual() and public.tiene_permiso('incidencias.ver_asignadas') and public.supervisor_puede_ver_empleado(e.id)
 order by i.resuelta,i.leida,i.creada_en desc
$$;
revoke all on function public.listar_incidencias_supervisor() from public,anon;
grant execute on function public.listar_incidencias_supervisor() to authenticated;

create or replace function public.listar_horarios_supervisor() returns table(
 id uuid,empleado_id uuid,codigo text,nombre text,sucursal text,departamento text,fecha_vigencia date,fecha_fin date,
 hora_entrada time,hora_salida time,inicio_almuerzo time,duracion_almuerzo_min integer,dias_laborales smallint[],tolerancia_min integer,activo boolean
) language sql stable security definer set search_path='' as $$
 select h.id,h.empleado_id,e.codigo_empleado,e.nombre_completo,b.name,d.name,h.fecha_vigencia,h.fecha_fin,h.hora_entrada,h.hora_salida,h.inicio_almuerzo,h.duracion_almuerzo_min,h.dias_laborales,h.tolerancia_min,h.activo
 from public.horarios_empleados h join public.empleados e on e.id=h.empleado_id and e.empresa_id=h.empresa_id
 join public.branches b on b.id=e.sucursal_id and b.company_id=e.empresa_id join public.departments d on d.id=e.departamento_id and d.company_id=e.empresa_id
 where h.empresa_id=public.obtener_empresa_actual() and public.tiene_permiso('horarios.ver_asignados') and public.supervisor_puede_ver_empleado(e.id)
 order by e.nombre_completo,h.fecha_vigencia desc
$$;
revoke all on function public.listar_horarios_supervisor() from public,anon;
grant execute on function public.listar_horarios_supervisor() to authenticated;

create or replace function public.dashboard_supervisor() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_tz text;v_fecha date;v_result jsonb;
begin
 if not public.tiene_permiso('supervisor.dashboard') or not public.es_supervisor_actual() then raise exception 'ALCANCE_O_PERMISO_DENEGADO';end if;
 select timezone into v_tz from public.companies where id=v_empresa;v_fecha=(now() at time zone coalesce(v_tz,'America/Santo_Domingo'))::date;
 with equipo as(
  select e.* from public.empleados e where e.empresa_id=v_empresa and public.supervisor_puede_ver_empleado(e.id)
 ),dia as(
  select j.* from public.jornadas j join equipo e on e.id=j.empleado_id where j.fecha_laboral=v_fecha
 ),inc as(
  select i.* from public.jornada_incidencias i join equipo e on e.id=i.empleado_id where not i.resuelta
 )
 select jsonb_build_object(
  'fecha_laboral',v_fecha,'total_empleados',(select count(*) from equipo),'activos',(select count(*) from equipo where activo),
  'sin_iniciar',(select count(*) from equipo e where e.activo and e.jornada_habilitada and not exists(select 1 from dia j where j.empleado_id=e.id)),
  'en_curso',(select count(*) from dia where estado='EN_CURSO'),'en_pausa',(select count(*) from dia where estado='EN_PAUSA'),
  'finalizadas',(select count(*) from dia where estado='FINALIZADA'),'pendientes',(select count(*) from dia where revision_pendiente),
  'incidencias_nuevas',(select count(*) from inc where not leida),'jornadas_deshabilitadas',(select count(*) from equipo where not jornada_habilitada),
  'sin_iniciar_empleados',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'codigo',e.codigo_empleado,'nombre',e.nombre_completo) order by e.nombre_completo) from equipo e where e.activo and e.jornada_habilitada and not exists(select 1 from dia j where j.empleado_id=e.id)),'[]'::jsonb),
  'recientes',coalesce((select jsonb_agg(x order by x->>'actualizada_en' desc) from(
   select jsonb_build_object('id',j.id,'empleado_id',e.id,'codigo',e.codigo_empleado,'nombre',e.nombre_completo,'estado',j.estado,'actualizada_en',j.actualizada_en,'severidad',j.severidad) x
   from dia j join equipo e on e.id=j.empleado_id order by j.actualizada_en desc limit 10
  )q),'[]'::jsonb),
  'incidencias',coalesce((select jsonb_agg(x order by x->>'creada_en' desc) from(
   select jsonb_build_object('id',i.id,'jornada_id',i.jornada_id,'empleado_id',e.id,'nombre',e.nombre_completo,'tipo',i.tipo,'severidad',i.severidad,'mensaje',i.mensaje,'creada_en',i.creada_en) x
   from inc i join equipo e on e.id=i.empleado_id order by i.creada_en desc limit 10
  )q),'[]'::jsonb)||coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'jornada_id',null,'empleado_id',e.id,'nombre',e.nombre_completo,'tipo','SIN_INICIAR','severidad','ALTA','mensaje','Empleado sin iniciar jornada','creada_en',now())) from equipo e where e.activo and e.jornada_habilitada and not exists(select 1 from dia j where j.empleado_id=e.id)),'[]'::jsonb)
 ) into v_result;
 return v_result;
end $$;
revoke all on function public.dashboard_supervisor() from public,anon;
grant execute on function public.dashboard_supervisor() to authenticated;

create or replace function public.establecer_jornada_habilitada(p_empleado uuid,p_habilitada boolean,p_motivo text) returns void
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_antes jsonb;v_despues jsonb;v_rol text;v_jornada uuid;
begin
 if btrim(coalesce(p_motivo,''))='' then raise exception 'MOTIVO_REQUERIDO';end if;
 if not public.puede_operar_empleado_rc3(p_empleado,'jornadas.admin_off_on') then raise exception 'ALCANCE_O_PERMISO_DENEGADO';end if;
 select to_jsonb(e) into v_antes from public.empleados e where e.id=p_empleado and e.empresa_id=v_empresa for update;
 if v_antes is null then raise exception 'EMPLEADO_NO_ENCONTRADO';end if;
 update public.empleados set jornada_habilitada=p_habilitada,updated_at=now() where id=p_empleado returning to_jsonb(empleados.*) into v_despues;
 select r.code into v_rol from public.profiles p join public.roles r on r.id=p.role_id and r.company_id=p.company_id where p.id=auth.uid();
 select id into v_jornada from public.jornadas where empresa_id=v_empresa and empleado_id=p_empleado order by fecha_laboral desc limit 1;
 insert into public.supervisor_auditoria(empresa_id,actor_id,actor_rol,empleado_id,jornada_id,entidad,entidad_id,accion,antes,despues,motivo)
 values(v_empresa,auth.uid(),v_rol,p_empleado,v_jornada,'empleados',p_empleado,case when p_habilitada then 'ADMIN_ON' else 'ADMIN_OFF' end,v_antes-'pin_hash'-'salario',v_despues-'pin_hash'-'salario',btrim(p_motivo));
 insert into public.notificaciones_internas(empresa_id,empleado_id,jornada_id,tipo,severidad,mensaje)
 values(v_empresa,p_empleado,v_jornada,case when p_habilitada then 'ADMIN_ON' else 'ADMIN_OFF' end,case when p_habilitada then 'INFORMATIVA' else 'ALTA' end,
  case when p_habilitada then 'Registro de jornada habilitado. ' else 'Tu registro de jornada esta deshabilitado. ' end||btrim(p_motivo));
 if not p_habilitada and v_jornada is not null then
  insert into public.jornada_incidencias(empresa_id,jornada_id,empleado_id,tipo,severidad,mensaje)
  values(v_empresa,v_jornada,p_empleado,'JORNADA_DESHABILITADA','ALTA','Tu registro de jornada esta deshabilitado. Motivo: '||btrim(p_motivo));
 end if;
end $$;
revoke all on function public.establecer_jornada_habilitada(uuid,boolean,text) from public,anon;
grant execute on function public.establecer_jornada_habilitada(uuid,boolean,text) to authenticated;

create or replace function public.corregir_jornada_supervisor(
 p_jornada uuid,p_inicio timestamptz,p_pausa_inicio timestamptz,p_pausa_fin timestamptz,p_fin timestamptz,p_motivo text
) returns void language plpgsql security definer set search_path='' as $$
declare v public.jornadas%rowtype;v_antes jsonb;v_despues jsonb;v_trabajo int;v_pausa int;v_rol text;v_hoy date;v_tz text;
begin
 if btrim(coalesce(p_motivo,''))='' then raise exception 'MOTIVO_REQUERIDO';end if;
 select * into v from public.jornadas where id=p_jornada and empresa_id=public.obtener_empresa_actual() for update;
 if not found or not public.puede_operar_empleado_rc3(v.empleado_id,'jornadas.corregir_asignadas') then raise exception 'ALCANCE_O_PERMISO_DENEGADO';end if;
 select timezone into v_tz from public.companies where id=v.empresa_id;v_hoy=(now() at time zone coalesce(v_tz,'America/Santo_Domingo'))::date;
 if v.fecha_laboral>v_hoy then raise exception 'FECHA_FUTURA_NO_PERMITIDA';end if;
 if p_inicio is null or p_fin is null or p_fin<=p_inicio then raise exception 'SECUENCIA_TEMPORAL_INVALIDA';end if;
 if (p_pausa_inicio is null)<>(p_pausa_fin is null) or (p_pausa_inicio is not null and not(p_inicio<=p_pausa_inicio and p_pausa_inicio<p_pausa_fin and p_pausa_fin<=p_fin)) then raise exception 'SECUENCIA_TEMPORAL_INVALIDA';end if;
 v_pausa:=case when p_pausa_inicio is null then 0 else floor(extract(epoch from(p_pausa_fin-p_pausa_inicio))/60)::int end;
 v_trabajo:=floor(extract(epoch from(p_fin-p_inicio))/60)::int-v_pausa;if v_trabajo<0 then raise exception 'MINUTOS_NEGATIVOS';end if;
 v_antes:=to_jsonb(v);
 update public.jornadas set iniciado_en=p_inicio,pausa_iniciada_en=p_pausa_inicio,pausa_finalizada_en=p_pausa_fin,finalizado_en=p_fin,
  estado='FINALIZADA',minutos_trabajados=v_trabajo,minutos_pausa=v_pausa,revision_pendiente=false,severidad='NINGUNA',
  actualizada_por=auth.uid(),actualizada_en=now(),version_sync=version_sync+1 where id=v.id returning to_jsonb(jornadas.*) into v_despues;
 select r.code into v_rol from public.profiles p join public.roles r on r.id=p.role_id and r.company_id=p.company_id where p.id=auth.uid();
 insert into public.jornada_auditoria(empresa_id,jornada_id,actor_id,accion,antes,despues,origen) values(v.empresa_id,v.id,auth.uid(),'CORRECCION_MANUAL',v_antes,v_despues||jsonb_build_object('motivo',btrim(p_motivo)),'WEB');
 insert into public.supervisor_auditoria(empresa_id,actor_id,actor_rol,empleado_id,jornada_id,entidad,entidad_id,accion,antes,despues,motivo)
 values(v.empresa_id,auth.uid(),v_rol,v.empleado_id,v.id,'jornadas',v.id,'CORRECCION_MANUAL',v_antes,v_despues,btrim(p_motivo));
 update public.jornada_incidencias set resuelta=true,resuelta_en=now(),resuelta_por=auth.uid() where jornada_id=v.id and not resuelta;
 insert into public.notificaciones_internas(empresa_id,empleado_id,jornada_id,tipo,mensaje) values(v.empresa_id,v.empleado_id,v.id,'JORNADA_CORREGIDA','Jornada corregida: '||btrim(p_motivo));
end $$;
revoke all on function public.corregir_jornada_supervisor(uuid,timestamptz,timestamptz,timestamptz,timestamptz,text) from public,anon;
grant execute on function public.corregir_jornada_supervisor(uuid,timestamptz,timestamptz,timestamptz,timestamptz,text) to authenticated;

create or replace function public.resolver_jornada_pendiente(p_jornada uuid,p_decision text,p_motivo text) returns void
language plpgsql security definer set search_path='' as $$
declare v public.jornadas%rowtype;v_antes jsonb;v_despues jsonb;v_rol text;
begin
 if btrim(coalesce(p_motivo,''))='' then raise exception 'MOTIVO_REQUERIDO';end if;
 if p_decision not in('APROBADA','RECHAZADA','CORREGIDA','DEVUELTA') then raise exception 'DECISION_INVALIDA';end if;
 select * into v from public.jornadas where id=p_jornada and empresa_id=public.obtener_empresa_actual() for update;
 if not found or not public.puede_operar_empleado_rc3(v.empleado_id,'jornadas.aprobar_pendientes_asignadas') then raise exception 'ALCANCE_O_PERMISO_DENEGADO';end if;v_antes:=to_jsonb(v);
 update public.jornadas set revision_pendiente=(p_decision in('RECHAZADA','DEVUELTA')),actualizada_por=auth.uid(),actualizada_en=now(),version_sync=version_sync+1 where id=v.id returning to_jsonb(jornadas.*) into v_despues;
 if p_decision in('APROBADA','CORREGIDA') then update public.jornada_incidencias set resuelta=true,resuelta_en=now(),resuelta_por=auth.uid() where jornada_id=v.id and not resuelta;end if;
 update public.jornada_conflictos set estado=case when p_decision in('APROBADA','CORREGIDA') then 'RESUELTO_REMOTO' else 'RESUELTO_MANUAL' end,resuelto_en=now(),resuelto_por=auth.uid() where jornada_id=v.id and estado='PENDIENTE';
 select r.code into v_rol from public.profiles p join public.roles r on r.id=p.role_id and r.company_id=p.company_id where p.id=auth.uid();
 insert into public.jornada_auditoria(empresa_id,jornada_id,actor_id,accion,antes,despues,origen) values(v.empresa_id,v.id,auth.uid(),'RESOLVER_'||p_decision,v_antes,v_despues||jsonb_build_object('motivo',btrim(p_motivo)),'WEB');
 insert into public.supervisor_auditoria(empresa_id,actor_id,actor_rol,empleado_id,jornada_id,entidad,entidad_id,accion,antes,despues,motivo) values(v.empresa_id,auth.uid(),v_rol,v.empleado_id,v.id,'jornadas',v.id,p_decision,v_antes,v_despues,btrim(p_motivo));
 insert into public.notificaciones_internas(empresa_id,empleado_id,jornada_id,tipo,mensaje) values(v.empresa_id,v.empleado_id,v.id,'JORNADA_'||p_decision,'Jornada '||lower(p_decision)||': '||btrim(p_motivo));
end $$;
revoke all on function public.resolver_jornada_pendiente(uuid,text,text) from public,anon;
grant execute on function public.resolver_jornada_pendiente(uuid,text,text) to authenticated;

create or replace function public.resolver_incidencia_supervisor(p_incidencia uuid,p_resuelta boolean,p_comentario text) returns void
language plpgsql security definer set search_path='' as $$
declare v public.jornada_incidencias%rowtype;v_rol text;
begin
 if btrim(coalesce(p_comentario,''))='' then raise exception 'COMENTARIO_REQUERIDO';end if;
 select * into v from public.jornada_incidencias where id=p_incidencia and empresa_id=public.obtener_empresa_actual() for update;
 if not found or not public.puede_operar_empleado_rc3(v.empleado_id,'incidencias.resolver_asignadas') then raise exception 'ALCANCE_O_PERMISO_DENEGADO';end if;
 update public.jornada_incidencias set leida=true,resuelta=p_resuelta,resuelta_en=case when p_resuelta then now() else null end,resuelta_por=case when p_resuelta then auth.uid() else null end where id=v.id;
 select r.code into v_rol from public.profiles p join public.roles r on r.id=p.role_id and r.company_id=p.company_id where p.id=auth.uid();
 insert into public.supervisor_auditoria(empresa_id,actor_id,actor_rol,empleado_id,jornada_id,entidad,entidad_id,accion,antes,despues,motivo)
 values(v.empresa_id,auth.uid(),v_rol,v.empleado_id,v.jornada_id,'jornada_incidencias',v.id,case when p_resuelta then 'RESOLVER' else 'DEVOLVER' end,to_jsonb(v),jsonb_build_object('resuelta',p_resuelta),btrim(p_comentario));
end $$;
revoke all on function public.resolver_incidencia_supervisor(uuid,boolean,text) from public,anon;
grant execute on function public.resolver_incidencia_supervisor(uuid,boolean,text) to authenticated;

create or replace function public.registrar_jornada_manual_supervisor(p_empleado uuid,p_fecha date,p_inicio timestamptz,p_pausa_inicio timestamptz,p_pausa_fin timestamptz,p_fin timestamptz,p_motivo text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_id uuid;
begin
 if not public.puede_operar_empleado_rc3(p_empleado,'jornadas.corregir_asignadas') then raise exception 'ALCANCE_O_PERMISO_DENEGADO';end if;
 if exists(select 1 from public.jornadas where empresa_id=v_empresa and empleado_id=p_empleado and fecha_laboral=p_fecha) then raise exception 'JORNADA_YA_EXISTE';end if;
 insert into public.jornadas(empresa_id,empleado_id,fecha_laboral,estado,origen,revision_pendiente) values(v_empresa,p_empleado,p_fecha,'SIN_INICIAR','WEB',true) returning id into v_id;
 perform public.corregir_jornada_supervisor(v_id,p_inicio,p_pausa_inicio,p_pausa_fin,p_fin,p_motivo);
 return v_id;
end $$;
revoke all on function public.registrar_jornada_manual_supervisor(uuid,date,timestamptz,timestamptz,timestamptz,timestamptz,text) from public,anon;
grant execute on function public.registrar_jornada_manual_supervisor(uuid,date,timestamptz,timestamptz,timestamptz,timestamptz,text) to authenticated;

create or replace function public.guardar_horario_supervisor(p_empleado uuid,p_fecha date,p_entrada time,p_salida time,p_almuerzo time,p_duracion int,p_dias smallint[],p_tolerancia int,p_motivo text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_empresa uuid:=public.obtener_empresa_actual();v_id uuid;v_antes jsonb;v_despues jsonb;v_rol text;v_tz text;v_hoy date;
begin
 if btrim(coalesce(p_motivo,''))='' then raise exception 'MOTIVO_REQUERIDO';end if;
 if not public.puede_operar_empleado_rc3(p_empleado,'horarios.editar_asignados') then raise exception 'ALCANCE_O_PERMISO_DENEGADO';end if;
 select timezone into v_tz from public.companies where id=v_empresa;v_hoy=(now() at time zone coalesce(v_tz,'America/Santo_Domingo'))::date;
 if p_fecha<v_hoy or p_salida<=p_entrada or p_duracion not between 0 and 240 or p_tolerancia not between 0 and 120 or cardinality(p_dias) not between 1 and 7 or not(p_dias<@array[1,2,3,4,5,6,7]::smallint[]) or (p_almuerzo is not null and not(p_almuerzo>p_entrada and p_almuerzo+(p_duracion*interval '1 minute')<=p_salida)) then raise exception 'HORARIO_INVALIDO';end if;
 select to_jsonb(h),h.id into v_antes,v_id from public.horarios_empleados h where h.empresa_id=v_empresa and h.empleado_id=p_empleado and h.fecha_vigencia=p_fecha for update;
 insert into public.horarios_empleados(empresa_id,empleado_id,fecha_vigencia,hora_entrada,hora_salida,inicio_almuerzo,duracion_almuerzo_min,dias_laborales,tolerancia_min,creado_por,actualizado_por)
 values(v_empresa,p_empleado,p_fecha,p_entrada,p_salida,p_almuerzo,p_duracion,p_dias,p_tolerancia,auth.uid(),auth.uid())
 on conflict(empresa_id,empleado_id,fecha_vigencia) do update set hora_entrada=excluded.hora_entrada,hora_salida=excluded.hora_salida,inicio_almuerzo=excluded.inicio_almuerzo,duracion_almuerzo_min=excluded.duracion_almuerzo_min,dias_laborales=excluded.dias_laborales,tolerancia_min=excluded.tolerancia_min,actualizado_por=auth.uid(),updated_at=now()
 returning id,to_jsonb(horarios_empleados.*) into v_id,v_despues;
 update public.empleados set updated_at=now() where id=p_empleado and empresa_id=v_empresa;
 select r.code into v_rol from public.profiles p join public.roles r on r.id=p.role_id and r.company_id=p.company_id where p.id=auth.uid();
 insert into public.supervisor_auditoria(empresa_id,actor_id,actor_rol,empleado_id,entidad,entidad_id,accion,antes,despues,motivo) values(v_empresa,auth.uid(),v_rol,p_empleado,'horarios_empleados',v_id,'GUARDAR_HORARIO',v_antes,v_despues,btrim(p_motivo));
 return v_id;
end $$;
revoke all on function public.guardar_horario_supervisor(uuid,date,time,time,time,integer,smallint[],integer,text) from public,anon;
grant execute on function public.guardar_horario_supervisor(uuid,date,time,time,time,integer,smallint[],integer,text) to authenticated;

commit;
