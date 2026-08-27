-- CONTROLHORARIO / OSINET Time ERP Enterprise
-- Migración inicial para Supabase PostgreSQL 17.
-- Esta migración está diseñada para aplicarse mediante Supabase CLI, no manualmente.

begin;

-- gen_random_uuid() y utilidades criptográficas soportadas por Supabase.
create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
comment on schema private is
  'Funciones internas de autorización. No debe exponerse mediante la Data API.';

-- Mantiene updated_at en la hora de la última modificación de cada fila.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at = statement_timestamp();
  return new;
end;
$$;

comment on function public.set_updated_at() is
  'Trigger genérico que actualiza updated_at antes de cada UPDATE.';

revoke all on function public.set_updated_at() from public;

-- Empresa o tenant propietario de todos los datos operativos.
create table public.companies (
  id uuid primary key default extensions.gen_random_uuid(),
  name text not null,
  legal_name text,
  slug text not null,
  tax_id text,
  timezone text not null default 'America/Santo_Domingo',
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint companies_name_length check (char_length(btrim(name)) between 2 and 160),
  constraint companies_legal_name_length check (legal_name is null or char_length(btrim(legal_name)) between 2 and 200),
  constraint companies_slug_format check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  constraint companies_tax_id_length check (tax_id is null or char_length(btrim(tax_id)) between 5 and 30),
  constraint companies_timezone_not_blank check (char_length(btrim(timezone)) > 0),
  constraint companies_status_check check (status in ('active', 'inactive', 'suspended'))
);

comment on table public.companies is
  'Tenants de CONTROLHORARIO. Cada empresa mantiene aislados sus usuarios y catálogos.';
comment on column public.companies.slug is
  'Identificador URL único, estable y en minúsculas.';

-- Roles de autorización configurables por empresa.
create table public.roles (
  id uuid primary key default extensions.gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  code text not null,
  description text,
  is_system boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint roles_name_length check (char_length(btrim(name)) between 2 and 80),
  constraint roles_code_format check (code ~ '^[a-z][a-z0-9_]{1,49}$'),
  constraint roles_description_length check (description is null or char_length(description) <= 500),
  constraint roles_company_code_unique unique (company_id, code),
  constraint roles_company_name_unique unique (company_id, name)
);

comment on table public.roles is
  'Roles de acceso por empresa. El código se usa en políticas y el nombre es descriptivo.';

-- Sucursales físicas o unidades operativas de una empresa.
create table public.branches (
  id uuid primary key default extensions.gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  name text not null,
  code text not null,
  address text,
  phone text,
  email text,
  is_main boolean not null default false,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint branches_name_length check (char_length(btrim(name)) between 2 and 120),
  constraint branches_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,19}$'),
  constraint branches_phone_length check (phone is null or char_length(btrim(phone)) between 7 and 30),
  constraint branches_email_format check (email is null or email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
  constraint branches_status_check check (status in ('active', 'inactive')),
  constraint branches_company_code_unique unique (company_id, code),
  constraint branches_company_name_unique unique (company_id, name)
);

comment on table public.branches is
  'Sucursales de cada empresa. Solo una sucursal puede marcarse como principal por tenant.';

-- Áreas organizativas, opcionalmente asociadas a una sucursal concreta.
create table public.departments (
  id uuid primary key default extensions.gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  branch_id uuid references public.branches(id) on delete restrict,
  name text not null,
  code text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint departments_name_length check (char_length(btrim(name)) between 2 and 120),
  constraint departments_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,19}$'),
  constraint departments_description_length check (description is null or char_length(description) <= 500),
  constraint departments_company_code_unique unique (company_id, code),
  constraint departments_company_name_unique unique (company_id, name),
  constraint departments_company_branch_unique unique (company_id, branch_id, id)
);

comment on table public.departments is
  'Departamentos de una empresa; pueden ser corporativos o pertenecer a una sucursal.';

-- Cargos laborales. Pueden ser generales o estar ligados a un departamento.
create table public.positions (
  id uuid primary key default extensions.gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  department_id uuid references public.departments(id) on delete restrict,
  name text not null,
  code text not null,
  description text,
  level smallint not null default 1,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint positions_name_length check (char_length(btrim(name)) between 2 and 120),
  constraint positions_code_format check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,19}$'),
  constraint positions_description_length check (description is null or char_length(description) <= 500),
  constraint positions_level_check check (level between 1 and 20),
  constraint positions_company_code_unique unique (company_id, code),
  constraint positions_company_name_unique unique (company_id, name),
  constraint positions_company_department_unique unique (company_id, department_id, id)
);

comment on table public.positions is
  'Catálogo de cargos laborales por empresa, separado de los roles de autorización.';

-- Perfil empresarial de cada identidad gestionada por Supabase Auth.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete restrict,
  role_id uuid not null references public.roles(id) on delete restrict,
  branch_id uuid references public.branches(id) on delete restrict,
  department_id uuid references public.departments(id) on delete restrict,
  position_id uuid references public.positions(id) on delete restrict,
  employee_code text,
  full_name text not null,
  phone text,
  avatar_url text,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profiles_full_name_length check (char_length(btrim(full_name)) between 2 and 160),
  constraint profiles_employee_code_format check (employee_code is null or employee_code ~ '^[0-9]{5,12}$'),
  constraint profiles_phone_length check (phone is null or char_length(btrim(phone)) between 7 and 30),
  constraint profiles_avatar_url_length check (avatar_url is null or char_length(avatar_url) <= 2048),
  constraint profiles_status_check check (status in ('invited', 'active', 'inactive', 'suspended')),
  constraint profiles_company_employee_code_unique unique (company_id, employee_code),
  constraint profiles_company_role_unique unique (company_id, role_id, id),
  constraint profiles_company_branch_unique unique (company_id, branch_id, id),
  constraint profiles_company_department_unique unique (company_id, department_id, id),
  constraint profiles_company_position_unique unique (company_id, position_id, id)
);

comment on table public.profiles is
  'Perfil de negocio vinculado 1:1 con auth.users. Define tenant, rol y asignación organizativa.';
comment on column public.profiles.id is
  'Mismo UUID de auth.users.id; nunca contiene contraseñas ni tokens.';

-- Las referencias compuestas necesitan unicidad sobre (company_id, id).
alter table public.roles add constraint roles_company_id_id_unique unique (company_id, id);
alter table public.branches add constraint branches_company_id_id_unique unique (company_id, id);
alter table public.departments add constraint departments_company_id_id_unique unique (company_id, id);
alter table public.positions add constraint positions_company_id_id_unique unique (company_id, id);

-- Impide relaciones cruzadas entre empresas usando claves foráneas compuestas.
alter table public.departments
  add constraint departments_branch_same_company_fk
  foreign key (company_id, branch_id)
  references public.branches(company_id, id)
  on delete restrict;

alter table public.positions
  add constraint positions_department_same_company_fk
  foreign key (company_id, department_id)
  references public.departments(company_id, id)
  on delete restrict;

alter table public.profiles
  add constraint profiles_role_same_company_fk
  foreign key (company_id, role_id)
  references public.roles(company_id, id)
  on delete restrict,
  add constraint profiles_branch_same_company_fk
  foreign key (company_id, branch_id)
  references public.branches(company_id, id)
  on delete restrict,
  add constraint profiles_department_same_company_fk
  foreign key (company_id, department_id)
  references public.departments(company_id, id)
  on delete restrict,
  add constraint profiles_position_same_company_fk
  foreign key (company_id, position_id)
  references public.positions(company_id, id)
  on delete restrict;

-- Índices de tenant, relaciones y búsquedas habituales.
create unique index companies_slug_lower_uidx on public.companies (lower(slug));
create unique index companies_tax_id_uidx on public.companies (tax_id) where tax_id is not null;
create index roles_company_active_idx on public.roles (company_id, is_active);
create index branches_company_status_idx on public.branches (company_id, status);
create unique index branches_one_main_per_company_uidx on public.branches (company_id) where is_main;
create index departments_company_branch_idx on public.departments (company_id, branch_id);
create index departments_company_active_idx on public.departments (company_id, is_active);
create index positions_company_department_idx on public.positions (company_id, department_id);
create index positions_company_active_idx on public.positions (company_id, is_active);
create index profiles_company_idx on public.profiles (company_id);
create index profiles_role_idx on public.profiles (role_id);
create index profiles_branch_idx on public.profiles (branch_id) where branch_id is not null;
create index profiles_department_idx on public.profiles (department_id) where department_id is not null;
create index profiles_position_idx on public.profiles (position_id) where position_id is not null;
create index profiles_company_status_idx on public.profiles (company_id, status);

-- Triggers updated_at automáticos.
create trigger companies_set_updated_at before update on public.companies
  for each row execute function public.set_updated_at();
create trigger roles_set_updated_at before update on public.roles
  for each row execute function public.set_updated_at();
create trigger branches_set_updated_at before update on public.branches
  for each row execute function public.set_updated_at();
create trigger departments_set_updated_at before update on public.departments
  for each row execute function public.set_updated_at();
create trigger positions_set_updated_at before update on public.positions
  for each row execute function public.set_updated_at();
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();

-- Helpers de autorización. SECURITY DEFINER evita recursión RLS al consultar profiles.
create or replace function private.current_company_id()
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

create or replace function private.has_company_role(allowed_codes text[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.profiles as p
    join public.roles as r
      on r.id = p.role_id
     and r.company_id = p.company_id
    where p.id = (select auth.uid())
      and p.status = 'active'
      and r.is_active
      and r.code = any (allowed_codes)
  )
$$;

comment on function private.current_company_id() is
  'Devuelve el tenant del usuario autenticado activo para filtrar políticas RLS.';
comment on function private.has_company_role(text[]) is
  'Comprueba roles activos del usuario autenticado sin exponer tablas fuera de su tenant.';

revoke all on schema private from public;
revoke all on all functions in schema private from public;
grant usage on schema private to authenticated;
grant execute on function private.current_company_id() to authenticated;
grant execute on function private.has_company_role(text[]) to authenticated;

-- Acceso base: anon no recibe privilegios; authenticated depende además de RLS.
revoke all on public.companies, public.profiles, public.roles,
  public.branches, public.departments, public.positions from anon;
grant select on public.companies, public.profiles, public.roles,
  public.branches, public.departments, public.positions to authenticated;
grant insert, update, delete on public.profiles, public.roles,
  public.branches, public.departments, public.positions to authenticated;
grant update on public.companies to authenticated;

alter table public.companies enable row level security;
alter table public.profiles enable row level security;
alter table public.roles enable row level security;
alter table public.branches enable row level security;
alter table public.departments enable row level security;
alter table public.positions enable row level security;

-- Lectura: solamente filas de la empresa del usuario autenticado activo.
create policy companies_select_own_company on public.companies
  for select to authenticated
  using (id = (select private.current_company_id()));
create policy roles_select_own_company on public.roles
  for select to authenticated
  using (company_id = (select private.current_company_id()));
create policy branches_select_own_company on public.branches
  for select to authenticated
  using (company_id = (select private.current_company_id()));
create policy departments_select_own_company on public.departments
  for select to authenticated
  using (company_id = (select private.current_company_id()));
create policy positions_select_own_company on public.positions
  for select to authenticated
  using (company_id = (select private.current_company_id()));
create policy profiles_select_own_company on public.profiles
  for select to authenticated
  using (company_id = (select private.current_company_id()));

-- Administración: solo administradores activos pueden cambiar catálogos de su tenant.
create policy companies_update_by_admin on public.companies
  for update to authenticated
  using (
    id = (select private.current_company_id())
    and (select private.has_company_role(array['admin']))
  )
  with check (
    id = (select private.current_company_id())
    and (select private.has_company_role(array['admin']))
  );

create policy roles_manage_by_admin on public.roles
  for all to authenticated
  using (
    company_id = (select private.current_company_id())
    and (select private.has_company_role(array['admin']))
  )
  with check (
    company_id = (select private.current_company_id())
    and (select private.has_company_role(array['admin']))
  );

create policy branches_manage_by_admin on public.branches
  for all to authenticated
  using (
    company_id = (select private.current_company_id())
    and (select private.has_company_role(array['admin']))
  )
  with check (
    company_id = (select private.current_company_id())
    and (select private.has_company_role(array['admin']))
  );

create policy departments_manage_by_admin_or_hr on public.departments
  for all to authenticated
  using (
    company_id = (select private.current_company_id())
    and (select private.has_company_role(array['admin', 'hr']))
  )
  with check (
    company_id = (select private.current_company_id())
    and (select private.has_company_role(array['admin', 'hr']))
  );

create policy positions_manage_by_admin_or_hr on public.positions
  for all to authenticated
  using (
    company_id = (select private.current_company_id())
    and (select private.has_company_role(array['admin', 'hr']))
  )
  with check (
    company_id = (select private.current_company_id())
    and (select private.has_company_role(array['admin', 'hr']))
  );

create policy profiles_insert_by_admin on public.profiles
  for insert to authenticated
  with check (
    company_id = (select private.current_company_id())
    and (select private.has_company_role(array['admin']))
  );

create policy profiles_update_by_admin on public.profiles
  for update to authenticated
  using (
    company_id = (select private.current_company_id())
    and (select private.has_company_role(array['admin']))
  )
  with check (
    company_id = (select private.current_company_id())
    and (select private.has_company_role(array['admin']))
  );

create policy profiles_delete_by_admin on public.profiles
  for delete to authenticated
  using (
    company_id = (select private.current_company_id())
    and id <> (select auth.uid())
    and (select private.has_company_role(array['admin']))
  );

commit;
