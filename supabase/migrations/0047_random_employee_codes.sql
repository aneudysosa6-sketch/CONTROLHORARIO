-- CONTROLHORARIO: random, collision-safe six-digit employee codes.

begin;

create or replace function public.preview_next_employee_code_internal(
  p_company_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_start integer;
  v_candidate integer;
  v_code text;
begin
  if p_company_id is null
     or not exists (select 1 from public.companies where id = p_company_id)
  then
    raise exception 'EMPLOYEE_CODE_COMPANY_INVALID';
  end if;

  v_start := 1 + pg_catalog.floor(pg_catalog.random() * 999999)::integer;
  for v_offset in 0..999998 loop
    v_candidate := ((v_start - 1 + v_offset) % 999999) + 1;
    v_code := pg_catalog.lpad(v_candidate::text, 6, '0');
    if not exists (
      select 1
      from public.employee_code_registry registry
      where registry.empresa_id = p_company_id
        and registry.employee_code = v_code
    ) and not exists (
      select 1
      from public.empleados employee
      where employee.empresa_id = p_company_id
        and employee.codigo_empleado = v_code
    ) then
      return v_code;
    end if;
  end loop;

  raise exception 'EMPLOYEE_CODE_EXHAUSTED';
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
  v_start integer;
  v_candidate integer;
  v_code text;
  v_reserved_code text;
begin
  if p_company_id is null
     or p_employee_id is null
     or not exists (select 1 from public.companies where id = p_company_id)
  then
    raise exception 'EMPLOYEE_CODE_ALLOCATION_INVALID';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(p_company_id::text, 24)
  );

  select employee.codigo_empleado
  into v_reserved_code
  from public.empleados employee
  where employee.empresa_id = p_company_id
    and employee.id = p_employee_id;
  if found then
    return v_reserved_code;
  end if;

  select registry.employee_code
  into v_reserved_code
  from public.employee_code_registry registry
  where registry.empresa_id = p_company_id
    and registry.employee_id = p_employee_id
    and registry.source = 'ALLOCATOR'
    and registry.consumed_at is null
  for update;
  if found then
    return v_reserved_code;
  end if;

  v_start := 1 + pg_catalog.floor(pg_catalog.random() * 999999)::integer;
  for v_offset in 0..999998 loop
    v_candidate := ((v_start - 1 + v_offset) % 999999) + 1;
    v_code := pg_catalog.lpad(v_candidate::text, 6, '0');

    if exists (
      select 1
      from public.employee_code_registry registry
      where registry.empresa_id = p_company_id
        and registry.employee_code = v_code
    ) or exists (
      select 1
      from public.empleados employee
      where employee.empresa_id = p_company_id
        and employee.codigo_empleado = v_code
    ) then
      continue;
    end if;

    insert into public.employee_code_registry(
      empresa_id, employee_code, employee_id, source
    ) values (
      p_company_id, v_code, p_employee_id, 'ALLOCATOR'
    );

    insert into public.employee_code_sequences(empresa_id, last_value)
    values (p_company_id, v_candidate)
    on conflict (empresa_id) do update
      set last_value = excluded.last_value,
          updated_at = now();

    return v_code;
  end loop;

  raise exception 'EMPLOYEE_CODE_EXHAUSTED';
end;
$$;

revoke all on function public.preview_next_employee_code_internal(uuid)
  from public, anon, authenticated;
revoke all on function public.allocate_next_employee_code_internal(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.preview_next_employee_code_internal(uuid)
  to service_role;
grant execute on function public.allocate_next_employee_code_internal(uuid, uuid)
  to service_role;

commit;