begin;

set local search_path = public, extensions, pg_catalog;

create extension if not exists btree_gist with schema extensions;

-- 0042 only establishes the authoritative calendar/configuration model.
-- It deliberately does not accrue salary, close days, or write to the 0038 ledger.

insert into public.permisos(codigo, nombre, descripcion, modulo, activo) values
  (
    'dias_libres.ver_asignados', 'Ver días libres asignados',
    'Consulta días libres únicamente dentro del alcance autorizado.',
    'supervisor', true
  ),
  (
    'dias_libres.editar_asignados', 'Editar días libres asignados',
    'Gestiona días libres únicamente dentro del alcance autorizado.',
    'supervisor', true
  ),
  (
    'recursos_humanos.acceder', 'RECURSO HUMANO',
    'Permite acceder y gestionar el módulo de licencias y vacaciones dentro del alcance autorizado.',
    'recursos_humanos', true
  ),
  (
    'nomina.festivos', 'Gestionar días festivos',
    'Registra y consulta días festivos persistentes de la empresa.',
    'nomina', true
  )
on conflict(codigo) do update set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  modulo = excluded.modulo,
  activo = true;

-- Los códigos técnicos previos se preservan si ya existen, pero quedan
-- inactivos para que Crear/Editar Rol muestre un único permiso principal.
update public.permisos
set activo = false
where codigo in (
  'licencias.ver_asignadas', 'licencias.editar_asignadas',
  'vacaciones.ver_asignadas', 'vacaciones.editar_asignadas'
)
  and activo;

-- Ningún permiso nuevo se autoconcede a SUPERVISOR. Debe marcarse
-- explícitamente en Crear/Editar Rol y siempre queda sujeto al alcance.
-- ADMIN conserva el patrón empresarial vigente.
insert into public.rol_permisos(rol_id, permiso_id, permitido, alcance)
select r.id, p.id, true, 'empresa'
from public.roles r
join public.permisos p on p.codigo in (
  'dias_libres.ver_asignados', 'dias_libres.editar_asignados',
  'recursos_humanos.acceder',
  'nomina.festivos'
)
where r.is_active
  and private.normalizar_codigo_rol(r.code) = 'ADMIN'
on conflict(rol_id, permiso_id) do update set
  permitido = true,
  alcance = 'empresa';

create table public.nomina_plantillas_horario (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  nombre text not null,
  descripcion text,
  activo boolean not null default true,
  revision bigint not null default 1,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_by uuid not null,
  updated_at timestamptz not null default clock_timestamp(),
  constraint nomina_plantillas_horario_nombre_check
    check (char_length(btrim(nombre)) between 2 and 120),
  constraint nomina_plantillas_horario_descripcion_check
    check (descripcion is null or char_length(descripcion) <= 500),
  constraint nomina_plantillas_horario_revision_check check (revision > 0),
  constraint nomina_plantillas_horario_empresa_id_id_unique
    unique (empresa_id, id),
  constraint nomina_plantillas_horario_created_by_fk
    foreign key (empresa_id, created_by)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_plantillas_horario_updated_by_fk
    foreign key (empresa_id, updated_by)
    references public.profiles(company_id, id) on delete restrict
);

create unique index nomina_plantillas_horario_nombre_uidx
  on public.nomina_plantillas_horario(empresa_id, lower(btrim(nombre)));
create index nomina_plantillas_horario_activas_idx
  on public.nomina_plantillas_horario(empresa_id, activo, nombre);

create table public.nomina_plantilla_horario_versiones (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  plantilla_id uuid not null,
  revision integer not null,
  descripcion text,
  motivo text not null,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint nomina_plantilla_horario_versiones_revision_check
    check (revision > 0),
  constraint nomina_plantilla_horario_versiones_descripcion_check
    check (descripcion is null or char_length(descripcion) <= 500),
  constraint nomina_plantilla_horario_versiones_motivo_check
    check (char_length(btrim(motivo)) between 3 and 500),
  constraint nomina_plantilla_horario_versiones_empresa_id_id_unique
    unique (empresa_id, id),
  constraint nomina_plantilla_horario_versiones_revision_unique
    unique (empresa_id, plantilla_id, revision),
  constraint nomina_plantilla_horario_versiones_plantilla_fk
    foreign key (empresa_id, plantilla_id)
    references public.nomina_plantillas_horario(empresa_id, id) on delete restrict,
  constraint nomina_plantilla_horario_versiones_created_by_fk
    foreign key (empresa_id, created_by)
    references public.profiles(company_id, id) on delete restrict
);

create index nomina_plantilla_horario_versiones_lookup_idx
  on public.nomina_plantilla_horario_versiones(
    empresa_id, plantilla_id, revision desc
  );

create table public.nomina_plantilla_horario_dias (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  plantilla_version_id uuid not null,
  iso_dia smallint not null,
  minutos_normales integer not null,
  hora_entrada time,
  hora_salida time,
  inicio_almuerzo time,
  duracion_almuerzo_min integer not null default 0,
  tolerancia_min integer not null default 0,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint nomina_plantilla_horario_dias_iso_check
    check (iso_dia between 1 and 7),
  constraint nomina_plantilla_horario_dias_minutos_check
    check (minutos_normales between 0 and 1440),
  constraint nomina_plantilla_horario_dias_almuerzo_check
    check (duracion_almuerzo_min between 0 and 240),
  constraint nomina_plantilla_horario_dias_semantica_check check (
    (
      minutos_normales = 0
      and hora_entrada is null
      and hora_salida is null
      and inicio_almuerzo is null
      and duracion_almuerzo_min = 0
      and tolerancia_min = 0
    )
    or (
      minutos_normales > 0
      and (
        (
          hora_entrada is null
          and hora_salida is null
          and inicio_almuerzo is null
          and duracion_almuerzo_min = 0
          and tolerancia_min = 0
        )
        or (
          hora_entrada is not null
          and hora_salida is not null
          and hora_salida <> hora_entrada
          and (
            case
              when hora_salida > hora_entrada
                then hora_salida - hora_entrada
              else hora_salida - hora_entrada + interval '24 hours'
            end
          ) = make_interval(
            mins => minutos_normales + duracion_almuerzo_min
          )
          and (
            (
              duracion_almuerzo_min = 0
              and inicio_almuerzo is null
            )
            or (
              duracion_almuerzo_min > 0
              and (
                inicio_almuerzo is null
                or (
                  (
                    case
                      when inicio_almuerzo >= hora_entrada
                        then inicio_almuerzo - hora_entrada
                      else inicio_almuerzo - hora_entrada
                        + interval '24 hours'
                    end
                  ) + make_interval(mins => duracion_almuerzo_min)
                    <= (
                      case
                        when hora_salida > hora_entrada
                          then hora_salida - hora_entrada
                        else hora_salida - hora_entrada + interval '24 hours'
                      end
                    )
                )
              )
            )
          )
        )
      )
    )
  ),
  constraint nomina_plantilla_horario_dias_tolerancia_check
    check (tolerancia_min between 0 and 120),
  constraint nomina_plantilla_horario_dias_empresa_id_id_unique
    unique (empresa_id, id),
  constraint nomina_plantilla_horario_dias_version_dia_unique
    unique (empresa_id, plantilla_version_id, iso_dia),
  constraint nomina_plantilla_horario_dias_version_fk
    foreign key (empresa_id, plantilla_version_id)
    references public.nomina_plantilla_horario_versiones(empresa_id, id)
    on delete restrict,
  constraint nomina_plantilla_horario_dias_created_by_fk
    foreign key (empresa_id, created_by)
    references public.profiles(company_id, id) on delete restrict
);

create index nomina_plantilla_horario_dias_lookup_idx
  on public.nomina_plantilla_horario_dias(
    empresa_id, plantilla_version_id, iso_dia
  );

create table public.nomina_asignaciones_horario (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  plantilla_version_id uuid not null,
  vigente_desde date not null,
  vigente_hasta date,
  periodo daterange generated always as (
    daterange(
      vigente_desde,
      case
        when vigente_hasta is null then null
        when vigente_hasta < vigente_desde then vigente_desde
        else vigente_hasta + 1
      end,
      '[)'
    )
  ) stored,
  motivo text not null,
  revision bigint not null default 1,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_by uuid not null,
  updated_at timestamptz not null default clock_timestamp(),
  constraint nomina_asignaciones_horario_fechas_check
    check (vigente_hasta is null or vigente_desde <= vigente_hasta),
  constraint nomina_asignaciones_horario_motivo_check
    check (char_length(btrim(motivo)) between 3 and 500),
  constraint nomina_asignaciones_horario_revision_check check (revision > 0),
  constraint nomina_asignaciones_horario_empresa_id_id_unique
    unique (empresa_id, id),
  constraint nomina_asignaciones_horario_empleado_fk
    foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  constraint nomina_asignaciones_horario_version_fk
    foreign key (empresa_id, plantilla_version_id)
    references public.nomina_plantilla_horario_versiones(empresa_id, id)
    on delete restrict,
  constraint nomina_asignaciones_horario_created_by_fk
    foreign key (empresa_id, created_by)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_asignaciones_horario_updated_by_fk
    foreign key (empresa_id, updated_by)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_asignaciones_horario_no_overlap
    exclude using gist (
      empresa_id with =,
      empleado_id with =,
      periodo with &&
    ) deferrable initially immediate
);

create index nomina_asignaciones_horario_lookup_idx
  on public.nomina_asignaciones_horario(
    empresa_id, empleado_id, vigente_desde desc
  );

create table public.nomina_condiciones_salariales (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  sueldo_mensual numeric(14,2) not null,
  valor_hora_extra numeric(14,2) not null,
  vigente_desde date not null,
  vigente_hasta date,
  periodo daterange generated always as (
    daterange(
      vigente_desde,
      case
        when vigente_hasta is null then null
        when vigente_hasta < vigente_desde then vigente_desde
        else vigente_hasta + 1
      end,
      '[)'
    )
  ) stored,
  motivo text not null,
  revision bigint not null default 1,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_by uuid not null,
  updated_at timestamptz not null default clock_timestamp(),
  constraint nomina_condiciones_salariales_valores_check
    check (sueldo_mensual > 0 and valor_hora_extra >= 0),
  constraint nomina_condiciones_salariales_fechas_check
    check (vigente_hasta is null or vigente_desde <= vigente_hasta),
  constraint nomina_condiciones_salariales_motivo_check
    check (char_length(btrim(motivo)) between 3 and 500),
  constraint nomina_condiciones_salariales_revision_check check (revision > 0),
  constraint nomina_condiciones_salariales_empresa_id_id_unique
    unique (empresa_id, id),
  constraint nomina_condiciones_salariales_empleado_fk
    foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  constraint nomina_condiciones_salariales_created_by_fk
    foreign key (empresa_id, created_by)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_condiciones_salariales_updated_by_fk
    foreign key (empresa_id, updated_by)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_condiciones_salariales_no_overlap
    exclude using gist (
      empresa_id with =,
      empleado_id with =,
      periodo with &&
    ) deferrable initially immediate
);

create index nomina_condiciones_salariales_lookup_idx
  on public.nomina_condiciones_salariales(
    empresa_id, empleado_id, vigente_desde desc
  );

create table public.nomina_dias_libres (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  vigente_desde date not null,
  vigente_hasta date,
  periodo daterange generated always as (
    daterange(
      vigente_desde,
      case
        when vigente_hasta is null then 'infinity'::date
        when vigente_hasta < vigente_desde then vigente_desde
        else vigente_hasta + 1
      end,
      '[)'
    )
  ) stored,
  descripcion text not null,
  revision bigint not null default 1,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_by uuid not null,
  updated_at timestamptz not null default clock_timestamp(),
  constraint nomina_dias_libres_vigencia_check
    check (vigente_hasta is null or vigente_desde <= vigente_hasta),
  constraint nomina_dias_libres_descripcion_check
    check (char_length(btrim(descripcion)) between 3 and 500),
  constraint nomina_dias_libres_revision_check check (revision > 0),
  constraint nomina_dias_libres_empresa_id_id_unique unique (empresa_id, id),
  constraint nomina_dias_libres_empresa_id_id_empleado_unique
    unique (empresa_id, id, empleado_id),
  constraint nomina_dias_libres_empleado_fk
    foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  constraint nomina_dias_libres_created_by_fk
    foreign key (empresa_id, created_by)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_dias_libres_updated_by_fk
    foreign key (empresa_id, updated_by)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_dias_libres_no_overlap
    exclude using gist (
      empresa_id with =,
      empleado_id with =,
      periodo with &&
    ) deferrable initially immediate
);

create index nomina_dias_libres_lookup_idx
  on public.nomina_dias_libres(
    empresa_id, empleado_id, vigente_desde desc
  );

create table public.nomina_dia_libre_dias (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  configuracion_id uuid not null,
  empleado_id uuid not null,
  iso_dia smallint not null,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint nomina_dia_libre_dias_iso_check check (iso_dia between 1 and 7),
  constraint nomina_dia_libre_dias_empresa_id_id_unique
    unique (empresa_id, id),
  constraint nomina_dia_libre_dias_configuracion_dia_unique
    unique (empresa_id, configuracion_id, iso_dia),
  constraint nomina_dia_libre_dias_configuracion_fk
    foreign key (empresa_id, configuracion_id, empleado_id)
    references public.nomina_dias_libres(empresa_id, id, empleado_id)
    on delete restrict,
  constraint nomina_dia_libre_dias_created_by_fk
    foreign key (empresa_id, created_by)
    references public.profiles(company_id, id) on delete restrict
);

create index nomina_dia_libre_dias_lookup_idx
  on public.nomina_dia_libre_dias(
    empresa_id, empleado_id, configuracion_id, iso_dia
  );

create table public.nomina_coberturas (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  tipo text not null,
  fecha_desde date not null,
  fecha_hasta date not null,
  periodo daterange generated always as (
    daterange(
      fecha_desde,
      case
        when fecha_hasta < fecha_desde then fecha_desde
        else fecha_hasta + 1
      end,
      '[)'
    )
  ) stored,
  porcentaje numeric(5,2) not null,
  descripcion text not null,
  estado text not null default 'APROBADA',
  aprobado_por uuid,
  aprobado_en timestamptz,
  revision bigint not null default 1,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_by uuid not null,
  updated_at timestamptz not null default clock_timestamp(),
  constraint nomina_coberturas_tipo_check
    check (tipo in ('LICENCIA', 'VACACIONES')),
  constraint nomina_coberturas_fechas_check
    check (fecha_desde <= fecha_hasta),
  constraint nomina_coberturas_porcentaje_check check (
    (tipo = 'LICENCIA' and porcentaje between 0 and 100)
    or (tipo = 'VACACIONES' and porcentaje = 100)
  ),
  constraint nomina_coberturas_descripcion_check
    check (char_length(btrim(descripcion)) between 3 and 500),
  constraint nomina_coberturas_estado_check
    check (estado in ('BORRADOR', 'APROBADA', 'RECHAZADA', 'REVOCADA')),
  constraint nomina_coberturas_aprobacion_check check (
    (estado <> 'APROBADA')
    or (aprobado_por is not null and aprobado_en is not null)
  ),
  constraint nomina_coberturas_revision_check check (revision > 0),
  constraint nomina_coberturas_empresa_id_id_unique unique (empresa_id, id),
  constraint nomina_coberturas_empleado_fk
    foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  constraint nomina_coberturas_created_by_fk
    foreign key (empresa_id, created_by)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_coberturas_updated_by_fk
    foreign key (empresa_id, updated_by)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_coberturas_aprobado_por_fk
    foreign key (empresa_id, aprobado_por)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_coberturas_no_overlap
    exclude using gist (
      empresa_id with =,
      empleado_id with =,
      periodo with &&
    ) where (estado = 'APROBADA')
    deferrable initially immediate
);

create index nomina_coberturas_lookup_idx
  on public.nomina_coberturas(
    empresa_id, empleado_id, tipo, fecha_desde desc, estado
  );

create table public.nomina_festivos (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  fecha date not null,
  descripcion text not null,
  activo boolean not null default true,
  revision bigint not null default 1,
  created_by uuid not null,
  created_at timestamptz not null default clock_timestamp(),
  updated_by uuid not null,
  updated_at timestamptz not null default clock_timestamp(),
  constraint nomina_festivos_descripcion_check
    check (char_length(btrim(descripcion)) between 3 and 300),
  constraint nomina_festivos_revision_check check (revision > 0),
  constraint nomina_festivos_empresa_fecha_unique unique (empresa_id, fecha),
  constraint nomina_festivos_empresa_id_id_unique unique (empresa_id, id),
  constraint nomina_festivos_created_by_fk
    foreign key (empresa_id, created_by)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_festivos_updated_by_fk
    foreign key (empresa_id, updated_by)
    references public.profiles(company_id, id) on delete restrict
);

create index nomina_festivos_lookup_idx
  on public.nomina_festivos(empresa_id, fecha, activo);

create table public.nomina_calendario_auditoria (
  id bigint generated always as identity primary key,
  empresa_id uuid not null references public.companies(id) on delete restrict,
  actor_id uuid,
  empleado_id uuid,
  entidad text not null,
  entidad_id uuid not null,
  accion text not null,
  revision bigint not null,
  antes jsonb,
  despues jsonb,
  motivo text not null,
  created_at timestamptz not null default clock_timestamp(),
  constraint nomina_calendario_auditoria_entidad_check
    check (entidad in (
      'nomina_plantillas_horario',
      'nomina_plantilla_horario_versiones',
      'nomina_plantilla_horario_dias',
      'nomina_asignaciones_horario',
      'nomina_condiciones_salariales',
      'nomina_dias_libres',
      'nomina_dia_libre_dias',
      'nomina_coberturas',
      'nomina_festivos'
    )),
  constraint nomina_calendario_auditoria_accion_check
    check (accion in ('INSERT', 'UPDATE')),
  constraint nomina_calendario_auditoria_revision_check check (revision > 0),
  constraint nomina_calendario_auditoria_actor_fk
    foreign key (empresa_id, actor_id)
    references public.profiles(company_id, id) on delete restrict,
  constraint nomina_calendario_auditoria_empleado_fk
    foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict
);

create index nomina_calendario_auditoria_entidad_idx
  on public.nomina_calendario_auditoria(
    empresa_id, entidad, entidad_id, created_at desc
  );
create index nomina_calendario_auditoria_empleado_idx
  on public.nomina_calendario_auditoria(
    empresa_id, empleado_id, created_at desc
  ) where empleado_id is not null;


create or replace function private.actor_nomina_calendario_0042()
returns table(perfil_id uuid, empresa_id uuid, rol_codigo text)
language sql
stable
security definer
set search_path = ''
as $$
  select pr.id, pr.company_id, private.normalizar_codigo_rol(r.code)
  from public.profiles pr
  join public.companies c
    on c.id = pr.company_id
   and c.status = 'active'
  join public.roles r
    on r.id = pr.role_id
   and r.company_id = pr.company_id
   and r.is_active
  where pr.id = (select auth.uid())
    and pr.status = 'active'
    and pr.access_deleted_at is null
  limit 1;
$$;

create or replace function private.permiso_efectivo_nomina_0042(
  p_codigo text
) returns table(permitido boolean, alcance text)
language sql
stable
security definer
set search_path = ''
as $$
  with actor as (
    select * from private.actor_nomina_calendario_0042()
  )
  select
    case
      when pp.perfil_id is not null then pp.permitido
      else coalesce(rp.permitido, false)
    end,
    case
      when pp.perfil_id is not null then pp.alcance
      else rp.alcance
    end
  from actor a
  join public.profiles pr on pr.id = a.perfil_id
  join public.permisos pe
    on pe.codigo = p_codigo
   and pe.activo
  left join public.perfil_permisos pp
    on pp.perfil_id = pr.id
   and pp.permiso_id = pe.id
  left join public.rol_permisos rp
    on rp.rol_id = pr.role_id
   and rp.permiso_id = pe.id
  limit 1;
$$;

create or replace function public.tiene_permiso_en_alcance(
  p_permiso text,
  p_alcances text[]
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (
      select permiso.permitido
         and permiso.alcance = any(coalesce(p_alcances, array[]::text[]))
      from private.permiso_efectivo_nomina_0042(p_permiso) permiso
      limit 1
    ),
    false
  );
$$;

create or replace function public.puede_operar_empleado_en_alcance(
  p_empleado uuid,
  p_permiso text
) returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  with actor as (
    select * from private.actor_nomina_calendario_0042()
  ), permiso as (
    select * from private.permiso_efectivo_nomina_0042(p_permiso)
  )
  select coalesce(exists(
    select 1
    from actor a
    cross join permiso pe
    join public.profiles pr on pr.id = a.perfil_id
    join public.empleados e
      on e.id = p_empleado
     and e.empresa_id = a.empresa_id
     and e.activo
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
              or exists(
                select 1
                from public.perfil_sucursales ps
                where ps.perfil_id = pr.id
                  and ps.sucursal_id = e.sucursal_id
              )
            )
            when 'departamento' then (
              e.departamento_id = pr.department_id
              or exists(
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

create or replace function private.proteger_historial_nomina_0042()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  raise exception using
    errcode = 'P4200',
    message = 'NOMINA_0042_HISTORY_IS_APPEND_ONLY';
end;
$$;

create or replace function private.validar_revision_nomina_0042()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.empresa_id is distinct from old.empresa_id
     or new.id is distinct from old.id
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at
     or new.revision <> old.revision + 1
     or new.updated_by is null
  then
    raise exception using
      errcode = 'P4201',
      message = 'NOMINA_0042_REVISION_INVALID';
  end if;

  if tg_table_name = 'nomina_asignaciones_horario' then
    if new.empleado_id is distinct from old.empleado_id
       or new.plantilla_version_id is distinct from old.plantilla_version_id
       or new.vigente_desde is distinct from old.vigente_desde
       or new.motivo is distinct from old.motivo
    then
      raise exception using
        errcode = 'P4201', message = 'NOMINA_0042_REVISION_INVALID';
    end if;
  elsif tg_table_name = 'nomina_condiciones_salariales' then
    if new.empleado_id is distinct from old.empleado_id
       or new.sueldo_mensual is distinct from old.sueldo_mensual
       or new.valor_hora_extra is distinct from old.valor_hora_extra
       or new.vigente_desde is distinct from old.vigente_desde
       or new.motivo is distinct from old.motivo
    then
      raise exception using
        errcode = 'P4201', message = 'NOMINA_0042_REVISION_INVALID';
    end if;
  elsif tg_table_name = 'nomina_dias_libres' then
    if new.empleado_id is distinct from old.empleado_id
       or new.vigente_desde is distinct from old.vigente_desde
       or new.descripcion is distinct from old.descripcion
       or old.vigente_hasta is not null
       or new.vigente_hasta is null
       or new.vigente_hasta < old.vigente_desde
    then
      raise exception using
        errcode = 'P4201', message = 'NOMINA_0042_REVISION_INVALID';
    end if;
  elsif tg_table_name = 'nomina_coberturas' then
    if new.empleado_id is distinct from old.empleado_id
       or new.tipo is distinct from old.tipo
       or new.fecha_desde is distinct from old.fecha_desde
       or new.fecha_hasta is distinct from old.fecha_hasta
       or new.porcentaje is distinct from old.porcentaje
       or new.descripcion is distinct from old.descripcion
       or new.aprobado_por is distinct from old.aprobado_por
       or new.aprobado_en is distinct from old.aprobado_en
    then
      raise exception using
        errcode = 'P4201', message = 'NOMINA_0042_REVISION_INVALID';
    end if;
  elsif tg_table_name = 'nomina_festivos' then
    if new.fecha is distinct from old.fecha then
      raise exception using
        errcode = 'P4201', message = 'NOMINA_0042_REVISION_INVALID';
    end if;
  elsif tg_table_name = 'nomina_plantillas_horario' then
    null;
  else
    raise exception using
      errcode = 'P4201', message = 'NOMINA_0042_REVISION_INVALID';
  end if;

  return new;
end;
$$;

create or replace function private.auditar_nomina_calendario_0042()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row jsonb := to_jsonb(new);
  v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) else null end;
  v_empresa uuid;
  v_actor_candidate uuid;
  v_actor uuid;
  v_empleado uuid;
  v_revision bigint;
  v_motivo text;
begin
  v_empresa := (v_row ->> 'empresa_id')::uuid;
  v_actor_candidate := coalesce(
    (select auth.uid()),
    nullif(v_row ->> 'updated_by', '')::uuid,
    nullif(v_row ->> 'created_by', '')::uuid
  );
  select pr.id into v_actor
  from public.profiles pr
  where pr.id = v_actor_candidate
    and pr.company_id = v_empresa;
  v_empleado := nullif(v_row ->> 'empleado_id', '')::uuid;
  v_revision := coalesce(nullif(v_row ->> 'revision', '')::bigint, 1);
  v_motivo := coalesce(
    nullif(current_setting('app.nomina_0042_motivo', true), ''),
    nullif(v_row ->> 'motivo', ''),
    'Operación de configuración 0042'
  );

  insert into public.nomina_calendario_auditoria(
    empresa_id, actor_id, empleado_id, entidad, entidad_id,
    accion, revision, antes, despues, motivo
  ) values (
    v_empresa, v_actor, v_empleado, tg_table_name,
    (v_row ->> 'id')::uuid, tg_op, v_revision,
    v_old, v_row, v_motivo
  );

  return new;
end;
$$;

create trigger nomina_plantilla_versiones_immutable
before update or delete on public.nomina_plantilla_horario_versiones
for each row execute function private.proteger_historial_nomina_0042();
create trigger nomina_plantilla_dias_immutable
before update or delete on public.nomina_plantilla_horario_dias
for each row execute function private.proteger_historial_nomina_0042();
create trigger nomina_dia_libre_dias_immutable
before update or delete on public.nomina_dia_libre_dias
for each row execute function private.proteger_historial_nomina_0042();
create trigger nomina_calendario_auditoria_immutable
before update or delete on public.nomina_calendario_auditoria
for each row execute function private.proteger_historial_nomina_0042();

create trigger nomina_plantillas_revision_guard
before update on public.nomina_plantillas_horario
for each row execute function private.validar_revision_nomina_0042();
create trigger nomina_asignaciones_revision_guard
before update on public.nomina_asignaciones_horario
for each row execute function private.validar_revision_nomina_0042();
create trigger nomina_condiciones_revision_guard
before update on public.nomina_condiciones_salariales
for each row execute function private.validar_revision_nomina_0042();
create trigger nomina_dias_libres_revision_guard
before update on public.nomina_dias_libres
for each row execute function private.validar_revision_nomina_0042();
create trigger nomina_coberturas_revision_guard
before update on public.nomina_coberturas
for each row execute function private.validar_revision_nomina_0042();
create trigger nomina_festivos_revision_guard
before update on public.nomina_festivos
for each row execute function private.validar_revision_nomina_0042();

create trigger nomina_plantillas_no_delete
before delete or truncate on public.nomina_plantillas_horario
for each statement execute function private.proteger_historial_nomina_0042();
create trigger nomina_plantilla_versiones_no_truncate
before truncate on public.nomina_plantilla_horario_versiones
for each statement execute function private.proteger_historial_nomina_0042();
create trigger nomina_plantilla_dias_no_truncate
before truncate on public.nomina_plantilla_horario_dias
for each statement execute function private.proteger_historial_nomina_0042();
create trigger nomina_asignaciones_no_delete
before delete or truncate on public.nomina_asignaciones_horario
for each statement execute function private.proteger_historial_nomina_0042();
create trigger nomina_condiciones_no_delete
before delete or truncate on public.nomina_condiciones_salariales
for each statement execute function private.proteger_historial_nomina_0042();
create trigger nomina_dias_libres_no_delete
before delete or truncate on public.nomina_dias_libres
for each statement execute function private.proteger_historial_nomina_0042();
create trigger nomina_dia_libre_dias_no_truncate
before truncate on public.nomina_dia_libre_dias
for each statement execute function private.proteger_historial_nomina_0042();
create trigger nomina_coberturas_no_delete
before delete or truncate on public.nomina_coberturas
for each statement execute function private.proteger_historial_nomina_0042();
create trigger nomina_festivos_no_delete
before delete or truncate on public.nomina_festivos
for each statement execute function private.proteger_historial_nomina_0042();
create trigger nomina_calendario_auditoria_no_truncate
before truncate on public.nomina_calendario_auditoria
for each statement execute function private.proteger_historial_nomina_0042();

create trigger nomina_plantillas_audit
after insert or update on public.nomina_plantillas_horario
for each row execute function private.auditar_nomina_calendario_0042();
create trigger nomina_plantilla_versiones_audit
after insert on public.nomina_plantilla_horario_versiones
for each row execute function private.auditar_nomina_calendario_0042();
create trigger nomina_plantilla_dias_audit
after insert on public.nomina_plantilla_horario_dias
for each row execute function private.auditar_nomina_calendario_0042();
create trigger nomina_asignaciones_audit
after insert or update on public.nomina_asignaciones_horario
for each row execute function private.auditar_nomina_calendario_0042();
create trigger nomina_condiciones_audit
after insert or update on public.nomina_condiciones_salariales
for each row execute function private.auditar_nomina_calendario_0042();
create trigger nomina_dias_libres_audit
after insert or update on public.nomina_dias_libres
for each row execute function private.auditar_nomina_calendario_0042();
create trigger nomina_dia_libre_dias_audit
after insert on public.nomina_dia_libre_dias
for each row execute function private.auditar_nomina_calendario_0042();
create trigger nomina_coberturas_audit
after insert or update on public.nomina_coberturas
for each row execute function private.auditar_nomina_calendario_0042();
create trigger nomina_festivos_audit
after insert or update on public.nomina_festivos
for each row execute function private.auditar_nomina_calendario_0042();


alter table public.nomina_plantillas_horario enable row level security;
alter table public.nomina_plantilla_horario_versiones enable row level security;
alter table public.nomina_plantilla_horario_dias enable row level security;
alter table public.nomina_asignaciones_horario enable row level security;
alter table public.nomina_condiciones_salariales enable row level security;
alter table public.nomina_dias_libres enable row level security;
alter table public.nomina_dia_libre_dias enable row level security;
alter table public.nomina_coberturas enable row level security;
alter table public.nomina_festivos enable row level security;
alter table public.nomina_calendario_auditoria enable row level security;

create policy nomina_plantillas_horario_select
on public.nomina_plantillas_horario
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and (
    public.tiene_permiso_en_alcance(
      'configuracion.horarios', array['empresa', 'global']
    )
    or public.tiene_permiso_en_alcance(
      'horarios.ver_asignados',
      array['departamento', 'sucursal', 'empresa', 'global']
    )
    or public.tiene_permiso_en_alcance(
      'horarios.editar_asignados',
      array['departamento', 'sucursal', 'empresa', 'global']
    )
  )
);

create policy nomina_plantilla_versiones_select
on public.nomina_plantilla_horario_versiones
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and exists(
    select 1
    from public.nomina_plantillas_horario plantilla
    where plantilla.empresa_id = nomina_plantilla_horario_versiones.empresa_id
      and plantilla.id = nomina_plantilla_horario_versiones.plantilla_id
  )
);

create policy nomina_plantilla_dias_select
on public.nomina_plantilla_horario_dias
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and exists(
    select 1
    from public.nomina_plantilla_horario_versiones version
    where version.empresa_id = nomina_plantilla_horario_dias.empresa_id
      and version.id = nomina_plantilla_horario_dias.plantilla_version_id
  )
);

create policy nomina_asignaciones_horario_select
on public.nomina_asignaciones_horario
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and (
    public.puede_operar_empleado_en_alcance(
      empleado_id, 'horarios.ver_asignados'
    )
    or public.puede_operar_empleado_en_alcance(
      empleado_id, 'horarios.editar_asignados'
    )
    or public.puede_operar_empleado_en_alcance(
      empleado_id, 'configuracion.horarios'
    )
  )
);

create policy nomina_condiciones_salariales_select
on public.nomina_condiciones_salariales
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and (
    public.puede_operar_empleado_en_alcance(empleado_id, 'nomina.ver')
    or public.puede_operar_empleado_en_alcance(empleado_id, 'nomina.editar')
  )
);

create policy nomina_dias_libres_select
on public.nomina_dias_libres
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and (
    public.puede_operar_empleado_en_alcance(
      empleado_id, 'dias_libres.ver_asignados'
    )
    or public.puede_operar_empleado_en_alcance(
      empleado_id, 'dias_libres.editar_asignados'
    )
  )
);

create policy nomina_dia_libre_dias_select
on public.nomina_dia_libre_dias
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and (
    public.puede_operar_empleado_en_alcance(
      empleado_id, 'dias_libres.ver_asignados'
    )
    or public.puede_operar_empleado_en_alcance(
      empleado_id, 'dias_libres.editar_asignados'
    )
  )
);

create policy nomina_coberturas_select
on public.nomina_coberturas
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and tipo in ('LICENCIA', 'VACACIONES')
  and public.puede_operar_empleado_en_alcance(
    empleado_id, 'recursos_humanos.acceder'
  )
);

create policy nomina_festivos_select
on public.nomina_festivos
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and public.tiene_permiso_en_alcance(
    'nomina.festivos', array['empresa', 'global']
  )
);

create policy nomina_calendario_auditoria_select
on public.nomina_calendario_auditoria
for select to authenticated
using (
  empresa_id = public.obtener_empresa_actual()
  and public.tiene_permiso_en_alcance(
    'configuracion.seguridad', array['empresa', 'global']
  )
);

create or replace function private.insertar_version_plantilla_horario_0042(
  p_empresa uuid,
  p_plantilla uuid,
  p_descripcion text,
  p_dias jsonb,
  p_actor uuid,
  p_motivo text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_version_id uuid;
  v_revision integer;
  v_count integer;
  v_distinct integer;
  v_min integer;
  v_max integer;
begin
  if jsonb_typeof(p_dias) <> 'array' then
    raise exception using
      errcode = '22023', message = 'HORARIO_DIAS_INVALIDOS';
  end if;

  select
    count(*)::integer,
    count(distinct d.iso_dia)::integer,
    min(d.iso_dia)::integer,
    max(d.iso_dia)::integer
  into v_count, v_distinct, v_min, v_max
  from jsonb_to_recordset(p_dias) as d(
    iso_dia smallint,
    minutos_normales integer,
    hora_entrada time,
    hora_salida time,
    inicio_almuerzo time,
    duracion_almuerzo_min integer,
    tolerancia_min integer
  );

  if v_count <> 7 or v_distinct <> 7 or v_min <> 1 or v_max <> 7 then
    raise exception using
      errcode = '22023', message = 'HORARIO_REQUIERE_LUNES_A_DOMINGO';
  end if;

  perform 1
  from public.nomina_plantillas_horario plantilla
  where plantilla.empresa_id = p_empresa
    and plantilla.id = p_plantilla
    and plantilla.activo
  for update;
  if not found then
    raise exception using
      errcode = '22023', message = 'PLANTILLA_HORARIO_NO_DISPONIBLE';
  end if;

  select coalesce(max(version.revision), 0) + 1
  into v_revision
  from public.nomina_plantilla_horario_versiones version
  where version.empresa_id = p_empresa
    and version.plantilla_id = p_plantilla;

  insert into public.nomina_plantilla_horario_versiones(
    empresa_id, plantilla_id, revision, descripcion,
    motivo, created_by
  ) values (
    p_empresa, p_plantilla, v_revision, nullif(btrim(p_descripcion), ''),
    btrim(p_motivo), p_actor
  )
  returning id into v_version_id;

  insert into public.nomina_plantilla_horario_dias(
    empresa_id, plantilla_version_id, iso_dia, minutos_normales,
    hora_entrada, hora_salida, inicio_almuerzo,
    duracion_almuerzo_min, tolerancia_min, created_by
  )
  select
    p_empresa, v_version_id, d.iso_dia, d.minutos_normales,
    d.hora_entrada, d.hora_salida, d.inicio_almuerzo,
    coalesce(d.duracion_almuerzo_min, 0),
    coalesce(d.tolerancia_min, 0), p_actor
  from jsonb_to_recordset(p_dias) as d(
    iso_dia smallint,
    minutos_normales integer,
    hora_entrada time,
    hora_salida time,
    inicio_almuerzo time,
    duracion_almuerzo_min integer,
    tolerancia_min integer
  );

  return v_version_id;
end;
$$;


create or replace function public.guardar_plantilla_horario(
  p_nombre text,
  p_descripcion text,
  p_dias jsonb,
  p_motivo text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_plantilla uuid;
  v_version uuid;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not public.tiene_permiso_en_alcance(
    'configuracion.horarios', array['empresa', 'global']
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if char_length(btrim(coalesce(p_nombre, ''))) not between 2 and 120
     or char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500
  then
    raise exception using
      errcode = '22023', message = 'PLANTILLA_HORARIO_INVALIDA';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  insert into public.nomina_plantillas_horario(
    empresa_id, nombre, descripcion, created_by, updated_by
  ) values (
    v_actor.empresa_id, btrim(p_nombre), nullif(btrim(p_descripcion), ''),
    v_actor.perfil_id, v_actor.perfil_id
  )
  returning id into v_plantilla;

  v_version := private.insertar_version_plantilla_horario_0042(
    v_actor.empresa_id, v_plantilla, p_descripcion,
    p_dias, v_actor.perfil_id, p_motivo
  );

  return jsonb_build_object(
    'plantilla_id', v_plantilla,
    'version_id', v_version
  );
end;
$$;

create or replace function public.revisar_plantilla_horario(
  p_plantilla uuid,
  p_descripcion text,
  p_dias jsonb,
  p_motivo text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_version uuid;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not public.tiene_permiso_en_alcance(
    'configuracion.horarios', array['empresa', 'global']
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500 then
    raise exception using errcode = '22023', message = 'MOTIVO_REQUERIDO';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  v_version := private.insertar_version_plantilla_horario_0042(
    v_actor.empresa_id, p_plantilla, p_descripcion,
    p_dias, v_actor.perfil_id, p_motivo
  );
  return v_version;
end;
$$;

create or replace function public.cambiar_estado_plantilla_horario(
  p_plantilla uuid,
  p_activo boolean,
  p_motivo text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not public.tiene_permiso_en_alcance(
    'configuracion.horarios', array['empresa', 'global']
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500 then
    raise exception using errcode = '22023', message = 'MOTIVO_REQUERIDO';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  update public.nomina_plantillas_horario plantilla
  set activo = p_activo,
      revision = plantilla.revision + 1,
      updated_by = v_actor.perfil_id,
      updated_at = clock_timestamp()
  where plantilla.empresa_id = v_actor.empresa_id
    and plantilla.id = p_plantilla;
  if not found then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
end;
$$;

create or replace function public.listar_plantillas_horario()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_result jsonb;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not (
    public.tiene_permiso_en_alcance(
      'configuracion.horarios', array['empresa', 'global']
    )
    or public.tiene_permiso_en_alcance(
      'horarios.ver_asignados',
      array['departamento', 'sucursal', 'empresa', 'global']
    )
    or public.tiene_permiso_en_alcance(
      'horarios.editar_asignados',
      array['departamento', 'sucursal', 'empresa', 'global']
    )
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', plantilla.id,
      'nombre', plantilla.nombre,
      'descripcion', plantilla.descripcion,
      'activo', plantilla.activo,
      'revision', plantilla.revision,
      'versiones', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'id', version.id,
            'revision', version.revision,
            'descripcion', version.descripcion,
            'created_at', version.created_at,
            'dias', coalesce((
              select jsonb_agg(
                to_jsonb(dia) - 'empresa_id' - 'created_by'
                order by dia.iso_dia
              )
              from public.nomina_plantilla_horario_dias dia
              where dia.empresa_id = version.empresa_id
                and dia.plantilla_version_id = version.id
            ), '[]'::jsonb)
          )
          order by version.revision desc
        )
        from public.nomina_plantilla_horario_versiones version
        where version.empresa_id = plantilla.empresa_id
          and version.plantilla_id = plantilla.id
      ), '[]'::jsonb)
    )
    order by plantilla.nombre
  ), '[]'::jsonb)
  into v_result
  from public.nomina_plantillas_horario plantilla
  where plantilla.empresa_id = v_actor.empresa_id;

  return v_result;
end;
$$;

create or replace function public.asignar_plantilla_horario(
  p_empleado uuid,
  p_plantilla_version uuid,
  p_desde date,
  p_hasta date,
  p_motivo text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_id uuid;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;

  perform 1
  from public.empleados empleado
  where empleado.empresa_id = v_actor.empresa_id
    and empleado.id = p_empleado
    and empleado.activo
  for update;
  if not found or not (
    public.puede_operar_empleado_en_alcance(
      p_empleado, 'horarios.editar_asignados'
    )
    or public.puede_operar_empleado_en_alcance(
      p_empleado, 'configuracion.horarios'
    )
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if p_desde is null
     or (p_hasta is not null and p_desde > p_hasta)
     or char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500
  then
    raise exception using errcode = '22023', message = 'VIGENCIA_INVALIDA';
  end if;
  if not exists(
    select 1
    from public.nomina_plantilla_horario_versiones version
    join public.nomina_plantillas_horario plantilla
      on plantilla.empresa_id = version.empresa_id
     and plantilla.id = version.plantilla_id
     and plantilla.activo
    where version.empresa_id = v_actor.empresa_id
      and version.id = p_plantilla_version
  ) then
    raise exception using
      errcode = '22023', message = 'PLANTILLA_HORARIO_NO_DISPONIBLE';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  insert into public.nomina_asignaciones_horario(
    empresa_id, empleado_id, plantilla_version_id,
    vigente_desde, vigente_hasta, motivo,
    created_by, updated_by
  ) values (
    v_actor.empresa_id, p_empleado, p_plantilla_version,
    p_desde, p_hasta, btrim(p_motivo),
    v_actor.perfil_id, v_actor.perfil_id
  )
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.cerrar_asignacion_horario(
  p_asignacion uuid,
  p_hasta date,
  p_motivo text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_asignacion public.nomina_asignaciones_horario%rowtype;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  select * into v_asignacion
  from public.nomina_asignaciones_horario asignacion
  where asignacion.empresa_id = v_actor.empresa_id
    and asignacion.id = p_asignacion
  for update;
  if not found or not (
    public.puede_operar_empleado_en_alcance(
      v_asignacion.empleado_id, 'horarios.editar_asignados'
    )
    or public.puede_operar_empleado_en_alcance(
      v_asignacion.empleado_id, 'configuracion.horarios'
    )
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if p_hasta is null
     or p_hasta < v_asignacion.vigente_desde
     or char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500
  then
    raise exception using errcode = '22023', message = 'VIGENCIA_INVALIDA';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  update public.nomina_asignaciones_horario asignacion
  set vigente_hasta = p_hasta,
      revision = asignacion.revision + 1,
      updated_by = v_actor.perfil_id,
      updated_at = clock_timestamp()
  where asignacion.empresa_id = v_actor.empresa_id
    and asignacion.id = p_asignacion;
end;
$$;

create or replace function public.listar_asignaciones_horario_empleado(
  p_empleado uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_result jsonb;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not (
    public.puede_operar_empleado_en_alcance(
      p_empleado, 'horarios.ver_asignados'
    )
    or public.puede_operar_empleado_en_alcance(
      p_empleado, 'horarios.editar_asignados'
    )
    or public.puede_operar_empleado_en_alcance(
      p_empleado, 'configuracion.horarios'
    )
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;

  select coalesce(jsonb_agg(
    to_jsonb(asignacion) - 'empresa_id' - 'created_by' - 'updated_by'
    order by asignacion.vigente_desde desc
  ), '[]'::jsonb)
  into v_result
  from public.nomina_asignaciones_horario asignacion
  where asignacion.empresa_id = v_actor.empresa_id
    and asignacion.empleado_id = p_empleado;

  return v_result;
end;
$$;


create or replace function public.guardar_condicion_salarial(
  p_empleado uuid,
  p_sueldo_mensual numeric,
  p_valor_hora_extra numeric,
  p_desde date,
  p_hasta date,
  p_motivo text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_id uuid;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  perform 1
  from public.empleados empleado
  where empleado.empresa_id = v_actor.empresa_id
    and empleado.id = p_empleado
    and empleado.activo
  for update;
  if not found or not public.puede_operar_empleado_en_alcance(
    p_empleado, 'nomina.editar'
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if p_sueldo_mensual is null or p_sueldo_mensual <= 0
     or p_valor_hora_extra is null or p_valor_hora_extra < 0
     or p_desde is null
     or (p_hasta is not null and p_desde > p_hasta)
     or char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500
  then
    raise exception using
      errcode = '22023', message = 'CONDICION_SALARIAL_INVALIDA';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  insert into public.nomina_condiciones_salariales(
    empresa_id, empleado_id, sueldo_mensual, valor_hora_extra,
    vigente_desde, vigente_hasta, motivo, created_by, updated_by
  ) values (
    v_actor.empresa_id, p_empleado, round(p_sueldo_mensual, 2),
    round(p_valor_hora_extra, 2), p_desde, p_hasta, btrim(p_motivo),
    v_actor.perfil_id, v_actor.perfil_id
  )
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.cerrar_condicion_salarial(
  p_condicion uuid,
  p_hasta date,
  p_motivo text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_condicion public.nomina_condiciones_salariales%rowtype;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  select * into v_condicion
  from public.nomina_condiciones_salariales condicion
  where condicion.empresa_id = v_actor.empresa_id
    and condicion.id = p_condicion
  for update;
  if not found or not public.puede_operar_empleado_en_alcance(
    v_condicion.empleado_id, 'nomina.editar'
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if p_hasta is null
     or p_hasta < v_condicion.vigente_desde
     or char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500
  then
    raise exception using errcode = '22023', message = 'VIGENCIA_INVALIDA';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  update public.nomina_condiciones_salariales condicion
  set vigente_hasta = p_hasta,
      revision = condicion.revision + 1,
      updated_by = v_actor.perfil_id,
      updated_at = clock_timestamp()
  where condicion.empresa_id = v_actor.empresa_id
    and condicion.id = p_condicion;
end;
$$;

create or replace function public.listar_condiciones_salariales_empleado(
  p_empleado uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_result jsonb;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not (
    public.puede_operar_empleado_en_alcance(p_empleado, 'nomina.ver')
    or public.puede_operar_empleado_en_alcance(p_empleado, 'nomina.editar')
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;

  select coalesce(jsonb_agg(
    to_jsonb(condicion) - 'empresa_id' - 'created_by' - 'updated_by'
    order by condicion.vigente_desde desc
  ), '[]'::jsonb)
  into v_result
  from public.nomina_condiciones_salariales condicion
  where condicion.empresa_id = v_actor.empresa_id
    and condicion.empleado_id = p_empleado;

  return v_result;
end;
$$;

create or replace function public.asignar_dias_libres_semanales(
  p_empleado uuid,
  p_vigente_desde date,
  p_vigente_hasta date,
  p_iso_dias smallint[],
  p_descripcion text,
  p_motivo text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_id uuid;
  v_total integer;
  v_unicos integer;
  v_validos boolean;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  perform 1
  from public.empleados empleado
  where empleado.empresa_id = v_actor.empresa_id
    and empleado.id = p_empleado
    and empleado.activo
  for update;
  if not found or not public.puede_operar_empleado_en_alcance(
    p_empleado, 'dias_libres.editar_asignados'
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;

  select count(*)::integer,
         count(distinct dia)::integer,
         coalesce(bool_and(dia between 1 and 7), false)
  into v_total, v_unicos, v_validos
  from unnest(p_iso_dias) as dias(dia);

  if p_vigente_desde is null
     or (
       p_vigente_hasta is not null
       and p_vigente_desde > p_vigente_hasta
     )
     or v_total not between 1 and 7
     or v_total <> v_unicos
     or not v_validos
     or char_length(btrim(coalesce(p_descripcion, ''))) not between 3 and 500
     or char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500
  then
    raise exception using
      errcode = '22023', message = 'DIAS_LIBRES_SEMANALES_INVALIDOS';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  insert into public.nomina_dias_libres(
    empresa_id, empleado_id, vigente_desde, vigente_hasta,
    descripcion, created_by, updated_by
  ) values (
    v_actor.empresa_id, p_empleado, p_vigente_desde, p_vigente_hasta,
    btrim(p_descripcion), v_actor.perfil_id, v_actor.perfil_id
  )
  returning id into v_id;

  insert into public.nomina_dia_libre_dias(
    empresa_id, configuracion_id, empleado_id, iso_dia, created_by
  )
  select
    v_actor.empresa_id, v_id, p_empleado, dia, v_actor.perfil_id
  from unnest(p_iso_dias) as dias(dia)
  order by dia;

  return v_id;
end;
$$;

create or replace function public.cerrar_dias_libres_semanales(
  p_configuracion uuid,
  p_hasta date,
  p_motivo text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_configuracion public.nomina_dias_libres%rowtype;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  select * into v_configuracion
  from public.nomina_dias_libres configuracion
  where configuracion.empresa_id = v_actor.empresa_id
    and configuracion.id = p_configuracion
  for update;
  if not found or not public.puede_operar_empleado_en_alcance(
    v_configuracion.empleado_id, 'dias_libres.editar_asignados'
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if v_configuracion.vigente_hasta is not null then
    raise exception using
      errcode = 'P4201', message = 'DIAS_LIBRES_YA_CERRADOS';
  end if;
  if p_hasta is null
     or p_hasta < v_configuracion.vigente_desde
     or char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500
  then
    raise exception using
      errcode = '22023', message = 'CIERRE_DIAS_LIBRES_INVALIDO';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  update public.nomina_dias_libres configuracion
  set vigente_hasta = p_hasta,
      revision = configuracion.revision + 1,
      updated_by = v_actor.perfil_id,
      updated_at = clock_timestamp()
  where configuracion.empresa_id = v_actor.empresa_id
    and configuracion.id = p_configuracion;
end;
$$;

create or replace function public.listar_dias_libres_empleado(
  p_empleado uuid
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_result jsonb;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not (
    public.puede_operar_empleado_en_alcance(
      p_empleado, 'dias_libres.ver_asignados'
    )
    or public.puede_operar_empleado_en_alcance(
      p_empleado, 'dias_libres.editar_asignados'
    )
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;

  select coalesce(jsonb_agg(
    (
      to_jsonb(configuracion)
      - 'empresa_id' - 'created_by' - 'updated_by' - 'periodo'
    ) || jsonb_build_object(
      'iso_dias',
      (
        select coalesce(
          jsonb_agg(detalle.iso_dia order by detalle.iso_dia),
          '[]'::jsonb
        )
        from public.nomina_dia_libre_dias detalle
        where detalle.empresa_id = configuracion.empresa_id
          and detalle.configuracion_id = configuracion.id
      )
    )
    order by configuracion.vigente_desde desc
  ), '[]'::jsonb)
  into v_result
  from public.nomina_dias_libres configuracion
  where configuracion.empresa_id = v_actor.empresa_id
    and configuracion.empleado_id = p_empleado;

  return v_result;
end;
$$;

create or replace function public.registrar_cobertura_empleado(
  p_empleado uuid,
  p_tipo text,
  p_desde date,
  p_hasta date,
  p_porcentaje numeric,
  p_descripcion text,
  p_motivo text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_tipo text := upper(btrim(coalesce(p_tipo, '')));
  v_id uuid;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if v_tipo not in ('LICENCIA', 'VACACIONES') then
    raise exception using errcode = '22023', message = 'COBERTURA_TIPO_INVALIDO';
  end if;

  perform 1
  from public.empleados empleado
  where empleado.empresa_id = v_actor.empresa_id
    and empleado.id = p_empleado
    and empleado.activo
  for update;
  if not found or not public.puede_operar_empleado_en_alcance(
    p_empleado, 'recursos_humanos.acceder'
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if p_desde is null or p_hasta is null or p_desde > p_hasta
     or p_porcentaje is null
     or p_porcentaje < 0 or p_porcentaje > 100
     or (v_tipo = 'VACACIONES' and p_porcentaje <> 100)
     or char_length(btrim(coalesce(p_descripcion, ''))) not between 3 and 500
     or char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500
  then
    raise exception using errcode = '22023', message = 'COBERTURA_INVALIDA';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  insert into public.nomina_coberturas(
    empresa_id, empleado_id, tipo, fecha_desde, fecha_hasta,
    porcentaje, descripcion, estado, aprobado_por, aprobado_en,
    created_by, updated_by
  ) values (
    v_actor.empresa_id, p_empleado, v_tipo, p_desde, p_hasta,
    round(p_porcentaje, 2), btrim(p_descripcion), 'APROBADA',
    v_actor.perfil_id, clock_timestamp(),
    v_actor.perfil_id, v_actor.perfil_id
  )
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.revocar_cobertura_empleado(
  p_cobertura uuid,
  p_motivo text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_cobertura public.nomina_coberturas%rowtype;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  select * into v_cobertura
  from public.nomina_coberturas cobertura
  where cobertura.empresa_id = v_actor.empresa_id
    and cobertura.id = p_cobertura
  for update;
  if not found
     or v_cobertura.tipo not in ('LICENCIA', 'VACACIONES')
     or not public.puede_operar_empleado_en_alcance(
       v_cobertura.empleado_id, 'recursos_humanos.acceder'
     )
  then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500 then
    raise exception using errcode = '22023', message = 'MOTIVO_REQUERIDO';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  update public.nomina_coberturas cobertura
  set estado = 'REVOCADA',
      revision = cobertura.revision + 1,
      updated_by = v_actor.perfil_id,
      updated_at = clock_timestamp()
  where cobertura.empresa_id = v_actor.empresa_id
    and cobertura.id = p_cobertura
    and cobertura.estado = 'APROBADA';
end;
$$;

create or replace function public.listar_coberturas_empleado(
  p_empleado uuid,
  p_tipo text
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_tipo text := upper(btrim(coalesce(p_tipo, '')));
  v_result jsonb;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if v_tipo not in ('LICENCIA', 'VACACIONES') then
    raise exception using errcode = '22023', message = 'COBERTURA_TIPO_INVALIDO';
  end if;
  if not public.puede_operar_empleado_en_alcance(
    p_empleado, 'recursos_humanos.acceder'
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;

  select coalesce(jsonb_agg(
    to_jsonb(cobertura) - 'empresa_id' - 'created_by' - 'updated_by'
    order by cobertura.fecha_desde desc
  ), '[]'::jsonb)
  into v_result
  from public.nomina_coberturas cobertura
  where cobertura.empresa_id = v_actor.empresa_id
    and cobertura.empleado_id = p_empleado
    and cobertura.tipo = v_tipo;

  return v_result;
end;
$$;

create or replace function public.registrar_festivo_empresa(
  p_fecha date,
  p_descripcion text,
  p_motivo text
) returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_id uuid;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not public.tiene_permiso_en_alcance(
    'nomina.festivos', array['empresa', 'global']
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if p_fecha is null
     or char_length(btrim(coalesce(p_descripcion, ''))) not between 3 and 300
     or char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500
  then
    raise exception using errcode = '22023', message = 'FESTIVO_INVALIDO';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  insert into public.nomina_festivos(
    empresa_id, fecha, descripcion, created_by, updated_by
  ) values (
    v_actor.empresa_id, p_fecha, btrim(p_descripcion),
    v_actor.perfil_id, v_actor.perfil_id
  )
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.actualizar_festivo_empresa(
  p_festivo uuid,
  p_descripcion text,
  p_activo boolean,
  p_motivo text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor record;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not public.tiene_permiso_en_alcance(
    'nomina.festivos', array['empresa', 'global']
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if char_length(btrim(coalesce(p_descripcion, ''))) not between 3 and 300
     or char_length(btrim(coalesce(p_motivo, ''))) not between 3 and 500
  then
    raise exception using errcode = '22023', message = 'FESTIVO_INVALIDO';
  end if;

  perform set_config('app.nomina_0042_motivo', btrim(p_motivo), true);
  update public.nomina_festivos festivo
  set descripcion = btrim(p_descripcion),
      activo = p_activo,
      revision = festivo.revision + 1,
      updated_by = v_actor.perfil_id,
      updated_at = clock_timestamp()
  where festivo.empresa_id = v_actor.empresa_id
    and festivo.id = p_festivo;
  if not found then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
end;
$$;

create or replace function public.listar_festivos_empresa(
  p_desde date,
  p_hasta date
) returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor record;
  v_result jsonb;
begin
  select * into v_actor from private.actor_nomina_calendario_0042();
  if not found then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not public.tiene_permiso_en_alcance(
    'nomina.festivos', array['empresa', 'global']
  ) then
    raise exception using
      errcode = '42501', message = 'ALCANCE_O_PERMISO_DENEGADO';
  end if;
  if p_desde is not null and p_hasta is not null and p_desde > p_hasta then
    raise exception using errcode = '22023', message = 'RANGO_FECHAS_INVALIDO';
  end if;

  select coalesce(jsonb_agg(
    to_jsonb(festivo) - 'empresa_id' - 'created_by' - 'updated_by'
    order by festivo.fecha
  ), '[]'::jsonb)
  into v_result
  from public.nomina_festivos festivo
  where festivo.empresa_id = v_actor.empresa_id
    and (p_desde is null or festivo.fecha >= p_desde)
    and (p_hasta is null or festivo.fecha <= p_hasta);

  return v_result;
end;
$$;


revoke all on
  public.nomina_plantillas_horario,
  public.nomina_plantilla_horario_versiones,
  public.nomina_plantilla_horario_dias,
  public.nomina_asignaciones_horario,
  public.nomina_condiciones_salariales,
  public.nomina_dias_libres,
  public.nomina_dia_libre_dias,
  public.nomina_coberturas,
  public.nomina_festivos,
  public.nomina_calendario_auditoria
from public, anon, authenticated, service_role;

grant select on
  public.nomina_plantillas_horario,
  public.nomina_plantilla_horario_versiones,
  public.nomina_plantilla_horario_dias,
  public.nomina_asignaciones_horario,
  public.nomina_condiciones_salariales,
  public.nomina_dias_libres,
  public.nomina_dia_libre_dias,
  public.nomina_coberturas,
  public.nomina_festivos,
  public.nomina_calendario_auditoria
to authenticated;

revoke all on function private.actor_nomina_calendario_0042()
  from public, anon, authenticated, service_role;
revoke all on function private.permiso_efectivo_nomina_0042(text)
  from public, anon, authenticated, service_role;
revoke all on function private.proteger_historial_nomina_0042()
  from public, anon, authenticated, service_role;
revoke all on function private.validar_revision_nomina_0042()
  from public, anon, authenticated, service_role;
revoke all on function private.auditar_nomina_calendario_0042()
  from public, anon, authenticated, service_role;
revoke all on function private.insertar_version_plantilla_horario_0042(
  uuid, uuid, text, jsonb, uuid, text
) from public, anon, authenticated, service_role;

revoke all on function public.tiene_permiso_en_alcance(text, text[])
  from public, anon, authenticated, service_role;
revoke all on function public.puede_operar_empleado_en_alcance(uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.guardar_plantilla_horario(text, text, jsonb, text)
  from public, anon, authenticated, service_role;
revoke all on function public.revisar_plantilla_horario(
  uuid, text, jsonb, text
) from public, anon, authenticated, service_role;
revoke all on function public.cambiar_estado_plantilla_horario(
  uuid, boolean, text
) from public, anon, authenticated, service_role;
revoke all on function public.listar_plantillas_horario()
  from public, anon, authenticated, service_role;
revoke all on function public.asignar_plantilla_horario(
  uuid, uuid, date, date, text
) from public, anon, authenticated, service_role;
revoke all on function public.cerrar_asignacion_horario(uuid, date, text)
  from public, anon, authenticated, service_role;
revoke all on function public.listar_asignaciones_horario_empleado(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.guardar_condicion_salarial(
  uuid, numeric, numeric, date, date, text
) from public, anon, authenticated, service_role;
revoke all on function public.cerrar_condicion_salarial(uuid, date, text)
  from public, anon, authenticated, service_role;
revoke all on function public.listar_condiciones_salariales_empleado(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.asignar_dias_libres_semanales(
  uuid, date, date, smallint[], text, text
) from public, anon, authenticated, service_role;
revoke all on function public.cerrar_dias_libres_semanales(uuid, date, text)
  from public, anon, authenticated, service_role;
revoke all on function public.listar_dias_libres_empleado(uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.registrar_cobertura_empleado(
  uuid, text, date, date, numeric, text, text
) from public, anon, authenticated, service_role;
revoke all on function public.revocar_cobertura_empleado(uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.listar_coberturas_empleado(uuid, text)
  from public, anon, authenticated, service_role;
revoke all on function public.registrar_festivo_empresa(date, text, text)
  from public, anon, authenticated, service_role;
revoke all on function public.actualizar_festivo_empresa(
  uuid, text, boolean, text
) from public, anon, authenticated, service_role;
revoke all on function public.listar_festivos_empresa(date, date)
  from public, anon, authenticated, service_role;

grant execute on function public.tiene_permiso_en_alcance(text, text[])
  to authenticated;
grant execute on function public.puede_operar_empleado_en_alcance(uuid, text)
  to authenticated;
grant execute on function public.guardar_plantilla_horario(
  text, text, jsonb, text
) to authenticated;
grant execute on function public.revisar_plantilla_horario(
  uuid, text, jsonb, text
) to authenticated;
grant execute on function public.cambiar_estado_plantilla_horario(
  uuid, boolean, text
) to authenticated;
grant execute on function public.listar_plantillas_horario()
  to authenticated;
grant execute on function public.asignar_plantilla_horario(
  uuid, uuid, date, date, text
) to authenticated;
grant execute on function public.cerrar_asignacion_horario(uuid, date, text)
  to authenticated;
grant execute on function public.listar_asignaciones_horario_empleado(uuid)
  to authenticated;
grant execute on function public.guardar_condicion_salarial(
  uuid, numeric, numeric, date, date, text
) to authenticated;
grant execute on function public.cerrar_condicion_salarial(uuid, date, text)
  to authenticated;
grant execute on function public.listar_condiciones_salariales_empleado(uuid)
  to authenticated;
grant execute on function public.asignar_dias_libres_semanales(
  uuid, date, date, smallint[], text, text
) to authenticated;
grant execute on function public.cerrar_dias_libres_semanales(
  uuid, date, text
) to authenticated;
grant execute on function public.listar_dias_libres_empleado(uuid)
  to authenticated;
grant execute on function public.registrar_cobertura_empleado(
  uuid, text, date, date, numeric, text, text
) to authenticated;
grant execute on function public.revocar_cobertura_empleado(uuid, text)
  to authenticated;
grant execute on function public.listar_coberturas_empleado(uuid, text)
  to authenticated;
grant execute on function public.registrar_festivo_empresa(date, text, text)
  to authenticated;
grant execute on function public.actualizar_festivo_empresa(
  uuid, text, boolean, text
) to authenticated;
grant execute on function public.listar_festivos_empresa(date, date)
  to authenticated;

comment on table public.nomina_plantillas_horario is
  'Cabeceras reutilizables de horarios del nuevo modelo salarial.';
comment on table public.nomina_plantilla_horario_versiones is
  'Versiones inmutables de cada plantilla; 0043 resolverá la versión asignada.';
comment on table public.nomina_plantilla_horario_dias is
  'Detalle L-D: minutos_normales es la única verdad económica; cero significa día no programado.';
comment on table public.nomina_asignaciones_horario is
  'Historial inclusivo y sin solapes de versiones de horario por empleado.';
comment on table public.nomina_condiciones_salariales is
  'Sueldo mensual y valor manual de hora extra vigentes, sin cálculo en 0042.';
comment on table public.nomina_dias_libres is
  'Cabeceras históricas sin solape de configuraciones semanales de días libres.';
comment on table public.nomina_dia_libre_dias is
  'Detalle inmutable ISO 1..7; permite uno o varios días libres por semana.';
comment on table public.nomina_coberturas is
  'Licencias y vacaciones inclusivas, aprobadas y auditables.';
comment on table public.nomina_festivos is
  'Festivos persistentes por empresa; no contiene cálculo ni devengo.';
comment on table public.nomina_calendario_auditoria is
  'Historial append-only de toda configuración salarial y de calendario 0042.';
comment on function public.puede_operar_empleado_en_alcance(uuid, text) is
  'Combina permiso efectivo y alcance; SUPERVISOR exige departamento explícito 0033.';

commit;
