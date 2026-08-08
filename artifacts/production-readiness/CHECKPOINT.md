# Checkpoint de auditoria

## Estado del repositorio

## Seguimiento A6

- ID: `A6`
- Estado: `OPEN`
- Severidad: `HIGH`
- Tipo: `CONFIGURATION`
- Clasificación: `PENDING PRODUCTION MIGRATION`
- Riesgo tecnico de aplicacion: `MEDIUM`
- Riesgo de no aplicarla: `MEDIUM`
- G07: `BLOCKED`
- Veredicto: `NO-GO PARA USO CON EMPLEADOS REALES`
- `git status --short`: `?? artifacts/`
- `git diff --check`: sin avisos de whitespace
- Carpeta inspeccionada: `artifacts/production-readiness/`
- Conteo de archivos confirmados: 7 (incluyendo `CHECKPOINT.md`)

## Resultado por area (segun esta etapa)

| Area | Estado |
|---|---|
| Android Build | PASS (`G01`-`G03`; `G04` sin cambios) |
| Supabase | BLOCKED — MIGRATION DRIFT |
| Branding Web | PARCIAL |

## Evidencia de cierre
- Android G01: `artifacts/production-readiness/android-unit-tests-manual.txt` confirma `BUILD SUCCESSFUL` y `TEST_EXIT_CODE=0`; `artifacts/production-readiness/android-unit-test-summary.txt` confirma `RESULT=PASS`, 34 suites XML, 178 pruebas, 0 fallos, 0 errores, 0 omitidas y reporte HTML existente.
- Se ejecutaron 178 pruebas unitarias distribuidas en 34 suites: 178 correctas, 0 fallos, 0 errores y 0 omitidas. Gradle terminó con BUILD SUCCESSFUL y TEST_EXIT_CODE=0.
- Android: `artifacts/production-readiness/android-manual-validation.txt` confirma `ASSEMBLE_DEBUG_EXIT_CODE=0` y `LINT_DEBUG_EXIT_CODE=0`.
- Android Lint: `app/build/reports/lint-results-debug.xml` existe; 59 hallazgos (`57` Warning, `2` Hint), `0` Errors.
- Observación de código legacy: `com.example.controlhorario.fingerprint.external.FingerprintVerificationPolicyTest` se registra como `REVIEW REQUIRED — LEGACY FINGERPRINT CODE`. El nombre de la prueba no demuestra por sí solo que `2Connect` esté activo; la revisión de rutas UI, SDK, USB e inicialización del lector pertenece al gate de biometría, no a `G01`.
- Supabase A3: `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`; `artifacts/production-readiness/supabase-manual-validation.txt` confirma `SUPABASE_HOME_WRITE=PASS` y códigos de salida `0` para version, projects list, migration list linked y functions list. El EPERM anterior ocurrió dentro del sandbox de Codex y no demostró una caída ni vulnerabilidad de Supabase.
- Supabase G07: proyecto remoto vinculado `controlhorario-prod` (`<PROJECT_REF_REDACTED>`) identificado; historiales local y remoto obtenidos sin operaciones remotas de escritura. Las migraciones `0001`-`0029` coinciden, pero `0030` existe solo localmente: nuevo hallazgo `CONFIGURATION / MIGRATION DRIFT`.
- Edge Functions: inventario remoto de 6 funciones `ACTIVE` confirmado. G09 permanece sin aprobar porque faltan auditorías de autenticación, autorización, `verify_jwt` y tenant.
- Web brand: `artifacts/production-readiness/web-brand-scan.txt` muestra referencias internas (`osinet_...`, `CONTROLHORARIO / OSINET`) sin evidencia cerrada de texto publico de portal.

## Nota de estado
- G01: `PASS`.
- G02: `assembleDebug` OK en esta ejecución, con APK `UP-TO-DATE` (no regenerado).
- G03: `lintDebug` OK en esta ejecución (`xml` generado y cargado).
- Limitación G02: El APK quedó UP-TO-DATE y no fue regenerado durante esa ejecución; sigue siendo un APK debug y no es apto para producción.
- G03: `PASS DE EJECUCIÓN`, con 0 errores, 57 warnings, 2 hints y 59 hallazgos totales.
- Acceso Java/Gradle desde Codex: `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`. La validación manual fuera del sandbox confirmó la ejecución correcta de Java, Gradle, `assembleDebug`, `lintDebug` y pruebas unitarias; no se considera un fallo abierto del producto.
- Hallazgos abiertos: 2 altos (`A2`, `A6`), 2 medios (`A4`, `A5`), 0 bajos; total 4. Los bloqueos resueltos A1 y A3 no están incluidos.
- Supabase continúa bloqueado en G07 por la divergencia de la migración `0030`, no por el entorno local.
- Siguiente paso: redactar `REPORT.md` únicamente con evidencia confirmada.
