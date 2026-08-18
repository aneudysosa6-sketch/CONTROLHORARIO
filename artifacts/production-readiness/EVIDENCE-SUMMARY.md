# Resumen validado de evidencias

## Estado del repositorio
- `git status --short`: `?? artifacts/`
- `git diff --check`: sin avisos de whitespace.
- Carpeta inspeccionada: `artifacts/production-readiness/` con 7 archivos (incluye `CHECKPOINT.md`).

## Android

| Validaci�n | Resultado | Evidencia | Observaci�n |
|---|---|---|---|
| Unit tests | PASS | `artifacts/production-readiness/android-unit-tests-manual.txt` + `artifacts/production-readiness/android-unit-test-summary.txt` | Se ejecutaron 178 pruebas unitarias distribuidas en 34 suites: 178 correctas, 0 fallos, 0 errores y 0 omitidas. Gradle terminó con BUILD SUCCESSFUL y TEST_EXIT_CODE=0. El reporte HTML existe. |
| Assemble Debug | PASS (con limitación) | `artifacts/production-readiness/android-manual-validation.txt` | `ASSEMBLE_DEBUG_EXIT_CODE=0`. El APK quedó UP-TO-DATE y no fue regenerado durante esa ejecución; sigue siendo un APK debug y no es apto para producción. |
| Lint Debug | PASS DE EJECUCIÓN | `artifacts/production-readiness/android-manual-validation.txt` + `app/build/reports/lint-results-debug.xml` | `LINT_DEBUG_EXIT_CODE=0`; 0 errores, 57 warnings, 2 hints y 59 hallazgos totales. |
| Assemble Release | BLOCKED | `artifacts/production-readiness/android-remediation.txt` | `=== attempt release ===` + `BLOCKED -- RELEASE SIGNING NOT CONFIGURED (no app/signing.properties)`. |

## APK

- Existe: S� (`Test-Path ...app-debug.apk` = True)
- Ruta relativa: `app/build/outputs/apk/debug/app-debug.apk`
- Tama�o: `120962325`
- Fecha: `mi�rcoles, 29 de julio de 2026 1:28:19 p.�m.`
- Apto para producción: NO, salvo release firmado y validado.

## Supabase

| Verificación | Resultado | Evidencia | Clasificación |
|---|---|---|---|
| Entorno local/CLI | RESOLVED | `artifacts/production-readiness/supabase-manual-validation.txt`: `SUPABASE_HOME_WRITE=PASS` y códigos de salida `0` para version, projects list, migration list linked y functions list | `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT` |
| Proyecto vinculado | CONFIRMADO | `projects list` identifica `controlhorario-prod` con project ref `<PROJECT_REF_REDACTED>` como proyecto vinculado | Solo lectura; proyecto remoto identificado |
| Migraciones | BLOCKED | `migration list --linked`: `0001`-`0029` presentes local y remotamente; `0030` presente localmente y ausente remotamente | `CONFIGURATION / MIGRATION DRIFT` |
| Funciones | INVENTARIO CONFIRMADO | `functions list`: 6 funciones remotas `ACTIVE` | G09 no aprobado; faltan auditorías de autenticación, autorización, `verify_jwt` y tenant |
| Escrituras remotas | NO REALIZADAS | La validación declara que no ejecutó `db push`, `db reset`, despliegues de funciones ni modificación de secretos | Condición de solo lectura satisfecha |

## Branding Web

| Control | Resultado | Evidencia |
|---|---|---|
| CONTROL HORARIO visible | PARCIAL | `src\modules\employees\employeeExports.ts:51` y `payrollExports.ts:47` (`CONTROLHORARIO / OSINET`) |
| OSINET no visible | PARCIAL | Coincidencias `osinet_employees` y texto `... / OSINET` en utilidades de exportación interna |
| Encabezado del portal correcto | PARCIAL | No se evidencia en este archivo una verificación explícita de `Portal privado del empleado` |
| Sin rutas locales | NO_CONFIRMADO | No hay coincidencias directas capturadas para `file:///`, `localhost`, direcciones loopback o rutas Windows en la extracci�n de muestra |
| Assets correctos | PARCIAL | Evidencia de rutas de assets de `dist` sin reporte de 404 ni rutas rotas confirmadas |

## Bloqueos del entorno local
- Android/Java/Gradle: `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`. La validación manual fuera del sandbox demostró que Java y Gradle pudieron ejecutarse y que `assembleDebug`, `lintDebug` y las pruebas unitarias terminaron correctamente. No es un fallo abierto del producto.
- Supabase: `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`. El EPERM anterior ocurrió dentro del entorno restringido de Codex; la validación manual confirmó escritura en `SUPABASE_HOME` y ejecución correcta de los comandos. No demostró una caída ni una vulnerabilidad de Supabase.

## Hallazgos abiertos por severidad
- Altos: 2 (`A2` release signing y `A6` migration drift).
- Medios: 2 (`A4` y `A5`).
- Bajos: 0.
- Total abierto: 4.
- Los bloqueos resueltos de Java/Gradle y Supabase CLI dentro de Codex no se incluyen en este conteo.

## Fallos reales del producto
- Ninguno confirmado como fallo funcional del producto a partir de evidencia ejecutable.

## Información todavía no confirmada
- Aplicación remota de la migración local `0030` y resolución de la divergencia detectada.
- Seguridad operativa de las 6 Edge Functions: autenticación, autorización, `verify_jwt` y aislamiento de tenant.
- Validación completa de branding visible en portal desde evidencia consolidada.

## A6

- ID: `A6`
- Estado: `OPEN`
- Severidad: `HIGH`
- Tipo: `CONFIGURATION`
- Clasificación: `PENDING PRODUCTION MIGRATION`
- Riesgo tecnico de aplicacion: `MEDIUM`
- Riesgo de no aplicarla: `MEDIUM`
- G07: `BLOCKED`
- Veredicto general: `NO-GO PARA USO CON EMPLEADOS REALES`
- Descripción: "Las migraciones 0001–0029 coinciden local y remotamente. La migracion `0030_fix_employee_role_canonicalization.sql` existe localmente y todavia no ha sido aplicada al proyecto de produccion. No existe evidencia de migration history drift. La migracion esta apta para prueba en staging, no para produccion."

## Recomendación para REPORT.md
- Redactar `REPORT.md` solo con evidencias confirmadas y no inferidas.

## Observación de código legacy de huellas
- `com.example.controlhorario.fingerprint.external.FingerprintVerificationPolicyTest`
- Clasificación: `REVIEW REQUIRED — LEGACY FINGERPRINT CODE`
- El nombre de la prueba por sí solo **no demuestra** que `2Connect` esté activo.
- La revisión de rutas UI, SDK, USB e inicialización del lector pertenece al gate de biometría, no a `G01`.
