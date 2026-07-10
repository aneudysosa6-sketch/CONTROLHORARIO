# MODULE_DEPENDENCIES.md

# Dependencias entre módulos

## Empleados

Base para:

- Asistencia.
- Nómina.
- Vacaciones.
- Permisos.
- Huellas.

## Asistencia

Depende de:

- Empleados.
- Huellas.

## Nómina

Depende de:

- Empleados.
- Asistencia.
- Configuración.

## Vacaciones

Depende de:

- Empleados.
- Supervisores.
- Permisos.

## Comunicación interna

Depende de eventos de todos los módulos.
