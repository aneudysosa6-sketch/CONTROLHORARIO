# Revisión de migración 0034 — columnas del trigger de alcance supervisor

Estado: validada localmente y ejecutada en staging dentro de la secuencia anterior; producción aún sin 0033/0034
Migración: `supabase/migrations/0034_fix_supervisor_scope_trigger_columns.sql`

## Estado por entorno

- **Producción:** todavía no tiene 0033 y, por tanto, tampoco 0034. No se tocó
  producción durante esta revisión.
- **Staging:** aplicó primero la versión anterior de 0033 y luego 0034. La
  corrección eliminó el fallo del trigger y el flujo quedó funcional.
- **Instalación nueva:** 0033 corregida instala esta función antes de ejecutar
  su backfill; 0034 permanece en la secuencia para reafirmar idempotentemente
  la definición segura.
- **Supabase local:** una base nueva aplicó 0001–0008, recibió un candidato
  histórico y completó 0009–0036. El backfill, la auditoría y el aislamiento por
  empresa pasaron; la suite pgTAP terminó 57/57.

## Incidente confirmado

En `controlhorario-staging`, `create-access` alcanzó la RPC
`public.crear_acceso_con_alcance_internal(jsonb)` después de crear la identidad
Auth y falló al guardar el alcance supervisor:

- `requestId`: `<REQUEST_ID_STAGING>`;
- `stage`: `create_access_transaction`;
- `code`: `42703` (`undefined_column`);
- `message`: `record "new" has no field "departamento_id"`;
- `recovery_status`: `auth_compensated`.

La compensación Auth fue correcta. La transacción PostgreSQL revirtió el
perfil, el vínculo con empleado, las asignaciones y sus auditorías.

## Diagnóstico exacto

La función defectuosa es `public.auditar_asignacion_supervisor()`, creada por
la migración 0009 y conservada por la versión anterior de 0033 que recibió
staging. Una misma función está vinculada a:

- `perfil_sucursales_audit_rc3`, `AFTER INSERT OR UPDATE OR DELETE` sobre
  `public.perfil_sucursales`;
- `perfil_departamentos_audit_rc3`, `AFTER INSERT OR UPDATE OR DELETE` sobre
  `public.perfil_departamentos`.

La definición anterior elegía la entidad con expresiones `CASE` que contenían
a la vez `NEW.sucursal_id` y `NEW.departamento_id`, o sus equivalentes de
`OLD`. Aunque el valor de `TG_TABLE_NAME` seleccionara una rama, PostgreSQL
debía resolver todos los campos del `record` al preparar la expresión. El
campo de la otra tabla no forma parte del tipo de fila activo y producía
`42703`.

Las columnas reales no han cambiado desde 0002:

- `public.perfil_sucursales(perfil_id, sucursal_id, created_at)`;
- `public.perfil_departamentos(perfil_id, departamento_id, created_at)`.

No existen `departamento_id` en `perfil_sucursales`, `sucursal_id` en
`perfil_departamentos`, ni aliases físicos `branch_id` o `department_id` en
ninguna de las dos relaciones.

## Punto exacto del flujo de creación

`crear_acceso_con_alcance_internal(jsonb)` crea primero el acceso SQL y, para
el rol canónico `SUPERVISOR`, llama a
`guardar_alcance_supervisor_internal(jsonb)`. Para un perfil nuevo, este RPC:

1. ejecuta `DELETE` que no encuentra asignaciones previas;
2. inserta `(perfil_id, sucursal_id)` en `perfil_sucursales`;
3. supera `perfil_sucursales_validate_rc3`;
4. ejecuta `perfil_sucursales_audit_rc3`;
5. la función de auditoría intenta resolver `NEW.departamento_id` y falla;
6. nunca alcanza el `INSERT` de `perfil_departamentos`.

Por eso el error ocurre dentro de `create_access_transaction`, después de
crear Auth y antes de confirmar cualquier dato PostgreSQL.

## Matriz de operaciones e impacto anterior a 0034

| Tabla | Operación | Campo inválido de la función anterior | Campo real | Impacto |
|---|---|---|---|---|
| `perfil_sucursales` | `INSERT` | `NEW.departamento_id` | `NEW.sucursal_id` | Bloquea la primera sucursal de un supervisor nuevo. |
| `perfil_sucursales` | `UPDATE` | `NEW.departamento_id` | `NEW.sucursal_id` | Bloquea cualquier actualización real de la relación. |
| `perfil_sucursales` | `DELETE` | `OLD.departamento_id` | `OLD.sucursal_id` | Bloquea retirar o sustituir una sucursal. |
| `perfil_departamentos` | `INSERT` | `NEW.sucursal_id` | `NEW.departamento_id` | Bloquea agregar uno o varios departamentos. |
| `perfil_departamentos` | `UPDATE` | `NEW.sucursal_id` | `NEW.departamento_id` | Bloquea actualizar una relación. |
| `perfil_departamentos` | `DELETE` | `OLD.sucursal_id` | `OLD.departamento_id` | Bloquea retirar, reemplazar o limpiar departamentos. |

El defecto también podía impedir:

- editar un supervisor cuando el conjunto de alcance cambiaba;
- cambiar `SUPERVISOR` a otra familia de rol, porque
  `limpiar_autorizacion_por_cambio_rol()` elimina primero las relaciones;
- cambiar otra familia a `SUPERVISOR`, al limpiar relaciones anteriores o al
  insertar el nuevo alcance;
- una eliminación física de perfil que propagara `ON DELETE CASCADE` a estas
  tablas.

Desactivar solamente `profiles.status` no ejecuta DML en las tablas de
asignación y, por tanto, no activa este defecto. Las asignaciones no tienen
columna `activo`: mientras el perfil está inactivo permanecen dormantes y no
otorgan alcance efectivo. Retirar una asignación equivale a eliminar la
relación y sí estaba afectado.

Un guardado exactamente igual podía no fallar si los `DELETE` afectaban cero
filas y todos los `INSERT ... ON CONFLICT DO NOTHING` terminaban sin insertar;
en ese caso no se ejecutaba ningún trigger `AFTER` de auditoría.

## Corrección mínima de 0034

0034 permanece como reparación independiente y no recrea tablas o datos. En
una sola transacción ejecuta `CREATE OR REPLACE FUNCTION` sobre
`public.auditar_asignacion_supervisor()` y conserva los triggers existentes.

La función corregida:

- mantiene `SECURITY DEFINER` y `search_path = ''`;
- exige `TG_TABLE_SCHEMA = 'public'`;
- selecciona primero una rama explícita de `TG_TABLE_NAME`;
- dentro de cada tabla separa `INSERT`, `UPDATE` y `DELETE` mediante `TG_OP`;
- usa `NEW` únicamente en `INSERT`/`UPDATE` y `OLD` únicamente para identificar
  la fila eliminada en `DELETE`;
- accede exclusivamente a `sucursal_id` en `perfil_sucursales` y a
  `departamento_id` en `perfil_departamentos`;
- conserva `antes`, `despues`, `entidad`, `entidad_id`, `accion`, motivo y
  resolución del actor de la auditoría existente;
- rechaza tablas u operaciones inesperadas con SQLSTATE `55000` en vez de
  continuar silenciosamente;
- conserva la frontera de ejecución por trigger y revoca ejecución directa a
  `public`, `anon` y `authenticated`.

No cambia reglas de alcance, RLS, policies, grants de RPC, idempotencia,
`operation_id`, perfiles, roles, empleados ni las tablas de asignación.

## Relación con la 0033 corregida

La corrección se incorpora también al comienzo de 0033, antes del primer DML
de backfill, porque una base nueva no debe atravesar temporalmente la función
defectuosa de 0009. Esto no reescribe el historial ya aplicado de staging:
allí 0034 fue el roll-forward que dejó el flujo funcional.

0034 no se elimina ni se convierte en una migración vacía. Su
`CREATE OR REPLACE FUNCTION` vuelve a establecer el mismo contrato después de
0033, por lo que es idempotente tanto sobre el staging ya corregido como sobre
una instalación limpia que recorra 0001–0036.

## Por qué las validaciones locales anteriores no lo detectaron

1. `pnpm.cmd run test:supervisor-scope` prueba la política TypeScript de
   selección y payload; no abre PostgreSQL ni ejecuta triggers.
2. El build Web y la transpilación Edge no compilan cuerpos PL/pgSQL contra el
   tipo de fila de cada trigger.
3. Una función trigger usa `NEW`/`OLD` como `record`; `CREATE FUNCTION` acepta
   el cuerpo y la incompatibilidad aparece al ejecutar una sentencia sobre una
   tabla concreta.
4. El postflight de 0033, correctamente limitado a `SELECT`, comprobaba que los
   triggers existían y estaban habilitados, pero no ejecutaba DML ni evaluaba
   las seis combinaciones tabla/operación.
5. El plan funcional de 0033 estaba preparado, pero sus casos SQL integrados
   no se habían ejecutado localmente por las restricciones del trabajo.
6. El backfill de 0033 sólo habría manifestado el defecto si hubiera insertado
   efectivamente una nueva fila en `perfil_sucursales`. Con cero filas origen o
   conflictos descartados no se ejecuta el trigger `AFTER INSERT`.

## Riesgo y compatibilidad

El cambio es acotado al cálculo de la entidad auditada. Al no modificar datos
ni firmas, los RPC de 0033 y la Edge desplegada no necesitan cambiar por este
defecto. Staging ya cumplió el orden 0033→0034 antes del reintento funcional;
en producción o una base nueva debe conservarse ese mismo orden y ejecutarse
después el postflight correspondiente.

La aprobación exige que las seis combinaciones de tabla y operación completen
su auditoría sin `42703`, que el flujo atómico conserve sus rollbacks y que no
se alteren RLS, policies ni privilegios.
