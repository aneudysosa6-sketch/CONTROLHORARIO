# Revisión de migración 0033 — alcance explícito de supervisores

Estado: corregida y validada localmente; producción aún no tiene 0033
Evidencia de staging: la secuencia anterior 0033→0034 fue aplicada y el flujo quedó funcional
Migración: `supabase/migrations/0033_supervisor_department_assignments.sql`

## Objetivo

La migración 0033 convierte las asignaciones explícitas de sucursal y
departamentos en la única fuente de alcance para un usuario con rol canónico
`SUPERVISOR`. No concede alcance global cuando las asignaciones están vacías o
son incoherentes.

## Estado por entorno

- **Producción:** todavía no tiene 0033. Esta revisión no acredita ni implica
  una aplicación en producción.
- **Staging:** ejecutó la secuencia anterior, en la que 0033 se aplicó primero y
  0034 corrigió después la función de auditoría compartida. El flujo integrado
  quedó funcional.
- **Instalación nueva:** el archivo 0033 corregido instala la función de
  auditoría segura antes del backfill. La secuencia se validó en Supabase local:
  se aplicaron 0001–0008, se insertó un candidato histórico y luego se aplicaron
  0009–0036 sin `42703`. El historial terminó con 36 migraciones y máximo 0036.

La validación local confirmó una sucursal backfilleada, una auditoría `INSERT`,
cero relaciones cruzadas entre empresas y ambos triggers habilitados sobre la
función segura. La suite pgTAP asociada terminó con 57 de 57 aserciones.

## Modelo reutilizado

No se crea `supervisor_departamentos` ni otro modelo paralelo. Se reutilizan:

- `public.perfil_sucursales(perfil_id, sucursal_id)`;
- `public.perfil_departamentos(perfil_id, departamento_id)`.

Las claves primarias compuestas existentes impiden duplicados. La actividad de
una asignación se resuelve por presencia de la relación más perfil, empresa,
rol, sucursal y departamento activos. Los escritores y triggers rechazan nuevas
asignaciones para perfiles inactivos; las relaciones históricas que pudieran
existir quedan dormantes y no otorgan alcance de sesión. Retirar una asignación
equivale a eliminar la relación exacta dentro de la operación transaccional
protegida.

`profiles.branch_id` y `profiles.department_id` continúan representando la
ubicación laboral del empleado vinculado; no se usan como fallback de alcance
para `SUPERVISOR`.

## Tratamiento de datos existentes

Antes del primer `INSERT` del backfill, la versión corregida de 0033 instala
`public.auditar_asignacion_supervisor()` con ramas separadas por tabla y
operación. Así, una base creada desde cero no ejecuta el cuerpo heredado de
0009 contra `perfil_sucursales` cuando todavía podría intentar resolver
`departamento_id`, ni contra `perfil_departamentos` intentando resolver
`sucursal_id`.

La migración completa idempotentemente `perfil_sucursales` a partir de las
asignaciones históricas de `perfil_departamentos` y la sucursal real del
departamento. Usa `ON CONFLICT DO NOTHING` y no elimina asignaciones durante el
backfill.

0034 conserva su lugar inmediatamente posterior y vuelve a instalar la misma
frontera de auditoría mediante `CREATE OR REPLACE FUNCTION`. Esa reafirmación es
idempotente: mantiene corregido un staging que hubiera ejecutado la versión
anterior de 0033 y protege también la secuencia nueva sin cambiar datos.

No existe una marca que permita distinguir con certeza una fila de
`perfil_sucursales` preexistente de una insertada por el backfill. Por ello el
rollback no puede eliminar esas filas a ciegas.

Si un supervisor histórico queda asociado a más de una sucursal, la migración
conserva sus datos pero lo marca como `requires_reconciliation`. El resolver
exige exactamente una sucursal coherente y devuelve alcance vacío mientras la
inconsistencia exista. Este comportamiento es deliberadamente *fail-closed*.

## Contratos SQL

### Nuevas funciones internas

- `obtener_empresa_actor_activo_internal(uuid)` deriva la empresa del actor
  activo; no confía en `company_id` enviado por el cliente.
- `alcance_supervisor_valido_internal(uuid, uuid)` comprueba la estructura
  persistida: empresa, rol, entidades activas, una sola sucursal y relación
  exacta con departamentos. Deliberadamente no exige que el perfil ya esté
  activo porque también valida la transición de reactivación; los escritores y
  resolvers efectivos sí exigen perfil activo.
- `obtener_alcance_supervisor_internal(jsonb)` lista catálogo activo y alcance;
  detecta datos multirrama o inválidos sin conciliarlos silenciosamente.
- `guardar_alcance_supervisor_internal(jsonb)` sustituye el alcance bajo locks
  transaccionales y audita únicamente cambios reales.
- `crear_acceso_con_alcance_internal(jsonb)` crea perfil/vínculo y alcance en
  una sola transacción PostgreSQL.
- `actualizar_acceso_con_alcance_internal(jsonb)` actualiza rol/acceso y alcance
  en la misma transacción. Para SUPERVISOR→SUPERVISOR sustituye primero las
  relaciones, permitiendo conciliar datos históricos inválidos sin exponer un
  estado parcial.
- `obtener_actualizacion_acceso_confirmada_internal(jsonb)` comprueba una marca
  `operation_id` escrita dentro de esa misma transacción antes de decidir una
  compensación Auth.
- `cambiar_estado_acceso_con_alcance_internal(jsonb)` impide activar un
  supervisor sin alcance válido.
- `obtener_creacion_acceso_idempotente_internal(jsonb)` resuelve reintentos con
  la misma clave y rechaza reutilización con un payload diferente.

### Contratos reemplazados o reforzados

- `listar_accesos_internal(jsonb)` conserva el comportamiento de 0027 para
  candidatos activos sin acceso y añade `role_code_canonical` calculado en SQL.
- `validar_alcance_supervisor()`,
  `proteger_sucursal_asignada_supervisor()` y
  `validar_cambio_sucursal_supervisor()` validan tenant, estado y coherencia.
- `obtener_departamentos_supervisor_actual()` usa exclusivamente relaciones
  explícitas válidas.
- `supervisor_puede_ver_empleado(uuid)` comprueba el departamento contra el
  resolver común.
- `obtener_mi_autorizacion()` devuelve `scope_source =
  explicit_supervisor_assignments`; para SUPERVISOR no incluye la ubicación
  laboral principal como alcance.
- Los RPC históricos de empleados, jornadas, incidencias, horarios y dashboard
  que llaman `supervisor_puede_ver_empleado` u
  `obtener_departamentos_supervisor_actual` heredan la misma frontera.

### Escritor legacy neutralizado

`guardar_departamento_administracion(uuid,jsonb,uuid,text)` conserva su firma
para compatibilidad, pero rechaza cualquier `p_supervisor` no nulo con
`SUPERVISOR_SCOPE_MANAGED_IN_ACCESS`. El catálogo de Departamentos deja así de
ser un escritor alternativo capaz de sobrescribir silenciosamente el alcance.

## Edge Function

`user-provisioning` expone:

- `get-supervisor-scope`;
- `save-supervisor-scope`;
- `create-access` y `update-access` con `branch_id` y `department_ids` dentro de
  la misma operación lógica.

El actor se valida por JWT, perfil activo y empresa derivada. Administrar
alcance exige al menos uno de `usuarios.administrar`, `roles.administrar` o
`permisos.administrar`. Los IDs se revalidan en SQL; el filtrado Web es sólo UX.

`authenticated` conserva SELECT sujeto a RLS sobre las tablas de alcance, pero
ya no puede ejecutar INSERT/UPDATE/DELETE directos. Esto elimina escritores
concurrentes alternativos; las mutaciones pasan por Edge y los RPC protegidos.

## Atomicidad Auth/PostgreSQL

Supabase Auth y PostgreSQL no comparten transacción distribuida:

- En creación, Edge crea Auth y llama un único RPC que crea perfil, vínculo y
  alcance. Ante error consulta primero la clave idempotente: un commit confirmado
  se devuelve como éxito y sólo un rollback confirmado permite eliminar la
  identidad recién creada. Un resultado ambiguo queda pendiente y no borra Auth.
- En actualización, Edge conserva email y metadata anteriores. Si la
  transacción SQL no dejó su `operation_id`, intenta restaurarlos; si la marca
  confirma commit devuelve éxito y si no puede verificar, no restaura a ciegas.
- La sincronización posterior del estado bloqueado de Auth puede quedar
  `pending`; la autorización PostgreSQL continúa denegando por perfil/estado.

## Idempotencia

- `create-access` exige un UUID `idempotency_key`.
- Un índice único parcial protege
  `(company_id, actor_user_id, details->>'idempotency_key')` para auditorías de
  creación.
- La firma normalizada incluye empleado, rol, usuario, estado, sucursal y el
  conjunto ordenado de departamentos.
- Mismo key y mismo payload devuelve replay; mismo key con payload distinto
  devuelve `IDEMPOTENCY_KEY_REUSED`.
- Las claves compuestas de las tablas de alcance y la deduplicación de UUID
  impiden repetir asignaciones.

## Privilegios

Las nuevas funciones que Edge invoca reciben `EXECUTE` exclusivamente para
`service_role`; `anon` y `authenticated` quedan revocados. Las funciones de
sesión estrictamente necesarias conservan `EXECUTE` para `authenticated`.

La migración no concede `GRANT ALL`. Revoca únicamente INSERT/UPDATE/DELETE de
`anon` y `authenticated` sobre `perfil_sucursales` y `perfil_departamentos`;
conserva SELECT sujeto a RLS. El Edge continúa requiriendo los grants mínimos
preexistentes para leer `profiles`, `empleados` y `roles` y ejecutar los RPC
internos.

## RLS y policies

0033 no ejecuta `ALTER TABLE ... DISABLE ROW LEVEL SECURITY`, no crea, elimina
ni reemplaza policies. RLS continúa habilitada en `perfil_sucursales` y
`perfil_departamentos`, con las policies vigentes establecidas por 0002/0026.

Las funciones `SECURITY DEFINER` fijan `search_path = ''`, validan actor,
empresa, permiso y entidades antes de escribir. Los triggers de validación y
auditoría existentes continúan activos.

## Riesgos y puntos de despliegue

1. **Legacy multirrama:** se conserva y bloquea; requiere conciliación explícita
   desde Accesos antes de habilitar al supervisor.
2. **Orden de despliegue:** migración antes que la nueva Edge Function y Web.
   No activar la UI nueva contra contratos SQL antiguos.
3. **Grants de staging:** verificar los grants mínimos de `service_role` antes
   de desplegar Edge. En staging es obligatorio aplicar primero
   `staging-roles-service-role-grant.sql`; 0033 no amplía ese privilegio.
4. **Recuperación Auth pendiente:** investigar mediante `requestId`, etapa y
   `provisioning_request_id` y `provisioning_idempotency_key`; no reintentar con
   claves distintas a ciegas.
5. **Sesión existente:** después de editar alcance se debe renovar autorización
   para actualizar `department_ids` y `branch_ids` en memoria.
6. **Rollback:** se prefiere roll-forward. Restaurar definiciones anteriores sin
   snapshot podría reintroducir alcance implícito o global.
7. **Concurrencia Auth/DB:** la compensación distingue commit, rollback y estado
   ambiguo, pero Auth y PostgreSQL no ofrecen un lock distribuido. Hasta añadir
   control de versión/lease por perfil, no ejecutar dos mutaciones administrativas
   simultáneas sobre el mismo acceso.

## Criterio de aprobación

- Postflight sin objetos o grants faltantes.
- Cero asignaciones cruzadas entre empresas.
- Supervisores válidos con exactamente una sucursal y uno o más departamentos
  activos de esa sucursal.
- Casos legacy reportados para conciliación y sin acceso efectivo.
- Pruebas Web, Edge y SQL del plan completadas en staging.
- Sin cambios de RLS, policies o permisos ajenos al contrato descrito.
