$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$migration = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'supabase/migrations/0003_FINAL.sql')
$edge = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'supabase/functions/user-provisioning/index.ts')
$app = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/App.tsx')
$bootstrapPage = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/BootstrapPage.tsx')
$loginPage = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/LoginPage.tsx')
$bootstrapGate = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/BootstrapGate.tsx')
$provisioningService = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/userProvisioning/userProvisioningService.ts')
$checks = [ordered]@{
  'profiles sin DML de authenticated' = $migration -match 'revoke insert, update, delete on public\.profiles from authenticated'
  'RPC solo service_role' = $migration -match 'grant execute on function public\.provision_user_internal\(jsonb\) to service_role'
  'auditoría inmutable' = $migration -match 'user_provisioning_audit' -and $migration -notmatch 'grant (insert|update|delete).*user_provisioning_audit.*authenticated'
  'validación empresa del rol' = $migration -match 'id = v_role_id and company_id = v_company_id'
  'validación empresa del empleado' = $migration -match 'id = v_employee_id and empresa_id = v_company_id'
  'detección Auth sin profile' = $edge -match 'filter\(u=>!known\.has\(u\.id\)\)'
  'paginación completa de Auth' = $edge -match 'for\(let page=1;;page\+\+\)'
  'tenant forzado por servidor' = $edge -match 'company_id:callerCompanyId'
  'bootstrap cerrado tras primer profile' = $edge -match "count!==0"
  'ruta web protegida' = $app -match 'usuarios/sincronizar' -and $app -match 'usuarios\.administrar'
  'ruta bootstrap publica' = $app -match 'path="/bootstrap"' -and $app.IndexOf('path="/bootstrap"') -lt $app.IndexOf('element={<Protected/>}')
  'secreto bootstrap solo en header' = $provisioningService -match "'x-bootstrap-secret':secret" -and $bootstrapPage -notmatch 'localStorage|sessionStorage|VITE_.*SECRET'
  'formulario bootstrap completo' = @('company_name','legal_name','company_slug','full_name','branch_name','employee_code','America/Santo_Domingo') | ForEach-Object { $bootstrapPage -match $_ } | Where-Object { -not $_ } | Measure-Object | Select-Object -ExpandProperty Count | ForEach-Object { $_ -eq 0 }
  'bloqueo bootstrap con profile' = $bootstrapPage -match "from\('profiles'\)" -and $bootstrapPage -match "navigate\('/dashboard'"
  'estado bootstrap publico sin JWT' = $edge -match "action==='bootstrap-status'" -and $edge.IndexOf("action==='bootstrap-status'") -lt $edge.IndexOf("if(!jwt)")
  'login redirige a bootstrap vacio' = $loginPage -match 'bootstrapStatus' -and $loginPage -match "navigate\('/bootstrap'"
  'bootstrap finaliza en login' = $bootstrapPage -match 'await logout\(\)' -and $bootstrapPage -match "navigate\('/login'"
  'ruta raiz usa BootstrapGate' = $app -match 'path="/" element={<BootstrapGate' -and $app -match 'import\{BootstrapGate\}'
  'gate no depende de sesion' = $bootstrapGate -match 'bootstrapStatus' -and $bootstrapGate -notmatch 'useAuth|getSession|session'
  'gate decide bootstrap o login' = $bootstrapGate -match "bootstrap_required \? '/bootstrap' : '/login'"
  'bootstrap autentica antes de invocar' = $bootstrapPage -match 'signInWithPassword' -and $bootstrapPage.IndexOf('signInWithPassword') -lt $bootstrapPage.IndexOf('userProvisioningService.bootstrap')
  'invoke usa sesion automatica' = $provisioningService -match "functions.invoke\('user-provisioning'" -and $provisioningService -notmatch 'Authorization|Bearer'
  'fallo bootstrap cierra sesion' = $bootstrapPage -match 'if \(loginCompleted\) await logout'
}
$failed = $checks.GetEnumerator() | Where-Object { -not $_.Value }
$checks.GetEnumerator() | ForEach-Object { if ($_.Value) { Write-Host "OK: $($_.Key)" } else { Write-Host "ERROR: $($_.Key)" } }
if ($failed) { throw 'Fallaron contratos de User Provisioning.' }
Write-Host 'Todos los contratos de User Provisioning están presentes.'
