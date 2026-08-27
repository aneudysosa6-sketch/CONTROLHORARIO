begin;

insert into public.permisos (codigo, nombre, descripcion, modulo, activo)
values (
  'mensajes.administrar',
  'Administrar mensajes a empleados',
  'Permite enviar un mensaje efimero a un empleado para su siguiente movimiento de jornada.',
  'mensajes',
  true
)
on conflict (codigo) do update set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  modulo = excluded.modulo,
  activo = excluded.activo;

with permiso as (
  select id from public.permisos where codigo = 'mensajes.administrar'
),
admin_roles as (
  select id from public.roles
  where is_active = true
    and private.normalizar_codigo_rol(code) = 'ADMIN'
)
insert into public.rol_permisos (rol_id, permiso_id, permitido, alcance)
select role.id, permission.id, true, 'empresa'
from admin_roles role cross join permiso permission
on conflict (rol_id, permiso_id) do update set
  permitido = excluded.permitido,
  alcance = excluded.alcance;

create table if not exists public.mensajes_empleados (
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  tipo text not null check (tipo in ('TEXTO', 'VOZ_SISTEMA', 'VOZ_GRABADA')),
  contenido_texto text,
  audio_object_path text,
  audio_duracion_segundos smallint,
  idempotency_key uuid not null,
  creado_por uuid not null references public.profiles(id) on delete restrict,
  creado_en timestamptz not null default statement_timestamp(),
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  constraint mensajes_empleados_contenido_check check (
    (
      tipo in ('TEXTO', 'VOZ_SISTEMA')
      and nullif(btrim(contenido_texto), '') is not null
      and audio_object_path is null
      and audio_duracion_segundos is null
    )
    or (
      tipo = 'VOZ_GRABADA'
      and contenido_texto is null
      and nullif(btrim(audio_object_path), '') is not null
      and audio_duracion_segundos between 1 and 30
    )
  ),
  constraint mensajes_empleados_idempotency_unique
    unique (empresa_id, idempotency_key)
);

create unique index if not exists mensajes_empleados_un_pendiente_idx
  on public.mensajes_empleados (empresa_id, empleado_id);

create index if not exists mensajes_empleados_sync_idx
  on public.mensajes_empleados (empresa_id, creado_en, empleado_id);

create table if not exists public.mensajes_empleados_recibidos (
  mensaje_id uuid primary key,
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  dispositivo_id uuid not null,
  idempotency_key uuid not null,
  recibido_en timestamptz not null default statement_timestamp(),
  foreign key (empresa_id, empleado_id)
    references public.empleados(empresa_id, id) on delete restrict,
  foreign key (empresa_id, dispositivo_id)
    references public.dispositivos_android(empresa_id, id) on delete restrict,
  constraint mensajes_recibidos_idempotency_unique
    unique (empresa_id, idempotency_key)
);

comment on table public.mensajes_empleados is
  'Cola efimera: contiene como maximo un mensaje pendiente por empleado y se elimina al confirmar.';
comment on table public.mensajes_empleados_recibidos is
  'Tombstone tecnico sin contenido para idempotencia multi-terminal; no es historial del mensaje.';

alter table public.mensajes_empleados enable row level security;
alter table public.mensajes_empleados force row level security;
alter table public.mensajes_empleados_recibidos enable row level security;
alter table public.mensajes_empleados_recibidos force row level security;

revoke all on public.mensajes_empleados, public.mensajes_empleados_recibidos
  from public, anon, authenticated;
grant all on public.mensajes_empleados, public.mensajes_empleados_recibidos
  to service_role;

create or replace function public.crear_mensaje_empleado(
  p_empleado uuid,
  p_tipo text,
  p_contenido_texto text,
  p_audio_object_path text,
  p_audio_duracion_segundos integer,
  p_idempotency_key uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_empresa uuid := public.obtener_empresa_actual();
  v_actor uuid := auth.uid();
  v_empleado public.empleados%rowtype;
  v_existente public.mensajes_empleados%rowtype;
  v_tipo text := upper(btrim(coalesce(p_tipo, '')));
  v_mensaje public.mensajes_empleados%rowtype;
begin
  if v_empresa is null or v_actor is null then
    raise exception using errcode = '28000', message = 'AUTH_SESSION_REQUIRED';
  end if;
  if not public.tiene_permiso('mensajes.administrar') then
    raise exception using errcode = '42501', message = 'EMPLOYEE_MESSAGE_PERMISSION_DENIED';
  end if;
  if p_empleado is null or p_idempotency_key is null then
    raise exception using errcode = '22023', message = 'EMPLOYEE_MESSAGE_REQUIRED_FIELDS';
  end if;

  select * into v_existente
  from public.mensajes_empleados message
  where message.empresa_id = v_empresa
    and message.idempotency_key = p_idempotency_key;
  if found then
    if v_existente.empleado_id <> p_empleado
       or v_existente.tipo <> v_tipo
       or coalesce(v_existente.contenido_texto, '') <> coalesce(nullif(btrim(p_contenido_texto), ''), '')
       or coalesce(v_existente.audio_object_path, '') <> coalesce(nullif(btrim(p_audio_object_path), ''), '')
       or coalesce(v_existente.audio_duracion_segundos, 0) <> coalesce(p_audio_duracion_segundos, 0)
    then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return jsonb_build_object('id', v_existente.id, 'status', 'PENDIENTE', 'idempotent_replay', true);
  end if;

  select * into v_empleado
  from public.empleados employee
  where employee.empresa_id = v_empresa
    and employee.id = p_empleado
  for update;
  if not found then
    raise exception using errcode = 'P4901', message = 'EMPLOYEE_NOT_FOUND';
  end if;
  if not v_empleado.activo
     or lower(coalesce(v_empleado.estado_laboral, '')) not in (
       'activo', 'active', 'licencia', 'vacaciones'
     )
  then
    raise exception using errcode = 'P4902', message = 'EMPLOYEE_MESSAGE_STATUS_DENIED';
  end if;
  if exists (
    select 1 from public.mensajes_empleados pending
    where pending.empresa_id = v_empresa
      and pending.empleado_id = p_empleado
  ) then
    raise exception using errcode = 'P4903', message = 'EMPLOYEE_MESSAGE_ALREADY_PENDING';
  end if;
  if v_tipo not in ('TEXTO', 'VOZ_SISTEMA', 'VOZ_GRABADA') then
    raise exception using errcode = '22023', message = 'EMPLOYEE_MESSAGE_TYPE_INVALID';
  end if;
  if v_tipo in ('TEXTO', 'VOZ_SISTEMA')
     and nullif(btrim(p_contenido_texto), '') is null
  then
    raise exception using errcode = '22023', message = 'EMPLOYEE_MESSAGE_TEXT_REQUIRED';
  end if;
  if v_tipo = 'VOZ_GRABADA' and (
    nullif(btrim(p_audio_object_path), '') is null
    or p_audio_duracion_segundos not between 1 and 30
  ) then
    raise exception using errcode = '22023', message = 'EMPLOYEE_MESSAGE_AUDIO_INVALID';
  end if;

  insert into public.mensajes_empleados (
    empresa_id, empleado_id, tipo, contenido_texto, audio_object_path,
    audio_duracion_segundos, idempotency_key, creado_por
  ) values (
    v_empresa, p_empleado, v_tipo,
    case when v_tipo in ('TEXTO', 'VOZ_SISTEMA') then p_contenido_texto else null end,
    case when v_tipo = 'VOZ_GRABADA' then btrim(p_audio_object_path) else null end,
    case when v_tipo = 'VOZ_GRABADA' then p_audio_duracion_segundos else null end,
    p_idempotency_key, v_actor
  )
  returning * into v_mensaje;

  return jsonb_build_object(
    'id', v_mensaje.id,
    'status', 'PENDIENTE',
    'idempotent_replay', false
  );
exception
  when unique_violation then
    if exists (
      select 1 from public.mensajes_empleados pending
      where pending.empresa_id = v_empresa
        and pending.empleado_id = p_empleado
    ) then
      raise exception using errcode = 'P4903', message = 'EMPLOYEE_MESSAGE_ALREADY_PENDING';
    end if;
    raise;
end;
$$;

create or replace function public.obtener_mensajes_pendientes_dispositivo(
  p_empresa uuid,
  p_dispositivo uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_sucursal uuid;
begin
  select device.sucursal_id into v_sucursal
  from public.dispositivos_android device
  where device.empresa_id = p_empresa
    and device.id = p_dispositivo
    and device.estado = 'activo';
  if not found then
    raise exception using errcode = '42501', message = 'DEVICE_REVOKED';
  end if;

  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', message.id,
      'employee_id', message.empleado_id,
      'type', message.tipo,
      'text', message.contenido_texto,
      'audio_object_path', message.audio_object_path,
      'audio_duration_seconds', message.audio_duracion_segundos,
      'created_at', message.creado_en
    ) order by message.creado_en)
    from public.mensajes_empleados message
    join public.empleados employee
      on employee.empresa_id = message.empresa_id
     and employee.id = message.empleado_id
    where message.empresa_id = p_empresa
      and (v_sucursal is null or employee.sucursal_id = v_sucursal)
      and employee.activo
      and lower(coalesce(employee.estado_laboral, '')) in (
        'activo', 'active', 'licencia', 'vacaciones'
      )
  ), '[]'::jsonb);
end;
$$;

create or replace function public.obtener_mensaje_pendiente_dispositivo(
  p_empresa uuid,
  p_dispositivo uuid,
  p_empleado uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_messages jsonb;
begin
  v_messages := public.obtener_mensajes_pendientes_dispositivo(p_empresa, p_dispositivo);
  return (
    select item
    from jsonb_array_elements(v_messages) item
    where (item ->> 'employee_id')::uuid = p_empleado
    order by (item ->> 'created_at')::timestamptz
    limit 1
  );
end;
$$;

create or replace function public.confirmar_mensaje_recibido_dispositivo(payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_empresa uuid;
  v_dispositivo uuid;
  v_empleado uuid;
  v_mensaje_id uuid;
  v_idempotency uuid;
  v_message public.mensajes_empleados%rowtype;
  v_receipt public.mensajes_empleados_recibidos%rowtype;
  v_device_branch uuid;
  v_employee_branch uuid;
begin
  begin
    v_empresa := (payload ->> 'empresa_id')::uuid;
    v_dispositivo := (payload ->> 'dispositivo_id')::uuid;
    v_empleado := (payload ->> 'empleado_id')::uuid;
    v_mensaje_id := (payload ->> 'mensaje_id')::uuid;
    v_idempotency := (payload ->> 'idempotency_key')::uuid;
  exception when others then
    raise exception using errcode = '22023', message = 'EMPLOYEE_MESSAGE_RECEIPT_INVALID';
  end;
  if v_empresa is null or v_dispositivo is null or v_empleado is null
     or v_mensaje_id is null or v_idempotency is null
  then
    raise exception using errcode = '22023', message = 'EMPLOYEE_MESSAGE_RECEIPT_INVALID';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_mensaje_id::text, 49)
  );

  select * into v_receipt
  from public.mensajes_empleados_recibidos receipt
  where receipt.mensaje_id = v_mensaje_id
     or (receipt.empresa_id = v_empresa and receipt.idempotency_key = v_idempotency)
  order by receipt.recibido_en
  limit 1;
  if found then
    if v_receipt.mensaje_id <> v_mensaje_id
       or v_receipt.empleado_id <> v_empleado
    then
      raise exception using errcode = '23505', message = 'IDEMPOTENCY_KEY_REUSED';
    end if;
    return jsonb_build_object(
      'result', 'duplicate',
      'message_id', v_receipt.mensaje_id,
      'audio_object_path', null
    );
  end if;

  select device.sucursal_id into v_device_branch
  from public.dispositivos_android device
  where device.empresa_id = v_empresa
    and device.id = v_dispositivo
    and device.estado = 'activo';
  if not found then
    raise exception using errcode = '42501', message = 'DEVICE_REVOKED';
  end if;

  select employee.sucursal_id into v_employee_branch
  from public.empleados employee
  where employee.empresa_id = v_empresa
    and employee.id = v_empleado;
  if not found or (v_device_branch is not null and v_employee_branch is distinct from v_device_branch) then
    raise exception using errcode = '42501', message = 'EMPLOYEE_MESSAGE_DEVICE_SCOPE_DENIED';
  end if;

  select * into v_message
  from public.mensajes_empleados message
  where message.empresa_id = v_empresa
    and message.id = v_mensaje_id
    and message.empleado_id = v_empleado
  for update;
  if not found then
    raise exception using errcode = 'P4904', message = 'EMPLOYEE_MESSAGE_NOT_FOUND';
  end if;

  insert into public.mensajes_empleados_recibidos (
    mensaje_id, empresa_id, empleado_id, dispositivo_id, idempotency_key
  ) values (
    v_message.id, v_empresa, v_empleado, v_dispositivo, v_idempotency
  );
  delete from public.mensajes_empleados where id = v_message.id;

  return jsonb_build_object(
    'result', 'accepted',
    'message_id', v_message.id,
    'audio_object_path', v_message.audio_object_path
  );
end;
$$;

revoke all on function public.crear_mensaje_empleado(
  uuid, text, text, text, integer, uuid
) from public, anon;
grant execute on function public.crear_mensaje_empleado(
  uuid, text, text, text, integer, uuid
) to authenticated, service_role;

revoke all on function public.obtener_mensajes_pendientes_dispositivo(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.obtener_mensaje_pendiente_dispositivo(uuid, uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.confirmar_mensaje_recibido_dispositivo(jsonb)
  from public, anon, authenticated;
grant execute on function public.obtener_mensajes_pendientes_dispositivo(uuid, uuid)
  to service_role;
grant execute on function public.obtener_mensaje_pendiente_dispositivo(uuid, uuid, uuid)
  to service_role;
grant execute on function public.confirmar_mensaje_recibido_dispositivo(jsonb)
  to service_role;

insert into storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
) values (
  'employee-message-audio',
  'employee-message-audio',
  false,
  5242880,
  array['audio/webm', 'audio/ogg', 'audio/mpeg', 'audio/mp4']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists employee_message_audio_insert on storage.objects;
create policy employee_message_audio_insert
on storage.objects for insert to authenticated
with check (
  bucket_id = 'employee-message-audio'
  and public.tiene_permiso('mensajes.administrar')
  and (storage.foldername(name))[1] = public.obtener_empresa_actual()::text
);

drop policy if exists employee_message_audio_delete on storage.objects;
create policy employee_message_audio_delete
on storage.objects for delete to authenticated
using (
  bucket_id = 'employee-message-audio'
  and public.tiene_permiso('mensajes.administrar')
  and (storage.foldername(name))[1] = public.obtener_empresa_actual()::text
);

commit;
