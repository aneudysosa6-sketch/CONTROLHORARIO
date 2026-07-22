begin;

-- El codigo de empleado identifica al empleado, pero ya no es ni genera un PIN.
-- pin_hash se conserva intacto para compatibilidad de esquema y trazabilidad;
-- ninguna funcion activa de empleados lo consulta, calcula o modifica.
lock table public.empleados in share row exclusive mode;

drop index if exists public.empleados_independent_pin_company_idx;

alter table public.empleados
  drop column if exists pin_configured,
  drop column if exists pin_is_employee_code;

comment on column public.empleados.pin_hash is
  'DEPRECATED: hash historico conservado solo por compatibilidad. No autentica empleados, no deriva del codigo y no debe recibir nuevas escrituras.';
comment on table public.employee_pin_code_verification_audit is
  'Auditoria historica de 0024 conservada sin secretos. Retirada del flujo funcional desde 0025; no bloquea codigos ni requiere resolver PIN.';
comment on column public.company_settings.pin_fallback_enabled is
  'DEPRECATED NAME: controla fallback de identificacion por codigo de empleado; no usa pin_hash. employee-sync publica employee_code_fallback_enabled.';

-- Normaliza exclusivamente datos de empleado. pin_hash queda fuera del flujo:
-- los INSERT nuevos permanecen null salvo una escritura legacy explicita, y los
-- cambios de codigo nunca crean, recalculan ni comparan hashes.
create or replace function public.normalizar_empleado()
returns trigger
language plpgsql
security definer
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

  if tg_op = 'UPDATE'
     and new.empresa_id is distinct from old.empresa_id
  then
    raise exception using
      errcode = '23514',
      message = 'EMPLOYEE_COMPANY_IMMUTABLE';
  end if;
  return new;
end;
$$;

revoke all on function public.normalizar_empleado()
  from public, anon, authenticated;

-- Reclama una propuesta solamente para compatibilidad de escrituras SQL
-- directas. La disponibilidad depende exclusivamente del registry permanente;
-- ningun hash participa en el namespace de codigos.
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

  insert into public.employee_code_sequences(empresa_id, last_value)
  values (p_company_id, 0)
  on conflict (empresa_id) do nothing;

  -- Orden global: sequence primero, registry despues.
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

  -- A retry can arrive after the reservation was consumed by the INSERT but
  -- before the caller received its response. The persisted employee is then
  -- the authoritative idempotency record and must not consume another code.
  select e.codigo_empleado
  into v_reserved_code
  from public.empleados as e
  where e.empresa_id = p_company_id
    and e.id = p_employee_id;
  if found then
    return v_reserved_code;
  end if;

  insert into public.employee_code_sequences(empresa_id, last_value)
  values (p_company_id, 0)
  on conflict (empresa_id) do nothing;

  -- Orden global: sequence primero, registry despues.
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

drop function if exists public.employee_pin_matches_code_internal(text, text);

-- Mantiene una lista positiva de columnas cliente. pin_hash continua privado y
-- ya no se publica ningun indicador que lo convierta en estado funcional.
revoke select on table public.empleados from public, anon, authenticated;
grant select (
  id, empresa_id, perfil_id, sucursal_id, departamento_id, puesto_id,
  supervisor_id, codigo_empleado, nombre_completo, cedula, correo, telefono,
  foto_url, fecha_ingreso, estado_laboral, salario, tipo_pago, activo,
  jornada_habilitada, created_at, updated_at
) on public.empleados to authenticated;

comment on function public.preview_next_employee_code_internal(uuid) is
  'Vista previa no reservante del siguiente codigo oficial; solo consulta secuencia y registry.';
comment on function public.claim_next_employee_code_internal(uuid, uuid, text) is
  'Compatibilidad para escrituras SQL: reclama el siguiente codigo exacto sin consultar PIN ni hashes.';
comment on function public.allocate_next_employee_code_internal(uuid, uuid) is
  'Autoridad transaccional de CREATE: reserva monotonicamente un codigo de seis digitos sin reutilizacion ni dependencia de PIN.';

commit;
