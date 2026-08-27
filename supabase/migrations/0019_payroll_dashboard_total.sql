begin;

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
  v_factor integer;
  v_row record;
  v_empleados jsonb := '[]'::jsonb;
  v_bloqueos jsonb := '[]'::jsonb;
  v_advertencias jsonb := '[]'::jsonb;
  v_empleados_incluidos integer := 0;
  v_jornadas_empleado integer;
  v_jornadas_usadas integer := 0;
  v_minutos_normales numeric;
  v_minutos_extra numeric;
  v_minutos_totales numeric := 0;
  v_horas_cerradas numeric := 0;
  v_valor_dia numeric;
  v_valor_hora numeric;
  v_pago_normal numeric;
  v_pago_extra numeric;
  v_incentivo numeric;
  v_afp numeric;
  v_sfs numeric;
  v_impuestos numeric;
  v_prestamos numeric;
  v_creditos numeric;
  v_descuento_fijo numeric;
  v_rotura_falta numeric;
  v_otros_descuentos numeric;
  v_bruto numeric;
  v_descuentos numeric;
  v_neto numeric;
  v_total numeric := 0;
begin
  -- Una nómina cerrada es contabilidad histórica: nunca se vuelve a estimar.
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
        'reason', 'La nómina cerrada no contiene un total almacenado válido.'
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

  -- Usa el período que contiene la fecha o deriva la quincena sin crear filas.
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

  v_factor := case when v_tipo_periodo = 'MENSUAL' then 2 else 1 end;

  -- RC4 no permite calcular mientras haya jornadas finalizadas sin confirmar.
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
        when j.revision_pendiente then 'La jornada está pendiente de revisión y bloquea el cálculo de nómina.'
        else 'La jornada tiene un conflicto pendiente y bloquea el cálculo de nómina.'
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
      r.valor_hora_extra,
      r.afp_valor,
      r.sfs_valor,
      r.otros_impuestos_valor,
      r.incentivo_periodo,
      r.descuento_fijo_quincenal,
      r.descuento_fijo_activo,
      r.otros_descuentos_fijos,
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
        'message', 'Falta la ficha de pago y nómina del empleado.'
      ));
      continue;
    end if;

    if not v_row.nomina_activa then
      v_bloqueos := v_bloqueos || jsonb_build_array(jsonb_build_object(
        'employee_id', v_row.id,
        'employee_code', v_row.codigo_empleado,
        'employee_name', v_row.nombre_completo,
        'reason', 'NOMINA_INACTIVA',
        'message', 'La ficha de nómina del empleado está desactivada.'
      ));
      continue;
    end if;

    if coalesce(v_row.salario, 0) <= 0 then
      v_bloqueos := v_bloqueos || jsonb_build_array(jsonb_build_object(
        'employee_id', v_row.id,
        'employee_code', v_row.codigo_empleado,
        'employee_name', v_row.nombre_completo,
        'reason', 'SALARIO_FALTANTE',
        'message', 'El salario mensual no está registrado o no es mayor que cero.'
      ));
      continue;
    end if;

    if v_row.tipo_pago is null or v_row.tipo_pago not in ('mensual', 'quincenal') then
      v_bloqueos := v_bloqueos || jsonb_build_array(jsonb_build_object(
        'employee_id', v_row.id,
        'employee_code', v_row.codigo_empleado,
        'employee_name', v_row.nombre_completo,
        'reason', 'TIPO_PAGO_FALTANTE',
        'message', 'El tipo de pago no está registrado o no es válido.'
      ));
      continue;
    end if;

    if coalesce(v_row.divisor, 0) <= 0 or coalesce(v_row.horas_dia, 0) <= 0 then
      v_bloqueos := v_bloqueos || jsonb_build_array(jsonb_build_object(
        'employee_id', v_row.id,
        'employee_code', v_row.codigo_empleado,
        'employee_name', v_row.nombre_completo,
        'reason', 'FICHA_PAGO_INVALIDA',
        'message', 'El divisor salarial o las horas diarias no son válidos.'
      ));
      continue;
    end if;

    select
      count(*)::integer,
      coalesce(sum(least(coalesce(j.minutos_trabajados, 0), (v_row.horas_dia * 60)::integer)), 0),
      coalesce(sum(greatest(coalesce(j.minutos_trabajados, 0) - (v_row.horas_dia * 60)::integer, 0)), 0)
      into v_jornadas_empleado, v_minutos_normales, v_minutos_extra
    from public.jornadas j
    where j.empresa_id = v_empresa
      and j.empleado_id = v_row.id
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

    v_valor_dia := v_row.salario / v_row.divisor;
    v_valor_hora := round(v_valor_dia / v_row.horas_dia, 4);
    v_pago_normal := round(v_minutos_normales / 60 * v_valor_hora, 2);
    v_pago_extra := round(v_minutos_extra / 60 * coalesce(v_row.valor_hora_extra, 0), 2);

    if v_periodo_id is null then
      v_incentivo := 0;
      v_rotura_falta := 0;
      v_otros_descuentos := 0;
    else
      select
        coalesce(sum(a.monto) filter (where a.tipo = 'INCENTIVO'), 0),
        coalesce(sum(a.monto) filter (where a.tipo = 'ROTUR/FALT'), 0),
        coalesce(sum(a.monto) filter (where a.tipo = 'OTRO_DESCUENTO'), 0)
        into v_incentivo, v_rotura_falta, v_otros_descuentos
      from public.nomina_ajustes a
      where a.empresa_id = v_empresa
        and a.periodo_id = v_periodo_id
        and a.empleado_id = v_row.id
        and a.activo;
    end if;

    v_incentivo := round(v_incentivo + coalesce(v_row.incentivo_periodo, 0) * v_factor, 2);
    v_afp := round(coalesce(v_row.afp_valor, 0) * v_factor, 2);
    v_sfs := round(coalesce(v_row.sfs_valor, 0) * v_factor, 2);
    v_impuestos := round(coalesce(v_row.otros_impuestos_valor, 0) * v_factor, 2);
    v_descuento_fijo := case
      when v_row.descuento_fijo_activo then round(coalesce(v_row.descuento_fijo_quincenal, 0) * v_factor, 2)
      else 0
    end;
    v_otros_descuentos := round(v_otros_descuentos + coalesce(v_row.otros_descuentos_fijos, 0) * v_factor, 2);

    select coalesce(sum(least(p.pendiente, p.descuento_periodo * v_factor)), 0)
      into v_prestamos
    from public.nomina_prestamos p
    where p.empresa_id = v_empresa
      and p.empleado_id = v_row.id
      and p.estado = 'ENTREGADO'
      and p.pendiente > 0;

    select coalesce(sum(least(c.pendiente, c.descuento_periodo * v_factor)), 0)
      into v_creditos
    from public.nomina_creditos c
    where c.empresa_id = v_empresa
      and c.empleado_id = v_row.id
      and c.estado = 'ACTIVO'
      and c.pendiente > 0;

    if v_periodo_id is not null then
      select v_prestamos + coalesce(sum(a.monto), 0)
        into v_prestamos
      from public.nomina_ajustes a
      where a.empresa_id = v_empresa
        and a.periodo_id = v_periodo_id
        and a.empleado_id = v_row.id
        and a.tipo = 'DESCU-PRES'
        and a.activo;

      select v_creditos + coalesce(sum(a.monto), 0)
        into v_creditos
      from public.nomina_ajustes a
      where a.empresa_id = v_empresa
        and a.periodo_id = v_periodo_id
        and a.empleado_id = v_row.id
        and a.tipo = 'DESCU-CRED'
        and a.activo;
    end if;

    v_bruto := round(v_pago_normal + v_pago_extra + v_incentivo, 2);
    v_descuentos := round(v_afp + v_sfs + v_impuestos + v_prestamos + v_creditos + v_descuento_fijo + v_rotura_falta + v_otros_descuentos, 2);
    v_neto := round(v_bruto - v_descuentos, 2);

    if v_neto < 0 then
      v_bloqueos := v_bloqueos || jsonb_build_array(jsonb_build_object(
        'employee_id', v_row.id,
        'employee_code', v_row.codigo_empleado,
        'employee_name', v_row.nombre_completo,
        'reason', 'NETO_NEGATIVO',
        'message', 'Los descuentos superan el pago acumulado; la nómina requiere corrección o autorización.',
        'amount', v_neto
      ));
    end if;

    v_empleados_incluidos := v_empleados_incluidos + 1;
    v_jornadas_usadas := v_jornadas_usadas + v_jornadas_empleado;
    v_minutos_totales := v_minutos_totales + v_minutos_normales + v_minutos_extra;
    v_total := v_total + v_neto;
    v_empleados := v_empleados || jsonb_build_array(jsonb_build_object(
      'employee_id', v_row.id,
      'employee_code', v_row.codigo_empleado,
      'employee_name', v_row.nombre_completo,
      'pay_type', v_row.tipo_pago,
      'salary', v_row.salario,
      'journeys', v_jornadas_empleado,
      'normal_hours', round(v_minutos_normales / 60, 2),
      'overtime_hours', round(v_minutos_extra / 60, 2),
      'gross', v_bruto,
      'afp', v_afp,
      'sfs', v_sfs,
      'loans', v_prestamos,
      'discounts', v_descuentos,
      'net', v_neto
    ));
  end loop;

  if jsonb_array_length(v_bloqueos) > 0 then
    return jsonb_build_object(
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
      'reason', 'El cálculo está bloqueado; revise los empleados indicados.'
    );
  end if;

  return jsonb_build_object(
    'source', 'REAL_TIME',
    'as_of_date', v_fecha,
    'period_id', v_periodo_id,
    'period_start', v_inicio,
    'period_end', v_fin,
    'period_type', v_tipo_periodo,
    'payroll_state', v_estado_periodo,
    'total', round(v_total, 2),
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

revoke all on function public.obtener_total_nomina_dashboard(date) from public, anon;
grant execute on function public.obtener_total_nomina_dashboard(date) to authenticated, service_role;

comment on function public.obtener_total_nomina_dashboard(date) is
  'Total de nómina para Dashboard: usa snapshot CERRADO o calcula una vista previa RC4_WORKED_MINUTES_V2 sin persistir cambios.';

commit;
