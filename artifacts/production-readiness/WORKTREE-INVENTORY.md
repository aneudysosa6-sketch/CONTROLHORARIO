# Worktree inventory

Fecha: 2026-08-08
Rama: `feature/production-readiness`

## Conteos

- Estado inicial: 124 rutas (`29 M`, `95 ??`).
- Después de añadir las reglas de ignore: 122 rutas visibles. Desaparecieron dos entradas de `.npm-cache/` y `.tmp/telemetry.json`; apareció la modificación versionable de `.gitignore`.
- `web/.env.local` y `web/dist/` ya estaban ignorados y no aparecían en el estado.
- Este inventario incluye además los tres documentos creados por la tarea (`WORKTREE-INVENTORY.md`, `COMMIT-SECURITY-REVIEW.md` y `COMMIT-PLAN.md`): 125 rutas clasificadas.
- Los siete cambios de `supabase/.temp/` y `web/tsconfig.app.tsbuildinfo` permanecen visibles porque ya están rastreados. Son `DO NOT COMMIT` hasta retirarlos del índice en una limpieza dedicada.

## Inventario completo

| Categoría | Archivo | Acción | Motivo |
|---|---|---|---|
| CÓDIGO FUNCIONAL | `.gitignore` | COMMIT 0 | Evita ruido local sin ocultar código versionable. |
| CÓDIGO FUNCIONAL | `web/src/modules/administration/administrationService.ts` | COMMIT 1 | Separa mantenimiento organizacional del alcance de supervisión. |
| CÓDIGO FUNCIONAL | `web/src/modules/employees/employeeService.ts` | COMMIT 2 | Conserva el cuerpo funcional de errores de Employee Management. |
| CÓDIGO FUNCIONAL | `web/src/modules/userProvisioning/supervisorScopePolicy.ts` | COMMIT 1 | Política pura de selección de sucursal y departamentos. |
| CÓDIGO FUNCIONAL | `web/src/modules/userProvisioning/userProvisioningService.ts` | COMMIT 1 | Contratos y llamadas de alcance multi-departamento. |
| CÓDIGO FUNCIONAL | `web/src/pages/OrganizationPages.tsx` | COMMIT 1 | Mueve la asignación de supervisión al flujo de accesos. |
| CÓDIGO FUNCIONAL | `web/src/pages/SystemAdministrationPage.tsx` | COMMIT 1 | Evita editar alcance desde departamentos. |
| CÓDIGO FUNCIONAL | `web/src/pages/UsersAdministrationPage.tsx` | COMMIT 1 | UI de creación/edición de alcance supervisor. |
| CÓDIGO FUNCIONAL | `web/src/styles/global.css` | COMMIT 1 | Estilos responsive del selector de alcance. |
| MIGRACIONES | `supabase/migrations/0031_admin_access_permissions.sql` | COMMIT 3 | Primera migración nueva posterior a `0030`. |
| MIGRACIONES | `supabase/migrations/0032_dashboard_access_permission.sql` | COMMIT 3 | Permiso reproducible de dashboard. |
| MIGRACIONES | `supabase/migrations/0033_supervisor_department_assignments.sql` | COMMIT 3 | RPC y alcance multi-departamento. |
| MIGRACIONES | `supabase/migrations/0034_fix_supervisor_scope_trigger_columns.sql` | COMMIT 3 | Corrección secuencial de triggers. |
| MIGRACIONES | `supabase/migrations/0035_service_role_minimum_grants.sql` | COMMIT 3 | Grants mínimos de `service_role`. |
| MIGRACIONES | `supabase/migrations/0036_service_role_privilege_remediation.sql` | COMMIT 3 | Remediación final de ACL; única `0036` activa. |
| EDGE FUNCTIONS | `supabase/config.toml` | SPLIT COMMIT 1/2 | Dos hunks independientes de configuración JWT manual. |
| EDGE FUNCTIONS | `supabase/functions/attendance-sync/deno.json` | COMMIT 4 | Alias de dependencia fijado. |
| EDGE FUNCTIONS | `supabase/functions/attendance-sync/deno.lock` | COMMIT 4 | Lockfile versionable. |
| EDGE FUNCTIONS | `supabase/functions/device-enrollment/deno.json` | COMMIT 4 | Alias de dependencia fijado. |
| EDGE FUNCTIONS | `supabase/functions/device-enrollment/deno.lock` | COMMIT 4 | Lockfile versionable. |
| EDGE FUNCTIONS | `supabase/functions/employee-management/deno.json` | COMMIT 4 | Alias de dependencia fijado. |
| EDGE FUNCTIONS | `supabase/functions/employee-management/deno.lock` | COMMIT 4 | Lockfile versionable. |
| EDGE FUNCTIONS | `supabase/functions/employee-management/index.ts` | COMMIT 2 | Manejo funcional y seguro de errores. |
| EDGE FUNCTIONS | `supabase/functions/employee-sync/deno.json` | COMMIT 4 | Alias de dependencia fijado. |
| EDGE FUNCTIONS | `supabase/functions/employee-sync/deno.lock` | COMMIT 4 | Lockfile versionable. |
| EDGE FUNCTIONS | `supabase/functions/employee-upsert/deno.json` | COMMIT 4 | Alias de dependencia fijado. |
| EDGE FUNCTIONS | `supabase/functions/employee-upsert/deno.lock` | COMMIT 4 | Lockfile versionable. |
| EDGE FUNCTIONS | `supabase/functions/employee-upsert/index.ts` | COMMIT 4 | Sustituye import remoto por alias fijado. |
| EDGE FUNCTIONS | `supabase/functions/user-provisioning/deno.json` | COMMIT 4 | Alias de dependencia fijado. |
| EDGE FUNCTIONS | `supabase/functions/user-provisioning/deno.lock` | COMMIT 4 | Lockfile versionable. |
| EDGE FUNCTIONS | `supabase/functions/user-provisioning/index.ts` | COMMIT 1 | Backend privilegiado del alcance supervisor. |
| PRUEBAS | `web/package.json` | COMMIT 5 | Registra los comandos de prueba nuevos. |
| PRUEBAS | `web/scripts/test-edge-dependency-pinning.mjs` | COMMIT 5 | Control estático de dependencias Edge. |
| PRUEBAS | `web/scripts/test-supervisor-scope-policy.mjs` | COMMIT 5 | Cobertura de política de alcance. |
| PRUEBAS | `supabase/tests/0034_supervisor_scope_trigger_columns.sql` | COMMIT 5 | Cobertura SQL del trigger de alcance. |
| PRUEBAS | `artifacts/production-readiness/0036-staging-final-diagnostic-readonly.sql` | COMMIT 8 | Diagnóstico final SELECT-only. |
| PRUEBAS | `artifacts/production-readiness/0036-staging-precheck-readonly-exec-v4.sql` | COMMIT 8 | Precheck ejecutable final. |
| PRUEBAS | `artifacts/production-readiness/compare-admin-access-prod-staging.sql` | COMMIT 8 | Comparación saneada y de solo lectura. |
| PRUEBAS | `artifacts/production-readiness/compare-prod-staging-access.sql` | COMMIT 8 | Comparación saneada y de solo lectura. |
| PRUEBAS | `artifacts/production-readiness/diagnose-admin-access-staging.sql` | COMMIT 8 | Diagnóstico de staging sin escritura. |
| PRUEBAS | `artifacts/production-readiness/diagnose-supervisor-login-staging.sql` | COMMIT 8 | Diagnóstico de login sin secretos embebidos. |
| PRUEBAS | `artifacts/production-readiness/migration-0030-preflight.sql` | COMMIT 7 | Gate previo de migración. |
| PRUEBAS | `artifacts/production-readiness/migration-0030-postflight.sql` | COMMIT 7 | Validación posterior. |
| PRUEBAS | `artifacts/production-readiness/migration-0030-production-postflight.sql` | COMMIT 7 | Postflight de producción SELECT-only. |
| PRUEBAS | `artifacts/production-readiness/migration-0031-postflight.sql` | COMMIT 7 | Postflight versionable. |
| PRUEBAS | `artifacts/production-readiness/migration-0032-postflight.sql` | COMMIT 7 | Postflight versionable. |
| PRUEBAS | `artifacts/production-readiness/migration-0032-production-postflight.sql` | COMMIT 7 | Postflight de producción SELECT-only. |
| PRUEBAS | `artifacts/production-readiness/migration-0033-postflight.sql` | COMMIT 7 | Verifica RPC y alcance. |
| PRUEBAS | `artifacts/production-readiness/migration-0034-postflight.sql` | COMMIT 7 | Verifica trigger corregido. |
| PRUEBAS | `artifacts/production-readiness/migration-0035-postflight.sql` | COMMIT 7 | Verifica grants mínimos. |
| PRUEBAS | `artifacts/production-readiness/migration-0036-postflight.sql` | COMMIT 7 | Verifica ACL directa/efectiva sin mutaciones. |
| PRUEBAS | `artifacts/production-readiness/production-promotion-precheck.sql` | COMMIT 9 | Precheck fuente de promoción. |
| PRUEBAS | `artifacts/production-readiness/production-promotion-precheck-summary-safe-v2.sql` | COMMIT 9 | Resumen final saneado. |
| DOCUMENTACIÓN VERSIONABLE | `docs/10_SUPABASE.md` | COMMIT 6 | Contrato de dependencias y despliegue. |
| DOCUMENTACIÓN VERSIONABLE | `docs/CHANGELOG.md` | COMMIT 6 | Hito de dependencias reproducibles. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/COMPARE-PROD-STAGING-INSTRUCTIONS.md` | COMMIT 8 | Instrucciones saneadas con rutas relativas. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/STAGING-0030-INSTRUCTIONS.md` | COMMIT 8 | Runbook de staging. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/edge-dependency-pinning-review.md` | COMMIT 6 | Revisión estática versionable. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/edge-dependency-rollback-plan.md` | COMMIT 6 | Plan de rollback. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/edge-dependency-staging-test-plan.md` | COMMIT 6 | Plan saneado con placeholder de raíz. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0030-review.md` | COMMIT 7 | Revisión de migración. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0030-rollback-plan.md` | COMMIT 7 | Plan de rollback. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0030-staging-test-plan.md` | COMMIT 7 | Plan de prueba. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0031-review.md` | COMMIT 7 | Revisión de migración. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0031-rollback-plan.md` | COMMIT 7 | Plan de rollback. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0032-review.md` | COMMIT 7 | Revisión de migración. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0032-rollback-plan.md` | COMMIT 7 | Plan de rollback. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0033-review.md` | COMMIT 7 | Revisión de alcance. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0033-rollback-plan.md` | COMMIT 7 | Plan de rollback. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0033-test-plan.md` | COMMIT 7 | Plan de pruebas. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0034-review.md` | COMMIT 7 | Revisión con request ID saneado. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0034-rollback-plan.md` | COMMIT 7 | Plan de rollback. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0034-test-plan.md` | COMMIT 7 | Plan de pruebas. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0036-review.md` | COMMIT 7 | Revisión final ACL. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0036-rollback-plan.md` | COMMIT 7 | Plan de rollback. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/migration-0036-test-plan.md` | COMMIT 7 | Plan de pruebas. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/production-precheck-safe-review.md` | COMMIT 9 | Revisión del precheck final. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/production-precheck-summary-instructions.md` | COMMIT 9 | Instrucciones de resumen saneado. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/production-promotion-plan.md` | COMMIT 9 | Plan saneado con placeholders. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/production-promotion-rollback.md` | COMMIT 9 | Plan de reversión operativa. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/production-smoke-test-plan.md` | COMMIT 9 | Smoke tests de promoción. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/run-staging-0030-dry-run.ps1` | COMMIT 8 | Deriva la raíz del repositorio sin ruta personal. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/WORKTREE-INVENTORY.md` | COMMIT 9 | Clasificación completa del worktree. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/COMMIT-SECURITY-REVIEW.md` | COMMIT 9 | Gate de seguridad sin valores sensibles. |
| DOCUMENTACIÓN VERSIONABLE | `artifacts/production-readiness/COMMIT-PLAN.md` | COMMIT 9 | Secuencia exacta de commits propuesta. |
| EVIDENCIA SANEADA | `artifacts/production-readiness/CHECKPOINT.md` | COMMIT 9 | Snapshot curado sin project ref. |
| EVIDENCIA SANEADA | `artifacts/production-readiness/EVIDENCE-SUMMARY.md` | COMMIT 9 | Resumen con rutas relativas y referencias saneadas. |
| EVIDENCIA SANEADA | `artifacts/production-readiness/REPORT.md` | COMMIT 9 | Reporte histórico rotulado y saneado. |
| EVIDENCIA SANEADA | `artifacts/production-readiness/secret-scan.txt` | COMMIT 9 | Resultado mínimo sin valores sensibles. |
| NO COMMIT / LOCAL / SENSIBLE | `supabase/.temp/cli-latest` | DO NOT COMMIT | Caché local ya rastreada. |
| NO COMMIT / LOCAL / SENSIBLE | `supabase/.temp/gotrue-version` | DO NOT COMMIT | Caché local ya rastreada. |
| NO COMMIT / LOCAL / SENSIBLE | `supabase/.temp/linked-project.json` | DO NOT COMMIT | Metadatos del proyecto vinculado. |
| NO COMMIT / LOCAL / SENSIBLE | `supabase/.temp/pooler-url` | DO NOT COMMIT | Endpoint de conexión local. |
| NO COMMIT / LOCAL / SENSIBLE | `supabase/.temp/postgres-version` | DO NOT COMMIT | Caché local ya rastreada. |
| NO COMMIT / LOCAL / SENSIBLE | `supabase/.temp/project-ref` | DO NOT COMMIT | Referencia del proyecto vinculado. |
| NO COMMIT / LOCAL / SENSIBLE | `supabase/.temp/storage-version` | DO NOT COMMIT | Caché local ya rastreada. |
| NO COMMIT / LOCAL / SENSIBLE | `web/tsconfig.app.tsbuildinfo` | DO NOT COMMIT | Salida incremental generada y rastreada. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/android-build.txt` | DO NOT COMMIT | Log crudo con ruta local. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/android-manual-validation.txt` | DO NOT COMMIT | Evidencia cruda con rutas locales. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/android-remediation.txt` | DO NOT COMMIT | Evidencia cruda con rutas locales. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/android-unit-test-summary.txt` | DO NOT COMMIT | Salida cruda con rutas locales. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/android-unit-tests-manual.txt` | DO NOT COMMIT | Salida cruda extensa. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/precheck.txt` | DO NOT COMMIT | Resultado obsoleto de otro estado de rama. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/staging-0030-dry-run.txt` | DO NOT COMMIT | Resultado crudo ligado al checkout local. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/supabase-manual-validation.txt` | DO NOT COMMIT | Evidencia cruda con rutas locales. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/supabase-status.txt` | DO NOT COMMIT | Rutas absolutas e identificadores temporales. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/web-brand-scan.txt` | DO NOT COMMIT | Bundle minificado y log extenso. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/web-build.txt` | DO NOT COMMIT | Log local de build. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/0036-staging-precheck-readonly.sql` | DO NOT COMMIT | Plantilla superada por el ejecutable final. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/0036-staging-precheck-readonly-exec.sql` | DO NOT COMMIT | Duplicado superado. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/0036-staging-precheck-readonly-exec-v3.sql` | DO NOT COMMIT | Duplicado byte a byte de `exec-v4`. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/production-promotion-precheck-summary.sql` | DO NOT COMMIT | Variante previa reemplazada por `safe-v2`. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/production-promotion-precheck-summary-safe.sql` | DO NOT COMMIT | Variante previa reemplazada por `safe-v2`. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/unconfirmed-0036_production_precheck_remediation.sql` | DO NOT COMMIT | Borrador 0036 supersedido y fuera de secuencia. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/unconfirmed-migration-0036-postflight.sql` | DO NOT COMMIT | Postflight del borrador supersedido. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/unconfirmed-migration-0036-review.md` | DO NOT COMMIT | Revisión del borrador supersedido. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/STAGING-PROFILES-GRANT-INSTRUCTIONS.md` | DO NOT COMMIT | Workaround manual reemplazado por migraciones activas. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/staging-empleados-service-role-grant.sql` | DO NOT COMMIT | Script temporal reemplazado por `0035`–`0036`. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/staging-empleados-service-role-rollback.sql` | DO NOT COMMIT | Script temporal reemplazado por `0035`–`0036`. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/staging-empleados-service-role-update-grant.sql` | DO NOT COMMIT | Script temporal reemplazado por `0035`–`0036`. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/staging-empleados-service-role-update-rollback.sql` | DO NOT COMMIT | Script temporal reemplazado por `0035`–`0036`. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/staging-profiles-service-role-grant.sql` | DO NOT COMMIT | Script temporal reemplazado por `0035`–`0036`. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/staging-profiles-service-role-rollback.sql` | DO NOT COMMIT | Script temporal reemplazado por `0035`–`0036`. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/staging-roles-service-role-grant.sql` | DO NOT COMMIT | Script temporal reemplazado por `0035`–`0036`. |
| NO COMMIT / LOCAL / SENSIBLE | `artifacts/production-readiness/staging-roles-service-role-rollback.sql` | DO NOT COMMIT | Script temporal reemplazado por `0035`–`0036`. |

## Verificación de migraciones

- 36 migraciones activas, exactamente una por número `0001`–`0036`.
- Orden `0030`–`0036` correcto.
- Una sola `0036` dentro de `supabase/migrations`.
- Cero migraciones temporales, duplicadas, `unconfirmed`, `.orig` o `.rej` en la secuencia activa.
- Los tres `unconfirmed-*` permanecen únicamente en artifacts y están clasificados `DO NOT COMMIT`.
