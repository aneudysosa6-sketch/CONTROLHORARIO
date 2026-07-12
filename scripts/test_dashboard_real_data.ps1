$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$dashboard = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/DashboardPage.tsx')
$service = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/dashboard/dashboardService.ts')
$checks = [ordered]@{
  'sin mockData' = $dashboard -notmatch 'mockData|Laura Martínez|Carlos Ramírez|Ana Pérez|Miguel Santos'
  'actividad consulta Supabase' = $service -match "from\('jornadas'\)" -and $dashboard -match 'dashboardService\.recentActivity'
  'actividad vacia exacta' = $dashboard -match 'No hay actividad reciente\.'
  'alertas usan empleados reales' = $dashboard -match 'employeeService\.list' -and $dashboard -match 'employees\.filter'
  'alertas vacias' = $dashboard -match 'No hay alertas importantes\.'
  'tabla futura tolerada' = $service -match "error\.code==='PGRST205'"
}
$failed = $checks.GetEnumerator() | Where-Object { -not $_.Value }
$checks.GetEnumerator() | ForEach-Object { if ($_.Value) { Write-Host "OK: $($_.Key)" } else { Write-Host "ERROR: $($_.Key)" } }
if ($failed) { throw 'Fallaron contratos de datos reales del Dashboard.' }
Write-Host 'El Dashboard no contiene actividad ficticia.'
