# Mapa modular, navegación y acciones

## Menú final

1. **Inicio:** dashboard por rol, actividad, alertas, pendientes, calendario e indicadores.
2. **Mi portal:** perfil, horario, jornadas, ponches, solicitudes, licencias, vacaciones, documentos, nómina, recibos, notificaciones y dispositivos.
3. **Personal:** empleados, expedientes, contratos, organización, históricos, documentos, altas/bajas.
4. **Tiempo:** asistencia, jornadas, ponches, pausas, horarios, turnos, rotaciones, correcciones, incidencias, kiosco, dispositivos y sync.
5. **Ausencias:** solicitudes, vacaciones, licencias, permisos laborales, incapacidades, horas extra y aprobaciones.
6. **Nómina:** períodos, plantillas, conceptos, reglas, novedades, pre-nómina, cálculo, validación, aprobación, resultados, recibos, exportación e historial.
7. **Reportes:** tiempo, ausencias, nómina, personal, auditoría, seguridad y sincronización.
8. **Administración:** usuarios, roles, permisos, alcances, organización, feriados y configuraciones.
9. **Sistema:** auditoría, sesiones, dispositivos, Storage, Realtime, Edge, errores, respaldos, migraciones y versiones.

No se muestra una entrada sin ruta implementada y permiso efectivo. Kiosco permanece separado del ERP administrativo.

## Pantallas base por dominio

Cada dominio usa: lista con filtros → detalle con pestañas → crear/editar → historial/auditoría. Inicio tiene variantes personal, supervisor, RRHH, nómina y administrador. Personal usa ficha 360°. Tiempo mantiene evento/jornada/horario/corrección/incidencia como pantallas conceptualmente distintas. Nómina usa pasos período→pre-nómina→validación→aprobación→resultado/exportación.

## Acciones estandarizadas

`Nuevo`, `Guardar`, `Guardar y continuar`, `Editar`, `Duplicar`, `Activar`, `Desactivar`, `Archivar`, `Restaurar`, `Ver detalle`, `Aprobar`, `Rechazar`, `Corregir`, `Cancelar`, `Exportar`, `Descargar`, `Imprimir`, `Adjuntar`, `Asignar`, `Revocar`, `Reintentar`, `Sincronizar`, `Cerrar/Reabrir período`, `Procesar`, `Recalcular`.

Contrato común: permiso+alcance, estado de carga, idempotency key, éxito/error, confirmación crítica y auditoría. Histórico nunca usa Editar/Eliminar: usa Corregir/Revertir mediante registro nuevo.

## Mapa de funciones

| Función | Capa autorizada |
|---|---|
| Lecturas propias/listas RLS | cliente Supabase + RLS |
| Alta usuario/enlace empleado | Edge Function |
| PIN/registro/corrección asistencia | Edge/RPC |
| CRUD visual no sensible | servicio de dominio |
| Salario, rol, empresa, permisos | Edge/RPC auditada |
| Nómina/procesamiento/exportación | job Edge + PostgreSQL |
| Offline | Repository Android + Room + Worker |

## Arquitectura de código objetivo

Web: `app/`, `modules/{auth,dashboard,portal,employees,attendance,schedules,leave,payroll,reports,administration,system}`, `shared/` e `infrastructure/{supabase,storage,realtime,permissions}`.

Android: `core/`, `data/{local,remote,sync,repository}`, `domain/{model,usecase,validation}`, `feature/{auth,kiosk,biometric,attendance,schedule,portal,sync}` y `ui/`. Migración archivo por archivo con adaptadores; nunca movimiento masivo.
