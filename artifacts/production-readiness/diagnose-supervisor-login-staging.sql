-- Diagnostico de login SUPERVISOR en staging.
-- SOLO LECTURA: este archivo contiene un unico SELECT con CTE.
--
-- Uso:
--   1. Reemplazar NULL::uuid por el auth.users.id del supervisor en
--      auth_user_id_override. Si se deja NULL, se intenta usar auth.uid().
--   2. Ejecutar exclusivamente contra controlhorario-staging.
--
-- permission_codes_sesion_calculados reproduce la prioridad aplicada por
-- public.obtener_mi_autorizacion(): perfil_permisos > rol_permisos > false,
-- considerando solamente permisos activos.

-- SOLO STAGING. Usar datos sinteticos; no ejecutar en controlhorario-prod.
-- Detenerse si el target es ambiguo. Produccion permanece NO-GO.
WITH params AS (
  SELECT
    NULL::uuid AS auth_user_id_override
),
target AS (
  SELECT
    COALESCE(p.auth_user_id_override, auth.uid()) AS auth_user_id,
    CASE
      WHEN p.auth_user_id_override IS NOT NULL THEN 'AUTH_USER_ID_OVERRIDE'
      WHEN auth.uid() IS NOT NULL THEN 'AUTH_UID'
      ELSE 'SIN_AUTH_USER_ID'
    END AS modo_resolucion
  FROM params AS p
),
identity AS (
  SELECT
    t.modo_resolucion,
    t.auth_user_id,
    pr.id AS profile_id,
    pr.company_id,
    pr.role_id,
    pr.status AS profile_status,
    pr.access_deleted_at,
    c.status AS company_status,
    r.company_id AS role_company_id,
    r.code AS role_code_original,
    CASE
      WHEN r.code IS NULL THEN NULL::text
      ELSE private.normalizar_codigo_rol(r.code)
    END AS role_code_canonical,
    r.is_active AS role_is_active,
    r.created_at AS role_created_at
  FROM target AS t
  LEFT JOIN public.profiles AS pr
    ON pr.id = t.auth_user_id
  LEFT JOIN public.companies AS c
    ON c.id = pr.company_id
  LEFT JOIN public.roles AS r
    ON r.id = pr.role_id
),
employee_state AS (
  SELECT
    i.profile_id,
    count(e.id) AS empleados_vinculados,
    count(e.id) FILTER (
      WHERE e.activo AND e.estado_laboral = 'activo'
    ) AS empleados_activos_vinculados,
    COALESCE(
      bool_or(
        e.id IS NOT NULL
        AND (NOT e.activo OR e.estado_laboral = 'desvinculado')
      ),
      false
    ) AS existe_empleado_desvinculado
  FROM identity AS i
  LEFT JOIN public.empleados AS e
    ON e.perfil_id = i.profile_id
   AND e.empresa_id = i.company_id
  GROUP BY i.profile_id
),
permission_resolution AS (
  SELECT
    pe.codigo,
    pp.permitido AS override_perfil,
    pp.alcance AS alcance_override_perfil,
    rp.permitido AS permitido_rol,
    rp.alcance AS alcance_rol,
    COALESCE(pp.permitido, rp.permitido, false) AS permitido_sesion
  FROM identity AS i
  CROSS JOIN public.permisos AS pe
  LEFT JOIN public.perfil_permisos AS pp
    ON pp.perfil_id = i.profile_id
   AND pp.permiso_id = pe.id
  LEFT JOIN public.rol_permisos AS rp
    ON rp.rol_id = i.role_id
   AND rp.permiso_id = pe.id
  WHERE pe.activo
),
session_permissions AS (
  SELECT
    COALESCE(
      array_agg(pr.codigo ORDER BY pr.codigo)
        FILTER (WHERE pr.permitido_sesion),
      ARRAY[]::text[]
    ) AS permission_codes_sesion_calculados
  FROM permission_resolution AS pr
),
direct_role_permissions AS (
  SELECT
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'codigo', pe.codigo,
          'permitido', rp.permitido,
          'alcance', rp.alcance,
          'permiso_activo', pe.activo
        )
        ORDER BY pe.codigo
      ) FILTER (WHERE rp.permiso_id IS NOT NULL),
      '[]'::jsonb
    ) AS permisos_directos_rol
  FROM identity AS i
  LEFT JOIN public.rol_permisos AS rp
    ON rp.rol_id = i.role_id
  LEFT JOIN public.permisos AS pe
    ON pe.id = rp.permiso_id
),
key_permissions AS (
  SELECT
    (
      count(*) FILTER (WHERE pr.codigo = 'portal.ver_dashboard') > 0
    ) AS portal_ver_dashboard_catalogo_activo,
    COALESCE(
      bool_or(pr.permitido_sesion)
        FILTER (WHERE pr.codigo = 'portal.ver_dashboard'),
      false
    ) AS portal_ver_dashboard_sesion,
    COALESCE(
      bool_or(pr.permitido_rol)
        FILTER (WHERE pr.codigo = 'portal.ver_dashboard'),
      false
    ) AS portal_ver_dashboard_rol,
    bool_or(pr.override_perfil)
      FILTER (WHERE pr.codigo = 'portal.ver_dashboard')
      AS portal_ver_dashboard_override_perfil,
    (
      count(*) FILTER (WHERE pr.codigo = 'supervisor.dashboard') > 0
    ) AS supervisor_dashboard_catalogo_activo,
    COALESCE(
      bool_or(pr.permitido_sesion)
        FILTER (WHERE pr.codigo = 'supervisor.dashboard'),
      false
    ) AS supervisor_dashboard_sesion,
    COALESCE(
      bool_or(pr.permitido_rol)
        FILTER (WHERE pr.codigo = 'supervisor.dashboard'),
      false
    ) AS supervisor_dashboard_rol,
    bool_or(pr.override_perfil)
      FILTER (WHERE pr.codigo = 'supervisor.dashboard')
      AS supervisor_dashboard_override_perfil,
    (
      count(*) FILTER (WHERE pr.codigo = 'empleados.ver_asignados') > 0
    ) AS empleados_ver_asignados_catalogo_activo,
    COALESCE(
      bool_or(pr.permitido_sesion)
        FILTER (WHERE pr.codigo = 'empleados.ver_asignados'),
      false
    ) AS empleados_ver_asignados_sesion,
    COALESCE(
      bool_or(pr.permitido_rol)
        FILTER (WHERE pr.codigo = 'empleados.ver_asignados'),
      false
    ) AS empleados_ver_asignados_rol,
    bool_or(pr.override_perfil)
      FILTER (WHERE pr.codigo = 'empleados.ver_asignados')
      AS empleados_ver_asignados_override_perfil,
    (
      count(*) FILTER (WHERE pr.codigo = 'jornadas.ver_asignadas') > 0
    ) AS jornadas_ver_asignadas_catalogo_activo,
    COALESCE(
      bool_or(pr.permitido_sesion)
        FILTER (WHERE pr.codigo = 'jornadas.ver_asignadas'),
      false
    ) AS jornadas_ver_asignadas_sesion,
    COALESCE(
      bool_or(pr.permitido_rol)
        FILTER (WHERE pr.codigo = 'jornadas.ver_asignadas'),
      false
    ) AS jornadas_ver_asignadas_rol,
    bool_or(pr.override_perfil)
      FILTER (WHERE pr.codigo = 'jornadas.ver_asignadas')
      AS jornadas_ver_asignadas_override_perfil
  FROM permission_resolution AS pr
)
SELECT
  i.modo_resolucion,
  i.auth_user_id,
  i.profile_id IS NOT NULL AS perfil_encontrado,
  i.profile_status,
  (
    i.profile_status = 'active'
    AND i.access_deleted_at IS NULL
  ) AS perfil_activo,
  i.company_id,
  i.company_status,
  (i.company_status = 'active') AS empresa_activa,
  i.role_id,
  i.role_code_original,
  i.role_code_canonical,
  i.role_is_active AS rol_activo,
  i.role_created_at,
  (
    i.role_id IS NOT NULL
    AND i.role_company_id = i.company_id
  ) AS rol_pertenece_a_empresa,
  es.empleados_vinculados,
  es.empleados_activos_vinculados,
  es.existe_empleado_desvinculado,
  sp.permission_codes_sesion_calculados,
  (
    cardinality(sp.permission_codes_sesion_calculados) = 0
  ) AS permission_codes_vacios,
  drp.permisos_directos_rol,
  kp.portal_ver_dashboard_catalogo_activo,
  kp.portal_ver_dashboard_sesion,
  kp.portal_ver_dashboard_rol,
  kp.portal_ver_dashboard_override_perfil,
  kp.supervisor_dashboard_catalogo_activo,
  kp.supervisor_dashboard_sesion,
  kp.supervisor_dashboard_rol,
  kp.supervisor_dashboard_override_perfil,
  kp.empleados_ver_asignados_catalogo_activo,
  kp.empleados_ver_asignados_sesion,
  kp.empleados_ver_asignados_rol,
  kp.empleados_ver_asignados_override_perfil,
  kp.jornadas_ver_asignadas_catalogo_activo,
  kp.jornadas_ver_asignadas_sesion,
  kp.jornadas_ver_asignadas_rol,
  kp.jornadas_ver_asignadas_override_perfil,
  CASE
    WHEN i.role_code_canonical = 'EMPLEADO' THEN '/mi-portal'
    ELSE '/dashboard'
  END AS ruta_inicial_web_actual,
  CASE
    WHEN i.role_code_canonical = 'EMPLEADO' THEN 'rol EMPLEADO'
    ELSE 'portal.ver_dashboard'
  END AS requisito_guard_ruta_inicial,
  CASE
    WHEN i.auth_user_id IS NULL THEN 'DEFINIR auth_user_id_override'
    WHEN i.profile_id IS NULL THEN '/login (PROFILE_NOT_FOUND)'
    WHEN i.profile_status <> 'active' OR i.access_deleted_at IS NOT NULL
      THEN '/login (PROFILE_INACTIVE)'
    WHEN i.company_status IS DISTINCT FROM 'active'
      THEN '/login (COMPANY_INACTIVE)'
    WHEN i.role_id IS NULL OR i.role_company_id IS DISTINCT FROM i.company_id
      THEN '/login (ROLE_NOT_FOUND)'
    WHEN i.role_is_active IS DISTINCT FROM true
      THEN '/login (ROLE_INACTIVE)'
    WHEN es.existe_empleado_desvinculado
      THEN '/login (PROFILE_INACTIVE por empleado desvinculado)'
    WHEN i.role_code_canonical = 'EMPLEADO' THEN '/mi-portal'
    WHEN kp.portal_ver_dashboard_sesion THEN '/dashboard'
    WHEN kp.empleados_ver_asignados_sesion THEN '/empleados'
    WHEN kp.jornadas_ver_asignadas_sesion THEN '/jornadas'
    ELSE '/acceso-denegado'
  END AS ruta_accesible_con_guards_actuales,
  CASE
    WHEN i.role_code_canonical = 'SUPERVISOR'
     AND kp.supervisor_dashboard_sesion
      THEN '/dashboard'
    WHEN i.role_code_canonical = 'SUPERVISOR'
     AND kp.empleados_ver_asignados_sesion
      THEN '/empleados'
    WHEN i.role_code_canonical = 'SUPERVISOR'
     AND kp.jornadas_ver_asignadas_sesion
      THEN '/jornadas'
    WHEN i.role_code_canonical = 'EMPLEADO' THEN '/mi-portal'
    WHEN kp.portal_ver_dashboard_sesion THEN '/dashboard'
    ELSE '/acceso-denegado'
  END AS ruta_recomendada_segun_permisos,
  CASE
    WHEN i.auth_user_id IS NULL THEN 'FALTA_AUTH_USER_ID_OVERRIDE'
    WHEN i.profile_id IS NULL THEN 'PROFILE_NOT_FOUND'
    WHEN i.profile_status <> 'active' OR i.access_deleted_at IS NOT NULL
      THEN 'PROFILE_INACTIVE'
    WHEN i.company_status IS DISTINCT FROM 'active' THEN 'COMPANY_INACTIVE'
    WHEN i.role_id IS NULL OR i.role_company_id IS DISTINCT FROM i.company_id
      THEN 'ROLE_NOT_FOUND_OR_CROSS_COMPANY'
    WHEN i.role_is_active IS DISTINCT FROM true THEN 'ROLE_INACTIVE'
    WHEN es.existe_empleado_desvinculado THEN 'PROFILE_INACTIVE_EMPLOYEE'
    WHEN i.role_code_canonical <> 'SUPERVISOR'
      THEN 'ROLE_NOT_CANONICAL_SUPERVISOR'
    WHEN NOT kp.supervisor_dashboard_catalogo_activo
      THEN 'STAGING_CATALOG_MISSING_OR_INACTIVE_SUPERVISOR_DASHBOARD'
    WHEN NOT kp.supervisor_dashboard_sesion
     AND kp.supervisor_dashboard_override_perfil IS false
      THEN 'PROFILE_OVERRIDE_DENIES_SUPERVISOR_DASHBOARD'
    WHEN NOT kp.supervisor_dashboard_sesion
      THEN 'STAGING_ROLE_MISSING_SUPERVISOR_DASHBOARD'
    WHEN NOT kp.portal_ver_dashboard_catalogo_activo
      THEN 'STAGING_CATALOG_MISSING_OR_INACTIVE_PORTAL_DASHBOARD'
    WHEN NOT kp.portal_ver_dashboard_sesion
     AND kp.portal_ver_dashboard_override_perfil IS false
      THEN 'PROFILE_OVERRIDE_DENIES_PORTAL_DASHBOARD'
    WHEN NOT kp.portal_ver_dashboard_sesion
      THEN 'STAGING_ROLE_MISSING_PORTAL_DASHBOARD'
    WHEN cardinality(sp.permission_codes_sesion_calculados) = 0
      THEN 'EMPTY_PERMISSION_CODES'
    ELSE 'BACKEND_AUTHORIZATION_OK_CHECK_WEB_SESSION_OR_DEPLOYED_BUNDLE'
  END AS diagnostico_probable
FROM identity AS i
CROSS JOIN employee_state AS es
CROSS JOIN session_permissions AS sp
CROSS JOIN direct_role_permissions AS drp
CROSS JOIN key_permissions AS kp;
