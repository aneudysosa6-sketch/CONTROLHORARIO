begin;

-- QR enrollment is historical from this migration forward. Revoke active material without
-- deleting audit history, then make every old entry point fail closed.
update public.face_enrollment_sessions s
set revoked_at = coalesce(s.revoked_at, now())
from public.face_enrollment_invitations i
where i.id = s.invitacion_id
  and s.used_at is null
  and s.revoked_at is null;

update public.face_enrollment_invitations
set estado = 'REVOKED', revoked_at = coalesce(revoked_at, now())
where estado = 'PENDING';

create or replace function public.crear_invitacion_enrolamiento_facial(
  p_empleado uuid,
  p_token_hash text
) returns table(
  invitation_id uuid,
  employee_id uuid,
  employee_name text,
  expires_at timestamptz,
  face_status text
)
language plpgsql
security definer
set search_path=''
as $$
begin
  raise exception using errcode='0A000', message='FACE_QR_ENROLLMENT_DEPRECATED';
end;
$$;

create or replace function public.service_exchange_face_enrollment_token(
  p_token_hash text,
  p_session_hash text
) returns table(
  session_id uuid,
  invitation_id uuid,
  employee_name text,
  session_expires_at timestamptz,
  model_name text,
  embedding_dimension integer
)
language plpgsql
security definer
set search_path=''
as $$
begin
  raise exception using errcode='0A000', message='FACE_QR_ENROLLMENT_DEPRECATED';
end;
$$;

create or replace function public.service_complete_face_enrollment(
  p_session_hash text,
  p_embedding jsonb,
  p_capture_metadata jsonb default '{}'::jsonb
) returns table(
  employee_id uuid,
  enrolled_at timestamptz,
  model_name text,
  embedding_dimension integer
)
language plpgsql
security definer
set search_path=''
as $$
begin
  raise exception using errcode='0A000', message='FACE_QR_ENROLLMENT_DEPRECATED';
end;
$$;

revoke all on function public.crear_invitacion_enrolamiento_facial(uuid,text)
from public,anon,authenticated,service_role;
revoke all on function public.service_exchange_face_enrollment_token(text,text)
from public,anon,authenticated,service_role;
revoke all on function public.service_complete_face_enrollment(text,jsonb,jsonb)
from public,anon,authenticated,service_role;

alter table public.face_enrollment_audit
  drop constraint if exists face_enrollment_audit_action_0055;
alter table public.face_enrollment_audit
  add constraint face_enrollment_audit_action_0055 check(
    accion in(
      'INVITATION_CREATED','INVITATION_REVOKED','TOKEN_EXCHANGED',
      'ENROLLMENT_COMPLETED','DUPLICATE_REJECTED','FACE_RESET'
    )
  );

create table if not exists public.terminal_face_enrollment_idempotency(
  empresa_id uuid not null references public.companies(id) on delete cascade,
  idempotency_key uuid not null,
  dispositivo_id uuid not null references public.dispositivos_android(id) on delete restrict,
  empleado_id uuid not null references public.empleados(id) on delete restrict,
  embedding_sha256 text not null check(embedding_sha256 ~ '^[0-9a-f]{64}$'),
  enrolled_at timestamptz not null,
  created_at timestamptz not null default now(),
  primary key(empresa_id,idempotency_key)
);
alter table public.terminal_face_enrollment_idempotency enable row level security;
revoke all on public.terminal_face_enrollment_idempotency from public,anon,authenticated;
grant all on public.terminal_face_enrollment_idempotency to service_role;

create or replace function public.terminal_face_schedule_ready(
  p_empresa uuid,
  p_empleado uuid
) returns boolean
language sql
stable
security definer
set search_path=public,pg_catalog,pg_temp
as $$
  select exists(
    select 1
    from public.horarios_empleados h
    where h.empresa_id=p_empresa
      and h.empleado_id=p_empleado
      and h.activo
      and h.fecha_vigencia<=current_date
      and (h.fecha_fin is null or h.fecha_fin>=current_date)
      and h.hora_entrada is not null
      and h.hora_salida is not null
      and cardinality(h.dias_laborales) between 1 and 6
  )
$$;

create or replace function public.terminal_face_enrollment_pending_count(
  p_empresa uuid,
  p_dispositivo uuid
) returns integer
language sql
stable
security definer
set search_path=public,pg_catalog,pg_temp
as $$
  select count(*)::integer
  from public.empleados e
  where e.empresa_id=p_empresa
    and e.face_embedding is null
    and public.terminal_empleado_elegible(p_empresa,p_dispositivo,e.id)
    and public.terminal_face_schedule_ready(p_empresa,e.id)
$$;

create or replace function public.terminal_face_enrollment_lookup(
  p_empresa uuid,
  p_dispositivo uuid,
  p_codigo text
) returns jsonb
language plpgsql
stable
security definer
set search_path=public,pg_catalog,pg_temp
as $$
declare
  v_employee public.empleados%rowtype;
begin
  if p_empresa is null or p_dispositivo is null or coalesce(p_codigo,'') !~ '^[0-9]{6}$' or p_codigo='000000' then
    return jsonb_build_object('result','rejected','error_code','INVALID_PAYLOAD');
  end if;
  select * into v_employee
  from public.empleados
  where empresa_id=p_empresa and codigo_empleado=p_codigo
  limit 1;
  if not found then
    return jsonb_build_object('result','rejected','error_code','EMPLOYEE_NOT_FOUND');
  end if;
  if not v_employee.activo or lower(coalesce(v_employee.estado_laboral,'')) not in('activo','active')
     or not v_employee.jornada_habilitada then
    return jsonb_build_object('result','rejected','error_code','EMPLOYEE_NOT_ELIGIBLE');
  end if;
  if not public.terminal_empleado_elegible(p_empresa,p_dispositivo,v_employee.id) then
    return jsonb_build_object('result','rejected','error_code','TERMINAL_SCOPE_DENIED');
  end if;
  if not public.terminal_face_schedule_ready(p_empresa,v_employee.id) then
    return jsonb_build_object('result','rejected','error_code','SCHEDULE_DAYOFF_REQUIRED');
  end if;
  if v_employee.face_embedding is not null then
    return jsonb_build_object('result','rejected','error_code','FACE_ALREADY_REGISTERED');
  end if;
  return jsonb_build_object(
    'result','eligible',
    'employee_id',v_employee.id,
    'employee_code',v_employee.codigo_empleado,
    'employee_name',v_employee.nombre_completo
  );
end;
$$;

create or replace function public.confirmar_enrolamiento_facial_terminal(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public,extensions,pg_catalog,pg_temp
as $$
declare
  v_company uuid;
  v_device uuid;
  v_employee_id uuid;
  v_idempotency uuid;
  v_embedding jsonb;
  v_embedding_hash text;
  v_employee public.empleados%rowtype;
  v_prior public.terminal_face_enrollment_idempotency%rowtype;
  v_numeric_count integer;
  v_norm double precision;
  v_threshold double precision := 0.75;
  v_duplicate uuid;
  v_similarity double precision;
  v_enrolled_at timestamptz := now();
  v_pending integer;
begin
  begin
    v_company := (payload->>'empresa_id')::uuid;
    v_device := (payload->>'dispositivo_id')::uuid;
    v_employee_id := (payload->>'empleado_id')::uuid;
    v_idempotency := (payload->>'idempotency_key')::uuid;
  exception when others then
    return jsonb_build_object('result','rejected','error_code','INVALID_PAYLOAD');
  end;
  v_embedding := payload->'embedding';
  v_embedding_hash := lower(coalesce(payload->>'embedding_sha256',''));
  if v_embedding_hash !~ '^[0-9a-f]{64}$'
     or jsonb_typeof(v_embedding)<>'array'
     or jsonb_array_length(v_embedding)<>128
     or exists(select 1 from jsonb_array_elements(v_embedding) item where jsonb_typeof(item)<>'number') then
    return jsonb_build_object('result','rejected','error_code','FACE_EMBEDDING_INVALID');
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_company::text||v_idempotency::text,60));
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_company::text||v_employee_id::text,61));

  select * into v_prior
  from public.terminal_face_enrollment_idempotency
  where empresa_id=v_company and idempotency_key=v_idempotency
  for update;
  if found then
    if v_prior.dispositivo_id<>v_device or v_prior.empleado_id<>v_employee_id
       or v_prior.embedding_sha256<>v_embedding_hash then
      return jsonb_build_object('result','rejected','error_code','IDEMPOTENCY_KEY_REUSED');
    end if;
    select * into v_employee from public.empleados
    where empresa_id=v_company and id=v_employee_id;
    if v_employee.face_embedding is null then
      return jsonb_build_object('result','rejected','error_code','FACE_ENROLLMENT_REPLAY_REVOKED');
    end if;
    v_pending := public.terminal_face_enrollment_pending_count(v_company,v_device);
    return jsonb_build_object(
      'result','duplicate','employee_id',v_employee.id,'enrolled_at',v_prior.enrolled_at,
      'model_name','FaceNet-128','embedding_dimension',128,
      'embedding_sha256',v_embedding_hash,'face_embedding',v_employee.face_embedding,
      'pending_face_count',v_pending
    );
  end if;

  if not exists(
    select 1 from public.dispositivos_android d
    where d.id=v_device and d.empresa_id=v_company and d.estado='activo'
  ) then
    return jsonb_build_object('result','rejected','error_code','DEVICE_REVOKED');
  end if;
  select * into v_employee
  from public.empleados
  where id=v_employee_id and empresa_id=v_company
  for update;
  if not found or not public.terminal_empleado_elegible(v_company,v_device,v_employee_id) then
    return jsonb_build_object('result','rejected','error_code','TERMINAL_SCOPE_DENIED');
  end if;
  if not public.terminal_face_schedule_ready(v_company,v_employee_id) then
    return jsonb_build_object('result','rejected','error_code','SCHEDULE_DAYOFF_REQUIRED');
  end if;
  if v_employee.face_embedding is not null then
    return jsonb_build_object('result','rejected','error_code','FACE_ALREADY_REGISTERED');
  end if;

  select count(*),sqrt(sum(power((item#>>'{}')::double precision,2)))
  into v_numeric_count,v_norm
  from jsonb_array_elements(v_embedding) item;
  if v_numeric_count<>128 or v_norm is null or v_norm not between 0.98 and 1.02
     or exists(select 1 from jsonb_array_elements(v_embedding) item where abs((item#>>'{}')::double precision)>1.000001) then
    return jsonb_build_object('result','rejected','error_code','FACE_EMBEDDING_INVALID');
  end if;

  select coalesce(cs.face_match_threshold,0.75)::double precision into v_threshold
  from public.company_settings cs where cs.company_id=v_company;
  v_threshold := coalesce(v_threshold,0.75);
  select candidate.id,sum((a.value#>>'{}')::double precision*(b.value#>>'{}')::double precision)
  into v_duplicate,v_similarity
  from public.empleados candidate
  cross join lateral jsonb_array_elements(candidate.face_embedding) with ordinality a(value,position)
  join lateral jsonb_array_elements(v_embedding) with ordinality b(value,position) on b.position=a.position
  where candidate.empresa_id=v_company
    and candidate.id<>v_employee_id
    and candidate.activo
    and jsonb_typeof(candidate.face_embedding)='array'
    and jsonb_array_length(candidate.face_embedding)=128
  group by candidate.id
  having count(*)=128
  order by 2 desc
  limit 1;
  if v_duplicate is not null and v_similarity>=v_threshold then
    return jsonb_build_object('result','rejected','error_code','FACE_DUPLICATE');
  end if;

  update public.empleados
  set face_embedding=v_embedding,
      face_embedding_model='FaceNet-128',
      face_embedding_version=1,
      face_enrolled_at=v_enrolled_at,
      face_enrollment_source='ANDROID_TERMINAL',
      updated_at=v_enrolled_at
  where id=v_employee_id and empresa_id=v_company and face_embedding is null;
  if not found then
    return jsonb_build_object('result','rejected','error_code','FACE_ALREADY_REGISTERED');
  end if;

  insert into public.terminal_face_enrollment_idempotency(
    empresa_id,idempotency_key,dispositivo_id,empleado_id,embedding_sha256,enrolled_at
  ) values(v_company,v_idempotency,v_device,v_employee_id,v_embedding_hash,v_enrolled_at);
  insert into public.face_enrollment_audit(
    empresa_id,empleado_id,actor_id,accion,detalle
  ) values(
    v_company,v_employee_id,null,'ENROLLMENT_COMPLETED',
    jsonb_build_object('source','ANDROID_TERMINAL','device_id',v_device,'model','FaceNet-128','dimension',128)
  );
  v_pending := public.terminal_face_enrollment_pending_count(v_company,v_device);
  return jsonb_build_object(
    'result','accepted','employee_id',v_employee_id,'enrolled_at',v_enrolled_at,
    'model_name','FaceNet-128','embedding_dimension',128,
    'embedding_sha256',v_embedding_hash,'face_embedding',v_embedding,
    'pending_face_count',v_pending
  );
end;
$$;

create or replace function public.eliminar_rostro_empleado(p_empleado uuid)
returns boolean
language plpgsql
security definer
set search_path=public,pg_catalog,pg_temp
as $$
declare
  v_company uuid := public.obtener_empresa_actual();
  v_actor uuid := auth.uid();
  v_removed boolean := false;
begin
  if v_company is null or v_actor is null or not public.puede_operar_empleado_en_alcance(
    p_empleado,'empleados.biometria_invitar'
  ) then
    raise exception using errcode='42501',message='FACE_RESET_SCOPE_DENIED';
  end if;
  update public.face_enrollment_sessions s set revoked_at=coalesce(s.revoked_at,now())
  from public.face_enrollment_invitations i
  where i.id=s.invitacion_id and i.empresa_id=v_company and i.empleado_id=p_empleado
    and s.used_at is null and s.revoked_at is null;
  update public.face_enrollment_invitations
  set estado='REVOKED',revoked_at=coalesce(revoked_at,now()),revoked_by=v_actor
  where empresa_id=v_company and empleado_id=p_empleado and estado='PENDING';
  update public.empleados
  set face_embedding=null,face_embedding_model=null,face_embedding_version=null,
      face_enrolled_at=null,face_enrollment_source=null,updated_at=now()
  where empresa_id=v_company and id=p_empleado and face_embedding is not null;
  v_removed := found;
  if v_removed then
    insert into public.face_enrollment_audit(empresa_id,empleado_id,actor_id,accion,detalle)
    values(v_company,p_empleado,v_actor,'FACE_RESET',jsonb_build_object('source','WEB_ADMIN'));
  end if;
  return v_removed;
end;
$$;

revoke all on function public.terminal_face_schedule_ready(uuid,uuid) from public,anon,authenticated;
revoke all on function public.terminal_face_enrollment_pending_count(uuid,uuid) from public,anon,authenticated;
revoke all on function public.terminal_face_enrollment_lookup(uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.confirmar_enrolamiento_facial_terminal(jsonb) from public,anon,authenticated;
grant execute on function public.terminal_face_schedule_ready(uuid,uuid) to service_role;
grant execute on function public.terminal_face_enrollment_pending_count(uuid,uuid) to service_role;
grant execute on function public.terminal_face_enrollment_lookup(uuid,uuid,text) to service_role;
grant execute on function public.confirmar_enrolamiento_facial_terminal(jsonb) to service_role;
revoke all on function public.eliminar_rostro_empleado(uuid) from public,anon;
grant execute on function public.eliminar_rostro_empleado(uuid) to authenticated,service_role;

comment on function public.confirmar_enrolamiento_facial_terminal(jsonb) is
  'Atomic terminal-only FaceNet-128 enrollment after Edge credential and P-256 verification.';
comment on table public.face_enrollment_invitations is
  'Historical QR invitations. Creation and exchange are disabled by migration 0060.';

commit;
