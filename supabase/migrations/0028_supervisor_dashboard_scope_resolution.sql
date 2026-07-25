-- Corrige resolución de alcance/rol de dashboard supervisor:
-- aceptar alias del rol supervisor y devolver detalle técnico estructurado
-- para el manejo amigable en Android.

begin;

create or replace function private.normalizar_codigo_rol(p_codigo text)
returns text
language sql
immutable
set search_path = ''
as $$
  select upper(
    trim(
      regexp_replace(
        replace(replace(coalesce(p_codigo, ''), '-', ' '), '_', ' '),
        '[[:space:]]+',
        ' ',
        'g'
      )
    )
  );
$$;

create or replace function private.es_rol_supervisor_aceptado(p_codigo text)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select private.normalizar_codigo_rol(p_codigo) in ('SUPERVISOR', 'SUP', 'SUPERVISOR APP', 'SUPERVISORAPP');
$$;

create or replace function public.es_supervisor_actual()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.profiles p
    join public.roles r
      on r.id = p.role_id
     and r.company_id = p.company_id
    where p.id = (select auth.uid())
      and p.status = 'active'
      and r.is_active
      and private.es_rol_supervisor_aceptado(r.code)
  )
$$;
revoke all on function public.es_supervisor_actual() from public,anon;
grant execute on function public.es_supervisor_actual() to authenticated;

create or replace function public.supervisor_puede_ver_empleado(p_empleado uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.profiles p
    join public.roles r
      on r.id = p.role_id
     and r.company_id = p.company_id
     and private.es_rol_supervisor_aceptado(r.code)
     and r.is_active
    join public.empleados e
      on e.id = p_empleado
     and e.empresa_id = p.company_id
    join public.departments d
      on d.id = e.departamento_id
     and d.company_id = e.empresa_id
     and d.branch_id = e.sucursal_id
    where p.id = (select auth.uid())
      and p.status = 'active'
      and public.tiene_permiso('empleados.ver_asignados')
      and e.sucursal_id is not null and e.departamento_id is not null
      and (
        e.sucursal_id = p.branch_id
        or exists(
          select 1
          from public.perfil_sucursales ps
          where ps.perfil_id = p.id
            and ps.sucursal_id = e.sucursal_id
        )
      )
      and (
        e.departamento_id is null
        or e.departamento_id = p.department_id
        or exists(
          select 1
          from public.perfil_departamentos pd
          where pd.perfil_id = p.id
            and pd.departamento_id = e.departamento_id
        )
      )
  )
$$;
revoke all on function public.supervisor_puede_ver_empleado(uuid) from public,anon;
grant execute on function public.supervisor_puede_ver_empleado(uuid) to authenticated;

create or replace function public.validar_alcance_supervisor()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_profile public.profiles%rowtype;
  v_department public.departments%rowtype;
  v_role text;
begin
  select * into strict v_profile from public.profiles where id = new.perfil_id;
  select code into strict v_role
    from public.roles
    where id = v_profile.role_id
      and company_id = v_profile.company_id;
  if tg_table_name = 'perfil_sucursales' then
    if not exists(
      select 1
      from public.branches b
      where b.id = new.sucursal_id
        and b.company_id = v_profile.company_id
    ) then
      raise exception 'SUPERVISOR_BRANCH_CROSS_COMPANY';
    end if;
  else
    select * into strict v_department
    from public.departments
    where id = new.departamento_id
      and company_id = v_profile.company_id;
    if not private.es_rol_supervisor_aceptado(v_role) then
      return new;
    end if;
    if v_department.branch_id is null then
      raise exception 'SUPERVISOR_DEPARTMENT_REQUIRES_BRANCH';
    end if;
    if v_department.branch_id <> v_profile.branch_id
      and not exists(
        select 1
        from public.perfil_sucursales ps
        where ps.perfil_id = new.perfil_id
          and ps.sucursal_id = v_department.branch_id
      ) then
      raise exception 'SUPERVISOR_DEPARTMENT_BRANCH_NOT_AUTHORIZED';
    end if;
  end if;
  return new;
end $$;
revoke all on function public.validar_alcance_supervisor() from public,anon,authenticated;

create or replace function public.dashboard_supervisor()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.obtener_empresa_actual();
  v_tz text;
  v_fecha date;
  v_result jsonb;
  v_role_code text;
  v_tiene_permiso boolean;
  v_departamentos_count integer;
  v_resultado_scope text;
begin
  select private.normalizar_codigo_rol(r.code)
    into v_role_code
    from public.profiles p
    join public.roles r
      on r.id = p.role_id
     and r.company_id = p.company_id
    where p.id = (select auth.uid())
      and p.status = 'active'
    limit 1;

  v_tiene_permiso := public.tiene_permiso('supervisor.dashboard');
  select count(*)::int into v_departamentos_count
  from public.perfil_departamentos pd
  where pd.perfil_id = (select auth.uid());

  if v_role_code is null or v_empresa is null then
    v_resultado_scope := 'PERFIL_INCONSISTENTE';
  elseif not v_tiene_permiso then
    v_resultado_scope := 'SIN_PERMISO';
  elseif not private.es_rol_supervisor_aceptado(v_role_code) then
    v_resultado_scope := 'ROL_NO_SUPERVISOR';
  elseif v_departamentos_count = 0 then
    v_resultado_scope := 'SIN_DEPARTAMENTOS';
  else
    v_resultado_scope := 'OK';
  end if;

  if v_resultado_scope <> 'OK' then
    raise exception using
      errcode = 'P0001',
      message = 'ALCANCE_O_PERMISO_DENEGADO',
      detail = jsonb_build_object(
        'user_id_presente', (select auth.uid()) is not null,
        'empresa_id_presente', v_empresa is not null,
        'role_code', coalesce(v_role_code, ''),
        'permiso_solicitado', 'supervisor.dashboard',
        'departamentos_asignados_count', coalesce(v_departamentos_count, 0),
        'resultado_scope', v_resultado_scope
      )::text,
      hint = v_resultado_scope;
  end if;

  select timezone into v_tz
    from public.companies where id = v_empresa;
  v_fecha = (now() at time zone coalesce(v_tz, 'America/Santo_Domingo'))::date;

  with equipo as(
    select e.*
    from public.empleados e
    where e.empresa_id = v_empresa
      and public.supervisor_puede_ver_empleado(e.id)
  ),
  dia as(
    select j.*
    from public.jornadas j
    join equipo e on e.id = j.empleado_id
    where j.fecha_laboral = v_fecha
  ),
  inc as(
    select i.*
    from public.jornada_incidencias i
    join equipo e on e.id = i.empleado_id
    where not i.resuelta
  )
  select jsonb_build_object(
    'fecha_laboral', v_fecha,
    'total_empleados', (select count(*) from equipo),
    'activos', (select count(*) from equipo where activo),
    'sin_iniciar', (select count(*) from equipo e where e.activo and e.jornada_habilitada and not exists(select 1 from dia j where j.empleado_id = e.id)),
    'en_curso', (select count(*) from dia where estado = 'EN_CURSO'),
    'en_pausa', (select count(*) from dia where estado = 'EN_PAUSA'),
    'finalizadas', (select count(*) from dia where estado = 'FINALIZADA'),
    'pendientes', (select count(*) from dia where revision_pendiente),
    'incidencias_nuevas', (select count(*) from inc where not leida),
    'jornadas_deshabilitadas', (select count(*) from equipo where not jornada_habilitada),
    'sin_iniciar_empleados', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'codigo', e.codigo_empleado, 'nombre', e.nombre_completo) order by e.nombre_completo) from equipo e where e.activo and e.jornada_habilitada and not exists(select 1 from dia j where j.empleado_id = e.id)), '[]'::jsonb),
    'recientes', coalesce((
      select jsonb_agg(x order by x->>'actualizada_en' desc)
      from (
        select jsonb_build_object(
          'id', j.id,
          'empleado_id', e.id,
          'codigo', e.codigo_empleado,
          'nombre', e.nombre_completo,
          'estado', j.estado,
          'actualizada_en', j.actualizada_en,
          'severidad', j.severidad
        ) x
        from dia j
        join equipo e on e.id = j.empleado_id
        order by j.actualizada_en desc
        limit 10
      ) q
    ), '[]'::jsonb),
    'incidencias', coalesce((
      select jsonb_agg(x order by x->>'creada_en' desc)
      from (
        select jsonb_build_object(
          'id', i.id,
          'jornada_id', i.jornada_id,
          'empleado_id', e.id,
          'nombre', e.nombre_completo,
          'tipo', i.tipo,
          'severidad', i.severidad,
          'mensaje', i.mensaje,
          'creada_en', i.creada_en
        ) x
        from inc i
        join equipo e on e.id = i.empleado_id
        order by i.creada_en desc
        limit 10
      ) q
    ), '[]'::jsonb) ||
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', e.id,
          'jornada_id', null,
          'empleado_id', e.id,
          'nombre', e.nombre_completo,
          'tipo', 'SIN_INICIAR',
          'severidad', 'ALTA',
          'mensaje', 'Empleado sin iniciar jornada',
          'creada_en', now()
        )
      )
      from equipo e
      where e.activo
        and e.jornada_habilitada
        and not exists(select 1 from dia j where j.empleado_id = e.id)
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end $$;
revoke all on function public.dashboard_supervisor() from public,anon;
grant execute on function public.dashboard_supervisor() to authenticated;

commit;
