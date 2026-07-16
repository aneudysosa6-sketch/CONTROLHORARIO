[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

$root = Split-Path -Parent $PSScriptRoot
$supabaseDirectory = Join-Path $root 'supabase'
$migrationsDirectory = Join-Path $supabaseDirectory 'migrations'
$testsDirectory = Join-Path $supabaseDirectory 'tests'

$officialMigrations = @(
    '0001_FINAL.sql',
    '0002_FINAL.sql',
    '0003_FINAL.sql',
    '0004_admin_employee_permissions.sql',
    '0005_employee_biometrics_foundation.sql',
    '0006_android_device_enrollment.sql',
    '0007_employee_supervisor_sync.sql',
    '0008_rc2_attendance_engine.sql',
    '0009_rc3_supervisor_scoped_operations.sql',
    '0010_rc4_payroll_engine.sql',
    '0011_rc35_system_administration.sql',
    '0012_rc4_employee_pay_alignment.sql',
    '0013_employee_portal_loans.sql'
)

$officialTests = @(
    'architecture_contracts.sql',
    '0010_rc4_payroll_contract.sql',
    '0011_rc35_system_administration_contract.sql',
    '0012_rc4_employee_pay_alignment.sql',
    '0013_employee_portal_loans.sql'
)

$localPorts = [ordered]@{
    'db.shadow_port' = 55420
    'api.port' = 55421
    'db.port' = 55422
    'studio.port' = 55423
    'local_smtp.port' = 55424
    'local_smtp.smtp_port' = 55425
    'local_smtp.pop3_port' = 55426
    'analytics.port' = 55427
    'analytics.vector_port' = 55428
    'db.pooler.port' = 55429
}

$localStackStarted = $false

function Write-Pass([string]$message) { Write-Host "PASS: $message" -ForegroundColor Green }
function Write-Fail([string]$message) { Write-Host "FAIL: $message" -ForegroundColor Red }

function Invoke-LocalSupabase([string[]]$arguments) {
    & supabase @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Falló: supabase $($arguments -join ' ')"
    }
}

function Get-ExcludedTcpRanges {
    $ranges = @()
    foreach ($line in (& netsh interface ipv4 show excludedportrange protocol=tcp)) {
        if ($line -match '^\s*(\d+)\s+(\d+)\s*(?:\*.*)?$') {
            $ranges += [pscustomobject]@{ Start = [int]$Matches[1]; End = [int]$Matches[2] }
        }
    }
    return $ranges
}

function Test-LocalPort([string]$name, [int]$port, $excludedRanges) {
    $listeners = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
    if ($listeners.Count -gt 0) {
        throw "Puerto configurado ocupado: $name=$port (PID $($listeners[0].OwningProcess))."
    }
    foreach ($range in $excludedRanges) {
        if ($port -ge $range.Start -and $port -le $range.End) {
            throw "Puerto configurado reservado por Windows: $name=$port (rango $($range.Start)-$($range.End))."
        }
    }
}

try {
    Set-Location $root

    if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
        throw 'Supabase CLI no está instalado o no está disponible en PATH.'
    }
    Invoke-LocalSupabase @('--version')
    Write-Pass 'Supabase CLI disponible.'

    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        throw 'Docker CLI no está instalado o no está disponible en PATH.'
    }
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) {
        throw 'Docker está instalado, pero el daemon no está disponible.'
    }
    Write-Pass 'Docker daemon disponible.'

    # Detiene únicamente el proyecto Supabase local actual antes de inspeccionar y reutilizar sus puertos.
    & supabase stop --no-backup *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'INFO: No había un stack local previo para detener.' -ForegroundColor DarkYellow
    }
    else {
        Write-Pass 'Stack local previo detenido.'
    }

    foreach ($requiredPath in @($supabaseDirectory, $migrationsDirectory, $testsDirectory, (Join-Path $supabaseDirectory 'config.toml'))) {
        if (-not (Test-Path -LiteralPath $requiredPath)) {
            throw "Falta recurso requerido: $requiredPath"
        }
    }

    $config = Get-Content -LiteralPath (Join-Path $supabaseDirectory 'config.toml') -Raw -Encoding UTF8
    foreach ($entry in $localPorts.GetEnumerator()) {
        if ($config -notmatch "(?m)^\s*$([regex]::Escape($entry.Key.Split('.')[-1]))\s*=\s*$($entry.Value)\s*$") {
            throw "El puerto configurado no coincide con el preflight: $($entry.Key)=$($entry.Value)."
        }
    }
    $lastPortError = $null
    foreach ($attempt in 1..10) {
        try {
            $excludedRanges = Get-ExcludedTcpRanges
            foreach ($entry in $localPorts.GetEnumerator()) {
                Test-LocalPort -name $entry.Key -port $entry.Value -excludedRanges $excludedRanges
            }
            $lastPortError = $null
            break
        }
        catch {
            $lastPortError = $_
            if ($attempt -lt 10) {
                Write-Host "INFO: Esperando liberación de puertos locales ($attempt/10)..." -ForegroundColor DarkYellow
                Start-Sleep -Seconds 2
            }
        }
    }
    if ($null -ne $lastPortError) {
        throw $lastPortError
    }
    Write-Pass "Puertos locales libres y no reservados: $($localPorts.Values -join ', ')."

    $actualMigrations = @(Get-ChildItem -LiteralPath $migrationsDirectory -File -Filter '*.sql' | Sort-Object Name | ForEach-Object Name)
    if ((@($officialMigrations) -join "`n") -cne (@($actualMigrations) -join "`n")) {
        throw "La carpeta supabase/migrations no coincide exactamente con la cadena oficial. Esperado: $($officialMigrations -join ', '). Encontrado: $($actualMigrations -join ', ')."
    }
    if (@(Get-ChildItem -LiteralPath (Join-Path $supabaseDirectory 'migrations_archivadas') -File -ErrorAction SilentlyContinue).Count -gt 0) {
        Write-Host 'INFO: migrations_archivadas detectada y excluida; Supabase CLI sólo leerá supabase/migrations.' -ForegroundColor Yellow
    }
    Write-Pass 'Cadena oficial de 13 migraciones validada.'

    $actualTests = @(Get-ChildItem -LiteralPath $testsDirectory -File -Filter '*.sql' | Sort-Object Name | ForEach-Object Name)
    if ((@($officialTests | Sort-Object) -join "`n") -cne (@($actualTests) -join "`n")) {
        throw "La carpeta supabase/tests no coincide con las pruebas oficiales. Esperado: $($officialTests -join ', '). Encontrado: $($actualTests -join ', ')."
    }
    Write-Pass 'Conjunto de pruebas SQL oficial validado.'

    # No se usan --linked, --db-url, supabase link, ni secretos remotos. Todo lo siguiente apunta al stack local.
    Invoke-LocalSupabase @('start')
    $localStackStarted = $true
    Write-Pass 'Entorno Supabase local aislado iniciado.'

    Invoke-LocalSupabase @('db', 'reset', '--local', '--no-seed')
    Write-Pass 'Cadena oficial aplicada desde cero sin seed ni migraciones archivadas.'

    Invoke-LocalSupabase @('db', 'lint', '--local', '--fail-on', 'error')
    Write-Pass 'Lint local de esquema completado.'

    foreach ($test in $officialTests) {
        Invoke-LocalSupabase @('test', 'db', '--local', (Join-Path 'supabase/tests' $test))
        Write-Pass "Prueba SQL aprobada: $test"
    }

    Write-Host 'PASS: Preflight Supabase local completado.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Fail $_.Exception.Message
    Write-Host 'FAIL: Preflight Supabase local detenido. No se contactó producción.' -ForegroundColor Red
    exit 1
}
finally {
    if ($localStackStarted) {
        & supabase stop --no-backup *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host 'INFO: Entorno Supabase local detenido y volúmenes locales descartados.' -ForegroundColor DarkYellow
        }
        else {
            Write-Host 'WARN: No se pudo detener automáticamente el entorno local; ejecute: supabase stop --no-backup' -ForegroundColor Yellow
        }
    }
}
