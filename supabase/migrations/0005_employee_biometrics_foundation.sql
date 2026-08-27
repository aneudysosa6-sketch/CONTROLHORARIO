-- Base segura para sincronización biométrica futura. No habilita captura web ni
-- modifica el flujo Android/Room existente.
begin;

insert into public.permisos(codigo,nombre,modulo,activo) values
('empleados.biometria_ver','Ver estado biométrico','empleados',true),
('empleados.biometria_registrar','Registrar biometría desde Android','empleados',true),
('empleados.biometria_reemplazar','Reemplazar biometría desde Android','empleados',true)
on conflict(codigo) do update set nombre=excluded.nombre,modulo=excluded.modulo,activo=true;

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'empresa' from public.roles r join public.permisos p
  on p.codigo in ('empleados.biometria_ver','empleados.biometria_registrar','empleados.biometria_reemplazar')
where r.code='admin' and r.is_active
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

create table public.empleado_biometrias(
  id uuid primary key default extensions.gen_random_uuid(),
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  tipo text not null default 'huella_2connect' check(tipo='huella_2connect'),
  formato_version text not null,
  template_size integer not null check(template_size in (256,512)),
  template_ciphertext bytea not null,
  encryption_key_version text not null,
  encryption_nonce bytea not null,
  dispositivo_origen text not null,
  registrado_por uuid references public.profiles(id) on delete set null,
  registrado_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  activo boolean not null default true,
  foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict
);
create unique index empleado_biometrias_una_activa_idx on public.empleado_biometrias(empresa_id,empleado_id,tipo) where activo;
create index empleado_biometrias_empleado_idx on public.empleado_biometrias(empresa_id,empleado_id,updated_at desc);
create trigger empleado_biometrias_set_updated_at before update on public.empleado_biometrias for each row execute function public.set_updated_at();

create table public.empleado_biometria_auditoria(
  id bigint generated always as identity primary key,
  empresa_id uuid not null references public.companies(id) on delete restrict,
  empleado_id uuid not null,
  biometria_id uuid references public.empleado_biometrias(id) on delete restrict,
  actor_id uuid references public.profiles(id) on delete set null,
  accion text not null check(accion in ('registrar','reemplazar','desactivar')),
  dispositivo_origen text,
  created_at timestamptz not null default now(),
  foreign key(empresa_id,empleado_id) references public.empleados(empresa_id,id) on delete restrict
);
create index empleado_biometria_auditoria_idx on public.empleado_biometria_auditoria(empresa_id,empleado_id,created_at desc);

alter table public.empleado_biometrias enable row level security;
alter table public.empleado_biometria_auditoria enable row level security;
revoke all on public.empleado_biometrias,public.empleado_biometria_auditoria from public,anon,authenticated;
grant all on public.empleado_biometrias,public.empleado_biometria_auditoria to service_role;

create or replace function public.listar_estados_biometricos_empleados()
returns table(empleado_id uuid,registrada boolean,registrado_at timestamptz,dispositivo_origen text,template_size integer,formato_version text)
language sql stable security definer set search_path=''
as $$
  select e.id,b.id is not null,b.registrado_at,b.dispositivo_origen,b.template_size,b.formato_version
  from public.empleados e left join public.empleado_biometrias b
    on b.empresa_id=e.empresa_id and b.empleado_id=e.id and b.activo
  where e.empresa_id=(select public.obtener_empresa_actual())
    and (select public.tiene_permiso('empleados.biometria_ver'))
$$;
revoke all on function public.listar_estados_biometricos_empleados() from public,anon;
grant execute on function public.listar_estados_biometricos_empleados() to authenticated;

comment on table public.empleado_biometrias is 'Template 2Connect cifrado antes de persistir. Sin lectura para clientes web; escritura futura exclusiva de canal Android/Edge autorizado.';
comment on column public.empleado_biometrias.template_ciphertext is 'Ciphertext del template; nunca imagen RAW ni template legible.';
comment on function public.listar_estados_biometricos_empleados() is 'Expone solo metadatos biométricos del tenant autorizado, nunca el template.';
commit;
