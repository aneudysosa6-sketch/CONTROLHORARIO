# Plan de prueba en staging del pinning Edge

Estado: validación ejecutada en una ventana autorizada exclusivamente contra
`controlhorario-staging`. Los comandos restantes documentan cómo repetirla;
producción continúa **NO-GO** y no es un target permitido por este plan.

## Resultado validado

- Seis Edge Functions resuelven `@supabase/supabase-js` exactamente en `2.110.2`.
- Validaciones locales de pinning y build: PASS.
- Redeploy de `user-provisioning` v10 en staging: PASS.
- `bootstrap-status`: POST 200.
- Login ADMIN posterior al redeploy: PASS.
- Logs temporales eliminados; permanecen solo errores operativos saneados.

## Condiciones de entrada

- Revisión del diff aprobada y worktree congelado por hash.
- Variable `CONTROLHORARIO_STAGING_PROJECT_REF` cargada por canal seguro.
- Variable `CONTROLHORARIO_PROD_PROJECT_REF` disponible solo para la guardia de
  desigualdad; no se imprime ni se usa como target.
- `SUPABASE_ACCESS_TOKEN` disponible sin mostrar su valor.
- Supabase CLI exactamente `2.109.1`.
- Docker Engine operativo durante todo el bundle.
- Deno `2.5.5` disponible para el check local congelado.
- `supabase/config.toml` conserva `verify_jwt=false` para las seis funciones.
- No usar proyecto vinculado implícito ni `--use-api`.

## Preflight local obligatorio

Ejecutar desde PowerShell:

```powershell
Set-Location -LiteralPath '<REPOSITORY_ROOT>'

$StagingProjectRef = $env:CONTROLHORARIO_STAGING_PROJECT_REF
$ProdProjectRef = $env:CONTROLHORARIO_PROD_PROJECT_REF
if ([string]::IsNullOrWhiteSpace($StagingProjectRef)) {
  throw 'Falta CONTROLHORARIO_STAGING_PROJECT_REF'
}
if (-not [string]::IsNullOrWhiteSpace($ProdProjectRef) -and $StagingProjectRef -eq $ProdProjectRef) {
  throw 'Target rechazado: staging coincide con producción'
}
if ((supabase --version).Trim() -ne '2.109.1') {
  throw 'La ventana exige Supabase CLI 2.109.1'
}
docker info | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Docker no está operativo; no permitir fallback a bundling API'
}

$Functions = @(
  'attendance-sync',
  'device-enrollment',
  'employee-management',
  'employee-sync',
  'employee-upsert',
  'user-provisioning'
)
foreach ($FunctionName in $Functions) {
  $FunctionRoot = Join-Path 'supabase\functions' $FunctionName
  deno check `
    --config (Join-Path $FunctionRoot 'deno.json') `
    --lock (Join-Path $FunctionRoot 'deno.lock') `
    --frozen `
    (Join-Path $FunctionRoot 'index.ts')
  if ($LASTEXITCODE -ne 0) {
    throw "deno check falló para $FunctionName"
  }
}

Push-Location -LiteralPath 'web'
pnpm.cmd run test:edge-dependencies
if ($LASTEXITCODE -ne 0) { throw 'Falló test:edge-dependencies' }
pnpm.cmd run test:supervisor-scope
if ($LASTEXITCODE -ne 0) { throw 'Falló test:supervisor-scope' }
pnpm.cmd run test:employee-code
if ($LASTEXITCODE -ne 0) { throw 'Falló test:employee-code' }
pnpm.cmd run build
if ($LASTEXITCODE -ne 0) { throw 'Falló build Web' }
Pop-Location
```

Antes del primer deploy, capturar mediante el procedimiento operativo aprobado:

- salida de `supabase functions list --project-ref $StagingProjectRef`;
- versión remota anterior de cada función;
- fuente descargada de cada función y hashes SHA-256;
- configuración `verify_jwt` anterior;
- ventana UTC, operador y commit/hash del paquete candidato.

La descarga de fuente es evidencia y preimagen lógica, pero no prueba ni
restaura por sí sola el ESZip anterior cuando su dependencia era flotante.

## Deploy exclusivo a staging

Ejecutar una función por vez. Cada comando conserva `verify_jwt=false`, fuerza
bundling Docker y usa el project-ref explícito de staging:

```powershell
supabase functions deploy attendance-sync --project-ref $StagingProjectRef --no-verify-jwt --use-docker
supabase functions deploy device-enrollment --project-ref $StagingProjectRef --no-verify-jwt --use-docker
supabase functions deploy employee-sync --project-ref $StagingProjectRef --no-verify-jwt --use-docker
supabase functions deploy employee-upsert --project-ref $StagingProjectRef --no-verify-jwt --use-docker
supabase functions deploy employee-management --project-ref $StagingProjectRef --no-verify-jwt --use-docker
supabase functions deploy user-provisioning --project-ref $StagingProjectRef --no-verify-jwt --use-docker
```

Después de cada comando:

1. abortar si el exit code no es cero;
2. volver a comprobar `docker info`;
3. confirmar que el CLI no informó fallback ni bundling server-side;
4. registrar versión remota nueva y timestamp UTC;
5. ejecutar OPTIONS/arranque de módulo antes de avanzar a la siguiente.

No usar:

- `supabase functions deploy` sin nombre;
- `--use-api`;
- `--linked` o target implícito;
- `supabase link`;
- `supabase db push`;
- comandos de secrets durante este cambio.

## Pruebas de humo

Usar solo datos sintéticos con prefijo inequívoco y una empresa QA de staging.

### Carga básica de las seis funciones

- `OPTIONS` responde sin error de inicialización/import.
- No aparecen `Module not found`, errores npm, checksum/integrity, ESZip o
  `WorkerBootError`.
- Cualquier llamada sin credenciales conserva su 401/403 esperado; no se
  interpreta un rechazo de autorización esperado como regresión.

### `user-provisioning`

- `bootstrap-status` conserva su contrato actual.
- Login ADMIN y listado de accesos.
- Crear un usuario EMPLEADO sintético.
- Crear SUPERVISOR con una sucursal y varios departamentos.
- Editar usuario, rol y alcance.
- Repetir la misma `idempotency_key` y verificar replay sin duplicados.
- Forzar el caso ensayado de compensación Auth y confirmar su estado esperado.
- Confirmar `requestId`, `operation_id`, auditoría y aislamiento de empresa.

### `employee-management`

- `next-code` devuelve formato válido.
- Crear y editar un empleado sintético.
- Desactivar/reactivar según el flujo aprobado.
- Confirmar unicidad de código, auditoría y ausencia de acceso cruzado.

### Otras funciones

- `device-enrollment`: enrolamiento/validación con dispositivo QA.
- `employee-sync` y `attendance-sync`: sincronización con payload sintético e
  idempotente; confirmar que no duplica empleados ni jornadas.
- `employee-upsert`: alta/actualización sintética y aislamiento multiempresa.

No reutilizar personas, correos, dispositivos, jornadas o identificadores de
producción. Eliminar o desactivar los fixtures mediante los flujos funcionales
existentes; preservar auditorías obligatorias.

## Logs y evidencia

Para cada función guardar, sin secretos:

- versión/despliegue y `DENO_DEPLOYMENT_ID` observado;
- timestamp UTC y región;
- requestId de los flujos privilegiados;
- códigos HTTP esperados/obtenidos;
- ausencia de 4xx/5xx inesperados y errores de resolución;
- resultado de idempotencia y compensación;
- hashes de `index.ts`, `deno.json` y `deno.lock` desplegados.

## GO / NO-GO

GO para actualizar el paquete de promoción a producción solo si:

- las seis funciones fueron bundleadas localmente con Docker;
- todos los checks congelados y smokes pasan;
- `user-provisioning` y `employee-management` no cambian contratos;
- `verify_jwt`, secrets, permisos y datos permanecen sin cambios no previstos;
- no hay errores nuevos en logs;
- el rollback/compensación fue revisado por un segundo operador.

NO-GO ante cualquier fallback a `--use-api`, drift de project-ref, versión CLI
distinta, lock ignorado, error de módulo, cambio de auth, fallo de aislamiento,
4xx/5xx inesperado o imposibilidad de identificar la preimagen.
