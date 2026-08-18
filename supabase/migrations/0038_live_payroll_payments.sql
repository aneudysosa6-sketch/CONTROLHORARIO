-- Event-sourced, immutable live-payroll ledger.
-- Date filters are read-only views over already accrued movements. Accrual is
-- driven only by source events (a journey entering FINALIZADA) and migration
-- backfill; payment only locks and consumes concrete movements.

begin;

insert into public.permisos(codigo, nombre, descripcion, modulo, activo)
values (
  'nomina.pagar',
  'Registrar pagos de nomina',
  'Confirma pagos individuales desde movimientos de nomina ya devengados.',
  'nomina',
  true
)
on conflict(codigo) do update
set nombre = excluded.nombre,
    descripcion = excluded.descripcion,
    modulo = excluded.modulo,
    activo = true;

insert into public.rol_permisos(rol_id, permiso_id, permitido, alcance)
select role_row.id, permission_row.id, true, 'empresa'
from public.roles role_row
cross join public.permisos permission_row
where role_row.is_active
  and private.normalizar_codigo_rol(role_row.code) in ('ADMIN', 'NOMINA')

  and permission_row.codigo = 'nomina.pagar'
  and permission_row.activo
on conflict(rol_id, permiso_id) do update
set permitido = excluded.permitido,
    alcance = excluded.alcance;

alter table public.jornadas
  add column revision_nomina bigint not null default 0;
alter table public.jornadas
  add constraint jornadas_revision_nomina_check
  check (revision_nomina >= 0);

create table public.nomina_pagos_tiempo_real (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  fecha_desde date not null,
  fecha_hasta date not null,
  codigo_empleado text not null,
  nombre_empleado text not null,
  jornadas integer not null check (jornadas >= 0),
  monto_bruto numeric(14,2) not null,
  monto_deducciones numeric(14,2) not null,
  monto_pagado numeric(14,2) not null check (monto_pagado > 0),
  formula text not null,
  calculo jsonb not null,
  motivo text not null,
  idempotency_key uuid not null,
  source_fingerprint text not null,
  pagado_por uuid not null,
  pagado_en timestamptz not null default now(),
  constraint nomina_pagos_tiempo_real_fechas_check
    check (fecha_hasta >= fecha_desde),
  constraint nomina_pagos_tiempo_real_montos_check
    check (round(monto_pagado + monto_deducciones, 2) = round(monto_bruto, 2)),
  constraint nomina_pagos_tiempo_real_motivo_check
    check (char_length(btrim(motivo)) between 1 and 500),
  constraint nomina_pagos_tiempo_real_fingerprint_check
    check (source_fingerprint ~ '^[0-9a-f]{64}$'),
  constraint nomina_pagos_tiempo_real_empresa_id_unique
    unique (empresa_id, id),
  constraint nomina_pagos_tiempo_real_empresa_id_empleado_unique
    unique (empresa_id, id, empleado_id),
  constraint nomina_pagos_tiempo_real_idempotency_unique
    unique (empresa_id, idempotency_key),
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  foreign key (empresa_id, pagado_por)
    references public.profiles(company_id, id) on delete restrict
);

create unique index jornadas_empresa_id_empleado_live_payroll_uidx
  on public.jornadas(empresa_id, id, empleado_id);

create table public.nomina_movimientos_tiempo_real (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null,
  empleado_id uuid not null,
  ciclo_desde date not null,
  ciclo_hasta date not null,
  fecha_devengo date not null,
  source_type text not null,
  source_key text not null,
  clase text not null check (clase in (
    'DEVENGO', 'DEDUCCION', 'REVERSO_DEVENGO', 'REVERSO_DEDUCCION', 'CONTROL'
  )),
  concepto text not null,
  tipo text,
  monto numeric(14,2) not null,
  formula text not null,
  snapshot jsonb not null default '{}'::jsonb,
  jornada_id uuid,
  ajuste_id uuid,
  prestamo_id uuid,
  credito_id uuid,
  creado_por uuid,
  creado_en timestamptz not null default now(),
  constraint nomina_movimientos_tiempo_real_ciclo_check
    check (ciclo_hasta >= ciclo_desde),
  constraint nomina_movimientos_tiempo_real_source_check
    check (char_length(btrim(source_type)) > 0 and char_length(btrim(source_key)) > 0),
  constraint nomina_movimientos_tiempo_real_monto_check
    check (
      (clase = 'CONTROL' and monto = 0)
      or (clase in ('DEVENGO', 'DEDUCCION') and monto <> 0)
      or (
        clase in ('REVERSO_DEVENGO', 'REVERSO_DEDUCCION')
        and monto > 0
      )
    ),
  constraint nomina_movimientos_tiempo_real_source_unique
    unique (empresa_id, source_type, source_key),
  constraint nomina_movimientos_tiempo_real_empresa_id_unique
    unique (empresa_id, id),
  constraint nomina_movimientos_tiempo_real_empresa_id_empleado_unique
    unique (empresa_id, id, empleado_id),
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  foreign key (empresa_id, jornada_id, empleado_id)
    references public.jornadas(empresa_id, id, empleado_id) on delete restrict,
  foreign key (empresa_id, ajuste_id)
    references public.nomina_ajustes(empresa_id, id) on delete restrict,
  foreign key (empresa_id, prestamo_id)
    references public.nomina_prestamos(empresa_id, id) on delete restrict,
  foreign key (empresa_id, credito_id)
    references public.nomina_creditos(empresa_id, id) on delete restrict,
  foreign key (empresa_id, creado_por)
    references public.profiles(company_id, id) on delete restrict
);

create table public.nomina_pago_movimientos (
  empresa_id uuid not null,
  pago_id uuid not null,
  movimiento_id uuid not null,
  empleado_id uuid not null,
  monto numeric(14,2) not null,
  source_type text not null,
  source_key text not null,
  consumido_en timestamptz not null default now(),
  primary key (empresa_id, pago_id, movimiento_id),
  constraint nomina_pago_movimientos_movimiento_unique
    unique (empresa_id, movimiento_id),
  foreign key (empresa_id, pago_id, empleado_id)
    references public.nomina_pagos_tiempo_real(empresa_id, id, empleado_id)
    on delete restrict,
  foreign key (empresa_id, movimiento_id, empleado_id)
    references public.nomina_movimientos_tiempo_real(empresa_id, id, empleado_id)
    on delete restrict
);

-- One-shot internal authorization for the balance mutation caused by consuming
-- debt movements.  The source guard consumes this row atomically; callers have
-- no privileges on it, so a direct UPDATE cannot spoof the registrar path.
create table private.nomina_pago_deuda_aplicaciones (
  empresa_id uuid not null,
  pago_id uuid not null,
  empleado_id uuid not null,
  fuente_tipo text not null check (fuente_tipo in ('LOAN', 'CREDIT')),
  fuente_id uuid not null,
  monto numeric(14,2) not null check (monto > 0),
  aplicada boolean not null default false,
  creada_en timestamptz not null default now(),
  aplicada_en timestamptz,
  primary key (empresa_id, pago_id, fuente_tipo, fuente_id),
  constraint nomina_pago_deuda_aplicaciones_estado_check
    check (aplicada = (aplicada_en is not null)),
  foreign key (empresa_id, pago_id, empleado_id)
    references public.nomina_pagos_tiempo_real(empresa_id, id, empleado_id)
    on delete restrict
);

revoke all privileges on table private.nomina_pago_deuda_aplicaciones
from public, anon, authenticated, service_role;

-- Compatibility/audit projection: one immutable row per journey actually
-- consumed by a payment. Earnings/deductions are authoritative in movements.
create table public.nomina_pago_jornadas (
  empresa_id uuid not null,
  pago_id uuid not null,
  jornada_id uuid not null,
  empleado_id uuid not null,
  fecha_laboral date not null,
  minutos_trabajados integer not null check (minutos_trabajados > 0),
  minutos_normales integer not null check (minutos_normales >= 0),
  minutos_extra integer not null check (minutos_extra >= 0),
  bruto_asignado numeric(14,2) not null check (bruto_asignado >= 0),
  fuente jsonb not null default '{}'::jsonb,
  version_sync bigint not null,
  jornada_actualizada_en timestamptz not null,
  registrada_en timestamptz not null default now(),
  primary key (empresa_id, pago_id, jornada_id),
  constraint nomina_pago_jornadas_jornada_unique unique (empresa_id, jornada_id),
  constraint nomina_pago_jornadas_minutos_check
    check (minutos_trabajados = minutos_normales + minutos_extra),
  foreign key (empresa_id, pago_id, empleado_id)
    references public.nomina_pagos_tiempo_real(empresa_id, id, empleado_id)
    on delete restrict,
  foreign key (empresa_id, jornada_id, empleado_id)
    references public.jornadas(empresa_id, id, empleado_id) on delete restrict
);

-- Historical cutover is fail-closed per employee: a journey on or before the
-- latest payroll period already CLOSED for that employee is never re-accrued.
create table public.nomina_pago_cortes_legacy (
  empresa_id uuid not null,
  empleado_id uuid not null,
  fecha_corte date not null,
  periodo_id uuid not null,
  nomina_id uuid not null,
  detalle_id uuid not null,
  formula text not null,
  cerrado_en timestamptz,
  cerrado_por uuid,
  registrado_en timestamptz not null default now(),
  primary key (empresa_id, empleado_id),
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  foreign key (empresa_id, periodo_id)
    references public.nomina_periodos(empresa_id, id) on delete restrict,
  foreign key (empresa_id, nomina_id)
    references public.nominas(empresa_id, id) on delete restrict,
  foreign key (empresa_id, detalle_id)
    references public.nomina_detalles(empresa_id, id) on delete restrict,
  foreign key (empresa_id, cerrado_por)
    references public.profiles(company_id, id) on delete restrict
);

insert into public.nomina_pago_cortes_legacy(
  empresa_id, empleado_id, fecha_corte, periodo_id, nomina_id, detalle_id,
  formula, cerrado_en, cerrado_por
)
select distinct on (detail.empresa_id, detail.empleado_id)
  detail.empresa_id, detail.empleado_id, period.fecha_fin, period.id,
  payroll.id, detail.id, detail.formula, period.cerrada_en, period.cerrada_por
from public.nomina_detalles detail
join public.nominas payroll
  on payroll.empresa_id = detail.empresa_id and payroll.id = detail.nomina_id
join public.nomina_periodos period
  on period.empresa_id = payroll.empresa_id and period.id = payroll.periodo_id
where payroll.estado = 'CERRADA' and period.estado = 'CERRADA'
order by detail.empresa_id, detail.empleado_id, period.fecha_fin desc,
  period.cerrada_en desc nulls last, period.id, payroll.id, detail.id;

create index nomina_movimientos_pending_idx
  on public.nomina_movimientos_tiempo_real(
    empresa_id, empleado_id, fecha_devengo, clase, id
  );
create index nomina_movimientos_cycle_idx
  on public.nomina_movimientos_tiempo_real(
    empresa_id, empleado_id, ciclo_desde, ciclo_hasta, concepto
  );
create index nomina_pago_movimientos_pago_idx
  on public.nomina_pago_movimientos(empresa_id, pago_id, movimiento_id);
create index nomina_pagos_tiempo_real_historial_idx
  on public.nomina_pagos_tiempo_real(empresa_id, pagado_en desc, id);
create index nomina_pago_jornadas_pago_idx
  on public.nomina_pago_jornadas(empresa_id, pago_id, fecha_laboral, jornada_id);

alter table public.nomina_pagos_tiempo_real enable row level security;
alter table public.nomina_movimientos_tiempo_real enable row level security;
alter table public.nomina_pago_movimientos enable row level security;
alter table public.nomina_pago_jornadas enable row level security;
alter table public.nomina_pago_cortes_legacy enable row level security;

revoke all privileges on table
  public.nomina_pagos_tiempo_real,
  public.nomina_movimientos_tiempo_real,
  public.nomina_pago_movimientos,
  public.nomina_pago_jornadas,
  public.nomina_pago_cortes_legacy
from public, anon, authenticated, service_role;

grant select on table
  public.nomina_pagos_tiempo_real,
  public.nomina_movimientos_tiempo_real,
  public.nomina_pago_movimientos,
  public.nomina_pago_jornadas,
  public.nomina_pago_cortes_legacy
to authenticated;

create policy nomina_pagos_tiempo_real_select
on public.nomina_pagos_tiempo_real for select to authenticated
using (
  empresa_id = (select public.obtener_empresa_actual())
  and (select public.tiene_permiso('nomina.ver'))
);

create policy nomina_movimientos_tiempo_real_select
on public.nomina_movimientos_tiempo_real for select to authenticated
using (
  empresa_id = (select public.obtener_empresa_actual())
  and (select public.tiene_permiso('nomina.ver'))
);

create policy nomina_pago_movimientos_select
on public.nomina_pago_movimientos for select to authenticated
using (
  empresa_id = (select public.obtener_empresa_actual())
  and (select public.tiene_permiso('nomina.ver'))
);

create policy nomina_pago_jornadas_select
on public.nomina_pago_jornadas for select to authenticated
using (
  empresa_id = (select public.obtener_empresa_actual())
  and (select public.tiene_permiso('nomina.ver'))
);

create policy nomina_pago_cortes_legacy_select
on public.nomina_pago_cortes_legacy for select to authenticated
using (
  empresa_id = (select public.obtener_empresa_actual())
  and (select public.tiene_permiso('nomina.ver'))
);

create or replace function private.rechazar_mutacion_ledger_nomina()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception using
    errcode = '55000',
    message = 'LIVE_PAYROLL_LEDGER_IMMUTABLE';
end
$$;

revoke all on function private.rechazar_mutacion_ledger_nomina()
from public, anon, authenticated, service_role;

create trigger nomina_pagos_tiempo_real_immutable
before update or delete or truncate on public.nomina_pagos_tiempo_real
for each statement execute function private.rechazar_mutacion_ledger_nomina();

create trigger nomina_movimientos_tiempo_real_immutable
before update or delete or truncate on public.nomina_movimientos_tiempo_real
for each statement execute function private.rechazar_mutacion_ledger_nomina();

create trigger nomina_pago_movimientos_immutable
before update or delete or truncate on public.nomina_pago_movimientos
for each statement execute function private.rechazar_mutacion_ledger_nomina();

create trigger nomina_pago_jornadas_immutable
before update or delete or truncate on public.nomina_pago_jornadas
for each statement execute function private.rechazar_mutacion_ledger_nomina();

create trigger nomina_pago_cortes_legacy_immutable
before update or delete or truncate on public.nomina_pago_cortes_legacy
for each statement execute function private.rechazar_mutacion_ledger_nomina();
create or replace function private.jornada_revision_cero_nomina_vigente(
  p_empresa uuid,
  p_empleado uuid,
  p_jornada uuid,
  p_version_sync text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.jornadas journey
    join public.nomina_movimientos_tiempo_real revision
      on revision.empresa_id = journey.empresa_id
     and revision.empleado_id = journey.empleado_id
     and revision.jornada_id = journey.id
    where journey.empresa_id = p_empresa
      and journey.empleado_id = p_empleado
      and journey.id = p_jornada
      and journey.estado = 'FINALIZADA'
      and journey.minutos_trabajados = 0
      and not journey.revision_pendiente
      and journey.version_sync::text = p_version_sync
      and journey.revision_nomina > 0
      and revision.source_type = 'JOURNEY_REVISION'
      and revision.source_key = concat(journey.id, ':', journey.revision_nomina)
      and (revision.snapshot ->> 'revision')::bigint = journey.revision_nomina
      and coalesce((revision.snapshot ->> 'minutes')::integer, -1) = 0
      and (revision.snapshot ->> 'work_date')::date = journey.fecha_laboral
      and round(coalesce(
        (revision.snapshot ->> 'target_gross')::numeric, -1), 2) = 0
      and round(coalesce(
        (revision.snapshot ->> 'target_deductions')::numeric, -1), 2) = 0
      and round(coalesce(
        (revision.snapshot ->> 'target_net')::numeric, -1), 2) = 0
      and not exists (
        select 1
        from public.jornada_conflictos conflict
        where conflict.empresa_id = journey.empresa_id
          and conflict.jornada_id = journey.id
          and conflict.estado = 'PENDIENTE'
      )
  );
$$;

revoke all on function private.jornada_revision_cero_nomina_vigente(
  uuid, uuid, uuid, text
) from public, anon, authenticated, service_role;

create or replace function private.dependencias_nomina_vigentes(
  p_movimiento public.nomina_movimientos_tiempo_real
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not (p_movimiento.snapshot ? 'journey_dependencies') then true
    when jsonb_typeof(p_movimiento.snapshot -> 'journey_dependencies') <> 'array'
      or jsonb_array_length(p_movimiento.snapshot -> 'journey_dependencies') = 0
      then false
    else not exists (
      select 1
      from jsonb_array_elements_text(
        p_movimiento.snapshot -> 'journey_dependencies'
      ) dependency(source_key)
      where not exists (
        select 1
        from public.nomina_movimientos_tiempo_real control
        join public.jornadas journey
          on journey.empresa_id = control.empresa_id
         and journey.empleado_id = control.empleado_id
         and journey.id = control.jornada_id
        where control.empresa_id = p_movimiento.empresa_id
          and control.empleado_id = p_movimiento.empleado_id
          and control.ciclo_desde = p_movimiento.ciclo_desde
          and control.ciclo_hasta = p_movimiento.ciclo_hasta
          and control.source_type = 'JOURNEY'
          and control.source_key = dependency.source_key
          and journey.estado = 'FINALIZADA'
          and (
            journey.minutos_trabajados > 0
            or private.jornada_revision_cero_nomina_vigente(
              control.empresa_id, control.empleado_id, control.jornada_id,
              control.snapshot ->> 'version_sync'))
          and not journey.revision_pendiente
          and journey.version_sync::text = control.snapshot ->> 'version_sync'
          and not exists (
            select 1
            from public.jornada_conflictos conflict
            where conflict.empresa_id = journey.empresa_id
              and conflict.jornada_id = journey.id
              and conflict.estado = 'PENDIENTE'
          )
      )
    )
  end;
$$;

revoke all on function private.dependencias_nomina_vigentes(
  public.nomina_movimientos_tiempo_real
) from public, anon, authenticated, service_role;
create or replace function private.movimiento_nomina_es_pagable(
  p_movimiento public.nomina_movimientos_tiempo_real
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (
  (
    p_movimiento.source_type = 'JOURNEY_CORRECTION'
    and (
      p_movimiento.clase = 'DEVENGO'
      and p_movimiento.monto > 0
      or (p_movimiento.clase = 'DEDUCCION' and p_movimiento.monto > 0)
      or (p_movimiento.clase in (
        'REVERSO_DEVENGO', 'REVERSO_DEDUCCION') and p_movimiento.monto > 0)
    )
    and not coalesce((p_movimiento.snapshot ->> 'credit_source')::boolean, false)
    and exists (
      select 1
      from public.nomina_movimientos_tiempo_real revision
      join public.jornadas journey
        on journey.empresa_id = revision.empresa_id
       and journey.empleado_id = revision.empleado_id
       and journey.id = revision.jornada_id
      where revision.empresa_id = p_movimiento.empresa_id
        and revision.empleado_id = p_movimiento.empleado_id
        and revision.jornada_id = p_movimiento.jornada_id
        and revision.source_type = 'JOURNEY_REVISION'
        and revision.source_key = p_movimiento.snapshot ->> 'revision_key'
        and (
          coalesce((revision.snapshot ->> 'net_delta')::numeric, 0) >= 0
          or (
            (revision.snapshot ->> 'net_delta')::numeric < 0
            and not coalesce(
              (revision.snapshot ->> 'credit_source')::boolean, false)
            and not exists (
              select 1 from public.nomina_pago_jornadas paid
              where paid.empresa_id = revision.empresa_id
                and paid.jornada_id = revision.jornada_id
            )
          )
        )
        and journey.estado = 'FINALIZADA'
        and not journey.revision_pendiente
        and not exists (
          select 1
          from public.jornada_conflictos conflict
          where conflict.empresa_id = journey.empresa_id
            and conflict.jornada_id = journey.id
            and conflict.estado = 'PENDIENTE'
        )
    )
  ) or (
    p_movimiento.source_type = 'CORRECTION_CREDIT_APPLICATION'
    and p_movimiento.clase = 'DEDUCCION'
    and p_movimiento.monto > 0
    and exists (
      select 1
      from public.nomina_movimientos_tiempo_real credit
      where credit.empresa_id = p_movimiento.empresa_id
        and credit.empleado_id = p_movimiento.empleado_id
        and credit.source_type = 'JOURNEY_REVISION'
        and credit.source_key = p_movimiento.snapshot ->> 'credit_key'
        and coalesce(
          (credit.snapshot ->> 'credit_source')::boolean, false)
        and (credit.snapshot ->> 'net_delta')::numeric < 0
    )
    and exists (
      select 1
      from public.jornadas journey
      where journey.empresa_id = p_movimiento.empresa_id
        and journey.empleado_id = p_movimiento.empleado_id
        and journey.id = p_movimiento.jornada_id
        and journey.estado = 'FINALIZADA'
        and not journey.revision_pendiente
        and coalesce(
          (p_movimiento.snapshot ->> 'target_revision')::bigint,
          journey.revision_nomina
        ) = journey.revision_nomina
        and not exists (
          select 1
          from public.jornada_conflictos conflict
          where conflict.empresa_id = journey.empresa_id
            and conflict.jornada_id = journey.id
            and conflict.estado = 'PENDIENTE'
        )
    )
  ) or (
    p_movimiento.source_type not in (
      'JOURNEY_REVISION', 'JOURNEY_CORRECTION',
      'CORRECTION_CREDIT_APPLICATION'
    )
    and ((
    p_movimiento.jornada_id is null
    and p_movimiento.snapshot ? 'journey_dependencies'
    and private.dependencias_nomina_vigentes(p_movimiento)
    and exists (
      select 1
      from public.nomina_movimientos_tiempo_real control
      join public.jornadas journey
        on journey.empresa_id = control.empresa_id
       and journey.empleado_id = control.empleado_id
       and journey.id = control.jornada_id
      where control.empresa_id = p_movimiento.empresa_id
        and control.empleado_id = p_movimiento.empleado_id
        and control.ciclo_desde = p_movimiento.ciclo_desde
        and control.ciclo_hasta = p_movimiento.ciclo_hasta
        and control.source_type = 'JOURNEY'
        and control.clase = 'CONTROL'
        and journey.estado = 'FINALIZADA'
        and (
          journey.minutos_trabajados > 0
          or private.jornada_revision_cero_nomina_vigente(
            control.empresa_id, control.empleado_id, control.jornada_id,
            control.snapshot ->> 'version_sync'))
        and not journey.revision_pendiente
        and journey.version_sync::text = control.snapshot ->> 'version_sync'
        and not exists (
          select 1
          from public.jornada_conflictos conflict
          where conflict.empresa_id = journey.empresa_id
            and conflict.jornada_id = journey.id
            and conflict.estado = 'PENDIENTE'
        )
        and not exists (
          select 1
          from public.nomina_pago_jornadas paid
          where paid.empresa_id = journey.empresa_id
            and paid.jornada_id = journey.id
        )
        and not exists (
          select 1
          from public.nomina_pago_movimientos consumed
          where consumed.empresa_id = control.empresa_id
            and consumed.movimiento_id = control.id
        )
    )
  ) or exists (
    select 1
    from public.jornadas journey
    where journey.empresa_id = p_movimiento.empresa_id
      and journey.empleado_id = p_movimiento.empleado_id
      and journey.id = p_movimiento.jornada_id
      and journey.estado = 'FINALIZADA'
      and (
        journey.minutos_trabajados > 0
        or private.jornada_revision_cero_nomina_vigente(
          p_movimiento.empresa_id, p_movimiento.empleado_id,
          p_movimiento.jornada_id, p_movimiento.snapshot ->> 'version_sync'))
      and not journey.revision_pendiente
      and journey.version_sync::text = p_movimiento.snapshot ->> 'version_sync'
      and private.dependencias_nomina_vigentes(p_movimiento)
      and not exists (
        select 1
        from public.jornada_conflictos conflict
        where conflict.empresa_id = journey.empresa_id
          and conflict.jornada_id = journey.id
          and conflict.estado = 'PENDIENTE'
      )
      and not exists (
        select 1
        from public.nomina_pago_jornadas paid
        where paid.empresa_id = journey.empresa_id
          and paid.jornada_id = journey.id
      )
  )))
  )
  and (
    p_movimiento.ajuste_id is null
    or exists (
      select 1 from public.nomina_ajustes adjustment
      where adjustment.empresa_id = p_movimiento.empresa_id
        and adjustment.id = p_movimiento.ajuste_id
        and adjustment.activo
    )
  )
  and (
    p_movimiento.prestamo_id is null
    or exists (
      select 1 from public.nomina_prestamos loan
      where loan.empresa_id = p_movimiento.empresa_id
        and loan.id = p_movimiento.prestamo_id
        and loan.estado = 'ENTREGADO'
        and loan.pendiente > 0
    )
  )
  and (
    p_movimiento.credito_id is null
    or exists (
      select 1 from public.nomina_creditos credit
      where credit.empresa_id = p_movimiento.empresa_id
        and credit.id = p_movimiento.credito_id
        and credit.estado = 'ACTIVO'
        and credit.pendiente > 0
    )
  );
$$;

revoke all on function private.movimiento_nomina_es_pagable(
  public.nomina_movimientos_tiempo_real
) from public, anon, authenticated, service_role;
create or replace function private.correccion_nomina_convertida_credito(
  p_movimiento public.nomina_movimientos_tiempo_real
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_movimiento.source_type = 'JOURNEY_CORRECTION'
    and p_movimiento.monto > 0
    and p_movimiento.clase in (
      'DEVENGO', 'DEDUCCION', 'REVERSO_DEVENGO', 'REVERSO_DEDUCCION'
    )
    and coalesce(
      (p_movimiento.snapshot ->> 'credit_source')::boolean, false)
    and p_movimiento.source_key = concat(
      p_movimiento.snapshot ->> 'revision_key', ':', p_movimiento.concepto)
    and round((p_movimiento.snapshot ->> 'signed_delta')::numeric, 2)
      = round(case
          when p_movimiento.clase in ('DEVENGO', 'DEDUCCION')
            then p_movimiento.monto
          else -p_movimiento.monto
        end, 2)
    and round(
      (p_movimiento.snapshot ->> 'target')::numeric
      - (p_movimiento.snapshot ->> 'previous')::numeric, 2)
      = round((p_movimiento.snapshot ->> 'signed_delta')::numeric, 2)
    and exists (
      select 1
      from public.nomina_movimientos_tiempo_real revision
      join public.jornadas journey
        on journey.empresa_id = revision.empresa_id
       and journey.empleado_id = revision.empleado_id
       and journey.id = revision.jornada_id
      where revision.empresa_id = p_movimiento.empresa_id
        and revision.empleado_id = p_movimiento.empleado_id
        and revision.jornada_id = p_movimiento.jornada_id
        and revision.ciclo_desde = p_movimiento.ciclo_desde
        and revision.ciclo_hasta = p_movimiento.ciclo_hasta
        and revision.source_type = 'JOURNEY_REVISION'
        and revision.source_key = p_movimiento.snapshot ->> 'revision_key'
        and revision.snapshot ->> 'revision'
          = p_movimiento.snapshot ->> 'revision'
        and coalesce(
          (revision.snapshot ->> 'credit_source')::boolean, false)
        and (revision.snapshot ->> 'net_delta')::numeric < 0
        and journey.estado = 'FINALIZADA'
        and not journey.revision_pendiente
        and exists (
          select 1
          from public.nomina_pago_jornadas paid
          where paid.empresa_id = revision.empresa_id
            and paid.jornada_id = revision.jornada_id
        )
        and not exists (
          select 1
          from public.jornada_conflictos conflict
          where conflict.empresa_id = journey.empresa_id
            and conflict.jornada_id = journey.id
            and conflict.estado = 'PENDIENTE'
        )
        and round((
          select coalesce(sum(case correction.clase
            when 'DEVENGO' then correction.monto
            when 'REVERSO_DEVENGO' then -correction.monto
            when 'DEDUCCION' then -correction.monto
            when 'REVERSO_DEDUCCION' then correction.monto
            else 0 end), 0)
          from public.nomina_movimientos_tiempo_real correction
          where correction.empresa_id = revision.empresa_id
            and correction.empleado_id = revision.empleado_id
            and correction.source_type = 'JOURNEY_CORRECTION'
            and correction.snapshot ->> 'revision_key' = revision.source_key
        ), 2) = round((revision.snapshot ->> 'net_delta')::numeric, 2)
    );
$$;

revoke all on function private.correccion_nomina_convertida_credito(
  public.nomina_movimientos_tiempo_real
) from public, anon, authenticated, service_role;

create or replace function private.movimiento_nomina_es_reconciliable(
  p_movimiento public.nomina_movimientos_tiempo_real
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.movimiento_nomina_es_pagable(p_movimiento)
    or exists (
      select 1
      from public.nomina_pago_movimientos consumed
      where consumed.empresa_id = p_movimiento.empresa_id
        and consumed.movimiento_id = p_movimiento.id
    )
    or private.correccion_nomina_convertida_credito(p_movimiento);
$$;

revoke all on function private.movimiento_nomina_es_reconciliable(
  public.nomina_movimientos_tiempo_real
) from public, anon, authenticated, service_role;

create or replace function private.nomina_ciclo_canonico(
  p_empresa uuid,
  p_empleado uuid,
  p_fecha date,
  out ciclo_desde date,
  out ciclo_hasta date,
  out tipo_periodo text,
  out periodo_id uuid
)
returns record
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_variable
declare
  v_tipo_pago text;
begin
  select lower(e.tipo_pago)
  into v_tipo_pago
  from public.empleados e
  where e.empresa_id = p_empresa and e.id = p_empleado and e.activo;

  if not found or v_tipo_pago not in ('mensual', 'quincenal') then
    raise exception 'PAYROLL_EMPLOYEE_CONFIGURATION_INVALID:%', p_empleado;
  end if;

  if v_tipo_pago = 'mensual' then
    ciclo_desde := date_trunc('month', p_fecha)::date;
    ciclo_hasta := (date_trunc('month', p_fecha) + interval '1 month - 1 day')::date;
    tipo_periodo := 'MENSUAL';
  elsif extract(day from p_fecha) <= 15 then
    ciclo_desde := date_trunc('month', p_fecha)::date;
    ciclo_hasta := ciclo_desde + 14;
    tipo_periodo := 'QUINCENAL';
  else
    ciclo_desde := date_trunc('month', p_fecha)::date + 15;
    ciclo_hasta := (date_trunc('month', p_fecha) + interval '1 month - 1 day')::date;
    tipo_periodo := 'QUINCENAL';
  end if;

  select period.id
  into periodo_id
  from public.nomina_periodos period
  where period.empresa_id = p_empresa
    and period.fecha_inicio = ciclo_desde
    and period.fecha_fin = ciclo_hasta
    and period.tipo_periodo = tipo_periodo
    and period.estado <> 'ANULADA'
  order by period.creada_en desc, period.id
  limit 1;
end
$$;

create or replace function private.aplicar_creditos_correccion_nomina(
  p_empresa uuid,
  p_empleado uuid,
  p_jornada uuid,
  p_fecha_devengo date,
  p_ciclo_desde date,
  p_ciclo_hasta date,
  p_target_event text,
  p_reconcile_source text,
  p_disponible numeric,
  p_formula text,
  p_actor uuid
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  credit record;
  v_disponible numeric := round(greatest(coalesce(p_disponible, 0), 0), 2);
  v_aplicar numeric;
  v_count integer;
  v_rows integer := 0;
  v_reconcile_source text := coalesce(
    nullif(btrim(p_reconcile_source), ''), 'BASE'
  );
begin
  if v_disponible <= 0
     or p_empresa is null
     or p_empleado is null
     or p_jornada is null
     or btrim(coalesce(p_target_event, '')) = '' then
    return 0;
  end if;

  perform journey.id
  from public.jornadas journey
  where journey.empresa_id = p_empresa
    and journey.empleado_id = p_empleado
    and journey.id = p_jornada
    and journey.estado = 'FINALIZADA'
    and not journey.revision_pendiente
  for share;
  if not found then
    return 0;
  end if;

  -- The caller already follows journey -> employee; repeat the same order so a
  -- direct private invocation cannot race an accrual or payment.
  perform employee.id
  from public.empleados employee
  where employee.empresa_id = p_empresa
    and employee.id = p_empleado
  for update;
  if not found then
    return 0;
  end if;

  for credit in
    select
      revision.source_key as credit_key,
      revision.jornada_id as credit_journey_id,
      round(
        greatest(
          -(revision.snapshot ->> 'net_delta')::numeric
          - coalesce(sum(application.monto), 0),
          0
        ),
        2
      ) as residual
    from public.nomina_movimientos_tiempo_real revision
    left join public.nomina_movimientos_tiempo_real application
      on application.empresa_id = revision.empresa_id
     and application.empleado_id = revision.empleado_id
     and application.source_type = 'CORRECTION_CREDIT_APPLICATION'
     and application.snapshot ->> 'credit_key' = revision.source_key
     and (
       exists (
         select 1
         from public.nomina_pago_movimientos consumed
         where consumed.empresa_id = application.empresa_id
           and consumed.movimiento_id = application.id
       )
       or exists (
         select 1
         from public.jornadas target_journey
         where target_journey.empresa_id = application.empresa_id
           and target_journey.empleado_id = application.empleado_id
           and target_journey.id = application.jornada_id
           and coalesce(
             (application.snapshot ->> 'target_revision')::bigint,
             target_journey.revision_nomina
           ) = target_journey.revision_nomina
       )
     )
    where revision.empresa_id = p_empresa
      and revision.empleado_id = p_empleado
      and revision.source_type = 'JOURNEY_REVISION'
      and coalesce((revision.snapshot ->> 'credit_source')::boolean, false)
      and (revision.snapshot ->> 'net_delta')::numeric < 0
      and revision.fecha_devengo <= p_fecha_devengo
    group by
      revision.source_key,
      revision.jornada_id,
      revision.fecha_devengo,
      revision.snapshot
    having round(
      greatest(
        -(revision.snapshot ->> 'net_delta')::numeric
        - coalesce(sum(application.monto), 0),
        0
      ),
      2
    ) > 0
    order by revision.fecha_devengo, revision.source_key
  loop
    exit when v_disponible <= 0;
    v_aplicar := round(least(v_disponible, credit.residual), 2);
    if v_aplicar <= 0 then
      continue;
    end if;

    insert into public.nomina_movimientos_tiempo_real(
      empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
      source_type, source_key, clase, concepto, tipo, monto, formula, snapshot,
      jornada_id, creado_por
    ) values (
      p_empresa, p_empleado, p_ciclo_desde, p_ciclo_hasta, p_fecha_devengo,
      'CORRECTION_CREDIT_APPLICATION',
      concat(
        credit.credit_key, ':', p_target_event, ':REV:',
        (
          select journey.revision_nomina
          from public.jornadas journey
          where journey.empresa_id = p_empresa
            and journey.empleado_id = p_empleado
            and journey.id = p_jornada
        ),
        ':SOURCE:', v_reconcile_source
      ),
      'DEDUCCION', 'COMPANY_CREDIT', 'CORRECCION_JORNADA', v_aplicar,
      p_formula,
      jsonb_build_object(
        'credit_key', credit.credit_key,
        'credit_journey_id', credit.credit_journey_id,
        'target_event', p_target_event,
        'reconcile_source', v_reconcile_source,
        'target_journey_id', p_jornada,
        'target_revision', (
          select journey.revision_nomina
          from public.jornadas journey
          where journey.empresa_id = p_empresa
            and journey.empleado_id = p_empleado
            and journey.id = p_jornada
        ),
        'residual_before', credit.residual,
        'applied', v_aplicar
      ),
      p_jornada, p_actor
    )
    on conflict (empresa_id, source_type, source_key) do nothing;
    get diagnostics v_count = row_count;
    if v_count = 1 then
      v_rows := v_rows + 1;
      v_disponible := round(v_disponible - v_aplicar, 2);
    end if;
  end loop;

  return v_rows;
end
$$;

revoke all on function private.aplicar_creditos_correccion_nomina(
  uuid, uuid, uuid, date, date, date, text, text, numeric, text, uuid
) from public, anon, authenticated, service_role;

create or replace function private.devengar_movimientos_nomina_jornada(
  p_empresa uuid,
  p_jornada uuid,
  p_reconcile_source text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_journey public.jornadas%rowtype;
  v_employee public.empleados%rowtype;
  v_rule public.nomina_reglas_empleado%rowtype;
  v_cycle record;
  v_calc_start date;
  v_calc_event jsonb;
  v_calc_cycle jsonb;
  v_formula text;
  v_event_key text;
  v_target numeric;
  v_existing numeric;
  v_delta numeric;
  v_item jsonb;
  v_applied numeric;
  v_source_kind text;

  v_source_id uuid;
  v_concept text;
  v_type text;
  v_source_key text;
  v_prev_nomina uuid;
  v_carry record;
  v_carry_target numeric;
  v_carry_remaining numeric;
  v_carry_apply numeric;
  v_dependencies jsonb;
  v_dependency_hash text;
  v_has_base boolean := false;
  v_latest_version bigint := 0;
  v_previous_net numeric := 0;
  v_previous_gross numeric := 0;
  v_previous_deductions numeric := 0;
  v_current_net numeric;
  v_correction_delta numeric;
  v_journey_found boolean := false;
  v_was_paid boolean := false;
  v_revision_inserted integer := 0;
  v_base_snapshot jsonb;
  v_inserted integer := 0;
begin
  select journey.*
  into v_journey
  from public.jornadas journey
  where journey.empresa_id = p_empresa and journey.id = p_jornada
  for share;

  v_journey_found := found;
  if v_journey_found then
    select coalesce(max(
      (revision.snapshot ->> 'revision')::bigint
    ), 0)
    into v_latest_version
    from public.nomina_movimientos_tiempo_real revision
    where revision.empresa_id = p_empresa
      and revision.empleado_id = v_journey.empleado_id
      and revision.jornada_id = v_journey.id
      and revision.source_type = 'JOURNEY_REVISION';
  end if;

  if not v_journey_found
     or v_journey.estado <> 'FINALIZADA'
     or (v_journey.minutos_trabajados <= 0 and v_journey.revision_nomina = 0)
     or v_journey.revision_pendiente then
    return jsonb_build_object('status', 'SKIPPED', 'inserted', 0);
  end if;
  if exists (
    select 1
    from public.jornada_conflictos conflict
    where conflict.empresa_id = p_empresa
      and conflict.jornada_id = p_jornada
      and conflict.estado = 'PENDIENTE'
  ) then
    return jsonb_build_object('status', 'BLOCKED_CONFLICT', 'inserted', 0);
  end if;

  if exists (
    select 1
    from public.nomina_pago_cortes_legacy legacy_cut
    where legacy_cut.empresa_id = p_empresa
      and legacy_cut.empleado_id = v_journey.empleado_id
      and v_journey.fecha_laboral <= legacy_cut.fecha_corte
  ) then
    return jsonb_build_object('status', 'SKIPPED_LEGACY', 'inserted', 0);
  end if;

  -- Uniform lock order is journey then employee. Jornada UPDATE already owns
  -- the tuple before its BEFORE trigger takes this employee lock.
  select employee.*
  into v_employee
  from public.empleados employee
  where employee.empresa_id = p_empresa
    and employee.id = v_journey.empleado_id
    and employee.activo
  for update;
  if not found then
    raise exception 'EMPLEADO_NO_ENCONTRADO';
  end if;

  -- Re-read the claimed revision only after the employee lock. Concurrent
  -- attempts then observe the winner before deriving any monetary delta.
  select coalesce(max(
    (revision.snapshot ->> 'revision')::bigint
  ), 0)
  into v_latest_version
  from public.nomina_movimientos_tiempo_real revision
  where revision.empresa_id = p_empresa
    and revision.empleado_id = v_journey.empleado_id
    and revision.jornada_id = v_journey.id
    and revision.source_type = 'JOURNEY_REVISION';

  -- A conflict INSERT serializes on the same employee; repeat the check after
  -- acquiring the employee lock to observe any transaction that won the race.
  if exists (
    select 1
    from public.jornada_conflictos conflict
    where conflict.empresa_id = p_empresa
      and conflict.jornada_id = p_jornada
      and conflict.estado = 'PENDIENTE'
  ) then
    return jsonb_build_object('status', 'BLOCKED_CONFLICT', 'inserted', 0);
  end if;

  select rule_row.*
  into v_rule
  from public.nomina_reglas_empleado rule_row
  where rule_row.empresa_id = p_empresa
    and rule_row.empleado_id = v_employee.id
    and rule_row.nomina_activa;
  if not found
     or coalesce(v_employee.salario, 0) <= 0
     or coalesce(v_rule.dias_divisor_quincenal, 0) <= 0
     or coalesce(v_rule.horas_dia, 0) <= 0 then
    raise exception 'PAYROLL_EMPLOYEE_CONFIGURATION_INVALID:%', v_employee.id;
  end if;

  select *
  into v_cycle
  from private.nomina_ciclo_canonico(p_empresa, v_employee.id, v_journey.fecha_laboral);

  -- Stable source-event identity: replaying an older journey after another
  -- journey closes in the cycle must not turn it into a new accrual event.
  v_event_key := concat(
    v_journey.id, ':',
    to_char(v_cycle.ciclo_desde, 'YYYYMMDD'), ':',
    to_char(v_cycle.ciclo_hasta, 'YYYYMMDD')
  );
  v_calc_start := v_cycle.ciclo_desde;
  select greatest(v_calc_start, legacy_cut.fecha_corte + 1)
  into v_calc_start
  from public.nomina_pago_cortes_legacy legacy_cut
  where legacy_cut.empresa_id = p_empresa
    and legacy_cut.empleado_id = v_employee.id;
  v_calc_start := coalesce(v_calc_start, v_cycle.ciclo_desde);

  select payroll.id
  into v_prev_nomina
  from public.nomina_periodos period
  join public.nominas payroll
    on payroll.empresa_id = period.empresa_id
   and payroll.periodo_id = period.id
   and payroll.estado = 'CERRADA'
  join public.nomina_detalles detail
    on detail.empresa_id = payroll.empresa_id
   and detail.nomina_id = payroll.id
   and detail.empleado_id = v_employee.id
  where period.empresa_id = p_empresa
    and period.estado = 'CERRADA'
    and period.fecha_fin < v_calc_start
  order by period.fecha_fin desc, period.cerrada_en desc nulls last
  limit 1;

  -- The event calculation is authoritative for this journey's own earned
  -- minutes and amounts. The cycle calculation is used only as an accumulated
  -- target for once-per-cycle components and deductions.
  v_calc_event := public.nomina_calculo_empleado_v3(
    p_empresa,
    v_employee.id,
    v_journey.fecha_laboral,
    v_journey.fecha_laboral,
    v_cycle.tipo_periodo,
    v_cycle.periodo_id
  );
  v_calc_cycle := public.nomina_calculo_empleado_v3(
    p_empresa,
    v_employee.id,
    v_calc_start,
    v_cycle.ciclo_hasta,
    v_cycle.tipo_periodo,
    v_cycle.periodo_id
  );
  v_formula := v_calc_event ->> 'formula';
  if v_journey.revision_nomina > 0 then
    if v_journey.revision_nomina <= v_latest_version then
      return jsonb_build_object(
        'status', 'REPLAYED_CORRECTION',
        'inserted', 0,
        'revision', v_journey.revision_nomina
      );
    end if;
    if v_journey.revision_nomina <> v_latest_version + 1 then
      raise exception 'PAYROLL_JOURNEY_REVISION_SEQUENCE_INVALID';
    end if;

    v_source_key := concat(v_journey.id, ':', v_journey.revision_nomina);
    select base.snapshot
    into v_base_snapshot
    from public.nomina_movimientos_tiempo_real base
    where base.empresa_id = p_empresa
      and base.empleado_id = v_employee.id
      and base.jornada_id = v_journey.id
      and base.source_type = 'JOURNEY'
      and base.source_key = v_journey.id::text;
    if not found then
      raise exception 'PAYROLL_JOURNEY_BASE_ACCRUAL_REQUIRED';
    end if;

    v_item := jsonb_build_object(
      'target_normal_pay',
        round(coalesce((v_calc_event ->> 'normal_pay')::numeric, 0), 2),
      'target_overtime_pay',
        round(coalesce((v_calc_event ->> 'overtime_pay')::numeric, 0), 2),
      'target_afp',
        case when coalesce(v_rule.afp_modo, 'MONTO') = 'PORCENTAJE'
          then round(coalesce(
            (v_calc_event #>> '{deductions,afp,applied}')::numeric, 0), 2)
          else coalesce(
            (v_base_snapshot ->> 'target_afp')::numeric,
            (v_base_snapshot ->> 'afp')::numeric, 0)
        end,
      'target_sfs',
        case when coalesce(v_rule.sfs_modo, 'MONTO') = 'PORCENTAJE'
          then round(coalesce(
            (v_calc_event #>> '{deductions,sfs,applied}')::numeric, 0), 2)
          else coalesce(
            (v_base_snapshot ->> 'target_sfs')::numeric,
            (v_base_snapshot ->> 'sfs')::numeric, 0)
        end,
      'target_other_tax',
        case when coalesce(v_rule.otros_impuestos_modo, 'MONTO') = 'PORCENTAJE'
          then round(coalesce(
            (v_calc_event #>> '{deductions,other_taxes,applied}')::numeric, 0), 2)
          else coalesce(
            (v_base_snapshot ->> 'target_other_tax')::numeric,
            (v_base_snapshot ->> 'other_tax')::numeric, 0)
        end
    );
    v_previous_gross := round(
      coalesce(
        (v_base_snapshot ->> 'target_normal_pay')::numeric,
        (v_base_snapshot ->> 'normal_pay')::numeric, 0)
      + coalesce(
        (v_base_snapshot ->> 'target_overtime_pay')::numeric,
        (v_base_snapshot ->> 'overtime_pay')::numeric, 0),
      2
    );
    v_previous_deductions := round(
      coalesce(
        (v_base_snapshot ->> 'target_afp')::numeric,
        (v_base_snapshot ->> 'afp')::numeric, 0)
      + coalesce(
        (v_base_snapshot ->> 'target_sfs')::numeric,
        (v_base_snapshot ->> 'sfs')::numeric, 0)
      + coalesce(
        (v_base_snapshot ->> 'target_other_tax')::numeric,
        (v_base_snapshot ->> 'other_tax')::numeric, 0),
      2
    );
    select
      round(v_previous_gross + coalesce(sum(case correction.concepto
        when 'NORMAL_PAY' then
          (correction.snapshot ->> 'signed_delta')::numeric
        when 'OVERTIME_PAY' then
          (correction.snapshot ->> 'signed_delta')::numeric
        else 0 end), 0), 2),
      round(v_previous_deductions + coalesce(sum(case correction.concepto
        when 'AFP' then (correction.snapshot ->> 'signed_delta')::numeric
        when 'SFS' then (correction.snapshot ->> 'signed_delta')::numeric
        when 'OTHER_TAX' then (correction.snapshot ->> 'signed_delta')::numeric
        else 0 end), 0), 2)
    into v_previous_gross, v_previous_deductions
    from public.nomina_movimientos_tiempo_real correction
    where correction.empresa_id = p_empresa
      and correction.empleado_id = v_employee.id
      and correction.jornada_id = v_journey.id
      and correction.source_type = 'JOURNEY_CORRECTION';
    v_previous_net := round(v_previous_gross - v_previous_deductions, 2);
    v_base_snapshot := v_base_snapshot || jsonb_build_object(
      'target_normal_pay', round(
        coalesce((v_base_snapshot ->> 'normal_pay')::numeric, 0)
        + coalesce((select sum(
            (correction.snapshot ->> 'signed_delta')::numeric)
          from public.nomina_movimientos_tiempo_real correction
          where correction.empresa_id = p_empresa
            and correction.empleado_id = v_employee.id
            and correction.jornada_id = v_journey.id
            and correction.source_type = 'JOURNEY_CORRECTION'
            and correction.concepto = 'NORMAL_PAY'), 0), 2),
      'target_overtime_pay', round(
        coalesce((v_base_snapshot ->> 'overtime_pay')::numeric, 0)
        + coalesce((select sum(
            (correction.snapshot ->> 'signed_delta')::numeric)
          from public.nomina_movimientos_tiempo_real correction
          where correction.empresa_id = p_empresa
            and correction.empleado_id = v_employee.id
            and correction.jornada_id = v_journey.id
            and correction.source_type = 'JOURNEY_CORRECTION'
            and correction.concepto = 'OVERTIME_PAY'), 0), 2),
      'target_afp', round(
        coalesce((v_base_snapshot ->> 'afp')::numeric, 0)
        + coalesce((select sum(
            (correction.snapshot ->> 'signed_delta')::numeric)
          from public.nomina_movimientos_tiempo_real correction
          where correction.empresa_id = p_empresa
            and correction.empleado_id = v_employee.id
            and correction.jornada_id = v_journey.id
            and correction.source_type = 'JOURNEY_CORRECTION'
            and correction.concepto = 'AFP'), 0), 2),
      'target_sfs', round(
        coalesce((v_base_snapshot ->> 'sfs')::numeric, 0)
        + coalesce((select sum(
            (correction.snapshot ->> 'signed_delta')::numeric)
          from public.nomina_movimientos_tiempo_real correction
          where correction.empresa_id = p_empresa
            and correction.empleado_id = v_employee.id
            and correction.jornada_id = v_journey.id
            and correction.source_type = 'JOURNEY_CORRECTION'
            and correction.concepto = 'SFS'), 0), 2),
      'target_other_tax', round(
        coalesce((v_base_snapshot ->> 'other_tax')::numeric, 0)
        + coalesce((select sum(
            (correction.snapshot ->> 'signed_delta')::numeric)
          from public.nomina_movimientos_tiempo_real correction
          where correction.empresa_id = p_empresa
            and correction.empleado_id = v_employee.id
            and correction.jornada_id = v_journey.id
            and correction.source_type = 'JOURNEY_CORRECTION'
            and correction.concepto = 'OTHER_TAX'), 0), 2)
    );
    v_target := round(
      (v_item ->> 'target_normal_pay')::numeric
      + (v_item ->> 'target_overtime_pay')::numeric,
      2
    );
    v_existing := round(
      (v_item ->> 'target_afp')::numeric
      + (v_item ->> 'target_sfs')::numeric
      + (v_item ->> 'target_other_tax')::numeric,
      2
    );
    v_applied := v_existing;
    v_current_net := round(v_target - v_existing, 2);
    v_correction_delta := round(v_current_net - v_previous_net, 2);
    select exists (
      select 1
      from public.nomina_pago_jornadas paid
      where paid.empresa_id = p_empresa
        and paid.jornada_id = v_journey.id
    )
    into v_was_paid;

    insert into public.nomina_movimientos_tiempo_real(
      empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
      source_type, source_key, clase, concepto, monto, formula, snapshot,
      jornada_id, creado_por
    ) values (
      p_empresa, v_employee.id, v_cycle.ciclo_desde, v_cycle.ciclo_hasta,
      v_journey.fecha_laboral, 'JOURNEY_REVISION', v_source_key,
      'CONTROL', 'JOURNEY_REVISION', 0, v_formula,
      v_item || jsonb_build_object(
        'revision', v_journey.revision_nomina,
        'previous_gross', v_previous_gross,
        'previous_deductions', v_previous_deductions,
        'previous_net', v_previous_net,
        'target_gross', v_target,
        'target_deductions', v_applied,
        'target_net', v_current_net,
        'net_delta', v_correction_delta,
        'credit_source', v_was_paid and v_correction_delta < 0,
        'minutes', v_journey.minutos_trabajados,
        'normal_minutes',
          coalesce((v_calc_event ->> 'normal_minutes')::integer, 0),
        'overtime_minutes',
          coalesce((v_calc_event ->> 'overtime_minutes')::integer, 0),
        'work_date', v_journey.fecha_laboral,
        'updated_at', v_journey.actualizada_en,
        'actor_id', auth.uid()
      ),
      v_journey.id, auth.uid()
    )
    on conflict (empresa_id, source_type, source_key) do nothing;
    get diagnostics v_revision_inserted = row_count;
    if v_revision_inserted = 0 then
      return jsonb_build_object(
        'status', 'REPLAYED_CORRECTION',
        'inserted', 0,
        'revision', v_journey.revision_nomina
      );
    end if;
    v_inserted := 1;

    insert into public.nomina_movimientos_tiempo_real(
      empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
      source_type, source_key, clase, concepto, tipo, monto, formula, snapshot,
      jornada_id, creado_por
    )
    select
      p_empresa, v_employee.id, v_cycle.ciclo_desde, v_cycle.ciclo_hasta,
      v_journey.fecha_laboral, 'JOURNEY_CORRECTION',
      concat(v_source_key, ':', component.concept),
      case
        when not component.is_deduction and component.delta > 0 then 'DEVENGO'
        when not component.is_deduction then 'REVERSO_DEVENGO'
        when component.delta > 0 then 'DEDUCCION'
        else 'REVERSO_DEDUCCION'
      end,
      component.concept,
      case when component.is_deduction then component.concept else null end,
      abs(component.delta),
      v_formula,
      jsonb_build_object(
        'revision_key', v_source_key,
        'revision', v_journey.revision_nomina,
        'target', component.target,
        'previous', component.previous,
        'signed_delta', component.delta,
        'credit_source', v_was_paid and v_correction_delta < 0
      ),
      v_journey.id, auth.uid()
    from (
      select
        values_row.concept,
        values_row.target,
        values_row.previous,
        values_row.is_deduction,
        round(values_row.target - values_row.previous, 2) as delta
      from (values
        (
          'NORMAL_PAY'::text,
          (v_item ->> 'target_normal_pay')::numeric,
          coalesce(
            (v_base_snapshot ->> 'target_normal_pay')::numeric,
            (v_base_snapshot ->> 'normal_pay')::numeric, 0),
          false
        ),
        (
          'OVERTIME_PAY',
          (v_item ->> 'target_overtime_pay')::numeric,
          coalesce(
            (v_base_snapshot ->> 'target_overtime_pay')::numeric,
            (v_base_snapshot ->> 'overtime_pay')::numeric, 0),
          false
        ),
        (
          'AFP',
          (v_item ->> 'target_afp')::numeric,
          coalesce(
            (v_base_snapshot ->> 'target_afp')::numeric,
            (v_base_snapshot ->> 'afp')::numeric, 0),
          true
        ),
        (
          'SFS',
          (v_item ->> 'target_sfs')::numeric,
          coalesce(
            (v_base_snapshot ->> 'target_sfs')::numeric,
            (v_base_snapshot ->> 'sfs')::numeric, 0),
          true
        ),
        (
          'OTHER_TAX',
          (v_item ->> 'target_other_tax')::numeric,
          coalesce(
            (v_base_snapshot ->> 'target_other_tax')::numeric,
            (v_base_snapshot ->> 'other_tax')::numeric, 0),
          true
        )
      ) values_row(concept, target, previous, is_deduction)
    ) component
    where component.delta <> 0
    on conflict (empresa_id, source_type, source_key) do nothing;
    get diagnostics v_existing = row_count;
    v_inserted := v_inserted + v_existing::integer;

    insert into public.nomina_auditoria(
      empresa_id, empleado_id, actor_id, accion, antes, despues, motivo
    ) values (
      p_empresa, v_employee.id, auth.uid(), 'CORRECCION_JORNADA',
      jsonb_build_object(
        'journey_id', v_journey.id,
        'revision', v_journey.revision_nomina - 1,
        'gross', v_previous_gross,
        'deductions', v_previous_deductions,
        'net', v_previous_net
      ),
      jsonb_build_object(
        'journey_id', v_journey.id,
        'revision', v_journey.revision_nomina,
        'gross', v_target,
        'deductions', v_applied,
        'net', v_current_net,
        'delta', v_correction_delta,
        'was_paid', v_was_paid
      ),
      'Correccion inmutable de jornada devengada'
    );

    -- A correction is itself a source event. Reconcile an older company credit
    -- against the newly accrued positive difference on this exact date/revision.
    -- Queries never call this path.
    select round(greatest(
      coalesce(sum(case movement.clase
        when 'DEVENGO' then movement.monto
        when 'REVERSO_DEDUCCION' then movement.monto
        when 'DEDUCCION' then -movement.monto
        when 'REVERSO_DEVENGO' then -movement.monto
        else 0 end), 0)
      - coalesce((
          select sum(application.monto)
          from public.nomina_movimientos_tiempo_real application
          where application.empresa_id = p_empresa
            and application.empleado_id = v_employee.id
            and application.ciclo_desde = v_cycle.ciclo_desde
            and application.ciclo_hasta = v_cycle.ciclo_hasta
            and application.fecha_devengo = v_journey.fecha_laboral
            and application.source_type = 'CORRECTION_CREDIT_APPLICATION'
            and private.movimiento_nomina_es_pagable(application)
            and not exists (
              select 1
              from public.nomina_pago_movimientos consumed
              where consumed.empresa_id = application.empresa_id
                and consumed.movimiento_id = application.id
            )
        ), 0),
      0
    ), 2)
    into v_applied
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = p_empresa
      and movement.empleado_id = v_employee.id
      and movement.ciclo_desde = v_cycle.ciclo_desde
      and movement.ciclo_hasta = v_cycle.ciclo_hasta
      and movement.fecha_devengo = v_journey.fecha_laboral
      and movement.source_type <> 'CORRECTION_CREDIT_APPLICATION'
      and private.movimiento_nomina_es_pagable(movement)
      and not exists (
        select 1
        from public.nomina_pago_movimientos consumed
        where consumed.empresa_id = movement.empresa_id
          and consumed.movimiento_id = movement.id
      );

    v_inserted := v_inserted + private.aplicar_creditos_correccion_nomina(
      p_empresa,
      v_employee.id,
      v_journey.id,
      v_journey.fecha_laboral,
      v_cycle.ciclo_desde,
      v_cycle.ciclo_hasta,
      concat('CORRECTION:', v_source_key),
      concat('JOURNEY_REVISION:', v_source_key),
      v_applied,
      'RC4_WORKED_MINUTES_V3_NET_FLOOR',
      auth.uid()
    );

    return jsonb_build_object(
      'status', case
        when v_was_paid and v_correction_delta < 0
          then 'ACCRUED_CORRECTION_CREDIT'
        else 'ACCRUED_CORRECTION'
      end,
      'inserted', v_inserted,
      'revision', v_journey.revision_nomina,
      'net_delta', v_correction_delta
    );
  end if;

  if round(
    coalesce((v_calc_event ->> 'normal_pay')::numeric, 0)
    + coalesce((v_calc_event ->> 'overtime_pay')::numeric, 0),
    2
  ) <= 0 then
    return jsonb_build_object('status', 'SKIPPED_ZERO_EARNED', 'inserted', 0);
  end if;

  -- Claim every valid journey source visible in this canonical cycle. This is a
  -- zero-value control movement; it is later linked to exactly one payment.
  insert into public.nomina_movimientos_tiempo_real(
    empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
    source_type, source_key, clase, concepto, monto, formula, snapshot,
    jornada_id, creado_por
  )
  select
    journey.empresa_id,
    journey.empleado_id,
    v_cycle.ciclo_desde,
    v_cycle.ciclo_hasta,
    journey.fecha_laboral,
    'JOURNEY',
    journey.id::text,
    'CONTROL',
    'JOURNEY',
    0,
    'RC4_WORKED_MINUTES_V3_NET_FLOOR',
    jsonb_build_object(
      'minutes', journey.minutos_trabajados,
      'normal_minutes', (v_calc_event ->> 'normal_minutes')::integer,
      'overtime_minutes', (v_calc_event ->> 'overtime_minutes')::integer,
      'normal_pay', round((v_calc_event ->> 'normal_pay')::numeric, 2),
      'overtime_pay', round((v_calc_event ->> 'overtime_pay')::numeric, 2),
      'earned', round(
        (v_calc_event ->> 'normal_pay')::numeric
        + (v_calc_event ->> 'overtime_pay')::numeric,
        2
      ),
      'afp', case
        when coalesce(v_rule.afp_modo, 'MONTO') = 'PORCENTAJE'
          then round(coalesce(
            (v_calc_event #>> '{deductions,afp,applied}')::numeric, 0), 2)
        else 0 end,
      'sfs', case
        when coalesce(v_rule.sfs_modo, 'MONTO') = 'PORCENTAJE'
          then round(coalesce(
            (v_calc_event #>> '{deductions,sfs,applied}')::numeric, 0), 2)
        else 0 end,
      'other_tax', case
        when coalesce(v_rule.otros_impuestos_modo, 'MONTO') = 'PORCENTAJE'
          then round(coalesce(
            (v_calc_event #>> '{deductions,other_taxes,applied}')::numeric, 0), 2)
        else 0 end,
      'work_date', journey.fecha_laboral,
      'version_sync', journey.version_sync,
      'updated_at', journey.actualizada_en
    ),
    journey.id,
    auth.uid()
  from public.jornadas journey
  where journey.empresa_id = p_empresa
    and journey.empleado_id = v_employee.id
    and journey.id = v_journey.id
    and journey.fecha_laboral between v_cycle.ciclo_desde and v_cycle.ciclo_hasta
    and journey.estado = 'FINALIZADA'
    and journey.minutos_trabajados > 0
    and not journey.revision_pendiente
    and not exists (
      select 1 from public.jornada_conflictos conflict
      where conflict.empresa_id = journey.empresa_id
        and conflict.jornada_id = journey.id
        and conflict.estado = 'PENDIENTE'
    )
    and not exists (
      select 1 from public.nomina_pago_cortes_legacy legacy_cut
      where legacy_cut.empresa_id = journey.empresa_id
        and legacy_cut.empleado_id = journey.empleado_id
        and journey.fecha_laboral <= legacy_cut.fecha_corte
    )
    and not exists (
      select 1 from public.nomina_pago_jornadas paid
      where paid.empresa_id = journey.empresa_id
        and paid.jornada_id = journey.id
    )
    and not exists (
      select 1 from public.nomina_movimientos_tiempo_real prior_source
      where prior_source.empresa_id = journey.empresa_id
        and prior_source.empleado_id = journey.empleado_id
        and prior_source.source_type = 'JOURNEY'
        and prior_source.jornada_id = journey.id
        and prior_source.source_key = journey.id::text
    )
  on conflict (empresa_id, source_type, source_key) do nothing;
  get diagnostics v_inserted = row_count;

  -- Every journey owns its own normal/extra movement and accrual date. A tiny
  -- cycle rounding movement reconciles per-source cents with the authoritative
  -- aggregate V3 result; no daily filter can absorb another journey's earnings.
  insert into public.nomina_movimientos_tiempo_real(
    empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
    source_type, source_key, clase, concepto, monto, formula, snapshot,
    jornada_id, creado_por
  )
  select
    journey.empresa_id, journey.empleado_id,
    v_cycle.ciclo_desde, v_cycle.ciclo_hasta, journey.fecha_laboral,
    'JOURNEY_NORMAL', journey.id::text,
    'DEVENGO', 'NORMAL_PAY', amounts.normal_pay, v_formula,
    jsonb_build_object(
      'minutes', amounts.normal_minutes,
      'hourly_rate', amounts.hourly_rate,
      'version_sync', journey.version_sync
    ),
    journey.id, auth.uid()
  from public.jornadas journey
  cross join lateral (
    select
      (v_calc_event ->> 'normal_minutes')::numeric as normal_minutes,
      (v_calc_event ->> 'hourly_rate')::numeric as hourly_rate,
      round(
        coalesce((v_calc_event ->> 'normal_pay')::numeric, 0),
        2
      ) as normal_pay
  ) amounts
  where journey.empresa_id = p_empresa
    and journey.empleado_id = v_employee.id
    and journey.id = v_journey.id
    and journey.estado = 'FINALIZADA'
    and journey.minutos_trabajados > 0
    and not journey.revision_pendiente
    and amounts.normal_pay <> 0
    and not exists (
      select 1 from public.jornada_conflictos conflict
      where conflict.empresa_id = journey.empresa_id
        and conflict.jornada_id = journey.id
        and conflict.estado = 'PENDIENTE'
    )
    and not exists (
      select 1 from public.nomina_pago_cortes_legacy legacy_cut
      where legacy_cut.empresa_id = journey.empresa_id
        and legacy_cut.empleado_id = journey.empleado_id
        and journey.fecha_laboral <= legacy_cut.fecha_corte
    )
    and not exists (
      select 1 from public.nomina_pago_jornadas paid
      where paid.empresa_id = journey.empresa_id and paid.jornada_id = journey.id
    )
  on conflict (empresa_id, source_type, source_key) do nothing;
  get diagnostics v_existing = row_count;
  v_inserted := v_inserted + v_existing::integer;

  insert into public.nomina_movimientos_tiempo_real(
    empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
    source_type, source_key, clase, concepto, monto, formula, snapshot,
    jornada_id, creado_por
  )
  select
    journey.empresa_id, journey.empleado_id,
    v_cycle.ciclo_desde, v_cycle.ciclo_hasta, journey.fecha_laboral,
    'JOURNEY_OVERTIME', journey.id::text,
    'DEVENGO', 'OVERTIME_PAY', amounts.overtime_pay, v_formula,
    jsonb_build_object(
      'minutes', amounts.overtime_minutes,
      'version_sync', journey.version_sync
    ),
    journey.id, auth.uid()
  from public.jornadas journey
  cross join lateral (
    select
      (v_calc_event ->> 'overtime_minutes')::numeric as overtime_minutes,
      round(
        coalesce((v_calc_event ->> 'overtime_pay')::numeric, 0),
        2
      ) as overtime_pay
  ) amounts
  where journey.empresa_id = p_empresa
    and journey.empleado_id = v_employee.id
    and journey.id = v_journey.id
    and journey.estado = 'FINALIZADA'
    and journey.minutos_trabajados > 0
    and not journey.revision_pendiente
    and amounts.overtime_pay <> 0
    and not exists (
      select 1 from public.jornada_conflictos conflict
      where conflict.empresa_id = journey.empresa_id
        and conflict.jornada_id = journey.id
        and conflict.estado = 'PENDIENTE'
    )
    and not exists (
      select 1 from public.nomina_pago_cortes_legacy legacy_cut
      where legacy_cut.empresa_id = journey.empresa_id
        and legacy_cut.empleado_id = journey.empleado_id
        and journey.fecha_laboral <= legacy_cut.fecha_corte
    )
    and not exists (
      select 1 from public.nomina_pago_jornadas paid
      where paid.empresa_id = journey.empresa_id and paid.jornada_id = journey.id
    )
  on conflict (empresa_id, source_type, source_key) do nothing;
  get diagnostics v_existing = row_count;
  v_inserted := v_inserted + v_existing::integer;

  -- Reconcile V3 cents only after every currently eligible source in the cycle
  -- has a CONTROL for its current version. This preserves the shared V3 engine,
  -- handles multi-row/out-of-order finalization, and never attributes a future
  -- journey's earnings to an earlier daily source.
  if not exists (
    select 1
    from public.jornadas journey
    where journey.empresa_id = p_empresa
      and journey.empleado_id = v_employee.id
      and journey.fecha_laboral between v_calc_start and v_cycle.ciclo_hasta
      and journey.estado = 'FINALIZADA'
      and journey.minutos_trabajados > 0
      and not journey.revision_pendiente
      and not exists (
        select 1 from public.jornada_conflictos conflict
        where conflict.empresa_id = journey.empresa_id
          and conflict.jornada_id = journey.id
          and conflict.estado = 'PENDIENTE'
      )
      and not exists (
        select 1 from public.nomina_pago_jornadas paid
        where paid.empresa_id = journey.empresa_id and paid.jornada_id = journey.id
      )
      and not exists (
        select 1 from public.nomina_movimientos_tiempo_real control
        where control.empresa_id = journey.empresa_id
          and control.empleado_id = journey.empleado_id
          and control.jornada_id = journey.id
          and control.source_type = 'JOURNEY'
          and control.source_key = journey.id::text
      )
  ) then
    select coalesce(
      jsonb_agg(control.source_key order by journey.fecha_laboral, journey.id),
      '[]'::jsonb
    )
    into v_dependencies
    from public.nomina_movimientos_tiempo_real control
    join public.jornadas journey
      on journey.empresa_id = control.empresa_id
     and journey.empleado_id = control.empleado_id
     and journey.id = control.jornada_id
    where control.empresa_id = p_empresa
      and control.empleado_id = v_employee.id
      and control.ciclo_desde = v_cycle.ciclo_desde
      and control.ciclo_hasta = v_cycle.ciclo_hasta
      and control.source_type = 'JOURNEY'
      and control.source_key = journey.id::text
      and journey.estado = 'FINALIZADA'
      and journey.minutos_trabajados > 0
      and not journey.revision_pendiente
      and not exists (
        select 1 from public.jornada_conflictos conflict
        where conflict.empresa_id = journey.empresa_id
          and conflict.jornada_id = journey.id
          and conflict.estado = 'PENDIENTE'
      );
    v_dependency_hash := encode(
      extensions.digest(convert_to(v_dependencies::text, 'UTF8'), 'sha256'),
      'hex'
    );

    foreach v_concept in array array['NORMAL_PAY', 'OVERTIME_PAY']::text[] loop
      v_target := round(coalesce(
        case v_concept
          when 'NORMAL_PAY' then (v_calc_cycle ->> 'normal_pay')::numeric
          else (v_calc_cycle ->> 'overtime_pay')::numeric
        end,
        0
      ), 2);
      select round(coalesce(sum(case movement.clase
        when 'DEVENGO' then movement.monto
        when 'REVERSO_DEVENGO' then -movement.monto
        else 0 end), 0), 2)
      into v_existing
      from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = p_empresa
        and movement.empleado_id = v_employee.id
        and movement.ciclo_desde = v_cycle.ciclo_desde
        and movement.ciclo_hasta = v_cycle.ciclo_hasta
        and movement.concepto = v_concept
        and movement.clase in ('DEVENGO', 'REVERSO_DEVENGO')
        and movement.source_type in (
          'JOURNEY_NORMAL', 'JOURNEY_OVERTIME', 'CYCLE_V3_ROUNDING',
          'JOURNEY_CORRECTION'
        )
        and private.movimiento_nomina_es_reconciliable(movement);
      v_delta := round(v_target - v_existing, 2);
      if v_delta <> 0 then
        insert into public.nomina_movimientos_tiempo_real(
          empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
          source_type, source_key, clase, concepto, monto, formula, snapshot,
          creado_por
        ) values (
          p_empresa, v_employee.id, v_cycle.ciclo_desde, v_cycle.ciclo_hasta,
          v_journey.fecha_laboral, 'CYCLE_V3_ROUNDING',
          concat(
            v_employee.id, ':', v_cycle.ciclo_desde, ':', v_cycle.ciclo_hasta,
            ':', v_dependency_hash, ':', v_concept, ':', v_target, ':', v_existing
          ),
          'DEVENGO', v_concept, v_delta, v_formula,
          jsonb_build_object(
            'target', v_target,
            'previous', v_existing,
            'last_source', v_journey.id,
            'journey_dependencies', v_dependencies,
            'dependency_hash', v_dependency_hash
          ),
          auth.uid()
        ) on conflict (empresa_id, source_type, source_key) do nothing;
        get diagnostics v_existing = row_count;
        v_inserted := v_inserted + v_existing::integer;
      end if;
    end loop;
  end if;

  if v_dependencies is not null then
  -- Fixed incentive is one canonical source per employee/cycle. Derive its
  -- target from V3, subtracting the separately identifiable adjustment rows.
  select round(
    coalesce((v_calc_cycle ->> 'incentive')::numeric, 0)
    - coalesce(sum(adjustment.monto) filter (
        where adjustment.tipo = 'INCENTIVO' and adjustment.activo
      ), 0),
    2
  )
  into v_target
  from public.nomina_ajustes adjustment
  where adjustment.empresa_id = p_empresa
    and adjustment.empleado_id = v_employee.id
    and adjustment.periodo_id = v_cycle.periodo_id;
  select round(coalesce(sum(movement.monto), 0), 2)
  into v_existing
  from public.nomina_movimientos_tiempo_real movement
  where movement.empresa_id = p_empresa
    and movement.empleado_id = v_employee.id
    and movement.ciclo_desde = v_cycle.ciclo_desde
    and movement.ciclo_hasta = v_cycle.ciclo_hasta
    and movement.source_type = 'CYCLE_INCENTIVE'
    and (
      private.movimiento_nomina_es_pagable(movement)
      or exists (
        select 1 from public.nomina_pago_movimientos consumed
        where consumed.empresa_id = movement.empresa_id
          and consumed.movimiento_id = movement.id
      )
    );
  v_delta := round(v_target - v_existing, 2);
  if v_delta <> 0 then
    insert into public.nomina_movimientos_tiempo_real(
      empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
      source_type, source_key, clase, concepto, monto, formula, snapshot,
      creado_por
    ) values (
      p_empresa, v_employee.id, v_cycle.ciclo_desde, v_cycle.ciclo_hasta,
      v_journey.fecha_laboral, 'CYCLE_INCENTIVE',
      concat(v_employee.id, ':', v_cycle.ciclo_desde, ':', v_cycle.ciclo_hasta),
      'DEVENGO', 'INCENTIVE', v_delta, v_formula,
      jsonb_build_object(
        'v3_cycle_target', (v_calc_cycle ->> 'incentive')::numeric,
        'configured', v_rule.incentivo_periodo,
        'previous', v_existing,
        'journey_dependencies', v_dependencies,
        'dependency_hash', v_dependency_hash
      ),
      auth.uid()
    ) on conflict (empresa_id, source_type, source_key) do nothing;
    get diagnostics v_existing = row_count;
    v_inserted := v_inserted + v_existing::integer;
  end if;

  -- Manual incentive adjustments are globally unique by their source row.
  if v_cycle.periodo_id is not null then
    insert into public.nomina_movimientos_tiempo_real(
      empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
      source_type, source_key, clase, concepto, tipo, monto, formula, snapshot,
      ajuste_id, creado_por
    )
    select
      adjustment.empresa_id, adjustment.empleado_id,
      v_cycle.ciclo_desde, v_cycle.ciclo_hasta, v_journey.fecha_laboral,
      'ADJUSTMENT', adjustment.id::text,
      'DEVENGO', 'INCENTIVE', adjustment.tipo,
      round(adjustment.monto - prior.amount, 2), v_formula,
      jsonb_build_object(
        'origin', adjustment.origen,
        'reason', adjustment.motivo,
        'target', adjustment.monto,
        'previous', prior.amount,
        'journey_dependencies', v_dependencies,
        'dependency_hash', v_dependency_hash
      ),
      adjustment.id, auth.uid()
    from public.nomina_ajustes adjustment
    cross join lateral (
      select round(coalesce(sum(movement.monto), 0), 2) amount
      from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = adjustment.empresa_id
        and movement.empleado_id = adjustment.empleado_id
        and movement.ajuste_id = adjustment.id
        and movement.source_type = 'ADJUSTMENT'
        and movement.clase = 'DEVENGO'
        and (
          private.movimiento_nomina_es_pagable(movement)
          or exists (
            select 1 from public.nomina_pago_movimientos consumed
            where consumed.empresa_id = movement.empresa_id
              and consumed.movimiento_id = movement.id
          )
        )
    ) prior
    where adjustment.empresa_id = p_empresa
      and adjustment.empleado_id = v_employee.id
      and adjustment.periodo_id = v_cycle.periodo_id
      and adjustment.tipo = 'INCENTIVO'
      and adjustment.activo
      and round(adjustment.monto - prior.amount, 2) <> 0
    on conflict (empresa_id, source_type, source_key) do nothing;
    get diagnostics v_existing = row_count;
    v_inserted := v_inserted + v_existing::integer;
  end if;

  -- Materialize the authoritative V3 deduction distribution. Statutory
  -- reconciliation is an event delta; every other component uses an obligation
  -- base plus immutable applications so a later event may finish a partial target.
  for v_item in
    select item.value
    from jsonb_array_elements(v_calc_cycle -> 'deduction_items') item(value)
    order by coalesce((item.value ->> 'priority')::integer, 9999),
             coalesce((item.value ->> 'sequence')::integer, 9999)
  loop
    v_applied := round(coalesce((v_item ->> 'applied')::numeric, 0), 2);
    if v_applied = 0 then
      continue;
    end if;
    v_source_kind := coalesce(v_item ->> 'source_kind', 'CONFIG');
    v_concept := coalesce(v_item ->> 'concept', v_item ->> 'type', 'OTHER');
    v_type := coalesce(v_item ->> 'type', 'OTRO_DESCUENTO');
    v_source_id := case
      when nullif(v_item ->> 'source_id', '') is null then null
      else (v_item ->> 'source_id')::uuid
    end;
    v_item := v_item || jsonb_build_object(
      'journey_dependencies', v_dependencies,
      'dependency_hash', v_dependency_hash
    );

    -- V3 aggregates legacy carry into each item. Split that applied target back
    -- onto the concrete nomina_descuentos rows so every historical obligation
    -- is consumed exactly once and remains independently auditable.
    v_carry_target := round(least(
      v_applied,
      coalesce((v_item ->> 'carry_in')::numeric, 0)
    ), 2);
    v_carry_remaining := v_carry_target;
    if v_carry_remaining > 0 then
      for v_carry in
        select discount.*
        from public.nomina_descuentos discount
        where discount.empresa_id = p_empresa
          and discount.nomina_id = v_prev_nomina
          and discount.empleado_id = v_employee.id
          and discount.monto_pendiente > 0
          and (
            (v_source_kind = 'LOAN' and discount.prestamo_id = v_source_id)
            or (v_source_kind = 'CREDIT' and discount.credito_id = v_source_id)
            or (v_source_kind = 'ADJUSTMENT' and discount.ajuste_id = v_source_id)
            or (
              v_source_kind = 'CONFIG'
              and discount.tipo = v_type
              and (
                v_concept not in ('FIXED', 'OTHER_FIXED')
                or discount.metadata ->> 'concept' = v_concept
              )
            )
          )
        order by discount.creado_en, discount.id
      loop
        exit when v_carry_remaining <= 0;
        v_carry_apply := round(least(v_carry_remaining, v_carry.monto_pendiente), 2);
        v_existing := private.materializar_obligacion_nomina(
          p_empresa, v_employee.id, v_cycle.ciclo_desde, v_cycle.ciclo_hasta,
          v_journey.fecha_laboral, 'LEGACY_CARRY', v_carry.id::text,
          v_concept, v_type, v_carry_apply, v_formula,
          v_item || jsonb_build_object(
            'requested', v_carry.monto_pendiente,
            'legacy_discount_id', v_carry.id
          ),
          concat(v_event_key, ':CARRY:', v_carry.id),
          v_carry.ajuste_id, v_carry.prestamo_id, v_carry.credito_id, auth.uid()
        );
        v_inserted := v_inserted + v_existing::integer;
        v_carry_remaining := round(v_carry_remaining - v_carry_apply, 2);
      end loop;
      if v_carry_remaining > 0 then
        raise exception 'LIVE_PAYROLL_CARRY_SOURCE_MISSING';
      end if;
      v_applied := round(v_applied - v_carry_target, 2);
      if v_applied = 0 then
        continue;
      end if;
      v_item := v_item || jsonb_build_object(
        'requested', coalesce((v_item ->> 'current_requested')::numeric, v_applied),
        'carry_in', 0
      );
    end if;

    if v_source_kind = 'CONFIG'
       and (
         v_concept in ('AFP', 'SFS')
         or (
           v_concept = 'OTHER_TAX'
           and coalesce(v_rule.otros_impuestos_modo, 'MONTO') = 'PORCENTAJE'
         )
       ) then
      select round(coalesce(sum(case movement.clase
        when 'DEDUCCION' then movement.monto
        when 'REVERSO_DEDUCCION' then -movement.monto
        else 0 end), 0), 2)
      into v_existing
      from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = p_empresa
        and movement.empleado_id = v_employee.id
        and movement.ciclo_desde = v_cycle.ciclo_desde
        and movement.ciclo_hasta = v_cycle.ciclo_hasta
        and movement.concepto = v_concept
        and movement.clase in ('DEDUCCION', 'REVERSO_DEDUCCION')
        and movement.source_type in (
          'CYCLE_STATUTORY_APPLICATION', 'JOURNEY_CORRECTION'
        )
        and private.movimiento_nomina_es_reconciliable(movement);
      v_delta := round(v_applied - v_existing, 2);
      if v_delta = 0 then
        continue;
      end if;
      v_source_key := concat(
        v_employee.id, ':', v_cycle.ciclo_desde, ':', v_cycle.ciclo_hasta,
        ':', v_dependency_hash, ':', v_event_key, ':', v_concept
      );
      insert into public.nomina_movimientos_tiempo_real(
        empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
        source_type, source_key, clase, concepto, tipo, monto, formula, snapshot,
        jornada_id, creado_por
      ) values (
        p_empresa, v_employee.id, v_cycle.ciclo_desde, v_cycle.ciclo_hasta,
        v_journey.fecha_laboral, 'CYCLE_STATUTORY_APPLICATION', v_source_key,
        'DEDUCCION', v_concept, v_type, v_delta, v_formula,
        v_item || jsonb_build_object(
          'delta', v_delta,
          'target', v_applied,
          'version_sync', v_journey.version_sync
        ),
        v_journey.id, auth.uid()
      ) on conflict (empresa_id, source_type, source_key) do nothing;
      get diagnostics v_existing = row_count;
    elsif v_source_kind = 'LOAN' then
      v_source_key := concat(v_source_id, ':', v_cycle.ciclo_desde, ':', v_cycle.ciclo_hasta);
      v_existing := private.materializar_obligacion_nomina(
        p_empresa, v_employee.id, v_cycle.ciclo_desde, v_cycle.ciclo_hasta,
        v_journey.fecha_laboral, 'LOAN_INSTALLMENT', v_source_key,
        v_concept, v_type, v_applied, v_formula, v_item, v_event_key,
        null, v_source_id, null, auth.uid()
      );
    elsif v_source_kind = 'CREDIT' then
      v_source_key := concat(v_source_id, ':', v_cycle.ciclo_desde, ':', v_cycle.ciclo_hasta);
      v_existing := private.materializar_obligacion_nomina(
        p_empresa, v_employee.id, v_cycle.ciclo_desde, v_cycle.ciclo_hasta,
        v_journey.fecha_laboral, 'CREDIT_INSTALLMENT', v_source_key,
        v_concept, v_type, v_applied, v_formula, v_item, v_event_key,
        null, null, v_source_id, auth.uid()
      );
    elsif v_source_kind = 'ADJUSTMENT' and v_source_id is not null then
      v_existing := private.materializar_obligacion_nomina(
        p_empresa, v_employee.id, v_cycle.ciclo_desde, v_cycle.ciclo_hasta,
        v_journey.fecha_laboral, 'ADJUSTMENT', v_source_id::text,
        v_concept, v_type, v_applied, v_formula, v_item, v_event_key,
        v_source_id, null, null, auth.uid()
      );
    else
      v_source_key := concat(v_employee.id, ':', v_cycle.ciclo_desde, ':',
        v_cycle.ciclo_hasta, ':', v_concept);
      v_existing := private.materializar_obligacion_nomina(
        p_empresa, v_employee.id, v_cycle.ciclo_desde, v_cycle.ciclo_hasta,
        v_journey.fecha_laboral, 'CYCLE_FIXED', v_source_key,
        v_concept, v_type, v_applied, v_formula, v_item, v_event_key,
        null, null, null, auth.uid()


      );
    end if;
    v_inserted := v_inserted + v_existing::integer;
  end loop;
  end if;

  select round(greatest(coalesce(sum(
    case movement.clase
      when 'DEVENGO' then movement.monto
      when 'REVERSO_DEDUCCION' then movement.monto
      when 'DEDUCCION' then -movement.monto
      when 'REVERSO_DEVENGO' then -movement.monto
      else 0
    end
  ), 0), 0), 2)
  into v_applied
  from public.nomina_movimientos_tiempo_real movement
  where movement.empresa_id = p_empresa
    and movement.empleado_id = v_employee.id
    and movement.fecha_devengo = v_journey.fecha_laboral
    and private.movimiento_nomina_es_pagable(movement)
    and not exists (
      select 1
      from public.nomina_pago_movimientos consumed
      where consumed.empresa_id = movement.empresa_id
        and consumed.movimiento_id = movement.id
    );
  v_inserted := v_inserted + private.aplicar_creditos_correccion_nomina(
    p_empresa, v_employee.id, v_journey.id, v_journey.fecha_laboral,
    v_cycle.ciclo_desde, v_cycle.ciclo_hasta,
    concat('JOURNEY:', v_event_key), p_reconcile_source,
    v_applied, v_formula, auth.uid()
  );

  return jsonb_build_object(
    'status', 'ACCRUED',
    'employee_id', v_employee.id,
    'cycle_from', v_cycle.ciclo_desde,
    'cycle_to', v_cycle.ciclo_hasta,
    'inserted', v_inserted,
    'formula', v_formula
  );
end
$$;

create or replace function private.materializar_obligacion_nomina(
  p_empresa uuid,
  p_empleado uuid,
  p_ciclo_desde date,
  p_ciclo_hasta date,
  p_fecha_devengo date,
  p_obligation_type text,
  p_obligation_key text,
  p_concepto text,
  p_tipo text,
  p_target numeric,
  p_formula text,
  p_snapshot jsonb,
  p_event_key text,
  p_ajuste uuid default null,
  p_prestamo uuid default null,
  p_credito uuid default null,
  p_actor uuid default null
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_existing numeric;
  v_consumed numeric;
  v_cap numeric;
  v_stored_cap numeric;
  v_cumulative_target numeric;
  v_delta numeric;
  v_dependency_hash text;
  v_rows integer := 0;
  v_count integer;
begin
  if p_target < 0 or btrim(coalesce(p_obligation_key, '')) = '' then
    raise exception 'PAYROLL_OBLIGATION_INVALID';
  end if;
  v_dependency_hash := nullif(p_snapshot ->> 'dependency_hash', '');
  if v_dependency_hash is null then
    raise exception 'PAYROLL_OBLIGATION_DEPENDENCIES_REQUIRED';
  end if;

  v_cap := round(greatest(
    p_target,
    coalesce((p_snapshot ->> 'requested')::numeric, p_target)
  ), 2);

  insert into public.nomina_movimientos_tiempo_real(
    empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
    source_type, source_key, clase, concepto, tipo, monto, formula, snapshot,
    ajuste_id, prestamo_id, credito_id, creado_por
  ) values (
    p_empresa, p_empleado, p_ciclo_desde, p_ciclo_hasta, p_fecha_devengo,
    p_obligation_type || '_OBLIGATION',
    p_obligation_key,
    'CONTROL', p_concepto, p_tipo, 0, p_formula,
    p_snapshot || jsonb_build_object(
      'obligation_type', p_obligation_type,
      'obligation_key', p_obligation_key,
      'obligation_cap', v_cap
    ),
    p_ajuste, p_prestamo, p_credito, p_actor
  ) on conflict (empresa_id, source_type, source_key) do nothing;
  get diagnostics v_count = row_count;
  v_rows := v_rows + v_count;

  select round(coalesce(sum(movement.monto), 0), 2)
  into v_existing
  from public.nomina_movimientos_tiempo_real movement
  where movement.empresa_id = p_empresa
    and movement.empleado_id = p_empleado
    and movement.clase = 'DEDUCCION'
    and movement.snapshot ->> 'obligation_type' = p_obligation_type
    and movement.snapshot ->> 'obligation_key' = p_obligation_key
    and (
      private.movimiento_nomina_es_pagable(movement)
      or exists (
        select 1 from public.nomina_pago_movimientos consumed
        where consumed.empresa_id = movement.empresa_id
          and consumed.movimiento_id = movement.id
      )
    );

  select round(coalesce(sum(movement.monto), 0), 2)
  into v_consumed
  from public.nomina_movimientos_tiempo_real movement
  where movement.empresa_id = p_empresa
    and movement.empleado_id = p_empleado
    and movement.clase = 'DEDUCCION'
    and movement.snapshot ->> 'obligation_type' = p_obligation_type
    and movement.snapshot ->> 'obligation_key' = p_obligation_key
    and exists (
      select 1
      from public.nomina_pago_movimientos consumed
      where consumed.empresa_id = movement.empresa_id
        and consumed.movimiento_id = movement.id
    );

  if exists (
    select 1
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = p_empresa
      and movement.empleado_id = p_empleado
      and movement.clase = 'DEDUCCION'
      and movement.snapshot ->> 'obligation_type' = p_obligation_type
      and movement.snapshot ->> 'obligation_key' = p_obligation_key
      and movement.snapshot ->> 'event_key' = p_event_key
      and (
        private.movimiento_nomina_es_pagable(movement)
        or exists (
          select 1 from public.nomina_pago_movimientos consumed
          where consumed.empresa_id = movement.empresa_id
            and consumed.movimiento_id = movement.id
        )
      )
  ) then
    return v_rows;
  end if;

  select coalesce(
    (base.snapshot ->> 'obligation_cap')::numeric,
    v_cap
  )
  into v_stored_cap
  from public.nomina_movimientos_tiempo_real base
  where base.empresa_id = p_empresa
    and base.empleado_id = p_empleado
    and base.source_type = p_obligation_type || '_OBLIGATION'
    and base.source_key = p_obligation_key;
  v_cap := case
    when v_consumed = 0 then greatest(v_cap, coalesce(v_stored_cap, v_cap))
    else coalesce(v_stored_cap, v_cap)
  end;

  v_cumulative_target := round(least(
    v_cap,
    case when v_consumed > 0 then v_consumed + p_target else p_target end
  ), 2);
  v_delta := round(v_cumulative_target - v_existing, 2);
  if v_delta < 0 and v_consumed > 0 then
    raise exception 'LIVE_PAYROLL_COMPONENT_REGRESSION_REQUIRES_REVIEW';
  end if;
  if v_delta <> 0 then
    insert into public.nomina_movimientos_tiempo_real(
      empresa_id, empleado_id, ciclo_desde, ciclo_hasta, fecha_devengo,
      source_type, source_key, clase, concepto, tipo, monto, formula, snapshot,
      ajuste_id, prestamo_id, credito_id, creado_por
    ) values (
      p_empresa, p_empleado, p_ciclo_desde, p_ciclo_hasta, p_fecha_devengo,
      p_obligation_type || '_APPLICATION',
      concat(p_obligation_key, ':', v_dependency_hash, ':', p_event_key),
      'DEDUCCION', p_concepto, p_tipo, v_delta, p_formula,
      p_snapshot || jsonb_build_object(
        'obligation_type', p_obligation_type,
        'obligation_key', p_obligation_key,
        'event_key', p_event_key,
        'target', v_cumulative_target,
        'previous_applied', v_existing,
        'applied', v_delta
      ),
      p_ajuste, p_prestamo, p_credito, p_actor
    ) on conflict (empresa_id, source_type, source_key) do nothing;
    get diagnostics v_count = row_count;
    v_rows := v_rows + v_count;
  end if;

  return v_rows;
end
$$;

revoke all on function private.materializar_obligacion_nomina(
  uuid, uuid, date, date, date, text, text, text, text, numeric, text,
  jsonb, text, uuid, uuid, uuid, uuid
) from public, anon, authenticated, service_role;

create or replace function private.serializar_fuente_nomina_tiempo_real()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid;
  v_empleado uuid;
  v_jornada uuid;
  v_valid_correction boolean := false;
begin
  if tg_table_name = 'jornadas' then
    if tg_op in ('UPDATE', 'DELETE') then
      v_empresa := old.empresa_id;
      v_empleado := old.empleado_id;
      v_jornada := old.id;
    else
      v_empresa := new.empresa_id;
      v_empleado := new.empleado_id;
      v_jornada := new.id;
    end if;
  else
    if tg_op in ('UPDATE', 'DELETE') then
      v_empresa := old.empresa_id;
      v_jornada := old.jornada_id;
    else
      v_empresa := new.empresa_id;
      v_jornada := new.jornada_id;
    end if;
    select journey.empleado_id
    into v_empleado
    from public.jornadas journey
    where journey.empresa_id = v_empresa and journey.id = v_jornada;
  end if;

  if v_empresa is not null and v_empleado is not null then
    perform employee.id
    from public.empleados employee
    where employee.empresa_id = v_empresa and employee.id = v_empleado
    for update;
  end if;
  if tg_table_name = 'jornadas'
     and tg_op = 'UPDATE'
     and exists (
       select 1
       from public.nomina_movimientos_tiempo_real movement
       where movement.empresa_id = old.empresa_id
         and movement.jornada_id = old.id
     ) then
    v_valid_correction :=
      old.empresa_id = new.empresa_id
      and old.id = new.id
      and old.empleado_id = new.empleado_id
      and old.fecha_laboral = new.fecha_laboral
      and old.estado = 'FINALIZADA'
      and new.estado = 'FINALIZADA'
      and not new.revision_pendiente
      and new.version_sync = old.version_sync
      and new.revision_nomina = old.revision_nomina + 1;
    if not v_valid_correction then
      raise exception 'LIVE_PAYROLL_SOURCE_MUTATION_REQUIRES_REVIEW';
    end if;
  end if;

  if v_jornada is not null and exists (
    select 1
    from public.nomina_pago_jornadas paid
    where paid.empresa_id = v_empresa and paid.jornada_id = v_jornada
  ) and not v_valid_correction then
    raise exception 'JORNADA_YA_PAGADA';
  end if;

  if tg_table_name = 'jornadas'
     and tg_op in ('UPDATE', 'DELETE')
     and exists (
       select 1
       from public.nomina_movimientos_tiempo_real movement
       where movement.empresa_id = old.empresa_id
         and movement.jornada_id = old.id
     )
     and not v_valid_correction then
    raise exception 'LIVE_PAYROLL_SOURCE_MUTATION_REQUIRES_REVIEW';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end
$$;

revoke all on function private.serializar_fuente_nomina_tiempo_real()
from public, anon, authenticated, service_role;

create trigger nomina_serializar_jornada_source
before insert or update or delete on public.jornadas
for each row execute function private.serializar_fuente_nomina_tiempo_real();

create trigger nomina_serializar_conflicto_source
before insert or update or delete on public.jornada_conflictos
for each row execute function private.serializar_fuente_nomina_tiempo_real();

create or replace function private.devengar_movimientos_nomina_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  source record;
  v_empresa uuid;
  v_empleado uuid;
  v_jornada uuid;
begin
  if tg_table_name = 'jornadas' then
    if tg_op = 'DELETE' then
      v_empresa := old.empresa_id;
      v_empleado := old.empleado_id;
      v_jornada := old.id;
    else
      v_empresa := new.empresa_id;
      v_empleado := new.empleado_id;
      v_jornada := new.id;
    end if;
  else
    if tg_op = 'DELETE' then
      v_empresa := old.empresa_id;
      v_jornada := old.jornada_id;
    else
      v_empresa := new.empresa_id;
      v_jornada := new.jornada_id;
    end if;
    select journey.empleado_id
    into v_empleado
    from public.jornadas journey
    where journey.empresa_id = v_empresa and journey.id = v_jornada;
  end if;

  if tg_table_name = 'jornadas' then
    if tg_op = 'UPDATE'
       and new.revision_nomina > old.revision_nomina then
      perform private.devengar_movimientos_nomina_jornada(new.empresa_id, new.id);
      return null;
    end if;
  end if;

  -- Re-run every current source for the employee, not only missing CONTROLs.
  -- Source keys keep this idempotent while cycle deltas reconcile dependency
  -- changes caused by reopen, conflict, or version edits.
  for source in
    select journey.empresa_id, journey.id
    from public.jornadas journey
    where journey.empresa_id = v_empresa
      and journey.empleado_id = v_empleado
      and journey.estado = 'FINALIZADA'
      and journey.minutos_trabajados > 0
      and not journey.revision_pendiente
      and not exists (
        select 1 from public.jornada_conflictos conflict
        where conflict.empresa_id = journey.empresa_id
          and conflict.jornada_id = journey.id
          and conflict.estado = 'PENDIENTE'
      )
      and not exists (
        select 1 from public.nomina_pago_jornadas paid
        where paid.empresa_id = journey.empresa_id
          and paid.jornada_id = journey.id
      )
    order by journey.fecha_laboral, journey.id
  loop
    perform private.devengar_movimientos_nomina_jornada(source.empresa_id, source.id);
  end loop;
  return null;
end
$$;

revoke all on function private.nomina_ciclo_canonico(uuid, uuid, date)
from public, anon, authenticated, service_role;
revoke all on function private.devengar_movimientos_nomina_jornada(uuid, uuid, text)
from public, anon, authenticated, service_role;
revoke all on function private.devengar_movimientos_nomina_trigger()
from public, anon, authenticated, service_role;

-- Deferred execution observes conflicts/review flags written later in the same
-- transaction that finalized the journey. Reads in subsequent transactions see
-- the accrued ledger; none of the date-filter RPCs performs this work.
create constraint trigger nomina_devengar_jornada_finalizada
after insert or update on public.jornadas
deferrable initially deferred
for each row execute function private.devengar_movimientos_nomina_trigger();

create constraint trigger nomina_reconciliar_jornada_conflicto
after insert or update or delete on public.jornada_conflictos
deferrable initially deferred
for each row execute function private.devengar_movimientos_nomina_trigger();

create or replace function private.reconciliar_fuente_nomina_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  source record;
  v_empresa uuid := new.empresa_id;
  v_empleado uuid := new.empleado_id;
  v_reconcile_source text := case tg_table_name
    when 'nomina_ajustes' then concat('ADJUSTMENT:', new.id::text)
    when 'nomina_prestamos' then concat('LOAN:', new.id::text)
    else concat('CREDIT:', new.id::text)
  end;
begin
  for source in
    select journey.empresa_id, journey.id
    from public.jornadas journey
    where journey.empresa_id = v_empresa
      and journey.empleado_id = v_empleado
      and journey.estado = 'FINALIZADA'
      and journey.minutos_trabajados > 0
      and not journey.revision_pendiente
      and not exists (
        select 1 from public.jornada_conflictos conflict
        where conflict.empresa_id = journey.empresa_id
          and conflict.jornada_id = journey.id
          and conflict.estado = 'PENDIENTE'
      )
      and not exists (
        select 1 from public.nomina_pago_jornadas paid
        where paid.empresa_id = journey.empresa_id
          and paid.jornada_id = journey.id
      )
    order by journey.fecha_laboral, journey.id
  loop
    perform private.devengar_movimientos_nomina_jornada(
      source.empresa_id, source.id, v_reconcile_source
    );
  end loop;
  return new;
end
$$;

create or replace function private.guardar_mutacion_fuente_nomina_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_blocked boolean := false;
  v_context record;
  v_internal_update boolean := false;
begin
  if tg_op = 'UPDATE'
     and tg_table_name in ('nomina_prestamos', 'nomina_creditos') then
    select debt_context.*
    into v_context
    from private.nomina_pago_deuda_aplicaciones debt_context
    join public.nomina_pagos_tiempo_real payment
      on payment.empresa_id = debt_context.empresa_id
     and payment.id = debt_context.pago_id
     and payment.empleado_id = debt_context.empleado_id
    where debt_context.empresa_id = old.empresa_id
      and debt_context.empleado_id = old.empleado_id
      and debt_context.fuente_tipo = case
        when tg_table_name = 'nomina_prestamos' then 'LOAN' else 'CREDIT'
      end
      and debt_context.fuente_id = old.id
      and not debt_context.aplicada
    order by debt_context.creada_en, debt_context.pago_id
    limit 1
    for update of debt_context;

    if found then
      if tg_table_name = 'nomina_prestamos' then
        v_internal_update :=
          old.estado = 'ENTREGADO'
          and round(new.total_pagado - old.total_pagado, 2) = v_context.monto
          and round(old.pendiente - new.pendiente, 2) = v_context.monto
          and new.pendiente >= 0
          and new.estado = case
            when new.pendiente = 0 then 'PAGADO' else old.estado
          end
          and new.fecha_final is not distinct from case
            when new.pendiente = 0 then current_date else old.fecha_final
          end
          and new.actualizado_en >= old.actualizado_en
          and (
            to_jsonb(new) - array[
              'total_pagado', 'pendiente', 'estado', 'fecha_final',
              'actualizado_en'
            ]::text[]
          ) = (
            to_jsonb(old) - array[
              'total_pagado', 'pendiente', 'estado', 'fecha_final',
              'actualizado_en'
            ]::text[]
          );
      else
        v_internal_update :=
          old.estado = 'ACTIVO'
          and round(new.total_descontado - old.total_descontado, 2) = v_context.monto
          and round(old.pendiente - new.pendiente, 2) = v_context.monto
          and new.pendiente >= 0
          and new.estado = case
            when new.pendiente = 0 then 'PAGADO' else old.estado
          end
          and new.fecha_final is not distinct from case
            when new.pendiente = 0 then current_date else old.fecha_final
          end
          and new.actualizado_en >= old.actualizado_en
          and (
            to_jsonb(new) - array[
              'total_descontado', 'pendiente', 'estado', 'fecha_final',
              'actualizado_en'
            ]::text[]
          ) = (
            to_jsonb(old) - array[
              'total_descontado', 'pendiente', 'estado', 'fecha_final',
              'actualizado_en'
            ]::text[]
          );
      end if;

      if not v_internal_update then
        raise exception 'LIVE_PAYROLL_SOURCE_MUTATION_REQUIRES_REVIEW';
      end if;

      update private.nomina_pago_deuda_aplicaciones debt_context
      set aplicada = true,
          aplicada_en = clock_timestamp()
      where debt_context.empresa_id = v_context.empresa_id
        and debt_context.pago_id = v_context.pago_id
        and debt_context.fuente_tipo = v_context.fuente_tipo
        and debt_context.fuente_id = v_context.fuente_id
        and not debt_context.aplicada;
      if not found then
        raise exception 'LIVE_PAYROLL_DEBT_APPLICATION_REUSED';
      end if;
      return new;
    end if;
  end if;

  if tg_table_name = 'nomina_ajustes' then
    select exists (
      select 1 from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = old.empresa_id
        and movement.ajuste_id = old.id
    ) into v_blocked;
  elsif tg_table_name = 'empleados' then
    select exists (
      select 1
      from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = old.empresa_id
        and movement.empleado_id = old.id
        and movement.ciclo_hasta >= current_date
    ) into v_blocked;
  elsif tg_table_name = 'nomina_reglas_empleado' then
    select exists (
      select 1 from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = old.empresa_id
        and movement.empleado_id = old.empleado_id
        and movement.ciclo_hasta >= current_date
    ) into v_blocked;
  elsif tg_table_name = 'nomina_prestamos' then
    select exists (
      select 1 from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = old.empresa_id and movement.prestamo_id = old.id
        and movement.ciclo_hasta >= current_date
    ) into v_blocked;
  else
    select exists (
      select 1 from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = old.empresa_id and movement.credito_id = old.id
        and movement.ciclo_hasta >= current_date
    ) into v_blocked;
  end if;

  if v_blocked then
    raise exception 'LIVE_PAYROLL_SOURCE_MUTATION_REQUIRES_REVIEW';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end
$$;

revoke all on function private.reconciliar_fuente_nomina_trigger()
from public, anon, authenticated, service_role;
revoke all on function private.guardar_mutacion_fuente_nomina_trigger()
from public, anon, authenticated, service_role;

create trigger nomina_reconciliar_ajuste_source
after insert or update on public.nomina_ajustes
for each row execute function private.reconciliar_fuente_nomina_trigger();

create trigger nomina_guardar_ajuste_source
before update or delete on public.nomina_ajustes
for each row execute function private.guardar_mutacion_fuente_nomina_trigger();

create trigger nomina_reconciliar_prestamo_source
after insert on public.nomina_prestamos
for each row execute function private.reconciliar_fuente_nomina_trigger();

create trigger nomina_reconciliar_prestamo_activado_source
after update of estado on public.nomina_prestamos
for each row
when (new.estado = 'ENTREGADO' and old.estado = 'APROBADO')
execute function private.reconciliar_fuente_nomina_trigger();

create trigger nomina_reconciliar_credito_source
after insert on public.nomina_creditos
for each row execute function private.reconciliar_fuente_nomina_trigger();

create trigger nomina_reconciliar_credito_activado_source
after update of estado on public.nomina_creditos
for each row
when (new.estado = 'ACTIVO' and old.estado is distinct from new.estado)
execute function private.reconciliar_fuente_nomina_trigger();

create trigger nomina_guardar_cuota_prestamo_source
before update of estado, descuento_periodo, pendiente on public.nomina_prestamos
for each row execute function private.guardar_mutacion_fuente_nomina_trigger();

create trigger nomina_guardar_cuota_credito_source
before update of estado, descuento_periodo, pendiente on public.nomina_creditos
for each row execute function private.guardar_mutacion_fuente_nomina_trigger();

create trigger nomina_guardar_regla_source
before update or delete on public.nomina_reglas_empleado
for each row execute function private.guardar_mutacion_fuente_nomina_trigger();

create trigger nomina_guardar_empleado_payroll_source
before update of salario, tipo_pago, activo on public.empleados
for each row execute function private.guardar_mutacion_fuente_nomina_trigger();

create or replace function private.rechazar_detalle_nomina_con_pago_live()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_desde date;
  v_hasta date;
begin
  select period.fecha_inicio, period.fecha_fin
  into v_desde, v_hasta
  from public.nominas payroll
  join public.nomina_periodos period
    on period.empresa_id = payroll.empresa_id
   and period.id = payroll.periodo_id
  where payroll.empresa_id = new.empresa_id
    and payroll.id = new.nomina_id;

  if found and exists (
    select 1
    from public.nomina_pago_jornadas paid
    where paid.empresa_id = new.empresa_id
      and paid.empleado_id = new.empleado_id
      and paid.fecha_laboral between v_desde and v_hasta
  ) then
    raise exception 'JORNADA_YA_PAGADA_EN_TIEMPO_REAL';
  end if;
  return new;
end
$$;

revoke all on function private.rechazar_detalle_nomina_con_pago_live()
from public, anon, authenticated, service_role;

create trigger nomina_detalle_rechazar_pago_live
before insert or update on public.nomina_detalles
for each row execute function private.rechazar_detalle_nomina_con_pago_live();

create or replace function private.rechazar_estado_nomina_con_pago_live()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.estado in ('EN_REVISION', 'APROBADA', 'CERRADA')
     and old.estado is distinct from new.estado
     and exists (
       select 1
       from public.nomina_periodos period
       join public.nomina_detalles detail
         on detail.empresa_id = new.empresa_id
        and detail.nomina_id = new.id
       join public.nomina_pago_jornadas paid
         on paid.empresa_id = detail.empresa_id
        and paid.empleado_id = detail.empleado_id
        and paid.fecha_laboral between period.fecha_inicio and period.fecha_fin
       where period.empresa_id = new.empresa_id
         and period.id = new.periodo_id
     ) then
    raise exception 'JORNADA_YA_PAGADA_EN_TIEMPO_REAL';
  end if;
  return new;
end
$$;

revoke all on function private.rechazar_estado_nomina_con_pago_live()
from public, anon, authenticated, service_role;

create trigger nomina_estado_rechazar_pago_live
before update of estado on public.nominas
for each row execute function private.rechazar_estado_nomina_con_pago_live();

-- One-time replay for eligible pre-existing sources after the legacy cutover.
-- The source UNIQUE makes reruns idempotent; only this migration executes it.
do $$
declare
  journey record;
begin
  for journey in
    select source.empresa_id, source.id
    from public.jornadas source
    where source.estado = 'FINALIZADA'
      and source.minutos_trabajados > 0
      and not source.revision_pendiente
      and not exists (
        select 1 from public.jornada_conflictos conflict
        where conflict.empresa_id = source.empresa_id
          and conflict.jornada_id = source.id
          and conflict.estado = 'PENDIENTE'
      )
      and not exists (
        select 1 from public.nomina_pago_cortes_legacy legacy_cut
        where legacy_cut.empresa_id = source.empresa_id
          and legacy_cut.empleado_id = source.empleado_id
          and source.fecha_laboral <= legacy_cut.fecha_corte
      )
    order by source.empresa_id, source.empleado_id, source.fecha_laboral, source.id
  loop
    perform private.devengar_movimientos_nomina_jornada(journey.empresa_id, journey.id);
  end loop;
end
$$;

create or replace function private.listar_pagos_pendientes_movimientos(
  p_empresa uuid,
  p_desde date,
  p_hasta date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  if p_empresa is null or p_desde is null or p_hasta is null or p_hasta < p_desde then
    raise exception 'RANGO_FECHAS_INVALIDO';
  end if;

  with pending as (
    select movement.*
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = p_empresa
      and movement.fecha_devengo between p_desde and p_hasta
      and private.movimiento_nomina_es_pagable(movement)
      and not exists (
        select 1
        from public.nomina_pago_movimientos consumed
        where consumed.empresa_id = movement.empresa_id
          and consumed.movimiento_id = movement.id
      )
  ),
  employee_totals as (
    select
      pending.empleado_id,
      round(coalesce(sum(case pending.clase
        when 'DEVENGO' then pending.monto
        when 'REVERSO_DEVENGO' then -pending.monto
        else 0 end), 0), 2) as gross,
      round(coalesce(sum(case pending.clase
        when 'DEDUCCION' then pending.monto
        when 'REVERSO_DEDUCCION' then -pending.monto
        else 0 end), 0), 2) as deductions,
      round(coalesce(sum(case
        when pending.clase = 'DEVENGO'
          and pending.concepto = 'OVERTIME_PAY' then pending.monto
        when pending.clase = 'REVERSO_DEVENGO'
          and pending.concepto = 'OVERTIME_PAY' then -pending.monto
        else 0 end), 0), 2) as overtime_pay,
      round(coalesce(sum(case when pending.tipo = 'AFP' then
        case pending.clase when 'DEDUCCION' then pending.monto
          when 'REVERSO_DEDUCCION' then -pending.monto else 0 end
        else 0 end), 0), 2) as afp,
      round(coalesce(sum(case when pending.tipo = 'SFS' then
        case pending.clase when 'DEDUCCION' then pending.monto
          when 'REVERSO_DEDUCCION' then -pending.monto else 0 end
        else 0 end), 0), 2) as sfs,
      round(coalesce(sum(pending.monto) filter (
        where pending.clase = 'DEDUCCION' and pending.tipo = 'DESCU-PRES'
      ), 0), 2) as loan_discount,
      round(coalesce(sum(pending.monto) filter (
        where pending.clase = 'DEDUCCION' and pending.tipo = 'DESCU-CRED'
      ), 0), 2) as credit_discount,
      round(coalesce(sum(case
        when coalesce(pending.tipo, '') not in (
          'AFP', 'SFS', 'DESCU-PRES', 'DESCU-CRED'
        ) then case pending.clase when 'DEDUCCION' then pending.monto
          when 'REVERSO_DEDUCCION' then -pending.monto else 0 end
        else 0 end), 0), 2) as other_discounts,
      count(distinct pending.jornada_id) filter (
        where pending.source_type = 'JOURNEY' and pending.clase = 'CONTROL'
      )::integer as journeys,
      min(pending.fecha_devengo) filter (
        where pending.source_type = 'JOURNEY' and pending.clase = 'CONTROL'
      ) as journey_from,
      max(pending.fecha_devengo) filter (
        where pending.source_type = 'JOURNEY' and pending.clase = 'CONTROL'
      ) as journey_to,
      max(pending.formula) filter (where pending.clase <> 'CONTROL') as formula,
      encode(
        extensions.digest(
          convert_to(
            string_agg(
              concat_ws(
                '|', pending.id::text, pending.source_type,
                pending.source_key, pending.clase, pending.concepto,
                coalesce(pending.tipo, ''), pending.monto::text
              ),
              E'\n' order by pending.id
            ),
            'UTF8'
          ),
          'sha256'
        ),
        'hex'
      ) as source_fingerprint,
      coalesce(
        jsonb_agg(
          pending.snapshot || jsonb_build_object(
            'applied', case pending.clase
              when 'REVERSO_DEDUCCION' then -pending.monto else pending.monto end)
          order by
            coalesce((pending.snapshot ->> 'priority')::integer, 9999),
            coalesce((pending.snapshot ->> 'sequence')::integer, 9999),
            pending.creado_en,
            pending.id
        ) filter (where pending.clase in ('DEDUCCION', 'REVERSO_DEDUCCION')),
        '[]'::jsonb
      ) as deduction_items
    from pending
    group by pending.empleado_id
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'employee_id', employee.id,
        'employee_code', employee.codigo_empleado,
        'employee_name', employee.nombre_completo,
        'journeys', totals.journeys,
        'journey_from', totals.journey_from,
        'journey_to', totals.journey_to,
        'gross', totals.gross,
        'overtime_pay', totals.overtime_pay,
        'afp', totals.afp,
        'sfs', totals.sfs,
        'loan_discount', totals.loan_discount,
        'credit_discount', totals.credit_discount,
        'other_discounts', totals.other_discounts,
        'total_pending', round(totals.gross - totals.deductions, 2),
        'formula', totals.formula,
        'source_fingerprint', totals.source_fingerprint,
        'deduction_items', totals.deduction_items
      ) order by employee.codigo_empleado, employee.id
    ),
    '[]'::jsonb
  )
  into v_result
  from employee_totals totals
  join public.empleados employee
    on employee.empresa_id = p_empresa and employee.id = totals.empleado_id
  where round(totals.gross - totals.deductions, 2) > 0;

  return v_result;
end
$$;

create or replace function private.nomina_pago_tiempo_real_json(
  p_pago public.nomina_pagos_tiempo_real
)
returns jsonb
language sql
stable
set search_path = ''
as $$
  select p_pago.calculo || jsonb_build_object(
    'id', p_pago.id,
    'paid_at', p_pago.pagado_en,
    'motive', p_pago.motivo
  );
$$;

create or replace function public.listar_pagos_pendientes(
  p_desde date,
  p_hasta date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.nomina_empresa_autorizada('nomina.ver');
begin
  return private.listar_pagos_pendientes_movimientos(v_empresa, p_desde, p_hasta);
end
$$;

create or replace function public.obtener_resumen_pagos_tiempo_real(
  p_desde date,
  p_hasta date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.nomina_empresa_autorizada('nomina.ver');
  v_items jsonb;
  v_employees integer;
  v_pending numeric;
  v_paid numeric;
begin
  v_items := private.listar_pagos_pendientes_movimientos(
    v_empresa, p_desde, p_hasta
  );

  select count(*)::integer,
         round(coalesce(sum((item.value ->> 'total_pending')::numeric), 0), 2)
  into v_employees, v_pending
  from jsonb_array_elements(v_items) item(value);

  select round(coalesce(sum(payment.monto_pagado), 0), 2)
  into v_paid
  from public.nomina_pagos_tiempo_real payment
  where payment.empresa_id = v_empresa
    and payment.pagado_en::date between p_desde and p_hasta;

  return jsonb_build_object(
    'desde', p_desde,
    'hasta', p_hasta,
    'pendiente_a_pagar', v_pending,
    'ya_pagado', v_paid,
    'empleados_pendientes', v_employees
  );
end
$$;

create or replace function public.registrar_pago_empleado(
  p_empleado uuid,
  p_desde date,
  p_hasta date,
  p_motivo text,
  p_idempotency_key uuid,
  p_source_fingerprint text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.nomina_empresa_autorizada('nomina.pagar');
  v_actor uuid := auth.uid();
  v_motivo text := btrim(coalesce(p_motivo, ''));
  v_existing public.nomina_pagos_tiempo_real%rowtype;
  v_payment public.nomina_pagos_tiempo_real%rowtype;
  v_pending jsonb;
  v_source_count integer;
  v_source_gross numeric;
  v_movement_ids uuid[];
  v_movement_count integer;
  v_link_count integer;
begin
  if p_empleado is null then
    raise exception 'EMPLEADO_NO_ENCONTRADO';
  end if;
  if p_desde is null or p_hasta is null or p_hasta < p_desde then
    raise exception 'RANGO_FECHAS_INVALIDO';
  end if;
  if v_motivo = '' or char_length(v_motivo) > 500 then
    raise exception 'MOTIVO_REQUERIDO';
  end if;
  if p_idempotency_key is null then
    raise exception 'IDEMPOTENCY_KEY_REQUIRED';
  end if;
  if p_source_fingerprint is null
     or p_source_fingerprint !~ '^[0-9a-f]{64}$' then
    raise exception 'PAGO_CAMBIO_REQUIERE_CONFIRMACION';
  end if;

  select payment.*
  into v_existing
  from public.nomina_pagos_tiempo_real payment
  where payment.empresa_id = v_empresa
    and payment.idempotency_key = p_idempotency_key
  for share;
  if found then
    if v_existing.empleado_id is distinct from p_empleado
       or v_existing.fecha_desde is distinct from p_desde
       or v_existing.fecha_hasta is distinct from p_hasta
       or v_existing.motivo is distinct from v_motivo
       or v_existing.source_fingerprint is distinct from p_source_fingerprint then
      raise exception 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return private.nomina_pago_tiempo_real_json(v_existing);
  end if;

  perform journey.id
  from public.jornadas journey
  where journey.empresa_id = v_empresa
    and journey.empleado_id = p_empleado
    and exists (
      select 1
      from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = journey.empresa_id
        and movement.empleado_id = journey.empleado_id
        and movement.jornada_id = journey.id
        and movement.fecha_devengo between p_desde and p_hasta
        and private.movimiento_nomina_es_pagable(movement)
        and not exists (
          select 1
          from public.nomina_pago_movimientos consumed
          where consumed.empresa_id = movement.empresa_id
            and consumed.movimiento_id = movement.id
        )
    )
  order by journey.id
  for share;

  perform employee.id
  from public.empleados employee
  where employee.empresa_id = v_empresa
    and employee.id = p_empleado
    and employee.activo
  for update;
  if not found then
    raise exception 'EMPLEADO_NO_ENCONTRADO';
  end if;

  perform loan.id
  from public.nomina_prestamos loan
  where loan.empresa_id = v_empresa
    and loan.empleado_id = p_empleado
    and exists (
      select 1 from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = loan.empresa_id
        and movement.empleado_id = loan.empleado_id
        and movement.prestamo_id = loan.id
        and movement.fecha_devengo between p_desde and p_hasta
        and private.movimiento_nomina_es_pagable(movement)
        and not exists (
          select 1 from public.nomina_pago_movimientos consumed
          where consumed.empresa_id = movement.empresa_id
            and consumed.movimiento_id = movement.id
        )
    )
  order by loan.id
  for update;

  perform credit.id
  from public.nomina_creditos credit
  where credit.empresa_id = v_empresa
    and credit.empleado_id = p_empleado
    and exists (
      select 1 from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = credit.empresa_id
        and movement.empleado_id = credit.empleado_id
        and movement.credito_id = credit.id
        and movement.fecha_devengo between p_desde and p_hasta
        and private.movimiento_nomina_es_pagable(movement)
        and not exists (
          select 1 from public.nomina_pago_movimientos consumed
          where consumed.empresa_id = movement.empresa_id
            and consumed.movimiento_id = movement.id
        )
    )
  order by credit.id
  for update;

  perform discount.id
  from public.nomina_descuentos discount
  where discount.empresa_id = v_empresa
    and discount.empleado_id = p_empleado
    and exists (
      select 1 from public.nomina_movimientos_tiempo_real movement
      where movement.empresa_id = discount.empresa_id
        and movement.empleado_id = discount.empleado_id
        and movement.source_type = 'LEGACY_CARRY_APPLICATION'
        and movement.snapshot ->> 'legacy_discount_id' = discount.id::text
        and movement.fecha_devengo between p_desde and p_hasta
        and private.movimiento_nomina_es_pagable(movement)
        and not exists (
          select 1 from public.nomina_pago_movimientos consumed
          where consumed.empresa_id = movement.empresa_id
            and consumed.movimiento_id = movement.id
        )
    )
  order by discount.id
  for update;

  -- Lock the exact immutable movements selected by this request. The range does
  -- not create or recalculate anything; later source events wait on employee.
  select pg_catalog.array_agg(locked.id order by locked.id)
  into v_movement_ids
  from (
    select movement.id
    from public.nomina_movimientos_tiempo_real movement
    where movement.empresa_id = v_empresa
      and movement.empleado_id = p_empleado
      and movement.fecha_devengo between p_desde and p_hasta
      and private.movimiento_nomina_es_pagable(movement)
      and not exists (
        select 1 from public.nomina_pago_movimientos consumed
        where consumed.empresa_id = movement.empresa_id
          and consumed.movimiento_id = movement.id
      )
    order by movement.id
    for update
  ) locked;
  v_movement_count := coalesce(pg_catalog.cardinality(v_movement_ids), 0);

  -- Resolve a concurrent replay that committed while this call waited on locks.
  select payment.*
  into v_existing
  from public.nomina_pagos_tiempo_real payment
  where payment.empresa_id = v_empresa
    and payment.idempotency_key = p_idempotency_key
  for share;
  if found then
    if v_existing.empleado_id is distinct from p_empleado
       or v_existing.fecha_desde is distinct from p_desde
       or v_existing.fecha_hasta is distinct from p_hasta
       or v_existing.motivo is distinct from v_motivo
       or v_existing.source_fingerprint is distinct from p_source_fingerprint then
      raise exception 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return private.nomina_pago_tiempo_real_json(v_existing);
  end if;

  select item.value
  into v_pending
  from jsonb_array_elements(
    private.listar_pagos_pendientes_movimientos(v_empresa, p_desde, p_hasta)
  ) item(value)
  where (item.value ->> 'employee_id')::uuid = p_empleado
  limit 1;
  if not found then
    raise exception 'PAGO_PENDIENTE_NO_ENCONTRADO';
  end if;
  if v_pending ->> 'source_fingerprint' is distinct from p_source_fingerprint then
    raise exception 'PAGO_CAMBIO_REQUIERE_CONFIRMACION';
  end if;

  insert into public.nomina_pagos_tiempo_real(
    empresa_id, empleado_id, fecha_desde, fecha_hasta,
    codigo_empleado, nombre_empleado, jornadas,
    monto_bruto, monto_deducciones, monto_pagado,
    formula, calculo, motivo, idempotency_key, source_fingerprint, pagado_por
  ) values (
    v_empresa,
    p_empleado,
    p_desde,
    p_hasta,
    v_pending ->> 'employee_code',
    v_pending ->> 'employee_name',
    (v_pending ->> 'journeys')::integer,
    round((v_pending ->> 'gross')::numeric, 2),
    round(
      (v_pending ->> 'gross')::numeric
      - (v_pending ->> 'total_pending')::numeric,
      2
    ),
    round((v_pending ->> 'total_pending')::numeric, 2),
    v_pending ->> 'formula',
    v_pending,
    v_motivo,
    p_idempotency_key,
    p_source_fingerprint,
    v_actor
  ) returning * into v_payment;

  insert into public.nomina_pago_movimientos(
    empresa_id, pago_id, movimiento_id, empleado_id,
    monto, source_type, source_key
  )
  select
    movement.empresa_id,
    v_payment.id,
    movement.id,
    movement.empleado_id,
    movement.monto,
    movement.source_type,
    movement.source_key
  from public.nomina_movimientos_tiempo_real movement
  where movement.empresa_id = v_empresa
    and movement.id = any(v_movement_ids)
  order by movement.id;
  get diagnostics v_link_count = row_count;
  if v_link_count <> v_movement_count then
    raise exception 'PAYMENT_SOURCE_INVARIANT_FAILED';
  end if;

  -- Compatibility journey snapshot. The last source receives the cent remainder,
  -- so the immutable allocations equal the header without becoming negative.
  with journey_sources as (
    select
      movement.jornada_id,
      movement.fecha_devengo as fecha_laboral,
      (movement.snapshot ->> 'minutes')::integer as minutos_trabajados,
      (movement.snapshot ->> 'normal_minutes')::integer as normal_minutes,
      (movement.snapshot ->> 'overtime_minutes')::integer as overtime_minutes,
      (movement.snapshot ->> 'version_sync')::bigint as version_sync,
      (movement.snapshot ->> 'updated_at')::timestamptz as actualizada_en,
      round((movement.snapshot ->> 'earned')::numeric, 2) as earned
    from public.nomina_pago_movimientos consumed
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = consumed.empresa_id
     and movement.id = consumed.movimiento_id
     and movement.source_type = 'JOURNEY'
    where consumed.empresa_id = v_empresa
      and consumed.pago_id = v_payment.id
  ),
  weighted as (
    select
      source.*,
      row_number() over (order by source.earned, source.jornada_id) as source_number,
      count(*) over () as source_count,
      sum(source.earned) over () as total_earned
    from journey_sources source
  ),
  provisional as (
    select
      weighted.*,
      trunc(v_payment.monto_bruto * weighted.earned / weighted.total_earned, 2)
        as provisional_gross
    from weighted
  ),
  allocated as (
    select
      provisional.*,
      case
        when source_number = source_count then round(
          v_payment.monto_bruto
          - coalesce(
              sum(provisional_gross) filter (
                where source_number < source_count
              ) over (),
              0
            ),
          2
        )
        else provisional_gross
      end as allocated_gross
    from provisional
  )
  insert into public.nomina_pago_jornadas(
    empresa_id, pago_id, jornada_id, empleado_id, fecha_laboral,
    minutos_trabajados, minutos_normales, minutos_extra, bruto_asignado,
    fuente, version_sync, jornada_actualizada_en
  )
  select
    v_empresa,
    v_payment.id,
    allocated.jornada_id,
    p_empleado,
    allocated.fecha_laboral,
    allocated.minutos_trabajados,
    allocated.normal_minutes,
    allocated.overtime_minutes,
    allocated.allocated_gross,
    jsonb_build_object(
      'earned_before_allocation', allocated.earned,
      'formula', v_payment.formula
    ),
    allocated.version_sync,
    allocated.actualizada_en
  from allocated;

  select count(*)::integer, round(coalesce(sum(source.bruto_asignado), 0), 2)
  into v_source_count, v_source_gross
  from public.nomina_pago_jornadas source
  where source.empresa_id = v_empresa and source.pago_id = v_payment.id;
  if v_source_count <> v_payment.jornadas
     or (v_payment.jornadas > 0
         and v_source_gross <> v_payment.monto_bruto) then
    raise exception 'PAYMENT_SOURCE_INVARIANT_FAILED';
  end if;

  -- Consume each historical carry row exactly once. The legacy row remains the
  -- compatibility balance source while the immutable movement/payment link is
  -- the audit trail for this application.
  if exists (
    select 1
    from (
      select
        (movement.snapshot ->> 'legacy_discount_id')::uuid discount_id,
        round(sum(movement.monto), 2) amount
      from public.nomina_pago_movimientos consumed
      join public.nomina_movimientos_tiempo_real movement
        on movement.empresa_id = consumed.empresa_id
       and movement.id = consumed.movimiento_id
      where consumed.empresa_id = v_empresa
        and consumed.pago_id = v_payment.id
        and movement.source_type = 'LEGACY_CARRY_APPLICATION'
      group by movement.snapshot ->> 'legacy_discount_id'
    ) applied
    left join public.nomina_descuentos discount
      on discount.empresa_id = v_empresa
     and discount.empleado_id = p_empleado
     and discount.id = applied.discount_id
    where discount.id is null
       or applied.amount <= 0
       or applied.amount > discount.monto_pendiente
  ) then
    raise exception 'PAYMENT_LEGACY_CARRY_SOURCE_INVALID';
  end if;

  with applied as (
    select
      (movement.snapshot ->> 'legacy_discount_id')::uuid discount_id,
      round(sum(movement.monto), 2) amount
    from public.nomina_pago_movimientos consumed
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = consumed.empresa_id
     and movement.id = consumed.movimiento_id
    where consumed.empresa_id = v_empresa
      and consumed.pago_id = v_payment.id
      and movement.source_type = 'LEGACY_CARRY_APPLICATION'
    group by movement.snapshot ->> 'legacy_discount_id'
  )
  update public.nomina_descuentos discount
  set monto = round(discount.monto + applied.amount, 2),
      monto_pendiente = round(discount.monto_pendiente - applied.amount, 2),
      aplicado = round(discount.monto_pendiente - applied.amount, 2) = 0,
      metadata = discount.metadata || jsonb_build_object(
        'live_payment_id', v_payment.id,
        'live_payment_applied', applied.amount
      )
  from applied
  where discount.empresa_id = v_empresa
    and discount.empleado_id = p_empleado
    and discount.id = applied.discount_id
    and discount.monto_pendiente >= applied.amount;

  -- Consume debt balances from the exact debt movements linked to this payment.
  -- Each private row is a one-shot capability consumed by the source guard.  It
  -- is derived only from immutable links created above and cannot be supplied by
  -- a caller or reused for a later balance mutation.
  with debt_application as (
    select
      'LOAN'::text source_kind,
      movement.prestamo_id source_id,
      round(sum(movement.monto), 2) amount
    from public.nomina_pago_movimientos consumed
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = consumed.empresa_id
     and movement.id = consumed.movimiento_id
    where consumed.empresa_id = v_empresa
      and consumed.pago_id = v_payment.id
      and movement.prestamo_id is not null
    group by movement.prestamo_id
    union all
    select
      'CREDIT'::text,
      movement.credito_id,
      round(sum(movement.monto), 2)
    from public.nomina_pago_movimientos consumed
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = consumed.empresa_id
     and movement.id = consumed.movimiento_id
    where consumed.empresa_id = v_empresa
      and consumed.pago_id = v_payment.id
      and movement.credito_id is not null
    group by movement.credito_id
  )
  insert into private.nomina_pago_deuda_aplicaciones(
    empresa_id, pago_id, empleado_id, fuente_tipo, fuente_id, monto
  )
  select
    v_empresa, v_payment.id, p_empleado,
    debt_application.source_kind, debt_application.source_id,
    debt_application.amount
  from debt_application
  where debt_application.amount > 0;

  if exists (
    select 1
    from (
      select movement.prestamo_id, round(sum(movement.monto), 2) amount
      from public.nomina_pago_movimientos consumed
      join public.nomina_movimientos_tiempo_real movement
        on movement.empresa_id = consumed.empresa_id
       and movement.id = consumed.movimiento_id
      where consumed.empresa_id = v_empresa
        and consumed.pago_id = v_payment.id
        and movement.prestamo_id is not null
      group by movement.prestamo_id
    ) applied
    left join public.nomina_prestamos loan
      on loan.empresa_id = v_empresa
     and loan.empleado_id = p_empleado
     and loan.id = applied.prestamo_id
     and loan.estado = 'ENTREGADO'
    where loan.id is null or applied.amount <= 0 or applied.amount > loan.pendiente
  ) then
    raise exception 'PAYMENT_LOAN_SOURCE_INVALID';
  end if;

  with applied as (
    select movement.prestamo_id, round(sum(movement.monto), 2) amount
    from public.nomina_pago_movimientos consumed
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = consumed.empresa_id
     and movement.id = consumed.movimiento_id
    where consumed.empresa_id = v_empresa
      and consumed.pago_id = v_payment.id
      and movement.prestamo_id is not null
    group by movement.prestamo_id
  )
  update public.nomina_prestamos loan
  set total_pagado = round(loan.total_pagado + applied.amount, 2),
      pendiente = round(loan.pendiente - applied.amount, 2),
      estado = case when round(loan.pendiente - applied.amount, 2) = 0
        then 'PAGADO' else loan.estado end,
      fecha_final = case when round(loan.pendiente - applied.amount, 2) = 0
        then current_date else loan.fecha_final end,
      actualizado_en = now()
  from applied
  where loan.empresa_id = v_empresa
    and loan.empleado_id = p_empleado
    and loan.id = applied.prestamo_id
    and loan.estado = 'ENTREGADO'
    and loan.pendiente >= applied.amount;

  if exists (
    select 1
    from (
      select movement.credito_id, round(sum(movement.monto), 2) amount
      from public.nomina_pago_movimientos consumed
      join public.nomina_movimientos_tiempo_real movement
        on movement.empresa_id = consumed.empresa_id
       and movement.id = consumed.movimiento_id
      where consumed.empresa_id = v_empresa
        and consumed.pago_id = v_payment.id
        and movement.credito_id is not null
      group by movement.credito_id
    ) applied
    left join public.nomina_creditos credit
      on credit.empresa_id = v_empresa
     and credit.empleado_id = p_empleado
     and credit.id = applied.credito_id
     and credit.estado = 'ACTIVO'
    where credit.id is null or applied.amount <= 0 or applied.amount > credit.pendiente
  ) then
    raise exception 'PAYMENT_CREDIT_SOURCE_INVALID';
  end if;

  with applied as (
    select movement.credito_id, round(sum(movement.monto), 2) amount
    from public.nomina_pago_movimientos consumed
    join public.nomina_movimientos_tiempo_real movement
      on movement.empresa_id = consumed.empresa_id
     and movement.id = consumed.movimiento_id
    where consumed.empresa_id = v_empresa
      and consumed.pago_id = v_payment.id
      and movement.credito_id is not null
    group by movement.credito_id
  )
  update public.nomina_creditos credit
  set total_descontado = round(credit.total_descontado + applied.amount, 2),
      pendiente = round(credit.pendiente - applied.amount, 2),
      estado = case when round(credit.pendiente - applied.amount, 2) = 0
        then 'PAGADO' else credit.estado end,
      fecha_final = case when round(credit.pendiente - applied.amount, 2) = 0
        then current_date else credit.fecha_final end,
      actualizado_en = now()
  from applied
  where credit.empresa_id = v_empresa
    and credit.empleado_id = p_empleado
    and credit.id = applied.credito_id
    and credit.estado = 'ACTIVO'
    and credit.pendiente >= applied.amount;

  if exists (
    select 1
    from private.nomina_pago_deuda_aplicaciones debt_context
    where debt_context.empresa_id = v_empresa
      and debt_context.pago_id = v_payment.id
      and not debt_context.aplicada
  ) then
    raise exception 'PAYMENT_DEBT_SOURCE_INVARIANT_FAILED';
  end if;

  insert into public.nomina_auditoria(
    empresa_id, empleado_id, actor_id, accion, despues, motivo
  ) values (
    v_empresa,
    p_empleado,
    v_actor,
    'PAGO_TIEMPO_REAL',
    jsonb_build_object(
      'payment_id', v_payment.id,
      'date_from', p_desde,
      'date_to', p_hasta,
      'movements', (
        select count(*) from public.nomina_pago_movimientos consumed
        where consumed.empresa_id = v_empresa and consumed.pago_id = v_payment.id
      ),
      'gross', v_payment.monto_bruto,
      'deductions', v_payment.monto_deducciones,
      'paid', v_payment.monto_pagado,
      'formula', v_payment.formula
    ),
    v_motivo
  );

  return private.nomina_pago_tiempo_real_json(v_payment);
exception
  when unique_violation then
    select payment.*
    into v_existing
    from public.nomina_pagos_tiempo_real payment
    where payment.empresa_id = v_empresa
      and payment.idempotency_key = p_idempotency_key;
    if found then
      if v_existing.empleado_id is distinct from p_empleado
         or v_existing.fecha_desde is distinct from p_desde
         or v_existing.fecha_hasta is distinct from p_hasta
         or v_existing.motivo is distinct from v_motivo
         or v_existing.source_fingerprint is distinct from p_source_fingerprint then
        raise exception 'IDEMPOTENCY_KEY_REUSED';
      end if;
      return private.nomina_pago_tiempo_real_json(v_existing);
    end if;
    raise exception 'JORNADA_YA_PAGADA';
end
$$;

create or replace function public.listar_historial_pagos(
  p_desde date,
  p_hasta date
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.nomina_empresa_autorizada('nomina.ver');
  v_result jsonb;
begin
  if p_desde is null or p_hasta is null or p_hasta < p_desde then
    raise exception 'RANGO_FECHAS_INVALIDO';
  end if;

  select coalesce(
    jsonb_agg(
      private.nomina_pago_tiempo_real_json(payment)
      order by payment.pagado_en desc, payment.id
    ),
    '[]'::jsonb
  )
  into v_result
  from public.nomina_pagos_tiempo_real payment
  where payment.empresa_id = v_empresa
    and payment.pagado_en::date between p_desde and p_hasta;
  return v_result;
end
$$;

revoke all privileges on function private.listar_pagos_pendientes_movimientos(
  uuid, date, date
) from public, anon, authenticated, service_role;
revoke all privileges on function private.nomina_pago_tiempo_real_json(
  public.nomina_pagos_tiempo_real
) from public, anon, authenticated, service_role;

revoke all privileges on function public.listar_pagos_pendientes(date, date)
from public, anon, authenticated, service_role;
revoke all privileges on function public.obtener_resumen_pagos_tiempo_real(date, date)
from public, anon, authenticated, service_role;
revoke all privileges on function public.registrar_pago_empleado(
  uuid, date, date, text, uuid, text
) from public, anon, authenticated, service_role;
revoke all privileges on function public.listar_historial_pagos(date, date)
from public, anon, authenticated, service_role;

grant execute on function public.listar_pagos_pendientes(date, date)
to authenticated;
grant execute on function public.obtener_resumen_pagos_tiempo_real(date, date)
to authenticated;
grant execute on function public.registrar_pago_empleado(
  uuid, date, date, text, uuid, text
) to authenticated;
grant execute on function public.listar_historial_pagos(date, date)
to authenticated;

comment on table public.nomina_movimientos_tiempo_real is
  'Immutable source-event payroll movements; source identity never depends on a UI date filter.';
comment on table public.nomina_pago_movimientos is
  'Immutable one-time consumption link from a payment to each concrete accrued movement.';
comment on table public.nomina_pagos_tiempo_real is
  'Immutable employee payment header composed only from pre-existing accrued movements.';
comment on function public.listar_pagos_pendientes(date, date) is
  'Stable read-only projection of unconsumed accrued movements in the date range.';
comment on function public.obtener_resumen_pagos_tiempo_real(date, date) is
  'Stable read-only pending/paid summary; never accrues or recalculates sources.';
comment on function public.registrar_pago_empleado(uuid, date, date, text, uuid, text) is
  'Idempotently locks and consumes the fingerprinted immutable movement set; it never accrues sources.';
comment on function public.listar_historial_pagos(date, date) is
  'Stable read-only history filtered by the effective payment date.';

commit;





