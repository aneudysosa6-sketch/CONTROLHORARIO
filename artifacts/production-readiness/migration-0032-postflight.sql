-- Postflight de solo lectura para 0032_dashboard_access_permission.sql.
-- No ejecuta DML ni cambia configuracion.
--
-- Para demostrar que el estado no objetivo no cambio, ejecutar el bloque 06
-- antes de 0032, archivar sus tres huellas y sustituir los NULL del CTE
-- baseline por esos valores al ejecutar el postflight. Sin preimagen, el
-- resultado es BASELINE_REQUERIDO y nunca un PASS implicito.

SELECT
  '01_contexto'::text AS check_name,
  current_database()::text AS database_name,
  current_user::text AS database_role,
  auth.uid() IS NOT NULL AS auth_session_available;

WITH expected AS (
  SELECT
    'portal.ver_dashboard'::text AS permission_code,
    'Ver dashboard'::text AS expected_name,
    'Permite consultar el panel inicial del portal.'::text
      AS expected_description,
    'portal'::text AS expected_module
)
SELECT
  '02_catalogo_dashboard'::text AS check_name,
  e.permission_code,
  (
    SELECT count(*)::integer
    FROM public.permisos AS counted
    WHERE counted.codigo = e.permission_code
  ) AS catalog_row_count,
  (
    SELECT count(*) = 1
    FROM public.permisos AS counted
    WHERE counted.codigo = e.permission_code
  ) AS exactly_one_catalog_row,
  p.id AS permission_id,
  p.nombre AS permission_name,
  p.descripcion AS permission_description,
  p.modulo AS permission_module,
  p.activo AS permission_active,
  COALESCE(
    p.nombre = e.expected_name
      AND p.descripcion = e.expected_description
      AND p.modulo = e.expected_module
      AND p.activo IS TRUE
      AND (
        SELECT count(*) = 1
        FROM public.permisos AS counted
        WHERE counted.codigo = e.permission_code
      ),
    false
  ) AS catalog_matches_0032
FROM expected AS e
LEFT JOIN public.permisos AS p
  ON p.codigo = e.permission_code;

WITH expected_roles(role_order, role_code) AS (
  VALUES
    (1, 'ADMIN'::text),
    (2, 'SUPERVISOR'::text)
),
assignment_state AS (
  SELECT
    er.role_order,
    er.role_code AS expected_role_code,
    r.company_id,
    r.id AS role_id,
    r.code AS role_code_original,
    r.is_active AS role_active,
    p.id AS permission_id,
    p.activo AS permission_active,
    rp.rol_id IS NOT NULL AS assignment_exists,
    rp.permitido,
    rp.alcance,
    COALESCE(
      p.activo IS TRUE
      AND rp.rol_id IS NOT NULL
      AND rp.permitido IS TRUE
      AND rp.alcance = 'empresa',
      false
    ) AS assignment_matches_0032
  FROM expected_roles AS er
  LEFT JOIN public.roles AS r
    ON upper(r.code) = er.role_code
   AND r.is_active = true
  LEFT JOIN public.permisos AS p
    ON p.codigo = 'portal.ver_dashboard'
  LEFT JOIN public.rol_permisos AS rp
    ON rp.rol_id = r.id
   AND rp.permiso_id = p.id
)
SELECT
  '03_asignaciones_dashboard_detalle'::text AS check_name,
  ast.role_order,
  ast.expected_role_code,
  ast.company_id,
  ast.role_id,
  ast.role_code_original,
  ast.role_active,
  ast.permission_id,
  ast.permission_active,
  ast.assignment_exists,
  ast.permitido,
  ast.alcance,
  ast.assignment_matches_0032
FROM assignment_state AS ast
ORDER BY ast.role_order, ast.company_id, ast.role_id;

WITH expected_roles(role_order, role_code) AS (
  VALUES
    (1, 'ADMIN'::text),
    (2, 'SUPERVISOR'::text)
),
assignment_state AS (
  SELECT
    er.role_order,
    er.role_code,
    r.id AS role_id,
    COALESCE(
      p.activo IS TRUE
      AND rp.rol_id IS NOT NULL
      AND rp.permitido IS TRUE
      AND rp.alcance = 'empresa',
      false
    ) AS assignment_matches_0032
  FROM expected_roles AS er
  LEFT JOIN public.roles AS r
    ON upper(r.code) = er.role_code
   AND r.is_active = true
  LEFT JOIN public.permisos AS p
    ON p.codigo = 'portal.ver_dashboard'
  LEFT JOIN public.rol_permisos AS rp
    ON rp.rol_id = r.id
   AND rp.permiso_id = p.id
)
SELECT
  '04_asignaciones_dashboard_resumen'::text AS check_name,
  ast.role_order,
  ast.role_code,
  count(ast.role_id)::integer AS active_role_count,
  count(ast.role_id) > 0 AS active_role_exists,
  count(ast.role_id) FILTER (
    WHERE ast.assignment_matches_0032
  )::integer AS valid_assignment_count,
  NOT EXISTS (
    SELECT 1
    FROM assignment_state AS invalid
    WHERE invalid.role_code = ast.role_code
      AND invalid.role_id IS NOT NULL
      AND invalid.assignment_matches_0032 IS NOT TRUE
  ) AS all_existing_active_roles_match_0032
FROM assignment_state AS ast
GROUP BY ast.role_order, ast.role_code
ORDER BY ast.role_order;

WITH supervisor_dashboard_state AS (
  SELECT
    r.company_id,
    r.id AS role_id,
    r.code AS role_code_original,
    p.id AS permission_id,
    p.activo AS permission_active,
    rp.rol_id IS NOT NULL AS assignment_exists,
    rp.permitido,
    rp.alcance,
    COALESCE(
      p.activo IS TRUE
      AND rp.rol_id IS NOT NULL
      AND rp.permitido IS TRUE,
      false
    ) AS assignment_preserved
  FROM public.roles AS r
  LEFT JOIN public.permisos AS p
    ON p.codigo = 'supervisor.dashboard'
  LEFT JOIN public.rol_permisos AS rp
    ON rp.rol_id = r.id
   AND rp.permiso_id = p.id
  WHERE upper(r.code) = 'SUPERVISOR'
    AND r.is_active = true
)
SELECT
  '05_supervisor_dashboard_preservado'::text AS check_name,
  sds.company_id,
  sds.role_id,
  sds.role_code_original,
  sds.permission_id,
  sds.permission_active,
  sds.assignment_exists,
  sds.permitido,
  sds.alcance,
  sds.assignment_preserved
FROM supervisor_dashboard_state AS sds
ORDER BY sds.company_id, sds.role_id;

WITH supervisor_dashboard_state AS (
  SELECT
    r.id AS role_id,
    COALESCE(
      p.activo IS TRUE
      AND rp.rol_id IS NOT NULL
      AND rp.permitido IS TRUE,
      false
    ) AS assignment_preserved
  FROM public.roles AS r
  LEFT JOIN public.permisos AS p
    ON p.codigo = 'supervisor.dashboard'
  LEFT JOIN public.rol_permisos AS rp
    ON rp.rol_id = r.id
   AND rp.permiso_id = p.id
  WHERE upper(r.code) = 'SUPERVISOR'
    AND r.is_active = true
)
SELECT
  '05b_supervisor_dashboard_resumen'::text AS check_name,
  count(sds.role_id)::integer AS active_supervisor_role_count,
  count(sds.role_id) > 0 AS active_supervisor_role_exists,
  count(sds.role_id) FILTER (
    WHERE sds.assignment_preserved
  )::integer AS preserved_assignment_count,
  NOT EXISTS (
    SELECT 1
    FROM supervisor_dashboard_state AS invalid
    WHERE invalid.assignment_preserved IS NOT TRUE
  ) AS all_existing_supervisor_assignments_preserved
FROM supervisor_dashboard_state AS sds;

WITH baseline AS (
  SELECT
    NULL::text AS other_permission_catalog_md5_before,
    NULL::text AS other_role_permissions_md5_before,
    NULL::text AS profile_permissions_md5_before
),
current_state AS (
  SELECT
    md5(COALESCE((
      SELECT string_agg(
        jsonb_build_array(
          p.id,
          p.codigo,
          p.nombre,
          p.descripcion,
          p.modulo,
          p.activo,
          p.created_at,
          p.updated_at
        )::text,
        E'\n' ORDER BY p.id
      )
      FROM public.permisos AS p
      WHERE p.codigo <> 'portal.ver_dashboard'
    ), '')) AS other_permission_catalog_md5_after,
    md5(COALESCE((
      SELECT string_agg(
        jsonb_build_array(
          rp.rol_id,
          rp.permiso_id,
          rp.permitido,
          rp.alcance,
          rp.created_at
        )::text,
        E'\n' ORDER BY rp.rol_id, rp.permiso_id
      )
      FROM public.rol_permisos AS rp
      JOIN public.permisos AS p
        ON p.id = rp.permiso_id
      WHERE p.codigo <> 'portal.ver_dashboard'
    ), '')) AS other_role_permissions_md5_after,
    md5(COALESCE((
      SELECT string_agg(
        jsonb_build_array(
          pp.perfil_id,
          pp.permiso_id,
          pp.permitido,
          pp.alcance,
          pp.created_at
        )::text,
        E'\n' ORDER BY pp.perfil_id, pp.permiso_id
      )
      FROM public.perfil_permisos AS pp
    ), '')) AS profile_permissions_md5_after
)
SELECT
  '06_estado_no_objetivo'::text AS check_name,
  b.other_permission_catalog_md5_before,
  cs.other_permission_catalog_md5_after,
  b.other_role_permissions_md5_before,
  cs.other_role_permissions_md5_after,
  b.profile_permissions_md5_before,
  cs.profile_permissions_md5_after,
  b.other_permission_catalog_md5_before IS NOT NULL
    AND b.other_role_permissions_md5_before IS NOT NULL
    AND b.profile_permissions_md5_before IS NOT NULL
    AS baseline_supplied,
  CASE
    WHEN b.other_permission_catalog_md5_before IS NULL
      OR b.other_role_permissions_md5_before IS NULL
      OR b.profile_permissions_md5_before IS NULL
      THEN 'BASELINE_REQUERIDO'
    WHEN b.other_permission_catalog_md5_before
        IS DISTINCT FROM cs.other_permission_catalog_md5_after
      OR b.other_role_permissions_md5_before
        IS DISTINCT FROM cs.other_role_permissions_md5_after
      OR b.profile_permissions_md5_before
        IS DISTINCT FROM cs.profile_permissions_md5_after
      THEN 'FAIL_ESTADO_NO_OBJETIVO_CAMBIO'
    ELSE 'PASS_ESTADO_NO_OBJETIVO_SIN_CAMBIOS'
  END AS non_target_state_check
FROM baseline AS b
CROSS JOIN current_state AS cs;
