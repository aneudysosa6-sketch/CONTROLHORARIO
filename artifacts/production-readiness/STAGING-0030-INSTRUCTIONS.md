# Instrucciones para validacion 0030 en STAGING

1. Crear o identificar un proyecto llamado `controlhorario-staging`.
2. Confirmar que el proyecto sea diferente de `controlhorario-prod`.
3. Usar solo datos sinteticos en todas las pruebas de rol, sesiones y migraciones.

**Gate obligatorio:** SOLO STAGING. Detenerse si el target es ambiguo o no puede
verificarse como staging. Produccion permanece **NO-GO** y este procedimiento no
autoriza tocar `controlhorario-prod`.

4. Ejecutar el script desde PowerShell normal, fuera de Codex:
   `.\artifacts\production-readiness\run-staging-0030-dry-run.ps1 -StagingProjectRef "<REF_STAGING>"`
5. No compartir referencias completas, tokens, contraseñas ni cadenas de conexion en chats o informes.
6. Revisar `artifacts/production-readiness/staging-0030-dry-run.txt` y confirmar que no aparezcan secretos.
7. No aplicar migraciones mientras se ejecute el dry-run.
8. Detener ejecucion si el dry-run reporta pendientes `0001` a `0029`.
9. Ejecutar preflight solo cuando staging reporte historial base `0001` a `0029`.
10. Solicitar autorizacion explicita antes de aplicar `0030` en staging.
