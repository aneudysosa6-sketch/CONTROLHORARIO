$ErrorActionPreference='Stop';$root=Split-Path -Parent $PSScriptRoot
$migration=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'supabase/migrations/0005_employee_biometrics_foundation.sql')
$web=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/modules/employees/employeeService.ts')
$detail=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/EmployeeDetailPage.tsx')
$android=Get-Content -Raw -Encoding UTF8 (Join-Path $root 'app/src/main/java/com/example/controlhorario/fingerprint/external/TwoConnectFingerprintManager.kt')
$checks=[ordered]@{
 'multiempresa compuesta'=$migration -match 'foreign key\(empresa_id,empleado_id\)' -and $migration -match 'references public\.empleados\(empresa_id,id\)'
 'una huella activa'=$migration -match 'unique index empleado_biometrias_una_activa_idx' -and $migration -match 'where activo'
 'template cifrado no publico'=$migration -match 'template_ciphertext bytea' -and $migration -match 'encryption_nonce bytea' -and $migration -match 'revoke all on public\.empleado_biometrias.*authenticated'
 'sin imagen raw'=$migration -notmatch 'raw_image|imagen_raw'
 'tamanos 256 y 512'=$migration -match 'template_size in \(256,512\)'
 'permisos biometricos'=@('empleados.biometria_ver','empleados.biometria_registrar','empleados.biometria_reemplazar')|ForEach-Object{$migration -match [regex]::Escape($_)}|Where-Object{-not $_}|Measure-Object|Select-Object -ExpandProperty Count|ForEach-Object{$_ -eq 0}
 'web solo metadatos'=$web -match 'listar_estados_biometricos_empleados' -and $web -notmatch 'template_ciphertext|templateBase64'
 'web indica Android'=$detail -match 'Registrar huella en Android' -and $detail -match 'nunca recibe ni muestra el template'
 'SDK preservado'=$android -match 'OpenDevice' -and $android -match 'FPRegModule' -and $android -match 'MatchTemplate'
}
$failed=$checks.GetEnumerator()|Where-Object{-not $_.Value};$checks.GetEnumerator()|ForEach-Object{if($_.Value){Write-Host "OK: $($_.Key)"}else{Write-Host "ERROR: $($_.Key)"}};if($failed){throw 'Fallaron contratos de base biométrica.'};Write-Host 'Base biométrica segura verificada; hardware real continúa pendiente.'
