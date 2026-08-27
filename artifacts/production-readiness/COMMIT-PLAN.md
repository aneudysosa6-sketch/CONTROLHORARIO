# Plan de commits

Rama objetivo: `feature/production-readiness`
Estado: propuesta; ningún commit fue creado ni staged durante esta tarea.

## Reglas de ejecución

- Stagear únicamente las rutas exactas de cada bloque.
- No incluir archivos clasificados `DO NOT COMMIT` en `WORKTREE-INVENTORY.md`.
- No usar `git add .` ni `git add -A` sobre este worktree.
- Ejecutar `git diff --cached --check` y el gate de seguridad antes de cada commit.
- Mantener `0030` como prerrequisito ya versionado; los archivos nuevos de migración son `0031`–`0036`.

## 0. `chore: stop tracking generated workspace state`

Objetivo: ignorar caches locales y retirar del índice metadatos generados que ya estaban rastreados, sin borrarlos del disco.

Archivos exactos:

- `.gitignore`
- retirar del índice `supabase/.temp/cli-latest`
- retirar del índice `supabase/.temp/gotrue-version`
- retirar del índice `supabase/.temp/linked-project.json`
- retirar del índice `supabase/.temp/pooler-url`
- retirar del índice `supabase/.temp/postgres-version`
- retirar del índice `supabase/.temp/project-ref`
- retirar del índice `supabase/.temp/rest-version`
- retirar del índice `supabase/.temp/storage-migration`
- retirar del índice `supabase/.temp/storage-version`
- retirar del índice `web/tsconfig.app.tsbuildinfo`

Validación requerida:

- `git check-ignore -v --no-index` para cachés, `.env.local`, `dist`, `node_modules`, `build` y `.temp`.
- Confirmar que los archivos locales continúen en disco y ya no aparezcan como cambios de contenido.
- `git diff --cached --check`.

## 1. `feat: add multi-department supervisor scope`

Objetivo: administrar sucursal y múltiples departamentos del supervisor desde alta/edición de acceso, manteniendo la validación privilegiada en servidor.

Archivos exactos:

- `supabase/functions/user-provisioning/index.ts`
- hunk `[functions.user-provisioning]` de `supabase/config.toml`
- `web/src/modules/administration/administrationService.ts`
- `web/src/modules/userProvisioning/supervisorScopePolicy.ts`
- `web/src/modules/userProvisioning/userProvisioningService.ts`
- `web/src/pages/OrganizationPages.tsx`
- `web/src/pages/SystemAdministrationPage.tsx`
- `web/src/pages/UsersAdministrationPage.tsx`
- `web/src/styles/global.css`

Validación requerida:

- `pnpm.cmd run build`.
- `pnpm.cmd run test:supervisor-scope`.
- Revisión estática de JWT, tenant, permiso, alcance e idempotencia de `user-provisioning`.

## 2. `fix: harden employee management error diagnostics`

Objetivo: conservar errores funcionales del backend sin perder el cuerpo de respuesta y reforzar la configuración local del handler.

Archivos exactos:

- `supabase/functions/employee-management/index.ts`
- `web/src/modules/employees/employeeService.ts`
- hunk `[functions.employee-management]` de `supabase/config.toml`

Validación requerida:

- `pnpm.cmd run build`.
- `pnpm.cmd run test:employee-code`.
- Revisión de que errores y logs no devuelvan SQL, stack traces ni valores sensibles.

## 3. `fix: add reproducible database migrations 0031-0036`

Objetivo: versionar la secuencia reproducible posterior a la migración `0030` ya existente.

Archivos exactos:

- `supabase/migrations/0031_admin_access_permissions.sql`
- `supabase/migrations/0032_dashboard_access_permission.sql`
- `supabase/migrations/0033_supervisor_department_assignments.sql`
- `supabase/migrations/0034_fix_supervisor_scope_trigger_columns.sql`
- `supabase/migrations/0035_service_role_minimum_grants.sql`
- `supabase/migrations/0036_service_role_privilege_remediation.sql`

Validación requerida:

- Confirmar una migración por número y una sola `0036` activa.
- Revisión estática de transacciones, RLS, policies, grants, owners y RPC.
- Confirmar que `0036` no contiene arrays ACL vacíos artificiales.
- `git diff --cached --check`.
- No ejecutar SQL remoto ni `db push` durante el commit.

## 4. `chore: pin Edge Function dependencies`

Objetivo: fijar `@supabase/supabase-js` y versionar un lockfile por Edge Function.

Archivos exactos:

- `supabase/functions/attendance-sync/deno.json`
- `supabase/functions/attendance-sync/deno.lock`
- `supabase/functions/device-enrollment/deno.json`
- `supabase/functions/device-enrollment/deno.lock`
- `supabase/functions/employee-management/deno.json`
- `supabase/functions/employee-management/deno.lock`
- `supabase/functions/employee-sync/deno.json`
- `supabase/functions/employee-sync/deno.lock`
- `supabase/functions/employee-upsert/deno.json`
- `supabase/functions/employee-upsert/deno.lock`
- `supabase/functions/employee-upsert/index.ts`
- `supabase/functions/user-provisioning/deno.json`
- `supabase/functions/user-provisioning/deno.lock`

Validación requerida:

- `pnpm.cmd run test:edge-dependencies`.
- Confirmar seis `deno.json`, seis `deno.lock` y ausencia de imports flotantes/directos.
- No desplegar Edge Functions.

## 5. `test: add authorization and migration coverage`

Objetivo: agregar pruebas reproducibles de alcance, triggers y dependencias.

Archivos exactos:

- `supabase/tests/0034_supervisor_scope_trigger_columns.sql`
- `web/package.json`
- `web/scripts/test-edge-dependency-pinning.mjs`
- `web/scripts/test-supervisor-scope-policy.mjs`

Validación requerida:

- `pnpm.cmd run build`.
- `pnpm.cmd run test:supervisor-scope`.
- `pnpm.cmd run test:employee-code`.
- `pnpm.cmd run test:edge-dependencies`.
- La prueba SQL se ejecutará únicamente en un entorno autorizado posterior.

## 6. `docs: document Supabase and Edge production readiness`

Objetivo: documentar contratos de despliegue reproducible y la evidencia de dependencias.

Archivos exactos:

- `docs/10_SUPABASE.md`
- `docs/CHANGELOG.md`
- `artifacts/production-readiness/edge-dependency-pinning-review.md`
- `artifacts/production-readiness/edge-dependency-rollback-plan.md`
- `artifacts/production-readiness/edge-dependency-staging-test-plan.md`

Validación requerida:

- Escaneo de rutas locales, secretos, project refs y tokens.
- Confirmar que ejemplos usen placeholders.
- `git diff --cached --check`.

## 7. `docs: add migration 0030-0036 review packages`

Objetivo: versionar preflights, postflights, revisiones, planes de prueba y rollback de la secuencia activa.

Archivos exactos:

- `artifacts/production-readiness/migration-0030-preflight.sql`
- `artifacts/production-readiness/migration-0030-postflight.sql`
- `artifacts/production-readiness/migration-0030-production-postflight.sql`
- `artifacts/production-readiness/migration-0030-review.md`
- `artifacts/production-readiness/migration-0030-rollback-plan.md`
- `artifacts/production-readiness/migration-0030-staging-test-plan.md`
- `artifacts/production-readiness/migration-0031-postflight.sql`
- `artifacts/production-readiness/migration-0031-review.md`
- `artifacts/production-readiness/migration-0031-rollback-plan.md`
- `artifacts/production-readiness/migration-0032-postflight.sql`
- `artifacts/production-readiness/migration-0032-production-postflight.sql`
- `artifacts/production-readiness/migration-0032-review.md`
- `artifacts/production-readiness/migration-0032-rollback-plan.md`
- `artifacts/production-readiness/migration-0033-postflight.sql`
- `artifacts/production-readiness/migration-0033-review.md`
- `artifacts/production-readiness/migration-0033-rollback-plan.md`
- `artifacts/production-readiness/migration-0033-test-plan.md`
- `artifacts/production-readiness/migration-0034-postflight.sql`
- `artifacts/production-readiness/migration-0034-review.md`
- `artifacts/production-readiness/migration-0034-rollback-plan.md`
- `artifacts/production-readiness/migration-0034-test-plan.md`
- `artifacts/production-readiness/migration-0035-postflight.sql`
- `artifacts/production-readiness/migration-0036-postflight.sql`
- `artifacts/production-readiness/migration-0036-review.md`
- `artifacts/production-readiness/migration-0036-rollback-plan.md`
- `artifacts/production-readiness/migration-0036-test-plan.md`

Validación requerida:

- Confirmar que todos los postflights sean SELECT-only.
- Escaneo de secretos, rutas locales e identificadores operacionales.
- Confirmar que ningún `unconfirmed-*` esté staged.

## 8. `docs: add sanitized staging validation runbooks`

Objetivo: conservar únicamente scripts de diagnóstico y ejecución saneados, sin resultados crudos ni workarounds superados.

Archivos exactos:

- `artifacts/production-readiness/0036-staging-final-diagnostic-readonly.sql`
- `artifacts/production-readiness/0036-staging-precheck-readonly-exec-v4.sql`
- `artifacts/production-readiness/compare-admin-access-prod-staging.sql`
- `artifacts/production-readiness/compare-prod-staging-access.sql`
- `artifacts/production-readiness/COMPARE-PROD-STAGING-INSTRUCTIONS.md`
- `artifacts/production-readiness/diagnose-admin-access-staging.sql`
- `artifacts/production-readiness/diagnose-supervisor-login-staging.sql`
- `artifacts/production-readiness/run-staging-0030-dry-run.ps1`
- `artifacts/production-readiness/STAGING-0030-INSTRUCTIONS.md`

Validación requerida:

- Confirmar que todas las rutas sean relativas o placeholders.
- Confirmar que no haya credenciales, URLs de conexión ni project refs literales.
- No ejecutar los scripts durante el commit.

## 9. `docs: add sanitized production-readiness runbooks`

Objetivo: versionar el inventario, revisión de seguridad, evidencia curada y runbooks finales de promoción.

Archivos exactos:

- `artifacts/production-readiness/WORKTREE-INVENTORY.md`
- `artifacts/production-readiness/COMMIT-SECURITY-REVIEW.md`
- `artifacts/production-readiness/COMMIT-PLAN.md`
- `artifacts/production-readiness/CHECKPOINT.md`
- `artifacts/production-readiness/EVIDENCE-SUMMARY.md`
- `artifacts/production-readiness/REPORT.md`
- `artifacts/production-readiness/secret-scan.txt`
- `artifacts/production-readiness/production-precheck-safe-review.md`
- `artifacts/production-readiness/production-precheck-summary-instructions.md`
- `artifacts/production-readiness/production-promotion-plan.md`
- `artifacts/production-readiness/production-promotion-precheck.sql`
- `artifacts/production-readiness/production-promotion-precheck-summary-safe-v2.sql`
- `artifacts/production-readiness/production-promotion-rollback.md`
- `artifacts/production-readiness/production-smoke-test-plan.md`

Validación requerida:

- Repetir el escaneo de seguridad sobre los archivos staged.
- Confirmar que no estén staged outputs `.txt` crudos, versiones superseded ni `unconfirmed-*`.
- `git diff --cached --check`.

## Archivos excluidos de todos los commits propuestos

- `.npm-cache/**`, `.tmp/**`, `web/.env.local`, `web/dist/**`, `**/node_modules/**`, `**/build/**`.
- `supabase/.temp/**` y `web/tsconfig.app.tsbuildinfo`, salvo su retirada del índice en el commit de higiene.
- Evidencias crudas Android/Supabase y `web-brand-scan.txt` identificadas en la revisión de seguridad.
- `artifacts/production-readiness/unconfirmed-*`.
- Versiones superadas `0036-staging-precheck-readonly.sql`, `0036-staging-precheck-readonly-exec.sql` y `0036-staging-precheck-readonly-exec-v3.sql`.
- `production-promotion-precheck-summary.sql` y `production-promotion-precheck-summary-safe.sql`, reemplazadas por `production-promotion-precheck-summary-safe-v2.sql`.
- Scripts manuales `staging-*-service-role-*` y sus instrucciones, reemplazados por las migraciones activas `0035`–`0036`.
