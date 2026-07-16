# Sincronización Android, Room y Supabase

## Contrato

Supabase es central; Room es caché/offline. Cada registro sincronizable tendrá `remote_id UUID`, `version`, `server_updated_at`, `device_updated_at`, `last_synced_at`, `sync_status` e idempotency key. Los IDs `Int` locales actuales se mantienen como claves internas durante transición.

## Mapeo Room actual

| Entidad Room | Tabla objetivo | Transformación | Dirección |
|---|---|---|---|
| Employee | empleados + asignaciones/historial salarial | Int local→UUID; `pin` no se sube; sueldo→historial | bidireccional controlada |
| BranchEntity | branches | campos ciudad/provincia a dirección estructurada futura | descarga/admin |
| DepartmentEntity | departments | manager textual→perfil/empleado FK | descarga/admin |
| CompanySettingsEntity | configuracion_empresa | singleton local→tenant | descarga |
| WorkScheduleTemplate | horarios + horario_detalles | días booleanos→filas; horas→time | bidireccional admin |
| LaborCalendarDayEntity | feriados/calendarios_laborales | String→date; tipo catálogo | descarga |
| AttendanceEntity | eventos_asistencia | fecha/hora→timestamptz; UUID; método/origen | subida append-only |
| PendingAttendanceReviewEntity | incidencias/correcciones | snapshot→incidencia y decisión | bidireccional |
| EmployeePermissionRequestEntity | solicitudes + detalle | tipo/estado catálogo; adjunto→Storage | bidireccional |
| VacationEntity | solicitudes + vacaciones | fechas/date; aprobación separada | bidireccional |
| MedicalLicenseDailyPaymentEntity | licencias/novedades_nomina | detalle derivado versionado | descarga |
| PayrollSettingsEntity | reglas_nomina | `Double`→numeric; singleton→reglas | descarga |
| EmployeePayrollSettingsEntity | reglas/novedades/empleado | descomponer columnas por concepto | descarga restringida |
| PayrollHistoryEntity | detalles_nomina | snapshot inmutable | descarga propia/autorizada |
| LoanEntity | solicitudes financieras/deducciones | módulo futuro específico | bidireccional futura |
| EmployeeDocumentEntity | archivos/relaciones_archivo | URI local→upload privado + hash | bidireccional |
| AppEventEntity | notificaciones | leído local sincronizable | bidireccional |
| AppUserEntity | profiles/Auth | NO subir password/CSV; migración de identidad | solo transición |
| Supervisor* | roles, alcances, horarios, auditoría | desnormalizar nombres→UUID/FK | descarga/transición |
| EmployeeBiometricEntity | dispositivo autorizado | NO subir templateBase64; solo estado/attestation | nunca plantilla |
Los modelos y colas exclusivos de entrega externa fueron eliminados. Nunca estuvieron registrados en `AppDatabase` ni se sincronizaron con Supabase.

## Outbox y Worker

Room incorpora `sync_outbox` con UUID, tipo, payload versionado, hash, intentos, `next_attempt_at` y estado. WorkManager agrupa por tenant/dispositivo, envía a Edge/RPC, marca ACK solo con respuesta durable y usa backoff exponencial con jitter. Un 4xx de validación pasa a conflicto/manual; 5xx o red reintenta.

## Conflictos

- Eventos de asistencia: el servidor conserva ambos si las idempotency keys difieren; duplicados exactos reciben el mismo resultado. Nunca last-write-wins.
- Catálogos: servidor gana; el dispositivo recarga.
- Datos personales editables: versión optimista; conflicto requiere merge/campo o decisión autorizada.
- Horarios: asignación aprobada del servidor gana; captura offline conserva el snapshot usado.
- Estado leído de notificación: máximo timestamp.
- Correcciones y nómina: servidor siempre; Android solo solicita.

## Sincronización incremental

Cursor por tabla/empresa basado en `(server_updated_at,id)`, no solo reloj del dispositivo. Las bajas lógicas se descargan como tombstones. El dispositivo nunca confía en su hora para orden jurídico; conserva `device_recorded_at` como evidencia y recibe `server_received_at`.

## Seguridad local

Room no debe guardar contraseñas, tokens administrativos, `service_role`, PIN plano, plantilla biométrica, cuentas bancarias completas ni nómina de otros empleados. Tokens de sesión usan almacenamiento cifrado del sistema. La retirada de campos legados exige migración Room y rotación de credenciales, no solo dejar de leerlos.
