# Auditoría P1 — Integridad de Jornadas, Biometría y Offline

Fecha: 2026-07-16  
Alcance: Android local, contrato RC2 y migración oficial `0008_rc2_attendance_engine.sql`. No se modificaron el SDK 2Connect, Web, nómina, préstamos, reportes ni producción.

## Resultado

**FAIL — bloque P1 no cerrado.** El flujo base de registro y sincronización existe, pero hay cuatro incumplimientos verificables frente a la especificación oficial.

La ejecución local de `scripts/verify_jornadas.ps1` confirmó los cuatro hallazgos. Las cinco pruebas de `JourneyStateEngineTest` finalizaron correctamente (0 fallos, 0 errores). El script resuelve automáticamente el JDK local de Android Studio cuando `JAVA_HOME` no está configurado.

## Comprobaciones aprobadas

| Área | Evidencia | Estado |
|---|---|---|
| PIN + lector 2Connect | `EmployeePunchScreen` identifica con PIN, captura con `TwoConnectFingerprintManager` y compara la plantilla antes de navegar. | PASS |
| No solo PIN en flujo heredado | `EmployeePunchViewModel.registerAttendance` rechaza la acción si `biometricVerified` es falso. | PASS |
| Estados de jornada | `JourneyStateEngine` restringe INICIAR, PAUSAR, REANUDAR y FINALIZAR según el estado. | PASS |
| Múltiples pausas | El motor acumula `breakMinutes` y reinicia el tramo trabajado tras cada reanudación. | PASS |
| Pausas no trabajadas | Los minutos trabajados se suman solo estando `EN_CURSO`; los de pausa se acumulan aparte. | PASS |
| Horas extra | `LaborCalculator` solo produce extras cuando `workedMinutes > scheduledMinutes`. | PASS |
| Persistencia offline | `JourneyDao.recordAction` es transaccional: actualiza la jornada y crea una operación de outbox con UUID. | PASS |
| Idempotencia y conflictos | El contrato usa UUID; la tabla remota tiene `unique(empresa_id,idempotency_key)` y el worker trata `duplicate` y `conflict`. | PASS |
| Reintentos y recuperación | WorkManager requiere red, programa backoff exponencial y el worker usa `Result.retry()` ante fallos transitorios. | PASS |
| Auditoría de eventos | La RPC inserta una fila en `jornada_auditoria` para cada evento remoto. | PASS |
| SDK 2Connect | Solo se verificó su uso mediante el gestor existente; no se modificó código del SDK en este bloque. | PASS |

## Incumplimientos y riesgos

1. **La prueba biométrica no llega a `JourneyViewModel.record`.** La ruta de interfaz normal solo abre acciones después de la huella, pero la acción no exige un comprobante de esa verificación. Una navegación directa hacia `EMPLOYEE_ASSISTANCE/{employeeId}` puede construir la pantalla de jornada sin segundo factor. Esto no permite certificar “nunca solo PIN”.
2. **Sucursal inicial/final ausente.** `journeys`, `jornadas` y `jornada_eventos` no conservan `branch_id`/`sucursal_id` por acción. Por tanto, no puede probarse ni auditarse que una jornada se inició en una sucursal y finalizó en otra.
3. **Sin cálculo inmediato de ganancias.** El cálculo laboral existe como motor separado, pero finalizar en `JourneyViewModel`/`JourneyDao` solo persiste y encola; no invoca cálculo ni publica ganancias.
4. **Sin límite ejecutable de edición de 30 días.** La migración tiene resolución/auditoría de pendientes, pero no una operación de corrección que valide antigüedad de 30 días. La auditoría tampoco puede demostrar modificaciones inexistentes.

## Prueba reproducible

Ejecutar desde la raíz:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify_jornadas.ps1
```

El script realiza comprobaciones estáticas del flujo, contrato, outbox, sincronización y migración; después ejecuta `JourneyStateEngineTest`. Devuelve `FAIL` mientras alguno de los incumplimientos anteriores siga presente. No conecta ni modifica Supabase remoto.

## Correcciones aplicadas

No se aplicaron correcciones funcionales. Resolver los cuatro hallazgos requeriría cambios de producto/modelo o de seguridad de jornada, y la instrucción de este bloque prohíbe implementar funcionalidades nuevas.

## Próximo paso recomendado

Autorizar un bloque de implementación de Jornadas que defina una credencial efímera de PIN+huella vinculada a la acción, capture sucursal por evento, conecte el cálculo de ganancias de cierre y establezca una RPC de corrección con límite de 30 días y auditoría obligatoria.

## Implementación P1 (2026-07-16)

- `JourneyBiometricGate` emite una autorización efímera de 90 segundos, de un uso y ligada al empleado/dispositivo. `JourneyViewModel` la consume antes de persistir una acción; la navegación directa queda rechazada.
- La Edge Function valida firma ECDSA, vencimiento y vínculo empleado/dispositivo/acción antes de invocar la RPC. PIN y plantilla biométrica no viajan en el payload ni se registran en logs.
- La migración `0014_p1_journeys_biometrics_branches.sql` persiste sucursal inicial, final y por evento; admite sucursales distintas al inicio y cierre.
- `corregir_jornada_30_dias` aplica la ventana desde la fecha y zona horaria del servidor y registra actor, antes, después, motivo y fecha en auditoría.
- `jornada_ganancias` se calcula al finalizar de forma idempotente por jornada. Si falta configuración salarial, queda en `REVISION_PENDIENTE` sin generar importes.

## Validación técnica local — PASS (2026-07-16)

La cadena oficial de migraciones `0001` a `0014` finalizó correctamente en Supabase local. El contrato `supabase/tests/jornadas_p1_contracts.sql` pasó 10 de 10 pruebas. Las pruebas Android de transiciones y comprobante biométrico también finalizaron en PASS.

Pendiente exclusivamente de hardware real: captura/comparación con lector 2Connect, verificación ECDSA con un dispositivo físicamente enrolado y cierre de jornada desde una segunda sucursal/dispositivo real.
