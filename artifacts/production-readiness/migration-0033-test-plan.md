# Plan de pruebas — migración 0033

Estado: staging funcional con la secuencia anterior; validación local completa aprobada
Entornos objetivo: staging para integración y base local efímera para fresh DB/pgTAP
Capas: Web, Edge Function y PostgreSQL/RLS-RPC

## Estado por entorno

- Producción todavía no tiene 0033 y queda fuera de estas pruebas.
- Staging ejecutó la secuencia anterior 0033→0034 y el flujo integrado quedó
  funcional. Esta evidencia no sustituye una instalación limpia ni demuestra
  por sí sola todos los casos de este plan.
- En una instalación nueva, 0033 corregida instala
  `auditar_asignacion_supervisor()` antes del backfill y 0034 reafirma después
  la misma definición idempotentemente.

## Gates locales ejecutados

| Gate | Estado | Evidencia |
|---|---|---|
| Base nueva con migraciones 0001–0036 | **PASS** | Supabase local se reinició hasta 0008, recibió un candidato histórico y aplicó 0009–0036; historial final: 36 migraciones, máximo 0036. |
| Suite pgTAP de alcance y triggers | **PASS** | `0034_supervisor_scope_trigger_columns.sql`: 57/57 aserciones en la misma base local. |

El fixture local confirmó una sucursal backfilleada, su auditoría `INSERT`, cero
relaciones cruzadas entre empresas, la función segura final y dos triggers
habilitados. No se usó `--linked` ni se ejecutó SQL remoto.

## Preparación

- Confirmar que staging conserva registrada la secuencia anterior 0033→0034;
  no volver a ejecutar una migración histórica ya aplicada.
- Desplegar después la versión compatible de `user-provisioning` y la Web.
- Disponer de dos empresas, al menos dos sucursales por empresa, departamentos
  activos e inactivos y usuarios ADMIN, SUPERVISOR y EMPLEADO.
- Capturar `requestId`, `idempotency_key`, perfil objetivo y estado Auth/DB para
  cada mutación, sin registrar contraseñas ni tokens.
- Ejecutar `migration-0033-postflight.sql` antes de los casos funcionales.

## Casos obligatorios

| # | Caso | Capas | Acción | Resultado esperado |
|---:|---|---|---|---|
| 1 | Supervisor con un departamento | Web / Edge / SQL | Crear acceso SUPERVISOR activo, seleccionar una sucursal y un departamento activo. | `201`; un Auth user, un profile, una fila de sucursal y una de departamento. `obtener_mi_autorizacion()` devuelve sólo ese departamento y `scope_source=explicit_supervisor_assignments`. |
| 2 | Supervisor con varios departamentos | Web / Edge / SQL | Crear o editar seleccionando dos o más departamentos activos de la misma sucursal. | Todos quedan guardados una sola vez; contador Web correcto; autorización devuelve el conjunto completo sin duplicados. |
| 3 | Supervisor sin departamentos | Web / Edge / SQL | Intentar guardar/activar SUPERVISOR activo con sucursal vacía o lista vacía; probar también payload manipulado. | Web bloquea Guardar. Edge/SQL rechaza con `SIN_DEPARTAMENTOS`/400-409. No aparece alcance global. Si era creación, Auth queda compensado o se reporta recuperación pendiente con `requestId`. |
| 4 | Sólo ve empleados asignados | RPC / RLS / Web | Con empleados en departamento permitido y no permitido, consultar listado como SUPERVISOR. | `listar_empleados_supervisor` y consultas protegidas incluyen únicamente empleados activos de los departamentos explícitos. |
| 5 | Sólo ve jornadas asignadas | RPC / RLS / Web | Consultar jornadas y pendientes de empleados dentro y fuera del alcance. | `listar_jornadas_supervisor`, pendientes y operaciones sólo devuelven/aceptan empleados cuyo departamento está asignado. |
| 6 | Sólo ve incidencias asignadas | RPC / RLS / Web | Consultar y resolver una incidencia propia y otra fuera de alcance. | `listar_incidencias_supervisor` muestra sólo la propia; resolver la externa queda denegado y no modifica filas. |
| 7 | No ve otra sucursal | Web / Edge / SQL | Seleccionar sucursal A e intentar incluir manualmente un department ID activo de sucursal B. | La Web no lo ofrece; SQL devuelve `SUPERVISOR_SCOPE_DEPARTMENT_INVALID`; no cambia el alcance anterior. |
| 8 | No ve otra empresa | Edge / SQL / RLS | Enviar branch/department/profile IDs de otra empresa con JWT válido de la empresa A. | Rechazo 400/404/403 según recurso; ninguna fila de A o B cambia y ninguna consulta devuelve datos cruzados. |
| 9 | URL directa no amplía acceso | Web guard / RPC / RLS | Abrir directamente módulos sin permiso y endpoints con IDs fuera del alcance. | Web muestra 403; aunque se manipule la URL, RPC/RLS devuelve vacío o deniega. El ocultamiento visual no es la única defensa. |
| 10 | IDs manipulados rechazados | Edge / SQL | Enviar UUID inválido, inexistente, duplicado, departamento inactivo, branch nula o combinación branch-department incoherente. | UUID/formato inválido: 400. Duplicados válidos se deduplican. IDs inexistentes, inactivos o incoherentes se rechazan atómicamente sin pérdida del alcance previo. |
| 11 | ADMIN conserva acceso | Web / autorización / módulos | Iniciar sesión ADMIN, crear/editar un acceso no supervisor y navegar módulos administrativos. | No se exigen campos de alcance para ADMIN; la Web no los envía; permisos y alcance administrativo existentes permanecen iguales. |
| 12 | EMPLEADO no hereda alcance | autorización / RLS | Vincular empleado cuyo profile tiene ubicación laboral y comprobar sesión/portal. | `role_code_canonical=EMPLEADO`; sólo ve datos propios. No hereda `perfil_departamentos` de supervisores ni obtiene rutas de supervisor. |
| 13 | Editar agrega departamento | Web / Edge / SQL | Precargar supervisor con D1 y marcar D2 de la misma sucursal. | `update-access` termina correctamente; D1 y D2 quedan asignados, auditoría registra antes/después y la autorización renovada contiene ambos. |
| 14 | Editar elimina departamento | Web / Edge / SQL | Precargar D1+D2 y desmarcar D2 conservando D1. | La sustitución transaccional elimina sólo D2, conserva D1 y registra auditoría. Fallo intermedio no deja alcance parcial. |
| 15 | Cambiar sucursal limpia selección | Web / Edge | Con departamentos marcados en A, cambiar el selector a B. | La Web limpia todos los IDs de A, actualiza contador a cero y bloquea Guardar hasta elegir al menos uno de B. Un payload que conserve IDs de A es rechazado por SQL. |
| 16 | Departamento inactivo no seleccionable | Web / Edge / SQL | Desactivar un departamento, recargar catálogo e intentar guardar su UUID manualmente. | No aparece en la lista activa. SQL rechaza el UUID; un alcance existente que se vuelve inactivo queda inválido y fail-closed hasta conciliación. |
| 17 | Perfil supervisor inactivo sin alcance efectivo | Auth / autorización / SQL | Desactivar el profile y probar login/RPC con token previo; consultar snapshot como administrador. | La sesión del supervisor queda rechazada y `obtener_departamentos_supervisor_actual()` no entrega filas. El administrador puede diagnosticar el snapshot, pero el usuario inactivo no obtiene acceso efectivo. |
| 18 | Cambio de rol limpia alcance | Web / Edge / SQL | Cambiar SUPERVISOR→otro rol con confirmación y luego probar otro rol→SUPERVISOR sin/con selección. | SUPERVISOR→otro limpia relaciones mediante el trigger y audita `DESACTIVAR_ALCANCE_SUPERVISOR`. Otro→SUPERVISOR sin alcance falla; con alcance válido guarda después del cambio de rol en la misma transacción. |
| 19 | Reintento no crea duplicados | Edge / Auth / SQL | Repetir `create-access` con mismo `idempotency_key` y payload; repetir el key con payload distinto; simular pérdida de respuesta. | Mismo key/payload devuelve `idempotent_replay=true` y existe un solo Auth/profile/vínculo/auditoría. Mismo key/payload diferente devuelve `IDEMPOTENCY_KEY_REUSED`. No hay asignaciones duplicadas. |
| 20 | Sesión renovada refleja alcance | Web / Auth / RPC | Modificar D1→D1+D2, renovar autorización o volver a iniciar sesión y repetir consultas. | `department_ids`/`branch_ids` y módulos reflejan inmediatamente el nuevo alcance tras recarga. Dato retirado deja de ser visible; no se usa caché antigua como autoridad. |

En los casos 13 y 14 se debe simular además una respuesta perdida después del
commit: `operation_id` confirma la transacción y la Edge no restaura Auth a un
estado anterior. Si la verificación no está disponible, debe devolver
`auth_restore_pending` sin compensación destructiva.

Prueba complementaria de concurrencia: lanzar dos mutaciones administrativas
sobre el mismo profile y comprobar que la versión operativa evita solaparlas.
La versión 0033 documenta esta serialización como requisito operativo pendiente
de un lock distribuido o control de versión entre Auth y PostgreSQL.

## Pruebas técnicas complementarias

- Ejecutar `pnpm.cmd run test:supervisor-scope`.
- Ejecutar `pnpm.cmd run build`.
- Ejecutar las pruebas SQL de contrato en un entorno local/staging autorizado,
  nunca contra producción.
- Confirmar en logs de Edge que cada error incluye `requestId` y, cuando aplica,
  `stage` y `recovery_status`, sin JWT, email ni UUID sensibles sin sanitizar.
- Repetir postflight y conservar fingerprints de policies/permisos junto con la
  preimagen para demostrar que no cambiaron.

## Evidencia a conservar

- Resultado del postflight.
- Salida de build y pruebas Web.
- Request/response sanitizados de cada acción Edge.
- Conteos y snapshots antes/después de perfiles y asignaciones de prueba.
- Logs sanitizados de compensación Auth e idempotencia.
- Resultado de login y navegación para cada rol.
