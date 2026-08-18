begin;

set local search_path = public, extensions, pg_catalog;

-- 0044 FUNDACIÓN CANÓNICA.
-- Esta migración NO activa cutover, NO instala triggers sobre las fuentes 0043,
-- NO modifica pagos 0038 y NO materializa AFP/SFS ni otras deducciones.
-- Solo crea la identidad económica estable y funciones privadas para reconciliar
-- explícitamente los cinco objetivos salariales canónicos de 0043 contra el
-- ledger inmutable 0038 mediante eventos append-only.

create table public.nomina_cutover_canonico_empresas (
  empresa_id uuid primary key
    references public.companies(id) on delete restrict,
  estado text not null default 'INACTIVO',
  fecha_efectiva date,
  activado_en timestamptz,
  activado_por uuid,
  motivo text,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp(),
  constraint nomina_cutover_canonico_empresas_estado_check
    check (estado in ('INACTIVO', 'ACTIVO')),
  constraint nomina_cutover_canonico_empresas_activacion_check
    check (
      (
        estado = 'INACTIVO'
        and fecha_efectiva is null
        and activado_en is null
        and activado_por is null
      )
      or (
        estado = 'ACTIVO'
        and fecha_efectiva is not null
        and activado_en is not null
        and activado_por is not null
        and char_length(btrim(coalesce(motivo, ''))) between 3 and 500
      )
    ),
  constraint nomina_cutover_canonico_empresas_actor_fk
    foreign key (empresa_id, activado_por)
    references public.profiles(company_id, id) on delete restrict
);

comment on table public.nomina_cutover_canonico_empresas is
  'Cutover por empresa para la nómina canónica. 0044 lo deja INACTIVO y no expone ninguna operación de activación.';

create table public.nomina_identidades_economicas_canonicas (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null,
  empleado_id uuid not null,
  fecha_economica date not null,
  concepto text not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint nomina_identidades_economicas_canonicas_concepto_check
    check (concepto in (
      'SALARY_DAY_BASE',
      'SALARY_DAY_ADJUSTMENT',
      'SALARY_DAY_OVERTIME',
      'HOLIDAY_NORMAL_PREMIUM',
      'SALARY_30DAY_COMPLEMENT'
    )),
  constraint nomina_identidades_economicas_canonicas_empresa_id_id_unique
    unique (empresa_id, id),
  constraint nomina_identidades_economicas_canonicas_natural_unique
    unique (empresa_id, empleado_id, fecha_economica, concepto),
  constraint nomina_identidades_economicas_canonicas_empleado_fk
    foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict
);

comment on table public.nomina_identidades_economicas_canonicas is
  'Identidad económica estable por empresa, empleado, fecha y concepto canónico. Es append-only e independiente de revisiones de 0043.';

create index nomina_identidades_economicas_canonicas_lookup_idx
  on public.nomina_identidades_economicas_canonicas(
    empresa_id, empleado_id, fecha_economica, concepto
  );

alter table public.nomina_cutover_canonico_empresas enable row level security;
alter table public.nomina_identidades_economicas_canonicas enable row level security;

revoke all privileges on table
  public.nomina_cutover_canonico_empresas,
  public.nomina_identidades_economicas_canonicas
from public, anon, authenticated, service_role;

create or replace function private.proteger_identidad_economica_0044()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P4400',
    message = 'CANONICAL_PAYROLL_IDENTITY_IMMUTABLE';
end;
$$;

create trigger nomina_identidades_economicas_canonicas_inmutables
before update or delete on public.nomina_identidades_economicas_canonicas
for each row execute function private.proteger_identidad_economica_0044();

create trigger nomina_identidades_economicas_canonicas_truncate_inmutable
before truncate on public.nomina_identidades_economicas_canonicas
for each statement execute function private.proteger_identidad_economica_0044();

create or replace function private.movimiento_nomina_firmado_0044(
  p_clase text,
  p_monto numeric
)
returns numeric
language sql
immutable
set search_path = ''
as $$
  select round(case p_clase
    when 'DEVENGO' then coalesce(p_monto, 0)
    when 'REVERSO_DEVENGO' then -coalesce(p_monto, 0)
    when 'DEDUCCION' then -coalesce(p_monto, 0)
    when 'REVERSO_DEDUCCION' then coalesce(p_monto, 0)
    else 0
  end, 2);
$$;

create or replace function private.complemento_convencion_30_vigente_sistema_0044(
  p_empresa uuid,
  p_empleado uuid,
  p_anio integer,
  p_fecha_fin_febrero date,
  p_fecha_ancla date
)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_ancla_actual date;
begin
  if p_empresa is null
     or p_empleado is null
     or p_anio is null
     or p_anio not between 1900 and 9999
     or p_fecha_fin_febrero is null
     or p_fecha_ancla is null
     or p_fecha_fin_febrero <> make_date(p_anio, 3, 1) - 1
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
    raise;
end;
$$;

create or replace function private.materializar_objetivo_canonico_0044(
  p_empresa uuid,
  p_empleado uuid,
  p_fecha_economica date,
  p_concepto text,
  p_target numeric,
  p_source_kind text,
  p_source_id uuid,
  p_source_revision bigint,
  p_source_input_hash text,
  p_actor uuid,
  p_motivo text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_identidad uuid;
  v_target numeric := round(coalesce(p_target, 0), 2);
  v_ciclo_desde date;
  v_ciclo_hasta date;
  v_prev_source_key text;
  v_prev_source_snapshot jsonb;
  v_existing_money numeric := 0;
  v_paid_money numeric := 0;
  v_existing_credit numeric := 0;
  v_money_target numeric := 0;
  v_credit_target numeric := 0;
  v_money_delta numeric := 0;
  v_credit_delta numeric := 0;
  v_event_key text;
  v_event_order bigint := 1;
  v_source_inserted integer := 0;
  v_money_inserted integer := 0;
  v_credit_inserted integer := 0;
  v_motivo text := btrim(coalesce(p_motivo, ''));
begin
  if p_empresa is null
     or p_empleado is null
     or p_fecha_economica is null
     or p_concepto not in (
       'SALARY_DAY_BASE',
       'SALARY_DAY_ADJUSTMENT',
       'SALARY_DAY_OVERTIME',
       'HOLIDAY_NORMAL_PREMIUM',
       'SALARY_30DAY_COMPLEMENT'
     )
     or p_source_kind not in (
       'DAILY_RESOLUTION', 'FEBRUARY_COMPLEMENT', 'ABSENT'
     )
     or p_source_input_hash is null
     or p_source_input_hash !~ '^[0-9a-f]{64}$'
     or char_length(v_motivo) not between 3 and 500
     or (
       p_source_kind = 'ABSENT'
       and (p_source_id is not null or coalesce(p_source_revision, -1) <> 0)
     )
     or (
       p_source_kind <> 'ABSENT'
       and (p_source_id is null or coalesce(p_source_revision, 0) <= 0)
     )
  then
    raise exception using
      errcode = 'P4401',
      message = 'CANONICAL_PAYROLL_TARGET_INVALID';
  end if;

  perform employee.id
  from public.empleados employee
  where employee.empresa_id = p_empresa
    and employee.id = p_empleado
  for update;
  if not found then
    raise exception using
      errcode = 'P4402',
      message = 'CANONICAL_PAYROLL_EMPLOYEE_NOT_FOUND';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      p_empresa::text || ':' || p_empleado::text || ':'
        || p_fecha_economica::text || ':' || p_concepto,
      4400
    )
  );

  insert into public.nomina_identidades_economicas_canonicas(
    empresa_id, empleado_id, fecha_economica, concepto
  ) values (
    p_empresa, p_empleado, p_fecha_economica, p_concepto
  )
  on conflict (empresa_id, empleado_id, fecha_economica, concepto)
  do nothing;

  select identity_row.id
  into v_identidad
  from public.nomina_identidades_economicas_canonicas identity_row
  where identity_row.empresa_id = p_empresa
    and identity_row.empleado_id = p_empleado
    and identity_row.fecha_economica = p_fecha_economica
    and identity_row.concepto = p_concepto
  for share;

  if extract(day from p_fecha_economica)::integer <= 15 then
    v_ciclo_desde := date_trunc(
      'month', p_fecha_economica::timestamp
    )::date;
    v_ciclo_hasta := v_ciclo_desde + 14;
  else
    v_ciclo_desde := (
      date_trunc('month', p_fecha_economica::timestamp) + interval '15 days'
    )::date;
    v_ciclo_hasta := (
      date_trunc('month', p_fecha_economica::timestamp)
      + interval '1 month - 1 day'
    )::date;
  end if;

  select movement.source_key, movement.snapshot
  into v_prev_source_key, v_prev_source_snapshot
  from public.nomina_movimientos_tiempo_real movement
  where movement.empresa_id = p_empresa
    and movement.empleado_id = p_empleado
    and movement.source_type = 'CANONICAL_SALARY_SOURCE'
    and movement.snapshot ->> 'canonical_identity_id' = v_identidad::text
  order by coalesce(
    (movement.snapshot ->> 'event_order')::bigint, 0
  ) desc, movement.id desc
  limit 1;

  if found
     and coalesce(v_prev_source_snapshot ->> 'source_kind', '') = p_source_kind
     and coalesce(v_prev_source_snapshot ->> 'source_id', '')
       = coalesce(p_source_id::text, '')
     and coalesce(
       (v_prev_source_snapshot ->> 'source_revision')::bigint, 0
     ) = coalesce(p_source_revision, 0)
     and coalesce(v_prev_source_snapshot ->> 'source_input_hash', '')
       = p_source_input_hash
     and round(coalesce(
       (v_prev_source_snapshot ->> 'economic_target')::numeric, 0
     ), 2) = v_target
  then
    return jsonb_build_object(
      'status', 'REPLAYED',
      'identity_id', v_identidad,
      'source_inserted', 0,
      'money_inserted', 0,
      'credit_inserted', 0,
      'economic_target', v_target
    );
  end if;

  v_event_order := coalesce(
    (v_prev_source_snapshot ->> 'event_order')::bigint, 0
  ) + 1;

  select round(coalesce(sum(
    private.movimiento_nomina_firmado_0044(
      movement.clase, movement.monto
    )
  ), 0), 2)
  into v_existing_money
  from public.nomina_movimientos_tiempo_real movement
  where movement.empresa_id = p_empresa
    and movement.empleado_id = p_empleado
    and movement.source_type = 'CANONICAL_SALARY_DELTA'
    and movement.snapshot ->> 'canonical_identity_id' = v_identidad::text;

  select round(coalesce(sum(
    private.movimiento_nomina_firmado_0044(
      movement.clase, movement.monto
    )
  ), 0), 2)
  into v_paid_money
  from public.nomina_movimientos_tiempo_real movement
  join public.nomina_pago_movimientos consumed
    on consumed.empresa_id = movement.empresa_id
   and consumed.movimiento_id = movement.id
  where movement.empresa_id = p_empresa
    and movement.empleado_id = p_empleado
    and movement.source_type = 'CANONICAL_SALARY_DELTA'
    and movement.snapshot ->> 'canonical_identity_id' = v_identidad::text;

  select round(coalesce(sum(
    (movement.snapshot ->> 'credit_delta')::numeric
  ), 0), 2)
  into v_existing_credit
  from public.nomina_movimientos_tiempo_real movement
  where movement.empresa_id = p_empresa
    and movement.empleado_id = p_empleado
    and movement.source_type = 'CANONICAL_SALARY_CREDIT'
    and movement.clase = 'CONTROL'
    and movement.snapshot ->> 'canonical_identity_id' = v_identidad::text
    and movement.snapshot ? 'credit_delta';

  if v_paid_money > 0 and v_target < v_paid_money then
    v_money_target := v_paid_money;
    v_credit_target := round(v_paid_money - v_target, 2);
  else
    v_money_target := v_target;
    v_credit_target := 0;
  end if;

  v_money_delta := round(v_money_target - v_existing_money, 2);
  v_credit_delta := round(v_credit_target - v_existing_credit, 2);

  v_event_key := encode(
    extensions.digest(
      pg_catalog.convert_to(
        concat_ws(
          '|',
          'C44',
          v_identidad::text,
          coalesce(v_prev_source_key, 'ROOT'),
          p_source_kind,
          coalesce(p_source_id::text, '-'),
          coalesce(p_source_revision, 0)::text,
          p_source_input_hash,
          v_target::text
        ),
        'UTF8'
      ),
      'sha256'
    ),
    'hex'
  );

  insert into public.nomina_movimientos_tiempo_real(
    empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
    source_type, source_key, clase, concepto, monto, formula, snapshot,
    creado_por
  ) values (
    p_empresa, p_empleado, v_ciclo_desde, v_ciclo_hasta, p_fecha_economica,
    'CANONICAL_SALARY_SOURCE', v_event_key, 'CONTROL', p_concepto, 0,
    'CANONICAL_SALARY_BRIDGE_V1',
    jsonb_build_object(
      'foundation', '0044',
      'canonical_identity_id', v_identidad,
      'event_order', v_event_order,
      'previous_source_key', v_prev_source_key,
      'source_kind', p_source_kind,
      'source_id', p_source_id,
      'source_revision', coalesce(p_source_revision, 0),
      'source_input_hash', p_source_input_hash,
      'economic_target', v_target,
      'previous_money_target', v_existing_money,
      'money_target', v_money_target,
      'paid_target', v_paid_money,
      'previous_credit_target', v_existing_credit,
      'credit_target', v_credit_target,
      'reason', v_motivo
    ),
    p_actor
  )
  on conflict (empresa_id, source_type, source_key) do nothing;
  get diagnostics v_source_inserted = row_count;

  if v_source_inserted = 0 then
    return jsonb_build_object(
      'status', 'REPLAYED',
      'identity_id', v_identidad,
      'source_inserted', 0,
      'money_inserted', 0,
      'credit_inserted', 0,
      'economic_target', v_target
    );
  end if;

  if v_money_delta <> 0 then
    insert into public.nomina_movimientos_tiempo_real(
      empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
      source_type, source_key, clase, concepto, monto, formula, snapshot,
      creado_por
    ) values (
      p_empresa, p_empleado, v_ciclo_desde, v_ciclo_hasta, p_fecha_economica,
      'CANONICAL_SALARY_DELTA', v_event_key || ':MONEY',
      case when v_money_delta > 0 then 'DEVENGO' else 'REVERSO_DEVENGO' end,
      p_concepto,
      abs(v_money_delta),
      'CANONICAL_SALARY_BRIDGE_V1',
      jsonb_build_object(
        'foundation', '0044',
        'canonical_identity_id', v_identidad,
        'source_event_order', v_event_order,
        'source_event_key', v_event_key,
        'source_kind', p_source_kind,
        'source_id', p_source_id,
        'source_revision', coalesce(p_source_revision, 0),
        'source_input_hash', p_source_input_hash,
        'economic_target', v_target,
        'previous_money_target', v_existing_money,
        'money_target', v_money_target,
        'paid_target', v_paid_money,
        'signed_delta', v_money_delta,
        'reason', v_motivo
      ),
      p_actor
    )
    on conflict (empresa_id, source_type, source_key) do nothing;
    get diagnostics v_money_inserted = row_count;
  end if;

  if v_credit_delta <> 0 then
    insert into public.nomina_movimientos_tiempo_real(
      empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
      source_type, source_key, clase, concepto, monto, formula, snapshot,
      creado_por
    ) values (
      p_empresa, p_empleado, v_ciclo_desde, v_ciclo_hasta, p_fecha_economica,
      'CANONICAL_SALARY_CREDIT', v_event_key || ':CREDIT',
      'CONTROL', p_concepto, 0,
      'CANONICAL_SALARY_BRIDGE_V1',
      jsonb_build_object(
        'foundation', '0044',
        'canonical_identity_id', v_identidad,
        'source_event_order', v_event_order,
        'source_event_key', v_event_key,
        'source_kind', p_source_kind,
        'source_id', p_source_id,
        'source_revision', coalesce(p_source_revision, 0),
        'source_input_hash', p_source_input_hash,
        'economic_target', v_target,
        'paid_target', v_paid_money,
        'previous_credit_target', v_existing_credit,
        'credit_delta', v_credit_delta,
        'credit_target', v_credit_target,
        'reason', v_motivo
      ),
      p_actor
    )
    on conflict (empresa_id, source_type, source_key) do nothing;
    get diagnostics v_credit_inserted = row_count;
  end if;

  return jsonb_build_object(
    'status', 'RECONCILED',
    'identity_id', v_identidad,
    'source_event_key', v_event_key,
    'source_inserted', v_source_inserted,
    'money_inserted', v_money_inserted,
    'credit_inserted', v_credit_inserted,
    'economic_target', v_target,
    'money_target', v_money_target,
    'paid_target', v_paid_money,
    'credit_target', v_credit_target
  );
end;
$$;

create or replace function private.reconciliar_objetivos_nomina_canonicos_0044(
  p_empresa uuid,
  p_empleado uuid,
  p_desde date,
  p_hasta date,
  p_actor uuid,
  p_motivo text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
  v_identity record;
  v_result jsonb;
  v_sources integer := 0;
  v_source_events integer := 0;
  v_money_events integer := 0;
  v_credit_events integer := 0;
  v_absences integer := 0;
  v_last_source_hash text;
  v_absence_hash text;
  v_motivo text := btrim(coalesce(p_motivo, ''));
begin
  if p_empresa is null
     or p_empleado is null
     or p_desde is null
     or p_hasta is null
     or p_hasta < p_desde
     or p_hasta - p_desde > 366
     or char_length(v_motivo) not between 3 and 500
  then
    raise exception using
      errcode = 'P4403',
      message = 'CANONICAL_PAYROLL_RECONCILIATION_INVALID';
  end if;

  if not exists (
    select 1
    from public.empleados employee
    where employee.empresa_id = p_empresa
      and employee.id = p_empleado
  ) then
    raise exception using
      errcode = 'P4402',
      message = 'CANONICAL_PAYROLL_EMPLOYEE_NOT_FOUND';
  end if;

  for v_row in
    select
      resolution.id as source_id,
      resolution.revision as source_revision,
      resolution.input_hash as source_input_hash,
      resolution.fecha_local as fecha_economica,
      objective.concepto,
      objective.target
    from public.nomina_resoluciones_diarias resolution
    cross join lateral (values
      ('SALARY_DAY_BASE'::text, resolution.objetivo_base_nominal),
      ('SALARY_DAY_ADJUSTMENT'::text, resolution.objetivo_ajuste_diario),
      ('SALARY_DAY_OVERTIME'::text, resolution.objetivo_hora_extra),
      ('HOLIDAY_NORMAL_PREMIUM'::text, resolution.objetivo_premium_festivo)
    ) objective(concepto, target)
    where resolution.empresa_id = p_empresa
      and resolution.empleado_id = p_empleado
      and resolution.fecha_local between p_desde and p_hasta
      and not exists (
        select 1
        from public.nomina_resoluciones_diarias posterior
        where posterior.empresa_id = resolution.empresa_id
          and posterior.empleado_id = resolution.empleado_id
          and posterior.fecha_local = resolution.fecha_local
          and posterior.revision > resolution.revision
      )
      and not private.empleado_suspendido_en_fecha_nomina_0043(
        resolution.empresa_id,
        resolution.empleado_id,
        resolution.fecha_local
      )
    order by resolution.fecha_local, objective.concepto
  loop
    v_sources := v_sources + 1;
    v_result := private.materializar_objetivo_canonico_0044(
      p_empresa,
      p_empleado,
      v_row.fecha_economica,
      v_row.concepto,
      v_row.target,
      'DAILY_RESOLUTION',
      v_row.source_id,
      v_row.source_revision,
      v_row.source_input_hash,
      p_actor,
      v_motivo
    );
    v_source_events := v_source_events
      + coalesce((v_result ->> 'source_inserted')::integer, 0);
    v_money_events := v_money_events
      + coalesce((v_result ->> 'money_inserted')::integer, 0);
    v_credit_events := v_credit_events
      + coalesce((v_result ->> 'credit_inserted')::integer, 0);
  end loop;

  for v_row in
    select
      complement.id as source_id,
      complement.revision as source_revision,
      complement.input_hash as source_input_hash,
      complement.fecha_fin_febrero as fecha_economica,
      'SALARY_30DAY_COMPLEMENT'::text as concepto,
      complement.objetivo_complemento_30_dias as target
    from public.nomina_complementos_convencion_30 complement
    where complement.empresa_id = p_empresa
      and complement.empleado_id = p_empleado
      and complement.fecha_fin_febrero between p_desde and p_hasta
      and not exists (
        select 1
        from public.nomina_complementos_convencion_30 posterior
        where posterior.empresa_id = complement.empresa_id
          and posterior.empleado_id = complement.empleado_id
          and posterior.anio = complement.anio
          and posterior.revision > complement.revision
      )
      and private.complemento_convencion_30_vigente_sistema_0044(
        complement.empresa_id,
        complement.empleado_id,
        complement.anio,
        complement.fecha_fin_febrero,
        complement.fecha_ancla
      )
    order by complement.fecha_fin_febrero
  loop
    v_sources := v_sources + 1;
    v_result := private.materializar_objetivo_canonico_0044(
      p_empresa,
      p_empleado,
      v_row.fecha_economica,
      v_row.concepto,
      v_row.target,
      'FEBRUARY_COMPLEMENT',
      v_row.source_id,
      v_row.source_revision,
      v_row.source_input_hash,
      p_actor,
      v_motivo
    );
    v_source_events := v_source_events
      + coalesce((v_result ->> 'source_inserted')::integer, 0);
    v_money_events := v_money_events
      + coalesce((v_result ->> 'money_inserted')::integer, 0);
    v_credit_events := v_credit_events
      + coalesce((v_result ->> 'credit_inserted')::integer, 0);
  end loop;

  for v_identity in
    select identity_row.*
    from public.nomina_identidades_economicas_canonicas identity_row
    where identity_row.empresa_id = p_empresa
      and identity_row.empleado_id = p_empleado
      and identity_row.fecha_economica between p_desde and p_hasta
      and (
        (
          identity_row.concepto <> 'SALARY_30DAY_COMPLEMENT'
          and not exists (
            select 1
            from public.nomina_resoluciones_diarias resolution
            where resolution.empresa_id = identity_row.empresa_id
              and resolution.empleado_id = identity_row.empleado_id
              and resolution.fecha_local = identity_row.fecha_economica
              and not exists (
                select 1
                from public.nomina_resoluciones_diarias posterior
                where posterior.empresa_id = resolution.empresa_id
                  and posterior.empleado_id = resolution.empleado_id
                  and posterior.fecha_local = resolution.fecha_local
                  and posterior.revision > resolution.revision
              )
              and not private.empleado_suspendido_en_fecha_nomina_0043(
                resolution.empresa_id,
                resolution.empleado_id,
                resolution.fecha_local
              )
          )
        )
        or (
          identity_row.concepto = 'SALARY_30DAY_COMPLEMENT'
          and not exists (
            select 1
            from public.nomina_complementos_convencion_30 complement
            where complement.empresa_id = identity_row.empresa_id
              and complement.empleado_id = identity_row.empleado_id
              and complement.fecha_fin_febrero = identity_row.fecha_economica
              and not exists (
                select 1
                from public.nomina_complementos_convencion_30 posterior
                where posterior.empresa_id = complement.empresa_id
                  and posterior.empleado_id = complement.empleado_id
                  and posterior.anio = complement.anio
                  and posterior.revision > complement.revision
              )
              and private.complemento_convencion_30_vigente_sistema_0044(
                complement.empresa_id,
                complement.empleado_id,
                complement.anio,
                complement.fecha_fin_febrero,
                complement.fecha_ancla
              )
          )
        )
      )
    order by identity_row.fecha_economica, identity_row.concepto
  loop
    select movement.snapshot ->> 'source_input_hash'
    into v_last_source_hash
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = p_empresa
      and movement.empleado_id = p_empleado
      and movement.source_type = 'CANONICAL_SALARY_SOURCE'
      and movement.snapshot ->> 'canonical_identity_id' = v_identity.id::text
      and movement.snapshot ->> 'source_kind' <> 'ABSENT'
    order by coalesce(
      (movement.snapshot ->> 'event_order')::bigint, 0
    ) desc, movement.id desc
    limit 1;

    v_absence_hash := encode(
      extensions.digest(
        pg_catalog.convert_to(
          concat_ws(
            '|',
            'C44-ABSENT',
            v_identity.id::text,
            coalesce(v_last_source_hash, 'ROOT')
          ),
          'UTF8'
        ),
        'sha256'
      ),
      'hex'
    );

    v_result := private.materializar_objetivo_canonico_0044(
      p_empresa,
      p_empleado,
      v_identity.fecha_economica,
      v_identity.concepto,
      0,
      'ABSENT',
      null,
      0,
      v_absence_hash,
      p_actor,
      v_motivo
    );
    if coalesce((v_result ->> 'source_inserted')::integer, 0) > 0 then
      v_absences := v_absences + 1;
    end if;
    v_source_events := v_source_events
      + coalesce((v_result ->> 'source_inserted')::integer, 0);
    v_money_events := v_money_events
      + coalesce((v_result ->> 'money_inserted')::integer, 0);
    v_credit_events := v_credit_events
      + coalesce((v_result ->> 'credit_inserted')::integer, 0);
  end loop;

  return jsonb_build_object(
    'foundation', '0044',
    'company_id', p_empresa,
    'employee_id', p_empleado,
    'date_from', p_desde,
    'date_to', p_hasta,
    'sources_processed', v_sources,
    'source_events', v_source_events,
    'money_events', v_money_events,
    'credit_events', v_credit_events,
    'absence_events', v_absences
  );
end;
$$;

revoke all on function private.proteger_identidad_economica_0044()
from public, anon, authenticated, service_role;
revoke all on function private.movimiento_nomina_firmado_0044(text, numeric)
from public, anon, authenticated, service_role;
revoke all on function private.complemento_convencion_30_vigente_sistema_0044(
  uuid, uuid, integer, date, date
) from public, anon, authenticated, service_role;
revoke all on function private.materializar_objetivo_canonico_0044(
  uuid, uuid, date, text, numeric, text, uuid, bigint, text, uuid, text
) from public, anon, authenticated, service_role;
revoke all on function private.reconciliar_objetivos_nomina_canonicos_0044(
  uuid, uuid, date, date, uuid, text
) from public, anon, authenticated, service_role;

comment on function private.materializar_objetivo_canonico_0044(
  uuid, uuid, date, text, numeric, text, uuid, bigint, text, uuid, text
) is
  '0044: materializa explícitamente deltas salariales canónicos append-only. Si una reducción cruza dinero ya consumido, preserva el pago y registra el crédito residual mediante CONTROL monto 0.';

comment on function private.reconciliar_objetivos_nomina_canonicos_0044(
  uuid, uuid, date, date, uuid, text
) is
  '0044 FUNDACIÓN: reconcilia los cinco objetivos canónicos de 0043 sin triggers, sin AFP/SFS, sin alterar consultas/pagos y sin activar cutover.';

commit;
