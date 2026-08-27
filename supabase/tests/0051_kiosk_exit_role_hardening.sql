begin;
set local search_path = extensions, public, pg_catalog;
set local role postgres;
select plan(2);

select is(
  (
    select count(*)::integer
    from public.roles r
    join public.rol_permisos rp on rp.rol_id = r.id
    join public.permisos p on p.id = rp.permiso_id
    where private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
      and p.codigo = 'kiosk.pin_mode_exit'
      and rp.permitido
  ),
  0,
  'SUPERVISOR cannot exit kiosk mode'
);

select is(
  (
    select count(*)::integer
    from public.roles r
    join public.rol_permisos rp on rp.rol_id = r.id
    join public.permisos p on p.id = rp.permiso_id
    where private.normalizar_codigo_rol(r.code) = 'EMPLEADO'
      and p.codigo = 'kiosk.pin_mode_exit'
      and rp.permitido
  ),
  0,
  'EMPLEADO cannot exit kiosk mode'
);

select * from finish();
rollback;