-- Completa el catalogo versionado para el acceso administrativo de usuarios,
-- roles y permisos. No depende de supabase/seed.sql.
BEGIN;

INSERT INTO public.permisos AS permiso_actual (
  codigo,
  nombre,
  descripcion,
  modulo,
  activo
)
VALUES
  (
    'usuarios.administrar',
    'Administrar usuarios',
    'Gestiona usuarios, estados de acceso y asignaciones de rol de la empresa.',
    'administracion',
    true
  ),
  (
    'roles.administrar',
    'Administrar roles',
    'Gestiona roles de autorizacion de la empresa.',
    'administracion',
    true
  ),
  (
    'permisos.administrar',
    'Administrar permisos',
    'Gestiona permisos asignados a los roles de la empresa.',
    'administracion',
    true
  )
ON CONFLICT (codigo) DO UPDATE
SET
  nombre = EXCLUDED.nombre,
  descripcion = EXCLUDED.descripcion,
  modulo = EXCLUDED.modulo,
  activo = EXCLUDED.activo
WHERE (
  permiso_actual.nombre,
  permiso_actual.descripcion,
  permiso_actual.modulo,
  permiso_actual.activo
) IS DISTINCT FROM (
  EXCLUDED.nombre,
  EXCLUDED.descripcion,
  EXCLUDED.modulo,
  EXCLUDED.activo
);

INSERT INTO public.rol_permisos AS asignacion_actual (
  rol_id,
  permiso_id,
  permitido,
  alcance
)
SELECT
  r.id,
  p.id,
  true,
  'empresa'
FROM public.roles AS r
CROSS JOIN public.permisos AS p
WHERE upper(r.code) = 'ADMIN'
  AND r.is_active = true
  AND p.codigo IN (
    'usuarios.administrar',
    'roles.administrar',
    'permisos.administrar'
  )
ON CONFLICT (rol_id, permiso_id) DO UPDATE
SET
  permitido = EXCLUDED.permitido,
  alcance = EXCLUDED.alcance
WHERE (
  asignacion_actual.permitido,
  asignacion_actual.alcance
) IS DISTINCT FROM (
  EXCLUDED.permitido,
  EXCLUDED.alcance
);

COMMIT;
