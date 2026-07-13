$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$repository = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/java/repository/AppUserRepository.kt')
$viewModel = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/java/ui/login/AppUserViewModel.kt')
$loginTests = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/test/java/repository/AppUserRepositoryTest.kt')
$app = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/App.tsx')
$adminDashboard = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/Rc2DashboardPage.tsx')
$supervisorDashboard = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/SupervisorPages.tsx')
$diagnostics = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/dashboard/dashboardDiagnostics.ts')
$checks = [ordered]@{
  'correo y username toman rutas distintas' = $repository -match "'@' in trimmed" -and $repository -match 'trimmed\.lowercase\(\)'
  'correo se resuelve separado del username' = (Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/java/database/AppUserDao.kt')) -match 'username = :identifier[\s\S]*email = :identifier'
  'password no se normaliza' = $repository -match 'user\.password == password' -and $repository -notmatch 'authenticate[\s\S]{0,500}password\.trim'
  'errores de login reales' = $viewModel -match 'cuenta vinculada a ese correo' -and $viewModel -match 'nombre de usuario no existe' -and $viewModel -match 'contrase.a es incorrecta'
  'cinco escenarios de login' = ([regex]::Matches($loginTests, '@Test').Count -eq 5)
  'fallback dashboard antes de migracion RC3' = $app -match "roleCode==='supervisor'&&hasPermission\('supervisor.dashboard'\)"
  'dashboard muestra PostgREST real' = $diagnostics -match 'code' -and $diagnostics -match 'details' -and $diagnostics -match 'hint'
  'diagnostico incluye tenant y permisos' = $diagnostics -match 'role_id' -and $diagnostics -match 'company_id' -and $diagnostics -match 'permisos_cargados'
  'diagnostico no imprime secretos' = $diagnostics -notmatch 'token|password|credential|authorization'
  'admin registra consulta fallida' = $adminDashboard -match 'logDashboardFailure'
  'supervisor registra RPC fallida' = $supervisorDashboard -match "logDashboardFailure\('rpc dashboard_supervisor'"
  'errores no se muestran como ceros' = $adminDashboard -match '!error && <section className="stats"' -and $supervisorDashboard -match 'if\(error\)return <div className="error"'
}
$failed = $false
foreach ($item in $checks.GetEnumerator()) { if ($item.Value) { Write-Host "OK: $($item.Key)" } else { Write-Host "FALLO: $($item.Key)"; $failed = $true } }
if ($failed) { throw 'Fallaron contratos de regresión de login/dashboard.' }
Write-Host 'Regresiones de login y Dashboard verificadas.'
