begin;

set local search_path = public, extensions, pg_catalog;

-- 0043 resolves canonical daily economic objectives. It deliberately does
-- not write payroll movements or touch the immutable 0038 ledger.
create table public.nomina_resoluciones_diarias (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  fecha_local date not null,
  revision bigint not null,
  estado text not null default 'RESUELTA',
  formula text not null default 'DAILY_FIXED_SALARY_V1',
  fuente_economica text not null,
  timezone text not null,
  iso_dia smallint not null,
  minutos_programados integer not null,
  minutos_trabajados integer not null,
  minutos_normales_reconocidos integer not null,
  minutos_extra integer not null,
  sueldo_mensual numeric(14,2) not null,
  valor_dia numeric(18,6) not null,
  valor_quincena numeric(18,6) not null,
  valor_hora_extra numeric(14,2) not null,
  monto_normal_reconocido numeric(14,2) not null,
  cobertura_tipo text,
  cobertura_porcentaje numeric(5,2),
  es_festivo boolean not null,
  es_dia_libre_automatico boolean not null,
  es_dia_libre_manual boolean not null,
  es_ausencia boolean not null,
  jornada_id uuid,
  asignacion_horario_id uuid not null,
  plantilla_version_id uuid not null,
  plantilla_dia_id uuid not null,
  condicion_salarial_id uuid not null,
  dia_libre_id uuid,
  dia_libre_detalle_id uuid,
  cobertura_id uuid,
  festivo_id uuid,
  objetivo_base_nominal numeric(14,2) not null,
  objetivo_ajuste_diario numeric(14,2) not null,
  objetivo_hora_extra numeric(14,2) not null,
  objetivo_premium_festivo numeric(14,2) not null,
  objetivo_complemento_30_dias numeric(14,2) not null,
  objetivo_total numeric(14,2) generated always as (
    round(
      objetivo_base_nominal
      + objetivo_ajuste_diario
      + objetivo_hora_extra
      + objetivo_premium_festivo
      + objetivo_complemento_30_dias,
      2
    )
  ) stored,
  snapshot jsonb not null,
  input_hash text not null,
  motivo text not null,
  actor_id uuid,
  created_at timestamptz not null default clock_timestamp(),
  constraint nomina_resoluciones_diarias_revision_check check (revision > 0),
  constraint nomina_resoluciones_diarias_estado_check
    check (estado = 'RESUELTA'),
  constraint nomina_resoluciones_diarias_formula_check
    check (formula = 'DAILY_FIXED_SALARY_V1'),
  constraint nomina_resoluciones_diarias_fuente_check check (
    fuente_economica in (
      'JORNADA', 'VACACIONES', 'LICENCIA', 'FESTIVO',
      'DIA_LIBRE_AUTOMATICO', 'DIA_LIBRE_MANUAL', 'AUSENCIA'
    )
  ),
  constraint nomina_resoluciones_diarias_iso_check check (iso_dia between 1 and 7),
  constraint nomina_resoluciones_diarias_minutos_check check (
    minutos_programados between 0 and 1440
    and minutos_trabajados >= 0
    and minutos_normales_reconocidos >= 0
    and minutos_normales_reconocidos <= minutos_trabajados
    and minutos_extra >= 0
  ),
  constraint nomina_resoluciones_diarias_valores_check check (
    sueldo_mensual > 0
    and valor_dia > 0
    and valor_quincena > 0
    and valor_hora_extra >= 0
    and monto_normal_reconocido >= 0
    and objetivo_base_nominal >= 0
    and objetivo_hora_extra >= 0
    and objetivo_premium_festivo >= 0
    and objetivo_complemento_30_dias = 0
  ),
  constraint nomina_resoluciones_diarias_cobertura_check check (
    (
      cobertura_tipo is null
      and cobertura_porcentaje is null
      and cobertura_id is null
    )
    or (
      cobertura_tipo = 'LICENCIA'
      and cobertura_porcentaje between 0 and 100
      and cobertura_id is not null
    )
    or (
      cobertura_tipo = 'VACACIONES'
      and cobertura_porcentaje = 100
      and cobertura_id is not null
    )
  ),
  constraint nomina_resoluciones_diarias_snapshot_check
    check (jsonb_typeof(snapshot) = 'object'),
  constraint nomina_resoluciones_diarias_hash_check
    check (input_hash ~ '^[0-9a-f]{64}$'),
  constraint nomina_resoluciones_diarias_motivo_check
    check (char_length(btrim(motivo)) between 3 and 500),
  constraint nomina_resoluciones_diarias_empresa_id_id_unique
    unique (empresa_id, id),
  constraint nomina_resoluciones_diarias_fuente_revision_unique
    unique (empresa_id, empleado_id, fecha_local, revision),
  constraint nomina_resoluciones_diarias_empleado_fk
    foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  constraint nomina_resoluciones_diarias_actor_fk
    foreign key (empresa_id, actor_id)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_resoluciones_diarias_jornada_fk
    foreign key (empresa_id, jornada_id)
    references public.jornadas(empresa_id, id) on delete restrict,
  constraint nomina_resoluciones_diarias_asignacion_fk
    foreign key (empresa_id, asignacion_horario_id)
    references public.nomina_asignaciones_horario(empresa_id, id)
    on delete restrict,
  constraint nomina_resoluciones_diarias_plantilla_version_fk
    foreign key (empresa_id, plantilla_version_id)
    references public.nomina_plantilla_horario_versiones(empresa_id, id)
    on delete restrict,
  constraint nomina_resoluciones_diarias_plantilla_dia_fk
    foreign key (empresa_id, plantilla_dia_id)
    references public.nomina_plantilla_horario_dias(empresa_id, id)
    on delete restrict,
  constraint nomina_resoluciones_diarias_condicion_fk
    foreign key (empresa_id, condicion_salarial_id)
    references public.nomina_condiciones_salariales(empresa_id, id)
    on delete restrict,
  constraint nomina_resoluciones_diarias_dia_libre_fk
    foreign key (empresa_id, dia_libre_id)
    references public.nomina_dias_libres(empresa_id, id) on delete restrict,
  constraint nomina_resoluciones_diarias_dia_libre_detalle_fk
    foreign key (empresa_id, dia_libre_detalle_id)
    references public.nomina_dia_libre_dias(empresa_id, id) on delete restrict,
  constraint nomina_resoluciones_diarias_cobertura_fk
    foreign key (empresa_id, cobertura_id)
    references public.nomina_coberturas(empresa_id, id) on delete restrict,
  constraint nomina_resoluciones_diarias_festivo_fk
    foreign key (empresa_id, festivo_id)
    references public.nomina_festivos(empresa_id, id) on delete restrict
);

create index nomina_resoluciones_diarias_actual_idx
  on public.nomina_resoluciones_diarias(
    empresa_id, empleado_id, fecha_local, revision desc
  );
create index nomina_resoluciones_diarias_fecha_idx
  on public.nomina_resoluciones_diarias(empresa_id, fecha_local, empleado_id);

create table public.nomina_cierres_diarios (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  fecha_local date not null,
  timezone text not null,
  origen text not null,
  intento bigint not null,
  estado text not null,
  empleados_objetivo integer not null,
  resoluciones_nuevas integer not null,
  resoluciones_reutilizadas integer not null,
  errores integer not null,
  detalle jsonb not null,
  motivo text not null,
  actor_id uuid,
  created_at timestamptz not null default clock_timestamp(),
  constraint nomina_cierres_diarios_estado_check
    check (estado in ('COMPLETADO', 'CON_ERRORES')),
  constraint nomina_cierres_diarios_origen_check
    check (origen in ('MANUAL', 'AUTOMATICO')),
  constraint nomina_cierres_diarios_intento_check check (intento > 0),
  constraint nomina_cierres_diarios_actor_origen_check check (
    (origen = 'MANUAL' and actor_id is not null)
    or (origen = 'AUTOMATICO' and actor_id is null)
  ),
  constraint nomina_cierres_diarios_contadores_check check (
    empleados_objetivo >= 0
    and resoluciones_nuevas >= 0
    and resoluciones_reutilizadas >= 0
    and errores >= 0
    and resoluciones_nuevas + resoluciones_reutilizadas + errores
      = empleados_objetivo
  ),
  constraint nomina_cierres_diarios_detalle_check
    check (jsonb_typeof(detalle) = 'object'),
  constraint nomina_cierres_diarios_motivo_check
    check (char_length(btrim(motivo)) between 3 and 500),
  constraint nomina_cierres_diarios_empresa_id_id_unique
    unique (empresa_id, id),
  constraint nomina_cierres_diarios_intento_unique
    unique (empresa_id, fecha_local, intento),
  constraint nomina_cierres_diarios_actor_fk
    foreign key (empresa_id, actor_id)
    references public.profiles(company_id, id) on delete restrict
);

create index nomina_cierres_diarios_lookup_idx
  on public.nomina_cierres_diarios(
    empresa_id, fecha_local, intento desc
  );

create table public.nomina_complementos_convencion_30 (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  anio integer not null,
  fecha_fin_febrero date not null,
  fecha_ancla date not null,
  revision bigint not null,
  estado text not null default 'RESUELTO',
  formula text not null default 'FEBRUARY_30DAY_COMPLEMENT_V1',
  timezone text not null,
  sueldo_mensual numeric(14,2) not null,
  valor_dia numeric(18,6) not null,
  condicion_salarial_id uuid not null,
  objetivo_complemento_30_dias numeric(14,2) not null,
  snapshot jsonb not null,
  input_hash text not null,
  motivo text not null,
  actor_id uuid,
  created_at timestamptz not null default clock_timestamp(),
  constraint nomina_complementos_convencion_30_anio_check
    check (anio between 1900 and 9999),
  constraint nomina_complementos_convencion_30_fechas_check check (
    fecha_fin_febrero = (make_date(anio, 3, 1) - 1)
    and fecha_ancla between make_date(anio, 2, 16) and fecha_fin_febrero
  ),
  constraint nomina_complementos_convencion_30_revision_check
    check (revision > 0),
  constraint nomina_complementos_convencion_30_estado_check
    check (estado = 'RESUELTO'),
  constraint nomina_complementos_convencion_30_formula_check
    check (formula = 'FEBRUARY_30DAY_COMPLEMENT_V1'),
  constraint nomina_complementos_convencion_30_valores_check check (
    sueldo_mensual > 0
    and valor_dia > 0
    and objetivo_complemento_30_dias >= 0
  ),
  constraint nomina_complementos_convencion_30_snapshot_check
    check (jsonb_typeof(snapshot) = 'object'),
  constraint nomina_complementos_convencion_30_hash_check
    check (input_hash ~ '^[0-9a-f]{64}$'),
  constraint nomina_complementos_convencion_30_motivo_check
    check (char_length(btrim(motivo)) between 3 and 500),
  constraint nomina_complementos_convencion_30_empresa_id_id_unique
    unique (empresa_id, id),
  constraint nomina_complementos_convencion_30_fuente_revision_unique
    unique (empresa_id, empleado_id, anio, revision),
  constraint nomina_complementos_convencion_30_empleado_fk
    foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  constraint nomina_complementos_convencion_30_condicion_fk
    foreign key (empresa_id, condicion_salarial_id)
    references public.nomina_condiciones_salariales(empresa_id, id)
    on delete restrict,
  constraint nomina_complementos_convencion_30_actor_fk
    foreign key (empresa_id, actor_id)
    references public.profiles(company_id, id) on delete restrict
);

create index nomina_complementos_convencion_30_actual_idx
  on public.nomina_complementos_convencion_30(
    empresa_id, empleado_id, anio, revision desc
  );

create table public.nomina_suspensiones_laborales (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  suspension_id uuid not null,
  empleado_id uuid not null,
  revision bigint not null,
  estado text not null,
  fecha_desde date not null,
  fecha_hasta date,
  periodo daterange generated always as (
    daterange(fecha_desde, fecha_hasta, '[]')
  ) stored,
  version_anterior_id uuid,
  motivo text not null,
  observacion text,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint nomina_suspensiones_revision_estado_check check (
    (
      revision = 1
      and estado = 'ABIERTA'
      and id = suspension_id
      and fecha_hasta is null
      and version_anterior_id is null
    )
    or (
      revision = 2
      and estado = 'FINALIZADA'
      and id <> suspension_id
      and fecha_hasta is not null
      and fecha_hasta >= fecha_desde
      and version_anterior_id is not null
    )
  ),
  constraint nomina_suspensiones_fechas_finitas_check check (
    pg_catalog.isfinite(fecha_desde)
    and (fecha_hasta is null or pg_catalog.isfinite(fecha_hasta))
  ),
  constraint nomina_suspensiones_motivo_check
    check (char_length(btrim(motivo)) between 3 and 500),
  constraint nomina_suspensiones_observacion_check
    check (observacion is null or char_length(observacion) <= 1000),
  constraint nomina_suspensiones_empresa_id_id_unique
    unique (empresa_id, id),
  constraint nomina_suspensiones_raiz_revision_unique
    unique (empresa_id, suspension_id, revision),
  constraint nomina_suspensiones_version_anterior_unique
    unique (empresa_id, version_anterior_id),
  constraint nomina_suspensiones_empleado_fk
    foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  constraint nomina_suspensiones_actor_fk
    foreign key (empresa_id, created_by)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_suspensiones_raiz_fk
    foreign key (empresa_id, suspension_id)
    references public.nomina_suspensiones_laborales(empresa_id, id)
    on delete restrict,
  constraint nomina_suspensiones_version_anterior_fk
    foreign key (empresa_id, version_anterior_id)
    references public.nomina_suspensiones_laborales(empresa_id, id)
    on delete restrict
);

create index nomina_suspensiones_laborales_actual_idx
  on public.nomina_suspensiones_laborales(
    empresa_id, empleado_id, suspension_id, revision desc
  );
create index nomina_suspensiones_laborales_periodo_idx
  on public.nomina_suspensiones_laborales using gist(periodo);

create or replace function private.proteger_historial_nomina_0043()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P4300',
    message = 'NOMINA_DAILY_HISTORY_IMMUTABLE';
end;
$$;

create trigger nomina_resoluciones_diarias_inmutables
before update or delete on public.nomina_resoluciones_diarias
for each row execute function private.proteger_historial_nomina_0043();
create trigger nomina_resoluciones_diarias_truncate_inmutable
before truncate on public.nomina_resoluciones_diarias
for each statement execute function private.proteger_historial_nomina_0043();
create trigger nomina_cierres_diarios_inmutables
before update or delete on public.nomina_cierres_diarios
for each row execute function private.proteger_historial_nomina_0043();
create trigger nomina_cierres_diarios_truncate_inmutable
before truncate on public.nomina_cierres_diarios
for each statement execute function private.proteger_historial_nomina_0043();
create trigger nomina_complementos_convencion_30_inmutables
before update or delete on public.nomina_complementos_convencion_30
for each row execute function private.proteger_historial_nomina_0043();
create trigger nomina_complementos_convencion_30_truncate_inmutable
before truncate on public.nomina_complementos_convencion_30
for each statement execute function private.proteger_historial_nomina_0043();
create trigger nomina_suspensiones_laborales_inmutables
before update or delete on public.nomina_suspensiones_laborales
for each row execute function private.proteger_historial_nomina_0043();
create trigger nomina_suspensiones_laborales_truncate_inmutable
before truncate on public.nomina_suspensiones_laborales
for each statement execute function private.proteger_historial_nomina_0043();

create or replace function private.validar_suspension_laboral_0043()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_anterior public.nomina_suspensiones_laborales%rowtype;
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      new.empresa_id::text || ':SUSPENSION:' || new.empleado_id::text,
      4300
    )
  );

  if new.empresa_id is null or new.empleado_id is null
     or new.suspension_id is null or new.id is null
     or new.fecha_desde is null or new.created_by is null
  then
    raise exception using
      errcode = 'P4314', message = 'EMPLOYEE_SUSPENSION_HISTORY_INVALID';
  end if;

  if new.revision = 1 then
    if new.estado <> 'ABIERTA' or new.id <> new.suspension_id
       or new.fecha_hasta is not null or new.version_anterior_id is not null
    then
      raise exception using
        errcode = 'P4314', message = 'EMPLOYEE_SUSPENSION_HISTORY_INVALID';
    end if;
  elsif new.revision = 2 then
    select * into v_anterior
    from public.nomina_suspensiones_laborales suspension
    where suspension.empresa_id = new.empresa_id
      and suspension.id = new.version_anterior_id
    for share;
    if not found
       or v_anterior.id <> new.suspension_id
       or v_anterior.suspension_id <> new.suspension_id
       or v_anterior.empleado_id <> new.empleado_id
       or v_anterior.revision <> 1
       or v_anterior.estado <> 'ABIERTA'
       or v_anterior.fecha_desde <> new.fecha_desde
       or new.estado <> 'FINALIZADA'
       or new.id = new.suspension_id
       or new.fecha_hasta is null
       or new.fecha_hasta < new.fecha_desde
       or exists (
         select 1
         from public.nomina_suspensiones_laborales posterior
         where posterior.empresa_id = new.empresa_id
           and posterior.suspension_id = new.suspension_id
           and posterior.revision > v_anterior.revision
       )
    then
      raise exception using
        errcode = 'P4314', message = 'EMPLOYEE_SUSPENSION_HISTORY_INVALID';
    end if;
  else
    raise exception using
      errcode = 'P4314', message = 'EMPLOYEE_SUSPENSION_HISTORY_INVALID';
  end if;

  if exists (
    select 1
    from public.nomina_suspensiones_laborales actual
    where actual.empresa_id = new.empresa_id
      and actual.empleado_id = new.empleado_id
      and actual.suspension_id <> new.suspension_id
      and not exists (
        select 1
        from public.nomina_suspensiones_laborales posterior
        where posterior.empresa_id = actual.empresa_id
          and posterior.suspension_id = actual.suspension_id
          and posterior.revision > actual.revision
      )
      and actual.periodo && daterange(
        new.fecha_desde, new.fecha_hasta, '[]'
      )
  ) then
    raise exception using
      errcode = 'P4313', message = 'EMPLOYEE_SUSPENSION_OVERLAP';
  end if;

  return new;
end;
$$;

create trigger nomina_suspensiones_laborales_validar
before insert on public.nomina_suspensiones_laborales
for each row execute function private.validar_suspension_laboral_0043();

create or replace function private.puede_gestionar_suspension_laboral_0043(
  p_empleado uuid
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with actor as (
    select * from private.actor_nomina_calendario_0042()
  ), permiso as (
    select *
    from private.permiso_efectivo_nomina_0042(
      'recursos_humanos.acceder'
    )
  )
  select coalesce(exists(
    select 1
    from actor a
    cross join permiso pe
    join public.profiles pr on pr.id = a.perfil_id
    join public.empleados e
      on e.id = p_empleado
     and e.empresa_id = a.empresa_id
    join public.departments d
      on d.id = e.departamento_id
     and d.company_id = e.empresa_id
     and d.branch_id = e.sucursal_id
     and d.is_active is true
    join public.branches b
      on b.id = e.sucursal_id
     and b.company_id = e.empresa_id
     and b.status = 'active'
    where pe.permitido
      and (
        (
          a.rol_codigo = 'SUPERVISOR'
          and pe.alcance in (
            'departamento', 'sucursal', 'empresa', 'global'
          )
          and e.departamento_id in (
            select scope.departamento_id
            from public.obtener_departamentos_supervisor_actual() scope
          )
        )
        or (
          a.rol_codigo <> 'SUPERVISOR'
          and case pe.alcance
            when 'global' then true
            when 'empresa' then true
            when 'sucursal' then (
              e.sucursal_id = pr.branch_id
              or exists (
                select 1
                from public.perfil_sucursales ps
                where ps.perfil_id = pr.id
                  and ps.sucursal_id = e.sucursal_id
              )
            )
            when 'departamento' then (
              e.departamento_id = pr.department_id
              or exists (
                select 1
                from public.perfil_departamentos pd
                where pd.perfil_id = pr.id
                  and pd.departamento_id = e.departamento_id
              )
            )
            when 'propio' then e.perfil_id = pr.id
            else false
          end
        )
      )
  ), false);
$$;

create or replace function private.empleado_suspendido_en_fecha_nomina_0043(
  p_empresa uuid,
  p_empleado uuid,
  p_fecha date
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_estado_laboral text;
  v_empleado_activo boolean;
  v_timezone text;
  v_hoy date;
  v_coincidencias_hoy integer;
  v_coincidencias_fecha integer;
begin
  if p_empresa is null or p_empleado is null or p_fecha is null then
    return false;
  end if;

  select empleado.estado_laboral, empleado.activo, empresa.timezone
  into v_estado_laboral, v_empleado_activo, v_timezone
  from public.empleados empleado
  join public.companies empresa on empresa.id = empleado.empresa_id
  where empleado.empresa_id = p_empresa
    and empleado.id = p_empleado;
  if not found then
    return false;
  end if;
  if v_timezone is null or not exists (
    select 1
    from pg_catalog.pg_timezone_names zona
    where zona.name = v_timezone
  ) then
    raise exception using
      errcode = 'P4304', message = 'COMPANY_TIMEZONE_INVALID';
  end if;
  v_hoy := (statement_timestamp() at time zone v_timezone)::date;

  select count(*)::integer
  into v_coincidencias_hoy
  from public.nomina_suspensiones_laborales actual
  where actual.empresa_id = p_empresa
    and actual.empleado_id = p_empleado
    and actual.periodo @> v_hoy
    and not exists (
      select 1
      from public.nomina_suspensiones_laborales posterior
      where posterior.empresa_id = actual.empresa_id
        and posterior.suspension_id = actual.suspension_id
        and posterior.revision > actual.revision
    );
  if v_coincidencias_hoy > 1 then
    raise exception using
      errcode = 'P4314', message = 'EMPLOYEE_SUSPENSION_HISTORY_INVALID';
  end if;
  if v_estado_laboral = 'suspendido' and (
    coalesce(v_empleado_activo, true) or v_coincidencias_hoy <> 1
  ) then
    raise exception using
      errcode = 'P4311',
      message = 'EMPLOYEE_SUSPENSION_HISTORY_REQUIRED';
  end if;

  select count(*)::integer
  into v_coincidencias_fecha
  from public.nomina_suspensiones_laborales actual
  where actual.empresa_id = p_empresa
    and actual.empleado_id = p_empleado
    and actual.periodo @> p_fecha
    and not exists (
      select 1
      from public.nomina_suspensiones_laborales posterior
      where posterior.empresa_id = actual.empresa_id
        and posterior.suspension_id = actual.suspension_id
        and posterior.revision > actual.revision
    );
  if v_coincidencias_fecha > 1 then
    raise exception using
      errcode = 'P4314', message = 'EMPLOYEE_SUSPENSION_HISTORY_INVALID';
  end if;
  return v_coincidencias_fecha = 1;
end;
$$;

create or replace function private.resolucion_cubierta_por_suspension_0043(
  p_empresa uuid,
  p_empleado uuid,
  p_fecha date
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor record;
begin
  select * into v_actor
  from private.actor_nomina_calendario_0042();
  if not found then
    return false;
  end if;
  if v_actor.empresa_id <> p_empresa or not (
    public.puede_operar_empleado_en_alcance(p_empleado, 'nomina.ver')
    or public.puede_operar_empleado_en_alcance(
      p_empleado, 'nomina.generar'
    )
    or (
      v_actor.rol_codigo <> 'SUPERVISOR'
      and (
        public.tiene_permiso_en_alcance(
          'nomina.ver', array['empresa', 'global']
        )
        or public.tiene_permiso_en_alcance(
          'nomina.generar', array['empresa', 'global']
        )
      )
    )
  ) then
    return false;
  end if;
  return private.empleado_suspendido_en_fecha_nomina_0043(
    p_empresa, p_empleado, p_fecha
  );
end;
$$;

create or replace function private.empleado_vigente_en_fecha_nomina_0043(
  p_empresa uuid,
  p_empleado uuid,
  p_fecha date
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_fecha_ingreso date;
  v_empleado_activo boolean;
  v_estado_laboral text;
  v_activo boolean;
  v_ultimo_activo boolean;
  v_tiene_eventos boolean;
  v_historial_invalido boolean;
begin
  if p_empresa is null or p_empleado is null or p_fecha is null then
    return false;
  end if;

  select empleado.fecha_ingreso, empleado.activo, empleado.estado_laboral
  into v_fecha_ingreso, v_empleado_activo, v_estado_laboral
  from public.empleados empleado
  where empleado.empresa_id = p_empresa
    and empleado.id = p_empleado;
  if not found or v_fecha_ingreso is null or p_fecha < v_fecha_ingreso then
    return false;
  end if;

  with eventos as (
    select
      ciclo.id,
      ciclo.evento,
      ciclo.fecha_efectiva,
      ciclo.evento_relacionado_id,
      pg_catalog.lag(ciclo.id) over (order by ciclo.id) as anterior_id,
      pg_catalog.lag(ciclo.evento) over (order by ciclo.id) as anterior_evento,
      pg_catalog.lag(ciclo.fecha_efectiva)
        over (order by ciclo.id) as anterior_fecha
    from public.empleado_ciclo_laboral_auditoria ciclo
    where ciclo.empresa_id = p_empresa
      and ciclo.empleado_id = p_empleado
  )
  select exists (
    select 1
    from eventos evento
    where evento.fecha_efectiva < v_fecha_ingreso
      or (
        evento.anterior_id is null
        and evento.evento <> 'EMPLOYEE_TERMINATED'
      )
      or (
        evento.anterior_id is not null
        and (
          evento.fecha_efectiva < evento.anterior_fecha
          or evento.evento = evento.anterior_evento
          or (
            evento.evento = 'EMPLOYEE_REACTIVATED'
            and evento.evento_relacionado_id <> evento.anterior_id
          )
        )
      )
  )
  into v_historial_invalido;
  if v_historial_invalido then
    raise exception using
      errcode = 'P4310',
      message = 'EMPLOYEE_LIFECYCLE_HISTORY_INVALID';
  end if;

  select exists (
    select 1
    from public.empleado_ciclo_laboral_auditoria ciclo
    where ciclo.empresa_id = p_empresa
      and ciclo.empleado_id = p_empleado
  ) into v_tiene_eventos;
  if not v_tiene_eventos then
    if v_estado_laboral = 'desvinculado' then
      raise exception using
        errcode = 'P4310',
        message = 'EMPLOYEE_LIFECYCLE_HISTORY_INVALID';
    end if;
    return true;
  end if;

  select ciclo.activo_nuevo
  into v_ultimo_activo
  from public.empleado_ciclo_laboral_auditoria ciclo
  where ciclo.empresa_id = p_empresa
    and ciclo.empleado_id = p_empleado
  order by ciclo.id desc
  limit 1;
  if (
       not v_ultimo_activo
       and (v_estado_laboral <> 'desvinculado' or v_empleado_activo)
     )
     or (v_ultimo_activo and v_estado_laboral = 'desvinculado')
  then
    raise exception using
      errcode = 'P4310',
      message = 'EMPLOYEE_LIFECYCLE_HISTORY_INVALID';
  end if;

  select ciclo.activo_nuevo
  into v_activo
  from public.empleado_ciclo_laboral_auditoria ciclo
  where ciclo.empresa_id = p_empresa
    and ciclo.empleado_id = p_empleado
    and ciclo.fecha_efectiva <= p_fecha
  order by ciclo.fecha_efectiva desc, ciclo.id desc
  limit 1;
  return coalesce(v_activo, true);
end;
$$;

create or replace function private.rango_suspension_dentro_ciclo_laboral_0043(
  p_empresa uuid,
  p_empleado uuid,
  p_fecha_desde date,
  p_fecha_hasta date
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if p_empresa is null or p_empleado is null or p_fecha_desde is null
     or (p_fecha_hasta is not null and p_fecha_hasta < p_fecha_desde)
  then
    return false;
  end if;
  if not private.empleado_vigente_en_fecha_nomina_0043(
    p_empresa, p_empleado, p_fecha_desde
  ) then
    return false;
  end if;

  if p_fecha_hasta is null then
    return not exists (
      select 1
      from public.empleado_ciclo_laboral_auditoria ciclo
      where ciclo.empresa_id = p_empresa
        and ciclo.empleado_id = p_empleado
        and ciclo.fecha_efectiva > p_fecha_desde
    );
  end if;
  if not private.empleado_vigente_en_fecha_nomina_0043(
    p_empresa, p_empleado, p_fecha_hasta
  ) then
    return false;
  end if;
  return not exists (
    select 1
    from public.empleado_ciclo_laboral_auditoria ciclo
    where ciclo.empresa_id = p_empresa
      and ciclo.empleado_id = p_empleado
      and ciclo.fecha_efectiva > p_fecha_desde
      and ciclo.fecha_efectiva <= p_fecha_hasta
  );
end;
$$;

create or replace function private.bloquear_desvinculacion_suspension_0043()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.estado_laboral = 'desvinculado'
     and old.estado_laboral is distinct from new.estado_laboral
     and exists (
       select 1
       from public.nomina_suspensiones_laborales actual
       where actual.empresa_id = old.empresa_id
         and actual.empleado_id = old.id
         and not exists (
           select 1
           from public.nomina_suspensiones_laborales posterior
           where posterior.empresa_id = actual.empresa_id
             and posterior.suspension_id = actual.suspension_id
             and posterior.revision > actual.revision
         )
         and (
           new.fecha_desvinculacion is null
           or actual.fecha_hasta is null
           or actual.fecha_hasta >= new.fecha_desvinculacion
         )
     )
  then
    raise exception using
      errcode = 'P4315',
      message = 'EMPLOYEE_OPEN_SUSPENSION_MUST_BE_CLOSED';
  end if;
  return new;
end;
$$;

create trigger empleados_bloquear_desvinculacion_suspension_0043
before update of estado_laboral on public.empleados
for each row execute function private.bloquear_desvinculacion_suspension_0043();

create or replace function public.es_supervisor_nomina_0043()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select actor.rol_codigo = 'SUPERVISOR'
      from private.actor_nomina_calendario_0042() actor
      limit 1
    ),
    false
  );
$$;

create or replace function private.base_nominal_dia_0043(
  p_sueldo_mensual numeric,
  p_fecha date
) returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_dia integer := extract(day from p_fecha)::integer;
  v_indice integer;
  v_quincena numeric := p_sueldo_mensual / 2;
begin
  if p_sueldo_mensual is null or p_sueldo_mensual <= 0 or p_fecha is null then
    raise exception using errcode = 'P4308', message = 'DAILY_INPUT_INVALID';
  end if;
  if v_dia > 30 then
    return 0::numeric;
  end if;
  v_indice := case when v_dia <= 15 then v_dia else v_dia - 15 end;
  return round(v_quincena * v_indice / 15, 2)
    - round(v_quincena * (v_indice - 1) / 15, 2);
end;
$$;

create or replace function private.complemento_convencion_30_0043(
  p_sueldo_mensual numeric,
  p_fecha date
) returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_ultimo date;
  v_dias_segunda integer;
  v_quincena numeric := p_sueldo_mensual / 2;
begin
  if p_sueldo_mensual is null or p_sueldo_mensual <= 0 or p_fecha is null then
    raise exception using errcode = 'P4308', message = 'DAILY_INPUT_INVALID';
  end if;
  v_ultimo := (
    date_trunc('month', p_fecha::timestamp)
    + interval '1 month' - interval '1 day'
  )::date;
  if extract(month from p_fecha)::integer <> 2 or p_fecha <> v_ultimo then
    return 0::numeric;
  end if;
  v_dias_segunda := extract(day from v_ultimo)::integer - 15;
  return greatest(
    round(v_quincena, 2)
      - round(v_quincena * v_dias_segunda / 15, 2),
    0
  );
end;
$$;

create or replace function private.calcular_objetivos_nomina_dia_0043(
  p_fecha date,
  p_sueldo_mensual numeric,
  p_valor_hora_extra numeric,
  p_minutos_programados integer,
  p_minutos_trabajados integer,
  p_tiene_jornada boolean,
  p_cobertura_tipo text,
  p_cobertura_porcentaje numeric,
  p_es_festivo boolean,
  p_es_dia_libre_manual boolean
) returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_base numeric;
  v_dia numeric;
  v_quincena numeric;
  v_referencia numeric;
  v_referencia_minutos integer;
  v_normales integer := 0;
  v_extra_minutos integer := 0;
  v_reconocido numeric := 0;
  v_reconocido_sin_redondear numeric := 0;
  v_extra numeric := 0;
  v_premium numeric := 0;
  v_ajuste numeric;

  v_fuente text;
  v_libre_automatico boolean := p_minutos_programados = 0;
  v_libre boolean := v_libre_automatico or p_es_dia_libre_manual;
begin
  if p_fecha is null
     or p_sueldo_mensual is null or p_sueldo_mensual <= 0
     or p_valor_hora_extra is null or p_valor_hora_extra < 0
     or p_minutos_programados is null
     or p_minutos_programados < 0 or p_minutos_programados > 1440
     or p_minutos_trabajados is null or p_minutos_trabajados < 0
     or p_tiene_jornada is null
     or p_es_festivo is null
     or p_es_dia_libre_manual is null
     or (
       not p_tiene_jornada
       and p_minutos_trabajados <> 0
     )
     or (
       p_cobertura_tipo is null
       and p_cobertura_porcentaje is not null
     )
     or (
       p_cobertura_tipo = 'LICENCIA'
       and (
         p_cobertura_porcentaje is null
         or p_cobertura_porcentaje < 0
         or p_cobertura_porcentaje > 100
       )
     )
     or (
       p_cobertura_tipo = 'VACACIONES'
       and (
         p_cobertura_porcentaje is null
         or p_cobertura_porcentaje <> 100
       )
     )
     or p_cobertura_tipo not in ('LICENCIA', 'VACACIONES')
  then
    raise exception using errcode = 'P4308', message = 'DAILY_INPUT_INVALID';
  end if;

  v_dia := p_sueldo_mensual / 30;
  v_quincena := p_sueldo_mensual / 2;
  v_base := private.base_nominal_dia_0043(p_sueldo_mensual, p_fecha);
  v_referencia := case
    when extract(day from p_fecha)::integer <= 30 then v_base
    else v_dia
  end;

  if p_tiene_jornada then
    v_referencia_minutos := case
      when v_libre then 480
      else p_minutos_programados
    end;
    if v_referencia_minutos <= 0 then
      raise exception using errcode = 'P4308', message = 'DAILY_REFERENCE_INVALID';
    end if;
    v_normales := least(p_minutos_trabajados, v_referencia_minutos);
    v_extra_minutos := greatest(
      p_minutos_trabajados - v_referencia_minutos,
      0
    );
    v_reconocido_sin_redondear :=
      v_referencia * v_normales / v_referencia_minutos;
    v_reconocido := round(v_reconocido_sin_redondear, 2);
    v_extra := round(
      v_extra_minutos::numeric / 60 * p_valor_hora_extra,
      2
    );
    v_premium := case when p_es_festivo then v_reconocido else 0 end;
    v_fuente := 'JORNADA';
  elsif p_cobertura_tipo = 'VACACIONES' then
    v_reconocido_sin_redondear := v_referencia;
    v_reconocido := round(v_reconocido_sin_redondear, 2);
    v_fuente := 'VACACIONES';
  elsif p_cobertura_tipo = 'LICENCIA' then
    v_reconocido_sin_redondear :=
      v_referencia * p_cobertura_porcentaje / 100;
    v_reconocido := round(v_reconocido_sin_redondear, 2);
    v_fuente := 'LICENCIA';
  elsif p_es_festivo then
    v_reconocido_sin_redondear := v_referencia;
    v_reconocido := round(v_reconocido_sin_redondear, 2);
    v_fuente := 'FESTIVO';
  elsif p_es_dia_libre_manual then
    v_reconocido_sin_redondear := v_referencia;
    v_reconocido := round(v_reconocido_sin_redondear, 2);
    v_fuente := 'DIA_LIBRE_MANUAL';
  elsif v_libre_automatico then
    v_reconocido_sin_redondear := v_referencia;
    v_reconocido := round(v_reconocido_sin_redondear, 2);
    v_fuente := 'DIA_LIBRE_AUTOMATICO';
  else
    v_reconocido_sin_redondear := 0;
    v_reconocido := 0;
    v_fuente := 'AUSENCIA';
  end if;

  v_ajuste := case
    when extract(day from p_fecha)::integer <= 30
      then round(v_reconocido - v_referencia, 2)
    else round(v_reconocido_sin_redondear - v_referencia, 2)
  end;

  return jsonb_build_object(
    'fuente_economica', v_fuente,
    'valor_dia', round(v_dia, 6),
    'valor_quincena', round(v_quincena, 6),
    'monto_normal_reconocido', v_reconocido,
    'minutos_normales_reconocidos', v_normales,
    'minutos_extra', v_extra_minutos,
    'es_dia_libre_automatico', v_libre_automatico,
    'es_dia_libre_manual', p_es_dia_libre_manual,
    'es_ausencia', v_fuente = 'AUSENCIA',
    'objetivos', jsonb_build_object(
      'SALARY_DAY_BASE', round(v_base, 2),
      'SALARY_DAY_ADJUSTMENT', round(v_ajuste, 2),
      'SALARY_DAY_OVERTIME', round(v_extra, 2),
      'HOLIDAY_NORMAL_PREMIUM', round(v_premium, 2),
      'SALARY_30DAY_COMPLEMENT', 0::numeric
    )
  );
end;
$$;

create or replace function private.resolver_nomina_dia_0043(
  p_empresa uuid,
  p_empleado uuid,
  p_fecha date,
  p_actor uuid,
  p_motivo text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_empresa public.companies%rowtype;
  v_empleado public.empleados%rowtype;
  v_jornada public.jornadas%rowtype;
  v_asignacion public.nomina_asignaciones_horario%rowtype;
  v_version public.nomina_plantilla_horario_versiones%rowtype;
  v_dia public.nomina_plantilla_horario_dias%rowtype;
  v_condicion public.nomina_condiciones_salariales%rowtype;
  v_libre_id uuid;
  v_libre_revision bigint;
  v_libre_detalle_id uuid;
  v_libre_detalle_iso smallint;
  v_cobertura public.nomina_coberturas%rowtype;
  v_festivo public.nomina_festivos%rowtype;
  v_ciclo public.empleado_ciclo_laboral_auditoria%rowtype;
  v_actual public.nomina_resoluciones_diarias%rowtype;
  v_nueva public.nomina_resoluciones_diarias%rowtype;
  v_hoy date;
  v_iso smallint;
  v_tiene_jornada boolean := false;
  v_tiene_jornada_fisica boolean := false;
  v_libre_manual boolean := false;
  v_es_festivo boolean := false;
  v_calc jsonb;
  v_fuentes jsonb;
  v_snapshot jsonb;
  v_hash text;
  v_revision bigint;
  v_motivo text := btrim(coalesce(p_motivo, ''));
begin
  if p_empresa is null or p_empleado is null or p_fecha is null
     or char_length(v_motivo) not between 3 and 500
  then
    raise exception using errcode = 'P4308', message = 'DAILY_REQUEST_INVALID';
  end if;

  select * into v_empresa
  from public.companies empresa
  where empresa.id = p_empresa
    and empresa.status = 'active';
  if not found then
    raise exception using errcode = 'P4309', message = 'TENANT_NOT_AVAILABLE';
  end if;
  if not exists (
    select 1
    from pg_catalog.pg_timezone_names zona
    where zona.name = v_empresa.timezone
  ) then
    raise exception using errcode = 'P4304', message = 'COMPANY_TIMEZONE_INVALID';
  end if;
  v_hoy := (clock_timestamp() at time zone v_empresa.timezone)::date;
  v_iso := extract(isodow from p_fecha)::smallint;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_empresa::text || ':' || p_empleado::text || ':' || p_fecha::text,
      4300
    )
  );

  select * into v_jornada
  from public.jornadas jornada
  where jornada.empresa_id = p_empresa
    and jornada.empleado_id = p_empleado
    and jornada.fecha_laboral = p_fecha
  for share;
  v_tiene_jornada_fisica := found;

  select * into v_empleado
  from public.empleados empleado
  where empleado.empresa_id = p_empresa
    and empleado.id = p_empleado
  for share;
  if not found then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;

  if p_actor is not null then
    select * into v_actor
    from private.actor_nomina_calendario_0042() actor
    where actor.perfil_id = p_actor
      and actor.empresa_id = p_empresa;
    if not found or not (
      public.puede_operar_empleado_en_alcance(
        p_empleado, 'nomina.generar'
      )
      or (
        v_actor.rol_codigo <> 'SUPERVISOR'
        and public.tiene_permiso_en_alcance(
          'nomina.generar', array['empresa', 'global']
        )
      )
    ) then
      raise exception using
        errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
    end if;
  end if;

  if v_empleado.fecha_ingreso is null then
    raise exception using errcode = 'P4305', message = 'EMPLOYEE_START_DATE_REQUIRED';
  end if;
  if p_fecha < v_empleado.fecha_ingreso then
    raise exception using errcode = 'P4301', message = 'DATE_BEFORE_EMPLOYMENT';
  end if;
  if not private.empleado_vigente_en_fecha_nomina_0043(
    p_empresa, p_empleado, p_fecha
  ) then
    raise exception using errcode = 'P4306', message = 'EMPLOYEE_NOT_ACTIVE_ON_DATE';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_empresa::text || ':SUSPENSION:' || p_empleado::text,
      4300
    )
  );
  if private.empleado_suspendido_en_fecha_nomina_0043(
    p_empresa, p_empleado, p_fecha
  ) then
    raise exception using
      errcode = 'P4312', message = 'EMPLOYEE_SUSPENDED_ON_DATE';
  end if;

  select * into v_ciclo
  from public.empleado_ciclo_laboral_auditoria ciclo
  where ciclo.empresa_id = p_empresa
    and ciclo.empleado_id = p_empleado
    and ciclo.fecha_efectiva <= p_fecha
  order by ciclo.fecha_efectiva desc, ciclo.id desc
  limit 1;

  if v_tiene_jornada_fisica then
    if v_jornada.estado = 'SIN_INICIAR' then
      v_tiene_jornada := false;
    elsif v_jornada.estado <> 'FINALIZADA'
       or v_jornada.revision_pendiente
       or exists (
         select 1
         from public.jornada_conflictos conflicto
         where conflicto.empresa_id = v_jornada.empresa_id
           and conflicto.jornada_id = v_jornada.id
           and conflicto.estado = 'PENDIENTE'
       )
    then
      raise exception using errcode = 'P4307', message = 'JOURNEY_NOT_ELIGIBLE';
    else
      v_tiene_jornada := true;
    end if;
  end if;

  if not v_tiene_jornada and p_fecha >= v_hoy then
    raise exception using errcode = 'P4302', message = 'DATE_NOT_EXPIRED';
  end if;

  select * into v_asignacion
  from public.nomina_asignaciones_horario asignacion
  where asignacion.empresa_id = p_empresa
    and asignacion.empleado_id = p_empleado
    and asignacion.periodo @> p_fecha
  order by asignacion.vigente_desde desc, asignacion.id
  limit 1
  for share;
  if not found then
    raise exception using errcode = 'P4303', message = 'SCHEDULE_ASSIGNMENT_MISSING';
  end if;

  select * into v_version
  from public.nomina_plantilla_horario_versiones version
  where version.empresa_id = p_empresa
    and version.id = v_asignacion.plantilla_version_id
  for share;
  if not found then
    raise exception using errcode = 'P4303', message = 'SCHEDULE_VERSION_MISSING';
  end if;

  select * into v_dia
  from public.nomina_plantilla_horario_dias dia
  where dia.empresa_id = p_empresa
    and dia.plantilla_version_id = v_version.id
    and dia.iso_dia = v_iso
  for share;
  if not found then
    raise exception using errcode = 'P4303', message = 'SCHEDULE_DAY_MISSING';
  end if;

  select * into v_condicion
  from public.nomina_condiciones_salariales condicion
  where condicion.empresa_id = p_empresa
    and condicion.empleado_id = p_empleado
    and condicion.periodo @> p_fecha
  order by condicion.vigente_desde desc, condicion.id
  limit 1
  for share;
  if not found then
    raise exception using errcode = 'P4303', message = 'SALARY_CONDITION_MISSING';
  end if;

  select
    libre.id,
    libre.revision,
    detalle.id,
    detalle.iso_dia
  into v_libre_id, v_libre_revision, v_libre_detalle_id, v_libre_detalle_iso
  from public.nomina_dias_libres libre
  join public.nomina_dia_libre_dias detalle
    on detalle.empresa_id = libre.empresa_id
   and detalle.configuracion_id = libre.id
   and detalle.empleado_id = libre.empleado_id
  where libre.empresa_id = p_empresa
    and libre.empleado_id = p_empleado
    and libre.periodo @> p_fecha
    and detalle.iso_dia = v_iso
  order by libre.vigente_desde desc, libre.id
  limit 1
  for share of libre, detalle;
  v_libre_manual := found;

  select * into v_cobertura
  from public.nomina_coberturas cobertura
  where cobertura.empresa_id = p_empresa
    and cobertura.empleado_id = p_empleado
    and cobertura.estado = 'APROBADA'
    and cobertura.periodo @> p_fecha
  order by cobertura.fecha_desde desc, cobertura.id
  limit 1
  for share;

  select * into v_festivo
  from public.nomina_festivos festivo
  where festivo.empresa_id = p_empresa
    and festivo.fecha = p_fecha
    and festivo.activo
  limit 1
  for share;
  v_es_festivo := found;

  v_calc := private.calcular_objetivos_nomina_dia_0043(
    p_fecha,
    v_condicion.sueldo_mensual,
    v_condicion.valor_hora_extra,
    v_dia.minutos_normales,
    case when v_tiene_jornada then v_jornada.minutos_trabajados else 0 end,
    v_tiene_jornada,
    v_cobertura.tipo,
    v_cobertura.porcentaje,
    v_es_festivo,
    v_libre_manual
  );

  v_fuentes := jsonb_build_object(
    'empleo', jsonb_build_object(
      'fecha_ingreso', v_empleado.fecha_ingreso,
      'ciclo_evento_id', v_ciclo.id,
      'ciclo_evento', v_ciclo.evento,
      'ciclo_fecha_efectiva', v_ciclo.fecha_efectiva
    ),
    'horario', jsonb_build_object(
      'asignacion_id', v_asignacion.id,
      'asignacion_revision', v_asignacion.revision,
      'plantilla_version_id', v_version.id,
      'plantilla_revision', v_version.revision,
      'plantilla_dia_id', v_dia.id,
      'iso_dia', v_dia.iso_dia,
      'minutos_normales', v_dia.minutos_normales
    ),
    'condicion_salarial', jsonb_build_object(
      'id', v_condicion.id,
      'revision', v_condicion.revision,
      'sueldo_mensual', v_condicion.sueldo_mensual,
      'valor_hora_extra', v_condicion.valor_hora_extra
    ),
    'jornada', case when v_tiene_jornada then jsonb_build_object(
      'id', v_jornada.id,
      'estado', v_jornada.estado,
      'version_sync', v_jornada.version_sync,
      'revision_nomina', v_jornada.revision_nomina,
      'minutos_trabajados', v_jornada.minutos_trabajados,
      'minutos_pausa', v_jornada.minutos_pausa
    ) else null end,
    'dia_libre_manual', case when v_libre_manual then jsonb_build_object(
      'id', v_libre_id,
      'revision', v_libre_revision,
      'detalle_id', v_libre_detalle_id,
      'iso_dia', v_libre_detalle_iso
    ) else null end,
    'cobertura', case when v_cobertura.id is not null then jsonb_build_object(
      'id', v_cobertura.id,
      'revision', v_cobertura.revision,
      'tipo', v_cobertura.tipo,
      'porcentaje', v_cobertura.porcentaje,
      'estado', v_cobertura.estado
    ) else null end,
    'festivo', case when v_es_festivo then jsonb_build_object(
      'id', v_festivo.id,
      'revision', v_festivo.revision,
      'activo', v_festivo.activo
    ) else null end
  );

  v_snapshot := jsonb_build_object(
    'formula', 'DAILY_FIXED_SALARY_V1',
    'empresa_id', p_empresa,
    'empleado_id', p_empleado,
    'fecha_local', p_fecha,
    'timezone', v_empresa.timezone,
    'fuentes', v_fuentes,
    'calculo', v_calc
  );
  v_hash := encode(
    extensions.digest(
      pg_catalog.convert_to(v_snapshot::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );

  select * into v_actual
  from public.nomina_resoluciones_diarias resolucion
  where resolucion.empresa_id = p_empresa
    and resolucion.empleado_id = p_empleado
    and resolucion.fecha_local = p_fecha
  order by resolucion.revision desc
  limit 1;
  if found and v_actual.input_hash = v_hash then
    return jsonb_build_object(
      'id', v_actual.id,
      'revision', v_actual.revision,
      'inserted', false,
      'input_hash', v_actual.input_hash
    );
  end if;
  v_revision := coalesce(v_actual.revision, 0) + 1;

  insert into public.nomina_resoluciones_diarias(
    empresa_id, empleado_id, fecha_local, revision, estado, formula,
    fuente_economica, timezone, iso_dia,
    minutos_programados, minutos_trabajados,
    minutos_normales_reconocidos, minutos_extra,
    sueldo_mensual, valor_dia, valor_quincena, valor_hora_extra,
    monto_normal_reconocido,
    cobertura_tipo, cobertura_porcentaje,
    es_festivo, es_dia_libre_automatico, es_dia_libre_manual, es_ausencia,
    jornada_id, asignacion_horario_id, plantilla_version_id,
    plantilla_dia_id, condicion_salarial_id,
    dia_libre_id, dia_libre_detalle_id, cobertura_id, festivo_id,
    objetivo_base_nominal, objetivo_ajuste_diario,
    objetivo_hora_extra, objetivo_premium_festivo,
    objetivo_complemento_30_dias,
    snapshot, input_hash, motivo, actor_id
  ) values (
    p_empresa, p_empleado, p_fecha, v_revision, 'RESUELTA',
    'DAILY_FIXED_SALARY_V1',
    v_calc ->> 'fuente_economica', v_empresa.timezone, v_iso,
    v_dia.minutos_normales,
    case when v_tiene_jornada then v_jornada.minutos_trabajados else 0 end,
    (v_calc ->> 'minutos_normales_reconocidos')::integer,
    (v_calc ->> 'minutos_extra')::integer,
    v_condicion.sueldo_mensual,
    (v_calc ->> 'valor_dia')::numeric,
    (v_calc ->> 'valor_quincena')::numeric,
    v_condicion.valor_hora_extra,
    (v_calc ->> 'monto_normal_reconocido')::numeric,
    v_cobertura.tipo, v_cobertura.porcentaje,
    v_es_festivo,
    (v_calc ->> 'es_dia_libre_automatico')::boolean,
    v_libre_manual,
    (v_calc ->> 'es_ausencia')::boolean,
    case when v_tiene_jornada then v_jornada.id else null end,
    v_asignacion.id, v_version.id, v_dia.id, v_condicion.id,
    case when v_libre_manual then v_libre_id else null end,
    case when v_libre_manual then v_libre_detalle_id else null end,
    v_cobertura.id,
    case when v_es_festivo then v_festivo.id else null end,
    (v_calc -> 'objetivos' ->> 'SALARY_DAY_BASE')::numeric,
    (v_calc -> 'objetivos' ->> 'SALARY_DAY_ADJUSTMENT')::numeric,
    (v_calc -> 'objetivos' ->> 'SALARY_DAY_OVERTIME')::numeric,
    (v_calc -> 'objetivos' ->> 'HOLIDAY_NORMAL_PREMIUM')::numeric,
    (v_calc -> 'objetivos' ->> 'SALARY_30DAY_COMPLEMENT')::numeric,
    v_snapshot, v_hash, v_motivo, p_actor
  )
  returning * into v_nueva;

  return jsonb_build_object(
    'id', v_nueva.id,
    'revision', v_nueva.revision,
    'inserted', true,
    'input_hash', v_nueva.input_hash
  );
end;
$$;

create or replace function private.resolver_complemento_convencion_30_0043(
  p_empresa uuid,
  p_empleado uuid,
  p_anio integer,
  p_actor uuid,
  p_motivo text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_empresa public.companies%rowtype;
  v_empleado public.empleados%rowtype;
  v_condicion public.nomina_condiciones_salariales%rowtype;
  v_actual public.nomina_complementos_convencion_30%rowtype;
  v_nueva public.nomina_complementos_convencion_30%rowtype;
  v_fin_febrero date;
  v_ancla date;
  v_monto numeric;
  v_snapshot jsonb;
  v_hash text;
  v_revision bigint;
  v_motivo text := btrim(coalesce(p_motivo, ''));
begin
  if p_empresa is null or p_empleado is null
     or p_anio is null or p_anio not between 1900 and 9999
     or char_length(v_motivo) not between 3 and 500
  then
    raise exception using
      errcode = 'P4308', message = 'FEBRUARY_COMPLEMENT_REQUEST_INVALID';
  end if;
  v_fin_febrero := make_date(p_anio, 3, 1) - 1;

  select * into v_empresa
  from public.companies empresa
  where empresa.id = p_empresa
    and empresa.status = 'active';
  if not found then
    raise exception using errcode = 'P4309', message = 'TENANT_NOT_AVAILABLE';
  end if;
  if not exists (
    select 1
    from pg_catalog.pg_timezone_names zona
    where zona.name = v_empresa.timezone
  ) then
    raise exception using errcode = 'P4304', message = 'COMPANY_TIMEZONE_INVALID';
  end if;

  select * into v_empleado
  from public.empleados empleado
  where empleado.empresa_id = p_empresa
    and empleado.id = p_empleado
  for share;
  if not found then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;

  if p_actor is not null then
    select * into v_actor
    from private.actor_nomina_calendario_0042() actor
    where actor.perfil_id = p_actor
      and actor.empresa_id = p_empresa;
    if not found or not (
      public.puede_operar_empleado_en_alcance(
        p_empleado, 'nomina.generar'
      )
      or (
        v_actor.rol_codigo <> 'SUPERVISOR'
        and public.tiene_permiso_en_alcance(
          'nomina.generar', array['empresa', 'global']
        )
      )
    ) then
      raise exception using
        errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
    end if;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_empresa::text || ':SUSPENSION:' || p_empleado::text,
      4300
    )
  );
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_empresa::text || ':COMP30:' || p_empleado::text || ':' || p_anio::text,
      4300
    )
  );

  if v_empleado.fecha_ingreso is null then
    raise exception using errcode = 'P4305', message = 'EMPLOYEE_START_DATE_REQUIRED';
  end if;
  if not private.empleado_vigente_en_fecha_nomina_0043(
    p_empresa, p_empleado, v_fin_febrero
  ) then
    raise exception using errcode = 'P4306', message = 'EMPLOYEE_NOT_ACTIVE_ON_DATE';
  end if;

  select max(make_date(p_anio, 2, dia.numero))
  into v_ancla
  from generate_series(
    16, extract(day from v_fin_febrero)::integer
  ) dia(numero)
  where private.empleado_vigente_en_fecha_nomina_0043(
      p_empresa, p_empleado, make_date(p_anio, 2, dia.numero)
    )
    and not private.empleado_suspendido_en_fecha_nomina_0043(
      p_empresa, p_empleado, make_date(p_anio, 2, dia.numero)
    );
  if v_ancla is null then
    raise exception using
      errcode = 'P4316',
      message = 'FEBRUARY_COMPLEMENT_ANCHOR_MISSING';
  end if;

  select * into v_condicion
  from public.nomina_condiciones_salariales condicion
  where condicion.empresa_id = p_empresa
    and condicion.empleado_id = p_empleado
    and condicion.periodo @> v_ancla
  order by condicion.vigente_desde desc, condicion.id
  limit 1
  for share;
  if not found then
    raise exception using errcode = 'P4303', message = 'SALARY_CONDITION_MISSING';
  end if;

  v_monto := private.complemento_convencion_30_0043(
    v_condicion.sueldo_mensual,
    v_fin_febrero
  );
  v_snapshot := jsonb_build_object(
    'formula', 'FEBRUARY_30DAY_COMPLEMENT_V1',
    'empresa_id', p_empresa,
    'empleado_id', p_empleado,
    'anio', p_anio,
    'fecha_fin_febrero', v_fin_febrero,
    'fecha_ancla', v_ancla,
    'timezone', v_empresa.timezone,
    'fuentes', jsonb_build_object(
      'empleo', jsonb_build_object(
        'vigente_fin_febrero', true,
        'fecha_ingreso', v_empleado.fecha_ingreso
      ),
      'condicion_salarial', jsonb_build_object(
        'id', v_condicion.id,
        'revision', v_condicion.revision,
        'sueldo_mensual', v_condicion.sueldo_mensual
      )
    ),
    'calculo', jsonb_build_object(
      'valor_dia', round(v_condicion.sueldo_mensual / 30, 6),
      'SALARY_30DAY_COMPLEMENT', round(v_monto, 2)
    )
  );
  v_hash := encode(
    extensions.digest(
      pg_catalog.convert_to(v_snapshot::text, 'UTF8'),
      'sha256'
    ),
    'hex'
  );

  select * into v_actual
  from public.nomina_complementos_convencion_30 complemento
  where complemento.empresa_id = p_empresa
    and complemento.empleado_id = p_empleado
    and complemento.anio = p_anio
  order by complemento.revision desc
  limit 1;
  if found and v_actual.input_hash = v_hash then
    return jsonb_build_object(
      'id', v_actual.id,
      'revision', v_actual.revision,
      'inserted', false,
      'input_hash', v_actual.input_hash,
      'fecha_fin_febrero', v_actual.fecha_fin_febrero,
      'fecha_ancla', v_actual.fecha_ancla,
      'objetivo_complemento_30_dias',
        v_actual.objetivo_complemento_30_dias
    );
  end if;
  v_revision := coalesce(v_actual.revision, 0) + 1;

  insert into public.nomina_complementos_convencion_30(
    empresa_id, empleado_id, anio, fecha_fin_febrero, fecha_ancla,
    revision, estado, formula, timezone, sueldo_mensual, valor_dia,
    condicion_salarial_id, objetivo_complemento_30_dias,
    snapshot, input_hash, motivo, actor_id
  ) values (
    p_empresa, p_empleado, p_anio, v_fin_febrero, v_ancla,
    v_revision, 'RESUELTO', 'FEBRUARY_30DAY_COMPLEMENT_V1',
    v_empresa.timezone, v_condicion.sueldo_mensual,
    round(v_condicion.sueldo_mensual / 30, 6),
    v_condicion.id, round(v_monto, 2),
    v_snapshot, v_hash, v_motivo, p_actor
  )
  returning * into v_nueva;

  return jsonb_build_object(
    'id', v_nueva.id,
    'revision', v_nueva.revision,
    'inserted', true,
    'input_hash', v_nueva.input_hash,
    'fecha_fin_febrero', v_nueva.fecha_fin_febrero,
    'fecha_ancla', v_nueva.fecha_ancla,
    'objetivo_complemento_30_dias',
      v_nueva.objetivo_complemento_30_dias
  );
end;
$$;

create or replace function private.complemento_convencion_30_vigente_0043(
  p_empresa uuid,
  p_empleado uuid,
  p_anio integer,
  p_fecha_fin_febrero date,
  p_fecha_ancla date
) returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_ancla_actual date;
begin
  select * into v_actor
  from private.actor_nomina_calendario_0042();
  if not found
     or p_empresa is null or p_empleado is null
     or p_anio is null or p_anio not between 1900 and 9999
     or p_fecha_fin_febrero is null or p_fecha_ancla is null
     or v_actor.empresa_id <> p_empresa
     or not (
       public.puede_operar_empleado_en_alcance(
         p_empleado, 'nomina.ver'
       )
       or public.puede_operar_empleado_en_alcance(
         p_empleado, 'nomina.generar'
       )
       or (
         v_actor.rol_codigo <> 'SUPERVISOR'
         and (
           public.tiene_permiso_en_alcance(
             'nomina.ver', array['empresa', 'global']
           )
           or public.tiene_permiso_en_alcance(
             'nomina.generar', array['empresa', 'global']
           )
         )
       )
     )
  then
    return false;
  end if;
  if p_fecha_fin_febrero <> make_date(p_anio, 3, 1) - 1
     or not private.empleado_vigente_en_fecha_nomina_0043(
       p_empresa, p_empleado, p_fecha_fin_febrero
     )
  then
    return false;
  end if;

  select max(make_date(p_anio, 2, dia.numero))
  into v_ancla_actual
  from generate_series(
    16, extract(day from p_fecha_fin_febrero)::integer
  ) dia(numero)
  where private.empleado_vigente_en_fecha_nomina_0043(
      p_empresa, p_empleado, make_date(p_anio, 2, dia.numero)
    )
    and not private.empleado_suspendido_en_fecha_nomina_0043(
      p_empresa, p_empleado, make_date(p_anio, 2, dia.numero)
    );
  return coalesce(v_ancla_actual = p_fecha_ancla, false);
exception
  when others then
    return false;
end;
$$;

create or replace function private.cerrar_nomina_dia_empresa_0043(
  p_empresa uuid,
  p_fecha date,
  p_actor uuid,
  p_motivo text,
  p_origen text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa public.companies%rowtype;
  v_empleado record;
  v_resultado jsonb;
  v_detalle jsonb := '[]'::jsonb;
  v_complemento_empleado record;
  v_complemento_resultado jsonb;
  v_complemento_detalle jsonb := '[]'::jsonb;
  v_complemento_errores integer := 0;
  v_objetivo integer := 0;
  v_nuevas integer := 0;
  v_reutilizadas integer := 0;
  v_errores integer := 0;
  v_cierre public.nomina_cierres_diarios%rowtype;
  v_hoy date;
  v_motivo text := btrim(coalesce(p_motivo, ''));
  v_origen text := upper(btrim(coalesce(p_origen, '')));
  v_intento bigint;
begin
  if p_empresa is null or p_fecha is null
     or char_length(v_motivo) not between 3 and 500
     or v_origen not in ('MANUAL', 'AUTOMATICO')
     or (v_origen = 'MANUAL' and p_actor is null)
     or (v_origen = 'AUTOMATICO' and p_actor is not null)
  then
    raise exception using errcode = 'P4308', message = 'DAILY_CLOSE_INVALID';
  end if;
  select * into v_empresa
  from public.companies empresa
  where empresa.id = p_empresa
    and empresa.status = 'active';
  if not found or not exists (
    select 1 from pg_catalog.pg_timezone_names zona
    where zona.name = v_empresa.timezone
  ) then
    raise exception using errcode = 'P4304', message = 'COMPANY_TIMEZONE_INVALID';
  end if;
  v_hoy := (clock_timestamp() at time zone v_empresa.timezone)::date;
  if p_fecha >= v_hoy then
    raise exception using errcode = 'P4302', message = 'DATE_NOT_EXPIRED';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_empresa::text || ':CLOSE:' || p_fecha::text,
      4300
    )
  );
  select coalesce(max(cierre.intento), 0) + 1
  into v_intento
  from public.nomina_cierres_diarios cierre
  where cierre.empresa_id = p_empresa
    and cierre.fecha_local = p_fecha;

  for v_empleado in
    select empleado.id
    from public.empleados empleado
    where empleado.empresa_id = p_empresa
      and empleado.fecha_ingreso is not null
      and empleado.fecha_ingreso <= p_fecha
      and private.empleado_vigente_en_fecha_nomina_0043(
        p_empresa, empleado.id, p_fecha
      )
      and not private.empleado_suspendido_en_fecha_nomina_0043(
        p_empresa, empleado.id, p_fecha
      )
    order by empleado.id
  loop
    v_objetivo := v_objetivo + 1;
    begin
      v_resultado := private.resolver_nomina_dia_0043(
        p_empresa, v_empleado.id, p_fecha, p_actor, v_motivo
      );
      if (v_resultado ->> 'inserted')::boolean then
        v_nuevas := v_nuevas + 1;
      else
        v_reutilizadas := v_reutilizadas + 1;
      end if;
      v_detalle := v_detalle || jsonb_build_array(
        jsonb_build_object(
          'empleado_id', v_empleado.id,
          'resultado', v_resultado
        )
      );
    exception
      when sqlstate 'P4312' then
        v_objetivo := v_objetivo - 1;
      when others then
        v_errores := v_errores + 1;
        v_detalle := v_detalle || jsonb_build_array(
          jsonb_build_object(
            'empleado_id', v_empleado.id,
            'sqlstate', SQLSTATE,
            'error', SQLERRM
          )
        );
    end;
  end loop;

  if extract(month from p_fecha)::integer = 2
     and p_fecha = (
       date_trunc('month', p_fecha::timestamp)
       + interval '1 month' - interval '1 day'
     )::date
  then
    for v_complemento_empleado in
      select empleado.id
      from public.empleados empleado
      where empleado.empresa_id = p_empresa
        and empleado.fecha_ingreso is not null
        and empleado.fecha_ingreso <= p_fecha
      order by empleado.id
    loop
      begin
        if not private.empleado_vigente_en_fecha_nomina_0043(
          p_empresa, v_complemento_empleado.id, p_fecha
        ) then
          continue;
        end if;
        v_complemento_resultado :=
          private.resolver_complemento_convencion_30_0043(
            p_empresa,
            v_complemento_empleado.id,
            extract(year from p_fecha)::integer,
            p_actor,
            v_motivo
          );
        v_complemento_detalle := v_complemento_detalle || jsonb_build_array(
          jsonb_build_object(
            'empleado_id', v_complemento_empleado.id,
            'resultado', v_complemento_resultado
          )
        );
      exception
        when others then
          v_complemento_errores := v_complemento_errores + 1;
          v_complemento_detalle :=
            v_complemento_detalle || jsonb_build_array(
              jsonb_build_object(
                'empleado_id', v_complemento_empleado.id,
                'sqlstate', SQLSTATE,
                'error', SQLERRM
              )
            );
      end;
    end loop;
  end if;

  insert into public.nomina_cierres_diarios(
    empresa_id, fecha_local, timezone, origen, intento, estado,
    empleados_objetivo, resoluciones_nuevas,
    resoluciones_reutilizadas, errores,
    detalle, motivo, actor_id
  ) values (
    p_empresa, p_fecha, v_empresa.timezone, v_origen, v_intento,
    case
      when v_errores = 0 and v_complemento_errores = 0
        then 'COMPLETADO'
      else 'CON_ERRORES'
    end,
    v_objetivo, v_nuevas, v_reutilizadas, v_errores,
    jsonb_build_object(
      'empleados', v_detalle,
      'complementos_convencion_30', v_complemento_detalle,
      'complementos_convencion_30_errores', v_complemento_errores
    ),
    v_motivo, p_actor
  )
  returning * into v_cierre;

  return jsonb_build_object(
    'id', v_cierre.id,
    'empresa_id', v_cierre.empresa_id,
    'fecha_local', v_cierre.fecha_local,
    'origen', v_cierre.origen,
    'intento', v_cierre.intento,
    'estado', v_cierre.estado,
    'empleados_objetivo', v_cierre.empleados_objetivo,
    'resoluciones_nuevas', v_cierre.resoluciones_nuevas,
    'resoluciones_reutilizadas', v_cierre.resoluciones_reutilizadas,
    'errores', v_cierre.errores,
    'complementos_convencion_30_errores', v_complemento_errores
  );
end;
$$;

create or replace function public.registrar_suspension_laboral_empleado(
  p_empleado uuid,
  p_fecha_desde date,
  p_motivo text,
  p_observacion text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_fecha_ingreso date;
  v_id uuid := extensions.gen_random_uuid();
  v_motivo text := btrim(coalesce(p_motivo, ''));
  v_observacion text := nullif(btrim(coalesce(p_observacion, '')), '');
begin
  select * into v_actor
  from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if p_empleado is null or p_fecha_desde is null
     or char_length(v_motivo) not between 3 and 500
     or char_length(coalesce(v_observacion, '')) > 1000
  then
    raise exception using errcode = 'P4308', message = 'SUSPENSION_REQUEST_INVALID';
  end if;

  select empleado.fecha_ingreso
  into v_fecha_ingreso
  from public.empleados empleado
  where empleado.empresa_id = v_actor.empresa_id
    and empleado.id = p_empleado
  for share;
  if not found
     or not private.puede_gestionar_suspension_laboral_0043(p_empleado)
  then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if v_fecha_ingreso is null or p_fecha_desde < v_fecha_ingreso
     or not private.rango_suspension_dentro_ciclo_laboral_0043(
       v_actor.empresa_id, p_empleado, p_fecha_desde, null
     )
  then
    raise exception using
      errcode = 'P4306', message = 'EMPLOYEE_NOT_ACTIVE_ON_DATE';
  end if;

  insert into public.nomina_suspensiones_laborales(
    id, empresa_id, suspension_id, empleado_id, revision, estado,
    fecha_desde, fecha_hasta, version_anterior_id,
    motivo, observacion, created_by
  ) values (
    v_id, v_actor.empresa_id, v_id, p_empleado, 1, 'ABIERTA',
    p_fecha_desde, null, null, v_motivo, v_observacion, v_actor.perfil_id
  );
  return v_id;
end;
$$;

create or replace function public.finalizar_suspension_laboral_empleado(
  p_suspension uuid,
  p_fecha_hasta date,
  p_motivo text,
  p_observacion text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_raiz public.nomina_suspensiones_laborales%rowtype;
  v_actual public.nomina_suspensiones_laborales%rowtype;
  v_id uuid := extensions.gen_random_uuid();
  v_motivo text := btrim(coalesce(p_motivo, ''));
  v_observacion text := nullif(btrim(coalesce(p_observacion, '')), '');
begin
  select * into v_actor
  from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if p_suspension is null or p_fecha_hasta is null
     or char_length(v_motivo) not between 3 and 500
     or char_length(coalesce(v_observacion, '')) > 1000
  then
    raise exception using errcode = 'P4308', message = 'SUSPENSION_REQUEST_INVALID';
  end if;

  select * into v_raiz
  from public.nomina_suspensiones_laborales suspension
  where suspension.empresa_id = v_actor.empresa_id
    and suspension.id = p_suspension
    and suspension.suspension_id = p_suspension;
  if not found
     or not private.puede_gestionar_suspension_laboral_0043(
       v_raiz.empleado_id
     )
  then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      v_actor.empresa_id::text || ':SUSPENSION:'
        || v_raiz.empleado_id::text,
      4300
    )
  );
  select * into v_actual
  from public.nomina_suspensiones_laborales suspension
  where suspension.empresa_id = v_actor.empresa_id
    and suspension.suspension_id = p_suspension
  order by suspension.revision desc
  limit 1
  for share;
  if not found or v_actual.estado <> 'ABIERTA'
     or v_actual.revision <> 1 or v_actual.id <> p_suspension
  then
    raise exception using
      errcode = 'P4314', message = 'EMPLOYEE_SUSPENSION_HISTORY_INVALID';
  end if;
  if p_fecha_hasta < v_actual.fecha_desde then
    raise exception using errcode = 'P4308', message = 'SUSPENSION_REQUEST_INVALID';
  end if;
  if not private.rango_suspension_dentro_ciclo_laboral_0043(
    v_actor.empresa_id, v_actual.empleado_id,
    v_actual.fecha_desde, p_fecha_hasta
  ) then
    raise exception using
      errcode = 'P4306', message = 'EMPLOYEE_NOT_ACTIVE_ON_DATE';
  end if;

  insert into public.nomina_suspensiones_laborales(
    id, empresa_id, suspension_id, empleado_id, revision, estado,
    fecha_desde, fecha_hasta, version_anterior_id,
    motivo, observacion, created_by
  ) values (
    v_id, v_actor.empresa_id, p_suspension, v_actual.empleado_id,
    2, 'FINALIZADA', v_actual.fecha_desde, p_fecha_hasta,
    v_actual.id, v_motivo, v_observacion, v_actor.perfil_id
  );
  return v_id;
end;
$$;

create or replace function public.registrar_suspension_laboral_empleado(
  p_empleado uuid,
  p_fecha_desde date,
  p_fecha_hasta date,
  p_motivo text,
  p_observacion text default null
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_fecha_ingreso date;
  v_suspension uuid := extensions.gen_random_uuid();
  v_final uuid := extensions.gen_random_uuid();
  v_motivo text := btrim(coalesce(p_motivo, ''));
  v_observacion text := nullif(btrim(coalesce(p_observacion, '')), '');
begin
  select * into v_actor
  from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if p_empleado is null or p_fecha_desde is null
     or (p_fecha_hasta is not null and p_fecha_hasta < p_fecha_desde)
     or char_length(v_motivo) not between 3 and 500
     or char_length(coalesce(v_observacion, '')) > 1000
  then
    raise exception using errcode = 'P4308', message = 'SUSPENSION_REQUEST_INVALID';
  end if;

  select empleado.fecha_ingreso
  into v_fecha_ingreso
  from public.empleados empleado
  where empleado.empresa_id = v_actor.empresa_id
    and empleado.id = p_empleado
  for share;
  if not found
     or not private.puede_gestionar_suspension_laboral_0043(p_empleado)
  then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if v_fecha_ingreso is null or p_fecha_desde < v_fecha_ingreso
     or not private.rango_suspension_dentro_ciclo_laboral_0043(
       v_actor.empresa_id, p_empleado, p_fecha_desde, p_fecha_hasta
     )
  then
    raise exception using
      errcode = 'P4306', message = 'EMPLOYEE_NOT_ACTIVE_ON_DATE';
  end if;

  insert into public.nomina_suspensiones_laborales(
    id, empresa_id, suspension_id, empleado_id, revision, estado,
    fecha_desde, fecha_hasta, version_anterior_id,
    motivo, observacion, created_by
  ) values (
    v_suspension, v_actor.empresa_id, v_suspension, p_empleado,
    1, 'ABIERTA', p_fecha_desde, null, null,
    v_motivo, v_observacion, v_actor.perfil_id
  );
  if p_fecha_hasta is not null then
    insert into public.nomina_suspensiones_laborales(
      id, empresa_id, suspension_id, empleado_id, revision, estado,
      fecha_desde, fecha_hasta, version_anterior_id,
      motivo, observacion, created_by
    ) values (
      v_final, v_actor.empresa_id, v_suspension, p_empleado,
      2, 'FINALIZADA', p_fecha_desde, p_fecha_hasta, v_suspension,
      v_motivo, v_observacion, v_actor.perfil_id
    );
  end if;
  return v_suspension;
end;
$$;

create or replace function public.listar_suspensiones_laborales_empleado(
  p_empleado uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_resultado jsonb;
begin
  select * into v_actor
  from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if p_empleado is null
     or not exists (
       select 1
       from public.empleados empleado
       where empleado.empresa_id = v_actor.empresa_id
         and empleado.id = p_empleado
     )
     or not private.puede_gestionar_suspension_laboral_0043(p_empleado)
  then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;

  select coalesce(
    jsonb_agg(
      to_jsonb(suspension) - 'empresa_id' - 'periodo' - 'created_by'
      order by suspension.fecha_desde desc,
        suspension.suspension_id, suspension.revision
    ),
    '[]'::jsonb
  ) into v_resultado
  from public.nomina_suspensiones_laborales suspension
  where suspension.empresa_id = v_actor.empresa_id
    and suspension.empleado_id = p_empleado;
  return v_resultado;
end;
$$;

create or replace function public.resolver_nomina_dia(
  p_empleado uuid,
  p_fecha date,
  p_motivo text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
begin
  select * into v_actor
  from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  return private.resolver_nomina_dia_0043(
    v_actor.empresa_id,
    p_empleado,
    p_fecha,
    v_actor.perfil_id,
    p_motivo
  );
end;
$$;

create or replace function public.listar_resoluciones_nomina_diaria(
  p_empleado uuid,
  p_desde date,
  p_hasta date,
  p_incluir_historial boolean default false
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_resultado jsonb;
begin
  select * into v_actor
  from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if p_empleado is null or p_desde is null or p_hasta is null
     or p_desde > p_hasta or p_hasta - p_desde > 366
     or p_incluir_historial is null
  then
    raise exception using errcode = 'P4308', message = 'DAILY_QUERY_INVALID';
  end if;
  if not exists (
    select 1
    from public.empleados empleado
    where empleado.empresa_id = v_actor.empresa_id
      and empleado.id = p_empleado
  ) or not (
    public.puede_operar_empleado_en_alcance(p_empleado, 'nomina.ver')
    or public.puede_operar_empleado_en_alcance(p_empleado, 'nomina.generar')
    or (
      v_actor.rol_codigo <> 'SUPERVISOR'
      and (
        public.tiene_permiso_en_alcance(
          'nomina.ver', array['empresa', 'global']
        )
        or public.tiene_permiso_en_alcance(
          'nomina.generar', array['empresa', 'global']
        )
      )
    )
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;

  select coalesce(
    jsonb_agg(
      to_jsonb(resolucion) - 'empresa_id' - 'actor_id'
      order by resolucion.fecha_local, resolucion.revision
    ),
    '[]'::jsonb
  )
  into v_resultado
  from public.nomina_resoluciones_diarias resolucion
  where resolucion.empresa_id = v_actor.empresa_id
    and resolucion.empleado_id = p_empleado
    and resolucion.fecha_local between p_desde and p_hasta
    and (
      p_incluir_historial
      or (
        not exists (
          select 1
          from public.nomina_resoluciones_diarias posterior
          where posterior.empresa_id = resolucion.empresa_id
            and posterior.empleado_id = resolucion.empleado_id
            and posterior.fecha_local = resolucion.fecha_local
            and posterior.revision > resolucion.revision
        )
        and not private.empleado_suspendido_en_fecha_nomina_0043(
          resolucion.empresa_id,
          resolucion.empleado_id,
          resolucion.fecha_local
        )
      )
    );
  return v_resultado;
end;
$$;

create or replace function public.cerrar_nomina_dia_empresa(
  p_fecha date,
  p_motivo text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
begin
  select * into v_actor
  from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if v_actor.rol_codigo = 'SUPERVISOR'
     or not public.tiene_permiso_en_alcance(
       'nomina.generar', array['empresa', 'global']
     )
  then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  perform pg_catalog.pg_advisory_xact_lock_shared(
    pg_catalog.hashtextextended(
      v_actor.empresa_id::text || ':AUTO_CLOSE',
      4301
    )
  );
  return private.cerrar_nomina_dia_empresa_0043(
    v_actor.empresa_id,
    p_fecha,
    v_actor.perfil_id,
    p_motivo,
    'MANUAL'
  );
end;
$$;

create or replace function public.cerrar_nomina_dias_vencidos()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa record;
  v_ayer date;
  v_ancla date;
  v_fecha date;
  v_cierre jsonb;
  v_intento bigint;
  v_sqlstate text;
  v_error text;
  v_resultado jsonb := '[]'::jsonb;
begin
  for v_empresa in
    select empresa.id, empresa.timezone
    from public.companies empresa
    where empresa.status = 'active'
    order by empresa.id
    for share
  loop
    if not exists (
      select 1 from pg_catalog.pg_timezone_names zona
      where zona.name = v_empresa.timezone
    ) then
      v_resultado := v_resultado || jsonb_build_array(
        jsonb_build_object(
          'empresa_id', v_empresa.id,
          'error', 'COMPANY_TIMEZONE_INVALID'
        )
      );
      continue;
    end if;
    v_ayer := (
      clock_timestamp() at time zone v_empresa.timezone
    )::date - 1;

    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        v_empresa.id::text || ':AUTO_CLOSE',
        4301
      )
    );

    select min(cierre.fecha_local)
    into v_ancla
    from public.nomina_cierres_diarios cierre
    where cierre.empresa_id = v_empresa.id
      and cierre.origen = 'AUTOMATICO'
      and cierre.fecha_local <= v_ayer;

    if v_ancla is null then
      -- El primer automático jamás abre un backfill: solo intenta ayer.
      v_fecha := v_ayer;
    else
      select dia.fecha
      into v_fecha
      from (
        select serie::date as fecha
        from pg_catalog.generate_series(
          v_ancla::timestamp,
          v_ayer::timestamp,
          interval '1 day'
        ) serie
      ) dia
      left join lateral (
        select cierre.estado
        from public.nomina_cierres_diarios cierre
        where cierre.empresa_id = v_empresa.id
          and cierre.fecha_local = dia.fecha
        order by cierre.intento desc
        limit 1
      ) ultimo on true
      where ultimo.estado is distinct from 'COMPLETADO'
      order by dia.fecha
      limit 1;
      if v_fecha is null then
        continue;
      end if;
    end if;

    while v_fecha is not null and v_fecha <= v_ayer loop
      begin
        v_cierre := private.cerrar_nomina_dia_empresa_0043(
          v_empresa.id,
          v_fecha,
          null,
          'Cierre diario automático',
          'AUTOMATICO'
        );
      exception when others then
        v_sqlstate := SQLSTATE;
        v_error := SQLERRM;
        perform pg_catalog.pg_advisory_xact_lock(
          pg_catalog.hashtextextended(
            v_empresa.id::text || ':CLOSE:' || v_fecha::text,
            4300
          )
        );
        select coalesce(max(cierre.intento), 0) + 1
        into v_intento
        from public.nomina_cierres_diarios cierre
        where cierre.empresa_id = v_empresa.id
          and cierre.fecha_local = v_fecha;
        insert into public.nomina_cierres_diarios(
          empresa_id, fecha_local, timezone, origen, intento, estado,
          empleados_objetivo, resoluciones_nuevas,
          resoluciones_reutilizadas, errores,
          detalle, motivo, actor_id
        ) values (
          v_empresa.id, v_fecha, v_empresa.timezone,
          'AUTOMATICO', v_intento, 'CON_ERRORES',
          0, 0, 0, 0,
          jsonb_build_object(
            'error_sistema', jsonb_build_object(
              'sqlstate', v_sqlstate,
              'error', v_error
            )
          ),
          'Cierre diario automático', null
        )
        returning jsonb_build_object(
          'id', id,
          'empresa_id', empresa_id,
          'fecha_local', fecha_local,
          'origen', origen,
          'intento', intento,
          'estado', estado,
          'empleados_objetivo', empleados_objetivo,
          'resoluciones_nuevas', resoluciones_nuevas,
          'resoluciones_reutilizadas', resoluciones_reutilizadas,
          'errores', errores,
          'sqlstate', v_sqlstate,
          'error', v_error
        ) into v_cierre;
      end;

      v_resultado := v_resultado || jsonb_build_array(v_cierre);
      exit when v_cierre ->> 'estado' <> 'COMPLETADO';

      select dia.fecha
      into v_fecha
      from (
        select serie::date as fecha
        from pg_catalog.generate_series(
          (v_fecha + 1)::timestamp,
          v_ayer::timestamp,
          interval '1 day'
        ) serie
      ) dia
      left join lateral (
        select cierre.estado
        from public.nomina_cierres_diarios cierre
        where cierre.empresa_id = v_empresa.id
          and cierre.fecha_local = dia.fecha
        order by cierre.intento desc
        limit 1
      ) ultimo on true
      where ultimo.estado is distinct from 'COMPLETADO'
      order by dia.fecha
      limit 1;
    end loop;
  end loop;
  return v_resultado;
end;
$$;

create view public.nomina_resoluciones_diarias_vigentes
with (security_invoker = true)
as
select resolucion.*
from public.nomina_resoluciones_diarias resolucion
where not exists (
  select 1
  from public.nomina_resoluciones_diarias posterior
  where posterior.empresa_id = resolucion.empresa_id
    and posterior.empleado_id = resolucion.empleado_id
    and posterior.fecha_local = resolucion.fecha_local
    and posterior.revision > resolucion.revision
)
and not private.resolucion_cubierta_por_suspension_0043(
  resolucion.empresa_id,
  resolucion.empleado_id,
  resolucion.fecha_local
);

create view public.nomina_complementos_convencion_30_vigentes
with (security_invoker = true)
as
select complemento.*
from public.nomina_complementos_convencion_30 complemento
where not exists (
  select 1
  from public.nomina_complementos_convencion_30 posterior
  where posterior.empresa_id = complemento.empresa_id
    and posterior.empleado_id = complemento.empleado_id
    and posterior.anio = complemento.anio
    and posterior.revision > complemento.revision
)
and private.complemento_convencion_30_vigente_0043(
  complemento.empresa_id,
  complemento.empleado_id,
  complemento.anio,
  complemento.fecha_fin_febrero,
  complemento.fecha_ancla
);

alter table public.nomina_resoluciones_diarias enable row level security;
alter table public.nomina_cierres_diarios enable row level security;
alter table public.nomina_complementos_convencion_30 enable row level security;
alter table public.nomina_suspensiones_laborales enable row level security;

create policy nomina_resoluciones_diarias_select
on public.nomina_resoluciones_diarias
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and (
    public.puede_operar_empleado_en_alcance(empleado_id, 'nomina.ver')
    or public.puede_operar_empleado_en_alcance(
      empleado_id, 'nomina.generar'
    )
    or (
      not public.es_supervisor_nomina_0043()
      and (
        public.tiene_permiso_en_alcance(
          'nomina.ver', array['empresa', 'global']
        )
        or public.tiene_permiso_en_alcance(
          'nomina.generar', array['empresa', 'global']
        )
      )
    )
  )
);

create policy nomina_complementos_convencion_30_select
on public.nomina_complementos_convencion_30
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and (
    public.puede_operar_empleado_en_alcance(empleado_id, 'nomina.ver')
    or public.puede_operar_empleado_en_alcance(
      empleado_id, 'nomina.generar'
    )
    or (
      not public.es_supervisor_nomina_0043()
      and (
        public.tiene_permiso_en_alcance(
          'nomina.ver', array['empresa', 'global']
        )
        or public.tiene_permiso_en_alcance(
          'nomina.generar', array['empresa', 'global']
        )
      )
    )
  )
);

create policy nomina_cierres_diarios_select
on public.nomina_cierres_diarios
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and not public.es_supervisor_nomina_0043()
  and (
    public.tiene_permiso_en_alcance(
      'nomina.ver', array['empresa', 'global']
    )
    or public.tiene_permiso_en_alcance(
      'nomina.generar', array['empresa', 'global']
    )
  )
);

revoke all on public.nomina_resoluciones_diarias,
  public.nomina_cierres_diarios,
  public.nomina_complementos_convencion_30,
  public.nomina_suspensiones_laborales,
  public.nomina_resoluciones_diarias_vigentes,
  public.nomina_complementos_convencion_30_vigentes
from public, anon, authenticated, service_role;
grant select on public.nomina_resoluciones_diarias,
  public.nomina_cierres_diarios,
  public.nomina_complementos_convencion_30,
  public.nomina_resoluciones_diarias_vigentes,
  public.nomina_complementos_convencion_30_vigentes
to authenticated;

revoke all on function private.proteger_historial_nomina_0043()
from public, anon, authenticated, service_role;
revoke all on function private.empleado_vigente_en_fecha_nomina_0043(
  uuid, uuid, date
) from public, anon, authenticated, service_role;
revoke all on function private.validar_suspension_laboral_0043()
from public, anon, authenticated, service_role;
revoke all on function private.puede_gestionar_suspension_laboral_0043(uuid)
from public, anon, authenticated, service_role;
revoke all on function private.empleado_suspendido_en_fecha_nomina_0043(
  uuid, uuid, date
) from public, anon, authenticated, service_role;
revoke all on function private.rango_suspension_dentro_ciclo_laboral_0043(
  uuid, uuid, date, date
) from public, anon, authenticated, service_role;
revoke all on function private.bloquear_desvinculacion_suspension_0043()
from public, anon, authenticated, service_role;
revoke all on function private.resolucion_cubierta_por_suspension_0043(
  uuid, uuid, date
) from public, anon, authenticated, service_role;
grant execute on function private.resolucion_cubierta_por_suspension_0043(
  uuid, uuid, date
) to authenticated;
revoke all on function public.es_supervisor_nomina_0043()
from public, anon, service_role;
grant execute on function public.es_supervisor_nomina_0043() to authenticated;
revoke all on function private.base_nominal_dia_0043(numeric, date)
from public, anon, authenticated, service_role;
revoke all on function private.complemento_convencion_30_0043(numeric, date)
from public, anon, authenticated, service_role;
revoke all on function private.calcular_objetivos_nomina_dia_0043(
  date, numeric, numeric, integer, integer, boolean,
  text, numeric, boolean, boolean
) from public, anon, authenticated, service_role;
revoke all on function private.resolver_nomina_dia_0043(
  uuid, uuid, date, uuid, text
) from public, anon, authenticated, service_role;
revoke all on function private.resolver_complemento_convencion_30_0043(
  uuid, uuid, integer, uuid, text
) from public, anon, authenticated, service_role;
revoke all on function private.complemento_convencion_30_vigente_0043(
  uuid, uuid, integer, date, date
) from public, anon, authenticated, service_role;
grant execute on function private.complemento_convencion_30_vigente_0043(
  uuid, uuid, integer, date, date
) to authenticated;
revoke all on function private.cerrar_nomina_dia_empresa_0043(
  uuid, date, uuid, text, text
) from public, anon, authenticated, service_role;

revoke all on function public.registrar_suspension_laboral_empleado(
  uuid, date, text, text
) from public, anon, service_role;
revoke all on function public.finalizar_suspension_laboral_empleado(
  uuid, date, text, text
) from public, anon, service_role;
revoke all on function public.registrar_suspension_laboral_empleado(
  uuid, date, date, text, text
) from public, anon, service_role;
revoke all on function public.listar_suspensiones_laborales_empleado(uuid)
from public, anon, service_role;
grant execute on function public.registrar_suspension_laboral_empleado(
  uuid, date, text, text
) to authenticated;
grant execute on function public.finalizar_suspension_laboral_empleado(
  uuid, date, text, text
) to authenticated;
grant execute on function public.registrar_suspension_laboral_empleado(
  uuid, date, date, text, text
) to authenticated;
grant execute on function public.listar_suspensiones_laborales_empleado(uuid)
to authenticated;

revoke all on function public.resolver_nomina_dia(uuid, date, text)
from public, anon, service_role;
revoke all on function public.listar_resoluciones_nomina_diaria(
  uuid, date, date, boolean
) from public, anon, service_role;
revoke all on function public.cerrar_nomina_dia_empresa(date, text)
from public, anon, service_role;
grant execute on function public.resolver_nomina_dia(uuid, date, text)
to authenticated;
grant execute on function public.listar_resoluciones_nomina_diaria(
  uuid, date, date, boolean
) to authenticated;
grant execute on function public.cerrar_nomina_dia_empresa(date, text)
to authenticated;

revoke all on function public.cerrar_nomina_dias_vencidos()
from public, anon, authenticated;
grant execute on function public.cerrar_nomina_dias_vencidos()
to service_role;

comment on table public.nomina_suspensiones_laborales is
  'Historial append-only de suspensiones laborales; cada finalización agrega una versión y el rango es inclusivo.';
comment on function public.registrar_suspension_laboral_empleado(
  uuid, date, text, text
) is 'Registra una suspensión laboral abierta con permiso HR y alcance sobre el empleado.';
comment on function public.finalizar_suspension_laboral_empleado(
  uuid, date, text, text
) is 'Finaliza una suspensión mediante una nueva versión inmutable con fecha final inclusiva.';
comment on function public.registrar_suspension_laboral_empleado(
  uuid, date, date, text, text
) is 'Registra una suspension abierta o cerrada; una fecha final crea la revision finalizada en la misma transaccion.';

comment on table public.nomina_complementos_convencion_30 is
  'Complemento mensual de febrero para la convención de 30 días; historial append-only independiente de resoluciones diarias.';
comment on column public.nomina_complementos_convencion_30.fecha_ancla is
  'Última fecha real entre el 16 y el fin de febrero con vínculo vigente y sin suspensión; determina la condición salarial.';
comment on table public.nomina_resoluciones_diarias is
  'Objetivos económicos diarios canónicos y append-only; 0043 no escribe el ledger 0038.';
comment on column public.nomina_resoluciones_diarias.minutos_trabajados is
  'Snapshot de jornadas.minutos_trabajados; ya excluye pausas y no se recalcula desde timestamps.';
comment on function public.resolver_nomina_dia(uuid, date, text) is
  'Reconcilia una fecha explícita; las consultas nunca crean resoluciones.';

commit;
