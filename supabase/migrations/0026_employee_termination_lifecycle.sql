begin;

-- La desvinculacion es un cambio de estado laboral, nunca un DELETE. Todas las
-- relaciones historicas (jornadas, nomina, prestamos, biometria y auditoria)
-- conservan el mismo empleado_id.
lock table public.empleados in share row exclusive mode;
lock table public.profiles in share row exclusive mode;

alter table public.empleados
  add column if not exists fecha_desvinculacion date,
  add column if not exists motivo_desvinculacion text,
  add column if not exists observacion_desvinculacion text,
  add column if not exists desvinculado_por uuid,
  add column if not exists actualizado_por uuid;

-- Completa bajas historicas sin inventar actores. La fecha procede de la
-- ultima escritura conocida y el texto deja claro que fue una normalizacion.
update public.empleados
set activo = false,
    fecha_desvinculacion = coalesce(
      fecha_desvinculacion,
      greatest(
        coalesce(fecha_ingreso, date '1900-01-01'),
        coalesce(updated_at::date, created_at::date, date '1900-01-01')
      )
    ),
    motivo_desvinculacion = coalesce(
      nullif(btrim(motivo_desvinculacion), ''),
      'Desvinculacion historica'
    ),
    observacion_desvinculacion = coalesce(
      nullif(btrim(observacion_desvinculacion), ''),
      'Metadatos normalizados por la migracion 0026.'
    )
where estado_laboral = 'desvinculado';

update public.empleados
set fecha_desvinculacion = null,
    motivo_desvinculacion = null,
    observacion_desvinculacion = null,
    desvinculado_por = null
where estado_laboral <> 'desvinculado';

alter table public.empleados
  add constraint empleados_desvinculado_por_misma_empresa_fk
    foreign key (empresa_id, desvinculado_por)
    references public.profiles(company_id, id)
    on delete set null (desvinculado_por),
  add constraint empleados_actualizado_por_misma_empresa_fk
    foreign key (empresa_id, actualizado_por)
    references public.profiles(company_id, id)
    on delete set null (actualizado_por),
  add constraint empleados_desvinculacion_motivo_check check (
    motivo_desvinculacion is null
    or char_length(btrim(motivo_desvinculacion)) between 3 and 500
  ),
  add constraint empleados_desvinculacion_observacion_check check (
    observacion_desvinculacion is null
    or char_length(btrim(observacion_desvinculacion)) <= 2000
  ),
  add constraint empleados_desvinculacion_consistencia_check check (
    (
      estado_laboral = 'desvinculado'
      and not activo
      and not jornada_habilitada
      and fecha_desvinculacion is not null
      and motivo_desvinculacion is not null
    )
    or (
      estado_laboral <> 'desvinculado'
      and fecha_desvinculacion is null
      and motivo_desvinculacion is null
      and observacion_desvinculacion is null
      and desvinculado_por is null
    )
  ) not valid;

comment on column public.empleados.fecha_desvinculacion is
  'Fecha efectiva de la desvinculacion actual; null para empleados vinculados.';
comment on column public.empleados.motivo_desvinculacion is
  'Motivo de la desvinculacion actual. El historial completo vive en empleado_ciclo_laboral_auditoria.';
comment on column public.empleados.observacion_desvinculacion is
  'Observacion administrativa opcional de la desvinculacion actual.';
comment on column public.empleados.desvinculado_por is
  'Perfil que ejecuto la desvinculacion actual; puede ser null solo para datos historicos.';
comment on column public.empleados.actualizado_por is
  'Perfil que realizo el ultimo cambio de ciclo laboral por RPC.';

-- Un acceso eliminado logicamente nunca puede recuperar permisos por una RPC
-- legacy que solo cambie profiles.status. El tombstone es irreversible.
update public.profiles
set status = 'inactive', updated_at = now()
where access_deleted_at is not null and status <> 'inactive';

create or replace function public.perfil_acceso_utilizable_internal(
  p_perfil uuid,
  p_empresa uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    join auth.users au on au.id = p.id
    where p.id = p_perfil
      and p.company_id = p_empresa
      and p.status = 'active'
      and p.access_deleted_at is null
      and au.deleted_at is null
      and (au.banned_until is null or au.banned_until <= now())
      and not exists (
        select 1 from public.empleados e
        where e.empresa_id = p.company_id
          and e.perfil_id = p.id
          and (not e.activo or e.estado_laboral = 'desvinculado')
      )
  )
$$;
revoke all on function public.perfil_acceso_utilizable_internal(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.perfil_acceso_utilizable_internal(uuid,uuid)
  to service_role;

create or replace function public.perfil_actual_tiene_acceso()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select public.perfil_acceso_utilizable_internal(p.id, p.company_id)
      from public.profiles p
      where p.id = (select auth.uid())
      limit 1
    ),
    false
  )
$$;
revoke all on function public.perfil_actual_tiene_acceso()
  from public, anon;
grant execute on function public.perfil_actual_tiene_acceso()
  to authenticated;

create or replace function public.enforce_profile_access_tombstone_internal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.company_id::text, 0)
  );
  if tg_op = 'UPDATE'
     and old.access_deleted_at is not null
     and new.access_deleted_at is distinct from old.access_deleted_at
  then
    raise exception using errcode = '23514', message = 'ACCESS_TOMBSTONE_IMMUTABLE';
  end if;
  if new.access_deleted_at is not null and new.status <> 'inactive' then
    raise exception using errcode = '23514', message = 'DELETED_ACCESS_MUST_REMAIN_INACTIVE';
  end if;
  if tg_op = 'UPDATE'
     and old.status = 'active'
     and old.access_deleted_at is null
     and public.es_rol_administrador_internal(old.role_id, old.company_id)
     and (
       new.status <> 'active'
       or new.access_deleted_at is not null
       or not public.es_rol_administrador_internal(new.role_id, new.company_id)
     )
     and public.perfil_acceso_utilizable_internal(old.id, old.company_id)
     and not exists (
       select 1
       from public.profiles other
       where other.company_id = old.company_id
         and other.id <> old.id
         and other.status = 'active'
         and other.access_deleted_at is null
         and public.es_rol_administrador_internal(other.role_id, old.company_id)
         and public.perfil_acceso_utilizable_internal(other.id, old.company_id)
     )
  then
    raise exception 'ULTIMO_ADMINISTRADOR_NO_DESACTIVABLE';
  end if;
  if new.status = 'active' and exists (
    select 1
    from public.empleados e
    where e.empresa_id = new.company_id
      and e.perfil_id = new.id
      and (not e.activo or e.estado_laboral = 'desvinculado')
  ) then
    raise exception using errcode = '23514', message = 'TERMINATED_EMPLOYEE_ACCESS_MUST_REMAIN_INACTIVE';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_profile_access_tombstone_internal()
  from public, anon, authenticated;
create trigger profiles_enforce_access_tombstone_before_write
before insert or update of status, access_deleted_at, role_id on public.profiles
for each row execute function public.enforce_profile_access_tombstone_internal();

create or replace function public.enforce_employee_profile_lifecycle_internal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.empresa_id::text, 0)
  );
  if new.perfil_id is not null
     and (not new.activo or new.estado_laboral = 'desvinculado')
     and exists (
       select 1
       from public.profiles p
       where p.company_id = new.empresa_id
         and p.id = new.perfil_id
         and p.status = 'active'
     )
  then
    raise exception using errcode = '23514', message = 'TERMINATED_EMPLOYEE_ACCESS_MUST_REMAIN_INACTIVE';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_employee_profile_lifecycle_internal()
  from public, anon, authenticated;
create trigger empleados_enforce_profile_lifecycle_before_write
before insert or update of perfil_id, estado_laboral, activo on public.empleados
for each row execute function public.enforce_employee_profile_lifecycle_internal();

-- Defensa global de autorizacion: ni un tombstone ni un empleado terminado
-- recuperan tenant/rol/permisos aunque exista un JWT aun no expirado.
create or replace function public.obtener_empresa_actual()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.company_id
  from public.profiles as p
  where p.id = (select auth.uid())
    and p.status = 'active'
    and p.access_deleted_at is null
    and public.perfil_acceso_utilizable_internal(p.id, p.company_id)
    and not exists (
      select 1 from public.empleados e
      where e.empresa_id = p.company_id and e.perfil_id = p.id
        and (not e.activo or e.estado_laboral = 'desvinculado')
    )
  limit 1
$$;

create or replace function public.obtener_rol_actual()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.role_id
  from public.profiles as p
  join public.roles as r
    on r.id = p.role_id
   and r.company_id = p.company_id
  where p.id = (select auth.uid())
    and p.status = 'active'
    and p.access_deleted_at is null
    and public.perfil_acceso_utilizable_internal(p.id, p.company_id)
    and not exists (
      select 1 from public.empleados e
      where e.empresa_id = p.company_id and e.perfil_id = p.id
        and (not e.activo or e.estado_laboral = 'desvinculado')
    )
    and r.is_active
  limit 1
$$;

create or replace function public.tiene_permiso(codigo_permiso text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select pp.permitido
      from public.profiles as p
      join public.permisos as pe
        on pe.codigo = codigo_permiso and pe.activo
      join public.perfil_permisos as pp
        on pp.perfil_id = p.id and pp.permiso_id = pe.id
      where p.id = (select auth.uid())
        and p.status = 'active'
        and p.access_deleted_at is null
        and public.perfil_acceso_utilizable_internal(p.id, p.company_id)
        and not exists (
          select 1 from public.empleados e
          where e.empresa_id = p.company_id and e.perfil_id = p.id
            and (not e.activo or e.estado_laboral = 'desvinculado')
        )
      limit 1
    ),
    (
      select rp.permitido
      from public.profiles as p
      join public.roles as r
        on r.id = p.role_id
       and r.company_id = p.company_id
       and r.is_active
      join public.permisos as pe
        on pe.codigo = codigo_permiso and pe.activo
      join public.rol_permisos as rp
        on rp.rol_id = r.id and rp.permiso_id = pe.id
      where p.id = (select auth.uid())
        and p.status = 'active'
        and p.access_deleted_at is null
        and public.perfil_acceso_utilizable_internal(p.id, p.company_id)
        and not exists (
          select 1 from public.empleados e
          where e.empresa_id = p.company_id and e.perfil_id = p.id
            and (not e.activo or e.estado_laboral = 'desvinculado')
        )
      limit 1
    ),
    false
  )
$$;

create or replace function private.current_company_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.company_id
  from public.profiles p
  where p.id = (select auth.uid())
    and p.status = 'active'
    and p.access_deleted_at is null
    and public.perfil_acceso_utilizable_internal(p.id, p.company_id)
    and not exists (
      select 1 from public.empleados e
      where e.empresa_id = p.company_id and e.perfil_id = p.id
        and (not e.activo or e.estado_laboral = 'desvinculado')
    )
  limit 1
$$;

create or replace function private.has_company_role(allowed_codes text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles p
    join public.roles r
      on r.id = p.role_id and r.company_id = p.company_id
    where p.id = (select auth.uid())
      and p.status = 'active'
      and p.access_deleted_at is null
      and public.perfil_acceso_utilizable_internal(p.id, p.company_id)
      and r.is_active
      and r.code = any (allowed_codes)
      and not exists (
        select 1 from public.empleados e
        where e.empresa_id = p.company_id and e.perfil_id = p.id
          and (not e.activo or e.estado_laboral = 'desvinculado')
      )
  )
$$;

create or replace function public.obtener_empleado_actual_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select e.id
  from public.empleados as e
  join public.profiles as p
    on p.id = e.perfil_id and p.company_id = e.empresa_id
  where p.id = (select auth.uid())
    and p.status = 'active'
    and p.access_deleted_at is null
    and public.perfil_acceso_utilizable_internal(p.id, p.company_id)
    and e.activo
    and e.estado_laboral = 'activo'
  limit 1
$$;

-- Un JWT emitido antes del bloqueo no conserva las ramas RLS de "mi perfil".
drop policy if exists perfil_permisos_select_propios on public.perfil_permisos;
create policy perfil_permisos_select_propios
on public.perfil_permisos
for select to authenticated
using (
  perfil_id = (select auth.uid())
  and (select public.perfil_actual_tiene_acceso())
);

drop policy if exists perfil_sucursales_select on public.perfil_sucursales;
create policy perfil_sucursales_select
on public.perfil_sucursales
for select to authenticated
using (
  (
    perfil_id = (select auth.uid())
    and (select public.perfil_actual_tiene_acceso())
  )
  or (
    exists (
      select 1 from public.profiles p
      where p.id = perfil_id
        and p.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  )
);

drop policy if exists perfil_departamentos_select on public.perfil_departamentos;
create policy perfil_departamentos_select
on public.perfil_departamentos
for select to authenticated
using (
  (
    perfil_id = (select auth.uid())
    and (select public.perfil_actual_tiene_acceso())
  )
  or (
    exists (
      select 1 from public.profiles p
      where p.id = perfil_id
        and p.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  )
);

drop policy if exists profiles_select_granular on public.profiles;
create policy profiles_select_granular
on public.profiles
for select to authenticated
using (
  (
    id = (select auth.uid())
    and (select public.perfil_actual_tiene_acceso())
  )
  or (
    company_id = (select public.obtener_empresa_actual())
    and (select public.tiene_permiso('usuarios.administrar'))
  )
);

create table public.empleado_ciclo_laboral_auditoria (
  id bigint generated always as identity primary key,
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  evento text not null,
  fecha_efectiva date not null,
  motivo text not null,
  observacion text,
  actor_id uuid,
  estado_anterior text,
  estado_nuevo text not null,
  activo_anterior boolean,
  activo_nuevo boolean not null,
  jornada_habilitada_anterior boolean,
  jornada_habilitada_nueva boolean not null,
  perfil_id uuid,
  perfil_estado_anterior text,
  perfil_estado_nuevo text,
  perfil_estado_cambiado boolean not null default false,
  evento_relacionado_id bigint references public.empleado_ciclo_laboral_auditoria(id)
    on delete restrict,
  auth_sync_status text not null default 'NOT_APPLICABLE',
  auth_sync_updated_at timestamptz,
  creado_en timestamptz not null default now(),
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  foreign key (empresa_id, actor_id)
    references public.profiles(company_id, id) on delete restrict,
  foreign key (empresa_id, perfil_id)
    references public.profiles(company_id, id) on delete restrict,
  constraint empleado_ciclo_evento_check check (
    evento in ('EMPLOYEE_TERMINATED', 'EMPLOYEE_REACTIVATED')
  ),
  constraint empleado_ciclo_motivo_check check (
    char_length(btrim(motivo)) between 3 and 500
  ),
  constraint empleado_ciclo_observacion_check check (
    observacion is null or char_length(btrim(observacion)) <= 2000
  ),
  constraint empleado_ciclo_auth_sync_check check (
    auth_sync_status in (
      'NOT_APPLICABLE',
      'PENDING_BAN', 'BAN_REQUESTED', 'BAN_APPLIED', 'BAN_FAILED',
      'PREEXISTING_BAN_PRESERVED', 'AUTH_USER_NOT_FOUND',
      'ACCESS_BLOCK_PRESERVED',
      'PENDING_UNBAN', 'UNBAN_REQUESTED', 'UNBAN_APPLIED', 'UNBAN_FAILED'
    )
  ),
  constraint empleado_ciclo_resultado_check check (
    (
      evento = 'EMPLOYEE_TERMINATED'
      and estado_nuevo = 'desvinculado'
      and not activo_nuevo
      and not jornada_habilitada_nueva
      and evento_relacionado_id is null
    )
    or (
      evento = 'EMPLOYEE_REACTIVATED'
      and estado_nuevo = 'activo'
      and activo_nuevo
      and evento_relacionado_id is not null
    )
  )
);

create index empleado_ciclo_laboral_scope_idx
  on public.empleado_ciclo_laboral_auditoria(
    empresa_id, empleado_id, creado_en desc, id desc
  );
create unique index empleado_ciclo_reactivacion_unica_idx
  on public.empleado_ciclo_laboral_auditoria(
    empresa_id, evento_relacionado_id
  ) where evento = 'EMPLOYEE_REACTIVATED';

create or replace function public.enforce_empleado_ciclo_audit_internal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.evento = 'EMPLOYEE_REACTIVATED' and not exists (
      select 1
      from public.empleado_ciclo_laboral_auditoria t
      where t.id = new.evento_relacionado_id
        and t.empresa_id = new.empresa_id
        and t.empleado_id = new.empleado_id
        and t.evento = 'EMPLOYEE_TERMINATED'
    ) then
      raise exception 'EMPLOYEE_LIFECYCLE_RELATED_EVENT_INVALID';
    end if;
    return new;
  end if;
  if tg_op = 'DELETE' then
    raise exception 'EMPLOYEE_LIFECYCLE_AUDIT_APPEND_ONLY';
  end if;
  if coalesce(current_setting('app.employee_lifecycle_auth_sync', true), '') <> 'on'
     or (
       to_jsonb(new) - array['auth_sync_status','auth_sync_updated_at']::text[]
       is distinct from
       to_jsonb(old) - array['auth_sync_status','auth_sync_updated_at']::text[]
     )
  then
    raise exception 'EMPLOYEE_LIFECYCLE_AUDIT_APPEND_ONLY';
  end if;
  return new;
end;
$$;
revoke all on function public.enforce_empleado_ciclo_audit_internal()
  from public, anon, authenticated;
create trigger empleado_ciclo_audit_immutable_before_write
before insert or update or delete on public.empleado_ciclo_laboral_auditoria
for each row execute function public.enforce_empleado_ciclo_audit_internal();

alter table public.empleado_ciclo_laboral_auditoria enable row level security;
revoke all on table public.empleado_ciclo_laboral_auditoria
  from public, anon, authenticated, service_role;
grant select on table public.empleado_ciclo_laboral_auditoria to authenticated;
grant select on table public.empleado_ciclo_laboral_auditoria to service_role;
revoke all on sequence public.empleado_ciclo_laboral_auditoria_id_seq
  from public, anon, authenticated, service_role;

create policy empleado_ciclo_laboral_select_scope
on public.empleado_ciclo_laboral_auditoria
for select to authenticated
using (
  empresa_id = (select public.obtener_empresa_actual())
  and (
    (select public.tiene_permiso('empleados.ver_todos'))
    or (
      (select public.tiene_permiso('empleados.ver_propio'))
      and (select public.es_empleado_actual(empleado_id))
    )
  )
);

comment on table public.empleado_ciclo_laboral_auditoria is
  'Historial append-only de desvinculaciones/reactivaciones; no elimina empleados ni relaciones historicas.';

-- Una baja historica que sea el unico acceso administrador activo requiere
-- resolucion explicita antes de migrar; no se bloquea silenciosamente el tenant.
do $$
declare
  v_blocking record;
begin
  select e.empresa_id, e.id as empleado_id, e.perfil_id
  into v_blocking
  from public.empleados e
  join public.profiles p
    on p.company_id = e.empresa_id and p.id = e.perfil_id
  where e.estado_laboral = 'desvinculado'
    and p.status = 'active'
    and p.access_deleted_at is null
    and public.es_rol_administrador_internal(p.role_id, e.empresa_id)
    and exists (
      select 1 from auth.users au
      where au.id = p.id
        and au.deleted_at is null
        and (au.banned_until is null or au.banned_until <= now())
    )
    and not exists (
      select 1
      from public.profiles other
      where other.company_id = e.empresa_id
        and other.id <> p.id
        and other.status = 'active'
        and other.access_deleted_at is null
        and public.es_rol_administrador_internal(other.role_id, e.empresa_id)
        and public.perfil_acceso_utilizable_internal(other.id, e.empresa_id)
    )
  order by e.empresa_id, e.id
  limit 1;

  if found then
    raise exception using
      errcode = '23514',
      message = pg_catalog.format(
        'TERMINATED_LAST_ADMIN_REQUIRES_REVIEW:company=%s employee=%s profile=%s',
        v_blocking.empresa_id, v_blocking.empleado_id, v_blocking.perfil_id
      );
  end if;
end;
$$;

-- Captura el estado anterior del acceso antes de bloquear perfiles historicos.
insert into public.empleado_ciclo_laboral_auditoria(
  empresa_id, empleado_id, evento, fecha_efectiva, motivo, observacion,
  actor_id, estado_anterior, estado_nuevo, activo_anterior, activo_nuevo,
  jornada_habilitada_anterior, jornada_habilitada_nueva,
  perfil_id, perfil_estado_anterior, perfil_estado_nuevo,
  perfil_estado_cambiado, auth_sync_status
)
select e.empresa_id,
       e.id,
       'EMPLOYEE_TERMINATED',
       e.fecha_desvinculacion,
       e.motivo_desvinculacion,
       e.observacion_desvinculacion,
       e.desvinculado_por,
       null,
       'desvinculado',
       null,
       false,
       e.jornada_habilitada,
       false,
       e.perfil_id,
       p.status,
       case when p.status = 'active' and p.access_deleted_at is null
         then 'inactive' else p.status end,
       p.status = 'active' and p.access_deleted_at is null,
       case
         when p.status = 'active' and p.access_deleted_at is null
           then 'PENDING_BAN'
         else 'NOT_APPLICABLE'
       end
from public.empleados e
left join public.profiles p
  on p.company_id = e.empresa_id and p.id = e.perfil_id
where e.estado_laboral = 'desvinculado';

update public.profiles p
set status = 'inactive', updated_at = now()
from public.empleados e
where e.empresa_id = p.company_id
  and e.perfil_id = p.id
  and e.estado_laboral = 'desvinculado'
  and p.status = 'active'
  and p.access_deleted_at is null;

update public.empleados
set jornada_habilitada = false
where estado_laboral = 'desvinculado'
  and jornada_habilitada;

alter table public.empleados
  validate constraint empleados_desvinculacion_consistencia_check;

-- Las bajas normalizadas tambien dejan cualquier jornada abierta disponible
-- para revision administrativa, sin cerrarla ni tocar eventos/version/tiempos.
insert into public.jornada_auditoria(
  empresa_id, jornada_id, actor_id, accion, antes, despues, origen
)
select j.empresa_id, j.id, null, 'EMPLOYEE_TERMINATED_REVIEW',
       jsonb_build_object(
         'estado', j.estado,
         'revision_pendiente', j.revision_pendiente,
         'severidad', j.severidad,
         'version_sync', j.version_sync,
         'actualizada_en', j.actualizada_en
       ),
       jsonb_build_object(
         'estado', j.estado,
         'revision_pendiente', true,
         'severidad', 'ALTA',
         'version_sync', j.version_sync,
         'actualizada_en', j.actualizada_en,
         'lifecycle_event_id', lifecycle.id
       ),
       'EMPLOYEE_LIFECYCLE_MIGRATION'
from public.jornadas j
join public.empleados e
  on e.empresa_id = j.empresa_id and e.id = j.empleado_id
join lateral (
  select a.id
  from public.empleado_ciclo_laboral_auditoria a
  where a.empresa_id = j.empresa_id
    and a.empleado_id = j.empleado_id
    and a.evento = 'EMPLOYEE_TERMINATED'
  order by a.creado_en desc, a.id desc
  limit 1
) lifecycle on true
where e.estado_laboral = 'desvinculado'
  and j.estado in ('EN_CURSO', 'EN_PAUSA');

update public.jornadas j
set revision_pendiente = true,
    severidad = 'ALTA'
from public.empleados e
where e.empresa_id = j.empresa_id
  and e.id = j.empleado_id
  and e.estado_laboral = 'desvinculado'
  and j.estado in ('EN_CURSO', 'EN_PAUSA')
  and (not j.revision_pendiente or j.severidad <> 'ALTA');

insert into public.jornada_incidencias(
  empresa_id, jornada_id, empleado_id, tipo, severidad, mensaje
)
select j.empresa_id, j.id, j.empleado_id, 'JORNADA_DESHABILITADA', 'ALTA',
       'Empleado desvinculado con jornada abierta. Requiere revision administrativa.'
from public.jornadas j
join public.empleados e
  on e.empresa_id = j.empresa_id and e.id = j.empleado_id
where e.estado_laboral = 'desvinculado'
  and j.estado in ('EN_CURSO', 'EN_PAUSA')
  and not exists (
    select 1 from public.jornada_incidencias i
    where i.empresa_id = j.empresa_id
      and i.jornada_id = j.id
      and i.tipo = 'JORNADA_DESHABILITADA'
      and not i.resuelta
  );

create or replace function public.desvincular_empleado(
  p_empleado uuid,
  p_fecha date,
  p_motivo text,
  p_observacion text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.obtener_empresa_actual();
  v_actor uuid := auth.uid();
  v_empleado public.empleados%rowtype;
  v_evento public.empleado_ciclo_laboral_auditoria%rowtype;
  v_perfil public.profiles%rowtype;
  v_perfil_estado_anterior text;
  v_perfil_estado_nuevo text;
  v_perfil_cambiado boolean := false;
  v_actor_rol text;
  v_estado_anterior text;
  v_activo_anterior boolean;
  v_jornada_anterior boolean;
  v_hoy date;
  v_motivo text := btrim(coalesce(p_motivo, ''));
  v_observacion text := nullif(btrim(coalesce(p_observacion, '')), '');
  v_auth_status text;
begin
  if v_actor is null or v_empresa is null
     or not public.tiene_permiso('empleados.desactivar')
  then
    raise exception using errcode = '42501', message = 'EMPLOYEE_TERMINATE_PERMISSION_DENIED';
  end if;
  if p_empleado is null then raise exception 'EMPLEADO_NO_ENCONTRADO'; end if;
  if p_fecha is null then raise exception 'FECHA_DESVINCULACION_REQUERIDA'; end if;
  if char_length(v_motivo) not between 3 and 500 then
    raise exception 'MOTIVO_DESVINCULACION_INVALIDO';
  end if;
  if v_observacion is not null and char_length(v_observacion) > 2000 then
    raise exception 'OBSERVACION_DESVINCULACION_INVALIDA';
  end if;

  select (now() at time zone coalesce(nullif(c.timezone, ''), 'America/Santo_Domingo'))::date
  into v_hoy
  from public.companies c
  where c.id = v_empresa;
  if p_fecha > v_hoy then raise exception 'FECHA_DESVINCULACION_FUTURA'; end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_empresa::text, 0)
  );
  select * into v_empleado
  from public.empleados e
  where e.empresa_id = v_empresa and e.id = p_empleado
  for update;
  if not found then raise exception 'EMPLEADO_NO_ENCONTRADO'; end if;
  if v_empleado.fecha_ingreso is not null and p_fecha < v_empleado.fecha_ingreso then
    raise exception 'FECHA_DESVINCULACION_ANTERIOR_INGRESO';
  end if;
  if v_empleado.estado_laboral = 'desvinculado' and not v_empleado.activo then
    select * into v_evento
    from public.empleado_ciclo_laboral_auditoria a
    where a.empresa_id = v_empresa
      and a.empleado_id = p_empleado
      and a.evento = 'EMPLOYEE_TERMINATED'
    order by a.creado_en desc, a.id desc
    limit 1;
    if not found then raise exception 'EMPLOYEE_TERMINATION_AUDIT_MISSING'; end if;
    return jsonb_build_object(
      'id', v_empleado.id,
      'codigo_empleado', v_empleado.codigo_empleado,
      'perfil_id', v_empleado.perfil_id,
      'activo', v_empleado.activo,
      'estado_laboral', v_empleado.estado_laboral,
      'jornada_habilitada', v_empleado.jornada_habilitada,
      'fecha_desvinculacion', v_empleado.fecha_desvinculacion,
      'motivo_desvinculacion', v_empleado.motivo_desvinculacion,
      'observacion_desvinculacion', v_empleado.observacion_desvinculacion,
      'desvinculado_por', v_empleado.desvinculado_por,
      'actualizado_por', v_empleado.actualizado_por,
      'updated_at', v_empleado.updated_at,
      'actualizado_en', v_empleado.updated_at,
      'lifecycle_event_id', v_evento.id,
      'auth_sync_status', v_evento.auth_sync_status,
      'already_terminated', true
    );
  end if;

  if v_empleado.perfil_id = v_actor then
    raise exception 'AUTO_DESVINCULACION_NO_PERMITIDA';
  end if;
  v_estado_anterior := v_empleado.estado_laboral;
  v_activo_anterior := v_empleado.activo;
  v_jornada_anterior := v_empleado.jornada_habilitada;

  if v_empleado.perfil_id is not null then
    select * into v_perfil
    from public.profiles p
    where p.company_id = v_empresa
      and p.id = v_empleado.perfil_id
      and p.access_deleted_at is null
    for update;
    if found then
      v_perfil_estado_anterior := v_perfil.status;
      if v_perfil.status = 'active'
         and public.es_rol_administrador_internal(v_perfil.role_id, v_empresa)
         and public.perfil_acceso_utilizable_internal(v_perfil.id, v_empresa)
         and not exists (
           select 1 from public.profiles other
           where other.company_id = v_empresa
             and other.id <> v_perfil.id
             and other.status = 'active'
             and other.access_deleted_at is null
             and public.es_rol_administrador_internal(other.role_id, v_empresa)
             and public.perfil_acceso_utilizable_internal(other.id, v_empresa)
         )
      then
        raise exception 'ULTIMO_ADMINISTRADOR_NO_DESACTIVABLE';
      end if;
      if v_perfil.status = 'active' then
        update public.profiles
        set status = 'inactive', updated_at = now()
        where company_id = v_empresa and id = v_perfil.id;
        v_perfil_estado_nuevo := 'inactive';
        v_perfil_cambiado := true;
      else
        v_perfil_estado_nuevo := v_perfil.status;
      end if;
    end if;
  end if;
  v_auth_status := case when v_perfil_cambiado
    then 'PENDING_BAN' else 'NOT_APPLICABLE' end;

  update public.empleados
  set activo = false,
      estado_laboral = 'desvinculado',
      jornada_habilitada = false,
      fecha_desvinculacion = p_fecha,
      motivo_desvinculacion = v_motivo,
      observacion_desvinculacion = v_observacion,
      desvinculado_por = v_actor,
      actualizado_por = v_actor,
      updated_at = now()
  where empresa_id = v_empresa and id = p_empleado
  returning * into v_empleado;

  insert into public.empleado_ciclo_laboral_auditoria(
    empresa_id, empleado_id, evento, fecha_efectiva, motivo, observacion,
    actor_id, estado_anterior, estado_nuevo, activo_anterior, activo_nuevo,
    jornada_habilitada_anterior, jornada_habilitada_nueva,
    perfil_id, perfil_estado_anterior, perfil_estado_nuevo,
    perfil_estado_cambiado, auth_sync_status
  ) values (
    v_empresa, p_empleado, 'EMPLOYEE_TERMINATED', p_fecha, v_motivo,
    v_observacion, v_actor, v_estado_anterior, 'desvinculado',
    v_activo_anterior, false, v_jornada_anterior, false, v_empleado.perfil_id,
    v_perfil_estado_anterior, v_perfil_estado_nuevo,
    v_perfil_cambiado, v_auth_status
  ) returning * into v_evento;

  select coalesce(r.code, 'service_role') into v_actor_rol
  from public.profiles p
  left join public.roles r
    on r.company_id = p.company_id and r.id = p.role_id
  where p.company_id = v_empresa and p.id = v_actor;
  insert into public.supervisor_auditoria(
    empresa_id, actor_id, actor_rol, empleado_id, entidad, entidad_id,
    accion, antes, despues, motivo
  ) values (
    v_empresa, v_actor, coalesce(v_actor_rol, 'service_role'), p_empleado,
    'empleados', p_empleado, 'EMPLOYEE_TERMINATED',
    jsonb_build_object('activo', v_activo_anterior,
      'estado_laboral', v_estado_anterior,
      'jornada_habilitada', v_jornada_anterior),
    jsonb_build_object('activo', false, 'estado_laboral', 'desvinculado',
      'jornada_habilitada', false, 'fecha_desvinculacion', p_fecha),
    v_motivo
  );
  insert into public.notificaciones_internas(
    empresa_id, empleado_id, tipo, severidad, mensaje, destinatario_perfil_id
  ) values (
    v_empresa, p_empleado, 'EMPLOYEE_TERMINATED', 'ALTA',
    'Empleado desvinculado. Motivo: ' || v_motivo, v_empleado.perfil_id
  );
  insert into public.jornada_auditoria(
    empresa_id, jornada_id, actor_id, accion, antes, despues, origen
  )
  select j.empresa_id, j.id, v_actor, 'EMPLOYEE_TERMINATED_REVIEW',
         jsonb_build_object(
           'estado', j.estado,
           'revision_pendiente', j.revision_pendiente,
           'severidad', j.severidad,
           'version_sync', j.version_sync,
           'actualizada_en', j.actualizada_en
         ),
         jsonb_build_object(
           'estado', j.estado,
           'revision_pendiente', true,
           'severidad', 'ALTA',
           'version_sync', j.version_sync,
           'actualizada_en', j.actualizada_en,
           'lifecycle_event_id', v_evento.id
         ),
         'EMPLOYEE_LIFECYCLE'
  from public.jornadas j
  where j.empresa_id = v_empresa
    and j.empleado_id = p_empleado
    and j.estado in ('EN_CURSO', 'EN_PAUSA')
    and not exists (
      select 1 from public.jornada_auditoria a
      where a.empresa_id = j.empresa_id
        and a.jornada_id = j.id
        and a.accion = 'EMPLOYEE_TERMINATED_REVIEW'
        and a.despues ->> 'lifecycle_event_id' = v_evento.id::text
    );
  update public.jornadas j
  set revision_pendiente = true,
      severidad = 'ALTA'
  where j.empresa_id = v_empresa
    and j.empleado_id = p_empleado
    and j.estado in ('EN_CURSO', 'EN_PAUSA')
    and (not j.revision_pendiente or j.severidad <> 'ALTA');
  insert into public.jornada_incidencias(
    empresa_id, jornada_id, empleado_id, tipo, severidad, mensaje
  )
  select j.empresa_id, j.id, j.empleado_id, 'JORNADA_DESHABILITADA', 'ALTA',
         'Empleado desvinculado con jornada abierta. Requiere revision administrativa.'
  from public.jornadas j
  where j.empresa_id = v_empresa
    and j.empleado_id = p_empleado
    and j.estado in ('EN_CURSO', 'EN_PAUSA')
    and not exists (
      select 1 from public.jornada_incidencias i
      where i.empresa_id = j.empresa_id
        and i.jornada_id = j.id
        and i.tipo = 'JORNADA_DESHABILITADA'
        and not i.resuelta
    );

  return jsonb_build_object(
    'id', v_empleado.id,
    'codigo_empleado', v_empleado.codigo_empleado,
    'perfil_id', v_empleado.perfil_id,
    'activo', v_empleado.activo,
    'estado_laboral', v_empleado.estado_laboral,
    'jornada_habilitada', v_empleado.jornada_habilitada,
    'fecha_desvinculacion', v_empleado.fecha_desvinculacion,
    'motivo_desvinculacion', v_empleado.motivo_desvinculacion,
    'observacion_desvinculacion', v_empleado.observacion_desvinculacion,
    'desvinculado_por', v_empleado.desvinculado_por,
    'actualizado_por', v_empleado.actualizado_por,
    'updated_at', v_empleado.updated_at,
    'actualizado_en', v_empleado.updated_at,
    'lifecycle_event_id', v_evento.id,
    'auth_sync_status', v_evento.auth_sync_status,
    'already_terminated', false
  );
end;
$$;

create or replace function public.reactivar_empleado(
  p_empleado uuid,
  p_motivo text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.obtener_empresa_actual();
  v_actor uuid := auth.uid();
  v_empleado public.empleados%rowtype;
  v_terminacion public.empleado_ciclo_laboral_auditoria%rowtype;
  v_evento public.empleado_ciclo_laboral_auditoria%rowtype;
  v_perfil public.profiles%rowtype;
  v_perfil_estado_anterior text;
  v_perfil_estado_nuevo text;
  v_perfil_cambiado boolean := false;
  v_acceso_restaurable boolean := false;
  v_restauracion_acceso_pendiente boolean := false;
  v_actor_rol text;
  v_hoy date;
  v_motivo text := coalesce(
    nullif(btrim(coalesce(p_motivo, '')), ''),
    'Reactivacion de empleado'
  );
  v_auth_status text;
begin
  if v_actor is null or v_empresa is null
     or not public.tiene_permiso('empleados.desactivar')
  then
    raise exception using errcode = '42501', message = 'EMPLOYEE_REACTIVATE_PERMISSION_DENIED';
  end if;
  if p_empleado is null then raise exception 'EMPLEADO_NO_ENCONTRADO'; end if;
  if char_length(v_motivo) not between 3 and 500 then
    raise exception 'MOTIVO_REACTIVACION_INVALIDO';
  end if;

  select (now() at time zone coalesce(nullif(c.timezone, ''), 'America/Santo_Domingo'))::date
  into v_hoy
  from public.companies c
  where c.id = v_empresa;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_empresa::text, 0)
  );
  select * into v_empleado
  from public.empleados e
  where e.empresa_id = v_empresa and e.id = p_empleado
  for update;
  if not found then raise exception 'EMPLEADO_NO_ENCONTRADO'; end if;

  if v_empleado.estado_laboral <> 'desvinculado' or v_empleado.activo then
    select * into v_evento
    from public.empleado_ciclo_laboral_auditoria a
    where a.empresa_id = v_empresa
      and a.empleado_id = p_empleado
      and a.evento = 'EMPLOYEE_REACTIVATED'
    order by a.creado_en desc, a.id desc
    limit 1;
    if not found then raise exception 'EMPLOYEE_NOT_TERMINATED'; end if;
    return jsonb_build_object(
      'id', v_empleado.id,
      'codigo_empleado', v_empleado.codigo_empleado,
      'perfil_id', v_empleado.perfil_id,
      'activo', v_empleado.activo,
      'estado_laboral', v_empleado.estado_laboral,
      'jornada_habilitada', v_empleado.jornada_habilitada,
      'fecha_desvinculacion', v_empleado.fecha_desvinculacion,
      'motivo_desvinculacion', v_empleado.motivo_desvinculacion,
      'observacion_desvinculacion', v_empleado.observacion_desvinculacion,
      'desvinculado_por', v_empleado.desvinculado_por,
      'actualizado_por', v_empleado.actualizado_por,
      'updated_at', v_empleado.updated_at,
      'actualizado_en', v_empleado.updated_at,
      'lifecycle_event_id', v_evento.id,
      'auth_ban_event_id', v_evento.evento_relacionado_id,
      'auth_sync_status', v_evento.auth_sync_status,
      'already_reactivated', true
    );
  end if;

  select * into v_terminacion
  from public.empleado_ciclo_laboral_auditoria a
  where a.empresa_id = v_empresa
    and a.empleado_id = p_empleado
    and a.evento = 'EMPLOYEE_TERMINATED'
  order by a.creado_en desc, a.id desc
  limit 1
  for update;
  if not found then raise exception 'EMPLOYEE_TERMINATION_AUDIT_MISSING'; end if;
  v_acceso_restaurable := v_empleado.perfil_id is not null
    and v_empleado.perfil_id = v_terminacion.perfil_id
    and exists (
      select 1 from auth.users au where au.id = v_empleado.perfil_id
    )
    and exists (
      select 1
      from public.profiles p
      where p.company_id = v_empresa
        and p.id = v_empleado.perfil_id
        and p.access_deleted_at is null
    );
  if v_acceso_restaurable and v_terminacion.auth_sync_status in (
    'PENDING_BAN', 'BAN_REQUESTED', 'BAN_FAILED'
  ) then
    raise exception 'EMPLOYEE_AUTH_SYNC_PENDING';
  end if;

  if v_empleado.perfil_id is not null then
    select * into v_perfil
    from public.profiles p
    where p.company_id = v_empresa
      and p.id = v_empleado.perfil_id
      and p.access_deleted_at is null
    for update;
    if found then
      v_perfil_estado_anterior := v_perfil.status;
      if v_acceso_restaurable
         and v_terminacion.perfil_estado_cambiado
         and v_terminacion.perfil_estado_anterior = 'active'
         and v_perfil.status = 'inactive'
         and v_terminacion.auth_sync_status = 'BAN_APPLIED'
      then
        -- El perfil permanece inactivo hasta que employee-management retire
        -- el ban propiedad de este evento y confirme por RPC interna.
        v_perfil_estado_nuevo := 'inactive';
        v_restauracion_acceso_pendiente := true;
      else
        v_perfil_estado_nuevo := v_perfil.status;
      end if;
    end if;
  end if;

  update public.empleados
  set activo = true,
      estado_laboral = 'activo',
      jornada_habilitada = coalesce(
        v_terminacion.jornada_habilitada_anterior, true
      ),
      fecha_desvinculacion = null,
      motivo_desvinculacion = null,
      observacion_desvinculacion = null,
      desvinculado_por = null,
      actualizado_por = v_actor,
      updated_at = now()
  where empresa_id = v_empresa and id = p_empleado
  returning * into v_empleado;

  v_auth_status := case
    when v_restauracion_acceso_pendiente then 'PENDING_UNBAN'
    else 'NOT_APPLICABLE'
  end;
  insert into public.empleado_ciclo_laboral_auditoria(
    empresa_id, empleado_id, evento, fecha_efectiva, motivo, observacion,
    actor_id, estado_anterior, estado_nuevo, activo_anterior, activo_nuevo,
    jornada_habilitada_anterior, jornada_habilitada_nueva,
    perfil_id, perfil_estado_anterior, perfil_estado_nuevo,
    perfil_estado_cambiado, evento_relacionado_id, auth_sync_status
  ) values (
    v_empresa, p_empleado, 'EMPLOYEE_REACTIVATED', v_hoy, v_motivo,
    null, v_actor, 'desvinculado', 'activo', false, true,
    false, v_empleado.jornada_habilitada, v_empleado.perfil_id,
    v_perfil_estado_anterior, v_perfil_estado_nuevo,
    v_perfil_cambiado, v_terminacion.id, v_auth_status
  ) returning * into v_evento;

  select coalesce(r.code, 'service_role') into v_actor_rol
  from public.profiles p
  left join public.roles r
    on r.company_id = p.company_id and r.id = p.role_id
  where p.company_id = v_empresa and p.id = v_actor;
  insert into public.supervisor_auditoria(
    empresa_id, actor_id, actor_rol, empleado_id, entidad, entidad_id,
    accion, antes, despues, motivo
  ) values (
    v_empresa, v_actor, coalesce(v_actor_rol, 'service_role'), p_empleado,
    'empleados', p_empleado, 'EMPLOYEE_REACTIVATED',
    jsonb_build_object('activo', false, 'estado_laboral', 'desvinculado',
      'jornada_habilitada', false),
    jsonb_build_object('activo', true, 'estado_laboral', 'activo',
      'jornada_habilitada', v_empleado.jornada_habilitada),
    v_motivo
  );
  insert into public.notificaciones_internas(
    empresa_id, empleado_id, tipo, severidad, mensaje, destinatario_perfil_id
  ) values (
    v_empresa, p_empleado, 'EMPLOYEE_REACTIVATED', 'INFORMATIVA',
    'Empleado reactivado. Motivo: ' || v_motivo, v_empleado.perfil_id
  );

  return jsonb_build_object(
    'id', v_empleado.id,
    'codigo_empleado', v_empleado.codigo_empleado,
    'perfil_id', v_empleado.perfil_id,
    'activo', v_empleado.activo,
    'estado_laboral', v_empleado.estado_laboral,
    'jornada_habilitada', v_empleado.jornada_habilitada,
    'fecha_desvinculacion', v_empleado.fecha_desvinculacion,
    'motivo_desvinculacion', v_empleado.motivo_desvinculacion,
    'observacion_desvinculacion', v_empleado.observacion_desvinculacion,
    'desvinculado_por', v_empleado.desvinculado_por,
    'actualizado_por', v_empleado.actualizado_por,
    'updated_at', v_empleado.updated_at,
    'actualizado_en', v_empleado.updated_at,
    'lifecycle_event_id', v_evento.id,
    'auth_ban_event_id', v_terminacion.id,
    'auth_sync_status', v_evento.auth_sync_status,
    'already_reactivated', false
  );
end;
$$;

revoke all on function public.desvincular_empleado(uuid,date,text,text)
  from public, anon;
revoke all on function public.reactivar_empleado(uuid,text)
  from public, anon;
grant execute on function public.desvincular_empleado(uuid,date,text,text)
  to authenticated;
grant execute on function public.reactivar_empleado(uuid,text)
  to authenticated;

comment on function public.desvincular_empleado(uuid,date,text,text) is
  'Desvincula sin DELETE, bloquea el acceso vinculado y conserva toda relacion historica.';
comment on function public.reactivar_empleado(uuid,text) is
  'Reactiva el empleado y restaura solo acceso/jornada modificados por su ultima desvinculacion.';

-- Compatibilidad con Administracion RC3.5: conserva las firmas usadas por Web,
-- pero unifica orden de locks y aplica el guard central de ultimo administrador.
create or replace function public.actualizar_estado_usuario_administracion(
  p_perfil uuid,
  p_estado text,
  p_motivo text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.obtener_empresa_actual();
  v_antes public.profiles%rowtype;
  v_despues public.profiles%rowtype;
begin
  if v_empresa is null or not public.tiene_permiso('usuarios.administrar') then
    raise exception using errcode = '42501', message = 'ADMIN_PERMISSION_DENIED';
  end if;
  if p_perfil = auth.uid() then raise exception 'AUTO_DESACTIVACION_NO_PERMITIDA'; end if;
  if p_estado not in ('active','inactive','suspended')
     or btrim(coalesce(p_motivo,'')) = ''
  then
    raise exception 'ESTADO_USUARIO_INVALIDO';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_empresa::text, 0)
  );
  select * into v_antes
  from public.profiles p
  where p.company_id = v_empresa
    and p.id = p_perfil
    and p.access_deleted_at is null
  for update;
  if not found then raise exception 'USUARIO_NO_ENCONTRADO'; end if;

  update public.profiles
  set status = p_estado, updated_at = now()
  where company_id = v_empresa and id = p_perfil
  returning * into v_despues;
  insert into public.administracion_auditoria(
    empresa_id, actor_id, seccion, accion, entidad, entidad_id,
    antes, despues, motivo
  ) values (
    v_empresa, auth.uid(), 'usuarios', 'CAMBIAR_ESTADO', 'profiles',
    p_perfil::text, to_jsonb(v_antes), to_jsonb(v_despues), btrim(p_motivo)
  );
end;
$$;

create or replace function public.actualizar_rol_usuario_administracion(
  p_perfil uuid,
  p_rol uuid,
  p_motivo text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.obtener_empresa_actual();
  v_antes public.profiles%rowtype;
  v_despues public.profiles%rowtype;
begin
  if v_empresa is null or not public.tiene_permiso('usuarios.administrar') then
    raise exception using errcode = '42501', message = 'ADMIN_PERMISSION_DENIED';
  end if;
  if p_perfil = auth.uid() then raise exception 'AUTO_CAMBIO_ROL_NO_PERMITIDO'; end if;
  if btrim(coalesce(p_motivo,'')) = ''
     or not exists (
       select 1 from public.roles r
       where r.company_id = v_empresa and r.id = p_rol and r.is_active
     )
  then
    raise exception 'ROL_USUARIO_INVALIDO';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_empresa::text, 0)
  );
  select * into v_antes
  from public.profiles p
  where p.company_id = v_empresa
    and p.id = p_perfil
    and p.access_deleted_at is null
  for update;
  if not found then raise exception 'USUARIO_NO_ENCONTRADO'; end if;

  update public.profiles
  set role_id = p_rol, updated_at = now()
  where company_id = v_empresa and id = p_perfil
  returning * into v_despues;
  insert into public.administracion_auditoria(
    empresa_id, actor_id, seccion, accion, entidad, entidad_id,
    antes, despues, motivo
  ) values (
    v_empresa, auth.uid(), 'usuarios', 'CAMBIAR_ROL', 'profiles',
    p_perfil::text, to_jsonb(v_antes), to_jsonb(v_despues), btrim(p_motivo)
  );
end;
$$;
revoke all on function public.actualizar_estado_usuario_administracion(uuid,text,text)
  from public, anon;
revoke all on function public.actualizar_rol_usuario_administracion(uuid,uuid,text)
  from public, anon;
grant execute on function public.actualizar_estado_usuario_administracion(uuid,text,text)
  to authenticated;
grant execute on function public.actualizar_rol_usuario_administracion(uuid,uuid,text)
  to authenticated;

-- CAS privado para coordinar la transaccion SQL con GoTrue sin permitir que
-- reintentos concurrentes hagan retroceder un estado terminal.
create or replace function public.actualizar_auth_sync_ciclo_empleado_internal(
  p_empresa uuid,
  p_evento_id bigint,
  p_evento text,
  p_expected text[],
  p_nuevo text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actual text;
  v_transicion_valida boolean;
  v_previous_guard text := current_setting(
    'app.employee_lifecycle_auth_sync', true
  );
begin
  if p_empresa is null or p_evento_id is null
     or p_evento not in ('EMPLOYEE_TERMINATED','EMPLOYEE_REACTIVATED')
     or p_expected is null or cardinality(p_expected) = 0
  then
    raise exception 'EMPLOYEE_AUTH_SYNC_ARGUMENT_INVALID';
  end if;
  select a.auth_sync_status into v_actual
  from public.empleado_ciclo_laboral_auditoria a
  where a.empresa_id = p_empresa
    and a.id = p_evento_id
    and a.evento = p_evento
  for update;
  if not found then raise exception 'EMPLOYEE_LIFECYCLE_EVENT_NOT_FOUND'; end if;
  if v_actual = p_nuevo then return v_actual; end if;
  if not (v_actual = any(p_expected)) then return v_actual; end if;

  v_transicion_valida := case p_evento
    when 'EMPLOYEE_TERMINATED' then
      (v_actual = 'PENDING_BAN' and p_nuevo in (
        'BAN_REQUESTED','BAN_APPLIED','BAN_FAILED',
        'PREEXISTING_BAN_PRESERVED','AUTH_USER_NOT_FOUND'
      ))
      or (v_actual = 'BAN_REQUESTED' and p_nuevo in (
        'BAN_APPLIED','BAN_FAILED','PREEXISTING_BAN_PRESERVED',
        'AUTH_USER_NOT_FOUND'
      ))
      or (v_actual = 'BAN_FAILED' and p_nuevo in (
        'BAN_REQUESTED','BAN_APPLIED','PREEXISTING_BAN_PRESERVED',
        'AUTH_USER_NOT_FOUND'
      ))
    when 'EMPLOYEE_REACTIVATED' then
      (v_actual = 'PENDING_UNBAN' and p_nuevo in (
        'UNBAN_REQUESTED','UNBAN_APPLIED','UNBAN_FAILED',
        'PREEXISTING_BAN_PRESERVED','ACCESS_BLOCK_PRESERVED',
        'AUTH_USER_NOT_FOUND'
      ))
      or (v_actual = 'UNBAN_REQUESTED' and p_nuevo in (
        'UNBAN_APPLIED','UNBAN_FAILED','PREEXISTING_BAN_PRESERVED',
        'ACCESS_BLOCK_PRESERVED','AUTH_USER_NOT_FOUND'
      ))
      or (v_actual = 'UNBAN_FAILED' and p_nuevo in (
        'UNBAN_REQUESTED','UNBAN_APPLIED','PREEXISTING_BAN_PRESERVED',
        'ACCESS_BLOCK_PRESERVED','AUTH_USER_NOT_FOUND'
      ))
    else false
  end;
  if not v_transicion_valida then
    raise exception 'EMPLOYEE_AUTH_SYNC_TRANSITION_INVALID';
  end if;
  perform set_config('app.employee_lifecycle_auth_sync', 'on', true);
  update public.empleado_ciclo_laboral_auditoria
  set auth_sync_status = p_nuevo,
      auth_sync_updated_at = now()
  where empresa_id = p_empresa and id = p_evento_id;
  perform set_config(
    'app.employee_lifecycle_auth_sync', coalesce(v_previous_guard, ''), true
  );
  return p_nuevo;
end;
$$;
revoke all on function public.actualizar_auth_sync_ciclo_empleado_internal(
  uuid,bigint,text,text[],text
) from public, anon, authenticated;
grant execute on function public.actualizar_auth_sync_ciclo_empleado_internal(
  uuid,bigint,text,text[],text
) to service_role;

-- Segundo paso de reactivacion: Auth se desbloquea primero mientras el perfil
-- sigue inactivo. Solo entonces esta RPC atomica restaura el acceso SQL.
create or replace function public.finalizar_reactivacion_acceso_internal(
  p_empresa uuid,
  p_evento_id bigint
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_evento public.empleado_ciclo_laboral_auditoria%rowtype;
  v_terminacion public.empleado_ciclo_laboral_auditoria%rowtype;
  v_empleado public.empleados%rowtype;
  v_perfil public.profiles%rowtype;
  v_previous_guard text := current_setting(
    'app.employee_lifecycle_auth_sync', true
  );
begin
  if p_empresa is null or p_evento_id is null then
    raise exception 'EMPLOYEE_ACCESS_FINALIZE_ARGUMENT_INVALID';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_empresa::text, 0)
  );
  select * into v_evento
  from public.empleado_ciclo_laboral_auditoria a
  where a.empresa_id = p_empresa
    and a.id = p_evento_id
    and a.evento = 'EMPLOYEE_REACTIVATED'
  for update;
  if not found then raise exception 'EMPLOYEE_LIFECYCLE_EVENT_NOT_FOUND'; end if;
  if v_evento.auth_sync_status = 'UNBAN_APPLIED' then
    return 'UNBAN_APPLIED';
  end if;
  if v_evento.auth_sync_status <> 'UNBAN_REQUESTED' then
    raise exception 'EMPLOYEE_ACCESS_FINALIZE_STATE_INVALID';
  end if;

  select * into v_terminacion
  from public.empleado_ciclo_laboral_auditoria a
  where a.empresa_id = p_empresa
    and a.id = v_evento.evento_relacionado_id
    and a.empleado_id = v_evento.empleado_id
    and a.evento = 'EMPLOYEE_TERMINATED'
  for update;
  if not found
     or v_terminacion.auth_sync_status <> 'BAN_APPLIED'
     or not v_terminacion.perfil_estado_cambiado
     or v_terminacion.perfil_estado_anterior <> 'active'
  then
    raise exception 'EMPLOYEE_ACCESS_FINALIZE_TERMINATION_INVALID';
  end if;
  if not exists (
    select 1
    from auth.users au
    where au.id = v_evento.perfil_id
      and au.deleted_at is null
      and (au.banned_until is null or au.banned_until <= now())
      and coalesce(
        au.raw_app_meta_data ->> 'employee_lifecycle_ban_event_id', ''
      ) <> v_terminacion.id::text
  ) then
    raise exception 'EMPLOYEE_ACCESS_FINALIZE_AUTH_NOT_CONFIRMED';
  end if;

  select * into v_empleado
  from public.empleados e
  where e.empresa_id = p_empresa
    and e.id = v_evento.empleado_id
  for update;
  if not found
     or not v_empleado.activo
     or v_empleado.estado_laboral <> 'activo'
     or v_empleado.perfil_id is distinct from v_evento.perfil_id
  then
    raise exception 'EMPLOYEE_ACCESS_FINALIZE_EMPLOYEE_INVALID';
  end if;

  select * into v_perfil
  from public.profiles p
  where p.company_id = p_empresa
    and p.id = v_evento.perfil_id
  for update;
  if not found
     or v_perfil.access_deleted_at is not null
     or v_perfil.status <> 'inactive'
  then
    raise exception 'EMPLOYEE_ACCESS_FINALIZE_PROFILE_INVALID';
  end if;

  update public.profiles
  set status = 'active', updated_at = now()
  where company_id = p_empresa and id = v_perfil.id;

  perform set_config('app.employee_lifecycle_auth_sync', 'on', true);
  update public.empleado_ciclo_laboral_auditoria
  set auth_sync_status = 'UNBAN_APPLIED',
      auth_sync_updated_at = now()
  where empresa_id = p_empresa and id = p_evento_id;
  perform set_config(
    'app.employee_lifecycle_auth_sync', coalesce(v_previous_guard, ''), true
  );

  insert into public.administracion_auditoria(
    empresa_id, actor_id, seccion, accion, entidad, entidad_id,
    antes, despues, motivo
  ) values (
    p_empresa, v_evento.actor_id, 'accesos',
    'RESTAURAR_ACCESO_REACTIVACION', 'profiles', v_perfil.id::text,
    jsonb_build_object('status', 'inactive'),
    jsonb_build_object(
      'status', 'active', 'lifecycle_event_id', p_evento_id
    ),
    v_evento.motivo
  );
  return 'UNBAN_APPLIED';
end;
$$;
revoke all on function public.finalizar_reactivacion_acceso_internal(uuid,bigint)
  from public, anon, authenticated;
grant execute on function public.finalizar_reactivacion_acceso_internal(uuid,bigint)
  to service_role;

create or replace function public.establecer_jornada_habilitada(
  p_empleado uuid,
  p_habilitada boolean,
  p_motivo text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_empresa uuid := public.obtener_empresa_actual();
  v_empleado public.empleados%rowtype;
  v_despues jsonb;
  v_rol text;
  v_jornada uuid;
begin
  if btrim(coalesce(p_motivo,'')) = '' then raise exception 'MOTIVO_REQUERIDO'; end if;
  if not public.puede_operar_empleado_rc3(p_empleado, 'jornadas.admin_off_on') then
    raise exception 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_empresa::text, 0)
  );
  select * into v_empleado
  from public.empleados e
  where e.id = p_empleado and e.empresa_id = v_empresa
  for update;
  if not found then raise exception 'EMPLEADO_NO_ENCONTRADO'; end if;
  if p_habilitada
     and (not v_empleado.activo or v_empleado.estado_laboral <> 'activo')
  then
    raise exception 'EMPLOYEE_LIFECYCLE_ATTENDANCE_DISABLED';
  end if;

  update public.empleados
  set jornada_habilitada = p_habilitada, updated_at = now()
  where id = p_empleado and empresa_id = v_empresa
  returning to_jsonb(empleados.*) into v_despues;
  select r.code into v_rol
  from public.profiles p
  join public.roles r on r.id = p.role_id and r.company_id = p.company_id
  where p.id = auth.uid();
  select id into v_jornada
  from public.jornadas
  where empresa_id = v_empresa and empleado_id = p_empleado
  order by fecha_laboral desc
  limit 1;
  insert into public.supervisor_auditoria(
    empresa_id, actor_id, actor_rol, empleado_id, jornada_id,
    entidad, entidad_id, accion, antes, despues, motivo
  ) values (
    v_empresa, auth.uid(), v_rol, p_empleado, v_jornada,
    'empleados', p_empleado,
    case when p_habilitada then 'ADMIN_ON' else 'ADMIN_OFF' end,
    to_jsonb(v_empleado) - 'pin_hash' - 'salario' - 'face_embedding',
    v_despues - 'pin_hash' - 'salario' - 'face_embedding',
    btrim(p_motivo)
  );
  insert into public.notificaciones_internas(
    empresa_id, empleado_id, jornada_id, tipo, severidad, mensaje
  ) values (
    v_empresa, p_empleado, v_jornada,
    case when p_habilitada then 'ADMIN_ON' else 'ADMIN_OFF' end,
    case when p_habilitada then 'INFORMATIVA' else 'ALTA' end,
    case when p_habilitada
      then 'Registro de jornada habilitado. '
      else 'Tu registro de jornada esta deshabilitado. '
    end || btrim(p_motivo)
  );
  if not p_habilitada and v_jornada is not null then
    insert into public.jornada_incidencias(
      empresa_id, jornada_id, empleado_id, tipo, severidad, mensaje
    ) values (
      v_empresa, v_jornada, p_empleado, 'JORNADA_DESHABILITADA', 'ALTA',
      'Tu registro de jornada esta deshabilitado. Motivo: ' || btrim(p_motivo)
    );
  end if;
end;
$$;
revoke all on function public.establecer_jornada_habilitada(uuid,boolean,text)
  from public, anon;
grant execute on function public.establecer_jornada_habilitada(uuid,boolean,text)
  to authenticated;

-- Los cambios de ciclo deben pasar por las RPC; las demas columnas continúan
-- sujetas a la politica RLS de edicion existente.
revoke update (estado_laboral, activo) on public.empleados from authenticated;
revoke update, delete on public.profiles from authenticated;
grant select (
  fecha_desvinculacion, motivo_desvinculacion,
  observacion_desvinculacion, desvinculado_por, actualizado_por
) on public.empleados to authenticated;

-- Defensa en profundidad: incluso si una fila legacy queda activo=true, solo
-- estado_laboral='activo' puede registrar una jornada. Los codigos de error y
-- el resto de la funcion se conservan sin reescribirla manualmente.
do $$
declare
  v_definition text;
  v_old text := 'and activo and jornada_habilitada';
  v_new text := 'and activo and estado_laboral=''activo'' and jornada_habilitada';
  v_guard text := 'if not exists(select 1 from public.empleados where id=v_empleado';
  v_lock text := 'perform 1 from public.empleados where id=v_empleado and empresa_id=v_empresa for share;';
  v_changed boolean := false;
begin
  select pg_catalog.pg_get_functiondef(
    'public.registrar_evento_jornada_dispositivo(jsonb)'::regprocedure
  ) into v_definition;
  if pg_catalog.strpos(v_definition, v_new) = 0 then
    if pg_catalog.strpos(v_definition, v_old) = 0 then
      raise exception 'ATTENDANCE_EMPLOYEE_GUARD_ANCHOR_NOT_FOUND';
    end if;
    v_definition := pg_catalog.replace(v_definition, v_old, v_new);
    v_changed := true;
  end if;
  if pg_catalog.strpos(v_definition, v_lock) = 0 then
    if pg_catalog.strpos(v_definition, v_guard) = 0 then
      raise exception 'ATTENDANCE_EMPLOYEE_LOCK_ANCHOR_NOT_FOUND';
    end if;
    v_definition := pg_catalog.replace(
      v_definition, v_guard, v_lock || chr(10) || ' ' || v_guard
    );
    v_changed := true;
  end if;
  if v_changed then
    execute v_definition;
  end if;
end;
$$;

commit;
