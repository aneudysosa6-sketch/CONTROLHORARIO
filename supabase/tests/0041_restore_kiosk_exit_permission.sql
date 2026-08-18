begin;

set local search_path = extensions, public, pg_catalog;
set local role postgres;

select * from no_plan();

select is(
  (select count(*)::int from public.permisos where codigo = 'kiosk.pin_mode_exit'),
  1,
  'Existe exactamente un permiso kiosk.pin_mode_exit'
);

select is(
  (select activo from public.permisos where codigo = 'kiosk.pin_mode_exit'),
  true,
  'kiosk.pin_mode_exit está activo'
);

select is(
  (select modulo from public.permisos where codigo = 'kiosk.pin_mode_exit'),
  'kiosk',
  'kiosk.pin_mode_exit pertenece al módulo kiosk'
);

select ok(
  (
    exists (
      select 1
      from public.roles r
      where r.is_active = true
        and private.normalizar_codigo_rol(r.code) = 'ADMIN'
    )
    and not exists (
      select 1
      from public.roles r
      where r.is_active = true
        and private.normalizar_codigo_rol(r.code) = 'ADMIN'
        and not exists (
          select 1
          from public.rol_permisos rp
          join public.permisos p on p.id = rp.permiso_id
          where rp.rol_id = r.id
            and p.codigo = 'kiosk.pin_mode_exit'
            and rp.permitido = true
            and rp.alcance = 'empresa'
        )
    )
  ),
  'Existe al menos un ADMIN activo y todos tienen permitido=true y alcance=empresa'
);

select is(
  (select count(*)::int
   from public.roles r
   join public.rol_permisos rp on rp.rol_id = r.id
   join public.permisos p on p.id = rp.permiso_id
   where r.is_active = true
     and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
     and p.codigo = 'kiosk.pin_mode_exit'
     and rp.permitido = true
  ),
  0,
  'Ningún SUPERVISOR activo tiene permitido=true para kiosk.pin_mode_exit'
);

select is(
  (select count(*)::int
   from public.roles r
   join public.rol_permisos rp on rp.rol_id = r.id
   join public.permisos p on p.id = rp.permiso_id
   where r.is_active = true
     and private.normalizar_codigo_rol(r.code) = 'EMPLEADO'
     and p.codigo = 'kiosk.pin_mode_exit'
     and rp.permitido = true
  ),
  0,
  'Ningún EMPLEADO activo tiene permitido=true para kiosk.pin_mode_exit'
);

select * from finish();
rollback;
