# Plan de pruebas — migración 0034

Estado: secuencia anterior funcional en staging; fresh DB y pgTAP locales aprobados
Entornos objetivo: staging para integración y base local efímera para fresh DB/pgTAP

## Objetivo

Demostrar mediante DML real que `public.auditar_asignacion_supervisor()` usa el
tipo de fila correcto en `perfil_sucursales` y `perfil_departamentos`, conserva
la auditoría y permite los flujos atómicos de 0033 sin volver a producir
SQLSTATE `42703`.

## Suite automatizada preparada

`supabase/tests/0034_supervisor_scope_trigger_columns.sql` contiene 57
aserciones pgTAP dentro de `BEGIN`/`ROLLBACK`. Usa fixtures aislados con prefijo
`34000000`, ejecuta DML real sobre ambas tablas y llama a los contratos de 0033
para creación, guardado de alcance, cambio de estado y cambio de rol. La suite
cubre las seis combinaciones tabla/operación (`INSERT`, `UPDATE`, `DELETE`) y
comprueba `idempotency_key` y `operation_id`. Además reconstruye un candidato
histórico en un segundo tenant, reproduce el `42703` con la función de 0009,
reinstala la definición segura antes del backfill y verifica auditoría y
aislamiento por empresa.

Staging ya ejecutó la secuencia anterior 0033→0034 y el flujo quedó funcional,
pero esa evidencia no sustituyó el gate local. La suite pgTAP se ejecutó después
en una base Supabase local aislada y terminó 57/57. El reintento
poscompensación se modela desde el estado DB esperado (sin
Auth/profile/auditoría anterior) y con una identidad nueva; la eliminación real
de Auth sigue siendo una prueba integrada exclusiva de staging.

## Orden corregido y gates reproducibles

En una base nueva, 0033 instala `auditar_asignacion_supervisor()` antes del
backfill. 0034 ejecuta después el mismo `CREATE OR REPLACE FUNCTION`, de manera
idempotente, para conservar el roll-forward aplicado en staging y reafirmar el
contrato en instalaciones limpias.

| Gate | Estado | Evidencia |
|---|---|---|
| Migración completa 0001–0036 sobre una base nueva | **PASS** | Reset local hasta 0008, candidato histórico previo a 0009 y aplicación ordenada 0009–0036; 36 migraciones registradas. |
| `supabase/tests/0034_supervisor_scope_trigger_columns.sql` | **PASS** | 57/57 aserciones dentro de `BEGIN`/`ROLLBACK`. |

La validación confirmó backfill y auditoría correctos, cero cruce entre empresas,
la función segura final y los dos triggers habilitados. Producción todavía no
tiene 0033/0034 y no intervino en estos gates.

## Preparación y evidencia

- Confirmar que staging conserva registradas 0033 y 0034; no volver a ejecutar
  una migración histórica ya aplicada.
- Ejecutar `migration-0034-postflight.sql` y conservar su salida.
- Confirmar que Web y `user-provisioning` desplegadas son compatibles con 0033.
- Disponer de una empresa activa, dos sucursales activas, al menos tres
  departamentos activos distribuidos entre ellas, un ADMIN autorizado, un
  empleado sin acceso y roles activos ADMIN y SUPERVISOR.
- Usar datos de prueba identificables y eliminables; no reutilizar usuarios
  reales ni ejecutar ningún caso en producción.
- Capturar por caso: `requestId`, acción Edge, RPC, `idempotency_key` u
  `operation_id`, SQLSTATE, filas antes/después y auditorías, sin guardar JWT,
  contraseña ni otros secretos.
- Para DML directo de trigger, utilizar una sesión administrativa autorizada y
  una transacción de prueba controlada. No conceder privilegios nuevos a
  `anon` o `authenticated`.

## Casos obligatorios

### 1. Crear supervisor con una sucursal y un departamento

Ejecutar `create-access` desde la Web/Edge con un `idempotency_key` nuevo,
sucursal B1 y departamento D1 de B1.

Resultado esperado:

- respuesta exitosa y una sola identidad Auth;
- un profile activo y vínculo correcto con empleado;
- una fila `(profile, B1)` en `perfil_sucursales`;
- una fila `(profile, D1)` en `perfil_departamentos`;
- auditorías `INSERT` con `entidad_id` B1 y D1 respectivamente;
- ningún `42703` en respuesta ni logs.

### 2. Crear supervisor con varios departamentos

Crear otro supervisor con B1 y D1+D2, enviando además un UUID repetido para
confirmar la deduplicación prevista por 0033.

Resultado esperado: una sucursal, dos departamentos únicos, una auditoría por
fila insertada, alcance válido y ausencia de `42703`.

### 3. Insertar en `perfil_sucursales`

En un fixture aislado y válido, insertar directamente una relación de sucursal
para un perfil de prueba que todavía no la tenga.

Resultado esperado: se ejecutan `perfil_sucursales_validate_rc3` y
`perfil_sucursales_audit_rc3`; la auditoría usa `NEW.sucursal_id`, `antes` es
`NULL`, `despues` contiene la fila y no se intenta acceder a
`NEW.departamento_id`.

### 4. Insertar en `perfil_departamentos`

Con la sucursal correspondiente ya asignada, insertar directamente D1 para el
mismo fixture.

Resultado esperado: se ejecutan `perfil_departamentos_validate_rc3` y
`perfil_departamentos_audit_rc3`; la auditoría usa `NEW.departamento_id`, no
`NEW.sucursal_id`, y no aparece `42703`.

### 5. Actualizar una asignación

En un fixture con B1 y D1, actualizar la relación de departamento de D1 a D2,
ambos activos y pertenecientes a B1. Si la política operativa evita actualizar
claves, ejecutar adicionalmente un `UPDATE` controlado de `created_at` para
cubrir el evento sin cambiar alcance.

Resultado esperado: validación correcta, auditoría `UPDATE` con `antes` y
`despues`, `entidad_id` tomado de `NEW.departamento_id` y ninguna referencia a
campos inexistentes.

### 6. Desactivar el acceso conservando asignaciones dormantes

Invocar `cambiar_estado_acceso_con_alcance_internal` para pasar un supervisor
activo a inactivo.

Resultado esperado: cambia `profiles.status`, las relaciones permanecen sin
otorgar alcance efectivo y no se produce `42703`. Este caso confirma el modelo:
las tablas de asignación no tienen columna `activo`; la desactivación del
acceso no equivale a actualizar esas filas.

### 7. Eliminar y reemplazar alcance

Mediante `update-access`, partir de B1/D1+D2 y guardar B1/D2, y después un
alcance válido de otra sucursal B2 con uno de sus departamentos.

Resultado esperado:

- la primera edición elimina únicamente D1;
- el reemplazo elimina relaciones anteriores e inserta las nuevas en el orden
  transaccional de 0033;
- los `DELETE` auditan con `OLD.departamento_id` o `OLD.sucursal_id`;
- los `INSERT` auditan con los campos `NEW` de su tabla;
- no queda estado parcial ni aparece `42703`.

### 8. Cambio de rol

Probar en fixtures separados:

1. `SUPERVISOR` a `ADMIN`, con alcance existente;
2. `ADMIN` a `SUPERVISOR`, suministrando B1 y D1;
3. `ADMIN` a `SUPERVISOR` sin departamentos.

Resultado esperado: el primer caso limpia las relaciones y confirma el nuevo
rol; el segundo crea alcance válido; el tercero falla por la validación de
alcance esperada, no por `42703`. Toda falla revierte perfil y relaciones.

### 9. Reintento después de Auth compensado

Reintentar el alta asociada al incidente, o un fixture equivalente, después de
confirmar que la identidad anterior fue compensada. Conservar el mismo
`idempotency_key` y payload lógico; usar un nuevo `requestId` de observabilidad.

Resultado esperado: una sola identidad Auth vigente, un solo profile, un solo
vínculo, asignaciones sin duplicados y replay consistente. No debe reaparecer
el request fallido ni quedar un Auth huérfano. El resultado no usa
`operation_id`, reservado al flujo de actualización.

### 10. Barrido final de SQLSTATE y auditoría

Revisar los logs y resultados de los nueve casos y ejecutar los `SELECT` de
postflight sobre triggers, funciones, columnas y auditorías.

Resultado esperado:

- cero eventos con `code=42703` o mensajes `record "new|old" has no field`;
- las seis combinaciones tabla/operación quedan cubiertas;
- cada mutación real tiene auditoría con entidad y UUID correctos;
- RLS, policies y privilegios permanecen sin ampliación;
- `alcance_supervisor_valido_internal` continúa exigiendo una sucursal y uno o
  más departamentos activos de esa sucursal.

## Matriz mínima de cobertura

| Tabla | INSERT | UPDATE | DELETE |
|---|---:|---:|---:|
| `perfil_sucursales` | Casos 1, 3 y 7 | Caso 5 si se usa fixture de sucursal | Casos 7 y 8 |
| `perfil_departamentos` | Casos 1, 2, 4 y 7 | Caso 5 | Casos 7 y 8 |

Si la suite no ejecuta un `UPDATE` real sobre `perfil_sucursales`, añadir un
fixture sin departamentos, actualizar B1 a B2 dentro de una transacción de
prueba y verificar su auditoría antes de revertir el fixture.

## Validación local permitida antes del staging integrado

- `pnpm.cmd run build`;
- `pnpm.cmd run test:supervisor-scope`;
- parser o chequeo estático disponible para delimitadores, transacción,
  `SECURITY DEFINER`, `search_path` y ausencia de DML en el postflight;
- `git diff --check`.

Estas comprobaciones no sustituyen los diez casos: el defecto original sólo se
manifiesta al ejecutar el trigger contra tipos de fila reales.

## Criterio de aprobación

0034 se aprueba únicamente cuando los diez casos terminan con los resultados
esperados, el postflight contiene sólo `SELECT`, no aparece `42703`, la
compensación/reintento Auth queda conciliada y no se observa ampliación de
permisos o alcance.
