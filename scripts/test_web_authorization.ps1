$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$app = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/App.tsx')
$auth = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/auth/authService.ts')
$context = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/context/AuthContext.tsx')
$checks = [ordered]@{
  'empleados exige codigo exacto' = $app -match 'path="/empleados" element={<RequirePermission permission="empleados\.ver_todos"'
  'guard espera loading' = $app -match 'if\(loading\)return <div className="empty">Cargando permisos'
  'guard diagnostica sin secretos' = $app -match 'permiso_requerido' -and $app -match 'codigos_cargados' -and $app -match 'role_id' -and $app -match 'company_id' -and $app -notmatch 'token|secret'
  'profile aporta role y company' = $auth -match 'profile\.role_id' -and $auth -match 'profile\.company_id'
  'rol validado dentro de company' = $auth -match "eq\('id',profile\.role_id\)\.eq\('company_id',profile\.company_id\)"
  'rol_permisos por rol real' = $auth -match "from\('rol_permisos'\).*eq\('rol_id',profile\.role_id\)"
  'permisos se cargan por ids' = $auth -match "from\('permisos'\).*in\('id',ids\)" -and $auth -notmatch 'rol_permisos\([^)]*permisos'
  'permitido false no se concede' = $auth -match 'effective\.set\(code,row\.permitido===true\)' -and $auth -match 'filter\(\(\[,allowed\]\)=>allowed\)'
  'excepcion de profile prevalece' = $auth.IndexOf('for(const row of profileRows)') -gt $auth.IndexOf('for(const row of roleRows)')
  'loading cubre login y refresh' = $context -match 'const login=.*setLoading\(true\)' -and $context -match 'const refresh=.*setLoading\(true\)'
  'sin codigo antiguo' = $app -notmatch 'permission="empleados\.ver"'
}
$failed = $checks.GetEnumerator() | Where-Object { -not $_.Value }
$checks.GetEnumerator() | ForEach-Object { if ($_.Value) { Write-Host "OK: $($_.Key)" } else { Write-Host "ERROR: $($_.Key)" } }
if ($failed) { throw 'Fallaron contratos de autorización web.' }
Write-Host 'El administrador con empleados.ver_todos puede abrir /empleados después de cargar permisos.'
