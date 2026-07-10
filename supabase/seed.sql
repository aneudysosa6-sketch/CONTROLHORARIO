-- Datos maestros iniciales de CONTROLHORARIO.
-- Idempotente: puede ejecutarse nuevamente sin duplicar catálogos.
-- No crea usuarios de Auth ni perfiles y no contiene credenciales.

begin;

insert into public.companies (id, name, legal_name, slug, timezone, status)
values (
  '10000000-0000-4000-8000-000000000001',
  'OSINET',
  'OSINET',
  'osinet',
  'America/Santo_Domingo',
  'active'
)
on conflict (id) do update
set name = excluded.name,
    legal_name = excluded.legal_name,
    slug = excluded.slug,
    timezone = excluded.timezone,
    status = excluded.status;

insert into public.roles (id, company_id, name, code, description, is_system)
values
  ('11000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', 'Administrador', 'admin', 'Administración total del tenant.', true),
  ('11000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', 'Recursos Humanos', 'hr', 'Gestión de perfiles y estructura organizativa.', true),
  ('11000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', 'Supervisor', 'supervisor', 'Supervisión operativa con permisos limitados.', true),
  ('11000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001', 'Empleado', 'employee', 'Acceso de empleado.', true),
  ('11000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000001', 'Nómina', 'payroll', 'Procesamiento y aprobación de nómina.', true)
on conflict (company_id, code) do update
set name = excluded.name,
    description = excluded.description,
    is_system = excluded.is_system,
    is_active = true;

insert into public.branches (
  id, company_id, name, code, address, is_main, status
)
values (
  '12000000-0000-4000-8000-000000000001',
  '10000000-0000-4000-8000-000000000001',
  'Sucursal principal',
  'PRINCIPAL',
  'Santo Domingo, República Dominicana',
  true,
  'active'
)
on conflict (company_id, code) do update
set name = excluded.name,
    address = excluded.address,
    is_main = excluded.is_main,
    status = excluded.status;

insert into public.departments (
  id, company_id, branch_id, name, code, is_active
)
values
  ('13000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000001', 'Administración', 'ADMIN', true),
  ('13000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000001', 'Recursos Humanos', 'RRHH', true),
  ('13000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000001', 'Operaciones', 'OPERACIONES', true),
  ('13000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000001', 'Tecnología', 'TECNOLOGIA', true),
  ('13000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000001', '12000000-0000-4000-8000-000000000001', 'Contabilidad', 'CONTABILIDAD', true)
on conflict (company_id, code) do update
set name = excluded.name,
    branch_id = excluded.branch_id,
    is_active = true;

insert into public.positions (
  id, company_id, department_id, name, code, level, is_active
)
values
  ('14000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', '13000000-0000-4000-8000-000000000001', 'Administrador', 'ADMINISTRADOR', 10, true),
  ('14000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000001', '13000000-0000-4000-8000-000000000003', 'Supervisor', 'SUPERVISOR', 6, true),
  ('14000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000001', null, 'Empleado', 'EMPLEADO', 1, true),
  ('14000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000001', '13000000-0000-4000-8000-000000000005', 'Nómina', 'NOMINA', 5, true),
  ('14000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000001', '13000000-0000-4000-8000-000000000003', 'Gerente', 'GERENTE', 9, true)
on conflict (company_id, code) do update
set name = excluded.name,
    department_id = excluded.department_id,
    level = excluded.level,
    is_active = true;

-- Catálogo global de capacidades. Nuevos permisos deben versionarse explícitamente.
insert into public.permisos (codigo, nombre, descripcion, modulo, activo)
values
  ('portal.acceder', 'Acceder al portal', 'Permite iniciar y mantener una sesión en el portal.', 'portal', true),
  ('portal.ver_dashboard', 'Ver dashboard', 'Permite consultar el panel inicial del portal.', 'portal', true),
  ('perfil.ver_propio', 'Ver perfil propio', 'Permite consultar los datos del perfil autenticado.', 'perfil', true),
  ('perfil.editar_propio', 'Editar perfil propio', 'Capacidad reservada para un RPC seguro de edición personal.', 'perfil', true),
  ('empleados.ver_propio', 'Ver empleado propio', 'Permite consultar el registro laboral enlazado al perfil.', 'empleados', true),
  ('empleados.ver_departamento', 'Ver empleados del departamento', 'Permite consultar empleados del mismo departamento.', 'empleados', true),
  ('empleados.ver_todos', 'Ver todos los empleados', 'Permite consultar empleados de toda la empresa.', 'empleados', true),
  ('empleados.crear', 'Crear empleados', 'Permite crear registros laborales no sensibles.', 'empleados', true),
  ('empleados.editar', 'Editar empleados', 'Permite modificar columnas laborales no sensibles.', 'empleados', true),
  ('empleados.desactivar', 'Desactivar empleados', 'Permite desactivar empleados sin eliminarlos.', 'empleados', true),
  ('asistencia.ver_propia', 'Ver asistencia propia', 'Permite consultar la asistencia del empleado actual.', 'asistencia', true),
  ('asistencia.ver_departamento', 'Ver asistencia del departamento', 'Permite consultar asistencia del departamento.', 'asistencia', true),
  ('asistencia.ver_todas', 'Ver toda la asistencia', 'Permite consultar asistencia de la empresa.', 'asistencia', true),
  ('asistencia.registrar_propia', 'Registrar asistencia propia', 'Permite registrar asistencia del empleado actual.', 'asistencia', true),
  ('asistencia.corregir', 'Corregir asistencia', 'Permite corregir incidencias de asistencia.', 'asistencia', true),
  ('horarios.ver_propio', 'Ver horario propio', 'Permite consultar el horario asignado.', 'horarios', true),
  ('horarios.ver_todos', 'Ver todos los horarios', 'Permite consultar horarios de la empresa.', 'horarios', true),
  ('horarios.administrar', 'Administrar horarios', 'Permite administrar horarios y turnos.', 'horarios', true),
  ('nomina.ver_propia', 'Ver nómina propia', 'Permite consultar la nómina del empleado actual.', 'nomina', true),
  ('nomina.ver_todas', 'Ver todas las nóminas', 'Permite consultar la nómina de la empresa.', 'nomina', true),
  ('nomina.procesar', 'Procesar nómina', 'Permite procesar una nómina.', 'nomina', true),
  ('nomina.aprobar', 'Aprobar nómina', 'Permite aprobar una nómina procesada.', 'nomina', true),
  ('nomina.descargar', 'Descargar nómina', 'Permite descargar archivos de nómina autorizados.', 'nomina', true),
  ('reportes.ver_personales', 'Ver reportes personales', 'Permite consultar reportes propios.', 'reportes', true),
  ('reportes.ver_departamento', 'Ver reportes del departamento', 'Permite consultar reportes departamentales.', 'reportes', true),
  ('reportes.ver_globales', 'Ver reportes globales', 'Permite consultar reportes de toda la empresa.', 'reportes', true),
  ('reportes.exportar', 'Exportar reportes', 'Permite exportar reportes autorizados.', 'reportes', true),
  ('usuarios.administrar', 'Administrar usuarios', 'Permite aprovisionar y enlazar accesos mediante backend confiable.', 'administracion', true),
  ('roles.administrar', 'Administrar roles', 'Permite gestionar roles del tenant.', 'administracion', true),
  ('permisos.administrar', 'Administrar permisos', 'Permite asignar permisos a otros roles y perfiles.', 'administracion', true),
  ('configuracion.administrar', 'Administrar configuración', 'Permite modificar configuración empresarial.', 'administracion', true)
on conflict (codigo) do update
set nombre = excluded.nombre,
    descripcion = excluded.descripcion,
    modulo = excluded.modulo,
    activo = excluded.activo;

-- Empleado: acceso personal mínimo.
insert into public.rol_permisos (rol_id, permiso_id, permitido)
select r.id, p.id, true
from public.roles as r
join public.companies as c on c.id = r.company_id and c.slug = 'osinet'
join public.permisos as p on p.codigo = any (array[
  'portal.acceder', 'portal.ver_dashboard',
  'perfil.ver_propio', 'perfil.editar_propio',
  'empleados.ver_propio',
  'asistencia.ver_propia', 'asistencia.registrar_propia',
  'horarios.ver_propio',
  'nomina.ver_propia', 'nomina.descargar',
  'reportes.ver_personales'
])
where r.code = 'employee'
on conflict (rol_id, permiso_id) do update set permitido = excluded.permitido;

-- Supervisor: permisos personales más alcance departamental.
insert into public.rol_permisos (rol_id, permiso_id, permitido)
select r.id, p.id, true
from public.roles as r
join public.companies as c on c.id = r.company_id and c.slug = 'osinet'
join public.permisos as p on p.codigo = any (array[
  'portal.acceder', 'portal.ver_dashboard',
  'perfil.ver_propio', 'perfil.editar_propio',
  'empleados.ver_propio', 'empleados.ver_departamento',
  'asistencia.ver_propia', 'asistencia.registrar_propia', 'asistencia.ver_departamento',
  'horarios.ver_propio',
  'nomina.ver_propia', 'nomina.descargar',
  'reportes.ver_personales', 'reportes.ver_departamento'
])
where r.code = 'supervisor'
on conflict (rol_id, permiso_id) do update set permitido = excluded.permitido;

-- Recursos Humanos: acceso personal más gestión laboral global.
insert into public.rol_permisos (rol_id, permiso_id, permitido)
select r.id, p.id, true
from public.roles as r
join public.companies as c on c.id = r.company_id and c.slug = 'osinet'
join public.permisos as p on p.codigo = any (array[
  'portal.acceder', 'portal.ver_dashboard',
  'perfil.ver_propio', 'perfil.editar_propio',
  'empleados.ver_propio', 'empleados.ver_todos', 'empleados.crear',
  'empleados.editar', 'empleados.desactivar',
  'asistencia.ver_propia', 'asistencia.registrar_propia', 'asistencia.ver_todas',
  'horarios.ver_propio', 'horarios.ver_todos', 'horarios.administrar',
  'nomina.ver_propia', 'nomina.descargar',
  'reportes.ver_personales', 'reportes.ver_globales', 'reportes.exportar'
])
where r.code = 'hr'
on conflict (rol_id, permiso_id) do update set permitido = excluded.permitido;

-- Nómina: rol nuevo porque no existía en 0001.
insert into public.rol_permisos (rol_id, permiso_id, permitido)
select r.id, p.id, true
from public.roles as r
join public.companies as c on c.id = r.company_id and c.slug = 'osinet'
join public.permisos as p on p.codigo = any (array[
  'portal.acceder', 'portal.ver_dashboard',
  'perfil.ver_propio', 'perfil.editar_propio',
  'empleados.ver_propio', 'empleados.ver_todos',
  'asistencia.ver_propia', 'asistencia.ver_todas',
  'horarios.ver_propio',
  'nomina.ver_propia', 'nomina.ver_todas', 'nomina.procesar',
  'nomina.aprobar', 'nomina.descargar',
  'reportes.ver_personales', 'reportes.ver_globales', 'reportes.exportar'
])
where r.code = 'payroll'
on conflict (rol_id, permiso_id) do update set permitido = excluded.permitido;

-- Administrador: todos los permisos activos.
insert into public.rol_permisos (rol_id, permiso_id, permitido)
select r.id, p.id, true
from public.roles as r
join public.companies as c on c.id = r.company_id and c.slug = 'osinet'
cross join public.permisos as p
where r.code = 'admin'
  and p.activo
on conflict (rol_id, permiso_id) do update set permitido = excluded.permitido;

-- Alcance explícito: no depende únicamente del nombre del rol.
update public.rol_permisos as rp
set alcance = case
  when r.code = 'admin' then 'empresa'
  when r.code in ('hr', 'payroll')
    and p.codigo in (
      'empleados.ver_todos', 'empleados.crear', 'empleados.editar', 'empleados.desactivar',
      'asistencia.ver_todas', 'horarios.ver_todos', 'horarios.administrar',
      'nomina.ver_todas', 'nomina.procesar', 'nomina.aprobar',
      'reportes.ver_globales', 'reportes.exportar'
    ) then 'empresa'
  when r.code = 'supervisor'
    and p.codigo in (
      'empleados.ver_departamento', 'asistencia.ver_departamento', 'reportes.ver_departamento'
    ) then 'departamento'
  else 'propio'
end
from public.roles as r, public.permisos as p, public.companies as c
where rp.rol_id = r.id
  and rp.permiso_id = p.id
  and c.id = r.company_id
  and c.slug = 'osinet';

commit;
