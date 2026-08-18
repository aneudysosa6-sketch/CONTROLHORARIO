# Plan de rollback compensatorio — migración 0033

Estado: documento operativo; no ejecutado

## Principio

0033 cambia contratos de autorización y completa relaciones existentes. No
existe un rollback destructivo seguro y genérico. La estrategia preferida es
*roll-forward*. Cualquier reversión debe preservar asignaciones y auditoría y
restaurar contratos anteriores sólo desde una preimagen verificada.

## Acciones prohibidas

- No borrar masivamente filas de `perfil_sucursales` o
  `perfil_departamentos`.
- No intentar identificar el backfill únicamente por la coincidencia entre la
  sucursal del departamento y `perfil_sucursales`; esa fila pudo existir antes.
- No restaurar alcance desde `profiles.branch_id` o `profiles.department_id`
  como fallback global.
- No desactivar RLS, borrar policies ni conceder `GRANT ALL`.
- No eliminar auditorías o `idempotency_key` para permitir reintentos.
- No restaurar funciones históricas sin confirmar su definición y grants en el
  entorno objetivo.
- No eliminar identidades Auth por email, nombre o aproximación; sólo por UUID y
  evidencia inequívoca de una operación concreta.

## Preimagen obligatoria antes de aplicar 0033

Conservar en almacenamiento seguro:

1. Definición (`pg_get_functiondef`) y ACL de todas las funciones que 0033
   reemplaza.
2. Definición, estado y ACL de triggers relacionados.
3. RLS y fingerprints de todas las policies de `perfil_sucursales` y
   `perfil_departamentos`.
4. ACL de ambas tablas, en especial SELECT/INSERT/UPDATE/DELETE para
   `anon`, `authenticated` y `service_role`.
5. Snapshot de ambas tablas de asignaciones, con perfil, empresa y timestamp.
6. Snapshot de profiles/roles/empleados afectados y sus relaciones.
7. Conteos/fingerprints de `permisos`, `rol_permisos` y `perfil_permisos`.
8. Versión desplegada de Web y `user-provisioning`.

Si no existe esta preimagen, no ejecutar una reversión de contratos: aislar la
función afectada y preparar una migración correctiva hacia adelante.

## Contención inmediata

1. Detener temporalmente nuevas altas y ediciones de SUPERVISOR, sin bloquear
   login de otros roles.
2. Mantener activos los resolvers fail-closed para evitar una ampliación de
   alcance durante el incidente.
3. Capturar `requestId`, `stage`, `recovery_status`, `idempotency_key`, profile
   y UUID Auth afectados.
4. Ejecutar sólo diagnósticos SELECT y clasificar el fallo: Web, Edge, contrato
   SQL, datos legacy o sincronización Auth.

## Reversión por capa

### Web

Se puede volver a la versión Web anterior sólo si las escrituras de alcance de
supervisor quedan deshabilitadas. Una Web antigua no conoce los campos
obligatorios ni los estados de conciliación y no debe crear supervisores
activos sin departamentos.

### Edge Function

Antes de retirar `get-supervisor-scope`, `save-supervisor-scope` o los wrappers
atómicos:

- confirmar que ninguna Web activa los llama;
- drenar solicitudes en curso;
- conservar lectura de `requestId` e idempotencia para operaciones ya iniciadas;
- impedir que la versión anterior llame directamente a `crear_acceso_internal`
  para un SUPERVISOR sin alcance.

Los grants de las funciones nuevas pueden permanecer inertes. Revocarlos o
eliminar las funciones sólo después de retirar todos los consumidores y validar
que no existen recuperaciones pendientes.

### Contratos SQL

Restaurar desde la preimagen, en una nueva migración compensatoria y una sola
transacción, únicamente las definiciones previas que resulten necesarias:

- `listar_accesos_internal(jsonb)`;
- `validar_alcance_supervisor()`;
- `proteger_sucursal_asignada_supervisor()`;
- `validar_cambio_sucursal_supervisor()`;
- `obtener_departamentos_supervisor_actual()`;
- `supervisor_puede_ver_empleado(uuid)`;
- `obtener_mi_autorizacion()`;
- `guardar_departamento_administracion(uuid,jsonb,uuid,text)`.

Antes de restaurar un resolver anterior, demostrar que no vuelve a interpretar
ubicación laboral o ausencia de asignaciones como acceso empresarial. Si amplía
alcance, no restaurarlo; corregir hacia adelante.

Las funciones nuevas y los índices de idempotencia/confirmación son aditivos y pueden
conservarse. Eliminarlos no recupera datos y aumenta el riesgo de reintentos
duplicados.

No restaurar DML directo para `authenticated` sobre las tablas de alcance salvo
que la preimagen y un consumidor vigente demuestren que es imprescindible. Si
se restaura, primero debe existir una estrategia de serialización equivalente a
los RPC protegidos para no reabrir carreras multirrama.

### Datos de alcance

No deshacer el backfill globalmente. Para un perfil concreto:

1. Comparar snapshot anterior, auditoría 0033 y estado actual.
2. Verificar que todas las filas pertenecen a la misma empresa.
3. Restaurar exactamente el conjunto previo sólo si la preimagen identifica
   cada fila con certeza.
4. Validar sucursal/departamentos activos y coherentes antes de reactivar.
5. Registrar una auditoría compensatoria con motivo y operador.

Un supervisor legacy multirrama debe permanecer bloqueado hasta conciliación.
No eliminar ramas para forzar una selección ni reactivar el fallback anterior.

## Reconciliación Auth/PostgreSQL

### Creación fallida

- Si Auth existe pero profile no, comprobar que su metadata contiene el
  `provisioning_request_id` esperado y que no ha iniciado sesión ni fue
  reutilizado. Sólo entonces deshabilitar/eliminar exactamente ese UUID.
- Si profile, empleado y alcance existen y la respuesta se perdió, conservarlos
  y completar el replay con el mismo `idempotency_key`.
- Si `recovery_status=auth_cleanup_pending`, no reintentar con otro key hasta
  resolver el UUID Auth pendiente.

### Actualización fallida

- Buscar primero el `operation_id` exacto en la auditoría transaccional.
- Comparar email/metadata Auth con la preimagen capturada por Edge.
- Si SQL hizo rollback y Auth no se restauró, restaurar únicamente los valores
  previos verificados.
- Si SQL completó, no revertir asignaciones por un fallo secundario de ban o
  auditoría; reparar la sincronización concreta.

## Validación posterior a la compensación

- RLS permanece habilitada y las policies conservan sus fingerprints.
- No existen relaciones cross-company.
- Un SUPERVISOR activo tiene exactamente una sucursal y al menos un departamento
  activo de esa sucursal, o queda fail-closed.
- ADMIN mantiene su contrato y EMPLEADO sólo su autoservicio.
- No hay keys de idempotencia duplicadas ni perfiles/Auth huérfanos.
- Los RPC de empleados, jornadas e incidencias respetan el mismo alcance.
- Web, Edge y SQL desplegados son versiones compatibles entre sí.

## Decisión de cierre

El rollback sólo se considera terminado cuando la autorización no se amplía,
los datos quedan preservados y toda compensación Auth está resuelta. Si alguna
de esas condiciones no puede demostrarse, mantener contención y ejecutar una
migración correctiva hacia adelante.
