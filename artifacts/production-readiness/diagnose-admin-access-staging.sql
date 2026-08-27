-- Diagnóstico de acceso a /administracion/accesos (solo SELECT, sin datos personales estáticos).
-- Ajuste: si auth.uid() no funciona en SQL Editor, usa override de parámetros para forzar diagnóstico.

-- SOLO STAGING. Usar datos sinteticos; no ejecutar en controlhorario-prod.
-- Detenerse si el target es ambiguo. Produccion permanece NO-GO.
WITH params AS (
  SELECT
    -- Reemplace NULL::uuid con un UUID real solo cuando se quiera forzar por diagnóstico.
    NULL::uuid AS auth_user_id_override,
    NULL::uuid AS profile_id_override
),
session_ctx AS (
  SELECT
    auth.uid()::uuid AS auth_user_id_current
),
required_permissions AS (
  SELECT unnest(
    ARRAY['usuarios.administrar', 'roles.administrar', 'permisos.administrar']
  ) AS required_permission
),
authorization_payload AS (
  SELECT
    p.auth_user_id_override,
    p.profile_id_override,
    s.auth_user_id_current,
    s.auth_user_id_current IS NOT NULL AS auth_session_available,
    CASE
      WHEN s.auth_user_id_current IS NOT NULL THEN public.obtener_mi_autorizacion()
      ELSE NULL::jsonb
    END AS authorization,
    CASE
      WHEN s.auth_user_id_current IS NOT NULL THEN 'SESSION'
      WHEN p.profile_id_override IS NOT NULL OR p.auth_user_id_override IS NOT NULL THEN 'OVERRIDE'
      ELSE 'NO_SESSION_NO_OVERRIDE'
    END AS authorization_resolution_mode
  FROM params AS p
  CROSS JOIN session_ctx AS s
),
identity_resolution AS (
  SELECT
    ap.auth_session_available,
    ap.auth_user_id_current,
    ap.auth_user_id_override,
    ap.profile_id_override,
    ap.authorization_resolution_mode,
    ap.authorization,
    ap.authorization ->> 'role_code_original' AS authorization_role_code_original,
    ap.authorization ->> 'role_code_canonical' AS authorization_role_code_canonical,
    CASE
      WHEN ap.authorization IS NOT NULL THEN (ap.authorization ->> 'active')::boolean
      ELSE NULL::boolean
    END AS authorization_profile_active,
    COALESCE(ap.authorization -> 'permission_codes', '[]'::jsonb) AS authorization_permission_codes,
    CASE
      WHEN ap.authorization IS NOT NULL THEN NULLIF(ap.authorization ->> 'profile_id', '')::uuid
      WHEN ap.profile_id_override IS NOT NULL THEN ap.profile_id_override
      WHEN ap.auth_user_id_override IS NOT NULL THEN ap.auth_user_id_override
      ELSE NULL::uuid
    END AS resolved_profile_id,
    CASE
      WHEN ap.authorization IS NOT NULL THEN NULLIF(ap.authorization ->> 'company_id', '')::uuid
      ELSE NULL::uuid
    END AS session_company_id,
    CASE
      WHEN ap.authorization IS NOT NULL THEN NULLIF(ap.authorization ->> 'role_id', '')::uuid
      ELSE NULL::uuid
    END AS session_role_id
  FROM authorization_payload AS ap
),
profile_lookup AS (
  SELECT
    ir.auth_session_available,
    ir.auth_user_id_current,
    ir.auth_user_id_override,
    ir.profile_id_override,
    ir.authorization_resolution_mode,
    ir.authorization,
    ir.authorization_role_code_original,
    ir.authorization_role_code_canonical,
    ir.authorization_profile_active,
    ir.authorization_permission_codes,
    ir.resolved_profile_id,
    ir.session_company_id,
    ir.session_role_id,
    p.company_id AS profile_company_id,
    p.role_id AS profile_role_id,
    p.status AS profile_status,
    p.access_deleted_at IS NULL AS profile_not_deleted,
    p.id IS NOT NULL AS profile_found
  FROM identity_resolution AS ir
  LEFT JOIN public.profiles AS p
    ON p.id = ir.resolved_profile_id
),
identity_final AS (
  SELECT
    pl.auth_session_available,
    pl.auth_user_id_current,
    pl.auth_user_id_override,
    pl.profile_id_override,
    pl.authorization_resolution_mode,
    pl.authorization,
    pl.authorization_role_code_original,
    pl.authorization_role_code_canonical,
    pl.authorization_profile_active,
    pl.authorization_permission_codes,
    pl.resolved_profile_id,
    COALESCE(pl.session_company_id, pl.profile_company_id) AS effective_company_id,
    COALESCE(pl.session_role_id, pl.profile_role_id) AS effective_role_id,
    CASE
      WHEN pl.authorization_profile_active IS NOT NULL THEN pl.authorization_profile_active
      WHEN pl.profile_status IS NULL THEN NULL::boolean
      ELSE (pl.profile_status = 'active' AND pl.profile_not_deleted)
    END AS profile_active_final,
    pl.profile_found
  FROM profile_lookup AS pl
),
role_lookup AS (
  SELECT
    i.auth_session_available,
    i.auth_user_id_current,
    i.auth_user_id_override,
    i.profile_id_override,
    i.authorization_resolution_mode,
    i.authorization,
    i.authorization_role_code_original,
    i.authorization_role_code_canonical,
    i.authorization_permission_codes,
    i.resolved_profile_id,
    i.effective_company_id,
    i.effective_role_id,
    i.profile_active_final,
    r.code AS role_code_db,
    private.normalizar_codigo_rol(r.code) AS role_code_canonical_db,
    r.is_active AS role_is_active,
    r.id AS role_id,
    COALESCE(c.status = 'active', false) AS company_active
  FROM identity_final AS i
  LEFT JOIN public.roles AS r
    ON r.id = i.effective_role_id
  LEFT JOIN public.companies AS c
    ON c.id = i.effective_company_id
),
role_direct_permissions AS (
  SELECT
    rlookup.effective_role_id,
    COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'codigo', p.codigo,
          'permitido', rp.permitido,
          'alcance', rp.alcance
        )
        ORDER BY p.codigo
      ) FILTER (WHERE p.codigo IS NOT NULL),
      '[]'::jsonb
    ) AS permisos_asignados_directamente_al_role_id
  FROM role_lookup AS rlookup
  LEFT JOIN public.rol_permisos AS rp
    ON rp.rol_id = rlookup.effective_role_id
  LEFT JOIN public.permisos AS p
    ON p.id = rp.permiso_id
  GROUP BY rlookup.effective_role_id
),
permission_presence_session AS (
  SELECT
    rlookup.effective_role_id,
    rp.required_permission,
    COALESCE((rlookup.authorization_permission_codes ? rp.required_permission), false) AS in_session
  FROM role_lookup AS rlookup
  CROSS JOIN required_permissions AS rp
),
permission_presence_role AS (
  SELECT
    rlookup.effective_role_id,
    rp.required_permission,
    EXISTS(
      SELECT
        1
      FROM public.rol_permisos AS rperf
      JOIN public.permisos AS pperf
        ON pperf.id = rperf.permiso_id
      WHERE rperf.rol_id = rlookup.effective_role_id
        AND pperf.codigo = rp.required_permission
        AND rperf.permitido
    ) AS in_role_direct
  FROM role_lookup AS rlookup
  CROSS JOIN required_permissions AS rp
),
admin_payload AS (
  SELECT
    rlookup.effective_role_id,
    CASE
      WHEN rlookup.auth_session_available THEN public.obtener_administracion_sistema()
      ELSE NULL::jsonb
    END AS administracion_sistema
  FROM role_lookup AS rlookup
)
SELECT
  rlookup.authorization_resolution_mode AS modo_resolucion,
  CASE
    WHEN rlookup.auth_session_available THEN 'auth.uid() disponible en SQL Editor'
    WHEN rlookup.auth_user_id_override IS NOT NULL OR rlookup.profile_id_override IS NOT NULL THEN 'sin sesión; se usó override manual de params'
    ELSE 'auth.uid() null en SQL Editor y no se indicó override'
  END AS contexto_autenticacion,
  rlookup.auth_session_available AS auth_uid_disponible,
  rlookup.resolved_profile_id AS profile_id,
  rlookup.effective_company_id IS NOT NULL AS perfil_con_empresa_vinculada,
  rlookup.company_active AS empresa_activa,
  CASE
    WHEN rlookup.effective_company_id IS NULL THEN NULL::text
    ELSE left(rlookup.effective_company_id::text, 8) || '-****-****-****-********'
  END AS company_id_mascarado,
  rlookup.effective_role_id AS role_id,
  COALESCE(rlookup.authorization_role_code_original, rlookup.role_code_db) AS role_code_original,
  COALESCE(rlookup.authorization_role_code_canonical, rlookup.role_code_canonical_db) AS role_code_canonical,
  COALESCE(rlookup.profile_active_final, false) AS perfil_activo,
  rlookup.authorization_permission_codes AS permission_codes,
  COALESCE(
    (
      SELECT
        pp.in_session
      FROM permission_presence_session AS pp
      WHERE pp.effective_role_id = rlookup.effective_role_id
        AND pp.required_permission = 'usuarios.administrar'
    ),
    false
  ) AS usuarios_administrar_en_sesion,
  COALESCE(
    (
      SELECT
        pp.in_session
      FROM permission_presence_session AS pp
      WHERE pp.effective_role_id = rlookup.effective_role_id
        AND pp.required_permission = 'roles.administrar'
    ),
    false
  ) AS roles_administrar_en_sesion,
  COALESCE(
    (
      SELECT
        pp.in_session
      FROM permission_presence_session AS pp
      WHERE pp.effective_role_id = rlookup.effective_role_id
        AND pp.required_permission = 'permisos.administrar'
    ),
    false
  ) AS permisos_administrar_en_sesion,
  COALESCE(
    (
      SELECT
        pr.in_role_direct
      FROM permission_presence_role AS pr
      WHERE pr.effective_role_id = rlookup.effective_role_id
        AND pr.required_permission = 'usuarios.administrar'
    ),
    false
  ) AS usuarios_administrar_directo_al_role,
  COALESCE(
    (
      SELECT
        pr.in_role_direct
      FROM permission_presence_role AS pr
      WHERE pr.effective_role_id = rlookup.effective_role_id
        AND pr.required_permission = 'roles.administrar'
    ),
    false
  ) AS roles_administrar_directo_al_role,
  COALESCE(
    (
      SELECT
        pr.in_role_direct
      FROM permission_presence_role AS pr
      WHERE pr.effective_role_id = rlookup.effective_role_id
        AND pr.required_permission = 'permisos.administrar'
    ),
    false
  ) AS permisos_administrar_directo_al_role,
  COALESCE(rperm.permisos_asignados_directamente_al_role_id, '[]'::jsonb) AS permisos_asignados_directamente_al_role_id,
  ad.administracion_sistema AS administracion_sistema_payload
FROM role_lookup AS rlookup
LEFT JOIN role_direct_permissions AS rperm
  ON rperm.effective_role_id = rlookup.effective_role_id
LEFT JOIN admin_payload AS ad
  ON ad.effective_role_id = rlookup.effective_role_id
