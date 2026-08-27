-- FINAL 03: auditoría y User Provisioning.
-- Requiere 0001_FINAL y 0002_FINAL. Aplicar mediante Supabase CLI.
begin;

create table public.user_provisioning_audit (
  id uuid primary key default extensions.gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  target_user_id uuid not null references auth.users(id) on delete restrict,
  action text not null,
  employee_id uuid references public.empleados(id) on delete set null,
  role_id uuid references public.roles(id) on delete restrict,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint user_provisioning_audit_action_check check (
    action in ('bootstrap_admin','create_user','invite_user','provision_user','reprovision_user')
  ),
  constraint user_provisioning_audit_details_object check (jsonb_typeof(details) = 'object')
);

comment on table public.user_provisioning_audit is
  'Bitácora inmutable de altas y enlaces realizados exclusivamente por User Provisioning.';

create index user_provisioning_audit_company_created_idx
  on public.user_provisioning_audit(company_id, created_at desc);
create index user_provisioning_audit_target_idx
  on public.user_provisioning_audit(target_user_id, created_at desc);

alter table public.user_provisioning_audit enable row level security;
revoke all on public.user_provisioning_audit from anon, authenticated;
grant select on public.user_provisioning_audit to authenticated;

create policy user_provisioning_audit_select on public.user_provisioning_audit
  for select to authenticated
  using (
    company_id = (select public.obtener_empresa_actual())
    and (select public.tiene_permiso('usuarios.administrar'))
  );

-- El cliente deja de poder insertar, modificar o eliminar profiles, incluso con RLS.
revoke insert, update, delete on public.profiles from authenticated;
drop policy if exists profiles_insert_granular on public.profiles;
drop policy if exists profiles_update_granular on public.profiles;
drop policy if exists profiles_delete_granular on public.profiles;

create or replace function public.provision_user_internal(payload jsonb)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (payload->>'user_id')::uuid;
  v_company_id uuid := (payload->>'company_id')::uuid;
  v_role_id uuid := (payload->>'role_id')::uuid;
  v_employee_id uuid := nullif(payload->>'employee_id', '')::uuid;
  v_actor_id uuid := nullif(payload->>'actor_user_id', '')::uuid;
  v_action text := coalesce(nullif(payload->>'action', ''), 'provision_user');
  v_profile public.profiles;
  v_permission text;
begin
  if v_action not in ('bootstrap_admin','create_user','invite_user','provision_user','reprovision_user') then
    raise exception 'Acción de aprovisionamiento inválida';
  end if;
  if not exists (select 1 from auth.users where id = v_user_id) then
    raise exception 'El usuario Auth no existe';
  end if;
  if not exists (
    select 1 from public.roles
    where id = v_role_id and company_id = v_company_id and is_active
  ) then
    raise exception 'Rol inválido o perteneciente a otra empresa';
  end if;
  if exists (select 1 from public.profiles where id = v_user_id) then
    raise exception 'El usuario ya tiene profile';
  end if;
  if v_employee_id is not null and not exists (
    select 1 from public.empleados
    where id = v_employee_id and empresa_id = v_company_id and perfil_id is null
  ) then
    raise exception 'Empleado inválido, enlazado o perteneciente a otra empresa';
  end if;

  insert into public.profiles (
    id, company_id, role_id, branch_id, department_id, position_id,
    employee_code, full_name, phone, status
  ) values (
    v_user_id, v_company_id, v_role_id,
    nullif(payload->>'branch_id', '')::uuid,
    nullif(payload->>'department_id', '')::uuid,
    nullif(payload->>'position_id', '')::uuid,
    nullif(btrim(payload->>'employee_code'), ''),
    btrim(payload->>'full_name'),
    nullif(btrim(payload->>'phone'), ''),
    coalesce(nullif(payload->>'status', ''), 'active')
  ) returning * into v_profile;

  for v_permission in
    select jsonb_array_elements_text(coalesce(payload->'permission_codes', '[]'::jsonb))
  loop
    insert into public.perfil_permisos(perfil_id, permiso_id, permitido, alcance)
    select v_user_id, id, true, 'propio' from public.permisos
    where codigo = v_permission and activo
    on conflict (perfil_id, permiso_id) do update set permitido = true;
  end loop;

  if v_employee_id is not null then
    update public.empleados set perfil_id = v_user_id where id = v_employee_id;
  end if;

  insert into public.user_provisioning_audit(
    company_id, actor_user_id, target_user_id, action, employee_id, role_id, details
  ) values (
    v_company_id, v_actor_id, v_user_id, v_action, v_employee_id, v_role_id,
    jsonb_build_object('status', v_profile.status, 'permission_codes', coalesce(payload->'permission_codes','[]'::jsonb))
  );
  return v_profile;
end;
$$;

comment on function public.provision_user_internal(jsonb) is
  'Operación transaccional interna. Solo User Provisioning con service_role puede ejecutarla.';
revoke all on function public.provision_user_internal(jsonb) from public, anon, authenticated;
grant execute on function public.provision_user_internal(jsonb) to service_role;

-- Bootstrap transaccional del primer tenant. La Edge Function valida secreto efímero
-- y que no existan profiles antes de invocarlo.
create or replace function public.bootstrap_tenant_internal(payload jsonb)
returns public.profiles
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (payload->>'user_id')::uuid;
  v_company_id uuid := extensions.gen_random_uuid();
  v_role_id uuid := extensions.gen_random_uuid();
  v_branch_id uuid := extensions.gen_random_uuid();
  v_employee_id uuid;
  v_profile public.profiles;
begin
  if exists (select 1 from public.profiles) then raise exception 'Bootstrap cerrado'; end if;
  if not exists (select 1 from auth.users where id=v_user_id) then raise exception 'Usuario Auth inexistente'; end if;
  insert into public.companies(id,name,legal_name,slug,timezone,status)
  values(v_company_id,btrim(payload->>'company_name'),nullif(btrim(payload->>'legal_name'),''),
    lower(btrim(payload->>'company_slug')),coalesce(nullif(payload->>'timezone',''),'America/Santo_Domingo'),'active');
  insert into public.roles(id,company_id,name,code,description,is_system,is_active)
  values(v_role_id,v_company_id,'Administrador','admin','Administrador inicial del tenant.',true,true);
  insert into public.branches(id,company_id,name,code,is_main,status)
  values(v_branch_id,v_company_id,coalesce(nullif(btrim(payload->>'branch_name'),''),'Sucursal principal'),'PRINCIPAL',true,'active');
  insert into public.profiles(id,company_id,role_id,branch_id,full_name,status)
  values(v_user_id,v_company_id,v_role_id,v_branch_id,btrim(payload->>'full_name'),'active') returning * into v_profile;
  insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
  select v_role_id,id,true,'empresa' from public.permisos where activo
  on conflict (rol_id,permiso_id) do update set permitido=true, alcance='empresa';
  if nullif(btrim(payload->>'employee_code'),'') is not null then
    insert into public.empleados(empresa_id,perfil_id,sucursal_id,codigo_empleado,nombre_completo,correo,estado_laboral,activo)
    values(v_company_id,v_user_id,v_branch_id,btrim(payload->>'employee_code'),btrim(payload->>'full_name'),
      nullif(lower(btrim(payload->>'email')),''),'activo',true) returning id into v_employee_id;
  end if;
  insert into public.user_provisioning_audit(company_id,target_user_id,action,employee_id,role_id,details)
  values(v_company_id,v_user_id,'bootstrap_admin',v_employee_id,v_role_id,jsonb_build_object('company_slug',payload->>'company_slug'));
  return v_profile;
end;
$$;
revoke all on function public.bootstrap_tenant_internal(jsonb) from public, anon, authenticated;
grant execute on function public.bootstrap_tenant_internal(jsonb) to service_role;

commit;
