$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$auth = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/java/com/example/controlhorario/auth/AuthRepository.kt')
$api = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/java/com/example/controlhorario/auth/SupabaseAuthApi.kt')
$login = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/java/ui/login/LoginScreen.kt')
$viewModel = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/java/ui/login/AppUserViewModel.kt')
$navigation = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/java/com/example/controlhorario/ui/navigation/AppNavigation.kt')
$dashboard = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/java/com/example/controlhorario/dashboard/AndroidDashboard.kt')
$authTests = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/test/java/com/example/controlhorario/auth/AuthRepositoryTest.kt')
$dashboardTests = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/test/java/com/example/controlhorario/dashboard/DashboardRoutePolicyTest.kt')
$dashboardMetricsTests = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/test/java/com/example/controlhorario/dashboard/DashboardMetricsCalculatorTest.kt')
$network = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/java/com/example/controlhorario/auth/NetworkDiagnostics.kt')
$networkTests = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/test/java/com/example/controlhorario/auth/NetworkDiagnosticsTest.kt')
$manifest = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/AndroidManifest.xml')
$instrumentedNetwork = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/androidTest/java/com/example/controlhorario/auth/SupabaseNetworkInstrumentedTest.kt')

$checks = [ordered]@{
  'correo no consulta Room antes de Auth' = $authTests -match 'errorIfResolve = true' -and $authTests -match 'resolveCalls\)'
  'correo usa signInWithPassword' = $api -match 'signInWithPassword' -and $api -match '/auth/v1/token\?grant_type=password'
  'username resuelve correo antes de Auth' = $auth -match 'usernameResolver\.resolveEmail' -and $auth -match 'gateway\.signInWithPassword'
  'correo aplica trim y minusculas' = $auth -match 'rawIdentifier\.trim\(\)' -and $auth -match 'identifier\.lowercase\(\)'
  'password no se normaliza' = $auth -match 'signInWithPassword\(email, password\)' -and $auth -notmatch 'password\.trim'
  'carga auth uid profile rol permisos' = $api -match 'session\.authUid' -and $api -match 'table = "profiles"' -and $api -match 'table = "roles"' -and $api -match 'rol_permisos' -and $api -match 'perfil_permisos'
  'sesion inicia despues de autorizacion' = $viewModel.IndexOf('auth.login') -lt $viewModel.IndexOf('AuthSessionStore.start')
  'diagnostico Auth sin secretos' = $auth -match 'supabase_auth_llamado=true' -and $auth -match 'auth_uid=' -and $auth -match 'permisos_efectivos=' -and $auth -notmatch 'Log\.[^(]+\([^\r\n]*(password|accessToken)'
  'navegacion admin supervisor y fallback' = $navigation -match 'SUPERVISOR_RC3' -and $navigation -match 'SUPERVISOR_FALLBACK' -and $navigation -match 'AdminHomeScreen'
  'loading no redirige' = $dashboard -match 'if \(loading\) return DashboardDestination\.LOADING'
  'fallback RC3 seguro' = $dashboard -match 'shouldFallbackFromRc3' -and $dashboard -match 'scopedDashboard'
  'Dashboard admin usa empleados jornadas e incidencias reales' = $dashboard -match '/rest/v1/empleados' -and $dashboard -match '/rest/v1/jornadas' -and $dashboard -match '/rest/v1/jornada_incidencias'
  'fecha laboral usa timezone empresarial' = $dashboard -match '/rest/v1/companies\?select=timezone' -and $dashboard -match 'CompanyWorkDate\.resolve'
  'sin iniciar deriva de empleados sin jornada' = $dashboard -match 'eligibleEmployeeIds\.count' -and $dashboardMetricsTests -match 'sin iniciar incluye activo habilitado sin fila de jornada'
  'errores PostgREST visibles' = $dashboard -match 'error\.visibleMessage\(\)' -and $dashboard -match 'details=' -and $dashboard -match 'hint='
  'metricas no se inventan en error' = $dashboard -match 'DashboardState\.Error -> OSINETCard' -and $dashboard -notmatch 'DashboardState\.Error[\s\S]{0,200}notStarted = 0'
  'pruebas obligatorias login' = ([regex]::Matches($authTests, '@Test').Count -ge 7)
  'pruebas obligatorias Dashboard' = ([regex]::Matches($dashboardTests, '@Test').Count -ge 5) -and ([regex]::Matches($dashboardMetricsTests, '@Test').Count -ge 4)
  'login local previo eliminado' = $viewModel -notmatch 'repository\.authenticate' -and $login -notmatch 'createDefaultAdminIfNeeded'
  'red fuera del hilo principal' = $api -match 'withContext\(Dispatchers\.IO\)' -and $dashboard -match 'withContext\(Dispatchers\.IO\)'
  'diagnostico separa DNS TLS timeout y rechazo' = $network -match 'DNS_ERROR' -and $network -match 'TLS_ERROR' -and $network -match 'TIMEOUT' -and $network -match 'CONNECTION_REFUSED'
  'runtime valida URL host y clave' = $network -match 'HTTPS_REQUIRED' -and $network -match 'PUBLISHABLE_KEY_EMPTY' -and $network -match 'publishable_key_present'
  'manifest permite Internet y prohibe HTTP' = $manifest -match 'android.permission.INTERNET' -and $manifest -match 'usesCleartextTraffic="false"' -and $manifest -match 'networkSecurityConfig'
  'pruebas especificas de red' = ([regex]::Matches($networkTests, '@Test').Count -ge 9) -and $network -match 'PUBLISHABLE_KEY_TRUNCATED'
  'prueba de conectividad desde APK' = $instrumentedNetwork -match 'SupabaseAuthApi\(\)\.signInWithPassword' -and $instrumentedNetwork -match 'invalid_credentials'
}

$failed = $false
foreach ($item in $checks.GetEnumerator()) {
  if ($item.Value) { Write-Host "OK: $($item.Key)" } else { Write-Host "FALLO: $($item.Key)"; $failed = $true }
}
if ($failed) { throw 'Fallaron contratos Android de login Supabase/Dashboard.' }
Write-Host 'Login Supabase y Dashboard Android verificados contractualmente.'
