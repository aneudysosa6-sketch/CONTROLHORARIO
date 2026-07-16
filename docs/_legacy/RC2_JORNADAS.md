# RC2 — Motor completo de jornadas

## Estado

Fundación integral implementada y preparada para despliegue de prueba. RC2 no se considera terminada hasta validar físicamente PIN → huella 2Connect → acción → Room/outbox → Supabase → Dashboard → PIN.

## Contrato

`contracts/attendance-rc2-v1.json` es el contrato canónico v1. Kotlin y TypeScript implementan sus transiciones y las verifican con casos equivalentes. Supabase es la autoridad remota; Android ejecuta el mismo contrato offline.

## Persistencia

- Supabase: `jornadas`, `jornada_eventos`, `jornada_incidencias`, `jornada_conflictos`, `jornada_auditoria`.
- Room v29: `journeys`, `journey_outbox`, `journey_conflicts`.
- `attendance_records` permanece como log legado compatible con nómina. Durante RC2, la transacción local escribe tanto el modelo consolidado como el evento legado. No se modificó el motor de nómina.

## Sincronización

`attendance-sync` autentica el dispositivo, procesa hasta 100 operaciones, llama la RPC atómica, devuelve ACK/duplicado/rechazo/conflicto y nunca expone credenciales. WorkManager conserva operaciones pendientes, aplica backoff y registra conflictos o rechazos definitivos como eventos internos.

## Fecha y zona horaria

El servidor aplica cierres por `companies.timezone`. Android conserva el instante UTC y una fecha laboral local para operación offline. Si la zona empresarial todavía no está descargada, el servidor valida/reconcilia la fecha; un desacuerdo debe tratarse como conflicto y no por last-write-wins.

## Cierre e incidencias

`cerrar_jornadas_vencidas()` calcula el día anterior por zona empresarial y ejecuta un cierre idempotente. Las jornadas incompletas quedan pendientes con severidad crítica, alta o media. La tardanza se evalúa únicamente cuando existe hora esperada; 14 minutos no genera incidencia y 15 minutos sí. No se inventan horarios faltantes.

## Seguridad

Todas las tablas tienen RLS. Administrador usa permisos `jornadas.*`; supervisor solo ve empleados asignados; el dispositivo no consulta tablas directamente. Las mutaciones del kiosco pasan por la Edge Function y la RPC `service_role` solo vive en servidor.

## Pendientes físicos

- USB attach/detach y permiso real 2Connect.
- PIN y huella reales con cada transición.
- Acción offline, reinicio, recuperación de red y ACK.
- Revocación física del dispositivo.
- Confirmación visual del Dashboard y retorno automático al PIN.
