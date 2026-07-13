# RC3 — Módulo de Supervisor

## Arquitectura

RC3 reutiliza `profiles`, `roles`, `perfil_sucursales` y `perfil_departamentos`. La migración `0009_rc3_supervisor_scoped_operations.sql` valida que supervisor, sucursal, departamento y empleado pertenezcan al mismo tenant y que cada departamento esté dentro de una sucursal autorizada.

`supervisor_puede_ver_empleado()` es la regla canónica de alcance. Las pantallas consumen RPC que entregan exclusivamente datos operativos. El rol supervisor queda excluido de la lectura directa de `empleados`, evitando exponer salario, `pin_hash`, biometría o datos financieros.

## Permisos y operaciones

El rol supervisor recibe por defecto solo dashboard y lecturas asignadas. Corrección, aprobación, resolución, ADMIN-OFF/ON y edición de horarios requieren concesión explícita en `perfil_permisos`.

- Dashboard por fecha local de `companies.timezone`.
- Equipo, jornadas, pendientes, incidencias, horarios y auditoría.
- Corrección y registro manual con secuencia temporal validada y motivo obligatorio.
- Aprobación, rechazo y devolución con snapshots y auditoría.
- ADMIN-OFF/ON modifica únicamente `jornada_habilitada`, genera incidencia/notificación y se propaga mediante `employee-sync`.
- Horarios versionados por vigencia, no retroactivos desde la UI supervisor.

## Android

Room v30 conserva el horario operativo descargado por `employee-sync`. El kiosco sigue validando `jornadaEnabled` antes de solicitar huella. El panel supervisor local heredado ya no desactiva laboralmente al empleado cuando usa ADMIN-OFF/ON. PIN, BiometricPrompt, 2Connect, kiosco y nómina no cambian.

## Estado

Preparado para despliegue de prueba. RC3 no se considera terminado hasta aplicar la migración en un entorno aislado, asignar alcances reales y completar pruebas manuales Web/Android/RLS con usuarios supervisor y administrador.
