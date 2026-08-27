# Rollback y compensacion de la promocion

Estado: procedimiento preparado, no ejecutado. Un rollback no autoriza por si
solo cambios en produccion; cada paso requiere incidente, responsable y target
confirmado.

## Principio de recuperacion

La promocion atraviesa tres limites sin transaccion distribuida:

1. cada archivo de migracion PostgreSQL;
2. Supabase Auth;
3. cada deploy de Edge Function.

Por eso “volver atras” no es un unico comando. Primero se contiene, luego se
determina que confirmo y finalmente se restaura o compensa cada capa desde su
preimagen.

## Rollback transaccional

Las migraciones 0030-0035 contienen su propia transaccion. Si una falla antes de
`COMMIT`, sus cambios se revierten. Sin embargo, las migraciones anteriores del
mismo `db push` pueden haber confirmado y deben considerarse aplicadas.

Ante un error de migracion:

1. detener el lote y no desplegar Edge;
2. capturar el error completo y timestamp UTC;
3. consultar historial, firmas, indices y ACL con SELECT-only;
4. identificar la ultima version confirmada;
5. no reintentar hasta explicar la causa y el estado parcial.

No usar:

- `supabase db reset`;
- `supabase migration repair`;
- `supabase link` o target implicito;
- edicion/eliminacion de una migracion aplicada;
- SQL manual para marcar historial;
- restauracion automatica sin evaluar escrituras posteriores.

## Contencion inmediata

Si el fallo ocurre despues de un commit o deploy:

1. suspender temporalmente altas/ediciones de accesos, supervisores y empleados;
2. no rotar ni borrar secretos salvo evidencia de exposicion;
3. no reintentar operaciones con nuevos UUID;
4. preservar `requestId`, `operation_id`, idempotency key, hashes, logs y
   versiones sin guardar valores secretos;
5. clasificar el incidente como DB, grants, RLS/policy, Edge, Auth o Web;
6. verificar aislamiento multiempresa antes de cualquier reapertura.

El paso 1 debe usar el mecanismo de congelamiento de escrituras preaprobado en
el plan principal. Este repo no ofrece un toggle conocido; si el mecanismo no
fue ensayado antes de la ventana, no existe contencion segura y la promocion no
debe comenzar. No sustituirlo por revocaciones, RLS o borrado de funciones
improvisados.

La perdida o posible perdida de aislamiento requiere cierre inmediato, no una
compensacion en caliente.

## Objetos que no deben borrarse a ciegas

- permisos o asignaciones de `rol_permisos`;
- roles ADMIN/SUPERVISOR;
- `portal.ver_dashboard`, que ya existia en produccion segun la evidencia;
- filas de `perfil_sucursales` añadidas por el backfill de 0033;
- filas de `perfil_departamentos`;
- indices de idempotencia/operation_id;
- auditorias de provisioning, administracion o supervisor;
- profiles tombstoneados o empleados historicos;
- identidades Auth cuyo commit SQL sea incierto;
- triggers o funciones 0034, porque volver al cuerpo anterior reintroduciria
  el error `42703`.

Una vez confirmado un commit, todo cambio compensatorio de DB se entrega como
una migracion nueva, revisada y transaccional.

## Compensacion por migracion

### 0030

La funcion de normalizacion se restaura solo desde la definicion/preimagen
archivada y mediante migracion nueva. Antes de hacerlo, demostrar que las Edge y
las sesiones no dependen de los aliases nuevos. Normalmente es mas seguro
corregir hacia adelante.

### 0031

El upsert puede haber creado permisos, cambiado metadata, reactivado codigos y
normalizado asignaciones ADMIN. La compensacion debe restaurar por ID la
preimagen de cada fila y asignacion. No borrar por `codigo` ni convertir todos
los grants en denegaciones.

### 0032

No borrar `portal.ver_dashboard`. Restaurar solo metadata/asignaciones cuyo
diferencial este probado por la preimagen. Preservar `supervisor.dashboard` y
los permisos no objetivo.

### 0033

No eliminar en bloque el backfill de `perfil_sucursales`: despues del commit no
se puede distinguir con seguridad una fila preexistente de una creada por la
migracion. Mantener el modelo fail-closed, conciliar supervisores legacy y
corregir hacia adelante. No devolver DML directo a clientes como bypass.

### 0034

No restaurar la funcion defectuosa. Cualquier defecto nuevo se corrige hacia
adelante manteniendo ramas explicitas por tabla y operacion.

### 0035

La preimagen del precheck distingue ACL directa y privilegio efectivo. Si se
debe compensar:

1. confirmar que version Edge quedara activa;
2. calcular solo el diferencial respecto de la preimagen;
3. restaurarlo mediante migracion nueva;
4. no ampliar `anon`/`authenticated`;
5. no conceder `DELETE` empleados ni DML de alcance salvo un diseño nuevo
   expresamente aprobado.

No ejecutar un `GRANT ALL` para “recuperar servicio”. Tampoco asumir que un
`REVOKE` directo elimina un privilegio heredado o concedido a PUBLIC: verificar
siempre `has_table_privilege` y la ACL desglosada.

## Reversion de Edge Functions

Solo se puede redeployar la preimagen descargada si se demostro que es
compatible con la version DB que permanece aplicada.

Mientras `deno.json` use `@supabase/supabase-js@2` sin version exacta/lock, la
fuente descargada no es una preimagen binaria reproducible: redeployarla puede
resolver otra dependencia. El rollback Edge queda NO-GO hasta fijar y ensayar la
dependencia o disponer del mismo bundle inmutable validado.

El manifiesto predeploy debe contener los booleanos
`PreviousUserProvisioningVerifyJwt` y `PreviousEmployeeManagementVerifyJwt`, y
el workdir de snapshot debe incluir un `config.toml` preaprobado con esos mismos
valores. Si falta cualquiera, mantener contencion: no asumir `false`.

Comandos futuros, con las variables, `Invoke-CheckedNative` y guardia de target
del plan principal:

```powershell
$UserJwtArgs = if ($PreviousUserProvisioningVerifyJwt -eq $false) {
  @('--no-verify-jwt')
} elseif ($PreviousUserProvisioningVerifyJwt -eq $true) {
  @()
} else {
  throw 'Falta preimagen verify_jwt de user-provisioning'
}
$EmployeeJwtArgs = if ($PreviousEmployeeManagementVerifyJwt -eq $false) {
  @('--no-verify-jwt')
} elseif ($PreviousEmployeeManagementVerifyJwt -eq $true) {
  @()
} else {
  throw 'Falta preimagen verify_jwt de employee-management'
}

Invoke-CheckedNative -Step 'rollback user-provisioning' -Command {
  supabase functions deploy user-provisioning --project-ref "$ProdProjectRef" --workdir "$EdgeSnapshotRoot" @UserJwtArgs
}
Invoke-CheckedNative -Step 'rollback employee-management' -Command {
  supabase functions deploy employee-management --project-ref "$ProdProjectRef" --workdir "$EdgeSnapshotRoot" @EmployeeJwtArgs
}
$RollbackFunctionInventory = Invoke-CheckedNative -Step 'verificar rollback Edge' -Command {
  supabase functions list --project-ref "$ProdProjectRef" --output json
}
$RollbackFunctionInventory | Set-Content -LiteralPath "$EvidenceDir\functions-after-rollback.json"
```

Comparar fuente descargada/hash y `verify_jwt` con la preimagen. No usar
`functions delete`, `--prune` ni desplegar todo el directorio. Si la
preimagen Edge no es compatible con DB 0030-0035, mantener contencion y preparar
un hotfix compatible en vez de un redeploy ciego.

Despues del redeploy, repetir smoke de autenticacion/autorizacion, provisioning,
empleados, aislamiento, compensacion y logs.

## Tratamiento de identidades Auth

Clasificar cada operacion por `requestId` e idempotencia:

- **Commit SQL confirmado:** conservar Auth y reparar el estado secundario; no
  borrar una identidad enlazada a un profile valido.
- **Rollback SQL confirmado y Auth nueva:** usar la compensacion soportada del
  mismo flujo/requestId y confirmar `auth_compensated`.
- **Estado ambiguo:** congelar/bloquear la cuenta, no borrar ni restaurar a
  ciegas, y conciliar `auth.users`, `profiles`, `empleados` y auditorias.
- **Actualizacion Auth previa a fallo SQL:** restaurar email/metadata solo desde
  la preimagen capturada por el flujo y confirmar `auth_restored`.
- **Baja normal:** conservar tombstone/auditoria; no requiere hard-delete.

`auth_cleanup_pending`, `auth_restore_pending`,
`ACCESS_CREATION_RECOVERY_PENDING` o `ACCESS_UPDATE_RECOVERY_PENDING` detienen
la promocion. No reintentar con otra key mientras exista ambiguedad.

## Restauracion completa

PITR/backup fisico es el ultimo recurso. Requiere:

- incidente aprobado y ventana de indisponibilidad;
- punto exacto y perdida de escrituras posteriores evaluada;
- plan de conciliacion Auth, porque DB y Auth pueden no volver al mismo instante;
- redeploy/configuracion Edge por separado;
- validacion de secretos, RLS, policies, ACL y multiempresa posterior.

El dump logico suplementario no sustituye PITR. Este documento no incluye un
comando automatizado de restore para evitar una restauracion destructiva sobre
un target incorrecto.

## Criterios para detener

Detener y mantener contencion ante cualquiera de estos eventos:

- target o historial ambiguo;
- migracion fallida o objeto parcial;
- `0033_backfill_candidates > 0` antes de aplicar;
- grants, RLS o policies distintos del baseline sin aprobacion;
- login o ruta inicial incorrecta para cualquier rol;
- acceso cross-tenant o por fuera del alcance;
- cuenta Auth parcial/ambigua;
- 5xx inesperado o 4xx no explicado;
- auditoria o idempotencia duplicada;
- falta de preimagen Edge o backup verificable.

## Criterios para reabrir

Reabrir solo cuando:

1. historial y objetos coincidan con la decision aprobada;
2. DB y Edge sean compatibles y sus hashes/versions esten archivados;
3. RLS, policies y grants pasen postflight;
4. Auth este conciliado sin estados pending;
5. toda la matriz smoke positiva/negativa pase;
6. los logs de la ventana no muestren errores inesperados;
7. los datos sinteticos esten desactivados/tombstoneados o retenidos solo por
   auditoria;
8. dos responsables documenten el GO de reapertura.
