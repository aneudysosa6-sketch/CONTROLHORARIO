-- Postflight de solo lectura para 0031_admin_access_permissions.sql.
-- Ejecutar primero con privilegios de diagnostico para revisar catalogo y roles.
-- Ejecutar tambien con el JWT de un ADMIN valido para completar la ultima prueba.

SELECT
  '01_contexto'::text AS check_name,
  current_database()::text AS database_name,
  current_user::text AS database_role,
  auth.uid() IS NOT NULL AS auth_session_available,
  to_regprocedure('public.tiene_permiso(text)') IS NOT NULL
    AS tiene_permiso_exists,
  to_regprocedure('public.obtener_administracion_sistema()') IS NOT NULL
    AS obtener_administracion_sistema_exists;

WITH expected_permissions(
  permission_order,
  permission_code,
  expected_name,
  expected_description,
  expected_module
) AS (
  VALUES
    (
      1,
      'usuarios.administrar'::text,
      'Administrar usuarios'::text,
      'Gestiona usuarios, estados de acceso y asignaciones de rol de la empresa.'::text,
      'administracion'::text
    ),
    (
      2,
      'roles.administrar'::text,
      'Administrar roles'::text,
      'Gestiona roles de autorizacion de la empresa.'::text,
      'administracion'::text
    ),
    (
      3,
      'permisos.administrar'::text,
      'Administrar permisos'::text,
      'Gestiona permisos asignados a los roles de la empresa.'::text,
      'administracion'::text
    )
)
SELECT
  '02_catalogo_0031'::text AS check_name,
  ep.permission_order,
  ep.permission_code,
  p.id IS NOT NULL AS permission_exists,
  p.id AS permission_id,
  p.nombre AS permission_name,
  p.descripcion AS permission_description,
  p.modulo AS permission_module,
  p.activo AS permission_active,
  COALESCE(
    p.nombre = ep.expected_name
      AND p.descripcion = ep.expected_description
      AND p.modulo = ep.expected_module,
    false
  ) AS metadata_matches_0031,
  COALESCE(p.activo, false) AS catalog_ready
FROM expected_permissions AS ep
LEFT JOIN public.permisos AS p
  ON p.codigo = ep.permission_code
ORDER BY ep.permission_order;

WITH target_admin_roles AS (
  SELECT
    r.id AS role_id,
    r.company_id,
    c.slug AS company_slug,
    c.status AS company_status,
    r.code AS role_code_original,
    r.is_active AS role_active
  FROM public.roles AS r
  JOIN public.companies AS c
    ON c.id = r.company_id
  WHERE upper(r.code) = 'ADMIN'
    AND r.is_active = true
)
SELECT
  '03_roles_admin_objetivo'::text AS check_name,
  count(*)::integer AS active_admin_role_count,
  count(*) > 0 AS active_admin_role_exists,
  count(*) FILTER (WHERE tar.company_status = 'active')::integer
    AS active_admin_roles_in_active_companies,
  COALESCE(
    array_agg(
      tar.company_slug || ':' || tar.role_code_original
      ORDER BY tar.company_id, tar.role_id
    ),
    ARRAY[]::text[]
  ) AS company_role_keys
FROM target_admin_roles AS tar;

WITH expected_permissions(permission_order, permission_code) AS (
  VALUES
    (1, 'usuarios.administrar'::text),
    (2, 'roles.administrar'::text),
    (3, 'permisos.administrar'::text)
),
target_admin_roles AS (
  SELECT
    r.id AS role_id,
    r.company_id,
    c.slug AS company_slug,
    c.status AS company_status,
    r.code AS role_code_original,
    r.is_active AS role_active
  FROM public.roles AS r
  JOIN public.companies AS c
    ON c.id = r.company_id
  WHERE upper(r.code) = 'ADMIN'
    AND r.is_active = true
)
SELECT
  '04_asignaciones_0031_detalle'::text AS check_name,
  tar.company_id,
  tar.company_slug,
  tar.company_status,
  tar.role_id,
  tar.role_code_original,
  tar.role_active,
  ep.permission_order,
  ep.permission_code,
  p.id IS NOT NULL AS permission_exists,
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
  ) AS assignment_matches_0031
FROM target_admin_roles AS tar
CROSS JOIN expected_permissions AS ep
LEFT JOIN public.permisos AS p
  ON p.codigo = ep.permission_code
LEFT JOIN public.rol_permisos AS rp
  ON rp.rol_id = tar.role_id
 AND rp.permiso_id = p.id
ORDER BY tar.company_id, tar.role_id, ep.permission_order;

WITH expected_permissions(
  permission_code,
  expected_name,
  expected_description,
  expected_module
) AS (
  VALUES
    (
      'usuarios.administrar'::text,
      'Administrar usuarios'::text,
      'Gestiona usuarios, estados de acceso y asignaciones de rol de la empresa.'::text,
      'administracion'::text
    ),
    (
      'roles.administrar'::text,
      'Administrar roles'::text,
      'Gestiona roles de autorizacion de la empresa.'::text,
      'administracion'::text
    ),
    (
      'permisos.administrar'::text,
      'Administrar permisos'::text,
      'Gestiona permisos asignados a los roles de la empresa.'::text,
      'administracion'::text
    )
),
catalog_state AS (
  SELECT
    ep.permission_code,
    p.id IS NOT NULL AS permission_exists,
    p.activo AS permission_active,
    COALESCE(
      p.nombre = ep.expected_name
        AND p.descripcion = ep.expected_description
        AND p.modulo = ep.expected_module,
      false
    ) AS metadata_matches_0031
  FROM expected_permissions AS ep
  LEFT JOIN public.permisos AS p
    ON p.codigo = ep.permission_code
),
target_admin_roles AS (
  SELECT r.id AS role_id
  FROM public.roles AS r
  WHERE upper(r.code) = 'ADMIN'
    AND r.is_active = true
),
entry_permissions(permission_code) AS (
  VALUES
    ('configuracion.administrar'::text),
    ('configuracion.ver'::text)
),
entry_state AS (
  SELECT
    tar.role_id,
    ep.permission_code,
    COALESCE(
      p.activo IS TRUE
        AND rp.rol_id IS NOT NULL
        AND rp.permitido IS TRUE,
      false
    ) AS entry_permission_available
  FROM target_admin_roles AS tar
  CROSS JOIN entry_permissions AS ep
  LEFT JOIN public.permisos AS p
    ON p.codigo = ep.permission_code
  LEFT JOIN public.rol_permisos AS rp
    ON rp.rol_id = tar.role_id
   AND rp.permiso_id = p.id
),
entry_by_role AS (
  SELECT
    es.role_id,
    bool_or(es.entry_permission_available) AS entry_gate_available
  FROM entry_state AS es
  GROUP BY es.role_id
),
assignment_state AS (
  SELECT
    tar.role_id,
    ep.permission_code,
    COALESCE(
      p.activo IS TRUE
        AND rp.rol_id IS NOT NULL
        AND rp.permitido IS TRUE
        AND rp.alcance = 'empresa',
      false
    ) AS assignment_matches_0031
  FROM target_admin_roles AS tar
  CROSS JOIN expected_permissions AS ep
  LEFT JOIN public.permisos AS p
    ON p.codigo = ep.permission_code
  LEFT JOIN public.rol_permisos AS rp
    ON rp.rol_id = tar.role_id
   AND rp.permiso_id = p.id
),
summary AS (
  SELECT
    (
      SELECT count(*) = 3
      FROM catalog_state AS cs
      WHERE cs.permission_exists
        AND cs.permission_active IS TRUE
    ) AS all_permissions_exist_and_are_active,
    (
      SELECT count(*) = 3
      FROM catalog_state AS cs
      WHERE cs.permission_exists
        AND cs.permission_active IS TRUE
        AND cs.metadata_matches_0031
    ) AS all_permissions_match_0031,
    (SELECT count(*) FROM target_admin_roles)::integer
      AS active_admin_role_count,
    (
      SELECT count(*)
      FROM entry_by_role AS ebr
      WHERE ebr.entry_gate_available IS NOT TRUE
    )::integer AS admin_roles_without_entry_gate_count,
    NOT EXISTS (
      SELECT 1
      FROM assignment_state AS ast
      WHERE ast.assignment_matches_0031 IS NOT TRUE
    ) AS no_invalid_target_assignment
)
SELECT
  '05_resumen_0031'::text AS check_name,
  s.all_permissions_exist_and_are_active,
  s.all_permissions_match_0031,
  s.active_admin_role_count,
  s.active_admin_role_count > 0 AS active_admin_role_exists,
  s.admin_roles_without_entry_gate_count,
  s.active_admin_role_count > 0
    AND s.admin_roles_without_entry_gate_count = 0
    AS all_target_admin_roles_have_entry_gate,
  s.active_admin_role_count > 0
    AND s.no_invalid_target_assignment AS all_target_assignments_match_0031,
  s.all_permissions_exist_and_are_active
    AND s.all_permissions_match_0031
    AND s.active_admin_role_count > 0
    AND s.admin_roles_without_entry_gate_count = 0
    AND s.no_invalid_target_assignment AS postflight_data_pass
FROM summary AS s;

WITH function_state AS (
  SELECT
    to_regprocedure('public.obtener_administracion_sistema()') AS function_oid
),
function_definition AS (
  SELECT
    fs.function_oid,
    CASE
      WHEN fs.function_oid IS NULL THEN NULL::text
      ELSE pg_get_functiondef(fs.function_oid)
    END AS definition
  FROM function_state AS fs
)
SELECT
  '06_contrato_rpc'::text AS check_name,
  fd.function_oid IS NOT NULL AS function_exists,
  position(
    'configuracion.administrar' IN COALESCE(fd.definition, '')
  ) > 0 AS uses_configuracion_administrar_for_entry,
  position(
    'configuracion.ver' IN COALESCE(fd.definition, '')
  ) > 0 AS uses_configuracion_ver_for_entry,
  position(
    'usuarios.administrar' IN COALESCE(fd.definition, '')
  ) > 0 AS uses_usuarios_administrar_for_users,
  position(
    'roles.administrar' IN COALESCE(fd.definition, '')
  ) > 0 AS uses_roles_administrar_for_users,
  position(
    'permisos.administrar' IN COALESCE(fd.definition, '')
  ) > 0 AS uses_permisos_administrar_for_users
FROM function_definition AS fd;

WITH permission_contract(permission_order, permission_purpose, permission_code) AS (
  VALUES
    (1, 'RPC_ENTRY'::text, 'configuracion.administrar'::text),
    (2, 'RPC_ENTRY'::text, 'configuracion.ver'::text),
    (3, 'USERS_SECTION'::text, 'usuarios.administrar'::text),
    (4, 'USERS_SECTION'::text, 'roles.administrar'::text),
    (5, 'USERS_SECTION'::text, 'permisos.administrar'::text)
),
session_context AS (
  SELECT auth.uid()::uuid AS auth_user_id
)
SELECT
  '07_permisos_efectivos_sesion'::text AS check_name,
  sc.auth_user_id IS NOT NULL AS auth_session_available,
  pc.permission_order,
  pc.permission_purpose,
  pc.permission_code,
  CASE
    WHEN sc.auth_user_id IS NULL THEN NULL::boolean
    ELSE public.tiene_permiso(pc.permission_code)
  END AS effective_permission
FROM session_context AS sc
CROSS JOIN permission_contract AS pc
ORDER BY pc.permission_order;

WITH session_context AS (
  SELECT auth.uid()::uuid AS auth_user_id
),
session_state AS (
  SELECT
    sc.auth_user_id,
    p.company_id,
    p.status AS profile_status,
    p.access_deleted_at,
    r.id AS role_id,
    r.code AS role_code_original,
    r.is_active AS role_active,
    c.status AS company_status
  FROM session_context AS sc
  LEFT JOIN public.profiles AS p
    ON p.id = sc.auth_user_id
  LEFT JOIN public.roles AS r
    ON r.id = p.role_id
   AND r.company_id = p.company_id
  LEFT JOIN public.companies AS c
    ON c.id = p.company_id
),
effective_permissions AS (
  SELECT
    ss.*,
    CASE
      WHEN ss.auth_user_id IS NULL THEN NULL::boolean
      ELSE public.tiene_permiso('configuracion.administrar')
        OR public.tiene_permiso('configuracion.ver')
    END AS entry_permission,
    CASE
      WHEN ss.auth_user_id IS NULL THEN NULL::boolean
      ELSE public.tiene_permiso('usuarios.administrar')
        OR public.tiene_permiso('roles.administrar')
        OR public.tiene_permiso('permisos.administrar')
    END AS users_section_permission
  FROM session_state AS ss
),
validated_session AS (
  SELECT
    ep.*,
    ep.auth_user_id IS NOT NULL
      AND ep.profile_status = 'active'
      AND ep.access_deleted_at IS NULL
      AND ep.role_id IS NOT NULL
      AND ep.role_active IS TRUE
      AND upper(ep.role_code_original) = 'ADMIN'
      AND ep.company_status = 'active' AS valid_admin_session
  FROM effective_permissions AS ep
),
rpc_result AS (
  SELECT
    vs.*,
    CASE
      WHEN vs.valid_admin_session IS NOT TRUE
        OR vs.entry_permission IS NOT TRUE
      THEN NULL::jsonb
      ELSE public.obtener_administracion_sistema()
    END AS payload
  FROM validated_session AS vs
)
SELECT
  '08_rpc_sesion_admin'::text AS check_name,
  rr.auth_user_id IS NOT NULL AS auth_session_available,
  rr.valid_admin_session,
  rr.role_code_original,
  rr.entry_permission,
  rr.users_section_permission AS expected_users_section_allowed,
  CASE
    WHEN rr.auth_user_id IS NULL THEN 'NO_EJECUTADA_AUTH_UID_NULL'
    WHEN rr.valid_admin_session IS NOT TRUE THEN 'NO_EJECUTADA_SESION_ADMIN_INVALIDA'
    WHEN rr.entry_permission IS NOT TRUE THEN 'NO_EJECUTADA_PERMISO_ENTRADA'
    ELSE 'EJECUTADA_CON_SESION_ADMIN_VALIDA'
  END AS rpc_execution_status,
  rr.payload IS NOT NULL AS payload_returned,
  (rr.payload -> 'sections' ->> 'usuarios')::boolean
    AS users_section_allowed,
  CASE
    WHEN rr.payload IS NULL THEN NULL::boolean
    ELSE (rr.payload -> 'sections' ->> 'usuarios')::boolean
      IS NOT DISTINCT FROM rr.users_section_permission
  END AS users_section_matches_effective_permissions,
  CASE
    WHEN rr.payload IS NULL THEN NULL::boolean
    ELSE COALESCE(
      (rr.payload -> 'sections' ->> 'usuarios')::boolean,
      false
    )
  END AS rpc_users_section_pass
FROM rpc_result AS rr;
