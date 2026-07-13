# Notificaciones internas

## Decisión de alcance

CONTROLHORARIO no incluye Gmail, WhatsApp ni n8n. Las alertas y notificaciones son internas.

## Arquitectura actual

- `AppEventEntity` registra eventos internos de aplicación y sucursal.
- `SupervisorEventEntity` limita eventos a empleados y supervisores asignados.
- El Centro de Incidencias permite al administrador revisar y corregir según permisos.
- Los eventos nuevos usan el borde neón azul del sistema visual OSINET.
- Room conserva la operación offline; Supabase y RLS mantienen el aislamiento multiempresa donde aplica.

## Eventos admitidos

- tardanza;
- jornada no finalizada;
- almuerzo excedido;
- salida anticipada;
- jornada pendiente;
- empleado deshabilitado;
- dispositivo revocado;
- error de sincronización;
- conflicto de jornada;
- nómina pendiente de aprobación.

Cada evento puede incluir severidad, fecha, empleado, sucursal, departamento, jornada relacionada, tipo y minutos exactos cuando corresponda. El administrador ve el alcance permitido de su empresa; el supervisor solo sus empleados asignados; el empleado no administra notificaciones.

## Exclusiones

No se permiten clientes de mensajería, secretos, plantillas externas, colas de envío, reintentos de entrega ni endpoints externos.
