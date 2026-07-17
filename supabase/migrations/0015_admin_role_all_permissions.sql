-- Restituye permisos explícitos para administradores de su propia empresa.
-- No modifica RLS ni concede acceso entre empresas.
insert into public.rol_permisos(rol_id,permiso_id,permitido,alcance)
select r.id,p.id,true,'empresa'
from public.roles r
cross join public.permisos p
where r.is_active
  and p.activo
  and upper(translate(trim(coalesce(r.code,r.name)),'ÁÉÍÓÚáéíóú','AEIOUaeiou')) in ('ADMIN','ADMINISTRADOR','ADMINISTRATOR')
on conflict(rol_id,permiso_id) do update set permitido=true,alcance='empresa';
