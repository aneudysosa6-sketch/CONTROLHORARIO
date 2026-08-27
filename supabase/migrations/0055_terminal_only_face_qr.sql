-- Terminal-only Android and Web QR facial enrollment.
-- Raw invitation/session tokens and biometric images are never persisted.

alter table public.company_settings
  add column if not exists face_enrollment_invitation_ttl_hours integer not null default 24,
  add column if not exists terminal_offline_lease_hours integer not null default 24;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'company_settings_face_invitation_ttl_0055'
  ) then
    alter table public.company_settings
      add constraint company_settings_face_invitation_ttl_0055
      check (face_enrollment_invitation_ttl_hours between 1 and 24);
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'company_settings_terminal_offline_lease_0055'
  ) then
    alter table public.company_settings
      add constraint company_settings_terminal_offline_lease_0055
      check (terminal_offline_lease_hours between 1 and 72);
  end if;
end
$$;

alter table public.empleados
  add column if not exists face_embedding_model text,
  add column if not exists face_embedding_version integer,
  add column if not exists face_enrolled_at timestamptz,
  add column if not exists face_enrollment_source text;

insert into public.permisos(codigo,nombre,descripcion,modulo,activo)
values(
  'empleados.biometria_invitar',
  'Invitar enrolamiento facial',
  'Genera o revoca invitaciones QR de enrolamiento facial para empleados dentro del alcance autorizado.',
  'empleados',
  true
)
on conflict(codigo) do update set
  nombre=excluded.nombre,
  descripcion=excluded.descripcion,
  modulo=excluded.modulo,
  activo=true;

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'empresa'
from public.roles r
join public.permisos p on p.codigo='empleados.biometria_invitar'
where r.is_active
  and upper(translate(trim(coalesce(r.code,r.name)),'ÁÉÍÓÚáéíóú','AEIOUaeiou'))
      in ('ADMIN','ADMINISTRADOR','ADMINISTRATOR')
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

create table if not exists public.face_enrollment_invitations(
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete cascade,
  empleado_id uuid not null references public.empleados(id) on delete cascade,
  token_hash text not null unique,
  estado text not null default 'PENDING',
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles(id) on delete set null,
  used_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid references public.profiles(id) on delete set null,
  model_name text not null default 'FaceNet-128',
  model_version integer not null default 1,
  embedding_dimension integer not null default 128,
  constraint face_enrollment_invitation_hash_0055
    check(token_hash ~ '^[0-9a-f]{64}$'),
  constraint face_enrollment_invitation_state_0055
    check(estado in('PENDING','USED','REVOKED')),
  constraint face_enrollment_invitation_expiry_0055
    check(expires_at > created_at),
  constraint face_enrollment_invitation_model_0055
    check(model_name='FaceNet-128' and model_version=1 and embedding_dimension=128)
);

create unique index if not exists face_enrollment_one_pending_employee_0055
on public.face_enrollment_invitations(empleado_id)
where estado='PENDING';

create index if not exists face_enrollment_invitation_company_0055
on public.face_enrollment_invitations(empresa_id,empleado_id,created_at desc);

create table if not exists public.face_enrollment_sessions(
  id uuid primary key default extensions.gen_random_uuid(),
  invitacion_id uuid not null references public.face_enrollment_invitations(id) on delete cascade,
  session_hash text not null unique,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  used_at timestamptz,
  revoked_at timestamptz,
  constraint face_enrollment_session_hash_0055
    check(session_hash ~ '^[0-9a-f]{64}$'),
  constraint face_enrollment_session_expiry_0055
    check(expires_at > created_at)
);

create index if not exists face_enrollment_session_invitation_0055
on public.face_enrollment_sessions(invitacion_id,created_at desc);

create table if not exists public.face_enrollment_audit(
  id bigint generated always as identity primary key,
  empresa_id uuid not null references public.companies(id) on delete cascade,
  empleado_id uuid not null references public.empleados(id) on delete cascade,
  invitacion_id uuid references public.face_enrollment_invitations(id) on delete set null,
  actor_id uuid references public.profiles(id) on delete set null,
  accion text not null,
  detalle jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint face_enrollment_audit_action_0055 check(
    accion in(
      'INVITATION_CREATED','INVITATION_REVOKED','TOKEN_EXCHANGED',
      'ENROLLMENT_COMPLETED','DUPLICATE_REJECTED'
    )
  )
);

alter table public.face_enrollment_invitations enable row level security;
alter table public.face_enrollment_sessions enable row level security;
alter table public.face_enrollment_audit enable row level security;

revoke all on public.face_enrollment_invitations from public,anon,authenticated;
revoke all on public.face_enrollment_sessions from public,anon,authenticated;
revoke all on public.face_enrollment_audit from public,anon,authenticated;
grant all on public.face_enrollment_invitations to service_role;
grant all on public.face_enrollment_sessions to service_role;
grant all on public.face_enrollment_audit to service_role;

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
declare
  v_empresa uuid := public.obtener_empresa_actual();
  v_actor uuid := auth.uid();
  v_empleado public.empleados%rowtype;
  v_ttl integer;
  v_invitacion public.face_enrollment_invitations%rowtype;
  v_revocada uuid;
begin
  if v_actor is null or v_empresa is null then
    raise exception using errcode='42501',message='FACE_INVITATION_AUTH_REQUIRED';
  end if;
  if p_token_hash is null or lower(p_token_hash) !~ '^[0-9a-f]{64}$' then
    raise exception using errcode='22023',message='FACE_INVITATION_TOKEN_INVALID';
  end if;
  if not public.puede_operar_empleado_en_alcance(
    p_empleado,
    'empleados.biometria_invitar'
  ) then
    raise exception using errcode='42501',message='FACE_INVITATION_SCOPE_DENIED';
  end if;

  select e.* into v_empleado
  from public.empleados e
  where e.id=p_empleado
    and e.empresa_id=v_empresa
    and e.activo
    and lower(coalesce(e.estado_laboral,'activo')) not in('desvinculado','inactivo')
  for update;
  if not found then
    raise exception using errcode='P0002',message='FACE_INVITATION_EMPLOYEE_NOT_ELIGIBLE';
  end if;

  select coalesce(cs.face_enrollment_invitation_ttl_hours,24)
  into v_ttl
  from public.company_settings cs
  where cs.company_id=v_empresa;
  v_ttl:=least(24,greatest(1,coalesce(v_ttl,24)));

  for v_revocada in
    update public.face_enrollment_invitations i
    set estado='REVOKED',revoked_at=now(),revoked_by=v_actor
    where i.empresa_id=v_empresa
      and i.empleado_id=p_empleado
      and i.estado='PENDING'
    returning i.id
  loop
    insert into public.face_enrollment_audit(
      empresa_id,empleado_id,invitacion_id,actor_id,accion,detalle
    ) values(
      v_empresa,p_empleado,v_revocada,v_actor,'INVITATION_REVOKED',
      jsonb_build_object('reason','REGENERATED')
    );
  end loop;

  insert into public.face_enrollment_invitations(
    empresa_id,empleado_id,token_hash,expires_at,created_by
  ) values(
    v_empresa,p_empleado,lower(p_token_hash),
    now()+make_interval(hours=>v_ttl),v_actor
  ) returning * into v_invitacion;

  insert into public.face_enrollment_audit(
    empresa_id,empleado_id,invitacion_id,actor_id,accion,detalle
  ) values(
    v_empresa,p_empleado,v_invitacion.id,v_actor,'INVITATION_CREATED',
    jsonb_build_object('expires_at',v_invitacion.expires_at,'model','FaceNet-128')
  );

  return query select
    v_invitacion.id,
    v_empleado.id,
    v_empleado.nombre_completo,
    v_invitacion.expires_at,
    case when v_empleado.face_embedding is null then 'PENDING' else 'ENROLLED' end;
end;
$$;

revoke all on function public.crear_invitacion_enrolamiento_facial(uuid,text)
from public,anon;
grant execute on function public.crear_invitacion_enrolamiento_facial(uuid,text)
to authenticated;

create or replace function public.estado_enrolamiento_facial_empleado(
  p_empleado uuid
) returns table(
  employee_id uuid,
  face_status text,
  invitation_status text,
  invitation_expires_at timestamptz,
  face_enrolled_at timestamptz
)
language plpgsql
stable
security definer
set search_path=''
as $$
declare
  v_empresa uuid := public.obtener_empresa_actual();
begin
  if v_empresa is null or (
    not public.puede_operar_empleado_en_alcance(p_empleado,'empleados.biometria_ver')
    and not public.puede_operar_empleado_en_alcance(
      p_empleado,'empleados.biometria_invitar'
    )
  ) then
    raise exception using errcode='42501',message='FACE_STATUS_SCOPE_DENIED';
  end if;

  return query
  select
    e.id,
    case when e.face_embedding is null then 'PENDING' else 'ENROLLED' end,
    coalesce(
      case
        when i.estado='PENDING' and i.expires_at<=now() then 'EXPIRED'
        when i.estado='PENDING' then 'ACTIVE'
        else i.estado
      end,
      'NONE'
    ),
    i.expires_at,
    e.face_enrolled_at
  from public.empleados e
  left join lateral(
    select x.estado,x.expires_at
    from public.face_enrollment_invitations x
    where x.empresa_id=e.empresa_id and x.empleado_id=e.id
    order by x.created_at desc
    limit 1
  ) i on true
  where e.id=p_empleado and e.empresa_id=v_empresa;
end;
$$;

revoke all on function public.estado_enrolamiento_facial_empleado(uuid)
from public,anon;
grant execute on function public.estado_enrolamiento_facial_empleado(uuid)
to authenticated;

create or replace function public.revocar_invitacion_enrolamiento_facial(
  p_empleado uuid,
  p_motivo text default 'ADMIN_REVOKED'
) returns boolean
language plpgsql
security definer
set search_path=''
as $$
declare
  v_empresa uuid:=public.obtener_empresa_actual();
  v_actor uuid:=auth.uid();
  v_invitacion uuid;
begin
  if v_actor is null or v_empresa is null then
    raise exception using errcode='42501',message='FACE_INVITATION_AUTH_REQUIRED';
  end if;
  if not public.puede_operar_empleado_en_alcance(
    p_empleado,'empleados.biometria_invitar'
  ) then
    raise exception using errcode='42501',message='FACE_INVITATION_SCOPE_DENIED';
  end if;

  update public.face_enrollment_invitations i
  set estado='REVOKED',revoked_at=now(),revoked_by=v_actor
  where i.empresa_id=v_empresa
    and i.empleado_id=p_empleado
    and i.estado='PENDING'
  returning i.id into v_invitacion;

  if v_invitacion is null then return false; end if;

  update public.face_enrollment_sessions s
  set revoked_at=now()
  where s.invitacion_id=v_invitacion
    and s.used_at is null
    and s.revoked_at is null;

  insert into public.face_enrollment_audit(
    empresa_id,empleado_id,invitacion_id,actor_id,accion,detalle
  ) values(
    v_empresa,p_empleado,v_invitacion,v_actor,'INVITATION_REVOKED',
    jsonb_build_object('reason',left(coalesce(nullif(btrim(p_motivo),''),'ADMIN_REVOKED'),120))
  );
  return true;
end;
$$;

revoke all on function public.revocar_invitacion_enrolamiento_facial(uuid,text)
from public,anon;
grant execute on function public.revocar_invitacion_enrolamiento_facial(uuid,text)
to authenticated;

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
declare
  v_row record;
  v_session public.face_enrollment_sessions%rowtype;
begin
  if lower(coalesce(p_token_hash,'')) !~ '^[0-9a-f]{64}$'
     or lower(coalesce(p_session_hash,'')) !~ '^[0-9a-f]{64}$' then
    raise exception using errcode='22023',message='FACE_TOKEN_INVALID';
  end if;

  select
    i.id,i.empresa_id,i.empleado_id,i.estado,i.expires_at,
    i.model_name,i.embedding_dimension,e.nombre_completo,e.activo,e.estado_laboral
  into v_row
  from public.face_enrollment_invitations i
  join public.empleados e
    on e.id=i.empleado_id and e.empresa_id=i.empresa_id
  where i.token_hash=lower(p_token_hash)
  for update of i;

  if not found then
    raise exception using errcode='P0002',message='FACE_TOKEN_INVALID';
  end if;
  if v_row.estado<>'PENDING' then
    raise exception using errcode='22023',message='FACE_TOKEN_ALREADY_USED_OR_REVOKED';
  end if;
  if v_row.expires_at<=now() then
    raise exception using errcode='22023',message='FACE_TOKEN_EXPIRED';
  end if;
  if not v_row.activo or lower(coalesce(v_row.estado_laboral,'activo'))
      in('desvinculado','inactivo') then
    raise exception using errcode='22023',message='FACE_EMPLOYEE_NOT_ELIGIBLE';
  end if;

  update public.face_enrollment_sessions s
  set revoked_at=now()
  where s.invitacion_id=v_row.id
    and s.used_at is null
    and s.revoked_at is null;

  insert into public.face_enrollment_sessions(
    invitacion_id,session_hash,expires_at
  ) values(
    v_row.id,
    lower(p_session_hash),
    least(v_row.expires_at,now()+interval '15 minutes')
  ) returning * into v_session;

  insert into public.face_enrollment_audit(
    empresa_id,empleado_id,invitacion_id,accion,detalle
  ) values(
    v_row.empresa_id,v_row.empleado_id,v_row.id,'TOKEN_EXCHANGED',
    jsonb_build_object('session_expires_at',v_session.expires_at)
  );

  return query select
    v_session.id,v_row.id,v_row.nombre_completo,v_session.expires_at,
    v_row.model_name,v_row.embedding_dimension;
end;
$$;

revoke all on function public.service_exchange_face_enrollment_token(text,text)
from public,anon,authenticated;
grant execute on function public.service_exchange_face_enrollment_token(text,text)
to service_role;

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
declare
  v_row record;
  v_numeric_count integer;
  v_norm double precision;
  v_threshold double precision;
  v_duplicate uuid;
  v_similarity double precision;
  v_enrolled_at timestamptz:=now();
begin
  if lower(coalesce(p_session_hash,'')) !~ '^[0-9a-f]{64}$' then
    raise exception using errcode='22023',message='FACE_SESSION_INVALID';
  end if;

  select
    s.id session_id,s.expires_at session_expires_at,s.used_at,s.revoked_at,
    i.id invitation_id,i.empresa_id,i.empleado_id,i.estado invitation_state,
    i.expires_at invitation_expires_at,i.model_name,i.embedding_dimension,
    e.activo,e.estado_laboral
  into v_row
  from public.face_enrollment_sessions s
  join public.face_enrollment_invitations i on i.id=s.invitacion_id
  join public.empleados e
    on e.id=i.empleado_id and e.empresa_id=i.empresa_id
  where s.session_hash=lower(p_session_hash)
  for update of s,i,e;

  if not found or v_row.used_at is not null or v_row.revoked_at is not null then
    raise exception using errcode='22023',message='FACE_SESSION_INVALID';
  end if;
  if v_row.session_expires_at<=now() then
    raise exception using errcode='22023',message='FACE_SESSION_EXPIRED';
  end if;
  if v_row.invitation_state<>'PENDING' or v_row.invitation_expires_at<=now() then
    raise exception using errcode='22023',message='FACE_TOKEN_ALREADY_USED_OR_EXPIRED';
  end if;
  if not v_row.activo or lower(coalesce(v_row.estado_laboral,'activo'))
      in('desvinculado','inactivo') then
    raise exception using errcode='22023',message='FACE_EMPLOYEE_NOT_ELIGIBLE';
  end if;
  if jsonb_typeof(p_embedding)<>'array'
     or jsonb_array_length(p_embedding)<>128 then
    raise exception using errcode='22023',message='FACE_EMBEDDING_INVALID';
  end if;

  select
    count(*) filter(where jsonb_typeof(value)='number'),
    sqrt(sum(
      case when jsonb_typeof(value)='number'
        then power((value#>>'{}')::double precision,2)
        else 0
      end
    ))
  into v_numeric_count,v_norm
  from jsonb_array_elements(p_embedding);

  if v_numeric_count<>128 or v_norm is null or v_norm not between 0.98 and 1.02
     or exists(
       select 1 from jsonb_array_elements(p_embedding) value
       where jsonb_typeof(value)<>'number'
          or abs((value#>>'{}')::double precision)>1.000001
     ) then
    raise exception using errcode='22023',message='FACE_EMBEDDING_INVALID';
  end if;

  select coalesce(cs.face_match_threshold,0.75)::double precision
  into v_threshold
  from public.company_settings cs
  where cs.company_id=v_row.empresa_id;
  v_threshold:=coalesce(v_threshold,0.75);

  select candidate.id,
    sum(
      case when jsonb_typeof(a.value)='number' and jsonb_typeof(b.value)='number'
        then (a.value#>>'{}')::double precision*(b.value#>>'{}')::double precision
        else 0
      end
    )
  into v_duplicate,v_similarity
  from public.empleados candidate
  cross join lateral jsonb_array_elements(candidate.face_embedding)
    with ordinality a(value,position)
  join lateral jsonb_array_elements(p_embedding)
    with ordinality b(value,position)
    on b.position=a.position
  where candidate.empresa_id=v_row.empresa_id
    and candidate.id<>v_row.empleado_id
    and candidate.activo
    and jsonb_typeof(candidate.face_embedding)='array'
    and jsonb_array_length(candidate.face_embedding)=128
  group by candidate.id
  having count(*) filter(
    where jsonb_typeof(a.value)='number' and jsonb_typeof(b.value)='number'
  )=128
  order by 2 desc
  limit 1;

  if v_duplicate is not null and v_similarity>=v_threshold then
    insert into public.face_enrollment_audit(
      empresa_id,empleado_id,invitacion_id,accion,detalle
    ) values(
      v_row.empresa_id,v_row.empleado_id,v_row.invitation_id,
      'DUPLICATE_REJECTED',
      jsonb_build_object('matched_employee_id',v_duplicate,'threshold',v_threshold)
    );
    raise exception using errcode='23505',message='FACE_DUPLICATE';
  end if;

  update public.empleados e
  set face_embedding=p_embedding,
      face_embedding_model='FaceNet-128',
      face_embedding_version=1,
      face_enrolled_at=v_enrolled_at,
      face_enrollment_source='WEB_QR',
      updated_at=v_enrolled_at
  where e.id=v_row.empleado_id and e.empresa_id=v_row.empresa_id;

  update public.face_enrollment_sessions
  set used_at=v_enrolled_at
  where id=v_row.session_id;

  update public.face_enrollment_invitations
  set estado='USED',used_at=v_enrolled_at
  where id=v_row.invitation_id;

  update public.face_enrollment_invitations
  set estado='REVOKED',revoked_at=v_enrolled_at
  where empleado_id=v_row.empleado_id
    and id<>v_row.invitation_id
    and estado='PENDING';

  insert into public.face_enrollment_audit(
    empresa_id,empleado_id,invitacion_id,accion,detalle
  ) values(
    v_row.empresa_id,v_row.empleado_id,v_row.invitation_id,
    'ENROLLMENT_COMPLETED',
    jsonb_build_object(
      'model','FaceNet-128',
      'dimension',128,
      'capture',coalesce(p_capture_metadata,'{}'::jsonb)
    )
  );

  return query select
    v_row.empleado_id,v_enrolled_at,'FaceNet-128'::text,128;
end;
$$;

revoke all on function public.service_complete_face_enrollment(text,jsonb,jsonb)
from public,anon,authenticated;
grant execute on function public.service_complete_face_enrollment(text,jsonb,jsonb)
to service_role;

comment on table public.face_enrollment_invitations is
  'Invitaciones Web QR de un uso; solo se persiste SHA-256 del token.';
comment on table public.face_enrollment_sessions is
  'Sesiones efímeras de captura; solo se persiste SHA-256 del token.';
comment on column public.empleados.face_embedding_model is
  'Modelo compatible con Android: FaceNet-128, entrada 160x160 RGB gris normalizada.';