# CONTROL HORARIO -- Preparacion para produccion

## 1. Veredicto

**NO-GO PARA USO CON EMPLEADOS REALES**

- Fecha del analisis: 2026-07-29 (America/Santo_Domingo)
- Repositorio: raíz del checkout local (`<REPOSITORY_ROOT>`)
- Rama del snapshot histórico: `main`; el worktree actual se revisa por separado en `feature/production-readiness`.
- Alcance: Auditoria de preparacion para produccion (Android, Web y Supabase), con evidencia limitada a artefactos de readiness.
- Limitaciones: no se ejecutaron builds nuevos, no se ejecuto Supabase adicional y no se corrieron pruebas fuera de evidencia existente.

## 2. Resumen ejecutivo

La verificacion encontro pendientes que impiden la habilitacion productiva.

En Android, G01 queda cerrado como `PASS`. Se ejecutaron 178 pruebas unitarias distribuidas en 34 suites: 178 correctas, 0 fallos, 0 errores y 0 omitidas. Gradle terminó con BUILD SUCCESSFUL y TEST_EXIT_CODE=0.

Existe un APK debug detectado y `assembleDebug` fue `UP-TO-DATE`; el APK no fue regenerado en esta corrida.

El hallazgo anterior de acceso denegado al ejecutar Java/Gradle desde Codex queda como `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`. La validacion manual fuera del sandbox demostro que Java y Gradle pudieron ejecutarse y que `assembleDebug`, `lintDebug` y las pruebas unitarias terminaron correctamente; no es un fallo abierto del producto.

La validacion manual de Supabase fuera del sandbox confirma `SUPABASE_HOME_WRITE=PASS` y codigos de salida `0` para version, projects list, migration list linked y functions list. El EPERM anterior queda resuelto como `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`; no demostro una caida ni una vulnerabilidad de Supabase.

El proyecto remoto vinculado es `controlhorario-prod` (`<PROJECT_REF_REDACTED>`). Los historiales local y remoto fueron obtenidos: `0001`-`0029` coinciden, pero la migracion `0030` existe localmente y esta ausente remotamente. G07 permanece bloqueado por `CONFIGURATION / MIGRATION DRIFT`; no se realizo ninguna operacion remota de escritura.

En Web, existe evidencia de build de produccion de cliente (`pnpm run build`) pero el branding publico permanece solo PARCIAL, con referencias internas (`CONTROLHORARIO / OSINET`, `osinet_...`) y sin prueba cerrada de mensajes visuales y rutas locales.

No se confirma fallo funcional real del producto en esta evidencia; se confirman controles no ejecutados o no concluidos.

Se puede seguir usando un entorno de desarrollo y revisiones internas de codigo no productivo, pero no se autoriza uso con datos reales ni para pilotaje.

## 3. Estado general

| Area | Resultado | Evidencia | Bloquea piloto | Bloquea produccion |
|---|---|---|---|---|
| Precheck Git | PASS | `artifacts/production-readiness/precheck.txt` | No | No |
| Secret scan | PASS | `artifacts/production-readiness/secret-scan.txt` | No | No |
| Android unit tests | PASS | `artifacts/production-readiness/android-unit-tests-manual.txt` + `artifacts/production-readiness/android-unit-test-summary.txt` | No | No |
| Android assembleDebug | PASS | `artifacts/production-readiness/android-manual-validation.txt` | Si | Si |
| Android lintDebug | PASS DE EJECUCION | `artifacts/production-readiness/android-manual-validation.txt` + `app/build/reports/lint-results-debug.xml` | Si | Si |
| Android release | BLOCKED | `artifacts/production-readiness/android-build.txt` | Si | Si |
| APK productivo | NOT ASSESSED | `artifacts/production-readiness/android-build.txt` | Si | Si |
| Web production build | PASS | `artifacts/production-readiness/web-build.txt` | No | No |
| Web branding | PARTIAL | `artifacts/production-readiness/web-brand-scan.txt` | Si | Si |
| Supabase CLI | RESOLVED | `artifacts/production-readiness/supabase-manual-validation.txt` | No | No |
| Migraciones remotas | BLOCKED — MIGRATION DRIFT | `artifacts/production-readiness/supabase-manual-validation.txt` | Si | Si |
| Edge Functions remotas | NOT ASSESSED (inventario confirmado) | `artifacts/production-readiness/supabase-manual-validation.txt` | Si | Si |
| Revision visual Android | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |
| Revision visual Web | NOT ASSESSED | `artifacts/production-readiness/web-build.txt` | Si | Si |
| Autenticacion | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |
| Autorizacion | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |
| RLS multiempresa | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |
| Reconocimiento facial | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |
| Liveness/PAD | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |
| Jornadas offline | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |
| Nomina | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |
| N8N | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |
| Backup y restauracion | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |
| Privacidad | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |
| Piloto | NOT ASSESSED | `artifacts/production-readiness/CHECKPOINT.md` | Si | Si |

## 4. Resultados Android

| Validacion | Resultado | Evidencia | Observacion |
|---|---|---|---|
| Unit tests | PASS | `artifacts/production-readiness/android-unit-tests-manual.txt` + `artifacts/production-readiness/android-unit-test-summary.txt` | Se ejecutaron 178 pruebas unitarias distribuidas en 34 suites: 178 correctas, 0 fallos, 0 errores y 0 omitidas. Gradle terminó con BUILD SUCCESSFUL y TEST_EXIT_CODE=0. El reporte HTML existe. |
| Assemble Debug | PASS | `artifacts/production-readiness/android-manual-validation.txt` | `ASSEMBLE_DEBUG_EXIT_CODE=0`. El APK quedó UP-TO-DATE y no fue regenerado durante esa ejecución; sigue siendo un APK debug y no es apto para producción. |
| Lint Debug | PASS DE EJECUCION | `artifacts/production-readiness/android-manual-validation.txt` + `app/build/reports/lint-results-debug.xml` | `LINT_DEBUG_EXIT_CODE=0`; 59 hallazgos (`57` Warning, `2` Hint, `0` Error). Sin bloqueo por severidad para produccion (deuda técnica no bloqueante). |
| Assemble Release | BLOCKED | `artifacts/production-readiness/android-build.txt` | `BLOCKED -- RELEASE SIGNING NOT CONFIGURED (no app/signing.properties)`. |
| Release signing | BLOCKED | `artifacts/production-readiness/android-build.txt` | Falta `app/signing.properties`, no existe evidencia de firma de release. |

Detalle de lint (debug):
- Total de severidad: `Error=0`, `Warning=57`, `Informational=0`, `Hint=2`.
- CategorÃ­a principal: `Correctness` (27), `Productivity` (20), `Performance` (12).
- Archivos mÃ¡s afectados: `app\\build.gradle.kts` (19), `gradle\\libs.versions.toml` (12), `app\\src\\main\\res\\values\\colors.xml` (7).

## 5. APK encontrado

- Ruta relativa: `app/build/outputs/apk/debug/app-debug.apk`
- Tipo: debug
- Tamano: 120962325 bytes
- Fecha: miercoles, 29 de julio de 2026, 1:28:19 p. m.
- Estado: `=== app-debug.apk exists ===` y no evidencia de build/reprueba actual adjunta.
- Conclusiones: "APK debug existente, no validado ni firmado como release de produccion."
- Regla operativa: no usar como artefacto productivo.

## 6. Resultado Web

### 6.1 Build de produccion

`artifacts/production-readiness/web-build.txt` muestra ejecucion de instalacion y build con salida de `vite build` exitosa y artefactos generados en `dist/`.

### 6.2 Branding

`artifacts/production-readiness/web-brand-scan.txt` detecta cadenas internas `osinet_employees`, `CONTROLHORARIO / OSINET` en utilidades de exportacion y assets. No hay evidencia cerrada del texto publico del portal (`Portal privado del empleado`) ni de la eliminacion total de marcas internas en UI.

### 6.3 Rutas locales

No se encontraron en evidencia revisada resultados concluyentes sobre `file:///`, `localhost` o rutas locales de forma completa.

### 6.4 Assets

Se observan rutas de assets de `dist`, sin reporte completo de carga sin 404 de todos los recursos en ejecucion real.

### 6.5 Revision visual

No se hizo revision visual interactiva en esta etapa (solo evidencia estatica de archivos).

## 7. Resultado Supabase

### Estado confirmado

- `SUPABASE_HOME_WRITE=PASS`.
- `VERSION_EXIT_CODE=0`, `PROJECTS_LIST_EXIT_CODE=0`, `MIGRATION_LIST_LINKED_EXIT_CODE=0` y `FUNCTIONS_LIST_EXIT_CODE=0`.
- Proyecto vinculado: `controlhorario-prod`, project ref `<PROJECT_REF_REDACTED>`.
- Historial local y remoto obtenido: migraciones `0001`-`0029` coincidentes.
- Divergencia: migracion `0030` presente localmente y ausente remotamente.
- Inventario remoto: 6 Edge Functions en estado `ACTIVE`.
- Validacion de solo lectura: no se ejecuto `db push`, `db reset`, despliegue de funciones ni modificacion de secretos.

### Estado no confirmado

- Aplicacion remota de la migracion local `0030`.
- Seguridad de cada Edge Function: autenticacion, autorizacion, `verify_jwt` y aislamiento de tenant.
- Estado funcional de los servicios backend, que no queda probado por comandos de inventario.

### Bloqueo del entorno

`RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`. El EPERM anterior ocurrio dentro del entorno restringido de Codex. La validacion manual fuera del sandbox confirmo la escritura en `SUPABASE_HOME` y la ejecucion correcta de los comandos; no demostro una caida ni una vulnerabilidad de Supabase.

### Riesgo productivo por falta de verificacion

G07 permanece bloqueado por una divergencia real de configuracion: la migracion local `0030` no figura en el historial remoto. No se aplico, no se ejecuto `db push` y no se reparo el historial. G09 permanece `NOT ASSESSED`: `functions list` confirma solo el inventario remoto.

## 8. Hallazgos

| ID | Severidad | Tipo | Hallazgo | Evidencia | Bloquea piloto | Bloquea produccion |
|---|---|---|---|---|---|---|
| A1 | RESOLVED | LOCAL ENVIRONMENT | `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`. El acceso denegado ocurrió dentro del entorno restringido de Codex. Java se ejecutó correctamente desde PowerShell normal y Gradle pudo ejecutar las pruebas unitarias, `assembleDebug` y `lintDebug`. No se demostró un fallo del producto y A1 no se cuenta entre los hallazgos abiertos. | `artifacts/production-readiness/android-unit-tests-manual.txt` + `artifacts/production-readiness/android-unit-test-summary.txt` | No | No |
| A2 | Alta | CONFIGURATION | `app/signing.properties` no existe y no hay release firmado. | `artifacts/production-readiness/android-build.txt` | Si | Si |
| A3 | RESOLVED | LOCAL ENVIRONMENT | `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`. El EPERM ocurrio dentro del entorno restringido de Codex. La validacion manual confirmo `SUPABASE_HOME_WRITE=PASS` y ejecucion correcta de version, projects list, migration list linked y functions list. No demostro una caida ni una vulnerabilidad de Supabase; A3 no se cuenta entre los hallazgos abiertos. | `artifacts/production-readiness/supabase-manual-validation.txt` | No | No |
| A4 | Media | VALIDATION BLOCKER | Branding publico de Web no queda cerrado por evidencia parcial y falta confirmacion de encabezado publico y rutas. | `artifacts/production-readiness/web-brand-scan.txt` | Si | Si |
| A5 | Media | NOT ASSESSED | Autenticacion, autorizacion, RLS multiempresa, biometria y otras areas criticas aun no validadas en esta etapa. | `artifacts/production-readiness/CHECKPOINT.md` y `EVIDENCE-SUMMARY.md` | Si | Si |
| A6 | Alta | CONFIGURATION | PENDING PRODUCTION MIGRATION: La migracion `0030` existe en el historial local y esta ausente en el historial remoto vinculado. La divergencia bloquea G07 hasta que sea explicada y resuelta mediante un procedimiento autorizado; no se ejecuto ninguna escritura. | `artifacts/production-readiness/supabase-manual-validation.txt` | Si | Si |

Hallazgo reclasificado:

- `A1`: `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`. El acceso denegado anterior al ejecutar Java/Gradle desde Codex correspondia al sandbox/entorno local. La validacion manual demostro ejecucion correcta de Java, Gradle, `assembleDebug`, `lintDebug` y pruebas unitarias. No permanece como hallazgo alto abierto del producto.
- `A3`: `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`. El EPERM anterior correspondia al entorno restringido de Codex y no a una caida ni vulnerabilidad confirmada de Supabase.
- `A6`: `OPEN`, `Alta`, `CONFIGURATION`, `PENDING PRODUCTION MIGRATION`. Se mantiene abierta hasta validar la migracion `0030` en staging siguiendo un proceso autorizado.
- Hallazgos abiertos por severidad, recalculados desde las filas abiertas: 2 altos (`A2`, `A6`), 2 medios (`A4`, `A5`), 0 bajos; total 4.
- Los hallazgos resueltos `A1` y `A3` no se incluyen en el conteo abierto.

Observacion de huellas legacy:

- `com.example.controlhorario.fingerprint.external.FingerprintVerificationPolicyTest`
- Clasificacion: `REVIEW REQUIRED — LEGACY FINGERPRINT CODE`.
- El nombre de la prueba no demuestra por si solo que `2Connect` este activo.
- La revision de rutas UI, SDK, USB e inicializacion del lector pertenece al gate de biometria, no a `G01`.

## 9. Bloqueadores para produccion

- `G01` esta cerrado como `PASS`; `G02` permanece `PASS` y `G03` permanece `PASS DE EJECUCION`.
- Bloqueo real: release firmado de Android no configurado y no validado.
- Bloqueo real: G07 presenta `CONFIGURATION / MIGRATION DRIFT`; la migracion `0030` existe localmente y no figura remotamente.
- Bloqueo real: branding web parcial y sin evidencia visual final.
- Bloqueo real: controles criticos (piloto, roles, RLS, liveness/PAD, nomina) sin evidencia.
- Falta de evidencia de:
  - backup/restauracion
  - pruebas con roles reales
  - controles exactos de RLS multiempresa
  - exactitud de nomina en condiciones de negocio
- Aclaracion: no se interpreta como fallo del producto lo no evaluado; se interpreta como riesgo de aprobacion pendiente.

## 10. Areas todavia no evaluadas

Autenticacion, autorizacion, permisos por rol, aislamiento entre empresas, RLS, Edge Functions, biometria facial, liveness/PAD, jornadas offline, idempotencia, calculo de nomina, N8N, backups, restauracion, privacidad, visual Android, visual Web, piloto.

## 11. Puertas de salida a produccion

| Gate | Requisito | Estado actual | Evidencia requerida |
|---|---|---|---|
| G01 â€” Android unit tests | Unit tests ejecutables y `EXIT_CODE=0` | PASS | `artifacts/production-readiness/android-unit-tests-manual.txt` + `artifacts/production-readiness/android-unit-test-summary.txt`: 34 suites, 178 pruebas, 0 fallos, 0 errores, 0 omitidas y reporte HTML existente. |
| G02 â€” Android debug build | `assembleDebug` ejecutado y valido | PASS | `artifacts/production-readiness/android-manual-validation.txt` con `ASSEMBLE_DEBUG_EXIT_CODE=0` (APK `UP-TO-DATE`, no regenerado). |
| G03 â€” Android lint | `lintDebug` aprobado | PASS DE EJECUCION | `artifacts/production-readiness/android-manual-validation.txt` y `app/build/reports/lint-results-debug.xml` (`LINT_DEBUG_EXIT_CODE=0`). |
| G04 â€” Android release firmado | `app/signing.properties` + firma release validada | BLOCKED | `app/signing.properties` + evidencia de build release firmado. |
| G05 â€” Web build | Build productivo sin regresiones | PASS | build de produccion + validacion manual funcional. |
| G06 â€” Branding Web y Android | Texto e interfaz publico validos | BLOCKED/PARTIAL | Evidencia visual y rutas de acceso sin fugas internas. |
| G07 â€” Supabase/migraciones | Migraciones y proyectos remotos verificados | BLOCKED — MIGRATION DRIFT | Proyecto vinculado `controlhorario-prod` (`<PROJECT_REF_REDACTED>`); historiales obtenidos; `0001`-`0029` coinciden y `0030` existe solo localmente. No se realizaron escrituras remotas. |
| G08 â€” Autorizacion y RLS | Permisos y aislamiento validados | NOT ASSESSED | Pruebas por rol, sesiones y RLS multiempresa en entorno controlado. |
| G09 â€” Edge Functions | Inventario y ejecucion valida | NOT ASSESSED | Inventario confirmado: 6 funciones remotas `ACTIVE`; faltan auditorias de autenticacion, autorizacion, `verify_jwt` y tenant. |
| G10 â€” Reconocimiento facial y liveness | Pruebas de vida y control anti-suplantacion | NOT ASSESSED | Evidencia de tests positivos y negativos. |
| G11 â€” Jornadas y offline | Validacion de flujo offline y reconciliacion | NOT ASSESSED | Escenarios con fallos red y recuperacion. |
| G12 â€” Nomina | Exactitud y trazabilidad final | NOT ASSESSED | Casos de calculo y cierre con resultados reconciliados. |
| G13 â€” Backup y restauracion | Procedimiento probado y restauracion valida | NOT ASSESSED | Evidencia operativa documentada y ensayos de recuperacion. |
| G14 â€” Privacidad y RR HH | Matriz de datos y accesos revisada | NOT ASSESSED | RevisiÃ³n de privacidad, retencion y trazabilidad. |
| G15 â€” Piloto controlado | Piloto aprobado con controles | NOT ASSESSED | Condiciones de piloto cerradas y riesgos mitigados. |

## 12. Plan de correccion priorizado

### Prioridad 1 â€” Cerrar bloqueos productivos

- Estado: `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`.
- Evidencia de cierre: la validacion manual fuera del sandbox confirmo Java, Gradle, `assembleDebug`, `lintDebug` y pruebas unitarias ejecutados correctamente.
- Clasificacion: incidencia del entorno local, no hallazgo abierto del producto.

- Accion: Configurar release signing seguro y documentado.
  - Responsable: equipo Android / Seguridad
  - Evidencia de cierre: artefacto release firmado y trazabilidad.
  - Bloquea piloto: Si
  - Bloquea produccion: Si

- Estado: A3 `RESOLVED — CODEX SANDBOX / LOCAL ENVIRONMENT`.
- Evidencia de cierre: `SUPABASE_HOME_WRITE=PASS` y todos los comandos manuales con codigo de salida `0`.
- Clasificacion: incidencia del entorno restringido de Codex, no fallo abierto del producto.

- Accion: Resolver mediante procedimiento autorizado la divergencia de la migracion `0030`, sin ejecutar automaticamente `db push` ni reparar el historial.
  - Responsable: equipo backend
  - Evidencia de cierre: historial local/remoto alineado y explicacion documentada de cualquier divergencia.
  - Bloquea piloto: Si
  - Bloquea produccion: Si

### Prioridad 2 â€” Validaciones de seguridad

- Accion: validar autenticacion, permisos, roles y autorizacion remota.
  - Responsable: backend + QA
  - Evidencia de cierre: casos de acceso por rol y denegacion controlada.
  - Bloquea piloto: Si
  - Bloquea produccion: Si

- Accion: auditar RLS multiempresa y aislamiento.
  - Responsable: backend + seguridad
  - Evidencia de cierre: pruebas de fuga de datos entre empresas.
  - Bloquea piloto: Si
  - Bloquea produccion: Si

### Prioridad 3 â€” Operacion laboral

- Accion: validar reconocimiento facial y liveness/PAD bajo escenarios controlados.
  - Responsable: Android + backend
  - Evidencia de cierre: logs de match/falsos positivos y negativos.
  - Bloquea piloto: Si
  - Bloquea produccion: Si

- Accion: validar jornadas offline y nomina en escenarios reales de negocio.
  - Responsable: Android + web + QA
  - Evidencia de cierre: pruebas de borde y reporte de exactitud.
  - Bloquea piloto: Si
  - Bloquea produccion: Si

### Prioridad 4 â€” Operacion productiva

- Accion: definir y probar backup y restauracion, monitoreo y rollback.
  - Responsable: operaciones
  - Evidencia de cierre: simulacion documentada exitosa.
  - Bloquea piloto: Si
  - Bloquea produccion: Si

- Accion: preparar guia de privacidad y entrenamiento RRHH.
  - Responsable: RRHH + seguridad
  - Evidencia de cierre: checklist firmado.
  - Bloquea piloto: Si
  - Bloquea produccion: Si

## 13. Plan de piloto provisional

No esta autorizado actualmente.

Condiciones minimas para habilitar piloto posterior:
- Ambiente de staging aislado.
- Datos sinteticos.
- Build release identificado y trazable.
- Backend validado (auth, autorizacion, RLS, migraciones, funciones).
- Grupo de prueba pequeno.
- Metodologia de control paralelo.
- Nomina no vinculante en piloto.
- Soporte activo y matriz de incidentes.
- Procedimiento de rollback definido.

## 14. Confirmaciones

- No se usaron datos reales.
- No se ejecuto `db push`.
- No se ejecuto `db reset`.
- No se despliegan Edge Functions.
- No se despliegue en Vercel.
- No se modificaron secretos.
- No se hizo commit.
- No se hizo push.
- No se distribuyo el APK debug.
- No se reactivio 2Connect.
- No se autorizo produccion.
