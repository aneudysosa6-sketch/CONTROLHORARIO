begin;

-- Conserva en cada snapshot el importe solicitado, el realmente descontado y
-- el remanente. Las filas historicas existentes representan importes que ya
-- fueron totalmente aceptados por su motor original.
alter table public.nomina_descuentos
  add column monto_solicitado numeric(14,2),
  add column monto_pendiente numeric(14,2),
  add column metadata jsonb;

update public.nomina_descuentos
set monto_solicitado = monto,
    monto_pendiente = 0,
    metadata = '{}'::jsonb
where monto_solicitado is null
   or monto_pendiente is null
   or metadata is null;

alter table public.nomina_descuentos
  alter column monto_solicitado set default 0,
  alter column monto_solicitado set not null,
  alter column monto_pendiente set default 0,
  alter column monto_pendiente set not null,
  alter column metadata set default '{}'::jsonb,
  alter column metadata set not null,
  add constraint nomina_descuentos_montos_v3_check check (
    monto_solicitado >= 0
    and monto >= 0
    and monto_pendiente >= 0
    and monto <= monto_solicitado
    and monto_pendiente = monto_solicitado - monto
  );

create or replace function public.nomina_prorratear_obligacion_v3(
  p_modo text,
  p_valor numeric,
  p_bruto numeric,
  p_factor integer,
  p_minutos_normales numeric,
  p_divisor numeric,
  p_horas_dia numeric
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select round(
    case
      when coalesce(p_modo, 'MONTO') = 'PORCENTAJE' then
        greatest(coalesce(p_bruto, 0), 0) * greatest(coalesce(p_valor, 0), 0) / 100
      when coalesce(p_divisor, 0) > 0
       and coalesce(p_horas_dia, 0) > 0
       and greatest(coalesce(p_factor, 1), 1) > 0 then
        greatest(coalesce(p_valor, 0), 0)
        * greatest(coalesce(p_factor, 1), 1)
        * least(
            1,
            greatest(coalesce(p_minutos_normales, 0), 0)
            / (
                p_divisor
                * p_horas_dia
                * 60
                * greatest(p_factor, 1)
                / 2
              )
          )
      else 0
    end,
    2
  );
$$;

create or replace function public.nomina_distribuir_descuentos_v3(
  p_bruto numeric,
  p_solicitudes jsonb
)
returns jsonb
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_disponible numeric := round(greatest(coalesce(p_bruto, 0), 0), 2);
  v_solicitado numeric := 0;
  v_aplicado numeric := 0;
  v_pendiente numeric := 0;
  v_item jsonb;
  v_monto_solicitado numeric;
  v_monto_aplicado numeric;
  v_monto_pendiente numeric;
  v_items jsonb := '[]'::jsonb;
begin
  if coalesce(jsonb_typeof(p_solicitudes), '') <> 'array' then
    raise exception 'PAYROLL_DEDUCTION_REQUESTS_MUST_BE_ARRAY';
  end if;

  for v_item in
    select value
    from jsonb_array_elements(p_solicitudes) with ordinality as x(value, ordinal)
    order by
      coalesce((value ->> 'priority')::integer, 9999),
      coalesce((value ->> 'sequence')::integer, ordinal::integer),
      ordinal
  loop
    v_monto_solicitado := round(greatest(coalesce((v_item ->> 'requested')::numeric, 0), 0), 2);
    v_monto_aplicado := round(least(v_monto_solicitado, v_disponible), 2);
    v_monto_pendiente := round(v_monto_solicitado - v_monto_aplicado, 2);
    v_disponible := round(greatest(v_disponible - v_monto_aplicado, 0), 2);

    v_solicitado := v_solicitado + v_monto_solicitado;
    v_aplicado := v_aplicado + v_monto_aplicado;
    v_pendiente := v_pendiente + v_monto_pendiente;
    v_items := v_items || jsonb_build_array(
      v_item || jsonb_build_object(
        'requested', v_monto_solicitado,
        'applied', v_monto_aplicado,
        'pending', v_monto_pendiente
      )
    );
  end loop;

  return jsonb_build_object(
    'requested', round(v_solicitado, 2),
    'applied', round(v_aplicado, 2),
    'pending', round(v_pendiente, 2),
    'net', round(v_disponible, 2),
    'items', v_items
  );
end
$$;

-- Declaracion adelantada: la implementacion completa se instala mas abajo.
create or replace function public.nomina_calculo_empleado_v3(
  p_empresa uuid,
  p_empleado uuid,
  p_inicio date,
  p_fin date,
  p_tipo_periodo text,
  p_periodo uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  raise exception 'PAYROLL_V3_FORWARD_DECLARATION';
end
$$;

create or replace function public.obtener_total_nomina_dashboard(p_fecha date default null)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.nomina_empresa_autorizada('nomina.ver');
  v_fecha date := coalesce(p_fecha, current_date);
  v_periodo_id uuid;
  v_nomina_id uuid;
  v_inicio date;
  v_fin date;
  v_tipo_periodo text;
  v_estado_periodo text;
  v_resumen jsonb;
  v_row record;
  v_calc jsonb;
  v_empleados jsonb := '[]'::jsonb;
  v_bloqueos jsonb := '[]'::jsonb;
  v_advertencias jsonb := '[]'::jsonb;
  v_empleados_incluidos integer := 0;
  v_jornadas_usadas integer := 0;
  v_minutos_totales numeric := 0;
  v_horas_cerradas numeric := 0;
  v_total numeric := 0;
  v_pending numeric;
begin
  -- Los cierres son snapshots contables y no se recalculan con el motor V3.
  select p.id, n.id, p.fecha_inicio, p.fecha_fin, p.tipo_periodo, p.estado, n.resumen
  into v_periodo_id, v_nomina_id, v_inicio, v_fin, v_tipo_periodo, v_estado_periodo, v_resumen
  from public.nomina_periodos p
  join public.nominas n
    on n.empresa_id = p.empresa_id
   and n.periodo_id = p.id
  where p.empresa_id = v_empresa
    and p.estado = 'CERRADA'
    and n.estado = 'CERRADA'
    and v_fecha between p.fecha_inicio and p.fecha_fin
  order by p.cerrada_en desc nulls last, p.fecha_inicio desc, p.creada_en desc
  limit 1;

  if found then
    if jsonb_typeof(v_resumen -> 'total_general_pagado') is distinct from 'number' then
      return jsonb_build_object(
        'status', 'UNAVAILABLE',
        'source', 'UNAVAILABLE',
        'as_of_date', v_fecha,
        'period_id', v_periodo_id,
        'period_start', v_inicio,
        'period_end', v_fin,
        'period_type', v_tipo_periodo,
        'payroll_state', v_estado_periodo,
        'total', null,
        'employees_included', 0,
        'journeys_used', 0,
        'total_hours', 0,
        'employees', '[]'::jsonb,
        'blockers', '[]'::jsonb,
        'warnings', '[]'::jsonb,
        'reason', 'La nomina cerrada no contiene un total almacenado valido.'
      );
    end if;

    select
      count(*)::integer,
      coalesce(sum(d.horas_normales + d.horas_extras), 0),
      coalesce(
        jsonb_agg(
          jsonb_build_object(
            'employee_id', d.empleado_id,
            'employee_code', d.codigo_empleado,
            'employee_name', d.nombre_empleado,
            'pay_type', d.tipo_pago,
            'salary', d.sueldo_base,
            'journeys', null,
            'normal_hours', d.horas_normales,
            'overtime_hours', d.horas_extras,
            'gross', d.bruto,
            'afp', d.afp,
            'sfs', d.sfs,
            'loans', d.descuento_prestamo,
            'discounts', d.total_descuentos,
            'deductions_applied', d.total_descuentos,
            'deductions_pending', coalesce((d.resultados #>> '{deductions,pending}')::numeric, 0),
            'deductions', coalesce(d.resultados -> 'deductions', '{}'::jsonb),
            'net', d.neto
          )
          order by d.codigo_empleado
        ),
        '[]'::jsonb
      )
    into v_empleados_incluidos, v_horas_cerradas, v_empleados
    from public.nomina_detalles d
    where d.empresa_id = v_empresa
      and d.nomina_id = v_nomina_id;

    select count(*)::integer
    into v_jornadas_usadas
    from public.jornadas j
    where j.empresa_id = v_empresa
      and j.fecha_laboral between v_inicio and v_fin
      and j.estado = 'FINALIZADA'
      and not j.revision_pendiente
      and not exists (
        select 1
        from public.jornada_conflictos c
        where c.empresa_id = j.empresa_id
          and c.jornada_id = j.id
          and c.estado = 'PENDIENTE'
      );

    return jsonb_build_object(
      'status', 'CLOSED',
      'source', 'CLOSED',
      'as_of_date', v_fecha,
      'period_id', v_periodo_id,
      'period_start', v_inicio,
      'period_end', v_fin,
      'period_type', v_tipo_periodo,
      'payroll_state', v_estado_periodo,
      'total', (v_resumen ->> 'total_general_pagado')::numeric,
      'employees_included', v_empleados_incluidos,
      'journeys_used', v_jornadas_usadas,
      'total_hours', round(v_horas_cerradas, 2),
      'employees', v_empleados,
      'blockers', '[]'::jsonb,
      'warnings', '[]'::jsonb,
      'reason', null
    );
  end if;

  select p.id, p.fecha_inicio, p.fecha_fin, p.tipo_periodo, p.estado
  into v_periodo_id, v_inicio, v_fin, v_tipo_periodo, v_estado_periodo
  from public.nomina_periodos p
  where p.empresa_id = v_empresa
    and p.estado not in ('ANULADA', 'CERRADA')
    and v_fecha between p.fecha_inicio and p.fecha_fin
  order by p.fecha_inicio desc, p.creada_en desc
  limit 1;

  if not found then
    v_periodo_id := null;
    v_estado_periodo := 'PREVIEW';
    v_tipo_periodo := 'QUINCENAL';
    if extract(day from v_fecha) <= 15 then
      v_inicio := date_trunc('month', v_fecha)::date;
      v_fin := v_inicio + 14;
    else
      v_inicio := (date_trunc('month', v_fecha) + interval '15 days')::date;
      v_fin := (date_trunc('month', v_fecha) + interval '1 month - 1 day')::date;
    end if;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'employee_code', x.codigo_empleado,
        'employee_name', x.nombre_completo,
        'reason', x.motivo,
        'message', x.mensaje,
        'journeys', x.cantidad
      )
      order by x.codigo_empleado, x.motivo
    ),
    '[]'::jsonb
  )
  into v_bloqueos
  from (
    select
      e.codigo_empleado,
      e.nombre_completo,
      case
        when j.revision_pendiente then 'JORNADA_PENDIENTE_REVISION'
        else 'CONFLICTO_JORNADA_PENDIENTE'
      end motivo,
      case
        when j.revision_pendiente then 'La jornada esta pendiente de revision y bloquea el calculo de nomina.'
        else 'La jornada tiene un conflicto pendiente y bloquea el calculo de nomina.'
      end mensaje,
      count(*)::integer cantidad
    from public.jornadas j
    join public.empleados e
      on e.empresa_id = j.empresa_id
     and e.id = j.empleado_id
    where j.empresa_id = v_empresa
      and j.fecha_laboral between v_inicio and v_fin
      and (
        j.revision_pendiente
        or exists (
          select 1
          from public.jornada_conflictos c
          where c.empresa_id = j.empresa_id
            and c.jornada_id = j.id
            and c.estado = 'PENDIENTE'
        )
      )
    group by e.codigo_empleado, e.nombre_completo, motivo, mensaje
  ) x;

  for v_row in
    select
      e.id,
      e.codigo_empleado,
      e.nombre_completo,
      e.salario,
      e.tipo_pago,
      r.id regla_id,
      r.dias_divisor_quincenal divisor,
      r.horas_dia,
      r.nomina_activa
    from public.empleados e
    left join public.nomina_reglas_empleado r
      on r.empresa_id = e.empresa_id
     and r.empleado_id = e.id
    where e.empresa_id = v_empresa
      and e.activo
      and coalesce(e.fecha_ingreso, v_fin) <= v_fin
    order by e.codigo_empleado
  loop
    if v_row.regla_id is null then
      v_bloqueos := v_bloqueos || jsonb_build_array(jsonb_build_object(
        'employee_id', v_row.id,
        'employee_code', v_row.codigo_empleado,
        'employee_name', v_row.nombre_completo,
        'reason', 'FICHA_PAGO_FALTANTE',
        'message', 'Falta la ficha de pago y nomina del empleado.'
      ));
      continue;
    end if;
    if not v_row.nomina_activa then
      v_bloqueos := v_bloqueos || jsonb_build_array(jsonb_build_object(
        'employee_id', v_row.id,
        'employee_code', v_row.codigo_empleado,
        'employee_name', v_row.nombre_completo,
        'reason', 'NOMINA_INACTIVA',
        'message', 'La ficha de nomina del empleado esta desactivada.'
      ));
      continue;
    end if;
    if coalesce(v_row.salario, 0) <= 0 then
      v_bloqueos := v_bloqueos || jsonb_build_array(jsonb_build_object(
        'employee_id', v_row.id,
        'employee_code', v_row.codigo_empleado,
        'employee_name', v_row.nombre_completo,
        'reason', 'SALARIO_FALTANTE',
        'message', 'El salario mensual no esta registrado o no es mayor que cero.'
      ));
      continue;
    end if;
    if v_row.tipo_pago is null or v_row.tipo_pago not in ('mensual', 'quincenal') then
      v_bloqueos := v_bloqueos || jsonb_build_array(jsonb_build_object(
        'employee_id', v_row.id,
        'employee_code', v_row.codigo_empleado,
        'employee_name', v_row.nombre_completo,
        'reason', 'TIPO_PAGO_FALTANTE',
        'message', 'El tipo de pago no esta registrado o no es valido.'
      ));
      continue;
    end if;
    if coalesce(v_row.divisor, 0) <= 0 or coalesce(v_row.horas_dia, 0) <= 0 then
      v_bloqueos := v_bloqueos || jsonb_build_array(jsonb_build_object(
        'employee_id', v_row.id,
        'employee_code', v_row.codigo_empleado,
        'employee_name', v_row.nombre_completo,
        'reason', 'FICHA_PAGO_INVALIDA',
        'message', 'El divisor salarial o las horas diarias no son validos.'
      ));
      continue;
    end if;

    v_calc := public.nomina_calculo_empleado_v3(
      v_empresa,
      v_row.id,
      v_inicio,
      v_fin,
      v_tipo_periodo,
      v_periodo_id
    );
    v_pending := coalesce((v_calc #>> '{deductions,pending}')::numeric, 0);

    if v_pending > 0 then
      v_advertencias := v_advertencias || jsonb_build_array(jsonb_build_object(
        'employee_id', v_row.id,
        'employee_code', v_row.codigo_empleado,
        'employee_name', v_row.nombre_completo,
        'reason', 'DEDUCCIONES_DIFERIDAS',
        'message', 'Parte de las deducciones queda pendiente para el siguiente periodo.',
        'amount', v_pending
      ));
    end if;

    v_empleados_incluidos := v_empleados_incluidos + 1;
    v_jornadas_usadas := v_jornadas_usadas + (v_calc ->> 'journeys')::integer;
    v_minutos_totales := v_minutos_totales
      + (v_calc ->> 'normal_minutes')::numeric
      + (v_calc ->> 'overtime_minutes')::numeric;
    v_total := round(v_total + (v_calc ->> 'net')::numeric, 2);

    v_empleados := v_empleados || jsonb_build_array(jsonb_build_object(
      'employee_id', v_calc -> 'employee_id',
      'employee_code', v_calc ->> 'employee_code',
      'employee_name', v_calc ->> 'employee_name',
      'pay_type', v_calc ->> 'pay_type',
      'salary', (v_calc ->> 'salary')::numeric,
      'journeys', (v_calc ->> 'journeys')::integer,
      'normal_hours', (v_calc ->> 'normal_hours')::numeric,
      'overtime_hours', (v_calc ->> 'overtime_hours')::numeric,
      'gross', (v_calc ->> 'gross')::numeric,
      'afp', coalesce((v_calc #>> '{deductions,afp,applied}')::numeric, 0),
      'sfs', coalesce((v_calc #>> '{deductions,sfs,applied}')::numeric, 0),
      'loans', coalesce((v_calc #>> '{deductions,loans,applied}')::numeric, 0),
      'discounts', coalesce((v_calc #>> '{deductions,applied}')::numeric, 0),
      'deductions_requested', coalesce((v_calc #>> '{deductions,requested}')::numeric, 0),
      'deductions_applied', coalesce((v_calc #>> '{deductions,applied}')::numeric, 0),
      'deductions_pending', v_pending,
      'deductions', v_calc -> 'deductions',
      'net', (v_calc ->> 'net')::numeric
    ));
  end loop;

  if jsonb_array_length(v_bloqueos) > 0 then
    return jsonb_build_object(
      'status', 'UNAVAILABLE',
      'source', 'UNAVAILABLE',
      'as_of_date', v_fecha,
      'period_id', v_periodo_id,
      'period_start', v_inicio,
      'period_end', v_fin,
      'period_type', v_tipo_periodo,
      'payroll_state', v_estado_periodo,
      'total', null,
      'employees_included', v_empleados_incluidos,
      'journeys_used', v_jornadas_usadas,
      'total_hours', round(v_minutos_totales / 60, 2),
      'employees', v_empleados,
      'blockers', v_bloqueos,
      'warnings', v_advertencias,
      'reason', 'El calculo esta bloqueado; revise los empleados indicados.'
    );
  end if;

  return jsonb_build_object(
    'status', 'REAL_TIME',
    'source', 'REAL_TIME',
    'as_of_date', v_fecha,
    'period_id', v_periodo_id,
    'period_start', v_inicio,
    'period_end', v_fin,
    'period_type', v_tipo_periodo,
    'payroll_state', v_estado_periodo,
    'total', greatest(round(v_total, 2), 0),
    'employees_included', v_empleados_incluidos,
    'journeys_used', v_jornadas_usadas,
    'total_hours', round(v_minutos_totales / 60, 2),
    'employees', v_empleados,
    'blockers', '[]'::jsonb,
    'warnings', v_advertencias,
    'reason', null
  );
end
$$;

create or replace function public.calcular_nomina(p_periodo uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.nomina_empresa_autorizada('nomina.generar');
  v_p public.nomina_periodos%rowtype;
  v_n public.nominas%rowtype;
  v_version integer;
  v_row record;
  v_calc jsonb;
  v_detail uuid;
  v_items jsonb;
  v_afp numeric;
  v_sfs numeric;
  v_tax numeric;
  v_loan numeric;
  v_credit numeric;
  v_fixed numeric;
  v_break numeric;
  v_other numeric;
  v_applied numeric;
  v_pending numeric;
  v_summary jsonb;
begin
  select *
  into v_p
  from public.nomina_periodos
  where empresa_id = v_empresa
    and id = p_periodo
  for update;
  if not found then
    raise exception 'PERIODO_NO_ENCONTRADO';
  end if;

  select *
  into v_n
  from public.nominas
  where empresa_id = v_empresa
    and periodo_id = p_periodo
  for update;
  if not found then
    raise exception 'NOMINA_NO_ENCONTRADA';
  end if;

  if v_p.estado in ('CERRADA', 'ANULADA')
    or (v_p.estado = 'APROBADA' and not v_n.desactualizada) then
    raise exception 'PERIODO_NO_RECALCULABLE';
  end if;
  if exists (
    select 1
    from public.jornadas j
    where j.empresa_id = v_empresa
      and j.fecha_laboral between v_p.fecha_inicio and v_p.fecha_fin
      and j.revision_pendiente
  ) then
    raise exception 'JORNADAS_PENDIENTES';
  end if;
  if exists (
    select 1
    from public.jornada_conflictos c
    join public.jornadas j
      on j.empresa_id = c.empresa_id
     and j.id = c.jornada_id
    where c.empresa_id = v_empresa
      and j.fecha_laboral between v_p.fecha_inicio and v_p.fecha_fin
      and c.estado = 'PENDIENTE'
  ) then
    raise exception 'CONFLICTOS_PENDIENTES';
  end if;
  if exists (
    select 1
    from public.empleados e
    left join public.nomina_reglas_empleado r
      on r.empresa_id = e.empresa_id
     and r.empleado_id = e.id
    where e.empresa_id = v_empresa
      and e.activo
      and (
        coalesce(e.salario, 0) <= 0
        or e.tipo_pago not in ('mensual', 'quincenal')
        or r.id is null
        or not r.nomina_activa
        or coalesce(r.dias_divisor_quincenal, 0) <= 0
        or coalesce(r.horas_dia, 0) <= 0
      )
  ) then
    raise exception 'EMPLEADOS_SIN_CONFIGURACION_SALARIAL';
  end if;

  v_version := v_n.version_calculo + 1;
  delete from public.nomina_descuentos
  where empresa_id = v_empresa
    and nomina_id = v_n.id
    and not aplicado;
  delete from public.nomina_detalles
  where empresa_id = v_empresa
    and nomina_id = v_n.id;

  for v_row in
    select e.id, e.codigo_empleado, r.horas_dia
    from public.empleados e
    join public.nomina_reglas_empleado r
      on r.empresa_id = e.empresa_id
     and r.empleado_id = e.id
     and r.nomina_activa
    where e.empresa_id = v_empresa
      and e.activo
      and coalesce(e.fecha_ingreso, v_p.fecha_fin) <= v_p.fecha_fin
    order by e.codigo_empleado
  loop
    v_calc := public.nomina_calculo_empleado_v3(
      v_empresa,
      v_row.id,
      v_p.fecha_inicio,
      v_p.fecha_fin,
      v_p.tipo_periodo,
      p_periodo
    );
    v_items := v_calc -> 'deduction_items';
    v_afp := coalesce((v_calc #>> '{deductions,afp,applied}')::numeric, 0);
    v_sfs := coalesce((v_calc #>> '{deductions,sfs,applied}')::numeric, 0);
    v_tax := coalesce((v_calc #>> '{deductions,other_taxes,applied}')::numeric, 0);
    v_loan := coalesce((v_calc #>> '{deductions,loans,applied}')::numeric, 0);
    v_credit := coalesce((v_calc #>> '{deductions,credits,applied}')::numeric, 0);
    v_break := coalesce((v_calc #>> '{deductions,breakage,applied}')::numeric, 0);
    v_applied := coalesce((v_calc #>> '{deductions,applied}')::numeric, 0);
    v_pending := coalesce((v_calc #>> '{deductions,pending}')::numeric, 0);

    select
      coalesce(sum((x.value ->> 'applied')::numeric) filter (
        where x.value ->> 'concept' = 'FIXED'
      ), 0),
      coalesce(sum((x.value ->> 'applied')::numeric) filter (
        where x.value ->> 'type' = 'OTRO_DESCUENTO'
          and x.value ->> 'concept' <> 'FIXED'
      ), 0)
    into v_fixed, v_other
    from jsonb_array_elements(v_items) x(value);

    insert into public.nomina_detalles(
      empresa_id, nomina_id, empleado_id, codigo_empleado, nombre_empleado,
      tipo_pago, sueldo_base, dias_trabajados, horas_normales, horas_extras,
      horas_nocturnas, valor_hora, total_horas_extras, total_nocturnas,
      incentivos, afp, sfs, otros_impuestos, total_impuestos,
      descuento_prestamo, descuento_credito, rotura_falta, otros_descuentos,
      total_descuentos, bruto, neto, version_calculo, formula, entradas,
      resultados, pago_normal, valor_hora_extra, descuento_fijo
    )
    values(
      v_empresa,
      v_n.id,
      v_row.id,
      v_calc ->> 'employee_code',
      v_calc ->> 'employee_name',
      v_calc ->> 'pay_type',
      (v_calc ->> 'salary')::numeric,
      round((v_calc ->> 'normal_minutes')::numeric / (v_row.horas_dia * 60), 2),
      (v_calc ->> 'normal_hours')::numeric,
      (v_calc ->> 'overtime_hours')::numeric,
      0,
      (v_calc ->> 'hourly_rate')::numeric,
      (v_calc ->> 'overtime_pay')::numeric,
      0,
      (v_calc ->> 'incentive')::numeric,
      v_afp,
      v_sfs,
      v_tax,
      round(v_afp + v_sfs + v_tax, 2),
      v_loan,
      v_credit,
      v_break,
      v_other,
      v_applied,
      (v_calc ->> 'gross')::numeric,
      (v_calc ->> 'net')::numeric,
      v_version,
      'RC4_WORKED_MINUTES_V3_NET_FLOOR',
      jsonb_build_object(
        'salary', (v_calc ->> 'salary')::numeric,
        'normal_minutes', (v_calc ->> 'normal_minutes')::numeric,
        'overtime_minutes', (v_calc ->> 'overtime_minutes')::numeric,
        'hourly_rate', (v_calc ->> 'hourly_rate')::numeric
      ),
      jsonb_build_object(
        'normal_pay', (v_calc ->> 'normal_pay')::numeric,
        'overtime_pay', (v_calc ->> 'overtime_pay')::numeric,
        'gross', (v_calc ->> 'gross')::numeric,
        'deductions', v_calc -> 'deductions',
        'deduction_items', v_items,
        'net', (v_calc ->> 'net')::numeric
      ),
      (v_calc ->> 'normal_pay')::numeric,
      case
        when (v_calc ->> 'overtime_minutes')::numeric > 0
          then round((v_calc ->> 'overtime_pay')::numeric / ((v_calc ->> 'overtime_minutes')::numeric / 60), 4)
        else 0
      end,
      v_fixed
    )
    returning id into v_detail;

    insert into public.nomina_descuentos(
      empresa_id, nomina_id, detalle_id, empleado_id,
      prestamo_id, credito_id, ajuste_id,
      tipo, monto, origen, monto_solicitado, monto_pendiente, metadata
    )
    select
      v_empresa,
      v_n.id,
      v_detail,
      v_row.id,
      case when x.value ->> 'source_kind' = 'LOAN' then (x.value ->> 'source_id')::uuid end,
      case when x.value ->> 'source_kind' = 'CREDIT' then (x.value ->> 'source_id')::uuid end,
      case when x.value ->> 'source_kind' = 'ADJUSTMENT' then (x.value ->> 'source_id')::uuid end,
      x.value ->> 'type',
      (x.value ->> 'applied')::numeric,
      coalesce(x.value ->> 'origin', 'MOTOR'),
      (x.value ->> 'requested')::numeric,
      (x.value ->> 'pending')::numeric,
      x.value - 'applied' - 'pending' - 'requested'
    from jsonb_array_elements(v_items) x(value)
    where (x.value ->> 'requested')::numeric > 0;

    if (v_calc ->> 'net')::numeric < 0
      or v_applied > (v_calc ->> 'gross')::numeric
      or round((v_calc ->> 'net')::numeric + v_applied, 2) <> (v_calc ->> 'gross')::numeric then
      raise exception 'PAYROLL_V3_INVARIANT_FAILED:%', v_row.codigo_empleado;
    end if;
  end loop;

  select jsonb_build_object(
    'employees', count(*),
    'total_salaries', coalesce(sum(pago_normal), 0),
    'total_overtime', coalesce(sum(total_horas_extras), 0),
    'total_incentives', coalesce(sum(incentivos), 0),
    'total_loans_applied', coalesce(sum(descuento_prestamo), 0),
    'total_credits_applied', coalesce(sum(descuento_credito), 0),
    'total_taxes_applied', coalesce(sum(total_impuestos), 0),
    'total_deductions_applied', coalesce(sum(total_descuentos), 0),
    'total_deductions_pending', coalesce(sum((resultados #>> '{deductions,pending}')::numeric), 0),
    'total_general_pagado', coalesce(sum(neto), 0)
  )
  into v_summary
  from public.nomina_detalles
  where empresa_id = v_empresa
    and nomina_id = v_n.id;

  update public.nominas
  set estado = 'CALCULADA',
      version_calculo = v_version,
      motor_version = 3,
      formula = 'RC4_WORKED_MINUTES_V3_NET_FLOOR',
      desactualizada = false,
      errores = '[]'::jsonb,
      resumen = v_summary,
      calculada_en = now(),
      actualizada_en = now(),
      jornadas_actualizadas_hasta = (
        select max(j.actualizada_en)
        from public.jornadas j
        where j.empresa_id = v_empresa
          and j.fecha_laboral between v_p.fecha_inicio and v_p.fecha_fin
      )
  where id = v_n.id;

  update public.nomina_periodos
  set estado = 'CALCULADA', calculada_en = now()
  where id = p_periodo;

  insert into public.nomina_auditoria(
    empresa_id, periodo_id, nomina_id, actor_id, accion, despues
  )
  values(
    v_empresa,
    p_periodo,
    v_n.id,
    auth.uid(),
    case when v_version = 1 then 'CALCULAR' else 'RECALCULAR' end,
    jsonb_build_object(
      'version', v_version,
      'formula', 'RC4_WORKED_MINUTES_V3_NET_FLOOR',
      'net_floor', true,
      'summary', v_summary
    )
  );

  return jsonb_build_object(
    'period_id', p_periodo,
    'payroll_id', v_n.id,
    'version', v_version,
    'formula', 'RC4_WORKED_MINUTES_V3_NET_FLOOR',
    'summary', v_summary
  );
end
$$;


create or replace function public.nomina_calculo_empleado_v3(
  p_empresa uuid,
  p_empleado uuid,
  p_inicio date,
  p_fin date,
  p_tipo_periodo text,
  p_periodo uuid default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_row record;
  v_factor integer := case when p_tipo_periodo = 'MENSUAL' then 2 else 1 end;
  v_jornadas integer := 0;
  v_minutos_normales numeric := 0;
  v_minutos_extra numeric := 0;
  v_valor_dia numeric;
  v_valor_hora numeric;
  v_pago_normal numeric;
  v_pago_extra numeric;
  v_incentivo numeric := 0;
  v_bruto numeric;
  v_prev_nomina uuid;
  v_current numeric;
  v_carry numeric;
  v_requests jsonb := '[]'::jsonb;
  v_distribution jsonb;
  v_deductions jsonb;
  v_record record;
  v_sequence integer := 0;
begin
  select
    e.id,
    e.codigo_empleado,
    e.nombre_completo,
    e.salario,
    e.tipo_pago,
    r.dias_divisor_quincenal divisor,
    r.horas_dia,
    r.valor_hora_extra,
    r.afp_modo,
    r.afp_valor,
    r.sfs_modo,
    r.sfs_valor,
    r.otros_impuestos_modo,
    r.otros_impuestos_valor,
    r.incentivo_periodo,
    r.descuento_fijo_quincenal,
    r.descuento_fijo_activo,
    r.otros_descuentos_fijos
  into v_row
  from public.empleados e
  join public.nomina_reglas_empleado r
    on r.empresa_id = e.empresa_id
   and r.empleado_id = e.id
   and r.nomina_activa
  where e.empresa_id = p_empresa
    and e.id = p_empleado
    and e.activo;

  if not found
    or coalesce(v_row.salario, 0) <= 0
    or coalesce(v_row.divisor, 0) <= 0
    or coalesce(v_row.horas_dia, 0) <= 0 then
    raise exception 'PAYROLL_EMPLOYEE_CONFIGURATION_INVALID:%', p_empleado;
  end if;

  select
    count(*)::integer,
    coalesce(sum(least(coalesce(j.minutos_trabajados, 0), (v_row.horas_dia * 60)::integer)), 0),
    coalesce(sum(greatest(coalesce(j.minutos_trabajados, 0) - (v_row.horas_dia * 60)::integer, 0)), 0)
  into v_jornadas, v_minutos_normales, v_minutos_extra
  from public.jornadas j
  where j.empresa_id = p_empresa
    and j.empleado_id = p_empleado
    and j.fecha_laboral between p_inicio and p_fin
    and j.estado = 'FINALIZADA'
    and not j.revision_pendiente
    and not exists (
      select 1
      from public.jornada_conflictos c
      where c.empresa_id = j.empresa_id
        and c.jornada_id = j.id
        and c.estado = 'PENDIENTE'
    );

  v_valor_dia := v_row.salario / v_row.divisor;
  v_valor_hora := round(v_valor_dia / v_row.horas_dia, 4);
  v_pago_normal := round(v_minutos_normales / 60 * v_valor_hora, 2);
  v_pago_extra := round(v_minutos_extra / 60 * coalesce(v_row.valor_hora_extra, 0), 2);

  if p_periodo is not null then
    select coalesce(sum(a.monto), 0)
    into v_incentivo
    from public.nomina_ajustes a
    where a.empresa_id = p_empresa
      and a.periodo_id = p_periodo
      and a.empleado_id = p_empleado
      and a.tipo = 'INCENTIVO'
      and a.activo;
  end if;

  v_incentivo := round(v_incentivo + coalesce(v_row.incentivo_periodo, 0) * v_factor, 2);
  v_bruto := round(v_pago_normal + v_pago_extra + v_incentivo, 2);

  select n.id
  into v_prev_nomina
  from public.nomina_periodos p
  join public.nominas n
    on n.empresa_id = p.empresa_id
   and n.periodo_id = p.id
   and n.estado = 'CERRADA'
  join public.nomina_detalles d
    on d.empresa_id = n.empresa_id
   and d.nomina_id = n.id
   and d.empleado_id = p_empleado
  where p.empresa_id = p_empresa
    and p.estado = 'CERRADA'
    and p.fecha_fin < p_inicio
  order by p.fecha_fin desc, p.cerrada_en desc nulls last
  limit 1;

  -- AFP y SFS son obligatorios, pero un MONTO se prorratea por la fraccion
  -- realmente trabajada del periodo. Cualquier faltante anterior se conserva.
  v_current := public.nomina_prorratear_obligacion_v3(
    v_row.afp_modo, v_row.afp_valor, v_bruto, v_factor,
    v_minutos_normales, v_row.divisor, v_row.horas_dia
  );
  select coalesce(sum(d.monto_pendiente), 0)
  into v_carry
  from public.nomina_descuentos d
  where d.empresa_id = p_empresa
    and d.nomina_id = v_prev_nomina
    and d.empleado_id = p_empleado
    and d.tipo = 'AFP';
  v_requests := v_requests || jsonb_build_array(jsonb_build_object(
    'priority', 10, 'sequence', 10, 'type', 'AFP', 'concept', 'AFP',
    'source_kind', 'CONFIG', 'origin', 'MOTOR',
    'current_requested', v_current, 'carry_in', v_carry,
    'requested', round(v_current + v_carry, 2)
  ));

  v_current := public.nomina_prorratear_obligacion_v3(
    v_row.sfs_modo, v_row.sfs_valor, v_bruto, v_factor,
    v_minutos_normales, v_row.divisor, v_row.horas_dia
  );
  select coalesce(sum(d.monto_pendiente), 0)
  into v_carry
  from public.nomina_descuentos d
  where d.empresa_id = p_empresa
    and d.nomina_id = v_prev_nomina
    and d.empleado_id = p_empleado
    and d.tipo = 'SFS';
  v_requests := v_requests || jsonb_build_array(jsonb_build_object(
    'priority', 20, 'sequence', 20, 'type', 'SFS', 'concept', 'SFS',
    'source_kind', 'CONFIG', 'origin', 'MOTOR',
    'current_requested', v_current, 'carry_in', v_carry,
    'requested', round(v_current + v_carry, 2)
  ));

  v_current := round(
    case
      when coalesce(v_row.otros_impuestos_modo, 'MONTO') = 'PORCENTAJE'
        then v_bruto * greatest(coalesce(v_row.otros_impuestos_valor, 0), 0) / 100
      else greatest(coalesce(v_row.otros_impuestos_valor, 0), 0) * v_factor
    end,
    2
  );
  select coalesce(sum(d.monto_pendiente), 0)
  into v_carry
  from public.nomina_descuentos d
  where d.empresa_id = p_empresa
    and d.nomina_id = v_prev_nomina
    and d.empleado_id = p_empleado
    and d.tipo = 'OTRO_IMPUESTO';
  v_requests := v_requests || jsonb_build_array(jsonb_build_object(
    'priority', 30, 'sequence', 30, 'type', 'OTRO_IMPUESTO', 'concept', 'OTHER_TAX',
    'source_kind', 'CONFIG', 'origin', 'MOTOR',
    'current_requested', v_current, 'carry_in', v_carry,
    'requested', round(v_current + v_carry, 2)
  ));

  v_current := case
    when v_row.descuento_fijo_activo
      then round(coalesce(v_row.descuento_fijo_quincenal, 0) * v_factor, 2)
    else 0
  end;
  select coalesce(sum(d.monto_pendiente), 0)
  into v_carry
  from public.nomina_descuentos d
  where d.empresa_id = p_empresa
    and d.nomina_id = v_prev_nomina
    and d.empleado_id = p_empleado
    and d.tipo = 'OTRO_DESCUENTO'
    and d.metadata ->> 'concept' = 'FIXED';
  v_requests := v_requests || jsonb_build_array(jsonb_build_object(
    'priority', 40, 'sequence', 40, 'type', 'OTRO_DESCUENTO', 'concept', 'FIXED',
    'source_kind', 'CONFIG', 'origin', 'MOTOR',
    'current_requested', v_current, 'carry_in', v_carry,
    'requested', round(v_current + v_carry, 2)
  ));

  v_current := round(coalesce(v_row.otros_descuentos_fijos, 0) * v_factor, 2);
  select coalesce(sum(d.monto_pendiente), 0)
  into v_carry
  from public.nomina_descuentos d
  where d.empresa_id = p_empresa
    and d.nomina_id = v_prev_nomina
    and d.empleado_id = p_empleado
    and d.tipo = 'OTRO_DESCUENTO'
    and d.metadata ->> 'concept' = 'OTHER_FIXED';
  v_requests := v_requests || jsonb_build_array(jsonb_build_object(
    'priority', 41, 'sequence', 41, 'type', 'OTRO_DESCUENTO', 'concept', 'OTHER_FIXED',
    'source_kind', 'CONFIG', 'origin', 'MOTOR',
    'current_requested', v_current, 'carry_in', v_carry,
    'requested', round(v_current + v_carry, 2)
  ));

  -- Arrastres de ajustes anteriores: primero se consume la deuda mas antigua.
  for v_record in
    select d.ajuste_id, d.tipo, d.origen, d.monto_pendiente,
           coalesce(d.metadata ->> 'concept', 'ADJUSTMENT_OTHER') concept,
           d.creado_en
    from public.nomina_descuentos d
    where d.empresa_id = p_empresa
      and d.nomina_id = v_prev_nomina
      and d.empleado_id = p_empleado
      and d.ajuste_id is not null
      and d.monto_pendiente > 0
    order by d.creado_en, d.id
  loop
    v_sequence := v_sequence + 1;
    v_requests := v_requests || jsonb_build_array(jsonb_build_object(
      'priority', case
        when v_record.tipo = 'ROTUR/FALT' then 50
        when v_record.tipo = 'OTRO_DESCUENTO' then 60
        when v_record.tipo = 'DESCU-PRES' then 80
        else 90
      end,
      'sequence', v_sequence,
      'type', v_record.tipo,
      'concept', v_record.concept,
      'source_kind', 'ADJUSTMENT',
      'source_id', v_record.ajuste_id,
      'origin', v_record.origen,
      'current_requested', 0,
      'carry_in', v_record.monto_pendiente,
      'requested', v_record.monto_pendiente
    ));
  end loop;

  if p_periodo is not null then
    for v_record in
      select a.id, a.tipo, a.monto, a.origen, a.creado_en
      from public.nomina_ajustes a
      where a.empresa_id = p_empresa
        and a.periodo_id = p_periodo
        and a.empleado_id = p_empleado
        and a.activo
        and a.tipo <> 'INCENTIVO'
      order by a.creado_en, a.id
    loop
      v_sequence := v_sequence + 1;
      v_requests := v_requests || jsonb_build_array(jsonb_build_object(
        'priority', case
          when v_record.tipo = 'ROTUR/FALT' then 51
          when v_record.tipo = 'OTRO_DESCUENTO' then 61
          when v_record.tipo = 'DESCU-PRES' then 81
          else 91
        end,
        'sequence', v_sequence,
        'type', v_record.tipo,
        'concept', case
          when v_record.tipo = 'ROTUR/FALT' then 'ADJUSTMENT_BREAK'
          when v_record.tipo = 'OTRO_DESCUENTO' then 'ADJUSTMENT_OTHER'
          when v_record.tipo = 'DESCU-PRES' then 'ADJUSTMENT_LOAN'
          else 'ADJUSTMENT_CREDIT'
        end,
        'source_kind', 'ADJUSTMENT',
        'source_id', v_record.id,
        'origin', v_record.origen,
        'current_requested', v_record.monto,
        'carry_in', 0,
        'requested', v_record.monto
      ));
    end loop;
  end if;

  for v_record in
    select
      p.id,
      p.pendiente,
      least(
        p.pendiente,
        p.descuento_periodo * v_factor
        + coalesce((
            select sum(d.monto_pendiente)
            from public.nomina_descuentos d
            where d.empresa_id = p_empresa
              and d.nomina_id = v_prev_nomina
              and d.empleado_id = p_empleado
              and d.prestamo_id = p.id
          ), 0)
      ) requested,
      coalesce((
        select sum(d.monto_pendiente)
        from public.nomina_descuentos d
        where d.empresa_id = p_empresa
          and d.nomina_id = v_prev_nomina
          and d.empleado_id = p_empleado
          and d.prestamo_id = p.id
      ), 0) carry_in,
      p.creado_en
    from public.nomina_prestamos p
    where p.empresa_id = p_empresa
      and p.empleado_id = p_empleado
      and p.estado = 'ENTREGADO'
      and p.pendiente > 0
    order by p.creado_en, p.id
  loop
    v_sequence := v_sequence + 1;
    v_requests := v_requests || jsonb_build_array(jsonb_build_object(
      'priority', 80, 'sequence', v_sequence,
      'type', 'DESCU-PRES', 'concept', 'LOAN',
      'source_kind', 'LOAN', 'source_id', v_record.id,
      'origin', 'MOTOR',
      'current_requested', round(v_record.requested - v_record.carry_in, 2),
      'carry_in', round(v_record.carry_in, 2),
      'requested', round(v_record.requested, 2)
    ));
  end loop;

  for v_record in
    select
      c.id,
      c.pendiente,
      least(
        c.pendiente,
        c.descuento_periodo * v_factor
        + coalesce((
            select sum(d.monto_pendiente)
            from public.nomina_descuentos d
            where d.empresa_id = p_empresa
              and d.nomina_id = v_prev_nomina
              and d.empleado_id = p_empleado
              and d.credito_id = c.id
          ), 0)
      ) requested,
      coalesce((
        select sum(d.monto_pendiente)
        from public.nomina_descuentos d
        where d.empresa_id = p_empresa
          and d.nomina_id = v_prev_nomina
          and d.empleado_id = p_empleado
          and d.credito_id = c.id
      ), 0) carry_in,
      c.creado_en
    from public.nomina_creditos c
    where c.empresa_id = p_empresa
      and c.empleado_id = p_empleado
      and c.estado = 'ACTIVO'
      and c.pendiente > 0
    order by c.creado_en, c.id
  loop
    v_sequence := v_sequence + 1;
    v_requests := v_requests || jsonb_build_array(jsonb_build_object(
      'priority', 90, 'sequence', v_sequence,
      'type', 'DESCU-CRED', 'concept', 'CREDIT',
      'source_kind', 'CREDIT', 'source_id', v_record.id,
      'origin', 'MOTOR',
      'current_requested', round(v_record.requested - v_record.carry_in, 2),
      'carry_in', round(v_record.carry_in, 2),
      'requested', round(v_record.requested, 2)
    ));
  end loop;

  v_distribution := public.nomina_distribuir_descuentos_v3(v_bruto, v_requests);

  select jsonb_build_object(
    'requested', coalesce(sum((x.value ->> 'requested')::numeric), 0),
    'applied', coalesce(sum((x.value ->> 'applied')::numeric), 0),
    'pending', coalesce(sum((x.value ->> 'pending')::numeric), 0),
    'afp', jsonb_build_object(
      'requested', coalesce(sum((x.value ->> 'requested')::numeric) filter (where x.value ->> 'type' = 'AFP'), 0),
      'applied', coalesce(sum((x.value ->> 'applied')::numeric) filter (where x.value ->> 'type' = 'AFP'), 0),
      'pending', coalesce(sum((x.value ->> 'pending')::numeric) filter (where x.value ->> 'type' = 'AFP'), 0)
    ),
    'sfs', jsonb_build_object(
      'requested', coalesce(sum((x.value ->> 'requested')::numeric) filter (where x.value ->> 'type' = 'SFS'), 0),
      'applied', coalesce(sum((x.value ->> 'applied')::numeric) filter (where x.value ->> 'type' = 'SFS'), 0),
      'pending', coalesce(sum((x.value ->> 'pending')::numeric) filter (where x.value ->> 'type' = 'SFS'), 0)
    ),
    'other_taxes', jsonb_build_object(
      'requested', coalesce(sum((x.value ->> 'requested')::numeric) filter (where x.value ->> 'type' = 'OTRO_IMPUESTO'), 0),
      'applied', coalesce(sum((x.value ->> 'applied')::numeric) filter (where x.value ->> 'type' = 'OTRO_IMPUESTO'), 0),
      'pending', coalesce(sum((x.value ->> 'pending')::numeric) filter (where x.value ->> 'type' = 'OTRO_IMPUESTO'), 0)
    ),
    'loans', jsonb_build_object(
      'requested', coalesce(sum((x.value ->> 'requested')::numeric) filter (where x.value ->> 'type' = 'DESCU-PRES'), 0),
      'applied', coalesce(sum((x.value ->> 'applied')::numeric) filter (where x.value ->> 'type' = 'DESCU-PRES'), 0),
      'pending', coalesce(sum((x.value ->> 'pending')::numeric) filter (where x.value ->> 'type' = 'DESCU-PRES'), 0)
    ),
    'credits', jsonb_build_object(
      'requested', coalesce(sum((x.value ->> 'requested')::numeric) filter (where x.value ->> 'type' = 'DESCU-CRED'), 0),
      'applied', coalesce(sum((x.value ->> 'applied')::numeric) filter (where x.value ->> 'type' = 'DESCU-CRED'), 0),
      'pending', coalesce(sum((x.value ->> 'pending')::numeric) filter (where x.value ->> 'type' = 'DESCU-CRED'), 0)
    ),
    'breakage', jsonb_build_object(
      'requested', coalesce(sum((x.value ->> 'requested')::numeric) filter (where x.value ->> 'type' = 'ROTUR/FALT'), 0),
      'applied', coalesce(sum((x.value ->> 'applied')::numeric) filter (where x.value ->> 'type' = 'ROTUR/FALT'), 0),
      'pending', coalesce(sum((x.value ->> 'pending')::numeric) filter (where x.value ->> 'type' = 'ROTUR/FALT'), 0)
    ),
    'other_discounts', jsonb_build_object(
      'requested', coalesce(sum((x.value ->> 'requested')::numeric) filter (where x.value ->> 'type' = 'OTRO_DESCUENTO'), 0),
      'applied', coalesce(sum((x.value ->> 'applied')::numeric) filter (where x.value ->> 'type' = 'OTRO_DESCUENTO'), 0),
      'pending', coalesce(sum((x.value ->> 'pending')::numeric) filter (where x.value ->> 'type' = 'OTRO_DESCUENTO'), 0)
    )
  )
  into v_deductions
  from jsonb_array_elements(v_distribution -> 'items') x(value);

  return jsonb_build_object(
    'employee_id', v_row.id,
    'employee_code', v_row.codigo_empleado,
    'employee_name', v_row.nombre_completo,
    'pay_type', v_row.tipo_pago,
    'salary', v_row.salario,
    'journeys', v_jornadas,
    'normal_minutes', v_minutos_normales,
    'overtime_minutes', v_minutos_extra,
    'normal_hours', round(v_minutos_normales / 60, 2),
    'overtime_hours', round(v_minutos_extra / 60, 2),
    'daily_rate', round(v_valor_dia, 4),
    'hourly_rate', v_valor_hora,
    'normal_pay', v_pago_normal,
    'overtime_pay', v_pago_extra,
    'incentive', v_incentivo,
    'gross', v_bruto,
    'deductions', v_deductions,
    'deduction_items', v_distribution -> 'items',
    'net', (v_distribution ->> 'net')::numeric,
    'formula', 'RC4_WORKED_MINUTES_V3_NET_FLOOR'
  );
end
$$;

-- Resolucion conservadora: no modifica la jornada ni su version. Solo admite
-- conflictos VERSION_CONFLICT cuya operacion no fue aplicada y cuyo snapshot
-- remoto ya fue superado por eventos validos posteriores.
create or replace function public.resolver_conflicto_jornada_remoto_superado(
  p_conflicto uuid,
  p_motivo text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.obtener_empresa_actual();
  v_conflicto public.jornada_conflictos%rowtype;
  v_jornada public.jornadas%rowtype;
  v_antes jsonb;
  v_snapshot_version integer;
  v_incidencias integer := 0;
begin
  if v_empresa is null
    or not public.tiene_permiso('jornadas.aprobar_pendientes') then
    raise exception using errcode = '42501', message = 'JOURNEY_CONFLICT_RESOLUTION_DENIED';
  end if;
  if btrim(coalesce(p_motivo, '')) = '' then
    raise exception 'MOTIVO_REQUERIDO';
  end if;

  select *
  into v_conflicto
  from public.jornada_conflictos c
  where c.empresa_id = v_empresa
    and c.id = p_conflicto
  for update;

  if not found then
    raise exception 'CONFLICTO_NO_ENCONTRADO';
  end if;
  if v_conflicto.estado <> 'PENDIENTE' then
    return jsonb_build_object(
      'conflict_id', v_conflicto.id,
      'journey_id', v_conflicto.jornada_id,
      'status', v_conflicto.estado,
      'already_resolved', true
    );
  end if;
  if v_conflicto.motivo <> 'VERSION_CONFLICT' then
    raise exception 'CONFLICTO_NO_ES_DE_VERSION';
  end if;

  select *
  into v_jornada
  from public.jornadas j
  where j.empresa_id = v_empresa
    and j.id = v_conflicto.jornada_id
  for share;

  if not found then
    raise exception 'JORNADA_NO_ENCONTRADA';
  end if;

  if v_conflicto.operacion_idempotency_key is not null
    and exists (
      select 1
      from public.jornada_eventos e
      where e.empresa_id = v_empresa
        and e.idempotency_key = v_conflicto.operacion_idempotency_key
    ) then
    raise exception 'OPERACION_CONFLICTIVA_YA_FUE_APLICADA';
  end if;

  v_snapshot_version := coalesce((v_conflicto.snapshot_remoto ->> 'version_sync')::integer, -1);
  if v_jornada.version_sync <= v_snapshot_version
    or not exists (
      select 1
      from public.jornada_eventos e
      where e.empresa_id = v_empresa
        and e.jornada_id = v_jornada.id
        and e.creado_en > v_conflicto.creado_en
    ) then
    raise exception 'CONFLICTO_NO_SUPERADO';
  end if;

  v_antes := jsonb_build_object(
    'journey', to_jsonb(v_jornada),
    'conflict', to_jsonb(v_conflicto)
  );

  update public.jornada_conflictos
  set estado = 'RESUELTO_REMOTO',
      resuelto_en = now(),
      resuelto_por = auth.uid()
  where empresa_id = v_empresa
    and id = v_conflicto.id
    and estado = 'PENDIENTE'
  returning * into v_conflicto;

  if not exists (
    select 1
    from public.jornada_conflictos c
    where c.empresa_id = v_empresa
      and c.jornada_id = v_jornada.id
      and c.estado = 'PENDIENTE'
  ) then
    update public.jornada_incidencias
    set resuelta = true,
        resuelta_en = now(),
        resuelta_por = auth.uid()
    where empresa_id = v_empresa
      and jornada_id = v_jornada.id
      and tipo = 'CONFLICTO'
      and not resuelta;
    get diagnostics v_incidencias = row_count;
  end if;

  insert into public.jornada_auditoria(
    empresa_id, jornada_id, actor_id, accion, antes, despues, origen
  )
  values(
    v_empresa,
    v_jornada.id,
    auth.uid(),
    'RESOLVER_CONFLICTO_REMOTO',
    v_antes,
    jsonb_build_object(
      'journey', to_jsonb(v_jornada),
      'conflict', to_jsonb(v_conflicto),
      'reason', btrim(p_motivo),
      'evidence', jsonb_build_object(
        'operation_not_applied', true,
        'snapshot_version', v_snapshot_version,
        'current_version', v_jornada.version_sync,
        'later_event_present', true
      )
    ),
    'SISTEMA'
  );

  return jsonb_build_object(
    'conflict_id', v_conflicto.id,
    'journey_id', v_jornada.id,
    'status', v_conflicto.estado,
    'journey_state', v_jornada.estado,
    'journey_version', v_jornada.version_sync,
    'incidents_resolved', v_incidencias,
    'journey_unchanged', true
  );
end
$$;

revoke all on function public.nomina_prorratear_obligacion_v3(text,numeric,numeric,integer,numeric,numeric,numeric)
  from public, anon, authenticated;
revoke all on function public.nomina_distribuir_descuentos_v3(numeric,jsonb)
  from public, anon, authenticated;
revoke all on function public.nomina_calculo_empleado_v3(uuid,uuid,date,date,text,uuid)
  from public, anon, authenticated;

revoke all on function public.resolver_conflicto_jornada_remoto_superado(uuid,text)
  from public, anon;
grant execute on function public.resolver_conflicto_jornada_remoto_superado(uuid,text)
  to authenticated;

revoke all on function public.obtener_total_nomina_dashboard(date)
  from public, anon;
grant execute on function public.obtener_total_nomina_dashboard(date)
  to authenticated, service_role;

comment on function public.calcular_nomina(uuid) is
  'RC4 V3: minutos trabajados, AFP/SFS proporcionales, deducciones limitadas al bruto y remanentes diferidos.';
comment on function public.obtener_total_nomina_dashboard(date) is
  'Dashboard V3: snapshot cerrado o calculo REAL_TIME con neto no negativo y deducciones aplicadas/pendientes.';
comment on function public.resolver_conflicto_jornada_remoto_superado(uuid,text) is
  'Resuelve un VERSION_CONFLICT remoto obsoleto sin modificar la jornada ni sus eventos.';

commit;
