# SOLO STAGING. Este script no aplica migraciones y rechaza produccion.
param(
    [Parameter(Mandatory)]
    [string]$StagingProjectRef
)

$ErrorActionPreference = "Stop"
$SourceProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$OutputFile = Join-Path $SourceProjectRoot "artifacts\production-readiness\staging-0030-dry-run.txt"
$TempRootBase = Join-Path $env:LOCALAPPDATA "CONTROLHORARIO\staging-validation"
$MigrationFile = Join-Path $SourceProjectRoot "supabase\migrations\0030_fix_employee_role_canonicalization.sql"
$ConfigFile = Join-Path $SourceProjectRoot "supabase\config.toml"
$ProjectRefFile = Join-Path $SourceProjectRoot "supabase\.temp\project-ref"
$TempMigrationFolder = "migrations"

function Get-SafeText([string]$Text) {
    if ([string]::IsNullOrEmpty($Text)) {
        return ""
    }

    $safe = $Text
    $safe = $safe -replace 'password=[^&\s"]+', 'password=[REDACTED]'
    $safe = $safe -replace 'service[_-]?role[_-]?key=[A-Za-z0-9+/=_-]+', 'service_role_key=[REDACTED]'
    $safe = $safe -replace 'anon[_-]?key=[A-Za-z0-9+/=_-]+', 'anon_key=[REDACTED]'
    $safe = $safe -replace 'postgres://[^\s"]+', 'postgres://[REDACTED_CONNECTION]'
    $safe = $safe -replace '([A-Za-z0-9+/=_-]{20,}\.[A-Za-z0-9+/=_-]{20,}\.[A-Za-z0-9+/=_-]{20,})', '[REDACTED_TOKEN]'
    $safe = $safe -replace '(?i)(ref:\s*)[a-z0-9]{20,}', '$1[REDACTED_REF]'
    return $safe
}

function Log-RunResult {
    param(
        [string]$Name,
        [int]$ExitCode,
        [string[]]$Output
    )

    $lines = @()
    $lines += ""
    $lines += "[$((Get-Date).ToString('s'))] $Name"
    $lines += "ExitCode: $ExitCode"
    $lines += "Output:"
    foreach ($line in $Output) {
        $lines += "  $line"
    }
    Add-Content -LiteralPath $OutputFile -Value ($lines -join "`r`n") -Encoding UTF8
}

function Invoke-SupabaseCommand {
    param([string]$Command, [string[]]$Arguments)
    $output = @()
    & $Command @Arguments 2>&1 | ForEach-Object { $output += [string]$_ }
    $exitCode = $LASTEXITCODE
    return @{
        ExitCode = if ($null -eq $exitCode) { 0 } else { $exitCode }
        Output = $output
    }
}

Set-Content -Path $OutputFile -Value "=== STAGING 0030 DRY-RUN ===" -Encoding UTF8
Add-Content -LiteralPath $OutputFile -Value "Started at: $((Get-Date).ToString('s'))" -Encoding UTF8

Write-Host "============================= SOLO STAGING ============================="
Write-Host "=== ESTE SCRIPT NO APLICA MIGRACIONES ==="
Write-Host "====================================================================="

if ([string]::IsNullOrWhiteSpace($StagingProjectRef)) {
    Write-Host "ERROR: StagingProjectRef no puede estar vacio."
    Add-Content -LiteralPath $OutputFile -Value "ERROR: StagingProjectRef empty."
    Write-Output "BLOCKED"
    exit 1
}

$stagingProjectRefTrimmed = $StagingProjectRef.Trim()
if ($stagingProjectRefTrimmed -ieq "controlhorario-prod") {
    Write-Host "ERROR: la referencia o nombre del proyecto no puede ser controlhorario-prod."
    Add-Content -LiteralPath $OutputFile -Value "ERROR: controlhorario-prod rejected."
    Write-Output "PRODUCTION_REF_REJECTED"
    exit 1
}

if (-not (Test-Path -LiteralPath $ConfigFile)) {
    Write-Host "ERROR: no existe supabase/config.toml"
    Add-Content -LiteralPath $OutputFile -Value "ERROR: supabase/config.toml missing."
    Write-Output "BLOCKED"
    exit 1
}

if (-not (Test-Path -LiteralPath $MigrationFile)) {
    Write-Host "ERROR: no existe la migracion 0030 en supabase/migrations."
    Add-Content -LiteralPath $OutputFile -Value "ERROR: migration 0030 missing."
    Write-Output "BLOCKED"
    exit 1
}

$productionProjectRef = $null
if (Test-Path -LiteralPath $ProjectRefFile) {
    $productionProjectRef = (Get-Content -LiteralPath $ProjectRefFile -Raw).Trim()
}

if (-not [string]::IsNullOrWhiteSpace($productionProjectRef) -and $stagingProjectRefTrimmed -eq $productionProjectRef) {
    Write-Host "ERROR: StagingProjectRef coincide con la referencia de produccion vinculada."
    Add-Content -LiteralPath $OutputFile -Value "ERROR: production project ref provided for staging."
    Write-Output "PRODUCTION_REF_REJECTED"
    exit 1
}

$supabaseExecutable = Get-Command -Name supabase -ErrorAction SilentlyContinue
if (-not $supabaseExecutable) {
    Write-Host "ERROR: no se encontro Supabase CLI en el PATH."
    Add-Content -LiteralPath $OutputFile -Value "ERROR: supabase cli not found."
    Write-Output "BLOCKED"
    exit 1
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$tempWorkspace = Join-Path $TempRootBase $timestamp
$tempSupabaseDir = Join-Path $tempWorkspace "supabase"
$tempMigrationDir = Join-Path $tempSupabaseDir $TempMigrationFolder
$tempConfigFile = Join-Path $tempSupabaseDir "config.toml"

New-Item -ItemType Directory -Path $tempMigrationDir -Force | Out-Null

Copy-Item -LiteralPath $ConfigFile -Destination $tempConfigFile -Force
Copy-Item -LiteralPath (Join-Path $SourceProjectRoot "supabase\migrations") -Destination $tempSupabaseDir -Recurse -Force

$originalLocation = Get-Location

try {
    Set-Location -LiteralPath $tempWorkspace
    Add-Content -LiteralPath $OutputFile -Value ""
    Add-Content -LiteralPath $OutputFile -Value "Workspace: $tempWorkspace"

    $commandResults = @{}

    $version = Invoke-SupabaseCommand -Command $supabaseExecutable.Source -Arguments @("--version")
    $commandResults.Version = $version
    Log-RunResult -Name "supabase --version" -ExitCode $version.ExitCode -Output ($version.Output | ForEach-Object { Get-SafeText -Text $_ })
    if ($version.ExitCode -ne 0) {
        Write-Output "BLOCKED"
        exit 1
    }

    $projects = Invoke-SupabaseCommand -Command $supabaseExecutable.Source -Arguments @("projects", "list")
    $commandResults.Projects = $projects
    Log-RunResult -Name "supabase projects list" -ExitCode $projects.ExitCode -Output ($projects.Output | ForEach-Object { Get-SafeText -Text $_ })
    if ($projects.ExitCode -ne 0) {
        Write-Output "BLOCKED"
        exit 1
    }

    $link = Invoke-SupabaseCommand -Command $supabaseExecutable.Source -Arguments @("link", "--project-ref", $stagingProjectRefTrimmed)
    $commandResults.Link = $link
    Log-RunResult -Name "supabase link --project-ref $stagingProjectRefTrimmed" -ExitCode $link.ExitCode -Output ($link.Output | ForEach-Object { Get-SafeText -Text $_ })
    if ($link.ExitCode -ne 0) {
        Write-Output "BLOCKED"
        exit 1
    }

    $migrationList = Invoke-SupabaseCommand -Command $supabaseExecutable.Source -Arguments @("migration", "list", "--linked")
    $commandResults.MigrationList = $migrationList
    Log-RunResult -Name "supabase migration list --linked" -ExitCode $migrationList.ExitCode -Output ($migrationList.Output | ForEach-Object { Get-SafeText -Text $_ })
    if ($migrationList.ExitCode -ne 0) {
        Write-Output "BLOCKED"
        exit 1
    }

    $dryRun = Invoke-SupabaseCommand -Command $supabaseExecutable.Source -Arguments @("db", "push", "--linked", "--dry-run")
    $commandResults.DryRun = $dryRun
    Log-RunResult -Name "supabase db push --linked --dry-run" -ExitCode $dryRun.ExitCode -Output ($dryRun.Output | ForEach-Object { Get-SafeText -Text $_ })
    if ($dryRun.ExitCode -ne 0) {
        Write-Output "BLOCKED"
        exit 1
    }

    $dryRunText = ($dryRun.Output -join "`n")
    $pendingMigrations = [regex]::Matches($dryRunText, '(0\d{3})(?=_)') | ForEach-Object { $_.Value } | Sort-Object -Unique
    $pendingOthers = @($pendingMigrations | Where-Object { $_ -ne "0030" })
    $hasPending0030 = $pendingMigrations -contains "0030"
    $hasAnyPending = $pendingMigrations.Count -gt 0

    $migrationListText = ($migrationList.Output -join "`n")
    $alreadyHas0030 = $migrationListText -match '0030'

    $finalState = "BLOCKED"
    if ($hasPending0030 -and -not $pendingOthers) {
        $finalState = "READY_FOR_STAGING_PREFLIGHT"
    } elseif ($pendingOthers.Count -gt 0) {
        $finalState = "STAGING_BASELINE_INCOMPLETE"
    } elseif ($alreadyHas0030 -and -not $hasAnyPending) {
        $finalState = "STAGING_ALREADY_HAS_0030"
    } else {
        $finalState = "BLOCKED"
    }

    Add-Content -LiteralPath $OutputFile -Value ""
    Add-Content -LiteralPath $OutputFile -Value "FINAL_STATE=$finalState"
    Write-Output $finalState
}
finally {
    Set-Location -LiteralPath $originalLocation
}
