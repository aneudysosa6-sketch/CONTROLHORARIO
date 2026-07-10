# Permisos de Empleados

## Objetivo

Centraliza las solicitudes enviadas desde el Portal del Empleado.

## Flujo

- El empleado envia permisos de llegada tarde, medico, licencia medica o motivo personal.
- La administracion abre Permisos Empleados desde el panel principal.
- Cada empleado se muestra como un bloque desplegable con sus permisos.
- Si el permiso tiene archivo o foto, se puede abrir con Ver archivo.
- Las solicitudes pendientes se pueden aprobar o rechazar.
- Al rechazar, el motivo es obligatorio.

## Licencia medica

Cuando una licencia medica se aprueba, se capturan:

- Fecha de inicio.
- Fecha de fin.
- Porcentaje a pagar.

El sistema calcula el pago diario:

```text
valor diario = sueldo quincenal / 15
pago diario licencia = valor diario * porcentaje / 100
```

Luego genera un registro por cada dia de la licencia para que la nomina tome el monto diario sin afectar el flujo de ganancias diarias.
