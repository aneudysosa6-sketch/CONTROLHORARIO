# Manifiesto vigente para changeset selectivo

Fecha de reconciliacion: 2026-08-24
Estado: preparado documentalmente; nada esta staged y no se creo commit.

El worktree contiene cambios del usuario y de varias fases. Este manifiesto identifica dependencias y grupos; no autoriza incluir indiscriminadamente todos los archivos modificados.

## Orden obligatorio de migraciones

| Orden | Migracion | Dependencia/proposito |
|---|---|---|
| 1 | `0045_kiosk_face_mode_manage.sql` | Base de gestion de modo facial/quiosco |
| 2 | `0046_supervisor_multi_branch_scope.sql` | Alcance multi-sucursal/departamento y funciones de autorizacion |
| 3 | `0047_random_employee_codes.sql` | Codigos de empleado autoritativos y unicos |
| 4 | `0048_attendance_chronology_guards.sql` | Guardas de cronologia e idempotencia de asistencia |
| 5 | `0049_employee_messages.sql` | Cola efimera, recibos y audio privado |
| 6 | `0050_p0_functional_contracts.sql` | Contratos P0; depende de empleados, alcance, asistencia, nomina y mensajeria anteriores |

Las pruebas SQL asociadas deben ejecutarse en el mismo orden. `supabase/tests/0050_p0_functional_contracts.sql` corresponde a la migracion 0050. Ninguna migracion de esta cadena fue aplicada por esta fase.

## Grupo SQL P0

- `supabase/migrations/0050_p0_functional_contracts.sql`
- `supabase/tests/0050_p0_functional_contracts.sql`

## Grupo Edge P0

- `supabase/functions/device-enrollment/index.ts`
- `supabase/functions/employee-sync/index.ts`
- `supabase/functions/attendance-sync/index.ts`

## Grupo Android P0

- `app/src/main/java/engine/P0FunctionalPolicies.kt`
- `app/src/test/java/com/example/controlhorario/engine/P0FunctionalPoliciesTest.kt`
- `app/src/main/java/com/example/controlhorario/device/EmployeeSyncClient.kt`
- `app/src/main/java/com/example/controlhorario/device/EmployeeSyncRepository.kt`
- `app/src/main/java/com/example/controlhorario/device/EmployeeSyncWorker.kt`
- `app/src/main/java/com/example/controlhorario/session/SessionCoordinator.kt`
- `app/src/main/java/ui/login/AppUserViewModel.kt`
- `app/src/main/java/ui/punch/JourneyViewModel.kt`
- `app/src/main/java/database/AppDatabase.kt`
- `app/src/main/java/database/DeviceEnrollmentDao.kt`
- `app/src/main/java/database/DeviceEnrollmentEntity.kt`
- `app/src/main/java/database/VacationDao.kt`
- `app/src/main/java/repository/VacationRepository.kt`
- `app/src/main/java/engine/Phase4Policy.kt`
- `app/src/test/java/com/example/controlhorario/engine/Phase4PolicyTest.kt`
- `app/src/main/java/database/PendingAttendanceReviewDao.kt`
- `app/src/main/java/database/PendingAttendanceReviewEntity.kt`
- `app/src/main/java/repository/PendingAttendanceReviewRepository.kt`
- `app/src/main/java/ui/incidents/PendingAttendanceReviewScreen.kt`
- `app/src/main/java/ui/incidents/PendingAttendanceReviewViewModel.kt`
- `app/src/main/java/messages/`

## Grupo Web P0

- `web/package.json`
- `web/scripts/test-device-enrollment-security.mjs`
- `web/scripts/test-p0-contracts.mjs`
- `web/src/App.tsx`
- `web/src/app/navigation.ts`
- `web/src/context/AuthContext.tsx`
- `web/src/modules/auth/authService.ts`
- `web/src/modules/devices/deviceService.ts`
- `web/src/pages/DevicesPage.tsx`
- `web/src/modules/payroll/payrollService.ts`
- `web/src/modules/p0/p0Service.ts`
- `web/src/pages/P0OperationsPages.tsx`

## Grupo de evidencia reconciliada

- `artifacts/CODEX_SPEC_COVERAGE_MATRIX.md`
- `artifacts/CODEX_MANUAL_TEST_CHECKLIST.md`
- `artifacts/CODEX_CRITICAL_DIFF_REVIEW.md`
- `artifacts/CODEX_CLEAN_CHANGESET_MANIFEST.md`
- `artifacts/CODEX_DATABASE_CHANGES.md`
- `artifacts/CODEX_UNRESOLVED_ITEMS.md`
- `artifacts/CODEX_TEST_RESULTS.md`
- `artifacts/CODEX_SECURITY_REVIEW.md`
- `artifacts/CODEX_PRECOMMIT_EVIDENCE_RECONCILIATION.md`
- `artifacts/CODEX_P0_RESOLUTION_REPORT.md`

## Archivos mixtos y cambios protegidos

- Cada archivo tracked modificado debe revisarse por hunk antes de un commit selectivo.
- `TwoConnectFingerprintManager.kt` conserva las correcciones de compilacion aprobadas y no debe revertirse.
- Los cambios previos del usuario no se eliminaron ni se atribuyen automaticamente a P0.
- Los archivos indicados en `CODEX_FILES_TO_EXCLUDE_FROM_COMMIT.md` siguen excluidos hasta revision explicita.
- Un commit documental no debe arrastrar APK, caches, credenciales, logs ni configuracion local.

## Estado operativo

- Migracion 0050: creada localmente, no aplicada.
- pgTAP 0050: creado, no ejecutado.
- Android/Web: validaciones locales finales en PASS.
- APK vigente: staging y firmado en debug; no instalado.
- Produccion: no tocada.
- Git add/commit/push: no ejecutados.
- Despliegues: no ejecutados.

Es seguro preparar commits selectivos por path/hunk despues de revisar archivos mixtos. Esto no significa que el changeset este aprobado para merge, STAGING o produccion.
