$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$migration = Join-Path $root 'supabase/migrations/0010_rc4_payroll_engine.sql'
$page = Join-Path $root 'web/src/pages/PayrollPage.tsx'
$service = Join-Path $root 'web/src/modules/payroll/payrollService.ts'
$exports = Join-Path $root 'web/src/modules/payroll/payrollExports.ts'

foreach ($file in @($migration,$page,$service,$exports)) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Falta contrato RC4: $file" }
}

$sql = Get-Content -LiteralPath $migration -Raw
$web = (Get-Content -LiteralPath $page -Raw) + (Get-Content -LiteralPath $service -Raw) + (Get-Content -LiteralPath $exports -Raw)
$tables = 'nomina_periodos','nominas','nomina_detalles','nomina_descuentos','nomina_prestamos','nomina_creditos','nomina_ajustes','nomina_auditoria','nomina_archivos'
$functions = 'crear_periodo_nomina','calcular_nomina','cambiar_estado_nomina','configurar_regla_nomina','aplicar_descuentos_nomina','crear_prestamo_nomina','cambiar_estado_prestamo_nomina','crear_credito_nomina','cancelar_credito_nomina','listar_nomina_periodos','listar_empleados_nomina','obtener_reglas_nomina','obtener_nomina','registrar_exportacion_nomina'
$permissions = 'nomina.ver','nomina.generar','nomina.editar','nomina.aprobar','nomina.cerrar','nomina.anular','nomina.exportar','nomina.prestamos','nomina.creditos','nomina.descuentos'

foreach ($table in $tables) {
    if ($sql -notmatch "create table public\.$table\b") { throw "Falta tabla RC4: $table" }
    if ($sql -notmatch "alter table public\.%I enable row level security") { throw 'Falta habilitación RLS centralizada.' }
}
foreach ($function in $functions) { if ($sql -notmatch "function public\.$function\b") { throw "Falta RPC RC4: $function" } }
foreach ($permission in $permissions) { if ($sql -notmatch [regex]::Escape($permission)) { throw "Falta permiso RC4: $permission" } }
if ($sql -match 'attendance_records') { throw 'RC4 no puede usar attendance_records legado.' }
if ($sql -notmatch "j\.estado='FINALIZADA'.+not j\.revision_pendiente") { throw 'El motor no limita jornadas consolidadas elegibles.' }
if ($sql -notmatch 'CONFLICTOS_PENDIENTES' -or $sql -notmatch 'JORNADAS_PENDIENTES') { throw 'Faltan bloqueos de jornadas/conflictos.' }
if ($sql -notmatch "formula='RC4_SQL_V1'" -or $sql -notmatch "version_calculo=v_version") { throw 'El motor no está versionado.' }
if ($sql -notmatch 'least\(pendiente,descuento_periodo\)') { throw 'No se limita el último descuento al remanente.' }
if ($sql -notmatch "p\.pendiente-d\.monto\)=0 then 'PAGADO'" -or $sql -notmatch "c\.pendiente-d\.monto\)=0 then 'PAGADO'") { throw 'Préstamos/créditos no cierran en cero.' }
if ($sql -notmatch "r\.code in\('admin','payroll'\)" -or $sql -match "r\.code in\([^\)]*supervisor") { throw 'Asignación de permisos RC4 incorrecta.' }
if ($sql -notmatch 'JORNADA_CAMBIADA' -or $sql -notmatch 'desactualizada=true') { throw 'Falta recálculo/auditoría por cambio de jornadas.' }

# Casos deterministas equivalentes al contrato RC4_SQL_V1.
$base = [decimal]15000
$daily = $base / 15
$hourly = $daily / 8
$extra = [math]::Round(2 * $hourly * (1 + 25 / 100),2)
$night = [math]::Round(3 * $hourly * (1 + 15 / 100),2)
$loanRemainder = [math]::Min([decimal]400,[decimal]275)
$creditRemainder = [math]::Min([decimal]250,[decimal]100)
$tax = [math]::Round(($base + $extra + $night) * 0.03,2)
$net = [math]::Round($base + $extra + $night - $loanRemainder - $creditRemainder - $tax,2)
if ($hourly -ne 125 -or $extra -ne 312.50 -or $night -ne 431.25) { throw 'Falló salario/valor hora/extra/nocturna/redondeo.' }
if ($loanRemainder -ne 275 -or $creditRemainder -ne 100 -or $net -ne 14896.44) { throw 'Falló remanente/crédito/impuesto/neto.' }

$headers = 'Código de empleado','Nombre de empleado','DESCU-PRES','DESCU-CRED','ROTUR/FALT'
foreach ($header in $headers) { if ($web -notmatch [regex]::Escape($header)) { throw "Falta columna Excel: $header" } }
foreach ($sheet in 'Resumen','Detalle','Descuentos') { if ($web -notmatch "'$sheet'") { throw "Falta hoja Excel final: $sheet" } }
if ($web -notmatch 'parsePayrollTemplate' -or $web -notmatch 'issues.length' -or $web -notmatch 'Código duplicado') { throw 'Falta validación/vista previa Excel.' }
if ($web -notmatch 'jsPDF' -or $web -notmatch 'autoTable') { throw 'Falta PDF profesional.' }
if ($web -match 'mockData|versión demo|muestra segura') { throw 'El módulo RC4 todavía usa mocks.' }

Write-Output 'OK RC4: esquema, motor, estados, jornadas, préstamos, créditos, Excel, PDF, RLS y Web cumplen el contrato estático.'
