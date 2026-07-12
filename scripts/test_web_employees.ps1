$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$service = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/employees/employeeService.ts')
$edge = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'supabase/functions/employee-management/index.ts')
$list = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/EmployeesPage.tsx')
$form = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/EmployeeFormPage.tsx')
$detail = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/EmployeeDetailPage.tsx')
$dashboard = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/DashboardPage.tsx')
$checks = [ordered]@{
  'lecturas Supabase con RLS' = $service -match "from\('empleados'\)" -and $service -notmatch 'localStorage'
  'relaciones compuestas explicitas' = $service -match 'empleados_sucursal_misma_empresa_fk' -and $service -match 'empleados_departamento_misma_empresa_fk' -and $service -match 'empleados_puesto_misma_empresa_fk'
  'CRUD usa funcion segura' = $service -match "functions.invoke\('employee-management'" -and $edge -match "action==='save'" -and $edge -match "action==='toggle'"
  'tenant forzado desde profile' = $edge -match "select\('company_id'\)" -and $edge -match 'empresa_id:profile.company_id'
  'permisos efectivos' = $edge -match "empleados.crear" -and $edge -match "empleados.editar" -and $edge -match "empleados.desactivar"
  'PIN bcrypt unico' = $edge -match 'bcrypt.compare' -and $edge -match 'bcrypt.hash' -and $edge -notmatch 'pin_hash:pin([,}])'
  'codigo y correo unicos' = $edge -match "eq\('codigo_empleado',code\)" -and $edge -match "eq\('correo',email\)" -and ([regex]::Matches($edge,"return json\(\{error:").Count -ge 6)
  'lista busca y filtra' = $list -match 'Buscar por nombre' -and $list -match 'Todos los estados'
  'pantallas crear editar ver' = $form -match 'employeeService.save' -and $detail -match 'employeeService.get' -and $detail -match '/editar'
  'huella preparada sin captura web' = $detail -match 'Huella 2Connect' -and $detail -match 'no captura ni almacena'
  'dashboard usa empleados reales' = $dashboard -match 'employeeService.list' -and $dashboard -notmatch 'employees}from.*mockData'
}
$failed = $checks.GetEnumerator() | Where-Object { -not $_.Value }
$checks.GetEnumerator() | ForEach-Object { if ($_.Value) { Write-Host "OK: $($_.Key)" } else { Write-Host "ERROR: $($_.Key)" } }
if ($failed) { throw 'Fallaron contratos del módulo web Empleados.' }
Write-Host 'Todos los contratos del módulo web Empleados están presentes.'
