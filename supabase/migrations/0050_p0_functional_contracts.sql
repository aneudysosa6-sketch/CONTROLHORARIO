begin;

set local search_path = public, extensions, pg_catalog;

-- P0 permissions are explicit capabilities. They are not inferred from UI roles.
insert into public.permisos (codigo, nombre, descripcion, modulo, activo)
values
  ('licencias.gestionar', 'Gestionar licencias', 'Crea, modifica y cancela licencias laborales directas.', 'licencias', true),
  ('nomina.no_pagar', 'Resolver jornadas incompletas', 'Resuelve jornadas incompletas mediante el circuito NO PAGAR.', 'nomina', true),
  ('nomina.ajustes_anteriores', 'Gestionar ajustes anteriores', 'Consulta y aplica diferencias de periodos ya cerrados.', 'nomina', true),
  ('lista_negra.ver', 'Ver lista negra', 'Consulta el seguimiento mensual individual de incidencias.', 'reportes', true)
on conflict (codigo) do update set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  modulo = excluded.modulo,
  activo = excluded.activo;

insert into public.rol_permisos (rol_id, permiso_id, permitido, alcance)
select r.id, p.id, true, 'empresa'
from public.roles r
join public.permisos p on p.codigo in (
  'licencias.gestionar', 'nomina.no_pagar',
  'nomina.ajustes_anteriores', 'lista_negra.ver'
)
where r.is_active
  and private.normalizar_codigo_rol(r.code) = 'ADMIN'
on conflict (rol_id, permiso_id) do update set
  permitido = excluded.permitido,
  alcance = excluded.alcance;

-- ---------------------------------------------------------------------------
-- Immediate authorization revision
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists authorization_revision bigint not null default 1,
  add column if not exists authorization_changed_at timestamptz not null default statement_timestamp();

create or replace function private.bump_profile_authorization_0050(p_profile uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
begin
  if p_profile is not null then
    update public.profiles
    set authorization_revision = authorization_revision + 1,
        authorization_changed_at = statement_timestamp(),
        updated_at = statement_timestamp()
    where id = p_profile;
  end if;
end;
$$;

create or replace function private.profile_authorization_changed_0050()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
begin
  if old.role_id is distinct from new.role_id
     or old.status is distinct from new.status
     or old.branch_id is distinct from new.branch_id
     or old.department_id is distinct from new.department_id
     or old.company_id is distinct from new.company_id
  then
    if new.authorization_revision = old.authorization_revision then
      new.authorization_revision := old.authorization_revision + 1;
    end if;
    new.authorization_changed_at := statement_timestamp();
    new.updated_at := statement_timestamp();
  end if;
  return new;
end;
$$;

drop trigger if exists profiles_authorization_revision_0050 on public.profiles;
create trigger profiles_authorization_revision_0050
before update on public.profiles
for each row execute function private.profile_authorization_changed_0050();

create or replace function private.related_authorization_changed_0050()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_new jsonb := case when tg_op = 'DELETE' then '{}'::jsonb else to_jsonb(new) end;
  v_old jsonb := case when tg_op = 'INSERT' then '{}'::jsonb else to_jsonb(old) end;
  v_profile uuid;
  v_role uuid;
begin
  v_profile := coalesce(
    nullif(v_new ->> 'perfil_id', '')::uuid,
    nullif(v_old ->> 'perfil_id', '')::uuid
  );
  if v_profile is not null then
    perform private.bump_profile_authorization_0050(v_profile);
    return coalesce(new, old);
  end if;

  v_role := coalesce(
    nullif(v_new ->> 'rol_id', '')::uuid,
    nullif(v_old ->> 'rol_id', '')::uuid,
    nullif(v_new ->> 'role_id', '')::uuid,
    nullif(v_old ->> 'role_id', '')::uuid
  );
  if v_role is not null then
    update public.profiles
    set authorization_revision = authorization_revision + 1,
        authorization_changed_at = statement_timestamp(),
        updated_at = statement_timestamp()
    where role_id = v_role;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists perfil_permisos_authorization_0050 on public.perfil_permisos;
create trigger perfil_permisos_authorization_0050
after insert or update or delete on public.perfil_permisos
for each row execute function private.related_authorization_changed_0050();

drop trigger if exists perfil_sucursales_authorization_0050 on public.perfil_sucursales;
create trigger perfil_sucursales_authorization_0050
after insert or update or delete on public.perfil_sucursales
for each row execute function private.related_authorization_changed_0050();

drop trigger if exists perfil_departamentos_authorization_0050 on public.perfil_departamentos;
create trigger perfil_departamentos_authorization_0050
after insert or update or delete on public.perfil_departamentos
for each row execute function private.related_authorization_changed_0050();

drop trigger if exists rol_permisos_authorization_0050 on public.rol_permisos;
create trigger rol_permisos_authorization_0050
after insert or update or delete on public.rol_permisos
for each row execute function private.related_authorization_changed_0050();

create or replace function public.obtener_revision_autorizacion()
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_profile public.profiles%rowtype;
begin
  select * into v_profile from public.profiles where id = auth.uid();
  if not found or v_profile.status <> 'active' then
    raise exception using errcode = '28000', message = 'PROFILE_INACTIVE';
  end if;
  return jsonb_build_object(
    'profile_id', v_profile.id,
    'authorization_revision', v_profile.authorization_revision,
    'authorization_changed_at', v_profile.authorization_changed_at,
    'active', true
  );
end;
$$;

create or replace function public.validar_autorizacion_actual(
  p_expected_revision bigint default null,
  p_permission text default null,
  p_employee uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_profile public.profiles%rowtype;
begin
  select * into v_profile from public.profiles where id = auth.uid();
  if not found or v_profile.status <> 'active' then
    raise exception using errcode = '28000', message = 'PROFILE_INACTIVE';
  end if;
  if p_expected_revision is not null
     and p_expected_revision <> v_profile.authorization_revision
  then
    raise exception using errcode = '40001', message = 'AUTHORIZATION_STALE';
  end if;
  if nullif(btrim(p_permission), '') is not null
     and not public.tiene_permiso(btrim(p_permission))
  then
    raise exception using errcode = '42501', message = 'PERMISSION_REVOKED';
  end if;
  if p_employee is not null
     and not public.puede_operar_empleado_en_alcance(p_employee, btrim(p_permission))
  then
    raise exception using errcode = '42501', message = 'SCOPE_REVOKED';
  end if;
  return jsonb_build_object(
    'ok', true,
    'authorization_revision', v_profile.authorization_revision
  );
end;
$$;

revoke all on function private.bump_profile_authorization_0050(uuid) from public, anon, authenticated, service_role;
revoke all on function private.profile_authorization_changed_0050() from public, anon, authenticated, service_role;
revoke all on function private.related_authorization_changed_0050() from public, anon, authenticated, service_role;
revoke all on function public.obtener_revision_autorizacion() from public, anon;
revoke all on function public.validar_autorizacion_actual(bigint, text, uuid) from public, anon;
grant execute on function public.obtener_revision_autorizacion() to authenticated;
grant execute on function public.validar_autorizacion_actual(bigint, text, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Direct, versioned licenses
-- ---------------------------------------------------------------------------

create table if not exists public.licencias_empleado (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  estado text not null default 'ACTIVA' check (estado in ('ACTIVA', 'CANCELADA')),
  revision_actual integer not null default 1 check (revision_actual > 0),
  idempotency_key uuid not null,
  creada_por uuid not null references public.profiles(id) on delete restrict,
  creada_en timestamptz not null default statement_timestamp(),
  actualizada_en timestamptz not null default statement_timestamp(),
  cancelada_por uuid references public.profiles(id) on delete restrict,
  cancelada_en timestamptz,
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  unique (empresa_id, id),
  unique (empresa_id, idempotency_key)
);

create table if not exists public.licencias_empleado_versiones (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  licencia_id uuid not null,
  empleado_id uuid not null,
  revision integer not null check (revision > 0),
  fecha_inicio date not null,
  fecha_fin date not null,
  porcentaje numeric(5,2) not null check (porcentaje between 0 and 100),
  documento_path text,
  modo_recalculo text not null check (modo_recalculo in ('DESDE_INICIO', 'HACIA_ADELANTE')),
  aplicar_desde date not null,
  motivo text not null,
  creada_por uuid not null references public.profiles(id) on delete restrict,
  creada_en timestamptz not null default statement_timestamp(),
  foreign key (empresa_id, licencia_id)
    references public.licencias_empleado(empresa_id, id) on delete restrict,
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  constraint licencias_version_fechas check (fecha_fin >= fecha_inicio),
  unique (empresa_id, licencia_id, revision)
);

create table if not exists public.licencias_empleado_dias (
  licencia_id uuid not null,
  empresa_id uuid not null,
  empleado_id uuid not null,
  fecha date not null,
  revision integer not null,
  sueldo_mensual numeric(14,2) not null check (sueldo_mensual >= 0),
  porcentaje numeric(5,2) not null check (porcentaje between 0 and 100),
  monto numeric(14,2) not null check (monto >= 0),
  generado_en timestamptz not null default statement_timestamp(),
  primary key (licencia_id, fecha),
  foreign key (empresa_id, licencia_id)
    references public.licencias_empleado(empresa_id, id) on delete cascade,
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict
);

create index if not exists licencias_empleado_activa_idx
  on public.licencias_empleado (empresa_id, empleado_id, estado);
create index if not exists licencias_empleado_dias_nomina_idx
  on public.licencias_empleado_dias (empresa_id, fecha, empleado_id);

create or replace function private.regenerar_dias_licencia_0050(
  p_license uuid,
  p_from date
)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_catalog, pg_temp
as $$
declare
  v_license public.licencias_empleado%rowtype;
  v_version public.licencias_empleado_versiones%rowtype;
  v_salary numeric(14,2);
begin
  select * into v_license
  from public.licencias_empleado
  where id = p_license
  for update;
  if not found or v_license.estado <> 'ACTIVA' then return; end if;

  select * into strict v_version
  from public.licencias_empleado_versiones
  where empresa_id = v_license.empresa_id
    and licencia_id = v_license.id
    and revision = v_license.revision_actual;

  select coalesce(salario, 0) into v_salary
  from public.empleados
  where empresa_id = v_license.empresa_id and id = v_license.empleado_id;

  delete from public.licencias_empleado_dias
  where licencia_id = v_license.id and fecha >= p_from;

  insert into public.licencias_empleado_dias (
    licencia_id, empresa_id, empleado_id, fecha, revision,
    sueldo_mensual, porcentaje, monto
  )
  select
    v_license.id, v_license.empresa_id, v_license.empleado_id, day::date,
    v_version.revision, v_salary, v_version.porcentaje,
    round((v_salary / 30.0) * (v_version.porcentaje / 100.0), 2)
  from generate_series(
    greatest(v_version.fecha_inicio, p_from)::timestamptz,
    v_version.fecha_fin::timestamptz,
    interval '1 day'
  ) day;
end;
$$;

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

  select * into v_license
  from public.licencias_empleado
  where empresa_id = v_company and idempotency_key = p_idempotency_key;
  if found then
    return jsonb_build_object('id', v_license.id, 'idempotent_replay', true);
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
  return jsonb_build_object('id', v_license.id, 'revision', 1, 'estado', 'ACTIVA', 'idempotent_replay', false);
end;
$$;

create or replace function public.modificar_licencia_empleado(
  p_licencia uuid,
  p_fecha_inicio date,
  p_fecha_fin date,
  p_porcentaje numeric,
  p_documento_path text,
  p_modo text,
  p_aplicar_desde date,
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
  v_license public.licencias_empleado%rowtype;
  v_mode text := upper(btrim(coalesce(p_modo, '')));
  v_from date;
begin
  select * into v_license
  from public.licencias_empleado
  where empresa_id = v_company and id = p_licencia
  for update;
  if not found or v_license.estado <> 'ACTIVA' then
    raise exception using errcode = 'P5001', message = 'ACTIVE_LICENSE_NOT_FOUND';
  end if;
  if not public.puede_operar_empleado_en_alcance(v_license.empleado_id, 'licencias.gestionar') then
    raise exception using errcode = '42501', message = 'LICENSE_SCOPE_DENIED';
  end if;
  if v_mode not in ('DESDE_INICIO', 'HACIA_ADELANTE')
     or p_fecha_inicio is null or p_fecha_fin < p_fecha_inicio
     or p_porcentaje not between 0 and 100
     or nullif(btrim(p_motivo), '') is null
  then
    raise exception using errcode = '22023', message = 'LICENSE_INPUT_INVALID';
  end if;
  v_from := case
    when v_mode = 'DESDE_INICIO' then p_fecha_inicio
    else greatest(coalesce(p_aplicar_desde, current_date), p_fecha_inicio)
  end;
  if v_from > p_fecha_fin then
    raise exception using errcode = '22023', message = 'LICENSE_FORWARD_DATE_INVALID';
  end if;

  update public.licencias_empleado
  set revision_actual = revision_actual + 1,
      actualizada_en = statement_timestamp()
  where id = v_license.id
  returning * into v_license;

  insert into public.licencias_empleado_versiones (
    empresa_id, licencia_id, empleado_id, revision, fecha_inicio, fecha_fin,
    porcentaje, documento_path, modo_recalculo, aplicar_desde, motivo, creada_por
  ) values (
    v_company, v_license.id, v_license.empleado_id, v_license.revision_actual,
    p_fecha_inicio, p_fecha_fin, p_porcentaje, nullif(btrim(p_documento_path), ''),
    v_mode, v_from, btrim(p_motivo), v_actor
  );
  if v_mode = 'DESDE_INICIO' then
    delete from public.licencias_empleado_dias where licencia_id = v_license.id;
  end if;
  perform private.regenerar_dias_licencia_0050(v_license.id, v_from);
  return jsonb_build_object('id', v_license.id, 'revision', v_license.revision_actual, 'estado', 'ACTIVA');
end;
$$;

create or replace function public.cancelar_licencia_empleado(
  p_licencia uuid,
  p_motivo text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_company uuid := public.obtener_empresa_actual();
  v_actor uuid := auth.uid();
  v_license public.licencias_empleado%rowtype;
begin
  select * into v_license
  from public.licencias_empleado
  where empresa_id = v_company and id = p_licencia
  for update;
  if not found or v_license.estado <> 'ACTIVA' then
    raise exception using errcode = 'P5001', message = 'ACTIVE_LICENSE_NOT_FOUND';
  end if;
  if not public.puede_operar_empleado_en_alcance(v_license.empleado_id, 'licencias.gestionar') then
    raise exception using errcode = '42501', message = 'LICENSE_SCOPE_DENIED';
  end if;
  if nullif(btrim(p_motivo), '') is null then
    raise exception using errcode = '22023', message = 'LICENSE_CANCEL_REASON_REQUIRED';
  end if;
  update public.licencias_empleado
  set estado = 'CANCELADA', cancelada_por = v_actor,
      cancelada_en = statement_timestamp(), actualizada_en = statement_timestamp()
  where id = v_license.id;
  delete from public.licencias_empleado_dias where licencia_id = v_license.id;
  return jsonb_build_object('id', v_license.id, 'estado', 'CANCELADA');
end;
$$;

create or replace function public.listar_licencias_empleado(p_empleado uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_company uuid := public.obtener_empresa_actual();
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', l.id,
      'employee_id', l.empleado_id,
      'employee_name', e.nombre_completo,
      'employee_code', e.codigo_empleado,
      'state', l.estado,
      'effective_state', case
        when l.estado = 'ACTIVA' and current_date between v.fecha_inicio and v.fecha_fin then 'EN LICENCIA'
        when l.estado = 'ACTIVA' and current_date > v.fecha_fin then 'ACTIVO'
        else l.estado
      end,
      'revision', v.revision,
      'start_date', v.fecha_inicio,
      'end_date', v.fecha_fin,
      'percent', v.porcentaje,
      'document_path', v.documento_path,
      'recalculation_mode', v.modo_recalculo,
      'apply_from', v.aplicar_desde,
      'total_amount', coalesce((select sum(d.monto) from public.licencias_empleado_dias d where d.licencia_id = l.id), 0)
    ) order by v.fecha_inicio desc, l.id)
    from public.licencias_empleado l
    join public.licencias_empleado_versiones v
      on v.empresa_id = l.empresa_id and v.licencia_id = l.id and v.revision = l.revision_actual
    join public.empleados e on e.empresa_id = l.empresa_id and e.id = l.empleado_id
    where l.empresa_id = v_company
      and (p_empleado is null or l.empleado_id = p_empleado)
      and public.puede_operar_empleado_en_alcance(l.empleado_id, 'licencias.gestionar')
  ), '[]'::jsonb);
end;
$$;

create or replace function private.licencia_activa_en_fecha_0050(
  p_company uuid,
  p_employee uuid,
  p_date date
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog, pg_temp
as $$
  select exists (
    select 1
    from public.licencias_empleado l
    join public.licencias_empleado_versiones v
      on v.empresa_id = l.empresa_id and v.licencia_id = l.id and v.revision = l.revision_actual
    where l.empresa_id = p_company and l.empleado_id = p_employee
      and l.estado = 'ACTIVA' and p_date between v.fecha_inicio and v.fecha_fin
  )
$$;

create or replace function private.salary_change_license_days_0050()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_license record;
begin
  if old.salario is distinct from new.salario then
    for v_license in
      select id from public.licencias_empleado
      where empresa_id = new.empresa_id and empleado_id = new.id and estado = 'ACTIVA'
    loop
      perform private.regenerar_dias_licencia_0050(v_license.id, current_date);
    end loop;
  end if;
  if old.perfil_id is distinct from new.perfil_id
     or old.departamento_id is distinct from new.departamento_id
     or old.sucursal_id is distinct from new.sucursal_id
     or old.activo is distinct from new.activo
     or old.estado_laboral is distinct from new.estado_laboral
  then
    perform private.bump_profile_authorization_0050(coalesce(new.perfil_id, old.perfil_id));
  end if;
  return new;
end;
$$;

drop trigger if exists employee_license_salary_and_auth_0050 on public.empleados;
create trigger employee_license_salary_and_auth_0050
after update of salario, perfil_id, departamento_id, sucursal_id, activo, estado_laboral
on public.empleados
for each row execute function private.salary_change_license_days_0050();

-- ---------------------------------------------------------------------------
-- Facial terminal GENERAL / DEPARTMENTS
-- ---------------------------------------------------------------------------

alter table public.dispositivos_android
  add column if not exists tipo_uso text not null default 'GENERAL',
  add column if not exists configuracion_revision bigint not null default 1,
  add column if not exists configurado_en timestamptz not null default statement_timestamp(),
  add column if not exists configurado_por uuid references public.profiles(id) on delete set null;

alter table public.codigos_enrolamiento_dispositivo
  add column if not exists tipo_uso text not null default 'GENERAL';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'dispositivos_android_tipo_uso_check') then
    alter table public.dispositivos_android add constraint dispositivos_android_tipo_uso_check
      check (tipo_uso in ('GENERAL', 'DEPARTMENTS'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'codigos_enrolamiento_tipo_uso_check') then
    alter table public.codigos_enrolamiento_dispositivo add constraint codigos_enrolamiento_tipo_uso_check
      check (tipo_uso in ('GENERAL', 'DEPARTMENTS'));
  end if;
end;
$$;

create table if not exists public.dispositivo_departamentos (
  empresa_id uuid not null,
  dispositivo_id uuid not null,
  sucursal_id uuid not null,
  departamento_id uuid not null,
  creado_por uuid references public.profiles(id) on delete set null,
  creado_en timestamptz not null default statement_timestamp(),
  primary key (dispositivo_id, departamento_id),
  foreign key (empresa_id, dispositivo_id)
    references public.dispositivos_android(empresa_id, id) on delete cascade,
  foreign key (empresa_id, sucursal_id, departamento_id)
    references public.departments(company_id, branch_id, id) on delete cascade
);

create table if not exists public.codigo_enrolamiento_departamentos (
  empresa_id uuid not null,
  codigo_enrolamiento_id uuid not null references public.codigos_enrolamiento_dispositivo(id) on delete cascade,
  sucursal_id uuid not null,
  departamento_id uuid not null,
  primary key (codigo_enrolamiento_id, departamento_id),
  foreign key (empresa_id, sucursal_id, departamento_id)
    references public.departments(company_id, branch_id, id) on delete cascade
);

create table if not exists public.dispositivo_empleados_sincronizados (
  empresa_id uuid not null,
  dispositivo_id uuid not null,
  empleado_id uuid not null,
  elegible boolean not null,
  employee_updated_at timestamptz not null,
  sincronizado_en timestamptz not null default statement_timestamp(),
  primary key (dispositivo_id, empleado_id),
  foreign key (empresa_id, dispositivo_id)
    references public.dispositivos_android(empresa_id, id) on delete cascade,
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete cascade
);

create index if not exists dispositivo_departamentos_scope_idx
  on public.dispositivo_departamentos (empresa_id, sucursal_id, departamento_id);
create index if not exists dispositivo_empleados_elegibles_idx
  on public.dispositivo_empleados_sincronizados (empresa_id, dispositivo_id, elegible);

create or replace function public.configurar_terminal_facial(
  p_dispositivo uuid,
  p_sucursal uuid,
  p_tipo text,
  p_departamentos uuid[],
  p_motivo text
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_company uuid := public.obtener_empresa_actual();
  v_actor uuid := auth.uid();
  v_type text := upper(btrim(coalesce(p_tipo, '')));
  v_departments uuid[] := coalesce((select array_agg(distinct x) from unnest(coalesce(p_departamentos, '{}'::uuid[])) x), '{}'::uuid[]);
  v_valid integer;
  v_revision bigint;
begin
  if not public.tiene_permiso('kiosk.face_mode_manage')
     and not public.tiene_permiso('dispositivos.registrar')
  then
    raise exception using errcode = '42501', message = 'TERMINAL_CONFIGURATION_PERMISSION_DENIED';
  end if;
  if v_type not in ('GENERAL', 'DEPARTMENTS') or p_sucursal is null
     or nullif(btrim(p_motivo), '') is null
  then
    raise exception using errcode = '22023', message = 'TERMINAL_CONFIGURATION_INVALID';
  end if;
  if not exists (
    select 1 from public.branches
    where id = p_sucursal and company_id = v_company and status = 'active'
  ) then
    raise exception using errcode = '22023', message = 'TERMINAL_BRANCH_INVALID';
  end if;
  if v_type = 'GENERAL' and cardinality(v_departments) <> 0 then
    raise exception using errcode = '22023', message = 'GENERAL_TERMINAL_DEPARTMENTS_NOT_ALLOWED';
  end if;
  if v_type = 'DEPARTMENTS' and cardinality(v_departments) = 0 then
    raise exception using errcode = '22023', message = 'TERMINAL_DEPARTMENT_REQUIRED';
  end if;
  if v_type = 'DEPARTMENTS' then
    select count(*) into v_valid
    from public.departments d
    where d.id = any(v_departments)
      and d.company_id = v_company and d.branch_id = p_sucursal and d.is_active;
    if v_valid <> cardinality(v_departments) then
      raise exception using errcode = '42501', message = 'TERMINAL_DEPARTMENT_SCOPE_INVALID';
    end if;
  end if;

  update public.dispositivos_android
  set sucursal_id = p_sucursal,
      tipo_uso = v_type,
      configuracion_revision = configuracion_revision + 1,
      configurado_en = statement_timestamp(),
      configurado_por = v_actor
  where id = p_dispositivo and empresa_id = v_company and estado = 'activo'
  returning configuracion_revision into v_revision;
  if not found then
    raise exception using errcode = 'P5002', message = 'ACTIVE_TERMINAL_NOT_FOUND';
  end if;

  delete from public.dispositivo_departamentos
  where empresa_id = v_company and dispositivo_id = p_dispositivo;
  if v_type = 'DEPARTMENTS' then
    insert into public.dispositivo_departamentos (
      empresa_id, dispositivo_id, sucursal_id, departamento_id, creado_por
    )
    select v_company, p_dispositivo, p_sucursal, x, v_actor from unnest(v_departments) x;
  end if;
  return jsonb_build_object(
    'device_id', p_dispositivo,
    'branch_id', p_sucursal,
    'usage_type', v_type,
    'department_ids', to_jsonb(v_departments),
    'configuration_revision', v_revision
  );
end;
$$;

create or replace function public.aplicar_configuracion_codigo_terminal_internal(
  p_enrollment uuid,
  p_device uuid
)
returns void
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_code public.codigos_enrolamiento_dispositivo%rowtype;
begin
  select * into strict v_code
  from public.codigos_enrolamiento_dispositivo
  where id = p_enrollment;
  update public.dispositivos_android
  set sucursal_id = v_code.sucursal_id,
      tipo_uso = v_code.tipo_uso,
      configuracion_revision = configuracion_revision + 1,
      configurado_en = statement_timestamp(),
      configurado_por = v_code.creado_por
  where id = p_device and empresa_id = v_code.empresa_id;
  delete from public.dispositivo_departamentos where dispositivo_id = p_device;
  insert into public.dispositivo_departamentos (
    empresa_id, dispositivo_id, sucursal_id, departamento_id, creado_por
  )
  select c.empresa_id, p_device, c.sucursal_id, c.departamento_id, v_code.creado_por
  from public.codigo_enrolamiento_departamentos c
  where c.codigo_enrolamiento_id = p_enrollment;
end;
$$;

create or replace function public.terminal_empleado_elegible(
  p_empresa uuid,
  p_dispositivo uuid,
  p_empleado uuid
)
returns boolean
language sql
stable
security definer
set search_path = public, pg_catalog, pg_temp
as $$
  select exists (
    select 1
    from public.dispositivos_android d
    join public.empleados e on e.empresa_id = d.empresa_id and e.id = p_empleado
    where d.empresa_id = p_empresa and d.id = p_dispositivo and d.estado = 'activo'
      and e.activo and lower(coalesce(e.estado_laboral, '')) in ('activo', 'active')
      and e.jornada_habilitada
      and not private.licencia_activa_en_fecha_0050(e.empresa_id, e.id, current_date)
      and (
        d.tipo_uso = 'GENERAL'
        or (
          d.tipo_uso = 'DEPARTMENTS'
          and exists (
            select 1
            from public.dispositivo_departamentos dd
            join public.departments dep
              on dep.company_id = dd.empresa_id
             and dep.branch_id = dd.sucursal_id
             and dep.id = dd.departamento_id
             and dep.is_active
            where dd.empresa_id = d.empresa_id
              and dd.dispositivo_id = d.id
              and dd.departamento_id = e.departamento_id
          )
        )
      )
  )
$$;

create or replace function public.obtener_configuracion_terminal_dispositivo(
  p_empresa uuid,
  p_dispositivo uuid
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_catalog, pg_temp
as $$
  select jsonb_build_object(
    'device_id', d.id,
    'company_id', d.empresa_id,
    'branch_id', d.sucursal_id,
    'usage_type', d.tipo_uso,
    'configuration_revision', d.configuracion_revision,
    'department_ids', coalesce((
      select jsonb_agg(dd.departamento_id order by dd.departamento_id)
      from public.dispositivo_departamentos dd
      join public.departments dep on dep.id = dd.departamento_id
        and dep.company_id = dd.empresa_id and dep.is_active
      where dd.empresa_id = d.empresa_id and dd.dispositivo_id = d.id
    ), '[]'::jsonb)
  )
  from public.dispositivos_android d
  where d.empresa_id = p_empresa and d.id = p_dispositivo and d.estado = 'activo'
$$;

create or replace function private.cleanup_terminal_departments_0050()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
begin
  if not new.is_active or new.branch_id is distinct from old.branch_id then
    delete from public.dispositivo_departamentos
    where empresa_id = new.company_id and departamento_id = new.id;
    update public.dispositivos_android d
    set configuracion_revision = configuracion_revision + 1,
        configurado_en = statement_timestamp()
    where d.empresa_id = new.company_id
      and d.tipo_uso = 'DEPARTMENTS'
      and exists (
        select 1 from public.dispositivo_empleados_sincronizados s
        where s.dispositivo_id = d.id and s.empresa_id = d.empresa_id and s.elegible
      );
  end if;
  return new;
end;
$$;

drop trigger if exists departments_terminal_cleanup_0050 on public.departments;
create trigger departments_terminal_cleanup_0050
after update of is_active, branch_id on public.departments
for each row execute function private.cleanup_terminal_departments_0050();

-- ---------------------------------------------------------------------------
-- NO PAGAR: auditable incomplete-journey resolution
-- ---------------------------------------------------------------------------

create table if not exists public.nomina_jornadas_incompletas_resueltas (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  jornada_id uuid not null,
  empleado_id uuid not null,
  fecha date not null,
  ultimo_evento text not null,
  horas_pagables numeric(6,2) not null check (horas_pagables >= 0),
  horas_manual boolean not null,
  monto numeric(14,2) not null check (monto >= 0),
  estado text not null default 'JORNADA INCOMPLETA RESUELTA',
  motivo text not null,
  resuelta_por uuid not null references public.profiles(id) on delete restrict,
  resuelta_en timestamptz not null default statement_timestamp(),
  actualizada_en timestamptz not null default statement_timestamp(),
  foreign key (empresa_id, jornada_id)
    references public.jornadas(empresa_id, id) on delete restrict,
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  unique (empresa_id, jornada_id)
);

create index if not exists nomina_incompletas_employee_date_idx
  on public.nomina_jornadas_incompletas_resueltas (empresa_id, empleado_id, fecha);

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

create or replace function public.listar_jornadas_incompletas_no_pagar()
returns jsonb
language sql
stable
security definer
set search_path = public, pg_catalog, pg_temp
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'journey_id', j.id,
    'employee_id', j.empleado_id,
    'employee_code', e.codigo_empleado,
    'employee_name', e.nombre_completo,
    'work_date', j.fecha_laboral,
    'state', j.estado,
    'last_event', (
      select ev.accion from public.jornada_eventos ev
      where ev.empresa_id = j.empresa_id and ev.jornada_id = j.id
      order by ev.ocurrido_en desc, ev.id desc limit 1
    ),
    'manual_hours_allowed', (
      select count(*) = 1 and max(ev.accion) = 'INICIAR'
      from public.jornada_eventos ev
      where ev.empresa_id = j.empresa_id and ev.jornada_id = j.id
    )
  ) order by j.fecha_laboral desc, e.codigo_empleado), '[]'::jsonb)
  from public.jornadas j
  join public.empleados e on e.empresa_id = j.empresa_id and e.id = j.empleado_id
  where j.empresa_id = public.obtener_empresa_actual()
    and j.finalizado_en is null
    and not exists (
      select 1 from public.nomina_jornadas_incompletas_resueltas r
      where r.empresa_id = j.empresa_id and r.jornada_id = j.id
    )
    and public.puede_operar_empleado_en_alcance(j.empleado_id, 'nomina.no_pagar')
$$;

-- ---------------------------------------------------------------------------
-- Prior-period adjustments
-- ---------------------------------------------------------------------------

create table if not exists public.nomina_ajustes_anteriores (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  fecha_origen date not null,
  periodo_cerrado_id uuid not null,
  resolucion_anterior_id uuid not null,
  resolucion_nueva_id uuid not null,
  horas_normales_delta numeric(10,2) not null,
  horas_extra_delta numeric(10,2) not null,
  festivo_delta numeric(14,2) not null,
  pausas_delta integer not null,
  tardanza_delta integer not null,
  monto_bruto numeric(14,2) not null,
  snapshot_anterior jsonb not null,
  snapshot_nuevo jsonb not null,
  estado text not null default 'PENDIENTE' check (estado in ('PENDIENTE', 'RESERVADO', 'APLICADO')),
  periodo_aplicado_id uuid,
  aplicado_en timestamptz,
  creado_en timestamptz not null default statement_timestamp(),
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  foreign key (empresa_id, periodo_cerrado_id)
    references public.nomina_periodos(empresa_id, id) on delete restrict,
  foreign key (empresa_id, periodo_aplicado_id)
    references public.nomina_periodos(empresa_id, id) on delete restrict,
  unique (empresa_id, resolucion_nueva_id)
);

create index if not exists nomina_ajustes_anteriores_pending_idx
  on public.nomina_ajustes_anteriores (empresa_id, estado, empleado_id, fecha_origen);

create or replace function private.capture_prior_adjustment_0050()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_previous public.nomina_resoluciones_diarias%rowtype;
  v_closed uuid;
  v_old_total numeric(14,2);
  v_new_total numeric(14,2);
begin
  if new.revision <= 1 then return new; end if;
  select id into v_closed
  from public.nomina_periodos
  where empresa_id = new.empresa_id and estado = 'CERRADA'
    and new.fecha_local between fecha_inicio and fecha_fin
  order by cerrada_en desc nulls last, id
  limit 1;
  if v_closed is null then return new; end if;

  select * into v_previous
  from public.nomina_resoluciones_diarias
  where empresa_id = new.empresa_id and empleado_id = new.empleado_id
    and fecha_local = new.fecha_local and revision < new.revision
  order by revision desc limit 1;
  if not found then return new; end if;

  v_old_total := v_previous.objetivo_base_nominal + v_previous.objetivo_ajuste_diario
    + v_previous.objetivo_hora_extra + v_previous.objetivo_premium_festivo
    + v_previous.objetivo_complemento_30_dias;
  v_new_total := new.objetivo_base_nominal + new.objetivo_ajuste_diario
    + new.objetivo_hora_extra + new.objetivo_premium_festivo
    + new.objetivo_complemento_30_dias;

  insert into public.nomina_ajustes_anteriores (
    empresa_id, empleado_id, fecha_origen, periodo_cerrado_id,
    resolucion_anterior_id, resolucion_nueva_id,
    horas_normales_delta, horas_extra_delta, festivo_delta,
    pausas_delta, tardanza_delta, monto_bruto,
    snapshot_anterior, snapshot_nuevo
  ) values (
    new.empresa_id, new.empleado_id, new.fecha_local, v_closed,
    v_previous.id, new.id,
    round((new.minutos_normales_reconocidos - v_previous.minutos_normales_reconocidos) / 60.0, 2),
    round((new.minutos_extra - v_previous.minutos_extra) / 60.0, 2),
    new.objetivo_premium_festivo - v_previous.objetivo_premium_festivo,
    coalesce((new.snapshot #>> '{jornada,minutos_pausa}')::integer, 0)
      - coalesce((v_previous.snapshot #>> '{jornada,minutos_pausa}')::integer, 0),
    coalesce((new.snapshot ->> 'minutos_tardanza')::integer, 0)
      - coalesce((v_previous.snapshot ->> 'minutos_tardanza')::integer, 0),
    round(v_new_total - v_old_total, 2),
    v_previous.snapshot, new.snapshot
  )
  on conflict (empresa_id, resolucion_nueva_id) do nothing;
  return new;
end;
$$;

drop trigger if exists capture_prior_adjustment_0050 on public.nomina_resoluciones_diarias;
create trigger capture_prior_adjustment_0050
after insert on public.nomina_resoluciones_diarias
for each row execute function private.capture_prior_adjustment_0050();

create or replace function public.aplicar_ajustes_anteriores_periodo(p_periodo uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_company uuid := public.obtener_empresa_actual();
  v_period public.nomina_periodos%rowtype;
  v_payroll public.nominas%rowtype;
  v_count integer := 0;
begin
  if not public.tiene_permiso('nomina.ajustes_anteriores') then
    raise exception using errcode = '42501', message = 'PRIOR_ADJUSTMENT_PERMISSION_DENIED';
  end if;
  select * into v_period from public.nomina_periodos
  where empresa_id = v_company and id = p_periodo for update;
  if not found or v_period.estado in ('CERRADA', 'ANULADA') then
    raise exception using errcode = '55000', message = 'PAYROLL_NOT_EDITABLE';
  end if;
  select * into v_payroll from public.nominas
  where empresa_id = v_company and periodo_id = p_periodo;
  if not found then
    raise exception using errcode = '55000', message = 'PAYROLL_NOT_CALCULATED';
  end if;

  with totals as (
    select a.empleado_id, sum(a.monto_bruto) amount, jsonb_agg(jsonb_build_object(
      'id', a.id, 'date', a.fecha_origen, 'amount', a.monto_bruto,
      'normal_hours', a.horas_normales_delta, 'overtime_hours', a.horas_extra_delta,
      'holiday', a.festivo_delta, 'break_minutes', a.pausas_delta,
      'late_minutes', a.tardanza_delta
    ) order by a.fecha_origen, a.id) details
    from public.nomina_ajustes_anteriores a
    where a.empresa_id = v_company
      and (a.estado = 'PENDIENTE' or (a.estado = 'RESERVADO' and a.periodo_aplicado_id = p_periodo))
      and a.fecha_origen < v_period.fecha_inicio
    group by a.empleado_id
  )
  update public.nomina_detalles d
  set bruto = greatest(0,
        coalesce((d.resultados ->> 'p0_base_bruto')::numeric, d.bruto) + totals.amount),
      neto = greatest(0,
        coalesce((d.resultados ->> 'p0_base_neto')::numeric, d.neto)
        + totals.amount * (1 - case when d.bruto > 0 then d.total_impuestos / d.bruto else 0 end)),
      resultados = d.resultados || jsonb_build_object(
        'p0_base_bruto', coalesce((d.resultados ->> 'p0_base_bruto')::numeric, d.bruto),
        'p0_base_neto', coalesce((d.resultados ->> 'p0_base_neto')::numeric, d.neto),
        'total_ajustes_anteriores', totals.amount,
        'ajustes_anteriores_detalle', totals.details
      )
  from totals
  where d.empresa_id = v_company and d.nomina_id = v_payroll.id
    and d.empleado_id = totals.empleado_id;

  update public.nomina_ajustes_anteriores a
  set estado = 'RESERVADO', periodo_aplicado_id = p_periodo
  where a.empresa_id = v_company and a.estado = 'PENDIENTE'
    and a.fecha_origen < v_period.fecha_inicio
    and exists (
      select 1 from public.nomina_detalles d
      where d.empresa_id = a.empresa_id and d.nomina_id = v_payroll.id
        and d.empleado_id = a.empleado_id
    );
  get diagnostics v_count = row_count;
  return jsonb_build_object('period_id', p_periodo, 'adjustments_reserved', v_count);
end;
$$;

create or replace function public.calcular_nomina_p0(p_periodo uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_result jsonb;
  v_adjustments jsonb;
begin
  v_result := public.calcular_nomina(p_periodo);
  if public.tiene_permiso('nomina.ajustes_anteriores') then
    v_adjustments := public.aplicar_ajustes_anteriores_periodo(p_periodo);
  else
    v_adjustments := jsonb_build_object('adjustments_reserved', 0);
  end if;
  return coalesce(v_result, '{}'::jsonb) || v_adjustments;
end;
$$;

create or replace function private.complete_prior_adjustments_0050()
returns trigger
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
begin
  if new.estado = 'CERRADA' and old.estado is distinct from new.estado then
    update public.nomina_ajustes_anteriores
    set estado = 'APLICADO', aplicado_en = statement_timestamp()
    where empresa_id = new.empresa_id and periodo_aplicado_id = new.id and estado = 'RESERVADO';
  end if;
  return new;
end;
$$;

drop trigger if exists complete_prior_adjustments_0050 on public.nomina_periodos;
create trigger complete_prior_adjustments_0050
after update of estado on public.nomina_periodos
for each row execute function private.complete_prior_adjustments_0050();

create or replace function public.listar_ajustes_anteriores(p_periodo uuid default null)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_catalog, pg_temp
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'employee_id', a.empleado_id,
    'employee_code', e.codigo_empleado, 'employee_name', e.nombre_completo,
    'date', a.fecha_origen, 'amount', a.monto_bruto,
    'normal_hours', a.horas_normales_delta, 'overtime_hours', a.horas_extra_delta,
    'holiday', a.festivo_delta, 'break_minutes', a.pausas_delta,
    'late_minutes', a.tardanza_delta, 'state', a.estado,
    'applied_period_id', a.periodo_aplicado_id
  ) order by a.fecha_origen, a.id), '[]'::jsonb)
  from public.nomina_ajustes_anteriores a
  join public.empleados e on e.empresa_id = a.empresa_id and e.id = a.empleado_id
  where a.empresa_id = public.obtener_empresa_actual()
    and (p_periodo is null or a.periodo_aplicado_id = p_periodo or a.estado = 'PENDIENTE')
    and public.puede_operar_empleado_en_alcance(a.empleado_id, 'nomina.ajustes_anteriores')
$$;

-- ---------------------------------------------------------------------------
-- Monthly employee watch list (never blocks attendance)
-- ---------------------------------------------------------------------------

create table if not exists public.lista_negra_mensual (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  anio integer not null check (anio between 2000 and 2200),
  mes integer not null check (mes between 1 and 12),
  categoria text not null check (categoria in ('AUSENCIAS', 'TARDANZA', 'SIN FINALIZAR JORNADA', 'MODIFICADOS')),
  contador integer not null check (contador >= 0),
  primera_entrada_en timestamptz not null default statement_timestamp(),
  actividad_reciente_en timestamptz not null,
  detalle jsonb not null default '[]'::jsonb,
  archivado boolean not null default false,
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  unique (empresa_id, empleado_id, anio, mes, categoria)
);

create index if not exists lista_negra_month_activity_idx
  on public.lista_negra_mensual (empresa_id, anio, mes, actividad_reciente_en desc);

create or replace function public.refrescar_lista_negra_mensual(
  p_anio integer default extract(year from current_date)::integer,
  p_mes integer default extract(month from current_date)::integer
)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_catalog, pg_temp
as $$
declare
  v_company uuid := public.obtener_empresa_actual();
  v_from date := make_date(p_anio, p_mes, 1);
  v_to date := (make_date(p_anio, p_mes, 1) + interval '1 month - 1 day')::date;
begin
  if not public.tiene_permiso('lista_negra.ver') then
    raise exception using errcode = '42501', message = 'BLACKLIST_PERMISSION_DENIED';
  end if;
  update public.lista_negra_mensual
  set archivado = true
  where empresa_id = v_company and make_date(anio, mes, 1) < v_from;

  with current_resolution as (
    select distinct on (r.empleado_id, r.fecha_local) r.*
    from public.nomina_resoluciones_diarias r
    where r.empresa_id = v_company and r.fecha_local between v_from and v_to
    order by r.empleado_id, r.fecha_local, r.revision desc
  ), categories as (
    select empleado_id, 'AUSENCIAS'::text category, count(*)::integer counter,
      max(fecha_local)::timestamptz recent,
      jsonb_agg(jsonb_build_object('date', fecha_local) order by fecha_local) detail
    from current_resolution where es_ausencia
    group by empleado_id having count(*) > 2
    union all
    select empleado_id, 'TARDANZA', count(*)::integer,
      max(fecha_local)::timestamptz,
      jsonb_agg(jsonb_build_object('date', fecha_local, 'minutes', snapshot ->> 'minutos_tardanza') order by fecha_local)
    from current_resolution
    where coalesce(nullif(snapshot ->> 'minutos_tardanza', ''), '0')::integer > 0
    group by empleado_id having count(*) > 5
    union all
    select j.empleado_id, 'SIN FINALIZAR JORNADA', count(*)::integer,
      max(j.actualizada_en),
      jsonb_agg(jsonb_build_object('date', j.fecha_laboral, 'state', j.estado) order by j.fecha_laboral)
    from public.jornadas j
    where j.empresa_id = v_company and j.fecha_laboral between v_from and v_to
      and j.finalizado_en is null
      and not exists (
        select 1 from public.nomina_jornadas_incompletas_resueltas x
        where x.empresa_id = j.empresa_id and x.jornada_id = j.id
      )
    group by j.empleado_id having count(*) > 5
    union all
    select r.empleado_id, 'MODIFICADOS', count(distinct r.fecha_local)::integer,
      max(r.fecha_local)::timestamptz,
      jsonb_agg(jsonb_build_object('date', r.fecha_local, 'revision', r.max_revision) order by r.fecha_local)
    from (
      select empleado_id, fecha_local, max(revision) max_revision
      from public.nomina_resoluciones_diarias
      where empresa_id = v_company and fecha_local between v_from and v_to
      group by empleado_id, fecha_local having max(revision) > 1
    ) r group by r.empleado_id
  )
  insert into public.lista_negra_mensual (
    empresa_id, empleado_id, anio, mes, categoria, contador,
    actividad_reciente_en, detalle, archivado
  )
  select v_company, empleado_id, p_anio, p_mes, category, counter, recent, detail, false
  from categories
  on conflict (empresa_id, empleado_id, anio, mes, categoria) do update set
    contador = greatest(public.lista_negra_mensual.contador, excluded.contador),
    actividad_reciente_en = greatest(public.lista_negra_mensual.actividad_reciente_en, excluded.actividad_reciente_en),
    detalle = excluded.detalle;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', b.id, 'employee_id', b.empleado_id,
      'employee_code', e.codigo_empleado, 'employee_name', e.nombre_completo,
      'year', b.anio, 'month', b.mes, 'category', b.categoria,
      'count', b.contador, 'last_activity', b.actividad_reciente_en,
      'detail', b.detalle, 'archived', b.archivado
    ) order by b.actividad_reciente_en desc, e.codigo_empleado, b.categoria)
    from public.lista_negra_mensual b
    join public.empleados e on e.empresa_id = b.empresa_id and e.id = b.empleado_id
    where b.empresa_id = v_company and b.anio = p_anio and b.mes = p_mes
      and public.puede_operar_empleado_en_alcance(b.empleado_id, 'lista_negra.ver')
  ), '[]'::jsonb);
end;
$$;

create or replace function public.reporte_lista_negra_empleado(
  p_empleado uuid,
  p_anio integer,
  p_mes integer
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_catalog, pg_temp
as $$
  select case
    when not public.puede_operar_empleado_en_alcance(p_empleado, 'lista_negra.ver')
      then jsonb_build_object('error', 'BLACKLIST_SCOPE_DENIED')
    else jsonb_build_object(
      'employee', (select jsonb_build_object('id', id, 'code', codigo_empleado, 'name', nombre_completo)
        from public.empleados where empresa_id = public.obtener_empresa_actual() and id = p_empleado),
      'year', p_anio, 'month', p_mes,
      'categories', coalesce((select jsonb_agg(jsonb_build_object(
        'category', categoria, 'count', contador, 'last_activity', actividad_reciente_en, 'detail', detalle
      ) order by actividad_reciente_en desc)
        from public.lista_negra_mensual
        where empresa_id = public.obtener_empresa_actual() and empleado_id = p_empleado
          and anio = p_anio and mes = p_mes), '[]'::jsonb)
    )
  end
$$;

-- ---------------------------------------------------------------------------
-- Message preload now follows terminal mode, not terminal branch in GENERAL.
-- ---------------------------------------------------------------------------

create or replace function public.obtener_mensajes_pendientes_dispositivo(
  p_empresa uuid,
  p_dispositivo uuid
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_catalog, pg_temp
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id, 'employee_id', m.empleado_id, 'type', m.tipo,
    'text', m.contenido_texto, 'audio_object_path', m.audio_object_path,
    'audio_duration_seconds', m.audio_duracion_segundos, 'created_at', m.creado_en
  ) order by m.creado_en), '[]'::jsonb)
  from public.mensajes_empleados m
  where m.empresa_id = p_empresa
    and public.terminal_empleado_elegible(p_empresa, p_dispositivo, m.empleado_id)
$$;

create or replace function public.obtener_mensaje_pendiente_dispositivo(
  p_empresa uuid,
  p_dispositivo uuid,
  p_empleado uuid
)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_catalog, pg_temp
as $$
  select item
  from jsonb_array_elements(public.obtener_mensajes_pendientes_dispositivo(p_empresa, p_dispositivo)) item
  where (item ->> 'employee_id')::uuid = p_empleado
  order by (item ->> 'created_at')::timestamptz limit 1
$$;

create or replace function public.confirmar_mensaje_recibido_dispositivo(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_catalog, pg_temp
as $$
declare
  v_company uuid;
  v_device uuid;
  v_employee uuid;
  v_message_id uuid;
  v_idempotency uuid;
  v_message public.mensajes_empleados%rowtype;
  v_receipt public.mensajes_empleados_recibidos%rowtype;
begin
  begin
    v_company := (payload ->> 'empresa_id')::uuid;
    v_device := (payload ->> 'dispositivo_id')::uuid;
    v_employee := (payload ->> 'empleado_id')::uuid;
    v_message_id := (payload ->> 'mensaje_id')::uuid;
    v_idempotency := (payload ->> 'idempotency_key')::uuid;
  exception when others then
    raise exception using errcode = '22023', message = 'EMPLOYEE_MESSAGE_RECEIPT_INVALID';
  end;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_message_id::text, 50));
  select * into v_receipt from public.mensajes_empleados_recibidos
  where mensaje_id = v_message_id
     or (empresa_id = v_company and idempotency_key = v_idempotency)
  order by recibido_en limit 1;
  if found then
    if v_receipt.mensaje_id <> v_message_id or v_receipt.empleado_id <> v_employee then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return jsonb_build_object('result', 'duplicate', 'message_id', v_receipt.mensaje_id, 'audio_object_path', null);
  end if;
  if not public.terminal_empleado_elegible(v_company, v_device, v_employee) then
    raise exception using errcode = '42501', message = 'EMPLOYEE_MESSAGE_DEVICE_SCOPE_DENIED';
  end if;
  select * into v_message from public.mensajes_empleados
  where empresa_id = v_company and id = v_message_id and empleado_id = v_employee
  for update;
  if not found then
    raise exception using errcode = 'P4904', message = 'EMPLOYEE_MESSAGE_NOT_FOUND';
  end if;
  insert into public.mensajes_empleados_recibidos (
    mensaje_id, empresa_id, empleado_id, dispositivo_id, idempotency_key
  ) values (v_message.id, v_company, v_employee, v_device, v_idempotency);
  delete from public.mensajes_empleados where id = v_message.id;
  return jsonb_build_object('result', 'accepted', 'message_id', v_message.id, 'audio_object_path', v_message.audio_object_path);
end;
$$;

-- RLS and grants. Direct writes stay behind RPCs.
alter table public.dispositivo_departamentos enable row level security;
alter table public.codigo_enrolamiento_departamentos enable row level security;
alter table public.dispositivo_empleados_sincronizados enable row level security;
alter table public.licencias_empleado enable row level security;
alter table public.licencias_empleado_versiones enable row level security;
alter table public.licencias_empleado_dias enable row level security;
alter table public.nomina_jornadas_incompletas_resueltas enable row level security;
alter table public.nomina_ajustes_anteriores enable row level security;
alter table public.lista_negra_mensual enable row level security;

create policy licencias_empleado_select_0050 on public.licencias_empleado
for select to authenticated using (
  empresa_id = public.obtener_empresa_actual()
  and public.puede_operar_empleado_en_alcance(empleado_id, 'licencias.gestionar')
);
create policy licencias_versiones_select_0050 on public.licencias_empleado_versiones
for select to authenticated using (
  empresa_id = public.obtener_empresa_actual()
  and public.puede_operar_empleado_en_alcance(empleado_id, 'licencias.gestionar')
);
create policy licencias_dias_select_0050 on public.licencias_empleado_dias
for select to authenticated using (
  empresa_id = public.obtener_empresa_actual()
  and (
    public.puede_operar_empleado_en_alcance(empleado_id, 'licencias.gestionar')
    or public.puede_operar_empleado_en_alcance(empleado_id, 'nomina.ver')
  )
);
create policy no_pay_select_0050 on public.nomina_jornadas_incompletas_resueltas
for select to authenticated using (
  empresa_id = public.obtener_empresa_actual()
  and public.puede_operar_empleado_en_alcance(empleado_id, 'nomina.no_pagar')
);
create policy prior_adjustments_select_0050 on public.nomina_ajustes_anteriores
for select to authenticated using (
  empresa_id = public.obtener_empresa_actual()
  and public.puede_operar_empleado_en_alcance(empleado_id, 'nomina.ajustes_anteriores')
);
create policy blacklist_select_0050 on public.lista_negra_mensual
for select to authenticated using (
  empresa_id = public.obtener_empresa_actual()
  and public.puede_operar_empleado_en_alcance(empleado_id, 'lista_negra.ver')
);

revoke all on public.dispositivo_departamentos, public.codigo_enrolamiento_departamentos,
  public.dispositivo_empleados_sincronizados from public, anon, authenticated;
grant all on public.dispositivo_departamentos, public.codigo_enrolamiento_departamentos,
  public.dispositivo_empleados_sincronizados to service_role;
revoke all on public.licencias_empleado, public.licencias_empleado_versiones,
  public.licencias_empleado_dias, public.nomina_jornadas_incompletas_resueltas,
  public.nomina_ajustes_anteriores, public.lista_negra_mensual
  from public, anon, authenticated;
grant select on public.licencias_empleado, public.licencias_empleado_versiones,
  public.licencias_empleado_dias, public.nomina_jornadas_incompletas_resueltas,
  public.nomina_ajustes_anteriores, public.lista_negra_mensual to authenticated;
grant all on public.licencias_empleado, public.licencias_empleado_versiones,
  public.licencias_empleado_dias, public.nomina_jornadas_incompletas_resueltas,
  public.nomina_ajustes_anteriores, public.lista_negra_mensual to service_role;

revoke all on function public.configurar_terminal_facial(uuid, uuid, text, uuid[], text) from public, anon;
grant execute on function public.configurar_terminal_facial(uuid, uuid, text, uuid[], text) to authenticated, service_role;
revoke all on function public.aplicar_configuracion_codigo_terminal_internal(uuid, uuid) from public, anon, authenticated;
grant execute on function public.aplicar_configuracion_codigo_terminal_internal(uuid, uuid) to service_role;
revoke all on function public.terminal_empleado_elegible(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.terminal_empleado_elegible(uuid, uuid, uuid) to service_role;
revoke all on function public.obtener_configuracion_terminal_dispositivo(uuid, uuid) from public, anon, authenticated;
grant execute on function public.obtener_configuracion_terminal_dispositivo(uuid, uuid) to service_role;
revoke all on function public.obtener_mensajes_pendientes_dispositivo(uuid, uuid) from public, anon, authenticated;
revoke all on function public.obtener_mensaje_pendiente_dispositivo(uuid, uuid, uuid) from public, anon, authenticated;
revoke all on function public.confirmar_mensaje_recibido_dispositivo(jsonb) from public, anon, authenticated;
grant execute on function public.obtener_mensajes_pendientes_dispositivo(uuid, uuid) to service_role;
grant execute on function public.obtener_mensaje_pendiente_dispositivo(uuid, uuid, uuid) to service_role;
grant execute on function public.confirmar_mensaje_recibido_dispositivo(jsonb) to service_role;

revoke all on function private.regenerar_dias_licencia_0050(uuid, date) from public, anon, authenticated, service_role;
revoke all on function private.licencia_activa_en_fecha_0050(uuid, uuid, date) from public, anon, authenticated, service_role;
revoke all on function public.crear_licencia_empleado(uuid, date, date, numeric, text, text, uuid) from public, anon;
revoke all on function public.modificar_licencia_empleado(uuid, date, date, numeric, text, text, date, text) from public, anon;
revoke all on function public.cancelar_licencia_empleado(uuid, text) from public, anon;
revoke all on function public.listar_licencias_empleado(uuid) from public, anon;
grant execute on function public.crear_licencia_empleado(uuid, date, date, numeric, text, text, uuid) to authenticated;
grant execute on function public.modificar_licencia_empleado(uuid, date, date, numeric, text, text, date, text) to authenticated;
grant execute on function public.cancelar_licencia_empleado(uuid, text) to authenticated;
grant execute on function public.listar_licencias_empleado(uuid) to authenticated;

revoke all on function public.resolver_jornada_incompleta_no_pagar(uuid, numeric, text) from public, anon;
revoke all on function public.listar_jornadas_incompletas_no_pagar() from public, anon;
grant execute on function public.resolver_jornada_incompleta_no_pagar(uuid, numeric, text) to authenticated;
grant execute on function public.listar_jornadas_incompletas_no_pagar() to authenticated;
revoke all on function public.aplicar_ajustes_anteriores_periodo(uuid) from public, anon;
revoke all on function public.calcular_nomina_p0(uuid) from public, anon;
revoke all on function public.listar_ajustes_anteriores(uuid) from public, anon;
grant execute on function public.aplicar_ajustes_anteriores_periodo(uuid) to authenticated;
grant execute on function public.calcular_nomina_p0(uuid) to authenticated;
grant execute on function public.listar_ajustes_anteriores(uuid) to authenticated;
revoke all on function public.refrescar_lista_negra_mensual(integer, integer) from public, anon;
revoke all on function public.reporte_lista_negra_empleado(uuid, integer, integer) from public, anon;
grant execute on function public.refrescar_lista_negra_mensual(integer, integer) to authenticated;
grant execute on function public.reporte_lista_negra_empleado(uuid, integer, integer) to authenticated;

comment on function public.terminal_empleado_elegible(uuid, uuid, uuid) is
  'GENERAL accepts every active employee in the same company; DEPARTMENTS requires an active configured department. Branch is punch location, never GENERAL eligibility.';
comment on table public.lista_negra_mensual is
  'Monthly follow-up snapshot only. Membership never blocks attendance by itself.';
comment on table public.nomina_ajustes_anteriores is
  'Idempotent deltas created when a daily resolution changes after its period was closed.';

commit;
