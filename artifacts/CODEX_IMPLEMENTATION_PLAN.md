# Plan de implementacion integral

Fecha: 2026-08-24
Estado: EN EJECUCION
Referencia permitida: STAGING `[STAGING_PROJECT_REF]`
Referencia prohibida: PRODUCCION `[PRODUCTION_PROJECT_REF]`

## Reglas de ejecucion

1. Preservar todos los cambios existentes y las correcciones aprobadas de `TwoConnectFingerprintManager.kt`.
2. Usar `JAVA_HOME=C:\Program Files\Android\Android Studio\jbr` en cada comando Gradle.
3. No usar valores ficticios como evidencia de integracion ni almacenar secretos.
4. No operar remotamente Supabase sin confirmar `supabase/.temp/project-ref = [STAGING_PROJECT_REF]`.
5. No tocar produccion ni realizar acciones destructivas sobre telefonos.
6. Un modulo solo pasa a Implementado con persistencia, dominio/repositorio/API, RLS/permisos/alcance, errores y pruebas cuando apliquen.
7. Despues de cada fase: compilar, ejecutar pruebas relacionadas, corregir regresiones y actualizar la matriz.

## Fases

| Fase | Alcance | Entregable verificable | Estado |
|---:|---|---|---|
| 1 | Roles, permisos y alcance | Un rol principal, roles protegidos, dependencias, alcance supervisor en UI/API/RLS y pruebas | Completada localmente con brechas documentadas |
| 2 | Empresa, sucursales y departamentos | CRUD seguro, estados, restricciones de reasignacion, supervisor y snapshots | Completada localmente con brechas documentadas |
| 3 | RR. HH. y empleados | Alta guiada, codigo/cuenta, ficha, perfil, historicos, documentos y activacion | En ejecucion |
| 4 | Licencias, vacaciones y prestamos | Motores de estado/devengo/saldo, documentos, historicos, auditoria y pruebas | Pendiente |
| 5 | Asistencia y jornadas | Maquina de estados, bloqueos, incompletas, NO PAGAR, consolidacion y offline | Pendiente |
| 6 | Dispositivos y Terminal facial | Enrollment, configuracion atomica, sync, cache minimo, rostro, kiosco y mensajes de estado | Pendiente |
| 7 | Nomina y pagos | Ciclos, ledger, deducciones, festivos, cierre/versiones, pagos, volantes/exportaciones | Pendiente |
| 8 | Portal y reportes | Portal siempre visible, eventos/historial, dashboard, lista negra y reportes | Pendiente |
| 9 | Mensajes a empleados | Creacion unitaria, tipos, entrega post-movimiento, offline y confirmacion unica | Pendiente |
| 10 | Auditoria, sesiones, navegacion y endurecimiento | Auditoria completa, cuenta/sesiones, guardas de ruta, seguridad y cierre documental | Pendiente |

## Puertas de calidad por fase

- Android: compilacion Kotlin y pruebas unitarias relacionadas con la fase.
- Web: pruebas de politica relacionadas y compilacion TypeScript cuando la fase toque web.
- Base de datos: revision estatica de migraciones, funciones, RLS, grants e idempotencia; ejecucion local si el stack esta disponible.
- Seguridad: ninguna operacion remota si la referencia de enlace no es STAGING; ningun secreto en logs o artefactos.
- Cobertura: actualizar `CODEX_SPEC_COVERAGE_MATRIX.md` con evidencia y bloqueos reales.

## Validacion final obligatoria

```text
gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --no-daemon
pnpm install --frozen-lockfile
pnpm run test:employee-code
pnpm run test:supervisor-scope
pnpm run test:edge-dependencies
pnpm run build
```

Tambien se ejecutaran las pruebas adicionales descubiertas. El APK se inspeccionara para paquete STAGING, referencias de proyecto, firma y SHA-256.

## Artefactos finales

- `CODEX_SPEC_COVERAGE_MATRIX.md`
- `CODEX_IMPLEMENTATION_PLAN.md`
- `CODEX_FINAL_REPORT.md`
- `CODEX_TEST_RESULTS.md`
- `CODEX_MANUAL_TEST_CHECKLIST.md`
- `CODEX_DATABASE_CHANGES.md`
- `CODEX_SECURITY_REVIEW.md`
- `CODEX_UNRESOLVED_ITEMS.md`

## Avance verificado - Fase 3 (2026-08-24)

La asignación secuencial fue sustituida por una reserva aleatoria y única. Compilación y pruebas relacionadas completadas. La fase se cierra localmente como parcial y la Fase 4 queda iniciada.
## Avance verificado - Fase 4 (2026-08-24)

Invariantes locales y persistencia endurecidas; pruebas y builds correctos. Fase cerrada como parcial y Fase 5 iniciada.
## Avance verificado - Fase 5 (2026-08-24)

Cronología local/Edge/SQL endurecida; pruebas ejecutables y builds correctos. Fase parcial por migración remota y una aserción SQL no portable; Fase 6 iniciada.
## Avance verificado - Fase 6 (2026-08-24)

Credenciales y alcance de terminal endurecidos; pruebas y builds correctos. Fase cerrada localmente como parcial y Fase 7 iniciada.
## Avance verificado - Fase 7 (2026-08-24)

Precisión y neto local endurecidos; pruebas y build correctos. Fase parcial por falta de verificación remota y Fase 8 iniciada.
## Avance verificado - Fase 8 (2026-08-24)

Portal y exportaciones revisados; inyección de fórmulas corregida y validada. Fase parcial por ausencia de verificación remota; Fase 9 iniciada.
## Fase 9 ejecutada

- Implementada cola efímera por empleado, permiso, RLS, RPC de creación/lectura/confirmación y almacenamiento privado de audio.
- Integrada entrega posterior al ACK de jornada, cifrado local, caché privada, pantalla de recepción y reintento idempotente con WorkManager.
- Añadidas pruebas estructurales SQL y unitarias Android.
- Pendiente externo: aplicar `0049` y validar dos terminales reales, offline y audio en STAGING.
- Validación local: Android unit `PASS`; web build `PASS`; Edge dependency pinning `PASS`.

## Fase 10 en curso

- Auditar referencias de entorno, secretos, logs, sesiones, navegación, permisos y RLS.
- Endurecer configuración local para impedir asociación accidental con producción.
- Ejecutar batería final y verificar identidad, referencias, firma y SHA-256 del APK.
## Fase 10 ejecutada

- Confirmado enlace temporal STAGING y corregido `supabase/config.toml` para evitar asociación accidental con producción.
- Reducida telemetría de Edge/web/Android a metadatos no sensibles y errores públicos genéricos.
- Añadida exclusión de logs y respaldos locales con datos operativos.
- Verificadas guardas de navegación para el nuevo permiso de mensajes.
- Validación de fase: Android unit `PASS`; web build `PASS`; Edge dependency pinning `PASS`.
- Pendiente externo: ejecución remota de migraciones/RLS y pruebas manuales de sesiones/dispositivos.

## Cierre técnico en ejecución

- Batería Android final: unit, lint y assemble.
- Batería web final: instalación congelada, pruebas funcionales de políticas y build.
- Inspección del APK: paquete, referencias de entorno, firma y SHA-256.
- Generación de reportes finales y lista de bloqueos reales.
## Estado final del plan

| Paso | Estado |
|---|---|
| Fases locales 1 a 10 | Completadas hasta el máximo verificable sin servicios externos |
| Corrección de compilación | Completada |
| Pruebas unitarias Android | Completada |
| Lint Android | Completada, 0 errores |
| APK debug STAGING | Generado y verificado |
| Pruebas/build web | Completadas |
| Sintaxis y dependencias Edge | Completadas |
| Migraciones/RLS STAGING | Bloqueadas externamente |
| Dispositivos físicos | Bloqueados externamente |
| Firma release | Bloqueada externamente |

## Próxima ejecución autorizada necesaria

1. Ejecutar la prueba SQL 0048 portable y el resto de pgTAP en STAGING.
2. Preparar respaldo y acceso STAGING.
3. Aplicar 0046 a 0049 y ejecutar pgTAP/RLS.
4. Desplegar las seis Edge Functions verificadas.
5. Ejecutar el checklist manual con dos terminales.
6. Corregir cualquier hallazgo y repetir batería final.
7. Preparar firma release solo después de aprobación de STAGING.

La producción [PRODUCTION_PROJECT_REF] queda explícitamente fuera de este plan.


## FASE P0 - Estado de ejecucion (2026-08-24)

1. Contratos SQL/RLS/RPC y pgTAP: implementados localmente; ejecucion pgTAP bloqueada por Docker Desktop.
2. Terminal GENERAL/DEPARTMENTS y mensajes Edge: implementados.
3. Android Room, sincronizacion, inbox cifrado y autorizacion inmediata: implementados y compilados.
4. Licencias directas y NO PAGAR Android: implementados y probados.
5. Portal P0, rutas, permisos y nomina: implementados; tests y build PASS.
6. APK y controles de referencia/firma: verificados.
7. Operaciones remotas, commits, despliegues e instalacion en telefonos: no ejecutados por alcance.
