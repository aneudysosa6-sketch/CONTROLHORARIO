# ATTENDANCE_DASHBOARD.md

# Dashboard Asistencias

## Estado

Implementado dentro de Centro de Incidencias.

## Funciones

- Buscar jornadas por fecha.
- Ver conteo de todos los inicios.
- Abrir historial de inicios.
- Ver conteo de pausas.
- Abrir historial de pausas.
- Ver jornadas sin finalizar.
- Abrir historial de jornadas sin finalizar.
- Finalizar manualmente la jornada de un empleado.

## Nómina

La finalización manual inserta un registro FIN_JORNADA en attendance_records. Ese registro queda disponible para el motor de Nómina.

## Permiso

Se agregó PermissionCatalog.ATTENDANCE_DASHBOARD como Dashboard Asistencias.

## Huella y Perfil

El registro de huella se accede desde Agregar empleado. La ficha de empleado admite foto de perfil mediante URI local.
