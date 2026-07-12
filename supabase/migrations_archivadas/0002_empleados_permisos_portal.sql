-- CONTROLHORARIO / OSINET Time ERP Enterprise
-- Empleados, acceso al portal y autorización granular.
-- Requiere 0001_initial_schema.sql. Compatible con Supabase PostgreSQL 17.

begin;

-- UUID del tenant del usuario autenticado. Nunca acepta un tenant enviado por cliente.
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
  limit 1
$$;

-- UUID del rol activo del usuario autenticado.
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
    and r.is_active
  limit 1
$$;

comment on function public.obtener_empresa_actual() is
  'Obtiene el tenant del perfil autenticado activo; no recibe empresa_id del cliente.';
comment on function public.obtener_rol_actual() is
  'Obtiene el rol activo del perfil autenticado.';

revoke all on function public.obtener_empresa_actual() from public;
revoke all on function public.obtener_rol_actual() from public;
grant execute on function public.obtener_empresa_actual() to authenticated;
grant execute on function public.obtener_rol_actual() to authenticated;

-- Perfil debe poder participar en relaciones compuestas que validan el tenant.
alter table public.profiles
  add constraint profiles_company_id_id_unique unique (company_id, id);

-- Información laboral. La identidad Auth y el perfil de acceso permanecen separados.
create table public.empleados (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null default public.obtener_empresa_actual()
    references public.companies(id) on delete restrict,
  perfil_id uuid unique,
  sucursal_id uuid references public.branches(id) on delete restrict,
  departamento_id uuid references public.departments(id) on delete restrict,
  puesto_id uuid references public.positions(id) on delete restrict,
  codigo_empleado text not null,
  nombre_completo text not null,
  cedula text,
  correo text,
  telefono text,
  foto_url text,
  pin_hash text,
  fecha_ingreso date,
  estado_laboral text not null default 'activo',
  salario numeric(14,2),
  tipo_pago text,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint empleados_codigo_formato check (codigo_empleado ~ '^[0-9]{5,12}$'),
  constraint empleados_nombre_longitud check (char_length(btrim(nombre_completo)) between 2 and 160),
  constraint empleados_cedula_longitud check (cedula is null or char_length(btrim(cedula)) between 5 and 30),
  constraint empleados_correo_normalizado check (correo is null or correo = lower(btrim(correo))),
  constraint empleados_correo_formato check (correo is null or correo ~ '^[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}$'),
  constraint empleados_telefono_longitud check (telefono is null or char_length(btrim(telefono)) between 7 and 30),
  constraint empleados_foto_url_longitud check (foto_url is null or char_length(foto_url) <= 2048),
  constraint empleados_pin_hash_formato check (
    pin_hash is null
    or pin_hash ~ '^\$(2[aby]\$|argon2(id|i|d)\$)'
  ),
  constraint empleados_fecha_ingreso_valida check (fecha_ingreso is null or fecha_ingreso >= date '1900-01-01'),
  constraint empleados_estado_laboral_check check (
    estado_laboral in ('pendiente', 'activo', 'licencia', 'suspendido', 'desvinculado')
  ),
  constraint empleados_salario_valido check (salario is null or salario >= 0),
  constraint empleados_tipo_pago_check check (
    tipo_pago is null or tipo_pago in ('semanal', 'quincenal', 'mensual', 'por_hora')
  ),
  constraint empleados_empresa_codigo_unique unique (empresa_id, codigo_empleado),
  constraint empleados_empresa_id_id_unique unique (empresa_id, id)
);

comment on table public.empleados is
  'Información laboral del empleado, separada de auth.users y profiles. Puede existir sin acceso al portal.';
comment on column public.empleados.perfil_id is
  'Perfil opcional y único. Se enlaza solo mediante un flujo administrativo confiable.';
comment on column public.empleados.pin_hash is
  'Hash bcrypt o Argon2 del PIN; nunca debe almacenar el PIN en texto plano.';
comment on column public.empleados.salario is
  'Dato sensible sin permiso de escritura directa para authenticated.';

-- Unicidad parcial: varios NULL son válidos, valores presentes son únicos por empresa.
create unique index empleados_empresa_cedula_uidx
  on public.empleados (empresa_id, cedula)
  where cedula is not null;
create unique index empleados_empresa_correo_uidx
  on public.empleados (empresa_id, correo)
  where correo is not null;

-- Relaciones compuestas bloquean referencias organizativas de otra empresa.
alter table public.empleados
  add constraint empleados_perfil_misma_empresa_fk
    foreign key (empresa_id, perfil_id)
    references public.profiles(company_id, id)
    on delete set null (perfil_id),
  add constraint empleados_sucursal_misma_empresa_fk
    foreign key (empresa_id, sucursal_id)
    references public.branches(company_id, id)
    on delete restrict,
  add constraint empleados_departamento_misma_empresa_fk
    foreign key (empresa_id, departamento_id)
    references public.departments(company_id, id)
    on delete restrict,
  add constraint empleados_puesto_misma_empresa_fk
    foreign key (empresa_id, puesto_id)
    references public.positions(company_id, id)
    on delete restrict;

create index empleados_empresa_activo_idx on public.empleados (empresa_id, activo);
create index empleados_empresa_departamento_idx on public.empleados (empresa_id, departamento_id);
create index empleados_sucursal_idx on public.empleados (sucursal_id) where sucursal_id is not null;
create index empleados_perfil_idx on public.empleados (perfil_id) where perfil_id is not null;
create index empleados_puesto_idx on public.empleados (puesto_id) where puesto_id is not null;

-- Normalización centralizada antes de comprobar restricciones de correo y textos.
create or replace function public.normalizar_empleado()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.codigo_empleado = btrim(new.codigo_empleado);
  new.nombre_completo = btrim(new.nombre_completo);
  new.cedula = nullif(btrim(new.cedula), '');
  new.correo = nullif(lower(btrim(new.correo)), '');
  new.telefono = nullif(btrim(new.telefono), '');
  new.foto_url = nullif(btrim(new.foto_url), '');
  new.tipo_pago = nullif(lower(btrim(new.tipo_pago)), '');
  return new;
end;
$$;

revoke all on function public.normalizar_empleado() from public;

create trigger empleados_normalizar_before_write
  before insert or update on public.empleados
  for each row execute function public.normalizar_empleado();

create trigger empleados_set_updated_at
  before update on public.empleados
  for each row execute function public.set_updated_at();

-- Catálogo global e inmutable desde clientes. Los códigos se versionan en migraciones/seed.
create table public.permisos (
  id uuid primary key default extensions.gen_random_uuid(),
  codigo text not null unique,
  nombre text not null,
  descripcion text,
  modulo text not null,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint permisos_codigo_formato check (codigo ~ '^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$'),
  constraint permisos_nombre_longitud check (char_length(btrim(nombre)) between 2 and 120),
  constraint permisos_descripcion_longitud check (descripcion is null or char_length(descripcion) <= 500),
  constraint permisos_modulo_formato check (modulo ~ '^[a-z][a-z0-9_]{1,49}$')
);

comment on table public.permisos is
  'Catálogo global de capacidades. Ausencia de asignación significa denegación.';

create table public.rol_permisos (
  rol_id uuid not null references public.roles(id) on delete cascade,
  permiso_id uuid not null references public.permisos(id) on delete cascade,
  permitido boolean not null default true,
  alcance text not null default 'propio',
  created_at timestamptz not null default now(),
  constraint rol_permisos_alcance_check check (alcance in ('propio', 'departamento', 'sucursal', 'empresa', 'global')),
  primary key (rol_id, permiso_id)
);

comment on table public.rol_permisos is
  'Asignación base de permisos a un rol. Puede conceder o denegar explícitamente.';

create table public.perfil_permisos (
  perfil_id uuid not null references public.profiles(id) on delete cascade,
  permiso_id uuid not null references public.permisos(id) on delete cascade,
  permitido boolean not null,
  alcance text not null default 'propio',
  created_at timestamptz not null default now(),
  constraint perfil_permisos_alcance_check check (alcance in ('propio', 'departamento', 'sucursal', 'empresa', 'global')),
  primary key (perfil_id, permiso_id)
);

comment on table public.perfil_permisos is
  'Excepciones individuales. Siempre tienen prioridad sobre la asignación del rol.';

create table public.perfil_sucursales (
  perfil_id uuid not null references public.profiles(id) on delete cascade,
  sucursal_id uuid not null references public.branches(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (perfil_id, sucursal_id)
);

create table public.perfil_departamentos (
  perfil_id uuid not null references public.profiles(id) on delete cascade,
  departamento_id uuid not null references public.departments(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (perfil_id, departamento_id)
);

comment on table public.perfil_sucursales is
  'Sucursales adicionales incluidas en el alcance efectivo de un perfil.';
comment on table public.perfil_departamentos is
  'Departamentos adicionales incluidos en el alcance efectivo de un perfil.';

create index permisos_modulo_activo_idx on public.permisos (modulo, activo);
create index rol_permisos_permiso_idx on public.rol_permisos (permiso_id);
create index perfil_permisos_permiso_idx on public.perfil_permisos (permiso_id);
create index perfil_sucursales_sucursal_idx on public.perfil_sucursales (sucursal_id);
create index perfil_departamentos_departamento_idx on public.perfil_departamentos (departamento_id);

create trigger permisos_set_updated_at
  before update on public.permisos
  for each row execute function public.set_updated_at();

-- Resolución efectiva: perfil > rol > denegación.
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
        on pe.codigo = codigo_permiso
       and pe.activo
      join public.perfil_permisos as pp
        on pp.perfil_id = p.id
       and pp.permiso_id = pe.id
      where p.id = (select auth.uid())
        and p.status = 'active'
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
        on pe.codigo = codigo_permiso
       and pe.activo
      join public.rol_permisos as rp
        on rp.rol_id = r.id
       and rp.permiso_id = pe.id
      where p.id = (select auth.uid())
        and p.status = 'active'
      limit 1
    ),
    false
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
    on p.id = e.perfil_id
   and p.company_id = e.empresa_id
  where p.id = (select auth.uid())
    and p.status = 'active'
    and e.activo
  limit 1
$$;

create or replace function public.es_empleado_actual(empleado_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select empleado_id is not null
     and empleado_id = (select public.obtener_empleado_actual_id())
$$;

comment on function public.tiene_permiso(text) is
  'Resuelve permiso efectivo: excepción de perfil, luego rol, luego false.';
comment on function public.obtener_empleado_actual_id() is
  'Obtiene el empleado activo enlazado al perfil autenticado.';
comment on function public.es_empleado_actual(uuid) is
  'Indica si el empleado dado pertenece al usuario autenticado.';

revoke all on function public.tiene_permiso(text) from public;
revoke all on function public.obtener_empleado_actual_id() from public;
revoke all on function public.es_empleado_actual(uuid) from public;
grant execute on function public.tiene_permiso(text) to authenticated;
grant execute on function public.obtener_empleado_actual_id() to authenticated;
grant execute on function public.es_empleado_actual(uuid) to authenticated;

-- Privilegios SQL mínimos. Las columnas sensibles no son editables desde authenticated.
revoke all on public.empleados, public.permisos,
  public.rol_permisos, public.perfil_permisos,
  public.perfil_sucursales, public.perfil_departamentos from anon;
grant select on public.empleados, public.permisos,
  public.rol_permisos, public.perfil_permisos,
  public.perfil_sucursales, public.perfil_departamentos to authenticated;
grant insert (
  codigo_empleado, nombre_completo, cedula, correo, telefono, foto_url,
  sucursal_id, departamento_id, puesto_id, fecha_ingreso,
  estado_laboral, tipo_pago, activo
) on public.empleados to authenticated;
grant update (
  codigo_empleado, nombre_completo, cedula, correo, telefono, foto_url,
  sucursal_id, departamento_id, puesto_id, fecha_ingreso,
  estado_laboral, tipo_pago, activo
) on public.empleados to authenticated;
grant insert, update, delete on public.rol_permisos, public.perfil_permisos,
  public.perfil_sucursales, public.perfil_departamentos to authenticated;

alter table public.empleados enable row level security;
alter table public.permisos enable row level security;
alter table public.rol_permisos enable row level security;
alter table public.perfil_permisos enable row level security;
alter table public.perfil_sucursales enable row level security;
alter table public.perfil_departamentos enable row level security;

-- Empleado: propio, departamento autorizado o alcance total; siempre dentro del tenant.
create policy empleados_select_segun_alcance on public.empleados
  for select to authenticated
  using (
    empresa_id = (select public.obtener_empresa_actual())
    and (
      (
        (select public.es_empleado_actual(id))
        and (select public.tiene_permiso('empleados.ver_propio'))
      )
      or (select public.tiene_permiso('empleados.ver_todos'))
      or (
        (select public.tiene_permiso('empleados.ver_departamento'))
        and departamento_id is not null
        and departamento_id = (
          select p.department_id
          from public.profiles as p
          where p.id = (select auth.uid())
        )
      )
    )
  );

create policy empleados_insert_autorizado on public.empleados
  for insert to authenticated
  with check (
    empresa_id = (select public.obtener_empresa_actual())
    and perfil_id is null
    and salario is null
    and pin_hash is null
    and (select public.tiene_permiso('empleados.crear'))
  );

create policy empleados_update_autorizado on public.empleados
  for update to authenticated
  using (
    empresa_id = (select public.obtener_empresa_actual())
    and (select public.tiene_permiso('empleados.editar'))
  )
  with check (
    empresa_id = (select public.obtener_empresa_actual())
    and (select public.tiene_permiso('empleados.editar'))
    and (
      (activo and estado_laboral <> 'desvinculado')
      or (select public.tiene_permiso('empleados.desactivar'))
    )
  );

-- Solo se muestran permisos relacionados con el perfil o rol actual.
create policy permisos_select_necesarios on public.permisos
  for select to authenticated
  using (
    activo
    and (
      exists (
        select 1 from public.rol_permisos as rp
        where rp.permiso_id = permisos.id
          and rp.rol_id = (select public.obtener_rol_actual())
      )
      or exists (
        select 1 from public.perfil_permisos as pp
        where pp.permiso_id = permisos.id
          and pp.perfil_id = (select auth.uid())
      )
      or (select public.tiene_permiso('permisos.administrar'))
    )
  );

create policy rol_permisos_select_rol_actual on public.rol_permisos
  for select to authenticated
  using (rol_id = (select public.obtener_rol_actual()));

create policy rol_permisos_select_admin on public.rol_permisos
  for select to authenticated
  using (
    exists (
      select 1 from public.roles as r
      where r.id = rol_id
        and r.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  );

create policy perfil_permisos_select_propios on public.perfil_permisos
  for select to authenticated
  using (perfil_id = (select auth.uid()));

create policy perfil_permisos_select_admin on public.perfil_permisos
  for select to authenticated
  using (
    exists (
      select 1 from public.profiles as p
      where p.id = perfil_id
        and p.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  );

-- Administradores con permiso explícito gestionan asignaciones de otros roles/perfiles.
create policy rol_permisos_insert_admin on public.rol_permisos
  for insert to authenticated
  with check (
    rol_id <> (select public.obtener_rol_actual())
    and exists (
      select 1 from public.roles as r
      where r.id = rol_id
        and r.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  );

create policy rol_permisos_update_admin on public.rol_permisos
  for update to authenticated
  using (
    rol_id <> (select public.obtener_rol_actual())
    and exists (
      select 1 from public.roles as r
      where r.id = rol_id
        and r.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  )
  with check (
    rol_id <> (select public.obtener_rol_actual())
    and exists (
      select 1 from public.roles as r
      where r.id = rol_id
        and r.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  );

create policy rol_permisos_delete_admin on public.rol_permisos
  for delete to authenticated
  using (
    rol_id <> (select public.obtener_rol_actual())
    and exists (
      select 1 from public.roles as r
      where r.id = rol_id
        and r.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  );

create policy perfil_permisos_insert_admin on public.perfil_permisos
  for insert to authenticated
  with check (
    perfil_id <> (select auth.uid())
    and exists (
      select 1 from public.profiles as p
      where p.id = perfil_id
        and p.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  );

create policy perfil_permisos_update_admin on public.perfil_permisos
  for update to authenticated
  using (
    perfil_id <> (select auth.uid())
    and exists (
      select 1 from public.profiles as p
      where p.id = perfil_id
        and p.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  )
  with check (
    perfil_id <> (select auth.uid())
    and exists (
      select 1 from public.profiles as p
      where p.id = perfil_id
        and p.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  );

create policy perfil_permisos_delete_admin on public.perfil_permisos
  for delete to authenticated
  using (
    perfil_id <> (select auth.uid())
    and exists (
      select 1 from public.profiles as p
      where p.id = perfil_id
        and p.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  );

-- El perfil ve sus alcances; administración puede gestionar alcances del mismo tenant.
create policy perfil_sucursales_select on public.perfil_sucursales
  for select to authenticated
  using (
    perfil_id = (select auth.uid())
    or (
      exists (
        select 1 from public.profiles as p
        where p.id = perfil_id
          and p.company_id = (select public.obtener_empresa_actual())
      )
      and (select public.tiene_permiso('permisos.administrar'))
    )
  );

create policy perfil_sucursales_manage on public.perfil_sucursales
  for all to authenticated
  using (
    perfil_id <> (select auth.uid())
    and exists (
      select 1
      from public.profiles as p
      join public.branches as b on b.id = sucursal_id and b.company_id = p.company_id
      where p.id = perfil_id
        and p.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  )
  with check (
    perfil_id <> (select auth.uid())
    and exists (
      select 1
      from public.profiles as p
      join public.branches as b on b.id = sucursal_id and b.company_id = p.company_id
      where p.id = perfil_id
        and p.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  );

create policy perfil_departamentos_select on public.perfil_departamentos
  for select to authenticated
  using (
    perfil_id = (select auth.uid())
    or (
      exists (
        select 1 from public.profiles as p
        where p.id = perfil_id
          and p.company_id = (select public.obtener_empresa_actual())
      )
      and (select public.tiene_permiso('permisos.administrar'))
    )
  );

create policy perfil_departamentos_manage on public.perfil_departamentos
  for all to authenticated
  using (
    perfil_id <> (select auth.uid())
    and exists (
      select 1
      from public.profiles as p
      join public.departments as d on d.id = departamento_id and d.company_id = p.company_id
      where p.id = perfil_id
        and p.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  )
  with check (
    perfil_id <> (select auth.uid())
    and exists (
      select 1
      from public.profiles as p
      join public.departments as d on d.id = departamento_id and d.company_id = p.company_id
      where p.id = perfil_id
        and p.company_id = (select public.obtener_empresa_actual())
    )
    and (select public.tiene_permiso('permisos.administrar'))
  );

-- Reemplaza las políticas de profiles de 0001 por autorización granular.
drop policy profiles_select_own_company on public.profiles;
drop policy profiles_insert_by_admin on public.profiles;
drop policy profiles_update_by_admin on public.profiles;
drop policy profiles_delete_by_admin on public.profiles;

create policy profiles_select_granular on public.profiles
  for select to authenticated
  using (
    id = (select auth.uid())
    or (
      company_id = (select public.obtener_empresa_actual())
      and (select public.tiene_permiso('usuarios.administrar'))
    )
  );

create policy profiles_insert_granular on public.profiles
  for insert to authenticated
  with check (
    company_id = (select public.obtener_empresa_actual())
    and (select public.tiene_permiso('usuarios.administrar'))
  );

create policy profiles_update_granular on public.profiles
  for update to authenticated
  using (
    company_id = (select public.obtener_empresa_actual())
    and (select public.tiene_permiso('usuarios.administrar'))
  )
  with check (
    company_id = (select public.obtener_empresa_actual())
    and (select public.tiene_permiso('usuarios.administrar'))
  );

create policy profiles_delete_granular on public.profiles
  for delete to authenticated
  using (
    company_id = (select public.obtener_empresa_actual())
    and id <> (select auth.uid())
    and (select public.tiene_permiso('usuarios.administrar'))
  );

commit;
