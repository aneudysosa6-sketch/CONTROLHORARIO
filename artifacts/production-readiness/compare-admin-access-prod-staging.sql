-- SOLO STAGING. No ejecutar este archivo en controlhorario-prod.
-- Comparar con un snapshot de produccion previamente aprobado y saneado.
-- Detenerse si el target es ambiguo; usar solo datos sinteticos.
-- Usar el rol SQL y el contexto RLS aprobados para staging.
-- Comparar por check_name, company_slug, role_code_original y permission_code.
-- Diagnostico de solo lectura: no sustituye una sesion JWT real.

SELECT
  '01_contexto'::text AS check_name,
  current_database()::text AS database_name,
  current_user::text AS database_role,
  current_setting('server_version') AS server_version,
  current_setting('row_security') AS row_security_setting,
  COALESCE(
    (SELECT pr.rolbypassrls FROM pg_roles AS pr WHERE pr.rolname = current_user),
    false
  ) AS database_role_bypasses_rls,
  auth.uid() IS NOT NULL AS auth_session_available,
  to_regclass('public.permisos') IS NOT NULL AS permisos_table_exists,
  to_regclass('public.rol_permisos') IS NOT NULL AS rol_permisos_table_exists,
  to_regprocedure('private.normalizar_codigo_rol(text)') IS NOT NULL AS role_normalizer_exists,
  to_regprocedure('public.tiene_permiso(text)') IS NOT NULL AS tiene_permiso_exists,
  to_regprocedure('public.obtener_administracion_sistema()') IS NOT NULL AS obtener_administracion_sistema_exists;

WITH permissions_to_check(permission_order, permission_purpose, permission_code) AS (
  VALUES
    (1, 'RPC_ENTRY'::text, 'configuracion.administrar'::text),
    (2, 'RPC_ENTRY'::text, 'configuracion.ver'::text),
    (3, 'USERS_SECTION'::text, 'usuarios.administrar'::text),
    (4, 'USERS_SECTION'::text, 'roles.administrar'::text),
    (5, 'USERS_SECTION'::text, 'permisos.administrar'::text)
)
SELECT
  '02_catalogo_exacto'::text AS check_name,
  rp.permission_order,
  rp.permission_purpose,
  rp.permission_code,
  p.id IS NOT NULL AS catalog_exists,
  p.id AS permission_id,
  p.codigo AS catalog_code,
  p.nombre AS permission_name,
  p.modulo AS permission_module,
  p.activo AS permission_active
FROM permissions_to_check AS rp
LEFT JOIN public.permisos AS p
  ON p.codigo = rp.permission_code
ORDER BY rp.permission_order;

WITH required_permissions(permission_code) AS (
  VALUES
    ('usuarios.administrar'::text),
    ('roles.administrar'::text),
    ('permisos.administrar'::text)
)
SELECT
  '03_codigos_relacionados'::text AS check_name,
  p.codigo AS permission_code,
  CASE
    WHEN rp.permission_code IS NOT NULL THEN 'EXACTO_REQUERIDO'
    ELSE 'RELACIONADO_NO_EQUIVALENTE'
  END AS code_classification,
  p.nombre AS permission_name,
  p.modulo AS permission_module,
  p.activo AS permission_active
FROM public.permisos AS p
LEFT JOIN required_permissions AS rp
  ON rp.permission_code = p.codigo
WHERE p.codigo LIKE ANY (
  ARRAY['usuarios.%'::text, 'roles.%'::text, 'permisos.%'::text]
)
ORDER BY p.codigo;

WITH admin_roles AS (
  SELECT
    r.id AS role_id,
    r.company_id,
    c.slug AS company_slug,
    r.code AS role_code_original,
    private.normalizar_codigo_rol(r.code) AS role_code_canonical,
    r.is_active AS role_active,
    c.status AS company_status
  FROM public.roles AS r
  JOIN public.companies AS c
    ON c.id = r.company_id
  WHERE private.normalizar_codigo_rol(r.code) = 'ADMIN'
)
SELECT
  '04_roles_admin'::text AS check_name,
  count(*)::integer AS admin_role_count,
  count(*) > 0 AS admin_role_exists,
  COALESCE(
    array_agg(
      ar.company_slug || ':' || ar.role_code_original
      ORDER BY ar.company_id, ar.role_id
    ),
    ARRAY[]::text[]
  ) AS company_role_keys
FROM admin_roles AS ar;

WITH permissions_to_check(permission_order, permission_purpose, permission_code) AS (
  VALUES
    (1, 'RPC_ENTRY'::text, 'configuracion.administrar'::text),
    (2, 'RPC_ENTRY'::text, 'configuracion.ver'::text),
    (3, 'USERS_SECTION'::text, 'usuarios.administrar'::text),
    (4, 'USERS_SECTION'::text, 'roles.administrar'::text),
    (5, 'USERS_SECTION'::text, 'permisos.administrar'::text)
),
admin_roles AS (
  SELECT
    r.id AS role_id,
    r.company_id,
    c.slug AS company_slug,
    r.code AS role_code_original,
    private.normalizar_codigo_rol(r.code) AS role_code_canonical,
    r.is_active AS role_active,
    c.status AS company_status
  FROM public.roles AS r
  JOIN public.companies AS c
    ON c.id = r.company_id
  WHERE private.normalizar_codigo_rol(r.code) = 'ADMIN'
)
SELECT
  '05_asignacion_admin_detalle'::text AS check_name,
  left(ar.company_id::text, 8) AS company_id_prefix,
  ar.company_slug,
  ar.role_id,
  ar.role_code_original,
  ar.role_code_canonical,
  ar.role_active,
  ar.company_status,
  req.permission_order,
  req.permission_purpose,
  req.permission_code,
  p.id IS NOT NULL AS catalog_exists,
  p.activo AS permission_active,
  rperm.rol_id IS NOT NULL AS role_assignment_exists,
  rperm.permitido,
  rperm.alcance,
  COALESCE(p.activo AND rperm.permitido, false) AS boolean_permission_granted,
  COALESCE(
    p.activo
    AND rperm.permitido
    AND rperm.alcance = 'empresa',
    false
  ) AS assignment_matches_admin_contract,
  COALESCE(
    ar.role_active
    AND ar.company_status = 'active'
    AND p.activo
    AND rperm.permitido
    AND rperm.alcance = 'empresa',
    false
  ) AS operational_admin_assignment
FROM admin_roles AS ar
CROSS JOIN permissions_to_check AS req
LEFT JOIN public.permisos AS p
  ON p.codigo = req.permission_code
LEFT JOIN public.rol_permisos AS rperm
  ON rperm.rol_id = ar.role_id
 AND rperm.permiso_id = p.id
ORDER BY ar.company_id, ar.role_id, req.permission_order;

WITH permissions_to_check(permission_order, permission_purpose, permission_code) AS (
  VALUES
    (1, 'RPC_ENTRY'::text, 'configuracion.administrar'::text),
    (2, 'RPC_ENTRY'::text, 'configuracion.ver'::text),
    (3, 'USERS_SECTION'::text, 'usuarios.administrar'::text),
    (4, 'USERS_SECTION'::text, 'roles.administrar'::text),
    (5, 'USERS_SECTION'::text, 'permisos.administrar'::text)
),
admin_roles AS (
  SELECT
    r.id AS role_id,
    r.company_id,
    c.slug AS company_slug,
    r.code AS role_code_original,
    private.normalizar_codigo_rol(r.code) AS role_code_canonical,
    r.is_active AS role_active,
    c.status AS company_status
  FROM public.roles AS r
  JOIN public.companies AS c
    ON c.id = r.company_id
  WHERE private.normalizar_codigo_rol(r.code) = 'ADMIN'
),
permission_state AS (
  SELECT
    ar.*,
    req.permission_order,
    req.permission_purpose,
    req.permission_code,
    p.id IS NOT NULL AS catalog_exists,
    p.activo AS permission_active,
    rperm.rol_id IS NOT NULL AS role_assignment_exists,
    rperm.permitido,
    rperm.alcance,
    COALESCE(p.activo AND rperm.permitido, false) AS boolean_permission_granted,
    COALESCE(
      ar.role_active AND p.activo AND rperm.permitido,
      false
    ) AS role_fallback_permission_available,
    COALESCE(
      p.activo
      AND rperm.permitido
      AND rperm.alcance = 'empresa',
      false
    ) AS assignment_matches_admin_contract,
    COALESCE(
      ar.role_active
      AND ar.company_status = 'active'
      AND p.activo
      AND rperm.permitido
      AND rperm.alcance = 'empresa',
      false
    ) AS operational_admin_assignment
  FROM admin_roles AS ar
  CROSS JOIN permissions_to_check AS req
  LEFT JOIN public.permisos AS p
    ON p.codigo = req.permission_code
  LEFT JOIN public.rol_permisos AS rperm
    ON rperm.rol_id = ar.role_id
   AND rperm.permiso_id = p.id
)
SELECT
  '06_asignacion_admin_resumen'::text AS check_name,
  left(ps.company_id::text, 8) AS company_id_prefix,
  ps.company_slug,
  ps.role_id,
  ps.role_code_original,
  ps.role_code_canonical,
  ps.role_active,
  ps.company_status,
  COALESCE(
    array_agg(ps.permission_code ORDER BY ps.permission_order)
      FILTER (
        WHERE ps.permission_purpose = 'RPC_ENTRY'
          AND ps.role_fallback_permission_available
      ),
    ARRAY[]::text[]
  ) AS granted_entry_codes,
  COALESCE(
    array_agg(ps.permission_code ORDER BY ps.permission_order)
      FILTER (
        WHERE ps.permission_purpose = 'USERS_SECTION'
          AND ps.role_fallback_permission_available
      ),
    ARRAY[]::text[]
  ) AS granted_users_section_codes,
  COALESCE(
    array_agg(ps.permission_code ORDER BY ps.permission_order)
      FILTER (WHERE NOT ps.catalog_exists),
    ARRAY[]::text[]
  ) AS missing_catalog_codes,
  COALESCE(
    array_agg(ps.permission_code ORDER BY ps.permission_order)
      FILTER (WHERE NOT ps.role_assignment_exists),
    ARRAY[]::text[]
  ) AS missing_role_assignment_codes,
  COALESCE(
    array_agg(ps.permission_code ORDER BY ps.permission_order)
      FILTER (
        WHERE ps.role_assignment_exists
          AND ps.permitido IS NOT TRUE
      ),
    ARRAY[]::text[]
  ) AS denied_role_codes,
  COALESCE(
    array_agg(ps.permission_code ORDER BY ps.permission_order)
      FILTER (
        WHERE ps.catalog_exists
          AND ps.permission_active IS NOT TRUE
      ),
    ARRAY[]::text[]
  ) AS inactive_catalog_codes,
  COALESCE(
    array_agg(ps.permission_code ORDER BY ps.permission_order)
      FILTER (
        WHERE ps.role_assignment_exists
          AND ps.alcance IS DISTINCT FROM 'empresa'
      ),
    ARRAY[]::text[]
  ) AS unexpected_scope_codes,
  bool_or(ps.role_fallback_permission_available)
    FILTER (WHERE ps.permission_purpose = 'RPC_ENTRY')
    AS entry_gate_allowed_by_direct_role,
  bool_or(ps.role_fallback_permission_available)
    FILTER (WHERE ps.permission_purpose = 'USERS_SECTION')
    AS users_section_allowed_by_direct_role,
  (
    bool_or(ps.role_fallback_permission_available)
      FILTER (WHERE ps.permission_purpose = 'RPC_ENTRY')
    AND
    bool_or(ps.role_fallback_permission_available)
      FILTER (WHERE ps.permission_purpose = 'USERS_SECTION')
  ) AS rpc_users_access_by_direct_role,
  (
    bool_or(ps.operational_admin_assignment)
      FILTER (WHERE ps.permission_purpose = 'RPC_ENTRY')
    AND
    bool_or(ps.operational_admin_assignment)
      FILTER (WHERE ps.permission_purpose = 'USERS_SECTION')
  ) AS rpc_users_access_matches_admin_contract
FROM permission_state AS ps
GROUP BY
  ps.company_id,
  ps.company_slug,
  ps.role_id,
  ps.role_code_original,
  ps.role_code_canonical,
  ps.role_active,
  ps.company_status
ORDER BY ps.company_id, ps.role_id;

WITH wanted_functions(signature) AS (
  VALUES
    ('private.normalizar_codigo_rol(text)'::text),
    ('public.obtener_administracion_sistema()'::text),
    ('public.tiene_permiso(text)'::text),
    ('public.obtener_empresa_actual()'::text),
    ('public.obtener_rol_actual()'::text),
    ('public.obtener_mi_autorizacion()'::text),
    ('public.perfil_acceso_utilizable_internal(uuid,uuid)'::text)
),
resolved_functions AS (
  SELECT
    wf.signature,
    to_regprocedure(wf.signature) AS function_oid
  FROM wanted_functions AS wf
)
SELECT
  '07_huella_funciones'::text AS check_name,
  rf.signature,
  rf.function_oid IS NOT NULL AS function_exists,
  pg_get_userbyid(p.proowner) AS function_owner,
  pg_get_function_result(p.oid) AS function_result,
  CASE p.provolatile
    WHEN 'i' THEN 'IMMUTABLE'
    WHEN 's' THEN 'STABLE'
    WHEN 'v' THEN 'VOLATILE'
    ELSE NULL::text
  END AS volatility,
  p.prosecdef AS security_definer,
  p.proconfig AS function_config,
  p.proacl::text AS function_acl,
  CASE
    WHEN p.oid IS NULL THEN NULL::text
    ELSE md5(pg_get_functiondef(p.oid))
  END AS function_definition_md5
FROM resolved_functions AS rf
LEFT JOIN pg_proc AS p
  ON p.oid = rf.function_oid
ORDER BY rf.signature;

WITH function_source AS (
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
  FROM function_source AS fs
)
SELECT
  '08_contrato_obtener_administracion_sistema'::text AS check_name,
  fd.function_oid IS NOT NULL AS function_exists,
  md5(fd.definition) AS function_definition_md5,
  position('configuracion.administrar' IN COALESCE(fd.definition, '')) > 0
    AS uses_configuracion_administrar,
  position('configuracion.ver' IN COALESCE(fd.definition, '')) > 0
    AS uses_configuracion_ver,
  position('usuarios.administrar' IN COALESCE(fd.definition, '')) > 0
    AS uses_usuarios_administrar,
  position('roles.administrar' IN COALESCE(fd.definition, '')) > 0
    AS uses_roles_administrar,
  position('permisos.administrar' IN COALESCE(fd.definition, '')) > 0
    AS uses_permisos_administrar
FROM function_definition AS fd;

WITH permissions_to_check(permission_order, permission_purpose, permission_code) AS (
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
  '09_permisos_efectivos_sesion'::text AS check_name,
  sc.auth_user_id IS NOT NULL AS auth_session_available,
  pc.permission_order,
  pc.permission_purpose,
  pc.permission_code,
  CASE
    WHEN sc.auth_user_id IS NULL THEN NULL::boolean
    ELSE public.tiene_permiso(pc.permission_code)
  END AS effective_permission
FROM session_context AS sc
CROSS JOIN permissions_to_check AS pc
ORDER BY pc.permission_order;

WITH session_context AS (
  SELECT auth.uid()::uuid AS auth_user_id
),
session_gate AS (
  SELECT
    sc.auth_user_id,
    CASE
      WHEN sc.auth_user_id IS NULL THEN NULL::boolean
      ELSE public.tiene_permiso('configuracion.administrar')
        OR public.tiene_permiso('configuracion.ver')
    END AS entry_permission
  FROM session_context AS sc
),
rpc_result AS (
  SELECT
    sg.auth_user_id,
    sg.entry_permission,
    CASE
      WHEN sg.auth_user_id IS NULL OR sg.entry_permission IS NOT TRUE THEN NULL::jsonb
      ELSE public.obtener_administracion_sistema()
    END AS payload
  FROM session_gate AS sg
)
SELECT
  '10_resultado_rpc_sesion'::text AS check_name,
  rr.auth_user_id IS NOT NULL AS auth_session_available,
  rr.entry_permission,
  CASE
    WHEN rr.auth_user_id IS NULL THEN 'NO_EJECUTADA_AUTH_UID_NULL'
    WHEN rr.entry_permission IS NOT TRUE THEN 'NO_EJECUTADA_PERMISO_ENTRADA'
    ELSE 'EJECUTADA_CON_SESION_AUTH'
  END AS rpc_execution_status,
  (rr.payload -> 'sections' ->> 'usuarios')::boolean AS users_section_allowed,
  rr.payload -> 'sections' AS sections
FROM rpc_result AS rr;
