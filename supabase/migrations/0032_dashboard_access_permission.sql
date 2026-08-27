-- Versiona el permiso requerido por /dashboard y su asignacion base.
-- No depende de supabase/seed.sql.
BEGIN;

INSERT INTO public.permisos AS permiso_actual (
  codigo,
  nombre,
  descripcion,
  modulo,
  activo
)
VALUES (
  'portal.ver_dashboard',
  'Ver dashboard',
  'Permite consultar el panel inicial del portal.',
  'portal',
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
JOIN public.permisos AS p
  ON p.codigo = 'portal.ver_dashboard'
WHERE upper(r.code) IN ('ADMIN', 'SUPERVISOR')
  AND r.is_active = true
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
