-- Postflight de produccion para 0032 y huellas no objetivo del lote 0031/0032.
-- Solo sentencias SELECT. Comparar las tres huellas con la salida precheck.

select exists (
  select 1
  from supabase_migrations.schema_migrations
  where version = '0032'
) as migration_0032_recorded;

select
  p.id as permission_id,
  p.codigo,
  p.nombre,
  p.descripcion,
  p.modulo,
  p.activo,
  p.codigo = 'portal.ver_dashboard'
    and p.modulo = 'portal'
    and p.activo as permission_matches_contract
from public.permisos as p
where p.codigo = 'portal.ver_dashboard';

select
  r.company_id,
  r.id as role_id,
  r.code as role_code_original,
  upper(r.code) as role_code_target,
  r.is_active,
  rp.permitido,
  rp.alcance,
  rp.permitido and rp.alcance = 'empresa' as assignment_matches_contract
from public.roles as r
join public.permisos as p on p.codigo = 'portal.ver_dashboard'
left join public.rol_permisos as rp
  on rp.rol_id = r.id
 and rp.permiso_id = p.id
where r.is_active
  and upper(r.code) in ('ADMIN', 'SUPERVISOR')
order by r.company_id, r.id;

select
  (
    select md5(coalesce(string_agg(
      concat_ws(
        '|', p.id::text, p.codigo, p.nombre,
        coalesce(p.descripcion, '<NULL>'), p.modulo, p.activo::text
      ),
      E'\n' order by p.codigo, p.id
    ), ''))
    from public.permisos as p
    where p.codigo not in (
      'usuarios.administrar', 'roles.administrar',
      'permisos.administrar', 'portal.ver_dashboard'
    )
  ) as non_target_permission_catalog_md5,
  (
    select md5(coalesce(string_agg(
      concat_ws(
        '|', rp.rol_id::text, rp.permiso_id::text,
        rp.permitido::text, rp.alcance
      ),
      E'\n' order by rp.rol_id, rp.permiso_id
    ), ''))
    from public.rol_permisos as rp
    join public.permisos as p on p.id = rp.permiso_id
    where p.codigo not in (
      'usuarios.administrar', 'roles.administrar',
      'permisos.administrar', 'portal.ver_dashboard'
    )
  ) as non_target_role_permissions_md5,
  (
    select md5(coalesce(string_agg(
      concat_ws(
        '|', pp.perfil_id::text, pp.permiso_id::text,
        pp.permitido::text, pp.alcance
      ),
      E'\n' order by pp.perfil_id, pp.permiso_id
    ), ''))
    from public.perfil_permisos as pp
  ) as profile_permission_overrides_md5;

select
  p.codigo,
  count(*) as assignments,
  count(*) filter (where rp.permitido) as allowed_assignments
from public.permisos as p
left join public.rol_permisos as rp on rp.permiso_id = p.id
where p.codigo in (
  'portal.ver_dashboard', 'supervisor.dashboard',
  'empleados.ver_asignados', 'jornadas.ver_asignadas'
)
group by p.codigo
order by p.codigo;
