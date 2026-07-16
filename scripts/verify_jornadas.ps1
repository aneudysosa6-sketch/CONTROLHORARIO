#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$failures = [System.Collections.Generic.List[string]]::new()

function Pass([string]$message) { Write-Host "PASS  $message" -ForegroundColor Green }
function Fail([string]$message) { Write-Host "FAIL  $message" -ForegroundColor Red; $script:failures.Add($message) }
function Require-Text([string]$path, [string]$pattern, [string]$description) {
    if (-not (Test-Path -LiteralPath $path)) { Fail "$description (missing $path)"; return }
    if (Select-String -LiteralPath $path -Pattern $pattern -Quiet) { Pass $description } else { Fail $description }
}
function Invoke-LocalSupabaseWithRetry([string[]]$arguments, [int]$attempts = 3) {
    for ($attempt = 1; $attempt -le $attempts; $attempt++) {
        & supabase @arguments | Out-Host
        if ($LASTEXITCODE -eq 0) { return }
        if ($attempt -eq $attempts) { throw "supabase $($arguments -join ' ') failed after $attempts attempts" }
        Write-Host "Retrying local Supabase ($attempt/$attempts)..." -ForegroundColor DarkYellow
        Start-Sleep -Seconds 5
        & supabase start -x analytics -x edge-runtime -x functions -x imgproxy -x inbucket -x kong -x meta -x realtime -x rest -x storage -x studio -x vector | Out-Host
    }
}
function Show-LocalDbDiagnostics {
    $container = @(docker ps -a --format '{{.Names}}' | Where-Object { $_ -like 'supabase_db_*' } | Select-Object -First 1)
    if ($container.Count -eq 0) { Write-Host 'DIAGNOSTIC: no Supabase PostgreSQL container remained after the failure.' -ForegroundColor Yellow; return }
    Write-Host "DIAGNOSTIC: docker inspect $($container[0])" -ForegroundColor Yellow
    docker inspect $container[0] | Out-Host
    Write-Host "DIAGNOSTIC: docker logs --tail 300 $($container[0])" -ForegroundColor Yellow
    docker logs --tail 300 $container[0] | Out-Host
}

Write-Host 'P1 verification: attendance, biometrics, and offline (no production).' -ForegroundColor Cyan

$punch = 'app/src/main/java/ui/punch/EmployeePunchScreen.kt'
$punchVm = 'app/src/main/java/ui/punch/EmployeePunchViewModel.kt'
$navigation = 'app/src/main/java/com/example/controlhorario/ui/navigation/AppNavigation.kt'
$journeyVm = 'app/src/main/java/ui/punch/JourneyViewModel.kt'
$journeyDao = 'app/src/main/java/database/JourneyDao.kt'
$stateEngine = 'app/src/main/java/engine/AttendanceContract.kt'
$syncWorker = 'app/src/main/java/attendance/AttendanceSyncWorker.kt'
$syncScheduler = 'app/src/main/java/attendance/AttendanceSyncScheduler.kt'
$labor = 'app/src/main/java/engine/LaborCalculator.kt'
$migration = 'supabase/migrations/0014_p1_journeys_biometrics_branches.sql'
$contract = 'contracts/attendance-rc2-v1.json'

Require-Text $punchVm 'REQUIRED_PIN_LENGTH' 'Required PIN length is defined'
Require-Text $punch 'TwoConnectFingerprintManager' 'Flow uses the existing 2Connect reader'
Require-Text $punch 'matchTemplates\(' 'Fingerprint is matched against registered template'
Require-Text $punchVm 'if \(!current\.biometricVerified\)' 'Legacy flow rejects attendance without fingerprint'
Require-Text $navigation 'onVerified = \{ employeeId ->' 'Attendance action route starts from fingerprint confirmation'
Require-Text $journeyDao '@Transaction' 'Journey action and outbox are persisted atomically'
Require-Text $journeyDao 'BIOMETRIC_PROOF_INVALID' 'Repository rejects an invalid biometric proof'
Require-Text $journeyVm 'JourneyBiometricGate.consume' 'Journey action consumes biometric proof'
Require-Text $punch 'JourneyBiometricGate.open' 'Only the successful 2Connect match opens proof gate'
Require-Text $journeyDao 'UUID\.randomUUID\(\)' 'Outbox uses UUID idempotency keys'
Require-Text $journeyDao 'insertOutbox\(' 'Every action creates a local sync operation'
Require-Text $stateEngine 'JourneyStatus\.EN_PAUSA -> setOf\(JourneyAction\.REANUDAR, JourneyAction\.FINALIZAR\)' 'State engine allows resume and finish after a pause'
Require-Text $stateEngine 'breakMinutes = current\.breakMinutes \+' 'State engine accumulates multiple pauses'
Require-Text $stateEngine 'workedMinutes = current\.workedMinutes \+' 'State engine excludes pauses from worked time'
Require-Text $labor 'extraMinutes = if \(workedMinutes > scheduledMinutes\)' 'Overtime starts only above scheduled normal hours'
Require-Text $syncScheduler 'NetworkType\.CONNECTED' 'Automatic synchronization requires connectivity'
Require-Text $syncScheduler 'BackoffPolicy\.EXPONENTIAL' 'Scheduler configures exponential retries'
Require-Text $syncWorker '"accepted","duplicate"' 'Sync handles accepted and idempotent duplicate responses'
Require-Text $syncWorker '"CONFLICTO"' 'Sync preserves conflicts for resolution'
Require-Text $syncWorker 'Result\.retry\(\)' 'Transient failures use recovery retry'
Require-Text $migration 'sucursal_inicio_id' 'Start branch is persisted remotely'
Require-Text $migration 'sucursal_fin_id' 'End branch is persisted remotely'
Require-Text $migration 'corregir_jornada_30_dias' 'Server correction applies 30 day policy'
Require-Text $migration 'jornada_auditoria' 'Journey correction is audited'
Require-Text $migration 'jornada_ganancias' 'Immediate daily earnings are persisted idempotently'
Require-Text $contract '"PAUSAR"' 'Canonical contract contains pause actions'

Require-Text 'supabase/functions/attendance-sync/index.ts' 'validProof\(' 'Edge Function verifies signed and expiring biometric proof'
Require-Text 'supabase/functions/attendance-sync/index.ts' 'biometric_verified:true' 'Only verified proof reaches the service RPC'

$gradle = Join-Path $root 'gradlew.bat'
if (Test-Path -LiteralPath $gradle) {
    if (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME 'bin\java.exe'))) {
        $androidStudioJbr = 'C:\Program Files\Android\Android Studio\jbr'
        if (Test-Path (Join-Path $androidStudioJbr 'bin\java.exe')) {
            $env:JAVA_HOME = $androidStudioJbr
            $env:Path = "$(Join-Path $androidStudioJbr 'bin');$env:Path"
            Pass 'Using local Android Studio JDK for unit tests'
        } else {
            Fail 'No usable JDK was found; set JAVA_HOME to run journey unit tests'
        }
    }
    Write-Host 'Running canonical JourneyStateEngine unit tests...' -ForegroundColor Cyan
    & $gradle testDebugUnitTest '--tests' 'com.example.controlhorario.engine.JourneyStateEngineTest' '--tests' 'com.example.controlhorario.ui.punch.JourneyBiometricGateTest'
    if ($LASTEXITCODE -eq 0) { Pass 'Journey state transition unit tests' } else { Fail 'Journey state transition unit tests' }
} else { Fail 'gradlew.bat was not found for journey unit tests' }

$supabase = Get-Command supabase -ErrorAction SilentlyContinue
if ($null -eq $supabase) {
    Fail 'Supabase CLI was not found for the local P1 SQL contract'
} else {
    Write-Host 'Running isolated Supabase migrations and P1 SQL contract...' -ForegroundColor Cyan
    try {
        & supabase stop --all --no-backup | Out-Host
        & supabase start -x analytics -x edge-runtime -x functions -x imgproxy -x inbucket -x kong -x meta -x realtime -x rest -x storage -x studio -x vector | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'supabase start failed' }
        & supabase status | Out-Host
        docker ps | Out-Host
        Invoke-LocalSupabaseWithRetry @('db','reset','--local','--no-seed')
        & supabase test db supabase/tests/jornadas_p1_contracts.sql --local | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'jornadas_p1_contracts.sql failed' }
        Pass 'Migrations 0001 through 0014 and jornadas P1 SQL contract'
    } catch {
        Show-LocalDbDiagnostics
        Fail "Local P1 SQL contract: $($_.Exception.Message)"
    } finally {
        & supabase stop --no-backup | Out-Host
    }
}

if ($failures.Count -gt 0) {
    Write-Host "`nFAIL - P1 Journeys: $($failures.Count) verified gap(s)." -ForegroundColor Red
    $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "`nPASS - P1 attendance, biometrics, and offline verified." -ForegroundColor Green
exit 0
