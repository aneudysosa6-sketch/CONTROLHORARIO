$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$migrationV3 = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'supabase/migrations/0020_payroll_net_floor_and_remote_conflict_resolution.sql')
$service = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/payroll/payrollService.ts')
$dashboardService = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/dashboard/executiveDashboardService.ts')
$dashboard = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/ExecutiveDashboardPage.tsx')

$dashboardRpc = [regex]::Match(
  $migrationV3,
  '(?s)create or replace function public\.obtener_total_nomina_dashboard\(p_fecha date default null\).*?(?=create or replace function public\.calcular_nomina)'
).Value
$conflictResolver = [regex]::Match(
  $migrationV3,
  '(?s)create or replace function public\.resolver_conflicto_jornada_remoto_superado\(.*?(?=revoke all on function public\.nomina_prorratear)'
).Value

$checks = [ordered]@{
  'RPC de Dashboard V3 estable y de solo lectura' = $dashboardRpc -match 'stable' -and $dashboardRpc -notmatch 'insert into|update public\.|delete from'
  'Nomina cerrada usa resumen almacenado' = $dashboardRpc -match "p\.estado = 'CERRADA'" -and $dashboardRpc -match "'status', 'CLOSED'" -and $dashboardRpc -match "v_resumen ->> 'total_general_pagado'"
  'RPC conserva source y agrega status REAL_TIME' = $dashboardRpc -match "'status', 'REAL_TIME'" -and $dashboardRpc -match "'source', 'REAL_TIME'"
  'Vista previa V3 usa el calculo compartido por empleado' = $dashboardRpc -match 'nomina_calculo_empleado_v3' -and $migrationV3 -match "j\.estado = 'FINALIZADA'" -and $migrationV3 -match 'RC4_WORKED_MINUTES_V3_NET_FLOOR'
  'AFP y SFS MONTO se prorratean por trabajo real' = $migrationV3 -match 'nomina_prorratear_obligacion_v3' -and $migrationV3 -match 'p_minutos_normales' -and $migrationV3 -match 'p_divisor' -and $migrationV3 -match 'p_horas_dia'
  'Neto tiene piso cero y descuentos secuenciales' = $migrationV3 -match 'nomina_distribuir_descuentos_v3' -and $migrationV3 -match 'least\(v_monto_solicitado, v_disponible\)' -and $migrationV3 -match "'net', round\(v_disponible, 2\)"
  'Descuentos aplicados y pendientes quedan registrados' = $migrationV3 -match 'monto_solicitado' -and $migrationV3 -match 'monto_pendiente' -and $dashboardRpc -match "'deductions_pending'"
  'Empleado bloqueante se identifica' = $dashboardRpc -match "'employee_code'" -and $dashboardRpc -match "'employee_name'" -and $dashboardRpc -match "'SALARIO_FALTANTE'"
  'Conflicto remoto se resuelve sin modificar jornada' = $conflictResolver -match "estado = 'RESUELTO_REMOTO'" -and $conflictResolver -match "'RESOLVER_CONFLICTO_REMOTO'" -and $conflictResolver -notmatch 'update public\.jornadas'
  'Cliente registra PAYROLL_DASHBOARD' = $service -match "console\.info\('PAYROLL_DASHBOARD'" -and $service -match 'jornadasUtilizadas' -and $service -match 'totalCalculado' -and $service -match 'motivo'
  'Dashboard consume el RPC por fecha' = $dashboardService -match 'payrollService\.dashboardTotal\(snapshot\.workDate\)' -and $dashboardService -match 'loadPayrollDashboard'
  'UI usa el total del RPC y no el snapshot vacio' = $dashboard -match 'payrollDashboard\.total' -and $dashboard -match 'C.lculo bloqueado' -and $dashboard -notmatch "money\(payroll\?\.nomina\.resumen\.total_general_pagado\)"
}

$failed = $false
foreach ($check in $checks.GetEnumerator()) {
  if ($check.Value) { Write-Output "PASS: $($check.Key)" }
  else { Write-Error "FAIL: $($check.Key)"; $failed = $true }
}
if ($failed) { throw 'Fallaron los contratos del total de nomina del Dashboard.' }
