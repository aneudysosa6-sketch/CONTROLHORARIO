# 00_LEER_PRIMERO.md

## Objetivo del proyecto

CONTROL HORARIO IA es una app Android para control horario, ponche por PIN + huella 2Connect, empleados, jornada, incidencias, nomina, prestamos, permisos, vacaciones, reportes y administracion por roles.

## Reglas criticas

- No eliminar funcionalidades existentes.
- El ponche operativo debe mantenerse con PIN + huella.
- El modo kiosko debe ofrecer PIN y HUELLA como accesos visibles.
- La busqueda por nombre o PIN es solo interna; no cambia la logica de ponche.
- Toda pantalla visible debe tener destino real.
- Todo cambio debe compilar.

## Modulos principales

- Empleados.
- Asistencia y ponche.
- Modo kiosko.
- Huellas 2Connect.
- Nomina general.
- Centro de incidencias.
- Permisos de empleados.
- Prestamos.
- Vacaciones.
- Encargado de sucursal.
- Supervisores.
- Configuracion.
- Reportes.

## Continuidad

Antes de modificar, revisar:

- `docs/PROJECT_RULES.md`
- `docs/MODULES.md`
- `docs/DATABASE.md`
- `docs/CHANGELOG.md`
- `app/src/main/java/com/example/controlhorario/ui/navigation/AppNavigation.kt`
- `app/src/main/java/database/AppDatabase.kt`
