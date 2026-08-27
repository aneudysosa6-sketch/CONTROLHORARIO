-- Corrige el listado de empleados para el formulario de accesos:
-- solo empleados activos de la empresa autenticada sin acceso vigente.

create or replace function public.listar_accesos_internal(payload jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_actor uuid := nullif(payload ->> 'actor_user_id', '')::uuid;
  v_empresa uuid := nullif(payload ->> 'company_id', '')::uuid;
  v_result jsonb;
begin
  if v_actor is null or v_empresa is null
    or not public.actor_puede_administrar_accesos_internal(
      v_actor,v_empresa,array[
        'usuarios.view','usuarios.create','usuarios.edit','usuarios.administrar'
      ]::text[]
    ) then
    raise exception using errcode = '42501', message = 'ACCESS_ADMIN_PERMISSION_DENIED';
  end if;

  select jsonb_build_object(
    'accesses', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', pr.id,
        'username', coalesce(nullif(btrim(u.raw_user_meta_data ->> 'username'), ''), u.email, ''),
        'email', u.email,
        'employee_id', e.id,
        'employee_name', e.nombre_completo,
        'employee_code', e.codigo_empleado,
        'role_id', r.id,
        'role_name', r.name,
        'role_code', r.code,
        'status', pr.status,
        'last_sign_in_at', u.last_sign_in_at
      ) order by lower(coalesce(e.nombre_completo, u.email, pr.id::text)))
      from public.profiles pr
      join auth.users u on u.id = pr.id
      join public.roles r on r.id = pr.role_id and r.company_id = pr.company_id
      left join public.empleados e
        on e.empresa_id = pr.company_id
       and e.perfil_id = pr.id
      where pr.company_id = v_empresa
        and pr.access_deleted_at is null
    ), '[]'::jsonb),
    'employees', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', e.id,
        'nombre_completo', e.nombre_completo,
        'codigo_empleado', e.codigo_empleado,
        'empresa_id', e.empresa_id,
        'perfil_id', e.perfil_id,
        'activo', e.activo
      ) order by e.nombre_completo)
      from public.empleados e
      where e.empresa_id = v_empresa
        and e.activo
        and e.perfil_id is null
    ), '[]'::jsonb),
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', r.id,
        'name', r.name,
        'code', r.code,
        'company_id', r.company_id
      ) order by r.name)
      from public.roles r
      where r.company_id = v_empresa
        and r.is_active
    ), '[]'::jsonb)
  ) into v_result;

  return v_result;
end;
$$;
