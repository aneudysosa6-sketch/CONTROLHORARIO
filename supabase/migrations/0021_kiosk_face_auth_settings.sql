begin;

insert into public.permisos(codigo,nombre,descripcion,modulo,activo) values
('kiosk.pin_fallback_manage','Administrar PIN alternativo del kiosk','Permite activar o desactivar el PIN alternativo; el rostro sigue siendo obligatorio.','kiosk',true)
on conflict(codigo) do update set
 nombre=excluded.nombre,
 descripcion=excluded.descripcion,
 modulo=excluded.modulo,
 activo=true;

insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'empresa'
from public.roles r
join public.permisos p on p.codigo='kiosk.pin_fallback_manage'
where r.is_active
  and upper(translate(trim(coalesce(r.code,r.name)),'ÁÉÍÓÚáéíóú','AEIOUaeiou')) in ('ADMIN','ADMINISTRADOR','ADMINISTRATOR')
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';

create table public.company_settings(
 company_id uuid primary key references public.companies(id) on delete cascade,
 face_only_enabled boolean not null default true,
 pin_fallback_enabled boolean not null default true,
 face_match_threshold numeric(6,5) not null default 0.75000,
 face_match_margin numeric(6,5),
 updated_at timestamptz not null default now(),
 updated_by uuid references public.profiles(id) on delete set null,
 constraint company_settings_face_match_threshold_check check(face_match_threshold between 0 and 1),
 constraint company_settings_face_match_margin_check check(face_match_margin is null or face_match_margin between 0 and 2)
);

comment on table public.company_settings is
 'Configuración empresarial de identificación facial distribuida a los dispositivos Android.';
comment on column public.company_settings.face_match_threshold is
 'Umbral de similitud coseno. El valor inicial 0.75 conserva el verificador Android existente.';
comment on column public.company_settings.face_match_margin is
 'Margen mínimo entre candidatos 1:N. NULL significa pendiente de calibración; no se inventa un valor productivo.';

insert into public.company_settings(company_id)
select id from public.companies
on conflict(company_id) do nothing;

create or replace function public.crear_company_settings_por_defecto()
returns trigger
language plpgsql
security definer
set search_path=public,pg_temp
as $$
begin
 insert into public.company_settings(company_id) values(new.id)
 on conflict(company_id) do nothing;
 return new;
end;
$$;

revoke all on function public.crear_company_settings_por_defecto() from public,anon,authenticated;
grant execute on function public.crear_company_settings_por_defecto() to service_role;

create trigger companies_create_company_settings
after insert on public.companies
for each row execute function public.crear_company_settings_por_defecto();

create trigger company_settings_set_updated_at
before update on public.company_settings
for each row execute function public.set_updated_at();

alter table public.company_settings enable row level security;
revoke all on public.company_settings from public,anon,authenticated;
grant select on public.company_settings to authenticated;
grant all on public.company_settings to service_role;

create policy company_settings_select_company
on public.company_settings for select to authenticated
using(company_id=public.obtener_empresa_actual());

create or replace function public.actualizar_configuracion_kiosk(
 p_pin_fallback_enabled boolean,
 p_face_only_enabled boolean default null,
 p_face_match_threshold numeric default null,
 p_face_match_margin numeric default null,
 p_motivo text default 'Configuración de autenticación del kiosk'
) returns jsonb
language plpgsql
security definer
set search_path=public,pg_temp
as $$
declare
 v_empresa uuid:=public.obtener_empresa_actual();
 v_antes jsonb;
 v_despues jsonb;
begin
 if v_empresa is null then
  raise exception using errcode='42501',message='COMPANY_CONTEXT_REQUIRED';
 end if;
 if not public.tiene_permiso('kiosk.pin_fallback_manage') then
  raise exception using errcode='42501',message='KIOSK_PIN_FALLBACK_PERMISSION_DENIED';
 end if;
 if p_pin_fallback_enabled is null then
  raise exception using errcode='22004',message='PIN_FALLBACK_VALUE_REQUIRED';
 end if;
 if p_face_match_threshold is not null and not(p_face_match_threshold between 0 and 1) then
  raise exception using errcode='22023',message='FACE_MATCH_THRESHOLD_INVALID';
 end if;
 if p_face_match_margin is not null and not(p_face_match_margin between 0 and 2) then
  raise exception using errcode='22023',message='FACE_MATCH_MARGIN_INVALID';
 end if;

 select to_jsonb(s) into v_antes
 from public.company_settings s
 where s.company_id=v_empresa
 for update;

 insert into public.company_settings(
  company_id,face_only_enabled,pin_fallback_enabled,face_match_threshold,face_match_margin,updated_by
 ) values(
  v_empresa,coalesce(p_face_only_enabled,true),p_pin_fallback_enabled,
  coalesce(p_face_match_threshold,0.75000),p_face_match_margin,auth.uid()
 )
 on conflict(company_id) do update set
  face_only_enabled=coalesce(p_face_only_enabled,company_settings.face_only_enabled),
  pin_fallback_enabled=p_pin_fallback_enabled,
  face_match_threshold=coalesce(p_face_match_threshold,company_settings.face_match_threshold),
  face_match_margin=coalesce(p_face_match_margin,company_settings.face_match_margin),
  updated_by=auth.uid()
 returning to_jsonb(company_settings) into v_despues;

 insert into public.administracion_auditoria(
  empresa_id,actor_id,seccion,accion,entidad,entidad_id,antes,despues,motivo
 ) values(
  v_empresa,auth.uid(),'seguridad','ACTUALIZAR_KIOSK_FACE_AUTH','company_settings',v_empresa::text,
  v_antes,v_despues,nullif(btrim(coalesce(p_motivo,'')),'')
 );
 return v_despues;
end;
$$;

revoke all on function public.actualizar_configuracion_kiosk(boolean,boolean,numeric,numeric,text) from public,anon;
grant execute on function public.actualizar_configuracion_kiosk(boolean,boolean,numeric,numeric,text) to authenticated;

commit;
