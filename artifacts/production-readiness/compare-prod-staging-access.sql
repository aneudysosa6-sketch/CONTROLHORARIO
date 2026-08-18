-- SOLO STAGING. No ejecutar en controlhorario-prod.
-- Comparar con un snapshot aprobado; no usar datos reales.
-- Read-only checks only. Stop if the target is ambiguous.

SELECT '01_profiles_exists' AS check_name,
       to_regclass('public.profiles') IS NOT NULL AS exists;

SELECT '02_profiles_owner' AS check_name,
       r.rolname AS owner,
       n.nspname AS schema_name,
       c.relname AS table_name,
       c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_roles r ON r.oid = c.relowner
WHERE n.nspname = 'public'
  AND c.relname = 'profiles';

SELECT '03_profiles_policies' AS check_name,
       schemaname,
       tablename,
       policyname,
       roles,
       cmd,
       permissive,
       qual,
       with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename = 'profiles'
ORDER BY policyname;

SELECT '04_profiles_table_grants_anon_auth_service' AS check_name,
       grantee,
       privilege_type,
       is_grantable
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND table_name = 'profiles'
  AND grantee IN ('anon', 'authenticated', 'service_role')
ORDER BY grantee, privilege_type;

WITH requested_roles(role_name) AS (
    VALUES
        ('anon'::text),
        ('authenticated'::text),
        ('service_role'::text)
),
public_schema AS (
    SELECT requested_schema.schema_name,
           n.oid AS schema_oid
    FROM (VALUES ('public'::text)) AS requested_schema(schema_name)
    LEFT JOIN pg_catalog.pg_namespace n
      ON n.nspname = requested_schema.schema_name
)
SELECT '05_public_schema_usage' AS check_name,
       ps.schema_name,
       rr.role_name,
       CASE
           WHEN r.oid IS NULL OR ps.schema_oid IS NULL THEN false
           ELSE pg_catalog.has_schema_privilege(r.oid, ps.schema_oid, 'USAGE')
       END AS has_usage,
       CASE
           WHEN r.oid IS NULL OR ps.schema_oid IS NULL THEN false
           ELSE pg_catalog.has_schema_privilege(r.oid, ps.schema_oid, 'CREATE')
       END AS has_create
FROM requested_roles rr
CROSS JOIN public_schema ps
LEFT JOIN pg_catalog.pg_roles r
  ON r.rolname::text = rr.role_name
ORDER BY rr.role_name;

SELECT '06_pg_default_acl_public' AS check_name,
       defaclrole::regrole::text AS role_with_defaults,
       COALESCE(n.nspname, '<database_default>') AS target_schema,
       defaclobjtype,
       defaclacl
FROM pg_default_acl d
LEFT JOIN pg_namespace n ON n.oid = d.defaclnamespace
WHERE n.nspname = 'public' OR d.defaclnamespace IS NULL
ORDER BY role_with_defaults, COALESCE(n.nspname, '<database_default>'), defaclobjtype;

WITH requested_roles(role_name) AS (
  VALUES
    ('anon'::text),
    ('authenticated'::text),
    ('service_role'::text)
),
profile_sequences AS (
  SELECT DISTINCT
    ns.nspname AS sequence_schema,
    sq.relname AS sequence_name,
    sq.oid AS sequence_oid
  FROM pg_class t
  JOIN pg_namespace tn
    ON tn.oid = t.relnamespace
  JOIN pg_attribute a
    ON a.attrelid = t.oid
  CROSS JOIN LATERAL (
    SELECT pg_get_serial_sequence(
      format('%I.%I', tn.nspname, t.relname),
      a.attname
    ) AS sequence_fqn
  ) dep
  JOIN pg_class sq
    ON sq.oid = dep.sequence_fqn::regclass
  JOIN pg_namespace ns
    ON ns.oid = sq.relnamespace
  WHERE tn.nspname = 'public'
    AND t.relname = 'profiles'
    AND t.relkind = 'r'
    AND a.attnum > 0
    AND NOT a.attisdropped
    AND dep.sequence_fqn IS NOT NULL
    AND sq.relkind = 'S'
)
SELECT '07_profiles_sequences_privileges' AS check_name,
       ps.sequence_schema,
       ps.sequence_name,
       rr.role_name,
       (r.oid IS NOT NULL) AS role_exists,
       CASE
         WHEN r.oid IS NULL THEN false
         ELSE has_sequence_privilege(r.rolname, ps.sequence_oid, 'USAGE')
       END AS has_usage,
       CASE
         WHEN r.oid IS NULL THEN false
         ELSE has_sequence_privilege(r.rolname, ps.sequence_oid, 'SELECT')
       END AS has_select,
       CASE
         WHEN r.oid IS NULL THEN false
         ELSE has_sequence_privilege(r.rolname, ps.sequence_oid, 'UPDATE')
       END AS has_update
FROM profile_sequences ps
CROSS JOIN requested_roles rr
LEFT JOIN pg_roles r
  ON r.rolname = rr.role_name
ORDER BY ps.sequence_schema, ps.sequence_name, rr.role_name;

SELECT '08_user_provisioning_function_privileges' AS check_name,
       rp.routine_schema,
       rp.routine_name,
       r.routine_type,
       rp.specific_name,
       rp.grantee,
       rp.privilege_type,
       rp.is_grantable
FROM information_schema.routine_privileges rp
LEFT JOIN information_schema.routines r
  ON r.specific_catalog = rp.specific_catalog
 AND r.specific_schema = rp.specific_schema
 AND r.specific_name = rp.specific_name
WHERE rp.routine_schema = 'public'
  AND rp.routine_name IN (
    'bootstrap_tenant_internal',
    'listar_accesos_internal',
    'obtener_acceso_internal',
    'provision_user_internal',
    'tiene_permiso'
  )
  AND rp.privilege_type = 'EXECUTE'
  AND rp.grantee IN ('anon', 'authenticated', 'service_role')
ORDER BY rp.routine_schema, rp.routine_name, rp.grantee;
