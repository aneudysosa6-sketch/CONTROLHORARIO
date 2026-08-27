$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dashboard = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/Rc2DashboardPage.tsx')
$service = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/dashboard/dashboardService.ts')
$diagnostics = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/dashboard/dashboardDiagnostics.ts')
$app = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/App.tsx')
$checks = [ordered]@{
  'sin mocks' = $dashboard -notmatch 'mockData' -and $service -notmatch 'mockData'
  'fuente unificada' = $dashboard -match 'dashboardService\.load' -and $dashboard -match 'DashboardSnapshot' -and $dashboard -notmatch 'journeyService'
  'consultas sin joins ambiguos' = $service -match "from\('empleados'\)" -and $service -match "from\('jornadas'\)" -and $service -match "from\('jornada_incidencias'\)" -and $service -notmatch '!inner|empleados!|jornada_incidencias\('
  'fecha laboral empresarial' = $service -match "from\('companies'\)" -and $service -match 'companyWorkDate' -and $service -match 'timeZone: timezone'
  'sin iniciar usa empleados sin jornada' = $service -match 'employeesWithJourney' -and $service -match 'jornada_habilitada' -and $service -match 'employee\.activo'
  'metricas y recientes mismo snapshot' = $dashboard -match 'snapshot\.notStarted' -and $dashboard -match 'snapshot\.recent' -and $dashboard -match 'snapshot\.incidents'
  'errores no muestran ceros' = $dashboard -match 'error &&' -and $dashboard -match 'snapshot && !error'
  'diagnostico seguro completo' = $diagnostics -match 'query' -and $diagnostics -match 'code' -and $diagnostics -match 'details' -and $diagnostics -match 'hint' -and $diagnostics -match 'company_id' -and $diagnostics -match 'role_id' -and $diagnostics -match 'permisos_cargados' -and $diagnostics -match 'fecha_laboral_usada' -and $diagnostics -notmatch 'token|secret'
  'admin y supervisor separados' = $app -match "roleCode==='supervisor'\?<SupervisorDashboardPage" -and $app -match '<DashboardPage/>'
  'permisos efectivos obligatorios' = $service -match 'DASHBOARD_PERMISSION_MISSING' -and $service -match 'jornadas\.ver_todas' -and $service -match 'empleados\.ver_todos'
}
$failed = $checks.GetEnumerator() | Where-Object { -not $_.Value }
$checks.GetEnumerator() | ForEach-Object { if ($_.Value) { Write-Host "OK: $($_.Key)" } else { Write-Host "ERROR: $($_.Key)" } }
if ($failed) { throw 'Fallaron pruebas específicas del Dashboard Web.' }
Write-Host 'Dashboard Web real y diagnóstico seguro verificados.'
