# Plan de rollback de migración 0036

## Principio

El full-set directo de `service_role` es el estado inseguro que se está eliminando. No debe restaurarse como rollback. Tampoco debe restaurarse DML directo sobre `perfil_sucursales` o `perfil_departamentos`.

## Fallo durante la migración

0036 es una única transacción. Si falla un `REVOKE`, un `GRANT` o cualquiera de las validaciones fail-closed, PostgreSQL revierte automáticamente todos los cambios de 0036. En ese caso:

1. detener la promoción;
2. conservar el error completo y su `DETAIL`;
3. diagnosticar la ruta residual (`PUBLIC`, herencia, ownership, otro grantor o dependencia);
4. preparar una corrección nueva y revisada;
5. no usar `CASCADE` ni ampliar el alcance sin aprobación específica.

## Incidente detectado después del commit

No editar ni volver a numerar una migración ya aplicada. Preparar una migración compensatoria posterior, por ejemplo 0037, después de identificar el privilegio o contrato exacto que falta.

- Si falta uno de los privilegios permitidos por la matriz, volver a conceder sólo ese privilegio y sólo en la tabla correspondiente.
- Si falla una RPC de alcance, corregir su contrato `SECURITY DEFINER`, su ACL `EXECUTE` o los privilegios mínimos del owner existente; no conceder DML directo de alcance a `service_role`. Un cambio de ownership queda fuera de 0036 y de este rollback, y requeriría una remediación separada expresamente aprobada.
- Si una Edge Function desplegada requiere un privilegio fuera de la matriz, detener la promoción y corregir la implementación o revisar explícitamente el modelo de seguridad antes de cualquier grant.
- Si cambió RLS o una policy, investigar otra migración del lote; 0036 no contiene sentencias que los modifiquen.

## Privilegios máximos admisibles en una compensación

| Tabla | Lista máxima permitida |
|---|---|
| `profiles` | `SELECT` |
| `roles` | `SELECT` |
| `empleados` | `SELECT`, `INSERT`, `UPDATE` |
| `perfil_sucursales` | ninguno |
| `perfil_departamentos` | ninguno |

No restaurar `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER`, `MAINTAIN` ni `WITH GRANT OPTION` en ninguna de las cinco tablas.

## Verificación posterior

Después de cualquier corrección compensatoria:

1. ejecutar completo `migration-0036-postflight.sql`;
2. repetir los smoke tests de staging;
3. comparar otra vez snapshots de RLS y policies;
4. exigir todos los booleanos globales en `true` antes de reanudar la promoción.

0036 no toca datos, por lo que no existe rollback de datos asociado.
