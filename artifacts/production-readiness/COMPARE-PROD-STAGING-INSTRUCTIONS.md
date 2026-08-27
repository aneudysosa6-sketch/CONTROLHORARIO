# Comparacion segura de snapshot aprobado vs staging

Objetivo: ejecutar consultas de solo lectura exclusivamente en staging y comparar
su salida con un snapshot de produccion previamente aprobado y saneado. Este
runbook no crea ni actualiza el snapshot de produccion.

## 1) Gate de entorno

1. **SOLO STAGING**. No conectar ni ejecutar consultas en `controlhorario-prod`.
2. Produccion permanece **NO-GO** y requiere una autorizacion separada.
3. Detenerse si el target es ambiguo o no puede verificarse como staging.
4. Usar solo datos sinteticos; no copiar datos reales entre entornos.

## 2) Ejecutar en controlhorario-staging

1. Exporta DSN de conexion de lectura:
   - `SUPABASE_DB_URL_STAGING`
2. Ejecuta:
    - `psql "$SUPABASE_DB_URL_STAGING" -v ON_ERROR_STOP=1 -f ".\artifacts\production-readiness\compare-prod-staging-access.sql" -o ".\artifacts\production-readiness\staging_profiles_access_audit.txt"`
3. Alternativa SQL Editor: pegar el contenido del `.sql` en `controlhorario-staging`.
4. No aplicar migraciones ni ejecutar sentencias de escritura.

## 3) Guardar resultados sin datos sensibles

- Los archivos generados contienen solo metadatos de permisos (esquema, ACL, RLS, políticas).
- Comparar solamente contra un snapshot saneado entregado por el proceso
  autorizado de produccion; no generarlo ni refrescarlo desde este runbook.
- Mantener el resultado de staging como `staging_profiles_access_audit.txt`.
- No pegar, registrar ni versionar:
  - URL de conexion, JWT, `service_role`, claves o secretos.
- Mantener cualquier salida generada fuera del commit.
