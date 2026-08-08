# Migración 0030 — Revisión de preparación

## Identificación

| Campo | Valor |
|---|---|
| Ruta | `supabase/migrations/0030_fix_employee_role_canonicalization.sql` |
| Nombre | `0030_fix_employee_role_canonicalization.sql` |
| Tamaño | 1951 bytes |
| SHA-256 | `FF59DA0746A6C333D1D56141C0A8A43D507888199588222856D18CE23956DB1F` |
| Modificación | 2026-07-27 10:51:18, hora local del equipo |
| Migración anterior | `0029_unified_authentication_authorization.sql` |

## Clasificación del estado

**PENDING MIGRATION**

Las migraciones `0001` a `0029` aparecen tanto en el historial local como en el
remoto. `0030` es la siguiente migración local y todavía no aparece remotamente.
No hay un hueco irregular ni una contradicción del historial que sustente
`MIGRATION HISTORY DRIFT`. Tampoco existe evidencia de cambios remotos ajenos a
las migraciones locales que permita afirmar `SCHEMA DRIFT`.

Recomendación para A6: **PENDING PRODUCTION MIGRATION**.

G07 debe permanecer `BLOCKED` hasta revisar y validar `0030` en staging, aprobar
preflight y postflight, completar pruebas de roles, disponer de backup y plan
de rollback, y autorizar expresamente su promoción.

## Resumen del cambio

`0030` reemplaza la función SQL inmutable
`private.normalizar_codigo_rol(text)`. Conserva la firma y los roles canónicos
existentes, añade `EMPLEADOS` y `EMPLOYEES` como alias de `EMPLEADO`, y cambia
los caracteres acentuados de `translate` a escapes Unicode explícitos. Un
bloque de verificación comprueba los cuatro alias de empleado antes del
`commit`.

No modifica datos, tablas, columnas, constraints, índices, RLS, grants,
triggers ni Edge Functions.

## Objetos afectados

| Objeto | Tipo de cambio | Impacto |
|---|---|---|
| `private.normalizar_codigo_rol(text)` | `CREATE OR REPLACE` | Canonicaliza `EMPLEADOS` y `EMPLOYEES` como `EMPLEADO`; mantiene firma, retorno, volatilidad y `search_path` |
| Bloque anónimo de comprobación | Ejecución transitoria | Aborta la transacción si cualquiera de los alias de empleado no produce `EMPLEADO` |
| `public.obtener_mi_autorizacion()` | Dependencia indirecta, sin reemplazo | Puede devolver `role_code_canonical = EMPLEADO` para los alias nuevos |
| `public.limpiar_autorizacion_por_cambio_rol()` | Dependencia indirecta, sin reemplazo | Evita tratar cambios entre alias de empleado como cambios de familia |

## Auditoría detallada del SQL

| Control | Resultado |
|---|---|
| Objetos creados | Ninguno persistente nuevo |
| Objetos reemplazados | `private.normalizar_codigo_rol(text)` |
| Objetos eliminados | Ninguno |
| Tablas modificadas | Ninguna |
| Columnas modificadas | Ninguna |
| Constraints | Ninguno |
| Índices | Ninguno |
| Funciones o RPC | Se reemplaza un helper privado; no cambia la firma de RPC públicos |
| Policies RLS | Ninguna |
| Grants o revokes | Ninguno |
| Triggers | Ninguno |
| Backfills o actualizaciones masivas | Ninguno |
| `auth.users`, profiles, empleados o roles | No hay acceso directo; los callers leen `profiles` y `roles` |
| `SECURITY DEFINER` | La función reemplazada no lo usa |
| `search_path` | Fijo y vacío: `set search_path = ''` |
| `auth.uid()` | No se usa; la función es un transformador puro de texto |
| `company_id` | No aplica dentro del helper; no consulta datos ni acepta empresa |
| Usuarios activos | No aplica dentro del helper; los RPC consumidores deben validarlos |
| Roles canónicos | Mantiene `ADMIN`, `SUPERVISOR`, `EMPLEADO`, `RRHH`, `NOMINA`, `AUDITOR` |
| Compatibilidad con roles anteriores | Conserva aliases previos y añade `EMPLEADOS`/`EMPLOYEES` |
| Bloqueos | No bloquea tablas; el reemplazo requiere un lock de catálogo sobre la función |
| Pérdida de datos | No se identifica riesgo de pérdida porque no escribe filas |
| Valores `NULL` | `coalesce(p_codigo, '')` produce cadena vacía |
| Duplicados | No crea ni modifica registros |
| Idempotencia | El reemplazo es determinista; repetir el SQL deja la misma definición |
| Transacción y atomicidad | `begin`/`commit`; una excepción revierte el reemplazo |
| Manejo de errores | La comprobación levanta `EMPLOYEE_ROLE_CANONICALIZATION_FAILED` |
| Android | Compatible con `EMPLEADO` y con los cuatro alias temporales |
| Web | Compatible después de canonicalizar; antes de `0030` la tolerancia es incompleta |
| Seis Edge Functions | Sin referencias directas al helper; `user-provisioning` depende indirectamente del trigger de cambio de rol |

## Seguridad

La función de `0030` no es `SECURITY DEFINER`, no usa SQL dinámico, no consulta
tablas y no acepta `company_id`. Su `search_path` está fijado a una cadena
vacía. Las funciones integradas usadas por la expresión se resuelven desde
`pg_catalog`.

El cambio sí influye en funciones `SECURITY DEFINER` definidas en `0029`, entre
ellas `obtener_mi_autorizacion()` y
`limpiar_autorizacion_por_cambio_rol()`. Esas funciones conservan
`search_path = ''`; la primera obtiene identidad mediante `auth.uid()`, valida
perfil, cuenta, empresa y rol activos, y deriva `company_id` del perfil en vez
de recibirlo del cliente. `0030` no debilita esos controles.

La revisión estática no sustituye pruebas con usuarios sintéticos ni una
auditoría integral de todos los callers privilegiados.

## RLS y aislamiento de empresa

`0030` no altera RLS ni ejecuta consultas de negocio. El aislamiento depende de
los RPC consumidores de `0029`. El preflight y postflight incluyen inventario
de policies y verificaciones agregadas de inconsistencias entre empresa de
perfil, rol y empleado. Staging debe probar explícitamente empresa A contra
empresa B.

## Compatibilidad Android

Android carga `role_code_canonical` desde `obtener_mi_autorizacion()` y lo usa
para resolver navegación. Su `DashboardResolver` acepta `EMPLEADO`,
`EMPLEADOS`, `EMPLOYEE` y `EMPLOYEES`, y las pruebas unitarias cubren esos
aliases. Mientras producción permanece en `0029`, existe compatibilidad
temporal para el dashboard Android. Después de `0030`, la respuesta se
estabiliza en `EMPLEADO`, sin cambio de contrato.

## Compatibilidad Web

Web también hidrata sesión mediante `obtener_mi_autorizacion()`, pero su
tolerancia temporal no es completa. El resolver de dashboard acepta
`EMPLEADOS`, aunque `normalizeRoleForClient` no lo convierte a `employee`; el
guard de `/mi-portal` acepta solo `employee` o `empleado`. `EMPLOYEES` tampoco
figura entre los casos del resolver de dashboard. Mientras producción siga en
`0029`, usuarios almacenados con esos aliases pueden sufrir navegación o
denegación incorrecta. `0030` corrige el valor en origen y devuelve
`EMPLEADO`, que Web procesa correctamente.

## Compatibilidad Edge Functions

La búsqueda estática no encontró referencias directas al helper ni a
`role_code_canonical` en las seis Edge Functions remotas inventariadas.
`user-provisioning` sí cambia `role_id` mediante
`actualizar_acceso_autorizacion_internal`; ese cambio activa el trigger de
`0029`, que compara familias usando el normalizador. Con `0030`, un cambio
entre aliases de empleado deja de limpiar innecesariamente permisos,
departamentos y sucursales del perfil. Las otras cinco funciones no muestran
dependencia directa.

El inventario remoto no valida autenticación, autorización, `verify_jwt` ni
tenant. G09 permanece `NOT ASSESSED`.

## Riesgos de despliegue

**Riesgo: MEDIUM**

El cambio técnico es pequeño, transaccional y sin escrituras de datos, pero
afecta una función central del contrato de autorización. No se puede estimar
una duración numérica sin observar locks y carga en staging. No se esperan
locks de tabla ni backfills; sí puede existir espera por uso concurrente de la
función durante el reemplazo.

La firma no cambia y el resultado nuevo es compatible hacia atrás. Sesiones ya
hidratadas conservarán su rol hasta la siguiente carga o restauración de
sesión. Si falla antes del `commit`, PostgreSQL revierte toda la transacción. Si
el problema aparece después, debe usarse una migración compensatoria aprobada,
no editar el historial.

Antes de producción se necesita backup verificable, captura de la definición
actual, monitoreo de locks, pruebas de sesión activa y restaurada, y aprobación
de una ventana operativa. No se conoce el tamaño ni distribución real de
roles; el preflight obtiene únicamente conteos agregados.

## Riesgo de no aplicar 0030

**Riesgo: MEDIUM**

Producción puede seguir devolviendo `EMPLEADOS` o `EMPLOYEES` como rol
supuestamente canónico. Android tolera ambos, pero Web puede denegar
incorrectamente `/mi-portal` o resolver un dashboard desconocido. Además, un
cambio entre aliases equivalentes puede activar la limpieza de autorización
del perfil. El riesgo real depende de cuántos roles activos usan esos valores;
el preflight debe medirlo sin extraer datos personales.

## Condiciones para probar en staging

- Proyecto staging separado y comprobado como distinto de producción.
- Datos exclusivamente sintéticos.
- Historial `0001` a `0029` aplicado y validado.
- Preflight ejecutado sin inconsistencias inexplicadas.
- Backup y restauración de staging comprobados.
- Aplicación de `0030` solo en staging.
- Postflight completamente satisfactorio.
- Pruebas de login, restauración, aliases, usuarios inactivos y sin perfil.
- Pruebas de aislamiento multiempresa y supervisor limitado.
- Pruebas Android, Web y `user-provisioning`.
- Evidencia de locks, duración observada y resultado de rollback compensatorio.

## Condiciones para producción

- Todos los criterios de staging aprobados y documentados.
- Distribución agregada de roles revisada.
- Backup reciente, verificable y con responsable.
- Migración compensatoria revisada, sin SQL destructivo improvisado.
- Ventana, monitoreo, criterios de aborto y responsables definidos.
- Compatibilidad con versiones Android y Web todavía activas confirmada.
- Aprobación formal de seguridad, backend, QA y responsable de producción.
- G07 actualizado solo después de comprobar el historial remoto posterior.

## Veredicto de la revisión

**APTO PARA PRUEBA EN STAGING**

Este veredicto no autoriza producción. G07 permanece `BLOCKED`.
