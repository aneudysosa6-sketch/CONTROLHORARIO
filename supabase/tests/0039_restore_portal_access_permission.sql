begin;

set local search_path = extensions, public, pg_catalog;
set local role postgres;

create extension if not exists pgtap;
select * from no_plan();

select is(
  (
    select count(*)::integer
    from public.permisos
    where codigo = 'portal.acceder'
  ),
  1,
  'portal.acceder existe exactamente una vez'
);

select is(
  (
    select count(*)::integer
    from public.permisos
    where codigo = 'portal.acceder'
      and activo = true
      and modulo = 'portal'
  ),
  1,
  'portal.acceder esta activo y pertenece al modulo portal'
);

select is(
  (
    select count(*)::integer
    from public.roles r
    where r.is_active = true
      and private.normalizar_codigo_rol(r.code)
          in ('ADMIN', 'SUPERVISOR', 'EMPLEADO')
      and not exists (
        select 1
        from public.rol_permisos rp
        join public.permisos p
          on p.id = rp.permiso_id
        where rp.rol_id = r.id
          and p.codigo = 'portal.acceder'
          and p.activo = true
          and rp.permitido = true
      )
  ),
  0,
  'todas las familias de portal activas reciben portal.acceder'
);

select is(
  (
    select count(*)::integer
    from public.rol_permisos rp
    join public.roles r
      on r.id = rp.rol_id
    join public.permisos p
      on p.id = rp.permiso_id
    where r.is_active = true
      and p.codigo = 'portal.acceder'
      and private.normalizar_codigo_rol(r.code) = 'ADMIN'
      and (
        rp.permitido is distinct from true
        or rp.alcance is distinct from 'empresa'
      )
  ),
  0,
  'ADMIN recibe portal.acceder con alcance empresa'
);

select is(
  (
    select count(*)::integer
    from public.rol_permisos rp
    join public.roles r
      on r.id = rp.rol_id
    join public.permisos p
      on p.id = rp.permiso_id
    where r.is_active = true
      and p.codigo = 'portal.acceder'
      and private.normalizar_codigo_rol(r.code) = 'SUPERVISOR'
      and (
        rp.permitido is distinct from true
        or rp.alcance is distinct from 'departamento'
      )
  ),
  0,
  'SUPERVISOR recibe portal.acceder con alcance departamento'
);

select is(
  (
    select count(*)::integer
    from public.rol_permisos rp
    join public.roles r
      on r.id = rp.rol_id
    join public.permisos p
      on p.id = rp.permiso_id
    where r.is_active = true
      and p.codigo = 'portal.acceder'
      and private.normalizar_codigo_rol(r.code) = 'EMPLEADO'
      and (
        rp.permitido is distinct from true
        or rp.alcance is distinct from 'propio'
      )
  ),
  0,
  'EMPLEADO recibe portal.acceder con alcance propio'
);

select * from finish();
rollback;