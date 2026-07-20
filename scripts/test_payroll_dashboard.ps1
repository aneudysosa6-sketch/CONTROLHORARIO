$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$migration = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'supabase/migrations/0019_payroll_dashboard_total.sql')
$service = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/payroll/payrollService.ts')
$dashboardService = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/dashboard/executiveDashboardService.ts')
$dashboard = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/ExecutiveDashboardPage.tsx')

$checks = [ordered]@{
  'RPC de Dashboard estable y de solo lectura' = $migration -match 'obtener_total_nomina_dashboard' -and $migration -match 'stable' -and $migration -notmatch 'insert into public\.nomina_detalles|update public\.nominas|delete from public\.nomina_detalles'
  'Nómina cerrada usa resumen almacenado' = $migration -match "p\.estado = 'CERRADA'" -and $migration -match "'source', 'CLOSED'" -and $migration -match "v_resumen ->> 'total_general_pagado'"
  'Vista previa usa jornadas finalizadas y fórmula RC4' = $migration -match "j\.estado = 'FINALIZADA'" -and $migration -match 'v_pago_normal' -and $migration -match 'v_pago_extra' -and $migration -match 'v_afp' -and $migration -match 'v_sfs' -and $migration -match 'v_prestamos'
  'Empleado bloqueante se identifica' = $migration -match "'employee_code'" -and $migration -match "'employee_name'" -and $migration -match "'SALARIO_FALTANTE'"
  'Cliente registra PAYROLL_DASHBOARD' = $service -match "console\.info\('PAYROLL_DASHBOARD'" -and $service -match 'jornadasUtilizadas' -and $service -match 'totalCalculado' -and $service -match 'motivo'
  'Dashboard consume el RPC por fecha' = $dashboardService -match 'payrollService\.dashboardTotal\(snapshot\.workDate\)' -and $dashboardService -match 'loadPayrollDashboard'
  'UI usa el total del RPC y no el snapshot vacío' = $dashboard -match 'payrollDashboard\.total' -and $dashboard -match 'C.lculo bloqueado' -and $dashboard -notmatch "money\(payroll\?\.nomina\.resumen\.total_general_pagado\)"
}

$failed = $false
foreach ($check in $checks.GetEnumerator()) {
  if ($check.Value) { Write-Output "PASS: $($check.Key)" }
  else { Write-Error "FAIL: $($check.Key)"; $failed = $true }
}
if ($failed) { throw 'Fallaron los contratos del total de nómina del Dashboard.' }
