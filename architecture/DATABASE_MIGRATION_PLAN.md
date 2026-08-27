# Database Migration Plan

1. `0001_FINAL`: extensiones, esquemas, organización, profiles, helpers y RLS base.
2. `0002_FINAL`: empleados, catálogo de permisos, asignaciones, alcances y RLS granular.
3. `0003_FINAL`: auditoría, revocación de DML de profiles, provisioning y bootstrap.
4. `seed.sql`: catálogos versionados; nunca usuarios Auth ni secretos.

Próximas migraciones, solo tras especificación aprobada: horarios; asistencia; solicitudes; nómina; auditoría general; dispositivos/sync; Storage; Realtime. Aplicar siempre en local, pgTAP, staging y producción con backup. Nunca editar una versión aplicada: emitir migración compensatoria.
