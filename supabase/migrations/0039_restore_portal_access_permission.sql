-- Restaura el permiso base requerido para acceder al portal privado.
-- Corrige instalaciones donde migraciones anteriores intentaron asignarlo
-- antes de que portal.acceder existiera en public.permisos.

begin;

insert into public.permisos as permiso_actual (
  codigo,
  nombre,
  descripcion,
  modulo,
  activo
)
values (
  'portal.acceder',
  'Acceder al portal',
  'Permite iniciar sesion y acceder al portal privado.',
  'portal',
  true
)
on conflict (codigo) do update
set
  nombre = excluded.nombre,
  descripcion = excluded.descripcion,
  modulo = excluded.modulo,
  activo = excluded.activo
where (
  permiso_actual.nombre,
  permiso_actual.descripcion,
  permiso_actual.modulo,
  permiso_actual.activo
) is distinct from (
  excluded.nombre,
  excluded.descripcion,
  excluded.modulo,
  excluded.activo
);

insert into public.rol_permisos as asignacion_actual (
  rol_id,
  permiso_id,
  permitido,
  alcance
)
select
  r.id,
  p.id,
  true,
  case private.normalizar_codigo_rol(r.code)
    when 'ADMIN' then 'empresa'
    when 'SUPERVISOR' then 'departamento'
    when 'EMPLEADO' then 'propio'
  end
from public.roles as r
join public.permisos as p
  on p.codigo = 'portal.acceder'
 and p.activo = true
where r.is_active = true
  and private.normalizar_codigo_rol(r.code)
      in ('ADMIN', 'SUPERVISOR', 'EMPLEADO')
on conflict (rol_id, permiso_id) do update
set
  permitido = excluded.permitido,
  alcance = excluded.alcance
where (
  asignacion_actual.permitido,
  asignacion_actual.alcance
) is distinct from (
  excluded.permitido,
  excluded.alcance
);

commit;