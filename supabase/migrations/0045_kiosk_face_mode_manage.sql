begin;

insert into public.permisos (
    codigo,
    nombre,
    descripcion,
    modulo,
    activo
)
values (
    'kiosk.face_mode_manage',
    'Administrar terminal facial',
    'Permite activar el terminal de reconocimiento facial para registrar jornadas y autorizar su salida mediante reautenticación.',
    'kiosk',
    true
)
on conflict (codigo)
do update set
    nombre = excluded.nombre,
    descripcion = excluded.descripcion,
    modulo = excluded.modulo,
    activo = excluded.activo;

with permiso as (
    select id
    from public.permisos
    where codigo = 'kiosk.face_mode_manage'
),
admin_roles as (
    select id
    from public.roles
    where is_active = true
      and private.normalizar_codigo_rol(code) = 'ADMIN'
)
insert into public.rol_permisos (
    rol_id,
    permiso_id,
    permitido,
    alcance
)
select
    r.id,
    p.id,
    true,
    'empresa'
from admin_roles r
cross join permiso p
on conflict (rol_id, permiso_id)
do update set
    permitido = excluded.permitido,
    alcance = excluded.alcance;

commit;