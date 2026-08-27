-- Ensure kiosk exit remains an administrator-only capability after 0041.
begin;

update public.rol_permisos rp
set permitido = false
from public.roles r,
     public.permisos p
where rp.rol_id = r.id
  and rp.permiso_id = p.id
  and p.codigo = 'kiosk.pin_mode_exit'
  and private.normalizar_codigo_rol(r.code) in ('SUPERVISOR', 'EMPLEADO')
  and rp.permitido is distinct from false;

commit;