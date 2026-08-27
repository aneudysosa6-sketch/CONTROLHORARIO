-- Repara de forma idempotente permisos de Empleados para administradores creados
-- antes de que el catálogo completo estuviera disponible durante el bootstrap.
begin;

insert into public.permisos (codigo, nombre, modulo, activo)
values
  ('empleados.ver_todos', 'Ver todos los empleados', 'empleados', true),
  ('empleados.crear', 'Crear empleados', 'empleados', true),
  ('empleados.editar', 'Editar empleados', 'empleados', true),
  ('empleados.desactivar', 'Desactivar empleados', 'empleados', true)
on conflict (codigo) do update
set nombre = excluded.nombre,
    modulo = excluded.modulo,
    activo = true;

insert into public.rol_permisos (rol_id, permiso_id, permitido, alcance)
select r.id, p.id, true, 'empresa'
from public.roles as r
join public.permisos as p
  on p.codigo in (
    'empleados.ver_todos',
    'empleados.crear',
    'empleados.editar',
    'empleados.desactivar'
  )
where r.code = 'admin'
  and r.is_active
on conflict (rol_id, permiso_id) do update
set permitido = true,
    alcance = 'empresa';

do $$
begin
  if exists (
    select 1
    from public.roles as r
    where r.code = 'admin'
      and r.is_active
      and (
        select count(*)
        from public.rol_permisos as rp
        join public.permisos as p on p.id = rp.permiso_id
        where rp.rol_id = r.id
          and p.codigo in (
            'empleados.ver_todos',
            'empleados.crear',
            'empleados.editar',
            'empleados.desactivar'
          )
          and rp.permitido
          and rp.alcance = 'empresa'
      ) <> 4
  ) then
    raise exception 'No se pudieron asignar todos los permisos de Empleados al rol admin';
  end if;
end
$$;

commit;
