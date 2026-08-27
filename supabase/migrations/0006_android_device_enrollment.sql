begin;
insert into public.permisos(codigo,nombre,modulo,activo) values
('dispositivos.ver','Ver dispositivos Android','dispositivos',true),
('dispositivos.registrar','Registrar dispositivos Android','dispositivos',true),
('dispositivos.revocar','Revocar dispositivos Android','dispositivos',true)
on conflict(codigo) do update set nombre=excluded.nombre,modulo=excluded.modulo,activo=true;
insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'empresa' from public.roles r join public.permisos p on p.codigo like 'dispositivos.%'
where r.code='admin' and r.is_active on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

create table public.dispositivos_android(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null references public.companies(id) on delete restrict,
 sucursal_id uuid,nombre text not null,modelo text not null,android_version text not null,app_version text not null,
 instalacion_id uuid not null,public_key_spki text not null,estado text not null default 'activo' check(estado in('activo','inactivo','revocado')),
 registrado_at timestamptz not null default now(),ultima_conexion_at timestamptz,revocado_at timestamptz,autorizado_por uuid references public.profiles(id) on delete set null,
 unique(empresa_id,instalacion_id),unique(empresa_id,id),foreign key(empresa_id,sucursal_id) references public.branches(company_id,id) on delete restrict
);
create table public.codigos_enrolamiento_dispositivo(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null references public.companies(id) on delete cascade,sucursal_id uuid,
 codigo_hash text not null unique,expires_at timestamptz not null,usado_at timestamptz,revocado_at timestamptz,creado_por uuid not null references public.profiles(id) on delete restrict,created_at timestamptz not null default now(),
 foreign key(empresa_id,sucursal_id) references public.branches(company_id,id) on delete restrict,check(expires_at>created_at)
);
create table public.credenciales_dispositivo(
 id uuid primary key default extensions.gen_random_uuid(),empresa_id uuid not null,dispositivo_id uuid not null,token_hash text not null unique,
 expires_at timestamptz not null,revocado_at timestamptz,created_at timestamptz not null default now(),ultima_uso_at timestamptz,
 foreign key(empresa_id,dispositivo_id) references public.dispositivos_android(empresa_id,id) on delete cascade
);
create table public.dispositivo_auditoria(
 id bigint generated always as identity primary key,empresa_id uuid not null references public.companies(id) on delete restrict,dispositivo_id uuid,
 actor_id uuid references public.profiles(id) on delete set null,accion text not null,resultado text not null,detalle jsonb not null default '{}'::jsonb,created_at timestamptz not null default now()
);
create index dispositivos_android_empresa_estado_idx on public.dispositivos_android(empresa_id,estado);
create index codigos_enrolamiento_expira_idx on public.codigos_enrolamiento_dispositivo(expires_at) where usado_at is null and revocado_at is null;
create index credenciales_dispositivo_activa_idx on public.credenciales_dispositivo(dispositivo_id,expires_at) where revocado_at is null;
create index dispositivo_auditoria_idx on public.dispositivo_auditoria(empresa_id,created_at desc);
alter table public.dispositivos_android enable row level security;alter table public.codigos_enrolamiento_dispositivo enable row level security;alter table public.credenciales_dispositivo enable row level security;alter table public.dispositivo_auditoria enable row level security;
revoke all on public.dispositivos_android,public.codigos_enrolamiento_dispositivo,public.credenciales_dispositivo,public.dispositivo_auditoria from public,anon,authenticated;
grant all on public.dispositivos_android,public.codigos_enrolamiento_dispositivo,public.credenciales_dispositivo,public.dispositivo_auditoria to service_role;
comment on column public.codigos_enrolamiento_dispositivo.codigo_hash is 'SHA-256 del código temporal; el código legible se devuelve una sola vez.';
comment on column public.credenciales_dispositivo.token_hash is 'SHA-256 de la credencial opaca; nunca se persiste la credencial legible.';
create or replace function public.enroll_android_device_internal(payload jsonb)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare
 enrollment public.codigos_enrolamiento_dispositivo%rowtype;
 new_device_id uuid := (payload->>'device_id')::uuid;
 event_time timestamptz := coalesce((payload->>'now')::timestamptz,now());
begin
 select * into enrollment from public.codigos_enrolamiento_dispositivo
 where id=(payload->>'enrollment_id')::uuid and usado_at is null and revocado_at is null and expires_at>event_time for update;
 if not found then raise exception 'Código inválido, vencido o usado'; end if;
 insert into public.dispositivos_android(id,empresa_id,sucursal_id,nombre,modelo,android_version,app_version,instalacion_id,public_key_spki,autorizado_por)
 values(new_device_id,enrollment.empresa_id,enrollment.sucursal_id,payload->>'name',payload->>'model',payload->>'android_version',payload->>'app_version',(payload->>'installation_id')::uuid,payload->>'public_key_spki',enrollment.creado_por);
 insert into public.credenciales_dispositivo(empresa_id,dispositivo_id,token_hash,expires_at)
 values(enrollment.empresa_id,new_device_id,payload->>'token_hash',event_time+interval '30 days');
 update public.codigos_enrolamiento_dispositivo set usado_at=event_time where id=enrollment.id;
 insert into public.dispositivo_auditoria(empresa_id,dispositivo_id,actor_id,accion,resultado)
 values(enrollment.empresa_id,new_device_id,enrollment.creado_por,'enrolamiento','exitoso');
 return new_device_id;
end $$;
revoke all on function public.enroll_android_device_internal(jsonb) from public,anon,authenticated;
grant execute on function public.enroll_android_device_internal(jsonb) to service_role;
commit;
