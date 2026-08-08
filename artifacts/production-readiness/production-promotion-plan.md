# Plan controlado de promocion a produccion

Estado: preparado para revision. **Ningun comando de este documento fue
ejecutado durante su preparacion.** Produccion permanece **NO-GO** y fuera de
alcance hasta una ventana aprobada.

Estado confirmado de este paquete: staging completo hasta `0036` con historial,
postflight y smoke en PASS. Produccion permanece en `0029`; `0030`-`0036` no se
han ejecutado alli. Backup/PITR verificable y baseline inmutable de las Edge son
requisitos externos pendientes. Toda promocion exige precheck, dry-run,
postflight, smoke con datos sinteticos y rollback aprobado.

## Inventario de la promocion

La evidencia aprobada indica produccion en `0029` y staging validado en
`0030`-`0036`. Esa validacion no autoriza produccion ni sustituye el precheck
remoto futuro.

| Componente | Cambio pendiente | Efecto previsto |
|---|---|---|
| `0030_fix_employee_role_canonicalization.sql` | Funcion de normalizacion | Canonicaliza `EMPLEADOS` y `EMPLOYEES` como `EMPLEADO`. |
| `0031_admin_access_permissions.sql` | Catalogo y asignaciones | Upsert de tres permisos administrativos para roles activos con `upper(code) = 'ADMIN'`. |
| `0032_dashboard_access_permission.sql` | Catalogo y asignaciones | Upsert de `portal.ver_dashboard` para ADMIN/SUPERVISOR activos de codigo exacto. |
| `0033_supervisor_department_assignments.sql` | RPC, ACL e indices | Alcance explicito, idempotencia, contratos transaccionales y revocacion de DML directo autenticado sobre tablas de alcance. |
| `0034_fix_supervisor_scope_trigger_columns.sql` | Funcion trigger | Corrige `auditar_asignacion_supervisor()` para las columnas reales de cada tabla. |
| `0035_service_role_minimum_grants.sql` | ACL reproducible | Grants minimos para las dos Edge Functions y revocaciones directas no deseadas. |
| `0036_service_role_privilege_remediation.sql` | ACL final fail-closed | Revoca el full-set heredado del estado historico y restablece solo la matriz minima validada. |
| `user-provisioning` | Edge Function | Flujo y dependencia fijada validados en staging; baseline inmutable de produccion pendiente. |
| `employee-management` | Edge Function | Flujo y dependencia fijada validados en staging; baseline inmutable de produccion pendiente. |

Configuracion local requerida en `supabase/config.toml`:

```toml
[functions.user-provisioning]
verify_jwt = false

[functions.employee-management]
verify_jwt = false
```

El `false` es intencional: ambos handlers validan el bearer por codigo;
`bootstrap-status` se atiende antes del bearer y `bootstrap` exige JWT mas el
secreto dedicado. El deploy individual repetira `--no-verify-jwt`; no se hara
un `config push` global durante esta promocion.

Secrets/runtime requeridos, solo por nombre:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `USER_PROVISIONING_BOOTSTRAP_SECRET`, solo si produccion conserva habilitado
  el flujo bootstrap. Si se omite deliberadamente, bootstrap queda cerrado.

Credenciales operativas requeridas por el runbook, tambien solo por nombre:

- `SUPABASE_ACCESS_TOKEN`
- `CONTROLHORARIO_PROD_DB_URL`
- `CONTROLHORARIO_PROD_PROJECT_REF`
- `CONTROLHORARIO_APPROVED_PROD_PROJECT_REF`
- `CONTROLHORARIO_PROD_PUBLISHABLE_KEY`
- `CONTROLHORARIO_PROD_EDGE_SECRETS_FILE`, solo si hay un secreto custom faltante
- `CONTROLHORARIO_STAGING_PROJECT_REF`
- `CONTROLHORARIO_STAGING_VALIDATION_MANIFEST`
- `CONTROLHORARIO_PROMOTION_EVIDENCE_DIR`

Grants manuales detectados en staging y convertidos a `0035`-`0036`:

- `SELECT` sobre `public.profiles` para `service_role`;
- `SELECT`, `INSERT`, `UPDATE` sobre `public.empleados` para `service_role`;
- `SELECT` sobre `public.roles` para `service_role`.

No se concede `DELETE` sobre empleados ni DML directo sobre
`perfil_sucursales`/`perfil_departamentos`. La accion legacy
`user-provisioning/list` tambien lee `public.companies`; no tiene consumidor Web
actual y no se amplio la matriz final por ella. El precheck exige que su `SELECT` efectivo
ya exista si se decide conservar ese contrato legacy.

### Diferencias conocidas y pendientes de reconfirmacion

| Area | Staging validado | Produccion segun evidencia historica | Decision de promocion |
|---|---|---|---|
| Historial | 0030-0036 aplicadas; historial, postflight y smoke PASS | 0029 como ultima version confirmada | Reconfirmar y aplicar 0030-0036 solo tras todos los gates. |
| Funciones/indices | Contratos e indices 0033 presentes; trigger function 0034 corregida | No deben estar sin history correspondiente | Cualquier objeto adelantado es drift/NO-GO. |
| Schema base | Sin tablas o columnas nuevas en 0030-0034 | Debe conservar tablas/columnas prerrequisito | El precheck inventaria tipos, constraints y owners. |
| Grants | Matriz minima `service_role` validada por 0035-0036 | Full-set historico confirmado; remediacion aun no aplicada | 0036 revoca todo y concede solo el minimo, con guard fail-closed. |
| RLS/policies | Permanecen habilitados/sin cambio esperado | Baseline remoto por capturar | Comparar huellas antes/despues; ninguna diferencia no aprobada. |
| Catalogo | Permisos administrativos y dashboard ya validados | `portal.ver_dashboard`/ADMIN existian en evidencia previa | 0031/0032 son idempotentes, pero pueden reactivar metadata/asignaciones legacy. |
| Roles/datos | SUPERVISOR y alcance multiple validados | No habia evidencia remota de SUPERVISOR | Es dato tenant: preparar un rol/fixture QA por flujo aprobado, no sembrarlo a ciegas. |
| Alcance | Sucursal/departamentos consistentes | Estado legacy desconocido | `0033_backfill_candidates` debe ser cero con el orden normal. |
| Edge | Ambas versiones nuevas validadas | Versiones remotas por inventariar | Capturar preimagen y desplegar solo despues de DB. |
| Config | Dos entradas `verify_jwt=false` presentes | Config remota no asumida | Deploy individual con `--no-verify-jwt`; sin `config push` global. |

Los artefactos existentes solo prueban un snapshot historico de produccion; no
autorizan afirmar el estado remoto actual sin el precheck futuro.

### Requisito externo de baseline Edge

Las seis Edge fijan `@supabase/supabase-js` en `2.110.2` y cuentan con lock
reproducible. El riesgo de dependencia flotante queda cerrado en el repositorio,
pero produccion permanece **NO-GO** hasta capturar su baseline inmutable,
aprobar hashes y ensayar despliegue y rollback sin volver a resolver
dependencias. Ese baseline es evidencia externa y no se crea en este commit.

## Guardia obligatoria de entorno

Existe una ambiguedad local peligrosa: `supabase/config.toml` identifica el
proyecto de produccion, mientras los metadatos temporales de enlace apuntan a
staging. Por eso ningun comando de este plan usa `--linked`, `supabase link` ni
el target implicito del worktree.

En la ventana futura, dos operadores deben obtener el project-ref aprobado por
un canal controlado y ejecutar esta guardia sin imprimir URLs, claves o tokens:

```powershell
Set-Location -LiteralPath '<REPOSITORY_ROOT>'

$ErrorActionPreference = 'Stop'

function Invoke-CheckedNative {
  param(
    [Parameter(Mandatory)] [string] $Step,
    [Parameter(Mandatory)] [scriptblock] $Command
  )
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "$Step fallo con exit code $LASTEXITCODE" }
}

function Invoke-ReadOnlySqlFile {
  param(
    [Parameter(Mandatory)] [string] $InputFile,
    [Parameter(Mandatory)] [string] $OutputFile,
    [Parameter(Mandatory)] [string] $Step
  )
  $PreviousPgOptions = [Environment]::GetEnvironmentVariable('PGOPTIONS', 'Process')
  try {
    $ReadOnlyOption = '-c default_transaction_read_only=on'
    $env:PGOPTIONS = if ([string]::IsNullOrWhiteSpace($PreviousPgOptions)) {
      $ReadOnlyOption
    } else {
      "$PreviousPgOptions $ReadOnlyOption"
    }
    Invoke-CheckedNative -Step $Step -Command {
      psql "$ProdDbUrl" -X -v ON_ERROR_STOP=1 -f $InputFile -o $OutputFile
    }
  } finally {
    if ($null -eq $PreviousPgOptions) {
      Remove-Item Env:PGOPTIONS -ErrorAction SilentlyContinue
    } else {
      $env:PGOPTIONS = $PreviousPgOptions
    }
  }
}

$ProdProjectRef = $env:CONTROLHORARIO_PROD_PROJECT_REF
$ApprovedProdProjectRef = $env:CONTROLHORARIO_APPROVED_PROD_PROJECT_REF
$ProdDbUrl = $env:CONTROLHORARIO_PROD_DB_URL
$ProdPublishableKey = $env:CONTROLHORARIO_PROD_PUBLISHABLE_KEY
$EvidenceRoot = $env:CONTROLHORARIO_PROMOTION_EVIDENCE_DIR

if ([string]::IsNullOrWhiteSpace($ProdProjectRef)) { throw 'Falta el project-ref de produccion' }
if ([string]::IsNullOrWhiteSpace($ApprovedProdProjectRef)) { throw 'Falta el project-ref aprobado por segundo operador' }
if ($ProdProjectRef -cne $ApprovedProdProjectRef) { throw 'Los project-ref aprobados no coinciden' }
if ([string]::IsNullOrWhiteSpace($ProdDbUrl)) { throw 'Falta el DB URL de produccion' }
if ($ProdDbUrl -notlike "*$ProdProjectRef*") { throw 'El DB URL no corresponde al project-ref aprobado' }
if ([string]::IsNullOrWhiteSpace($ProdPublishableKey)) { throw 'Falta publishable key de produccion' }
if ([string]::IsNullOrWhiteSpace($env:SUPABASE_ACCESS_TOKEN)) { throw 'Falta SUPABASE_ACCESS_TOKEN' }
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) { throw 'Falta el directorio seguro de evidencia' }

$RunId = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$EvidenceDir = Join-Path $EvidenceRoot "controlhorario-prod-$RunId"
New-Item -ItemType Directory -Path $EvidenceDir -ErrorAction Stop | Out-Null

$SupabaseCliVersion = Invoke-CheckedNative -Step 'leer version Supabase CLI' -Command { supabase --version }
$PsqlVersion = Invoke-CheckedNative -Step 'leer version psql' -Command { psql --version }
$SupabaseCliVersion | Set-Content -LiteralPath "$EvidenceDir\supabase-cli-version.txt"
$PsqlVersion | Set-Content -LiteralPath "$EvidenceDir\psql-version.txt"
```

No se debe escribir el contenido de esas variables en consola, transcript,
artefactos, historial del shell ni repositorio.

### Gate previo de paridad con staging

Con la guardia ya inicializada y antes de abrir la ventana de produccion, debe
existir evidencia aprobada de que:

1. 0030-0036 se aplicaron en staging y `0036_HISTORY`, `0036_POSTFLIGHT` y
   `0036_SMOKE` quedaron en PASS;
2. el manifiesto SHA-256 de 0030-0036 corresponde exactamente a los archivos que
   se promoveran;
3. las fuentes **realmente desplegadas** de ambas Edge en staging coinciden con
   `index.ts` y `deno.json` congelados localmente;
4. build y tests se ejecutaron sobre esa misma revision.
5. la version fijada y los locks Edge corresponden al baseline aprobado para
   promocion y rollback.

Descargar las Edge de staging con project-ref explicito a un workdir aislado y
comparar cada par; cualquier diferencia es NO-GO:

```powershell
$StagingProjectRef = $env:CONTROLHORARIO_STAGING_PROJECT_REF
if ([string]::IsNullOrWhiteSpace($StagingProjectRef)) { throw 'Falta project-ref de staging' }

$StagingSnapshotRoot = Join-Path $EvidenceRoot "staging-validated-$RunId"
New-Item -ItemType Directory -Path "$StagingSnapshotRoot\supabase" -Force | Out-Null
Copy-Item -LiteralPath 'supabase/config.toml' -Destination "$StagingSnapshotRoot\supabase\config.toml"

Invoke-CheckedNative -Step 'descargar user-provisioning de staging' -Command {
  supabase functions download user-provisioning --project-ref "$StagingProjectRef" --use-api --workdir "$StagingSnapshotRoot"
}
Invoke-CheckedNative -Step 'descargar employee-management de staging' -Command {
  supabase functions download employee-management --project-ref "$StagingProjectRef" --use-api --workdir "$StagingSnapshotRoot"
}

$ParityPairs = @(
  @('supabase/functions/user-provisioning/index.ts', "$StagingSnapshotRoot\supabase\functions\user-provisioning\index.ts"),
  @('supabase/functions/user-provisioning/deno.json', "$StagingSnapshotRoot\supabase\functions\user-provisioning\deno.json"),
  @('supabase/functions/employee-management/index.ts', "$StagingSnapshotRoot\supabase\functions\employee-management\index.ts"),
  @('supabase/functions/employee-management/deno.json', "$StagingSnapshotRoot\supabase\functions\employee-management\deno.json")
)
foreach ($Pair in $ParityPairs) {
  $LocalHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Pair[0]).Hash
  $StagingHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Pair[1]).Hash
  if ($LocalHash -cne $StagingHash) { throw "Fuente desplegada en staging no coincide: $($Pair[0])" }
}

$ValidationManifestPath = $env:CONTROLHORARIO_STAGING_VALIDATION_MANIFEST
if ([string]::IsNullOrWhiteSpace($ValidationManifestPath)) {
  throw 'Falta ruta del manifiesto aprobado de staging'
}
if (-not (Test-Path -LiteralPath $ValidationManifestPath -PathType Leaf)) {
  throw 'Falta manifiesto aprobado de validacion staging'
}
$ApprovedHashes = Import-Csv -LiteralPath $ValidationManifestPath
$MigrationFiles = 30..35 | ForEach-Object {
  Get-ChildItem -LiteralPath 'supabase/migrations' -Filter ("{0:D4}_*.sql" -f $_)
}
foreach ($File in $MigrationFiles) {
  $RelativePath = $File.FullName.Substring((Get-Location).Path.Length + 1).Replace('\', '/')
  $Approved = $ApprovedHashes | Where-Object { $_.RelativePath -ceq $RelativePath }
  if ($Approved.Count -ne 1) { throw "Manifiesto staging incompleto o duplicado: $RelativePath" }
  $Observed = (Get-FileHash -Algorithm SHA256 -LiteralPath $File.FullName).Hash
  if ($Observed -cne $Approved.SHA256) { throw "Hash distinto al validado en staging: $RelativePath" }
}
```

Este gate es de preparacion futura; no fue ejecutado al crear el paquete.

## 1. Backup y punto de restauracion

Antes de la ventana:

1. Confirmar backup administrado/PITR, timestamp, retencion y responsable.
2. Confirmar que el procedimiento de restauracion fue ensayado.
3. Registrar el punto de restauracion aprobado.
4. Crear dumps logicos suplementarios en almacenamiento cifrado fuera del repo.

Comandos futuros de backup suplementario:

```powershell
Invoke-CheckedNative -Step 'dump schema public' -Command {
  supabase db dump --db-url "$ProdDbUrl" --schema public --file "$EvidenceDir\schema-public.sql"
}
Invoke-CheckedNative -Step 'dump schema private' -Command {
  supabase db dump --db-url "$ProdDbUrl" --schema private --file "$EvidenceDir\schema-private.sql"
}
Invoke-CheckedNative -Step 'dump datos public' -Command {
  supabase db dump --db-url "$ProdDbUrl" --schema public --data-only --use-copy --file "$EvidenceDir\data-public.sql"
}
Invoke-CheckedNative -Step 'dump roles' -Command {
  supabase db dump --db-url "$ProdDbUrl" --role-only --file "$EvidenceDir\roles.sql"
}

Get-FileHash -Algorithm SHA256 -LiteralPath `
  "$EvidenceDir\schema-public.sql", `
  "$EvidenceDir\schema-private.sql", `
  "$EvidenceDir\data-public.sql", `
  "$EvidenceDir\roles.sql"
```

Los dumps pueden contener PII o metadatos sensibles: no se versionan y no
sustituyen PITR. Sin punto de restauracion verificable, el resultado es NO-GO.

### Gate de artefacto posterior al backup

El worktree actual contiene cambios no consolidados. La promocion real debe
partir de un artefacto inmutable revisado, no del estado mutable de una sesion.

```powershell
$GitStatus = Invoke-CheckedNative -Step 'git status' -Command { git status --short }
$GitDiffCheck = Invoke-CheckedNative -Step 'git diff check' -Command { git diff --check }
$GitRevision = Invoke-CheckedNative -Step 'git revision' -Command { git rev-parse HEAD }
$GitStatus | Set-Content -LiteralPath "$EvidenceDir\git-status.txt"
$GitDiffCheck | Set-Content -LiteralPath "$EvidenceDir\git-diff-check.txt"
$GitRevision | Set-Content -LiteralPath "$EvidenceDir\git-revision.txt"

Get-FileHash -Algorithm SHA256 -LiteralPath `
  'supabase/migrations/0030_fix_employee_role_canonicalization.sql', `
  'supabase/migrations/0031_admin_access_permissions.sql', `
  'supabase/migrations/0032_dashboard_access_permission.sql', `
  'supabase/migrations/0033_supervisor_department_assignments.sql', `
  'supabase/migrations/0034_fix_supervisor_scope_trigger_columns.sql', `
  'supabase/migrations/0035_service_role_minimum_grants.sql', `
  'supabase/migrations/0036_service_role_privilege_remediation.sql', `
  'supabase/functions/user-provisioning/index.ts', `
  'supabase/functions/user-provisioning/deno.json', `
  'supabase/functions/user-provisioning/deno.lock', `
  'supabase/functions/employee-management/index.ts', `
  'supabase/functions/employee-management/deno.json', `
  'supabase/functions/employee-management/deno.lock', `
  'supabase/config.toml', `
  'artifacts/production-readiness/production-promotion-precheck.sql', `
  'artifacts/production-readiness/migration-0030-production-postflight.sql', `
  'artifacts/production-readiness/migration-0031-postflight.sql', `
  'artifacts/production-readiness/migration-0032-production-postflight.sql', `
  'artifacts/production-readiness/migration-0033-postflight.sql', `
  'artifacts/production-readiness/migration-0034-postflight.sql', `
  'artifacts/production-readiness/migration-0035-postflight.sql', `
  'artifacts/production-readiness/migration-0036-postflight.sql', `
  'artifacts/production-readiness/production-promotion-plan.md', `
  'artifacts/production-readiness/production-smoke-test-plan.md', `
  'artifacts/production-readiness/production-promotion-rollback.md'
```

Archivar commit/revision, hashes, aprobadores y hora UTC. Un diff distinto o un
archivo extra invalida la aprobacion. Antes de congelar, repetir la comprobacion
estatica SELECT-only; el modo read-only de sesion es defensa adicional, no
sustituto del hash revisado.

## 2. Ejecutar precheck

Los siguientes comandos son para la ventana futura:

```powershell
Invoke-ReadOnlySqlFile `
  -InputFile 'artifacts/production-readiness/production-promotion-precheck.sql' `
  -OutputFile "$EvidenceDir\production-precheck.txt" `
  -Step 'precheck produccion'

$MigrationInventory = Invoke-CheckedNative -Step 'listar migraciones' -Command {
  supabase migration list --db-url "$ProdDbUrl"
}
$FunctionInventory = Invoke-CheckedNative -Step 'listar Edge Functions' -Command {
  supabase functions list --project-ref "$ProdProjectRef" --output json
}
$SecretInventory = Invoke-CheckedNative -Step 'listar nombres de secrets' -Command {
  supabase secrets list --project-ref "$ProdProjectRef"
}
$MigrationInventory | Set-Content -LiteralPath "$EvidenceDir\migration-list-before.txt"
$FunctionInventory | Set-Content -LiteralPath "$EvidenceDir\functions-before.json"
$SecretInventory | Set-Content -LiteralPath "$EvidenceDir\secret-names-before.txt"
```

El precheck debe mostrar:

- historial 0001-0029 completo y 0030-0036 ausente;
- `migration_0033_backfill_candidates = 0`;
- cero duplicados de las claves parciales de idempotencia/operation_id;
- triggers legacy presentes y correctamente enlazados;
- `auditar_asignacion_supervisor()` presente desde 0009, pero wrappers/indices
  0033 ausentes; cualquier otro drift debe explicarse;
- cero inconsistencias multiempresa o de alcance;
- RLS habilitado y baseline de policies archivado;
- roles/codigos/permisos compatibles y al menos un SUPERVISOR de QA viable;
- preimagen de grants y conteos de impacto aceptada.

La salida de funciones debe registrar el modo `verify_jwt` previo de ambas Edge.
Si el CLI no lo expone, capturarlo en Dashboard/Management API y anexarlo al
manifiesto aprobado; sin ese dato no existe rollback Edge completo.

Antes de aceptar las revocaciones de 0035-0036, inventariar funciones externas,
integraciones y jobs que no viven en este repositorio. Si alguno usa DML directo
de `service_role` sobre profiles, roles o tablas de alcance, es NO-GO hasta
migrarlo a RPC o revisar la matriz final.

El precheck debe registrar los candidatos del backfill 0033. La migracion instala
la funcion auditora corregida antes del DML; cualquier inconsistencia
multiempresa, fallo de trigger o resultado inesperado sigue siendo NO-GO.

## 3. Confirmar migraciones pendientes y capturar Edge anterior

Confirmar primero que el inventario del paso 2 termina en 0029 y que solo
0030-0036 estan pendientes. Luego descargar las dos versiones Edge remotas en un
workdir aislado, nunca encima de las fuentes aprobadas:

```powershell
$EdgeSnapshotRoot = Join-Path $EvidenceDir 'edge-before'
New-Item -ItemType Directory -Path "$EdgeSnapshotRoot\supabase" -Force | Out-Null
Copy-Item -LiteralPath 'supabase/config.toml' -Destination "$EdgeSnapshotRoot\supabase\config.toml"

Invoke-CheckedNative -Step 'capturar user-provisioning anterior' -Command {
  supabase functions download user-provisioning --project-ref "$ProdProjectRef" --use-api --workdir "$EdgeSnapshotRoot"
}
Invoke-CheckedNative -Step 'capturar employee-management anterior' -Command {
  supabase functions download employee-management --project-ref "$ProdProjectRef" --use-api --workdir "$EdgeSnapshotRoot"
}

Get-FileHash -Algorithm SHA256 -LiteralPath `
  "$EdgeSnapshotRoot\supabase\functions\user-provisioning\index.ts", `
  "$EdgeSnapshotRoot\supabase\functions\user-provisioning\deno.json", `
  "$EdgeSnapshotRoot\supabase\functions\employee-management\index.ts", `
  "$EdgeSnapshotRoot\supabase\functions\employee-management\deno.json"
```

Archivar versiones, timestamps, hashes y los dos valores booleanos `verify_jwt`
previos en un manifiesto controlado. Preparar y hashear tambien un
`config.toml` de rollback que reproduzca exactamente esos valores; el config
local nuevo no sirve como preimagen. No guardar tokens. Sin preimagen Edge y
gateway recuperable: NO-GO.

## 4. Dry-run de migraciones

```powershell
$DryRun = Invoke-CheckedNative -Step 'dry-run 0030-0036' -Command {
  supabase db push --db-url "$ProdDbUrl" --dry-run
}
$DryRun | Set-Content -LiteralPath "$EvidenceDir\db-push-dry-run.txt"
```

Debe enumerar **solo** `0030`, `0031`, `0032`, `0033`, `0034`, `0035` y `0036`, en ese
orden. No usar `--include-all`, `--include-seed`, `--include-roles`, `--yes`,
`migration repair`, `db reset` ni target enlazado.

## 5. Aplicar migraciones

Solo tras GO formal:

```powershell
Invoke-CheckedNative -Step 'aplicar 0030-0036' -Command {
  supabase db push --db-url "$ProdDbUrl"
}
$MigrationInventoryAfter = Invoke-CheckedNative -Step 'confirmar historial posterior' -Command {
  supabase migration list --db-url "$ProdDbUrl"
}
$MigrationInventoryAfter | Set-Content -LiteralPath "$EvidenceDir\migration-list-after.txt"
```

El CLI aplica el lote en orden. Cada archivo es transaccional, pero las
migraciones anteriores pueden haber confirmado si una posterior falla. Ante
cualquier error: detener, no desplegar Edge y consultar historial/objetos.

Si el proceso exige una pausa real entre migraciones, se debe aprobar otro
procedimiento con artefactos aislados. No ejecutar archivos manualmente con
`psql` ni manipular el historial para simular pasos individuales.

## 6. Postflight por migracion

Los postflights se ejecutan despues del lote y se archivan por separado:

```powershell
Invoke-ReadOnlySqlFile -Step 'postflight 0030' `
  -InputFile 'artifacts/production-readiness/migration-0030-production-postflight.sql' `
  -OutputFile "$EvidenceDir\postflight-0030.txt"

Invoke-ReadOnlySqlFile -Step 'postflight DB 0031' `
  -InputFile 'artifacts/production-readiness/migration-0031-postflight.sql' `
  -OutputFile "$EvidenceDir\postflight-0031.txt"

Invoke-ReadOnlySqlFile -Step 'postflight 0032' `
  -InputFile 'artifacts/production-readiness/migration-0032-production-postflight.sql' `
  -OutputFile "$EvidenceDir\postflight-0032.txt"

Invoke-ReadOnlySqlFile -Step 'postflight 0033' `
  -InputFile 'artifacts/production-readiness/migration-0033-postflight.sql' `
  -OutputFile "$EvidenceDir\postflight-0033.txt"

Invoke-ReadOnlySqlFile -Step 'postflight 0034' `
  -InputFile 'artifacts/production-readiness/migration-0034-postflight.sql' `
  -OutputFile "$EvidenceDir\postflight-0034.txt"

Invoke-ReadOnlySqlFile -Step 'postflight 0035' `
  -InputFile 'artifacts/production-readiness/migration-0035-postflight.sql' `
  -OutputFile "$EvidenceDir\postflight-0035.txt"

Invoke-ReadOnlySqlFile -Step 'postflight 0036' `
  -InputFile 'artifacts/production-readiness/migration-0036-postflight.sql' `
  -OutputFile "$EvidenceDir\postflight-0036.txt"
```

No se usa `migration-0030-postflight.sql` porque su encabezado limita la
ejecucion a staging. Tampoco se usa el 0032 generico con hashes `NULL`: la
variante de produccion emite las mismas tres huellas que el precheck y el
operador debe exigir igualdad exacta. El postflight 0031 ejecutado por psql es
solo DB; su validacion con JWT ADMIN se completa en SM-03 y las rutas
administrativas. Comparar ACL/RLS/policies/catalogo contra la preimagen; sin
baseline, “no cambio” no puede declararse PASS.

## 7. Configurar o verificar secrets

Primero, solo inventario:

```powershell
$SecretInventoryBeforeDeploy = Invoke-CheckedNative -Step 'revalidar nombres de secrets' -Command {
  supabase secrets list --project-ref "$ProdProjectRef"
}
$SecretInventoryBeforeDeploy | Set-Content -LiteralPath "$EvidenceDir\secret-names-predeploy.txt"
```

No intentar sobrescribir los `SUPABASE_*` administrados por la plataforma. Si
falta un secreto personalizado aprobado, cargarlo desde un archivo seguro fuera
del repositorio, nunca como `NAME=VALUE` inline:

```powershell
$SecretFile = $env:CONTROLHORARIO_PROD_EDGE_SECRETS_FILE
if ([string]::IsNullOrWhiteSpace($SecretFile)) {
  throw 'Falta archivo seguro de secrets aprobado'
}
if (-not (Test-Path -LiteralPath $SecretFile -PathType Leaf)) {
  throw 'El archivo seguro de secrets no existe'
}
$SecretNames = Get-Content -LiteralPath $SecretFile |
  Where-Object { $_ -match '^\s*[A-Za-z_][A-Za-z0-9_]*\s*=' } |
  ForEach-Object { (($_ -split '=', 2)[0]).Trim() }
if ($SecretNames.Count -ne 1 -or $SecretNames[0] -cne 'USER_PROVISIONING_BOOTSTRAP_SECRET') {
  throw 'El env-file debe contener exclusivamente USER_PROVISIONING_BOOTSTRAP_SECRET'
}

Invoke-CheckedNative -Step 'configurar secreto bootstrap aprobado' -Command {
  supabase secrets set --env-file "$SecretFile" --project-ref "$ProdProjectRef"
}
```

## 8. Desplegar Edge Functions

Solo despues de que 0033, 0034, 0035 y 0036 hayan pasado sus postflights:

```powershell
Invoke-CheckedNative -Step 'deploy user-provisioning' -Command {
  supabase functions deploy user-provisioning --project-ref "$ProdProjectRef" --no-verify-jwt
}
Invoke-CheckedNative -Step 'deploy employee-management' -Command {
  supabase functions deploy employee-management --project-ref "$ProdProjectRef" --no-verify-jwt
}

$FunctionInventoryAfter = Invoke-CheckedNative -Step 'confirmar versiones Edge' -Command {
  supabase functions list --project-ref "$ProdProjectRef" --output json
}
$FunctionInventoryAfter | Set-Content -LiteralPath "$EvidenceDir\functions-after.json"

$EdgeAfterRoot = Join-Path $EvidenceDir 'edge-after'
New-Item -ItemType Directory -Path "$EdgeAfterRoot\supabase" -Force | Out-Null
Copy-Item -LiteralPath 'supabase/config.toml' -Destination "$EdgeAfterRoot\supabase\config.toml"
Invoke-CheckedNative -Step 'descargar user-provisioning posterior' -Command {
  supabase functions download user-provisioning --project-ref "$ProdProjectRef" --use-api --workdir "$EdgeAfterRoot"
}
Invoke-CheckedNative -Step 'descargar employee-management posterior' -Command {
  supabase functions download employee-management --project-ref "$ProdProjectRef" --use-api --workdir "$EdgeAfterRoot"
}

$PostDeployPairs = @(
  @('supabase/functions/user-provisioning/index.ts', "$EdgeAfterRoot\supabase\functions\user-provisioning\index.ts"),
  @('supabase/functions/user-provisioning/deno.json', "$EdgeAfterRoot\supabase\functions\user-provisioning\deno.json"),
  @('supabase/functions/employee-management/index.ts', "$EdgeAfterRoot\supabase\functions\employee-management\index.ts"),
  @('supabase/functions/employee-management/deno.json', "$EdgeAfterRoot\supabase\functions\employee-management\deno.json")
)
foreach ($Pair in $PostDeployPairs) {
  if ((Get-FileHash -Algorithm SHA256 -LiteralPath $Pair[0]).Hash -cne
      (Get-FileHash -Algorithm SHA256 -LiteralPath $Pair[1]).Hash) {
    throw "Deploy Edge no coincide con artefacto aprobado: $($Pair[0])"
  }
}
```

No usar `--prune`, no desplegar otras funciones y no hacer `config push` global.
Confirmar ademas que ambas funciones quedaron con `verify_jwt=false`; el hash de
fuente no prueba la configuracion del gateway.

## 9. Pruebas de humo con datos sinteticos

Ejecutar la matriz de `production-smoke-test-plan.md`. Como primer control:

```powershell
$Headers = @{
  apikey = $ProdPublishableKey
  'Content-Type' = 'application/json'
}
$Body = @{ action = 'bootstrap-status' } | ConvertTo-Json -Compress

$BootstrapStatus = Invoke-RestMethod `
  -Method Post `
  -Uri "https://$ProdProjectRef.supabase.co/functions/v1/user-provisioning" `
  -Headers $Headers `
  -Body $Body

if ($BootstrapStatus.bootstrap_required -ne $false) {
  throw 'bootstrap-status no confirma tenant inicializado'
}
```

Esperado: HTTP 200 y `bootstrap_required = false`. No registrar tokens,
contraseñas ni payloads con PII.

## 10. Verificacion de logs

Usar Dashboard/Logs Explorer para la ventana UTC, filtrando por funcion,
`requestId` y `operation_id`. El CLI previsto no ofrece un comando estable de
logs para este flujo.

Riesgos residuales a aceptar expresamente: `verify_jwt=false` desplaza toda la
validacion JWT a los handlers y ambas Edge responden con CORS `*`. Este paquete
no cambia CORS. SM-02 debe demostrar fail-closed sin bearer/malformed bearer y
los tests negativos de rutas deben confirmar que CORS no equivale a autorizacion.

El repositorio no contiene un feature flag conocido para congelar solo estas
escrituras. Antes del GO, el operador de hosting/gateway debe registrar y ensayar
un mecanismo reversible concreto de mantenimiento o bloqueo de altas/ediciones,
incluida su verificacion. No se debe improvisar con `REVOKE`, borrar funciones o
cambiar RLS durante un incidente.

## 11. Criterios GO/NO-GO

GO requiere simultaneamente:

- target confirmado por dos operadores;
- backup/PITR y restauracion verificables;
- 0030-0036 validadas en staging y paridad por hash de migraciones/Edge demostrada;
- dependencia Edge exacta/bundle inmutable revalidado y rollback ensayado;
- artefacto inmutable y hashes aprobados;
- precheck sin blockers y dry-run exacto 0030-0036;
- postflights completos;
- grants exactos, sin `DELETE` empleados ni DML directo de alcance;
- consumidores externos inventariados y compatibles con las revocaciones 0035-0036;
- mecanismo reversible de congelamiento de altas/ediciones identificado,
  ensayado y registrado por el operador de la plataforma;
- RLS/policies sin diferencias no aprobadas;
- secrets presentes sin exponer valores;
- Edge/DB compatibles;
- smoke positivo y negativo completo;
- logs sin 4xx/5xx inesperados ni recuperacion Auth pendiente.

NO-GO inmediato ante target ambiguo, historial divergente, backfill inconsistente,
objeto conflictivo, duplicado, inconsistencia multiempresa, rol SUPERVISOR no
preparado para QA, evidencia staging incompleta, hash distinto, consumidor externo
incompatible, baseline Edge ausente, ausencia de mecanismo de contencion,
cambio ACL/RLS/policy no previsto, 5xx no explicado,
`auth_cleanup_pending`, `auth_restore_pending` o fuga de datos.

## 12. Rollback o compensacion

Ante NO-GO posterior a un cambio:

1. cerrar temporalmente altas/ediciones afectadas;
2. conservar requestIds, hashes, versiones, pre/postflight y logs;
3. identificar la ultima migracion confirmada;
4. no borrar objetos ni reparar historial a ciegas;
5. aplicar el procedimiento de `production-promotion-rollback.md`;
6. reabrir solo con DB, Edge, Auth, RLS y grants conciliados.

Toda compensacion de base confirmada se implementa como migracion nueva
revisada. Una restauracion PITR es el ultimo recurso y requiere evaluar las
escrituras posteriores al punto de restauracion.
