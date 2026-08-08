# Commit security review

Fecha: 2026-08-08
Rama: `feature/production-readiness`
Alcance: todos los archivos mostrados por `git status --short -uall` después de aplicar las reglas de ignore, más los archivos locales expresamente indicados en esta revisión.

## Resultado ejecutivo

- No se detectaron claves `service_role`, valores `sb_secret_`, JWT completos, tokens conocidos, encabezados Bearer literales, contraseñas reales, secretos de bootstrap, claves privadas, IP públicas ni UUID de usuarios confirmados.
- Las referencias a `service_role` encontradas son nombres de rol SQL, nombres de variables de entorno o documentación; no contienen la clave.
- Los valores locales y la evidencia cruda enumerados abajo no deben incluirse en ningún commit.
- Las evidencias crudas no fueron modificadas. Se sanearon únicamente runbooks y resúmenes versionables, reemplazando rutas locales e identificadores operacionales por rutas relativas o marcadores.

## Hallazgos

| Estado | Archivo | Hallazgo | Acción |
|---|---|---|---|
| DO NOT COMMIT | `supabase/.temp/cli-latest` | Caché local de versión del CLI. | Mantener fuera de staging; retirar del índice en una limpieza dedicada. |
| DO NOT COMMIT | `supabase/.temp/gotrue-version` | Caché local de versión de servicio. | Mantener fuera de staging; retirar del índice en una limpieza dedicada. |
| DO NOT COMMIT | `supabase/.temp/linked-project.json` | Metadatos e identificadores del proyecto vinculado. | Mantener local y fuera de todo commit. |
| DO NOT COMMIT | `supabase/.temp/pooler-url` | Endpoint local de conexión con datos de host/usuario/puerto. | Mantener local y fuera de todo commit. |
| DO NOT COMMIT | `supabase/.temp/postgres-version` | Caché local de versión. | Mantener fuera de staging; retirar del índice en una limpieza dedicada. |
| DO NOT COMMIT | `supabase/.temp/project-ref` | Referencia del proyecto vinculado. | Mantener local y fuera de todo commit. |
| DO NOT COMMIT | `supabase/.temp/storage-version` | Caché local de versión de servicio. | Mantener fuera de staging; retirar del índice en una limpieza dedicada. |
| DO NOT COMMIT | `.npm-cache/` | Caché y log local de npm. | Ignorado por `.gitignore`. |
| DO NOT COMMIT | `.tmp/telemetry.json` | Identificadores locales de dispositivo/sesión de telemetría. | Ignorado por `.gitignore`. |
| DO NOT COMMIT | `web/.env.local` | Archivo local con dos valores de configuración no vacíos. | Ya ignorado por `web/.gitignore`; no copiar su contenido. |
| DO NOT COMMIT | `web/tsconfig.app.tsbuildinfo` | Salida incremental generada y actualmente rastreada. | Excluir del staging y retirar del índice en una limpieza dedicada. |
| DO NOT COMMIT | `artifacts/production-readiness/android-build.txt` | Salida cruda con ruta local. | Conservar local; usar los resúmenes saneados. |
| DO NOT COMMIT | `artifacts/production-readiness/android-manual-validation.txt` | Evidencia cruda con rutas locales. | Conservar local; usar los resúmenes saneados. |
| DO NOT COMMIT | `artifacts/production-readiness/android-remediation.txt` | Evidencia cruda con rutas locales. | Conservar local; usar los resúmenes saneados. |
| DO NOT COMMIT | `artifacts/production-readiness/android-unit-test-summary.txt` | Salida cruda con rutas locales. | Conservar local; usar `EVIDENCE-SUMMARY.md`. |
| DO NOT COMMIT | `artifacts/production-readiness/android-unit-tests-manual.txt` | Salida cruda extensa con rutas locales. | Conservar local; usar los runbooks versionables. |
| DO NOT COMMIT | `artifacts/production-readiness/staging-0030-dry-run.txt` | Resultado crudo ligado al checkout local. | Conservar local; usar el script y el plan saneados. |
| DO NOT COMMIT | `artifacts/production-readiness/supabase-manual-validation.txt` | Evidencia cruda con rutas locales. | Conservar local; usar los postflights y revisiones saneados. |
| DO NOT COMMIT | `artifacts/production-readiness/supabase-status.txt` | Salida cruda con rutas absolutas e identificadores temporales. | Conservar local; no copiar fragmentos al repositorio. |
| DO NOT COMMIT | `artifacts/production-readiness/web-brand-scan.txt` | Bundle minificado y salida cruda extensa con correos embebidos. | Conservar local; no versionar. |
| DO NOT COMMIT | `artifacts/production-readiness/precheck.txt` | Salida cruda obsoleta de otro estado de rama/commit. | Sustituir por `WORKTREE-INVENTORY.md`. |
| DO NOT COMMIT | `artifacts/production-readiness/web-build.txt` | Log de build generado localmente. | Registrar únicamente el resultado resumido en documentación. |
| DO NOT COMMIT | `artifacts/production-readiness/0036-staging-precheck-readonly-exec.sql` | Duplicado superado por la versión final. | Conservar local; no stagear. |
| DO NOT COMMIT | `artifacts/production-readiness/0036-staging-precheck-readonly-exec-v3.sql` | Duplicado superado por `exec-v4`. | Conservar local; no stagear. |
| DO NOT COMMIT | `artifacts/production-readiness/0036-staging-precheck-readonly.sql` | Plantilla superada por el ejecutable final. | Conservar local; no stagear. |
| DO NOT COMMIT | `artifacts/production-readiness/production-promotion-precheck-summary.sql` | Variante anterior del resumen de promoción. | Usar exclusivamente `*-safe-v2.sql`. |
| DO NOT COMMIT | `artifacts/production-readiness/production-promotion-precheck-summary-safe.sql` | Variante anterior con controles superados. | Usar exclusivamente `*-safe-v2.sql`. |
| DO NOT COMMIT | `artifacts/production-readiness/unconfirmed-0036_production_precheck_remediation.sql` | Borrador 0036 supersedido y fuera de la secuencia activa. | No versionar como migración ni runbook activo. |
| DO NOT COMMIT | `artifacts/production-readiness/unconfirmed-migration-0036-postflight.sql` | Postflight del borrador supersedido. | No versionar. |
| DO NOT COMMIT | `artifacts/production-readiness/unconfirmed-migration-0036-review.md` | Revisión del borrador supersedido. | No versionar. |
| DO NOT COMMIT | `artifacts/production-readiness/STAGING-PROFILES-GRANT-INSTRUCTIONS.md` | Instrucción manual reemplazada por las migraciones activas. | No versionar como runbook vigente. |
| DO NOT COMMIT | `artifacts/production-readiness/staging-profiles-service-role-grant.sql` | Workaround temporal reemplazado por `0035`–`0036`. | No versionar. |
| DO NOT COMMIT | `artifacts/production-readiness/staging-profiles-service-role-rollback.sql` | Rollback del workaround temporal. | No versionar. |
| DO NOT COMMIT | `artifacts/production-readiness/staging-roles-service-role-grant.sql` | Workaround temporal reemplazado por `0035`–`0036`. | No versionar. |
| DO NOT COMMIT | `artifacts/production-readiness/staging-roles-service-role-rollback.sql` | Rollback del workaround temporal. | No versionar. |
| DO NOT COMMIT | `artifacts/production-readiness/staging-empleados-service-role-grant.sql` | Workaround temporal reemplazado por `0035`–`0036`. | No versionar. |
| DO NOT COMMIT | `artifacts/production-readiness/staging-empleados-service-role-rollback.sql` | Rollback del workaround temporal. | No versionar. |
| DO NOT COMMIT | `artifacts/production-readiness/staging-empleados-service-role-update-grant.sql` | Workaround temporal reemplazado por `0035`–`0036`. | No versionar. |
| DO NOT COMMIT | `artifacts/production-readiness/staging-empleados-service-role-update-rollback.sql` | Rollback del workaround temporal. | No versionar. |
| SAFE | `artifacts/production-readiness/COMPARE-PROD-STAGING-INSTRUCTIONS.md` | Las rutas absolutas fueron sustituidas por rutas relativas. | Versionable después del escaneo final. |
| SAFE | `artifacts/production-readiness/edge-dependency-staging-test-plan.md` | La ruta absoluta fue sustituida por `<REPOSITORY_ROOT>`. | Versionable. |
| SAFE | `artifacts/production-readiness/EVIDENCE-SUMMARY.md` | La ruta del APK fue convertida a ruta relativa. | Versionable como evidencia saneada. |
| SAFE | `artifacts/production-readiness/production-promotion-plan.md` | La ruta absoluta fue sustituida por `<REPOSITORY_ROOT>`. | Versionable. |
| SAFE | `artifacts/production-readiness/REPORT.md` | Las rutas locales fueron sustituidas por marcador y ruta relativa. | Versionable como resumen saneado. |
| SAFE | `artifacts/production-readiness/run-staging-0030-dry-run.ps1` | La raíz ahora se deriva de `$PSScriptRoot`; no contiene credenciales. | Versionable. |
| SAFE | `artifacts/production-readiness/migration-0034-review.md` | El identificador operacional fue sustituido por `<REQUEST_ID_STAGING>`. | Versionable. |
| SAFE | `supabase/tests/0034_supervisor_scope_trigger_columns.sql` | Correos únicamente como fixtures deterministas. | Versionable como prueba. |
| SAFE | `web/src/pages/UsersAdministrationPage.tsx` | Correo únicamente como ejemplo de interfaz. | Versionable. |
| SAFE | Edge Functions y runbooks | Bearer, password, bootstrap y service role aparecen como parsing, validaciones, placeholders o nombres de variables de entorno. | Versionable; nunca introducir valores literales. |
| SAFE | `artifacts/production-readiness/secret-scan.txt` | Resultado mínimo sin valores sensibles. | Puede versionarse como evidencia saneada. |

## Patrones revisados

- Claves `service_role` y prefijo `sb_secret_`.
- Tokens, JWT completos y encabezados `Authorization: Bearer`.
- Contraseñas, secretos de bootstrap y claves privadas.
- Connection strings y archivos `.env`.
- Correos, IP públicas, UUID e identificadores operacionales.
- Rutas absolutas de usuario y salidas locales generadas.

## Gate antes de cada commit

1. Stagear exclusivamente los archivos exactos del commit propuesto.
2. Confirmar que ningún archivo `DO NOT COMMIT` esté staged.
3. Repetir el escaneo sobre `git diff --cached` sin imprimir valores.
4. Ejecutar `git diff --cached --check`.
5. Detener el commit si aparece un secreto nuevo, una ruta local o evidencia cruda.
