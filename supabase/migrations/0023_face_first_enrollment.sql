begin;

-- Auditoria deliberadamente estructurada: no admite embedding, PIN, foto ni payload libre.
create table if not exists public.face_first_enrollment_audit (
  id bigint generated always as identity primary key,
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid,
  dispositivo_id uuid not null,
  employee_code text not null,
  idempotency_key uuid,
  event_name text not null default 'FACE_FIRST_ENROLLMENT',
  outcome text not null,
  validation_mode text not null default 'ONLINE_VERIFIED',
  responsible_user text not null default 'EMPLOYEE_SELF_SERVICE',
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  constraint face_first_enrollment_audit_employee_code_check
    check (employee_code ~ '^[0-9]{5,12}$'),
  constraint face_first_enrollment_audit_event_check
    check (event_name = 'FACE_FIRST_ENROLLMENT'),
  constraint face_first_enrollment_audit_outcome_check check (outcome in (
    'ENROLLED',
    'FACE_ALREADY_REGISTERED',
    'EMPLOYEE_NOT_FOUND',
    'EMPLOYEE_CHANGED',
    'EMPLOYEE_INACTIVE',
    'BRANCH_MISMATCH',
    'JOURNEY_DISABLED'
  )),
  constraint face_first_enrollment_audit_validation_mode_check
    check (validation_mode in ('ONLINE_VERIFIED', 'OFFLINE_CACHED')),
  constraint face_first_enrollment_audit_responsible_user_check
    check (responsible_user = 'EMPLOYEE_SELF_SERVICE'),
  constraint face_first_enrollment_audit_occurred_at_check
    check (occurred_at <= created_at + interval '10 minutes'),
  constraint face_first_enrollment_audit_device_scope_fk
    foreign key (empresa_id, dispositivo_id)
    references public.dispositivos_android(empresa_id, id) on delete restrict,
  constraint face_first_enrollment_audit_employee_scope_fk
    foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict
);

create index if not exists face_first_enrollment_audit_scope_idx
  on public.face_first_enrollment_audit(empresa_id, employee_code, created_at desc);

alter table public.face_first_enrollment_audit enable row level security;
revoke all on table public.face_first_enrollment_audit from public, anon, authenticated;
grant all on table public.face_first_enrollment_audit to service_role;
revoke all on sequence public.face_first_enrollment_audit_id_seq from public, anon, authenticated;
grant usage, select on sequence public.face_first_enrollment_audit_id_seq to service_role;

comment on table public.face_first_enrollment_audit is
  'Auditoria segura del primer registro facial. No almacena embedding, PIN, foto ni payload arbitrario.';

create or replace function public.initial_face_enrollment_internal(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_company uuid;
  v_device_id uuid;
  v_employee_id uuid;
  v_idempotency_key uuid;
  v_employee_code text := btrim(coalesce(payload ->> 'employee_code', ''));
  v_validation_mode text := btrim(coalesce(payload ->> 'validation_mode', ''));
  v_embedding jsonb := payload -> 'face_embedding';
  v_occurred_text text := btrim(coalesce(payload ->> 'occurred_at', ''));
  v_occurred_at timestamptz;
  v_device record;
  v_employee record;
  v_prior record;
  v_updated_at timestamptz;
  v_idempotency_inserted boolean;
begin
  if payload is null or jsonb_typeof(payload) <> 'object' then
    return jsonb_build_object('result', 'rejected', 'error_code', 'INVALID_PAYLOAD');
  end if;
  if v_occurred_text !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,9})?(Z|[+-][0-9]{2}:[0-9]{2})$' then
    return jsonb_build_object('result', 'rejected', 'error_code', 'INVALID_PAYLOAD');
  end if;

  begin
    v_company := nullif(btrim(payload ->> 'company_id'), '')::uuid;
    v_device_id := nullif(btrim(payload ->> 'device_id'), '')::uuid;
    v_employee_id := nullif(btrim(payload ->> 'employee_id'), '')::uuid;
    v_idempotency_key := nullif(btrim(payload ->> 'idempotency_key'), '')::uuid;
    v_occurred_at := v_occurred_text::timestamptz;
  exception
    when invalid_text_representation or invalid_datetime_format or datetime_field_overflow
  then
    return jsonb_build_object('result', 'rejected', 'error_code', 'INVALID_PAYLOAD');
  end;

  if v_company is null
     or v_device_id is null
     or v_employee_id is null
     or v_idempotency_key is null
     or v_occurred_at is null
     or v_employee_code !~ '^[0-9]{5,12}$'
     or v_validation_mode not in ('ONLINE_VERIFIED', 'OFFLINE_CACHED')
     or v_occurred_at > now() + interval '10 minutes'
  then
    return jsonb_build_object('result', 'rejected', 'error_code', 'INVALID_PAYLOAD');
  end if;

  if v_embedding is null or jsonb_typeof(v_embedding) <> 'array' then
    return jsonb_build_object('result', 'rejected', 'error_code', 'INVALID_PAYLOAD');
  end if;
  if jsonb_array_length(v_embedding) <> 128 then
    return jsonb_build_object('result', 'rejected', 'error_code', 'INVALID_PAYLOAD');
  end if;
  if exists (
    select 1
    from jsonb_array_elements(v_embedding) as item(value)
    where case
      when jsonb_typeof(item.value) <> 'number' then true
      else abs((item.value #>> '{}')::numeric) >
        1.7976931348623157e308::numeric
    end
  ) then
    return jsonb_build_object('result', 'rejected', 'error_code', 'INVALID_PAYLOAD');
  end if;

  select d.id, d.empresa_id, d.sucursal_id
  into v_device
  from public.dispositivos_android as d
  where d.id = v_device_id
    and d.empresa_id = v_company
    and d.estado = 'activo'
  for share;
  if not found then
    return jsonb_build_object('result', 'rejected', 'error_code', 'DEVICE_REVOKED');
  end if;

  -- Serializa reintentos de la misma operacion aun si llegan en requests concurrentes.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_company::text || ':' || v_idempotency_key::text, 0)
  );
  select i.empleado_id, e.codigo_empleado, e.updated_at
  into v_prior
  from public.employee_upload_idempotency as i
  join public.empleados as e
    on e.id = i.empleado_id
   and e.empresa_id = i.empresa_id
  where i.empresa_id = v_company
    and i.idempotency_key = v_idempotency_key;
  if found then
    if v_prior.codigo_empleado <> v_employee_code then
      return jsonb_build_object(
        'result', 'rejected',
        'error_code', 'IDEMPOTENCY_KEY_REUSED'
      );
    end if;
    if v_prior.empleado_id <> v_employee_id then
      insert into public.face_first_enrollment_audit(
        empresa_id, empleado_id, dispositivo_id, employee_code,
        idempotency_key, outcome, validation_mode, occurred_at
      ) values (
        v_company, v_prior.empleado_id, v_device_id, v_employee_code,
        v_idempotency_key, 'EMPLOYEE_CHANGED', v_validation_mode, v_occurred_at
      );
      return jsonb_build_object(
        'result', 'rejected',
        'error_code', 'EMPLOYEE_CHANGED'
      );
    end if;
    return jsonb_build_object(
      'result', 'duplicate',
      'remote_id', v_prior.empleado_id,
      'updated_at', v_prior.updated_at,
      'operation_applied', 'UPDATE'
    );
  end if;

  select e.id, e.empresa_id, e.sucursal_id, e.codigo_empleado,
         e.activo, e.estado_laboral, e.jornada_habilitada,
         e.face_embedding, e.updated_at
  into v_employee
  from public.empleados as e
  where e.empresa_id = v_company
    and e.id = v_employee_id
  for update;

  if not found then
    select e.id, e.updated_at
    into v_prior
    from public.empleados as e
    where e.empresa_id = v_company
      and e.codigo_empleado = v_employee_code
    for update;
    if found then
      insert into public.face_first_enrollment_audit(
        empresa_id, empleado_id, dispositivo_id, employee_code,
        idempotency_key, outcome, validation_mode, occurred_at
      ) values (
        v_company, v_prior.id, v_device_id, v_employee_code,
        v_idempotency_key, 'EMPLOYEE_CHANGED', v_validation_mode, v_occurred_at
      );
      return jsonb_build_object(
        'result', 'rejected',
        'error_code', 'EMPLOYEE_CHANGED',
        'remote_id', v_employee_id
      );
    end if;
    insert into public.face_first_enrollment_audit(
      empresa_id, empleado_id, dispositivo_id, employee_code,
      idempotency_key, outcome, validation_mode, occurred_at
    ) values (
      v_company, null, v_device_id, v_employee_code,
      v_idempotency_key, 'EMPLOYEE_NOT_FOUND', v_validation_mode, v_occurred_at
    );
    return jsonb_build_object('result', 'rejected', 'error_code', 'EMPLOYEE_NOT_FOUND');
  end if;

  if v_employee.codigo_empleado <> v_employee_code then
    insert into public.face_first_enrollment_audit(
      empresa_id, empleado_id, dispositivo_id, employee_code,
      idempotency_key, outcome, validation_mode, occurred_at
    ) values (
      v_company, v_employee.id, v_device_id, v_employee_code,
      v_idempotency_key, 'EMPLOYEE_CHANGED', v_validation_mode, v_occurred_at
    );
    return jsonb_build_object(
      'result', 'rejected',
      'error_code', 'EMPLOYEE_CHANGED',
      'remote_id', v_employee_id,
      'updated_at', v_employee.updated_at
    );
  end if;

  if not v_employee.activo or v_employee.estado_laboral <> 'activo' then
    insert into public.face_first_enrollment_audit(
      empresa_id, empleado_id, dispositivo_id, employee_code,
      idempotency_key, outcome, validation_mode, occurred_at
    ) values (
      v_company, v_employee.id, v_device_id, v_employee_code,
      v_idempotency_key, 'EMPLOYEE_INACTIVE', v_validation_mode, v_occurred_at
    );
    return jsonb_build_object(
      'result', 'rejected',
      'error_code', 'EMPLOYEE_INACTIVE',
      'remote_id', v_employee.id,
      'updated_at', v_employee.updated_at
    );
  end if;

  if v_device.sucursal_id is not null
     and v_employee.sucursal_id is distinct from v_device.sucursal_id
  then
    insert into public.face_first_enrollment_audit(
      empresa_id, empleado_id, dispositivo_id, employee_code,
      idempotency_key, outcome, validation_mode, occurred_at
    ) values (
      v_company, v_employee.id, v_device_id, v_employee_code,
      v_idempotency_key, 'BRANCH_MISMATCH', v_validation_mode, v_occurred_at
    );
    return jsonb_build_object(
      'result', 'rejected',
      'error_code', 'BRANCH_MISMATCH',
      'remote_id', v_employee.id,
      'updated_at', v_employee.updated_at
    );
  end if;

  if v_employee.jornada_habilitada is not true then
    insert into public.face_first_enrollment_audit(
      empresa_id, empleado_id, dispositivo_id, employee_code,
      idempotency_key, outcome, validation_mode, occurred_at
    ) values (
      v_company, v_employee.id, v_device_id, v_employee_code,
      v_idempotency_key, 'JOURNEY_DISABLED', v_validation_mode, v_occurred_at
    );
    return jsonb_build_object(
      'result', 'rejected',
      'error_code', 'JOURNEY_DISABLED',
      'remote_id', v_employee.id,
      'updated_at', v_employee.updated_at
    );
  end if;

  if v_employee.face_embedding is not null then
    insert into public.face_first_enrollment_audit(
      empresa_id, empleado_id, dispositivo_id, employee_code,
      idempotency_key, outcome, validation_mode, occurred_at
    ) values (
      v_company, v_employee.id, v_device_id, v_employee_code,
      v_idempotency_key, 'FACE_ALREADY_REGISTERED', v_validation_mode, v_occurred_at
    );
    return jsonb_build_object(
      'result', 'rejected',
      'error_code', 'FACE_ALREADY_REGISTERED',
      'remote_id', v_employee.id,
      'updated_at', v_employee.updated_at
    );
  end if;

  insert into public.employee_upload_idempotency(
    empresa_id, idempotency_key, empleado_id, operation
  ) values (
    v_company, v_idempotency_key, v_employee.id, 'UPDATE'
  )
  on conflict (empresa_id, idempotency_key) do nothing
  returning true into v_idempotency_inserted;
  if not coalesce(v_idempotency_inserted, false) then
    select i.empleado_id, e.codigo_empleado, e.updated_at
    into v_prior
    from public.employee_upload_idempotency as i
    join public.empleados as e
      on e.id = i.empleado_id
     and e.empresa_id = i.empresa_id
    where i.empresa_id = v_company
      and i.idempotency_key = v_idempotency_key;
    if v_prior.codigo_empleado = v_employee_code then
      return jsonb_build_object(
        'result', 'duplicate',
        'remote_id', v_prior.empleado_id,
        'updated_at', v_prior.updated_at,
        'operation_applied', 'UPDATE'
      );
    end if;
    return jsonb_build_object('result', 'rejected', 'error_code', 'IDEMPOTENCY_KEY_REUSED');
  end if;

  update public.empleados
  set face_embedding = v_embedding
  where id = v_employee.id
    and empresa_id = v_company
    and face_embedding is null
  returning updated_at into v_updated_at;
  if not found then
    delete from public.employee_upload_idempotency
    where empresa_id = v_company
      and idempotency_key = v_idempotency_key;
    select updated_at into v_updated_at
    from public.empleados
    where id = v_employee.id and empresa_id = v_company;
    insert into public.face_first_enrollment_audit(
      empresa_id, empleado_id, dispositivo_id, employee_code,
      idempotency_key, outcome, validation_mode, occurred_at
    ) values (
      v_company, v_employee.id, v_device_id, v_employee_code,
      v_idempotency_key, 'FACE_ALREADY_REGISTERED', v_validation_mode, v_occurred_at
    );
    return jsonb_build_object(
      'result', 'rejected',
      'error_code', 'FACE_ALREADY_REGISTERED',
      'remote_id', v_employee.id,
      'updated_at', v_updated_at
    );
  end if;

  insert into public.face_first_enrollment_audit(
    empresa_id, empleado_id, dispositivo_id, employee_code,
    idempotency_key, outcome, validation_mode, occurred_at
  ) values (
    v_company, v_employee.id, v_device_id, v_employee_code,
    v_idempotency_key, 'ENROLLED', v_validation_mode, v_occurred_at
  );

  return jsonb_build_object(
    'result', 'accepted',
    'remote_id', v_employee.id,
    'updated_at', v_updated_at,
    'operation_applied', 'UPDATE'
  );
end;
$$;

revoke all on function public.initial_face_enrollment_internal(jsonb)
  from public, anon, authenticated;
grant execute on function public.initial_face_enrollment_internal(jsonb)
  to service_role;

comment on function public.initial_face_enrollment_internal(jsonb) is
  'Primer registro facial atomico para Edge employee-upsert; solo service_role y sin reemplazo.';

commit;
