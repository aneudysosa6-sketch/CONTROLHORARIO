# Matriz de pruebas de humo de produccion

Estado: plan para una ventana futura. No se crearon datos ni se ejecutaron
pruebas remotas al preparar este documento.

## Condiciones previas

- Usar exclusivamente empresas QA sinteticas preaprobadas y aisladas. Se
  requieren dos para probar separacion entre tenants.
- Usar un ADMIN QA por empresa; nunca cuentas personales ni datos laborales
  reales.
- El dominio de correo sintetico debe estar controlado por el equipo.
- No reutilizar passwords, tokens, correos, UUID de idempotencia ni
  `operation_id` de staging.
- Etiquetar nombres y motivos con `PROMO-<runId>`.
- Si no existen tenants QA, ADMIN QA, sucursales y departamentos seguros para
  la prueba, declarar NO-GO; no improvisar tenants durante la ventana.

## Manifiesto de evidencia

Crear fuera del repositorio un manifiesto cifrado con:

- `runId`, hora UTC, version DB y versiones Edge;
- empresa A/B, sucursales y departamentos sinteticos;
- IDs de empleados, perfiles y usuarios Auth sinteticos;
- `requestId`, `idempotency_key` y `operation_id` por operacion;
- codigo HTTP, resultado esperado/observado y estado de limpieza;
- enlaces o identificadores de logs.

Los IDs Auth/profile/empleado son identificadores seudonimos y se tratan como
datos personales: guardar solo los minimos, con acceso restringido, retencion
definida y borrado seguro al cerrar la evidencia. No guardar passwords, JWT,
claves API, service key, correos completos ni payloads. La generacion de codigo
de empleado es monotona: no intentar rebobinar la secuencia durante la limpieza.

## Datos sinteticos minimos

En empresa A:

- sucursal `PROMO-<runId>-A`;
- departamentos `PROMO-<runId>-A1` y `PROMO-<runId>-A2` en esa sucursal;
- sucursal `PROMO-<runId>-B` con departamento `PROMO-<runId>-B1`;
- tres empleados sinteticos activos sin acceso;
- un acceso SUPERVISOR y un acceso EMPLEADO sinteticos.

En empresa B:

- una sucursal, un departamento y un empleado sintetico que sirvan como
  recursos negativos cross-tenant.

Crear organizacion y empleados mediante los flujos soportados de la aplicacion,
no con SQL directo.

## Matriz obligatoria

| ID | Caso | Ejecucion | Resultado esperado |
|---|---|---|---|
| SM-01 | `bootstrap-status` | POST publico con `apikey`, sin bearer | HTTP 200, `bootstrap_required=false`, sin revelar configuracion sensible. |
| SM-02 | JWT ausente o malformado | Invocar una accion protegida | HTTP 401; no se ejecuta ninguna operacion. |
| SM-03 | Login ADMIN | Iniciar sesion con ADMIN QA | `role_code_canonical=ADMIN`; dashboard y administracion permitidos. |
| SM-04 | Login SUPERVISOR | Iniciar sesion con el supervisor sintetico | `role_code_original` presente, canónico `SUPERVISOR`; abre `/dashboard`, no `/acceso-denegado`. |
| SM-05 | Login EMPLEADO | Iniciar sesion con el empleado sintetico | Canónico `EMPLEADO`; acceso propio permitido y administracion denegada. |
| SM-06 | Crear empleado | Alta en `employee-management` | Exito; codigo de seis digitos generado por servidor, tenant y auditoria correctos. |
| SM-07 | Editar empleado | Cambiar un dato no sensible sintetico | Exito sin cambiar tenant/codigo; auditoria correcta. |
| SM-08 | Crear acceso | `create-access` para empleado sintetico | HTTP 201, `idempotent_replay=false`; Auth, profile y empleado quedan vinculados una vez. |
| SM-09 | Repetir alta | Reenviar mismo payload y `idempotency_key` | HTTP 200, `idempotent_replay=true`; cero duplicados Auth/profile/auditoria. |
| SM-10 | Reusar key con otro payload | Cambiar un campo conservando la key | HTTP 409 `IDEMPOTENCY_KEY_REUSED`; estado anterior intacto. |
| SM-11 | Editar acceso | `update-access` una sola vez | HTTP 200; Auth y SQL coherentes; una auditoria `ACTUALIZAR_ACCESO` cuyo `operation_id` coincide con el `requestId` generado por el servidor. |
| SM-12 | Fallo controlado de edicion | Provocar una validacion SQL fallida despues de una preimagen Auth controlada | Estado Auth restaurado y `recovery_status=auth_restored`; detener si queda `auth_restore_pending`. |
| SM-13 | Supervisor multidepartamento | Crear SUPERVISOR con sucursal A y A1+A2 | HTTP 201; una sucursal, dos departamentos, sin PostgreSQL `42703`. |
| SM-14 | Editar alcance | Reemplazar A1+A2 por A2 mediante el flujo soportado | Exito transaccional; no queda alcance huerfano o multirrama. |
| SM-15 | Filtro por alcance | Consultar empleados A1, A2 y B1 | El supervisor solo ve los departamentos actualmente asignados. |
| SM-16 | Aislamiento entre empresas | Intentar IDs de empresa B desde ADMIN/SUPERVISOR de A | HTTP 403/404 controlado; cero contenido o cambios de empresa B. |
| SM-17 | Rutas administrativas | Abrir rutas ADMIN como SUPERVISOR y EMPLEADO | 403 o `/acceso-denegado`; no se renderizan ni filtran datos. |
| SM-18 | Permisos de supervisor | Consultar autorizacion de sesion | `portal.ver_dashboard`, `supervisor.dashboard`, `empleados.ver_asignados` y `jornadas.ver_asignadas` efectivos. |
| SM-19 | Jornadas | Abrir listado/detalle con datos sinteticos | ADMIN ve empresa; SUPERVISOR solo alcance; EMPLEADO solo propio. |
| SM-20 | Incidencias | Crear/consultar una incidencia sintetica por flujo autorizado | Visibilidad y operaciones respetan rol, alcance y tenant. |
| SM-21 | Compensacion Auth | `create-access` con alcance deliberadamente invalido y key nueva | HTTP 400 con `stage=create_access_transaction`, `recovery_status=auth_compensated`; no quedan Auth/profile/vinculo parcial. |
| SM-22 | Reintento compensado | Corregir alcance y reintentar el mismo caso controlado | Crea exactamente un acceso valido, sin colision residual ni duplicado. |
| SM-23 | Cambio de rol | SUPERVISOR sintetico a rol permitido y retorno por flujo ADMIN | Autorizacion se limpia/recalcula; alcance no se usa fuera del rol; sin bypass. |
| SM-24 | Auditoria | Revisar filas de las operaciones sinteticas | Empresa, actor, accion, motivo, requestId/operation_id correlacionables; sin secretos. |
| SM-25 | Estado y baja logica | Desactivar/reactivar acceso sintetico | Auth y perfil reflejan estado; ultimo ADMIN y auto-baja siguen protegidos. |
| SM-26 | Logs | Revisar ventana UTC completa | Cero 5xx inesperados y solo 4xx negativos previstos por esta matriz. |

## Detalle de compensacion Auth

SM-21 solo puede ejecutarse con un empleado, correo, key y alcance sinteticos.
El fallo debe ocurrir despues de crear Auth y dentro del guardado SQL, usando por
ejemplo un departamento QA que no pertenezca a la sucursal QA seleccionada.

Detener toda la promocion si aparece cualquiera de estos estados:

- `auth_cleanup_pending`;
- `auth_restore_pending`;
- `ACCESS_CREATION_RECOVERY_PENDING`;
- `ACCESS_UPDATE_RECOVERY_PENDING`.

No reintentar con keys diferentes ni borrar una identidad a ciegas cuando el
commit SQL sea ambiguo. Correlacionar primero `auth.users`, `profiles`,
`empleados`, auditorias y el `requestId`.

`update-access` no acepta una idempotency key del cliente: cada invocacion genera
un `requestId`/`operation_id` nuevo. No se debe repetir SM-11 esperando replay;
la interfaz debe evitar dobles envios y cada llamada se trata como operacion
independiente.

## Evidencia por caso

Para cada caso conservar:

1. rol y tenant sinteticos;
2. accion y ruta, sin credenciales;
3. HTTP y codigo publico;
4. `requestId`/`operation_id`;
5. conteos antes/despues relevantes;
6. log correlacionado;
7. PASS/FAIL y responsable.

Un 403 esperado es PASS solo si no hubo lectura ni mutacion. Un 4xx no previsto,
un 5xx, una cuenta parcial o una fuga cross-tenant es NO-GO.

## Limpieza segura

La limpieza se hace con contratos soportados y en orden inverso:

1. Desactivar y retirar los accesos sinteticos mediante `delete-access` o el
   flujo de baja soportado. Confirmar que Auth no puede iniciar sesion y que el
   profile queda tombstoneado/auditado; no hacer hard-delete manual.
2. Terminar/desactivar empleados sinteticos mediante `employee-management`, con
   motivo `PROMOTION_SMOKE_CLEANUP:<runId>`.
3. Desactivar departamentos y sucursales QA solo despues de retirar referencias
   activas. Si son fixtures permanentes QA, restaurar su estado inicial.
4. Conservar jornadas, incidencias y auditorias como evidencia; no borrarlas.
5. No rebobinar secuencias ni reutilizar codigos de empleado.
6. Confirmar que no quedan sesiones activas, asignaciones de alcance utilizables
   ni cuentas sinteticas capaces de autenticar.
7. Marcar cada ID del manifiesto como `desactivado`, `tombstoneado`,
   `retenido_por_auditoria` o `restaurado_a_preimagen`.

La limpieza termina solo cuando las vistas operativas no muestran fixtures
activos y cada residuo retenido tiene una razon de auditoria documentada.
