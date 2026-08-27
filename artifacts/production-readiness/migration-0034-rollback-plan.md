# Plan de rollback compensatorio — migración 0034

Estado: documento operativo; no ejecutado

## Principio

0034 sólo reemplaza el cuerpo de `public.auditar_asignacion_supervisor()`; no
modifica tablas, datos, RLS, policies, triggers ni firmas. No existe ningún
backfill que deshacer.

La definición anterior no es una versión funcional a la que se pueda volver:
reintroduce SQLSTATE `42703` en las escrituras de alcance. Por ello la
estrategia obligatoria es *roll-forward* mediante otra migración transaccional
que conserve ramas explícitas y columnas reales.

## Acciones prohibidas

- No restaurar literalmente la definición de 0009/0033 con un `CASE` que
  mezcle `sucursal_id` y `departamento_id`.
- No editar 0033 ni 0034 después de aplicarlas.
- No deshabilitar o eliminar `perfil_sucursales_audit_rc3` ni
  `perfil_departamentos_audit_rc3` para ocultar el fallo.
- No desactivar RLS, modificar policies ni conceder `GRANT ALL`.
- No ampliar DML directo de `anon` o `authenticated`.
- No borrar asignaciones o auditorías creadas correctamente después de 0034.
- No eliminar identidades Auth por email o nombre; usar sólo UUID y evidencia
  inequívoca de la operación y su `requestId`.
- No reintentar una creación con otra clave mientras exista una compensación
  Auth incierta para el mismo intento lógico.

## Preimagen antes de aplicar 0034

Conservar mediante diagnósticos `SELECT`:

1. `pg_get_functiondef` y ACL de
   `public.auditar_asignacion_supervisor()`;
2. nombres, eventos, estado y función asociada de ambos triggers de auditoría;
3. columnas, tipos y orden de `perfil_sucursales` y
   `perfil_departamentos`;
4. RLS y fingerprints de policies de ambas tablas;
5. ACL de las tablas y RPC de 0033;
6. conteos de asignaciones y `supervisor_auditoria`;
7. versión desplegada de Edge/Web y solicitudes de provisión pendientes.

La preimagen documenta el incidente, pero no autoriza restaurar la función
defectuosa.

## Comportamiento transaccional

Si 0034 falla durante su aplicación, `BEGIN`/`COMMIT` impide confirmar una
definición parcial. Verificar el estado con el postflight antes de admitir
nuevas altas o ediciones SUPERVISOR.

Si 0034 se aplicó y aparece otra regresión:

1. detener temporalmente nuevas mutaciones de alcance desde Web/Edge;
2. mantener los resolvers fail-closed y RLS activos;
3. capturar función, triggers, requestId, SQLSTATE y datos antes/después;
4. distinguir un fallo de auditoría de una validación legítima de 0033;
5. preparar 0035 u otra migración nueva, nunca reescribir historia.

## Roll-forward compensatorio

La migración compensatoria debe elegir una de estas formas seguras:

### Opción A — función compartida corregida

Ejecutar `CREATE OR REPLACE FUNCTION` manteniendo:

- `SECURITY DEFINER` y `search_path = ''`;
- rama de `TG_TABLE_NAME = 'perfil_sucursales'` antes de cualquier acceso a
  `sucursal_id`;
- rama de `TG_TABLE_NAME = 'perfil_departamentos'` antes de cualquier acceso a
  `departamento_id`;
- ramas explícitas de `TG_OP` que usen `NEW` para `INSERT`/`UPDATE` y `OLD`
  para `DELETE`;
- rechazo fail-closed de tablas u operaciones desconocidas;
- auditoría y ACL equivalentes.

### Opción B — funciones separadas por tabla

Si la función compartida siguiera siendo fuente de riesgo, crear una función
trigger para `perfil_sucursales` y otra para `perfil_departamentos`, cada una
con su único tipo de columna. En la misma transacción, reemplazar los bindings
de los dos triggers sin cambiar sus eventos `AFTER INSERT OR UPDATE OR DELETE`.
Revocar ejecución directa de las nuevas funciones a `public`, `anon` y
`authenticated`.

Esta separación es una corrección hacia adelante, no una razón para suspender
la auditoría entre migraciones.

## Datos y auditorías

0034 no requiere compensación de datos. Las auditorías escritas correctamente
tras su aplicación son evidencia operativa y deben preservarse.

Si una operación posterior falla:

- confirmar si PostgreSQL hizo rollback completo;
- para creación, conciliar Auth con profile mediante `requestId`, UUID Auth e
  `idempotency_key`;
- para actualización, buscar el `operation_id` exacto antes de restaurar Auth;
- no insertar manualmente asignaciones para simular éxito;
- no borrar auditorías de idempotencia para permitir un reintento.

## Validación posterior a la compensación

- La definición vigente no contiene una misma expresión `CASE` que mezcle
  campos de ambas tablas.
- Los dos triggers existen, están habilitados y apuntan a la función esperada.
- `perfil_sucursales` usa sólo `sucursal_id` y `perfil_departamentos` sólo
  `departamento_id` para identificar la entidad auditada.
- INSERT, UPDATE y DELETE reales en ambos fixtures completan sin `42703`.
- `antes` y `despues` respetan la semántica de cada `TG_OP`.
- RLS y fingerprints de policies no cambian.
- No se ampliaron privilegios para `anon`, `authenticated` o `service_role`.
- Los RPC atómicos de creación, actualización, estado e idempotencia conservan
  firmas y grants.
- No quedan perfiles, asignaciones o identidades Auth parciales.

## Criterio de cierre

La compensación se considera terminada sólo cuando las seis combinaciones de
tabla/operación auditan correctamente, no reaparece `42703`, no se pierde
trazabilidad y no se amplía el alcance de ningún usuario. Si no puede
demostrarse, mantener contenidas las mutaciones SUPERVISOR y continuar con otro
roll-forward seguro.
