$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$migration = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'supabase/migrations/0004_admin_employee_permissions.sql')
$app = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/App.tsx')
$seed = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'supabase/seed.sql')
$codes = @('empleados.ver_todos','empleados.crear','empleados.editar','empleados.desactivar')
$checks = [ordered]@{
  'ruta coincide con seed' = $app -match 'permission="empleados\.ver_todos"' -and $seed -match "'empleados\.ver_todos'"
  'no inventa empleados.ver' = $migration -notmatch "'empleados\.ver'"
  'todos los permisos incluidos' = ($codes | Where-Object { $migration -notmatch [regex]::Escape($_) } | Measure-Object).Count -eq 0
  'asignacion solo admin activo' = $migration -match "r\.code = 'admin'" -and $migration -match 'r\.is_active'
  'alcance empresa permitido' = $migration -match "true, 'empresa'" -and $migration -match 'permitido = true' -and $migration -match "alcance = 'empresa'"
  'idempotente' = $migration -match 'on conflict \(codigo\) do update' -and $migration -match 'on conflict \(rol_id, permiso_id\) do update'
  'RLS permanece intacta' = $migration -notmatch 'disable row level security|drop policy'
  'verificacion transaccional' = $migration -match '<> 4' -and $migration -match 'raise exception'
}
$failed = $checks.GetEnumerator() | Where-Object { -not $_.Value }
$checks.GetEnumerator() | ForEach-Object { if ($_.Value) { Write-Host "OK: $($_.Key)" } else { Write-Host "ERROR: $($_.Key)" } }
if ($failed) { throw 'Falló la validación de permisos admin para Empleados.' }
Write-Host 'La migración de permisos admin para Empleados es consistente.'
