# Plan de migraciones Supabase

No aplicar una migración hasta probar desde cero `db reset`, RLS con varios tenants y rollback lógico en una rama aislada.

| Migración | Contenido | Dependencias / prueba mínima | Rollback |
|---|---|---|---|
| 0001 ejecutada | companies, branches, departments, positions, profiles, roles; helpers, triggers, RLS, índices | Auth; crear dos tenants y comprobar aislamiento | No revertir en producción; migración compensatoria |
| 0002 pendiente | empleados, permisos, asignaciones y alcances; helpers y RLS | 0001; propio/D/S/E, denegación y self-escalation | Drop solo en local; compensatoria si se aplicara |
| 0003 organización ampliada | configuración, feriados, calendarios; horarios, detalles, turnos, rotaciones y asignaciones | 0002; turno nocturno, rotación y excepción | Desactivar datos; conservar históricos |
| 0004 asistencia | dispositivos/ubicaciones, eventos append-only, jornadas, pausas, incidencias, correcciones y aprobaciones | 0003; idempotencia, offline duplicado, cruce medianoche | No borrar eventos; deshabilitar funciones |
| 0005 solicitudes | tipos, solicitudes, aprobación multinivel, vacaciones, permisos laborales, licencias, incapacidades y horas extra | 0004/empleados; aprobación/rechazo/cancelación | Estados compensatorios |
| 0006 nómina | períodos, conceptos, reglas, novedades, detalles, deducciones, ingresos, horas extra, plantillas, archivos e historial | asistencia/solicitudes; cálculo reproducible y doble aprobación | Nueva versión/reverso, nunca delete |
| 0007 archivos y Storage | categorías, metadatos, relaciones; políticas `storage.objects` y configuración declarativa de buckets | módulos previos; MIME/tamaño/tenant | Revocar acceso; retención antes de borrar |
| 0008 notificaciones/Realtime | notificaciones, preferencias, push y publicación Realtime mínima | eventos previos; filtro tenant y carga | Quitar publicación, conservar datos |
| 0009 auditoría/seguridad | auditoría particionada, cambios sensibles, eventos, historial permisos, sesiones/intentos | todos; before/after filtrado | Inmutable; corregir con eventos nuevos |
| 0010 sincronización | dispositivos sync, cola, conflictos, cursores, RPC incremental | asistencia y auditoría; reintento/idempotencia/conflicto | Deshabilitar sync, preservar outbox |

## Contenido obligatorio por migración

Cada archivo incluye tablas/FKs compuestas, CHECK, índices de tenant, trigger `updated_at`, RLS, grants mínimos, funciones con `search_path=''`, comentarios y seed idempotente solo para catálogos. La prueba debe cubrir `anon`, usuario inactivo, propio, departamento, sucursal, empresa y otro tenant.

## Orden revisado

Se incorporan configuración/feriados a `0003` antes de horarios; asistencia precede solicitudes y nómina; Storage sigue a módulos que generan archivos; auditoría estructural se completa en `0009`, aunque cada migración anterior debe emitir auditoría mínima desde el inicio mediante una interfaz estable. Sincronización completa queda al final, pero UUID/idempotencia deben existir desde `0004`.

## Pruebas y entrega

1. `supabase db reset` local.
2. Seed.
3. Tests pgTAP/RLS con dos empresas.
4. `supabase db diff` vacío respecto al esquema esperado.
5. Revisión de locks, índices y plan de backfill.
6. Backup y ventana antes de `db push`.

No usar rollback destructivo sobre históricos; publicar una migración compensatoria.
