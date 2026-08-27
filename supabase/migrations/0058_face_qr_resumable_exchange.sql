-- A valid QR may safely resume its ephemeral capture session until the
-- invitation is completed, revoked, or expired. Final enrollment remains
-- single-use in service_complete_face_enrollment.
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
  v_now timestamptz:=now();
  v_resumed boolean:=false;
begin
  if lower(coalesce(p_token_hash,'')) !~ '^[0-9a-f]{64}$'
     or lower(coalesce(p_session_hash,'')) !~ '^[0-9a-f]{64}$' then
    raise exception using errcode='22023',message='FACE_TOKEN_INVALID';
  end if;

  select
    i.id,i.empresa_id,i.empleado_id,i.estado,i.expires_at,i.exchanged_at,
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
  if v_row.expires_at<=v_now then
    raise exception using errcode='22023',message='FACE_TOKEN_EXPIRED';
  end if;
  if not v_row.activo or lower(coalesce(v_row.estado_laboral,'activo'))
      in('desvinculado','inactivo') then
    raise exception using errcode='22023',message='FACE_EMPLOYEE_NOT_ELIGIBLE';
  end if;

  select s.*
  into v_session
  from public.face_enrollment_sessions s
  where s.invitacion_id=v_row.id
    and s.session_hash=lower(p_session_hash)
    and s.used_at is null
    and s.revoked_at is null
  order by s.created_at desc
  limit 1
  for update of s;

  if found then
    v_resumed:=true;
    if v_session.expires_at<=v_now then
      update public.face_enrollment_sessions s
      set expires_at=least(v_row.expires_at,v_now+interval '15 minutes')
      where s.id=v_session.id
      returning s.* into v_session;
    end if;
  else
    v_resumed:=v_row.exchanged_at is not null;
    update public.face_enrollment_sessions s
    set revoked_at=v_now
    where s.invitacion_id=v_row.id
      and s.used_at is null
      and s.revoked_at is null;

    insert into public.face_enrollment_sessions(
      invitacion_id,session_hash,expires_at
    ) values(
      v_row.id,
      lower(p_session_hash),
      least(v_row.expires_at,v_now+interval '15 minutes')
    ) returning * into v_session;
  end if;

  update public.face_enrollment_invitations i
  set exchanged_at=coalesce(i.exchanged_at,v_now)
  where i.id=v_row.id;

  insert into public.face_enrollment_audit(
    empresa_id,empleado_id,invitacion_id,accion,detalle
  ) values(
    v_row.empresa_id,
    v_row.empleado_id,
    v_row.id,
    'TOKEN_EXCHANGED',
    jsonb_build_object(
      'session_expires_at',v_session.expires_at,
      'resumed',v_resumed
    )
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
