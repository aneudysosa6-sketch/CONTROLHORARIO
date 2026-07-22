begin;

-- Evita que una escritura concurrente invalide el preflight entre la deteccion
-- de colisiones y la normalizacion de los datos historicos.
lock table public.empleados in share row exclusive mode;
lock table public.profiles in share row exclusive mode;
lock table public.face_first_enrollment_audit in share row exclusive mode;

do $$
declare
  v_invalid record;
  v_collision record;
begin
  select e.empresa_id, e.id, e.codigo_empleado
  into v_invalid
  from public.empleados as e
  where e.codigo_empleado !~ '^[0-9]{5,6}$'
     or pg_catalog.lpad(e.codigo_empleado, 6, '0') = '000000'
  order by e.empresa_id, e.codigo_empleado
  limit 1;
  if found then
    raise exception using
      errcode = '23514',
      message = pg_catalog.format(
        'EMPLOYEE_CODE_MIGRATION_INVALID:company=%s employee=%s code=%s',
        v_invalid.empresa_id, v_invalid.id, v_invalid.codigo_empleado
      );
  end if;

  select e.empresa_id,
         pg_catalog.lpad(e.codigo_empleado, 6, '0') as normalized_code,
         pg_catalog.array_agg(e.id order by e.id) as employee_ids
  into v_collision
  from public.empleados as e
  group by e.empresa_id, pg_catalog.lpad(e.codigo_empleado, 6, '0')
  having pg_catalog.count(*) > 1
  order by e.empresa_id, normalized_code
  limit 1;
  if found then
    raise exception using
      errcode = '23505',
      message = pg_catalog.format(
        'EMPLOYEE_CODE_MIGRATION_COLLISION:company=%s code=%s employees=%s',
        v_collision.empresa_id, v_collision.normalized_code, v_collision.employee_ids
      );
  end if;
end;
$$;

-- El codigo final de un perfil vinculado siempre procede del empleado. Para
-- perfiles sin empleado se conserva y normaliza su codigo historico.
do $$
declare
  v_invalid record;
  v_collision record;
begin
  with desired as (
    select p.id,
           p.company_id,
           coalesce(e.codigo_empleado, p.employee_code) as source_code
    from public.profiles as p
    left join public.empleados as e
      on e.empresa_id = p.company_id
     and e.perfil_id = p.id
  )
  select d.company_id, d.id, d.source_code
  into v_invalid
  from desired as d
  where d.source_code is not null
    and (
      d.source_code !~ '^[0-9]{5,6}$'
      or pg_catalog.lpad(d.source_code, 6, '0') = '000000'
    )
  order by d.company_id, d.source_code
  limit 1;
  if found then
    raise exception using
      errcode = '23514',
      message = pg_catalog.format(
        'PROFILE_EMPLOYEE_CODE_MIGRATION_INVALID:company=%s profile=%s code=%s',
        v_invalid.company_id, v_invalid.id, v_invalid.source_code
      );
  end if;

  with desired as (
    select p.id,
           p.company_id,
           coalesce(e.codigo_empleado, p.employee_code) as source_code
    from public.profiles as p
    left join public.empleados as e
      on e.empresa_id = p.company_id
     and e.perfil_id = p.id
  )
  select d.company_id,
         pg_catalog.lpad(d.source_code, 6, '0') as normalized_code,
         pg_catalog.array_agg(d.id order by d.id) as profile_ids
  into v_collision
  from desired as d
  where d.source_code is not null
  group by d.company_id, pg_catalog.lpad(d.source_code, 6, '0')
  having pg_catalog.count(*) > 1
  order by d.company_id, normalized_code
  limit 1;
  if found then
    raise exception using
      errcode = '23505',
      message = pg_catalog.format(
        'PROFILE_EMPLOYEE_CODE_MIGRATION_COLLISION:company=%s code=%s profiles=%s',
        v_collision.company_id, v_collision.normalized_code, v_collision.profile_ids
      );
  end if;

  -- Un profile no vinculado tambien consume su codigo. Si ya pertenece a un
  -- empleado distinto, no hay una normalizacion segura y la migracion aborta.
  with desired as (
    select p.id,
           p.company_id,
           coalesce(linked.codigo_empleado, p.employee_code) as source_code,
           linked.id as linked_employee_id
    from public.profiles as p
    left join public.empleados as linked
      on linked.empresa_id = p.company_id
     and linked.perfil_id = p.id
  )
  select d.company_id,
         pg_catalog.lpad(d.source_code, 6, '0') as normalized_code,
         d.id as profile_id,
         e.id as employee_id
  into v_collision
  from desired as d
  join public.empleados as e
    on e.empresa_id = d.company_id
   and pg_catalog.lpad(e.codigo_empleado, 6, '0') =
       pg_catalog.lpad(d.source_code, 6, '0')
  where d.source_code is not null
    and e.id is distinct from d.linked_employee_id
  order by d.company_id, normalized_code
  limit 1;
  if found then
    raise exception using
      errcode = '23505',
      message = pg_catalog.format(
        'PROFILE_EMPLOYEE_CODE_CROSS_COLLISION:company=%s code=%s profile=%s employee=%s',
        v_collision.company_id, v_collision.normalized_code,
        v_collision.profile_id, v_collision.employee_id
      );
  end if;
end;
$$;

do $$
declare
  v_invalid record;
begin
  select a.id, a.empresa_id, a.employee_code
  into v_invalid
  from public.face_first_enrollment_audit as a
  where a.employee_code !~ '^[0-9]{5,6}$'
     or pg_catalog.lpad(a.employee_code, 6, '0') = '000000'
  order by a.id
  limit 1;
  if found then
    raise exception using
      errcode = '23514',
      message = pg_catalog.format(
        'FACE_AUDIT_EMPLOYEE_CODE_MIGRATION_INVALID:audit=%s company=%s code=%s',
        v_invalid.id, v_invalid.empresa_id, v_invalid.employee_code
      );
  end if;
end;
$$;

create or replace function public.employee_pin_matches_code_internal(
  p_code text,
  p_pin_hash text
)
returns boolean
language plpgsql
immutable
security definer
set search_path = ''
as $$
begin
  if p_code is null
     or p_pin_hash is null
     or p_pin_hash !~ '^\$2[aby]\$'
  then
    return false;
  end if;
  return extensions.crypt(p_code, p_pin_hash) = p_pin_hash;
exception
  when others then
    return false;
end;
$$;

revoke all on function public.employee_pin_matches_code_internal(text, text)
  from public, anon, authenticated, service_role;

alter table public.empleados
  add column pin_is_employee_code boolean not null default false,
  add column pin_configured boolean generated always as (
    pin_hash is not null
  ) stored;

comment on column public.empleados.pin_is_employee_code is
  'Metadato interno: el hash fue derivado del codigo canonico; nunca contiene el PIN.';
comment on column public.empleados.pin_configured is
  'Indicador seguro para clientes; evita exponer pin_hash para saber si existe PIN.';

-- Una unica comparacion bcrypt por empleado durante la migracion. El plan
-- temporal evita el O(N^2) y no expone ni persiste alias PIN en texto claro.
create temporary table employee_code_0024_plan on commit drop as
select e.id,
       e.empresa_id,
       e.codigo_empleado as old_code,
       pg_catalog.lpad(e.codigo_empleado, 6, '0') as new_code,
       public.employee_pin_matches_code_internal(
         e.codigo_empleado, e.pin_hash
       ) as pin_matches_code,
       e.pin_hash ~ '^\$argon2(id|i|d)\$' as pin_argon2
from public.empleados as e;

-- Auditoria estructurada de la conversion. No contiene PIN, hash ni secretos.
create table public.employee_code_normalization_audit (
  id bigint generated always as identity primary key,
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  old_code text not null,
  new_code text not null,
  pin_rehashed boolean not null default false,
  pin_strategy text not null,
  migration_name text not null default '0024_employee_codes_six_digits',
  migrated_at timestamptz not null default now(),
  constraint employee_code_normalization_old_check
    check (old_code ~ '^[0-9]{5}$' and old_code <> '00000'),
  constraint employee_code_normalization_new_check
    check (new_code ~ '^[0-9]{6}$' and new_code <> '000000'),
  constraint employee_code_normalization_change_check
    check (new_code = pg_catalog.lpad(old_code, 6, '0')),
  constraint employee_code_normalization_pin_strategy_check check (
    pin_strategy in (
      'REHASHED_BCRYPT_MATCH',
      'PRESERVED_ARGON2_UNVERIFIED',
      'PRESERVED_INDEPENDENT_OR_EMPTY'
    )
  ),
  constraint employee_code_normalization_migration_check
    check (migration_name = '0024_employee_codes_six_digits')
);

alter table public.employee_code_normalization_audit enable row level security;
revoke all on table public.employee_code_normalization_audit
  from public, anon, authenticated, service_role;
grant select on table public.employee_code_normalization_audit to service_role;
revoke all on sequence public.employee_code_normalization_audit_id_seq
  from public, anon, authenticated, service_role;

comment on table public.employee_code_normalization_audit is
  'Auditoria sin secretos de la normalizacion irreversible de codigos de empleado 5 a 6 digitos.';

insert into public.employee_code_normalization_audit(
  empresa_id, empleado_id, old_code, new_code, pin_rehashed, pin_strategy
)
select p.empresa_id,
       p.id,
       p.old_code,
       p.new_code,
       p.pin_matches_code,
       case
         when p.pin_matches_code then 'REHASHED_BCRYPT_MATCH'
         when p.pin_argon2
           then 'PRESERVED_ARGON2_UNVERIFIED'
         else 'PRESERVED_INDEPENDENT_OR_EMPTY'
       end
from employee_code_0024_plan as p
where p.old_code ~ '^[0-9]{5}$';

-- pgcrypto no verifica Argon2. Se preserva el hash sin tocarlo y se deja una
-- evidencia explicita para revision, sin almacenar el hash ni el PIN.
create table public.employee_pin_code_verification_audit (
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  original_employee_code text not null,
  normalized_employee_code text not null,
  pin_algorithm text not null default 'ARGON2',
  verification_status text not null default 'UNVERIFIED_REQUIRES_REVIEW',
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  primary key (empresa_id, empleado_id),
  constraint employee_pin_code_original_check
    check (original_employee_code ~ '^[0-9]{5,6}$'),
  constraint employee_pin_code_normalized_check check (
    normalized_employee_code ~ '^[0-9]{6}$'
    and normalized_employee_code <> '000000'
  ),
  constraint employee_pin_code_algorithm_check
    check (pin_algorithm = 'ARGON2'),
  constraint employee_pin_code_status_check
    check (
      verification_status in (
        'UNVERIFIED_REQUIRES_REVIEW', 'RESOLVED_PIN_RESET'
      )
    ),
  constraint employee_pin_code_resolution_check check (
    (verification_status = 'UNVERIFIED_REQUIRES_REVIEW' and resolved_at is null)
    or (verification_status = 'RESOLVED_PIN_RESET' and resolved_at is not null)
  )
);
alter table public.employee_pin_code_verification_audit enable row level security;
revoke all on table public.employee_pin_code_verification_audit
  from public, anon, authenticated, service_role;
grant select on table public.employee_pin_code_verification_audit to service_role;

insert into public.employee_pin_code_verification_audit(
  empresa_id, empleado_id, original_employee_code, normalized_employee_code
)
select p.empresa_id, p.id, p.old_code, p.new_code
from employee_code_0024_plan as p
where p.pin_argon2;

comment on table public.employee_pin_code_verification_audit is
  'Identifica hashes Argon2 preservados que pgcrypto no puede comparar con el codigo; no contiene PIN ni hash.';

update public.empleados as e
set codigo_empleado = p.new_code,
    pin_hash = case
      when p.old_code ~ '^[0-9]{5}$' and p.pin_matches_code
      then extensions.crypt(
        p.new_code,
        extensions.gen_salt('bf', 12)
      )
      else e.pin_hash
    end,
    pin_is_employee_code = p.pin_matches_code
from employee_code_0024_plan as p
where e.id = p.id
  and e.empresa_id = p.empresa_id
  and (
    p.old_code ~ '^[0-9]{5}$'
    or e.pin_is_employee_code is distinct from p.pin_matches_code
  );

-- Se conserva como helper privado para comparar candidatos exclusivamente
-- contra los hashes bcrypt independientes del mismo tenant. No tiene grants y
-- nunca devuelve ni registra el hash o el candidato.

update public.profiles as p
set employee_code = e.codigo_empleado,
    updated_at = now()
from public.empleados as e
where e.empresa_id = p.company_id
  and e.perfil_id = p.id
  and p.employee_code is distinct from e.codigo_empleado;

update public.profiles as p
set employee_code = pg_catalog.lpad(p.employee_code, 6, '0'),
    updated_at = now()
where p.employee_code ~ '^[0-9]{5}$'
  and not exists (
    select 1
    from public.empleados as e
    where e.empresa_id = p.company_id
      and e.perfil_id = p.id
  );

-- Conserva evidencia old/new por cada fila antes de canonizar la referencia.
create table public.face_first_enrollment_code_normalization_audit (
  face_audit_id bigint primary key,
  empresa_id uuid not null references public.companies(id) on delete restrict,
  old_code text not null,
  new_code text not null,
  migrated_at timestamptz not null default now(),
  constraint face_code_normalization_old_check
    check (old_code ~ '^[0-9]{5}$' and old_code <> '00000'),
  constraint face_code_normalization_new_check
    check (new_code ~ '^[0-9]{6}$' and new_code <> '000000'),
  constraint face_code_normalization_change_check
    check (new_code = pg_catalog.lpad(old_code, 6, '0'))
);
alter table public.face_first_enrollment_code_normalization_audit
  enable row level security;
revoke all on table public.face_first_enrollment_code_normalization_audit
  from public, anon, authenticated, service_role;
grant select on table public.face_first_enrollment_code_normalization_audit
  to service_role;

insert into public.face_first_enrollment_code_normalization_audit(
  face_audit_id, empresa_id, old_code, new_code
)
select a.id,
       a.empresa_id,
       a.employee_code,
       pg_catalog.lpad(a.employee_code, 6, '0')
from public.face_first_enrollment_audit as a
where a.employee_code ~ '^[0-9]{5}$';

update public.face_first_enrollment_audit
set employee_code = pg_catalog.lpad(employee_code, 6, '0')
where employee_code ~ '^[0-9]{5}$';

alter table public.empleados
  drop constraint empleados_codigo_formato,
  add constraint empleados_codigo_formato check (
    codigo_empleado ~ '^[0-9]{6}$' and codigo_empleado <> '000000'
  );

create index empleados_independent_pin_company_idx
  on public.empleados(empresa_id)
  where not pin_is_employee_code and pin_hash ~ '^\$2[aby]\$';

alter table public.profiles
  drop constraint profiles_employee_code_format,
  add constraint profiles_employee_code_format check (
    employee_code is null
    or (employee_code ~ '^[0-9]{6}$' and employee_code <> '000000')
  );

alter table public.face_first_enrollment_audit
  drop constraint face_first_enrollment_audit_employee_code_check,
  add constraint face_first_enrollment_audit_employee_code_check check (
    employee_code ~ '^[0-9]{6}$' and employee_code <> '000000'
  );

-- La definicion ya existe en 0023. Esta sustitucion acotada permite actualizar
-- instalaciones enlazadas sin duplicar una funcion biometrica extensa.
do $$
declare
  v_definition text;
  v_changed boolean := false;
begin
  select pg_catalog.pg_get_functiondef(
    'public.initial_face_enrollment_internal(jsonb)'::regprocedure
  ) into v_definition;

  if pg_catalog.strpos(v_definition, '''^[0-9]{5,12}$''') > 0 then
    v_definition := pg_catalog.replace(
      v_definition,
      '''^[0-9]{5,12}$''',
      '''^[0-9]{6}$'''
    );
    v_changed := true;
  end if;
  if pg_catalog.strpos(v_definition, '''^[0-9]{6}$''') = 0 then
    raise exception 'INITIAL_FACE_ENROLLMENT_EMPLOYEE_CODE_VALIDATION_NOT_FOUND';
  end if;
  if pg_catalog.strpos(v_definition, 'v_employee_code = ''000000''') = 0 then
    if pg_catalog.strpos(
      v_definition,
      'or v_validation_mode not in'
    ) = 0 then
      raise exception 'INITIAL_FACE_ENROLLMENT_VALIDATION_ANCHOR_NOT_FOUND';
    end if;
    v_definition := pg_catalog.replace(
      v_definition,
      'or v_validation_mode not in',
      'or v_employee_code = ''000000'' or v_validation_mode not in'
    );
    v_changed := true;
  end if;
  if v_changed then
    execute v_definition;
  end if;
end;
$$;

-- Registro permanente de codigos consumidos. employee_id es un snapshot sin FK
-- deliberadamente: al borrar un empleado el codigo sigue reservado para siempre.
create table public.employee_code_registry (
  empresa_id uuid not null references public.companies(id) on delete restrict,
  employee_code text not null,
  employee_id uuid,
  profile_id uuid,
  source text not null,
  first_assigned_at timestamptz not null default now(),
  consumed_at timestamptz,
  primary key (empresa_id, employee_code),
  constraint employee_code_registry_code_check check (
    employee_code ~ '^[0-9]{6}$' and employee_code <> '000000'
  ),
  constraint employee_code_registry_source_check check (
    source in (
      'MIGRATION', 'PROFILE_MIGRATION', 'PROFILE_DIRECT_WRITE',
      'ALLOCATOR', 'DIRECT_WRITE'
    )
  ),
  constraint employee_code_registry_single_owner_check check (
    (employee_id is not null and profile_id is null)
    or (employee_id is null and profile_id is not null)
  ),
  constraint employee_code_registry_state_check check (
    (source = 'ALLOCATOR' and consumed_at is null)
    or (source <> 'ALLOCATOR' and consumed_at is not null)
  )
);

create index employee_code_registry_employee_idx
  on public.employee_code_registry(empresa_id, employee_id)
  where employee_id is not null;
create unique index employee_code_registry_pending_employee_uidx
  on public.employee_code_registry(empresa_id, employee_id)
  where source = 'ALLOCATOR' and consumed_at is null;
create index employee_code_registry_profile_idx
  on public.employee_code_registry(empresa_id, profile_id)
  where profile_id is not null;

create table public.employee_code_sequences (
  empresa_id uuid primary key references public.companies(id) on delete restrict,
  last_value integer not null default 0,
  updated_at timestamptz not null default now(),
  constraint employee_code_sequences_range_check
    check (last_value between 0 and 999999)
);

alter table public.employee_code_registry enable row level security;
alter table public.employee_code_sequences enable row level security;
revoke all on table public.employee_code_registry, public.employee_code_sequences
  from public, anon, authenticated, service_role;
grant select on table public.employee_code_registry, public.employee_code_sequences
  to service_role;

insert into public.employee_code_registry(
  empresa_id, employee_code, employee_id, source,
  first_assigned_at, consumed_at
)
select e.empresa_id, e.codigo_empleado, e.id, 'MIGRATION',
       e.created_at, e.created_at
from public.empleados as e;

-- Una auditoria facial vinculada puede conservar un codigo anterior del mismo
-- empleado. Se reserva tambien para no reutilizar historia disponible antes de
-- 0024; intentos sin empleado no se interpretan como asignaciones reales.
insert into public.employee_code_registry(
  empresa_id, employee_code, employee_id, source,
  first_assigned_at, consumed_at
)
select distinct on (a.empresa_id, a.employee_code)
       a.empresa_id,
       a.employee_code,
       a.empleado_id,
       'MIGRATION',
       a.created_at,
       a.created_at
from public.face_first_enrollment_audit as a
where a.empleado_id is not null
  and not exists (
    select 1
    from public.employee_code_registry as r
    where r.empresa_id = a.empresa_id
      and r.employee_code = a.employee_code
  )
order by a.empresa_id, a.employee_code, a.created_at, a.id;

insert into public.employee_code_registry(
  empresa_id, employee_code, employee_id, profile_id, source,
  first_assigned_at, consumed_at
)
select p.company_id,
       p.employee_code,
       null,
       p.id,
       'PROFILE_MIGRATION',
       p.created_at,
       p.created_at
from public.profiles as p
where p.employee_code is not null
  and not exists (
    select 1
    from public.empleados as e
    where e.empresa_id = p.company_id
      and e.perfil_id = p.id
  );

insert into public.employee_code_sequences(empresa_id, last_value)
select c.id,
       coalesce(pg_catalog.max(r.employee_code::integer), 0)
from public.companies as c
left join public.employee_code_registry as r on r.empresa_id = c.id
group by c.id;

-- Reclama exactamente el proximo codigo admisible bajo el lock del tenant.
-- Sirve tanto al CREATE del dispositivo como al trigger que arbitra escrituras
-- SQL directas: ninguna ruta puede saltar el contador ni elegir otro codigo.
create or replace function public.claim_next_employee_code_internal(
  p_company_id uuid,
  p_employee_id uuid,
  p_proposed_code text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last integer;
  v_next integer;
  v_code text;
  v_reserved_code text;
begin
  if p_company_id is null
     or p_employee_id is null
     or p_proposed_code is null
     or p_proposed_code !~ '^[0-9]{6}$'
     or p_proposed_code = '000000'
     or not exists (select 1 from public.companies where id = p_company_id)
  then
    raise exception using
      errcode = '23514',
      message = 'EMPLOYEE_CODE_STALE_OR_USED';
  end if;

  if exists (
    select 1
    from public.employee_pin_code_verification_audit as a
    join public.empleados as pending
      on pending.empresa_id = a.empresa_id
     and pending.id = a.empleado_id
    where a.empresa_id = p_company_id
      and a.verification_status = 'UNVERIFIED_REQUIRES_REVIEW'
  ) then
    raise exception using
      errcode = '23514',
      message = 'EMPLOYEE_PIN_ALIAS_REVIEW_REQUIRED';
  end if;

  insert into public.employee_code_sequences(empresa_id, last_value)
  values (p_company_id, 0)
  on conflict (empresa_id) do nothing;

  select s.last_value
  into v_last
  from public.employee_code_sequences as s
  where s.empresa_id = p_company_id
  for update;

  select r.employee_code
  into v_reserved_code
  from public.employee_code_registry as r
  where r.empresa_id = p_company_id
    and r.employee_id = p_employee_id
    and r.source = 'ALLOCATOR'
    and r.consumed_at is null
  for update;
  if found then
    if v_reserved_code = p_proposed_code then
      return v_reserved_code;
    end if;
    raise exception using
      errcode = '23505',
      message = 'EMPLOYEE_CODE_STALE_OR_USED';
  end if;

  loop
    v_next := v_last + 1;
    if v_next > 999999 then
      raise exception 'EMPLOYEE_CODE_EXHAUSTED';
    end if;
    v_code := pg_catalog.lpad(v_next::text, 6, '0');
    if exists (
      select 1
      from public.employee_code_registry as r
      where r.empresa_id = p_company_id
        and r.employee_code = v_code
    ) or exists (
      select 1
      from public.empleados as e
      where e.empresa_id = p_company_id
        and not e.pin_is_employee_code
        and e.pin_hash ~ '^\$2[aby]\$'
        and public.employee_pin_matches_code_internal(v_code, e.pin_hash)
    ) then
      v_last := v_next;
      continue;
    end if;
    exit;
  end loop;

  if v_code <> p_proposed_code then
    raise exception using
      errcode = '23505',
      message = 'EMPLOYEE_CODE_STALE_OR_USED';
  end if;

  update public.employee_code_sequences
  set last_value = v_next, updated_at = now()
  where empresa_id = p_company_id;
  insert into public.employee_code_registry(
    empresa_id, employee_code, employee_id, source
  ) values (
    p_company_id, v_code, p_employee_id, 'ALLOCATOR'
  );
  return v_code;
end;
$$;

create or replace function public.normalizar_empleado()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_old_employee_id uuid;
  v_code_changed boolean;
begin
  new.codigo_empleado = btrim(new.codigo_empleado);
  new.nombre_completo = btrim(new.nombre_completo);
  new.cedula = nullif(btrim(new.cedula), '');
  new.correo = nullif(lower(btrim(new.correo)), '');
  new.telefono = nullif(btrim(new.telefono), '');
  new.foto_url = nullif(btrim(new.foto_url), '');
  new.tipo_pago = nullif(lower(btrim(new.tipo_pago)), '');

  if tg_op = 'INSERT' then
    v_old_employee_id := null;
    v_code_changed := true;
  else
    if new.empresa_id is distinct from old.empresa_id then
      raise exception using
        errcode = '23514',
        message = 'EMPLOYEE_COMPANY_IMMUTABLE';
    end if;
    v_old_employee_id := old.id;
    v_code_changed := new.empresa_id is distinct from old.empresa_id
      or new.codigo_empleado is distinct from old.codigo_empleado;
  end if;

  if v_code_changed
     and new.codigo_empleado ~ '^[0-9]{6}$'
     and new.codigo_empleado <> '000000'
  then
    -- Argon2 no puede comprobarse con pgcrypto. Una empresa con una revision
    -- historica pendiente se cierra de forma segura hasta restablecer ese PIN.
    if exists (
      select 1
      from public.employee_pin_code_verification_audit as a
      join public.empleados as pending
        on pending.empresa_id = a.empresa_id
       and pending.id = a.empleado_id
      where a.empresa_id = new.empresa_id
        and a.verification_status = 'UNVERIFIED_REQUIRES_REVIEW'
    ) then
      raise exception using
        errcode = '23514',
        message = 'EMPLOYEE_PIN_ALIAS_REVIEW_REQUIRED';
    end if;

    if exists (
      select 1
      from public.empleados as e
      where e.empresa_id = new.empresa_id
        and e.id is distinct from v_old_employee_id
        and not e.pin_is_employee_code
        and e.pin_hash ~ '^\$2[aby]\$'
        and public.employee_pin_matches_code_internal(
          new.codigo_empleado, e.pin_hash
        )
    ) then
      raise exception using
        errcode = '23505',
        message = 'EMPLOYEE_CODE_UNAVAILABLE';
    end if;
  end if;

  if tg_op = 'INSERT' then
    if new.pin_hash is null
       and new.codigo_empleado ~ '^[0-9]{6}$'
       and new.codigo_empleado <> '000000'
    then
      new.pin_hash := extensions.crypt(
        new.codigo_empleado,
        extensions.gen_salt('bf', 12)
      );
      new.pin_is_employee_code := true;
    elsif new.pin_hash ~ '^\$argon2(id|i|d)\$' then
      -- Desde 0024 no se aceptan nuevos alias imposibles de verificar. Los
      -- historicos ya quedaron preservados y auditados antes de este trigger.
      raise exception using
        errcode = '23514',
        message = 'EMPLOYEE_PIN_ALIAS_REVIEW_REQUIRED';
    else
      new.pin_is_employee_code := public.employee_pin_matches_code_internal(
        new.codigo_empleado, new.pin_hash
      );
      if not new.pin_is_employee_code then
        raise exception using
          errcode = '23514',
          message = 'EMPLOYEE_PIN_MUST_MATCH_CODE';
      end if;
    end if;
  elsif new.pin_hash is distinct from old.pin_hash then
    if new.pin_hash is null then
      new.pin_hash := extensions.crypt(
        new.codigo_empleado,
        extensions.gen_salt('bf', 12)
      );
      new.pin_is_employee_code := true;
    elsif new.pin_hash ~ '^\$argon2(id|i|d)\$' then
      raise exception using
        errcode = '23514',
        message = 'EMPLOYEE_PIN_ALIAS_REVIEW_REQUIRED';
    else
      new.pin_is_employee_code := public.employee_pin_matches_code_internal(
        new.codigo_empleado, new.pin_hash
      );
      if not new.pin_is_employee_code then
        raise exception using
          errcode = '23514',
          message = 'EMPLOYEE_PIN_MUST_MATCH_CODE';
      end if;
    end if;

    update public.employee_pin_code_verification_audit
    set verification_status = 'RESOLVED_PIN_RESET',
        resolved_at = now()
    where empresa_id = new.empresa_id
      and empleado_id = new.id
      and verification_status = 'UNVERIFIED_REQUIRES_REVIEW';
  elsif new.codigo_empleado is distinct from old.codigo_empleado then
    if not old.pin_is_employee_code
       and public.employee_pin_matches_code_internal(
         new.codigo_empleado, new.pin_hash
       )
    then
      -- Un codigo que alcanza su propio PIN historico deja de ser un alias
      -- independiente; no debe bloquearse contra si mismo en el claim.
      new.pin_is_employee_code := true;
    elsif old.pin_is_employee_code then
      new.pin_hash := extensions.crypt(
        new.codigo_empleado,
        extensions.gen_salt('bf', 12)
      );
      new.pin_is_employee_code := true;
    else
      new.pin_is_employee_code := false;
    end if;
  else
    new.pin_is_employee_code := old.pin_is_employee_code;
  end if;
  return new;
end;
$$;

revoke all on function public.normalizar_empleado() from public;

-- 0003 ya canaliza profiles por RPC SECURITY DEFINER. Se reafirma el revoke a
-- nivel de tabla: un revoke de columna no anula un grant de tabla heredado.
revoke insert, update on table public.profiles from authenticated;

-- 0002 habia concedido SELECT de tabla completa, lo que exponia pin_hash y,
-- tras 0018, face_embedding. Se sustituye por una lista positiva de columnas
-- aptas para clientes. Las Edge Functions usan service_role y no dependen de
-- este grant.
revoke select on table public.empleados from public, anon, authenticated;
grant select (
  id, empresa_id, perfil_id, sucursal_id, departamento_id, puesto_id,
  supervisor_id, codigo_empleado, nombre_completo, cedula, correo, telefono,
  foto_url, fecha_ingreso, estado_laboral, salario, tipo_pago, activo,
  jornada_habilitada, created_at, updated_at, pin_configured
) on public.empleados to authenticated;

-- authenticated no recibe privilegio de escritura sobre pin_hash. El valor no
-- nulo procede exclusivamente del trigger, por lo que la politica debe evaluar
-- la fila final sin bloquear esa derivacion controlada.
drop policy empleados_insert_autorizado on public.empleados;
create policy empleados_insert_autorizado on public.empleados
  for insert to authenticated
  with check (
    empresa_id = (select public.obtener_empresa_actual())
    and perfil_id is null
    and salario is null
    and (select public.tiene_permiso('empleados.crear'))
  );

create or replace function public.register_employee_code_usage_internal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_employee_owner uuid;
  v_profile_owner uuid;
  v_consumed_at timestamptz;
begin
  if tg_op = 'UPDATE'
     and new.empresa_id = old.empresa_id
     and new.codigo_empleado = old.codigo_empleado
  then
    return null;
  end if;

  select r.employee_id, r.profile_id, r.consumed_at
  into v_employee_owner, v_profile_owner, v_consumed_at
  from public.employee_code_registry as r
  where r.empresa_id = new.empresa_id
    and r.employee_code = new.codigo_empleado
  for update;

  if found then
    if v_employee_owner = new.id
       and v_profile_owner is null
       and v_consumed_at is null
    then
      update public.employee_code_registry
      set source = 'DIRECT_WRITE', consumed_at = now()
      where empresa_id = new.empresa_id
        and employee_code = new.codigo_empleado;
    elsif v_employee_owner is null
      and v_profile_owner = new.perfil_id
      and exists (
        select 1
        from public.profiles as p
        where p.id = new.perfil_id
          and p.company_id = new.empresa_id
          and p.employee_code = new.codigo_empleado
      )
    then
      update public.employee_code_registry
      set employee_id = new.id,
          profile_id = null,
          source = 'DIRECT_WRITE',
          consumed_at = coalesce(consumed_at, now())
      where empresa_id = new.empresa_id
        and employee_code = new.codigo_empleado;
    else
      raise exception using
        errcode = '23505',
        message = 'EMPLOYEE_CODE_ALREADY_USED';
    end if;
  end if;

  if not found then
    perform public.claim_next_employee_code_internal(
      new.empresa_id, new.id, new.codigo_empleado
    );
    update public.employee_code_registry
    set source = 'DIRECT_WRITE', consumed_at = now()
    where empresa_id = new.empresa_id
      and employee_code = new.codigo_empleado
      and employee_id = new.id
      and source = 'ALLOCATOR'
      and consumed_at is null;
    if not found then
      raise exception 'EMPLOYEE_CODE_RESERVATION_FAILED';
    end if;
  end if;
  return null;
end;
$$;

revoke all on function public.register_employee_code_usage_internal()
  from public, anon, authenticated;

create trigger empleados_register_code_after_write
  after insert or update of empresa_id, codigo_empleado on public.empleados
  for each row execute function public.register_employee_code_usage_internal();

create or replace function public.sync_employee_code_to_profile_internal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.perfil_id is not null then
    update public.profiles as p
    set employee_code = new.codigo_empleado,
        updated_at = now()
    where p.id = new.perfil_id
      and p.company_id = new.empresa_id
      and p.employee_code is distinct from new.codigo_empleado;
  end if;
  return null;
end;
$$;

revoke all on function public.sync_employee_code_to_profile_internal()
  from public, anon, authenticated;

create trigger empleados_sync_code_to_profile_after_write
  after insert or update of empresa_id, perfil_id, codigo_empleado
  on public.empleados
  for each row execute function public.sync_employee_code_to_profile_internal();

create or replace function public.canonicalize_profile_employee_code_internal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_employee_code text;
begin
  select e.codigo_empleado
  into v_employee_code
  from public.empleados as e
  where e.empresa_id = new.company_id
    and e.perfil_id = new.id;
  if found then
    new.employee_code := v_employee_code;
  end if;
  return new;
end;
$$;

revoke all on function public.canonicalize_profile_employee_code_internal()
  from public, anon, authenticated;

create trigger profiles_employee_code_canonical_before_write
  before insert or update of company_id, employee_code on public.profiles
  for each row execute function public.canonicalize_profile_employee_code_internal();

create or replace function public.register_profile_code_usage_internal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_employee_owner uuid;
  v_consumed_at timestamptz;
  v_linked_employee uuid;
begin
  if new.employee_code is null
     or (
       tg_op = 'UPDATE'
       and new.company_id = old.company_id
       and new.employee_code is not distinct from old.employee_code
     )
  then
    return null;
  end if;

  select r.employee_id, r.consumed_at
  into v_employee_owner, v_consumed_at
  from public.employee_code_registry as r
  where r.empresa_id = new.company_id
    and r.employee_code = new.employee_code;
  if not found or v_employee_owner is null or v_consumed_at is null then
    raise exception using
      errcode = '23514',
      message = 'PROFILE_EMPLOYEE_CODE_REQUIRES_EMPLOYEE';
  end if;

  -- El registry conserva para siempre los codigos consumidos, incluso despues
  -- de borrar al empleado. Un profile nuevo solo puede adoptar el codigo si su
  -- propietario sigue existiendo y conserva empresa/codigo. El bloqueo evita
  -- que un DELETE concurrente deje al profile huerfano durante esta operacion.
  perform 1
  from public.empleados as owner
  where owner.id = v_employee_owner
    and owner.empresa_id = new.company_id
    and owner.codigo_empleado = new.employee_code
  for key share;
  if not found then
    raise exception using
      errcode = '23514',
      message = 'PROFILE_EMPLOYEE_CODE_REQUIRES_EMPLOYEE';
  end if;

  select e.id into v_linked_employee
  from public.empleados as e
  where e.empresa_id = new.company_id
    and e.perfil_id = new.id;
  if tg_op = 'UPDATE'
     and (
       new.company_id is distinct from old.company_id
       or new.employee_code is distinct from old.employee_code
     )
     and not found
  then
    raise exception using
      errcode = '23514',
      message = 'PROFILE_EMPLOYEE_CODE_IMMUTABLE';
  end if;
  if found and v_linked_employee <> v_employee_owner then
    raise exception using
      errcode = '23505',
      message = 'EMPLOYEE_CODE_ALREADY_USED';
  end if;
  -- crear_acceso_internal inserta el profile con el codigo del empleado y lo
  -- vincula dentro de la misma transaccion. Ningun profile crea namespaces.
  return null;
end;
$$;

revoke all on function public.register_profile_code_usage_internal()
  from public, anon, authenticated;

create trigger profiles_register_code_after_write
  after insert or update of company_id, employee_code on public.profiles
  for each row execute function public.register_profile_code_usage_internal();

create or replace function public.preview_next_employee_code_internal(
  p_company_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_next integer;
  v_code text;
begin
  if p_company_id is null
     or not exists (select 1 from public.companies where id = p_company_id)
  then
    raise exception 'EMPLOYEE_CODE_COMPANY_INVALID';
  end if;

  if exists (
    select 1
    from public.employee_pin_code_verification_audit as a
    join public.empleados as pending
      on pending.empresa_id = a.empresa_id
     and pending.id = a.empleado_id
    where a.empresa_id = p_company_id
      and a.verification_status = 'UNVERIFIED_REQUIRES_REVIEW'
  ) then
    raise exception 'EMPLOYEE_PIN_ALIAS_REVIEW_REQUIRED';
  end if;

  select coalesce(s.last_value, 0)
  into v_next
  from (select 1) as singleton
  left join public.employee_code_sequences as s
    on s.empresa_id = p_company_id;

  loop
    v_next := v_next + 1;
    if v_next > 999999 then
      raise exception 'EMPLOYEE_CODE_EXHAUSTED';
    end if;
    v_code := pg_catalog.lpad(v_next::text, 6, '0');
    if exists (
      select 1
      from public.employee_code_registry as r
      where r.empresa_id = p_company_id
        and r.employee_code = v_code
    ) or exists (
      select 1
      from public.empleados as e
      where e.empresa_id = p_company_id
        and not e.pin_is_employee_code
        and e.pin_hash ~ '^\$2[aby]\$'
        and public.employee_pin_matches_code_internal(v_code, e.pin_hash)
    ) then
      continue;
    end if;
    return v_code;
  end loop;
end;
$$;

create or replace function public.allocate_next_employee_code_internal(
  p_company_id uuid,
  p_employee_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_last integer;
  v_next integer;
  v_code text;
  v_reserved_code text;
begin
  if p_company_id is null
     or p_employee_id is null
     or not exists (select 1 from public.companies where id = p_company_id)
  then
    raise exception 'EMPLOYEE_CODE_ALLOCATION_INVALID';
  end if;

  if exists (
    select 1
    from public.employee_pin_code_verification_audit as a
    join public.empleados as pending
      on pending.empresa_id = a.empresa_id
     and pending.id = a.empleado_id
    where a.empresa_id = p_company_id
      and a.verification_status = 'UNVERIFIED_REQUIRES_REVIEW'
  ) then
    raise exception 'EMPLOYEE_PIN_ALIAS_REVIEW_REQUIRED';
  end if;

  insert into public.employee_code_sequences(empresa_id, last_value)
  values (p_company_id, 0)
  on conflict (empresa_id) do nothing;

  select s.last_value
  into v_last
  from public.employee_code_sequences as s
  where s.empresa_id = p_company_id
  for update;

  select r.employee_code
  into v_reserved_code
  from public.employee_code_registry as r
  where r.empresa_id = p_company_id
    and r.employee_id = p_employee_id
    and r.source = 'ALLOCATOR'
    and r.consumed_at is null
  for update;
  if found then
    return v_reserved_code;
  end if;

  loop
    v_next := v_last + 1;
    if v_next > 999999 then
      raise exception 'EMPLOYEE_CODE_EXHAUSTED';
    end if;
    v_code := pg_catalog.lpad(v_next::text, 6, '0');
    if exists (
      select 1
      from public.employee_code_registry as r
      where r.empresa_id = p_company_id
        and r.employee_code = v_code
    ) then
      v_last := v_next;
      continue;
    end if;
    if exists (
      select 1
      from public.empleados as e
      where e.empresa_id = p_company_id
        and not e.pin_is_employee_code
        and e.pin_hash ~ '^\$2[aby]\$'
        and public.employee_pin_matches_code_internal(v_code, e.pin_hash)
    ) then
      v_last := v_next;
      continue;
    end if;
    exit;
  end loop;

  update public.employee_code_sequences
  set last_value = v_next, updated_at = now()
  where empresa_id = p_company_id;

  insert into public.employee_code_registry(
    empresa_id, employee_code, employee_id, source
  ) values (
    p_company_id, v_code, p_employee_id, 'ALLOCATOR'
  );
  return v_code;
end;
$$;

-- El bootstrap ya no confia en un employee_code de la UI. La primera empresa
-- crea siempre su empleado administrador con la misma autoridad monotona.
create or replace function public.bootstrap_tenant_internal(payload jsonb)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (payload->>'user_id')::uuid;
  v_company_id uuid := extensions.gen_random_uuid();
  v_role_id uuid := extensions.gen_random_uuid();
  v_branch_id uuid := extensions.gen_random_uuid();
  v_employee_id uuid := extensions.gen_random_uuid();
  v_employee_code text;
  v_profile public.profiles;
begin
  if exists (select 1 from public.profiles) then
    raise exception 'Bootstrap cerrado';
  end if;
  if not exists (select 1 from auth.users where id = v_user_id) then
    raise exception 'Usuario Auth inexistente';
  end if;
  insert into public.companies(
    id,name,legal_name,slug,timezone,status
  ) values (
    v_company_id,
    btrim(payload->>'company_name'),
    nullif(btrim(payload->>'legal_name'),''),
    lower(btrim(payload->>'company_slug')),
    coalesce(
      nullif(payload->>'timezone',''), 'America/Santo_Domingo'
    ),
    'active'
  );
  insert into public.roles(
    id,company_id,name,code,description,is_system,is_active
  ) values (
    v_role_id,v_company_id,'Administrador','admin',
    'Administrador inicial del tenant.',true,true
  );
  insert into public.branches(
    id,company_id,name,code,is_main,status
  ) values (
    v_branch_id,v_company_id,
    coalesce(nullif(btrim(payload->>'branch_name'),''),'Sucursal principal'),
    'PRINCIPAL',true,'active'
  );
  insert into public.profiles(
    id,company_id,role_id,branch_id,full_name,status
  ) values (
    v_user_id,v_company_id,v_role_id,v_branch_id,
    btrim(payload->>'full_name'),'active'
  ) returning * into v_profile;
  insert into public.rol_permisos(
    rol_id,permiso_id,permitido,alcance
  )
  select v_role_id,id,true,'empresa'
  from public.permisos
  where activo
  on conflict (rol_id,permiso_id)
  do update set permitido=true, alcance='empresa';

  v_employee_code := public.allocate_next_employee_code_internal(
    v_company_id, v_employee_id
  );
  insert into public.empleados(
    id,empresa_id,perfil_id,sucursal_id,codigo_empleado,nombre_completo,
    correo,estado_laboral,activo
  ) values (
    v_employee_id,v_company_id,v_user_id,v_branch_id,v_employee_code,
    btrim(payload->>'full_name'),
    nullif(lower(btrim(payload->>'email')),''),'activo',true
  );
  insert into public.user_provisioning_audit(
    company_id,target_user_id,action,employee_id,role_id,details
  ) values (
    v_company_id,v_user_id,'bootstrap_admin',v_employee_id,v_role_id,
    jsonb_build_object(
      'company_slug',payload->>'company_slug',
      'employee_code_assigned_automatically',true
    )
  );
  select * into v_profile
  from public.profiles
  where id = v_user_id;
  return v_profile;
end;
$$;

revoke all on function public.preview_next_employee_code_internal(uuid)
  from public, anon, authenticated;
revoke all on function public.claim_next_employee_code_internal(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.allocate_next_employee_code_internal(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.preview_next_employee_code_internal(uuid)
  to service_role;
grant execute on function public.claim_next_employee_code_internal(uuid, uuid, text)
  to service_role;
grant execute on function public.allocate_next_employee_code_internal(uuid, uuid)
  to service_role;
revoke all on function public.bootstrap_tenant_internal(jsonb)
  from public, anon, authenticated;
grant execute on function public.bootstrap_tenant_internal(jsonb)
  to service_role;

comment on function public.preview_next_employee_code_internal(uuid) is
  'Vista previa no reservante del siguiente codigo oficial de seis digitos.';
comment on function public.claim_next_employee_code_internal(uuid, uuid, text) is
  'Reclama el proximo codigo solo si coincide exactamente con la propuesta; arbitra Edge y escrituras directas.';
comment on function public.allocate_next_employee_code_internal(uuid, uuid) is
  'Reserva monotonicamente un codigo oficial para un UUID de empleado; nunca reutiliza codigos consumidos.';

commit;
