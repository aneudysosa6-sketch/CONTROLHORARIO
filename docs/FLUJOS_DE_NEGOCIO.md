# Flujos de negocio

Todos los pasos sensibles producen auditoría y validan tenant, permiso y alcance en servidor.

1. **Crear empresa:** `super_admin` llama Edge Function; crea company, configuración, sucursal, roles/seed y administrador invitado en una transacción compensable.
2. **Primer administrador:** Auth invita; backend crea profile con rol empresarial y empleado opcional; nunca metadata cliente.
3. **Crear empleado:** RRHH crea expediente sin perfil, asignación inicial y salario histórico mediante RPC.
4. **Crear usuario para empleado:** `create-company-user`; valida empleado sin perfil, crea/invita Auth, profile no privilegiado y enlace único.
5. **Asignar rol/permisos:** administrador modifica a terceros; excepción y alcance quedan en historial.
6. **Asignar horario:** crea `empleado_horarios` con vigencia; no sobrescribe el anterior.
7. **Entrada por PIN:** kiosco envía código+PIN a `verify-employee-pin`; rate limit; token de desafío corto; `register-attendance` registra evento.
8. **Entrada biométrica:** Android usa BiometricPrompt/dispositivo autorizado; envía attestation/desafío, nunca imagen/plantilla.
9. **Asistencia offline:** Android valida política local permitida, genera UUID/idempotency key y guarda evento/outbox.
10. **Regreso de Internet:** Worker envía lote; servidor valida tenant, secuencia, dispositivo y duplicados; devuelve ACK/conflicto.
11. **Corregir asistencia:** usuario autorizado crea solicitud de corrección; aprobación genera ajuste, evento original permanece.
12. **Solicitar vacaciones:** empleado crea solicitud y adjuntos privados; motor calcula disponibilidad sin comprometerla dos veces.
13. **Aprobar solicitud:** se resuelve nivel actual, suplencias y alcance; decisión append-only; al finalizar actualiza calendario/novedad.
14. **Procesar nómina:** Edge Function bloquea período, toma snapshots, asistencia, solicitudes y conceptos; crea versión y totales.
15. **Descargar nómina:** permiso y alcance; trabajo asíncrono genera archivo privado con URL firmada corta y auditoría.
16. **Desactivar empleado:** RPC cierra asignaciones, bloquea portal/dispositivos y marca empleado; no borra históricos.
17. **Revocar portal:** profile pasa a inactivo, sesiones se revocan y se registra evento; expediente permanece.
18. **Cambiar empresa/sucursal:** empresa no se cambia en sitio. Se cierra acceso/asignación anterior y se crea una pertenencia nueva controlada; sucursal usa vigencias.
19. **Resolver conflicto:** se compara versión/base, se conserva payload original y resolución; asistencia nunca se sobrescribe.

## Estados y concurrencia

Solicitudes: borrador → enviada → en_aprobación → aprobada/rechazada/cancelada. Nómina: borrador → procesando → revisada → aprobada → exportada/cerrada. Transiciones se validan con RPC, versión optimista y `SELECT ... FOR UPDATE` cuando exista riesgo de doble aprobación.

## Errores

Errores de negocio usan códigos estables (`PERMISSION_DENIED`, `TENANT_MISMATCH`, `DUPLICATE_EVENT`, `VERSION_CONFLICT`, `DEVICE_REVOKED`). El cliente no interpreta textos para decidir lógica.
