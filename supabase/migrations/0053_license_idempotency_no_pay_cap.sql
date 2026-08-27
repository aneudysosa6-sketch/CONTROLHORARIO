begin;

create or replace function public.crear_licencia_empleado(
  p_empleado uuid,
  p_fecha_inicio date,
  p_fecha_fin date,
  p_porcentaje numeric,
  p_documento_path text,
  p_motivo text,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_catalog, pg_temp
as $$
declare
  v_company uuid := public.obtener_empresa_actual();
  v_actor uuid := auth.uid();
  v_license public.licencias_empleado%rowtype;
begin
  if v_company is null or v_actor is null then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not public.puede_operar_empleado_en_alcance(p_empleado, 'licencias.gestionar') then
    raise exception using errcode = '42501', message = 'LICENSE_SCOPE_DENIED';
  end if;
  if p_fecha_inicio is null or p_fecha_fin < p_fecha_inicio
     or p_porcentaje not between 0 and 100
     or p_idempotency_key is null
     or nullif(btrim(p_motivo), '') is null
  then
    raise exception using errcode = '22023', message = 'LICENSE_INPUT_INVALID';
  end if;

  select * into v_license
  from public.licencias_empleado
  where empresa_id = v_company and idempotency_key = p_idempotency_key;
  if found then
    if v_license.empleado_id <> p_empleado then
      raise exception using errcode = '23505', message = 'LICENSE_IDEMPOTENCY_CONFLICT';
    end if;
    return jsonb_build_object(
      'id', v_license.id,
      'revision', v_license.revision_actual,
      'estado', v_license.estado,
      'idempotent_replay', true
    );
  end if;

  if exists (
    select 1
    from public.licencias_empleado l
    join public.licencias_empleado_versiones v
      on v.empresa_id = l.empresa_id
     and v.licencia_id = l.id
     and v.revision = l.revision_actual
    where l.empresa_id = v_company
      and l.empleado_id = p_empleado
      and l.estado = 'ACTIVA'
      and daterange(v.fecha_inicio, v.fecha_fin, '[]') && daterange(p_fecha_inicio, p_fecha_fin, '[]')
  ) then
    raise exception using errcode = '23P01', message = 'LICENSE_DATE_OVERLAP';
  end if;

  insert into public.licencias_empleado (
    empresa_id, empleado_id, idempotency_key, creada_por
  ) values (v_company, p_empleado, p_idempotency_key, v_actor)
  returning * into v_license;

  insert into public.licencias_empleado_versiones (
    empresa_id, licencia_id, empleado_id, revision, fecha_inicio, fecha_fin,
    porcentaje, documento_path, modo_recalculo, aplicar_desde, motivo, creada_por
  ) values (
    v_company, v_license.id, p_empleado, 1, p_fecha_inicio, p_fecha_fin,
    p_porcentaje, nullif(btrim(p_documento_path), ''), 'DESDE_INICIO',
    p_fecha_inicio, btrim(p_motivo), v_actor
  );
  perform private.regenerar_dias_licencia_0050(v_license.id, p_fecha_inicio);
  return jsonb_build_object(
    'id', v_license.id,
    'revision', 1,
    'estado', 'ACTIVA',
    'idempotent_replay', false
  );
end;
$$;

create or replace function public.resolver_jornada_incompleta_no_pagar(
  p_jornada uuid,
  p_horas_manual numeric,
  p_motivo text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_catalog, pg_temp
as $$
declare
  v_company uuid := public.obtener_empresa_actual();
  v_actor uuid := auth.uid();
  v_journey public.jornadas%rowtype;
  v_event_count integer;
  v_last_action text;
  v_last_pause timestamptz;
  v_hours numeric(6,2);
  v_manual boolean;
  v_salary numeric(14,2);
  v_amount numeric(14,2);
  v_resolution public.nomina_jornadas_incompletas_resueltas%rowtype;
begin
  select * into v_journey
  from public.jornadas
  where empresa_id = v_company and id = p_jornada
  for update;
  if not found or v_journey.finalizado_en is not null then
    raise exception using errcode = 'P5003', message = 'INCOMPLETE_JOURNEY_NOT_FOUND';
  end if;
  if not public.puede_operar_empleado_en_alcance(v_journey.empleado_id, 'nomina.no_pagar') then
    raise exception using errcode = '42501', message = 'NO_PAY_SCOPE_DENIED';
  end if;
  if exists (
    select 1 from public.nomina_periodos p
    where p.empresa_id = v_company and p.estado = 'CERRADA'
      and v_journey.fecha_laboral between p.fecha_inicio and p.fecha_fin
  ) then
    raise exception using errcode = '55000', message = 'PAYROLL_PERIOD_CLOSED';
  end if;
  if nullif(btrim(p_motivo), '') is null then
    raise exception using errcode = '22023', message = 'NO_PAY_REASON_REQUIRED';
  end if;

  select count(*),
         (array_agg(ev.accion order by ev.ocurrido_en desc, ev.id desc))[1],
         max(ev.ocurrido_en) filter (where ev.accion = 'PAUSAR')
  into v_event_count, v_last_action, v_last_pause
  from public.jornada_eventos ev
  where ev.empresa_id = v_company and ev.jornada_id = v_journey.id;

  if v_event_count = 1 and v_last_action = 'INICIAR' then
    if p_horas_manual is null or p_horas_manual < 0 or p_horas_manual > 8 then
      raise exception using errcode = '22023', message = 'NO_PAY_MANUAL_HOURS_OUT_OF_RANGE';
    end if;
    v_hours := round(p_horas_manual, 2);
    v_manual := true;
  else
    if p_horas_manual is not null then
      raise exception using errcode = '22023', message = 'NO_PAY_MANUAL_HOURS_NOT_ALLOWED';
    end if;
    v_manual := false;
    if v_last_action = 'PAUSAR' and v_last_pause is not null and v_journey.iniciado_en is not null then
      v_hours := round(greatest(0, extract(epoch from (v_last_pause - v_journey.iniciado_en)) / 3600.0), 2);
    else
      v_hours := round(greatest(0, coalesce(v_journey.minutos_trabajados, 0)) / 60.0, 2);
    end if;
  end if;

  v_hours := least(8.00::numeric, greatest(0.00::numeric, v_hours));

  select coalesce(salario, 0) into v_salary
  from public.empleados where empresa_id = v_company and id = v_journey.empleado_id;
  v_amount := round((v_salary / 30.0 / 8.0) * v_hours, 2);

  insert into public.nomina_jornadas_incompletas_resueltas (
    empresa_id, jornada_id, empleado_id, fecha, ultimo_evento,
    horas_pagables, horas_manual, monto, motivo, resuelta_por
  ) values (
    v_company, v_journey.id, v_journey.empleado_id, v_journey.fecha_laboral,
    coalesce(v_last_action, 'INICIAR'), v_hours, v_manual, v_amount,
    btrim(p_motivo), v_actor
  )
  on conflict (empresa_id, jornada_id) do update set
    ultimo_evento = excluded.ultimo_evento,
    horas_pagables = excluded.horas_pagables,
    horas_manual = excluded.horas_manual,
    monto = excluded.monto,
    motivo = excluded.motivo,
    resuelta_por = excluded.resuelta_por,
    actualizada_en = statement_timestamp()
  returning * into v_resolution;

  update public.jornadas
  set minutos_trabajados = round(v_hours * 60)::integer,
      estado = 'FINALIZADA',
      revision_pendiente = false,
      actualizada_en = statement_timestamp(),
      actualizada_por = v_actor,
      version_sync = version_sync + 1
  where id = v_journey.id and empresa_id = v_company;

  return to_jsonb(v_resolution) - 'empresa_id';
end;
$$;

comment on function public.crear_licencia_empleado(uuid,date,date,numeric,text,text,uuid)
is 'Creates a direct employee license; same-company idempotency replays are resolved before overlap checks.';
comment on function public.resolver_jornada_incompleta_no_pagar(uuid,numeric,text)
is 'Resolves an incomplete journey without allowing payable hours above the regular eight-hour day.';

commit;