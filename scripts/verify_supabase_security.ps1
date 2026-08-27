[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [Console]::OutputEncoding

$root = Split-Path -Parent $PSScriptRoot
$tests = @('security_rls_contracts.sql','security_rpc_contracts.sql')
$ports = 55420,55421,55422,55423,55424,55425,55426,55427,55428,55429
$started = $false

function Invoke-LocalSupabase([string[]]$arguments) {
    & supabase @arguments
    if ($LASTEXITCODE -ne 0) { throw "Falló: supabase $($arguments -join ' ')" }
}
function Invoke-LocalSupabaseWithRetry([string[]]$arguments, [int]$attempts = 3) {
    for ($attempt = 1; $attempt -le $attempts; $attempt++) {
        & supabase @arguments
        if ($LASTEXITCODE -eq 0) { return }
        if ($attempt -eq $attempts) { throw "Falló: supabase $($arguments -join ' ') después de $attempts intentos" }
        Write-Host "INFO: Reintentando supabase $($arguments -join ' ') ($attempt/$attempts)..." -ForegroundColor DarkYellow
        Start-Sleep -Seconds 5
    }
}
function Assert-LocalPort([int]$port) {
    $listener = @(Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue)
    if ($listener.Count -gt 0) { throw "Puerto local ocupado: $port (PID $($listener[0].OwningProcess))." }
}

try {
    Set-Location $root
    if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) { throw 'Supabase CLI no está disponible en PATH.' }
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker CLI no está disponible en PATH.' }
    & docker info *> $null
    if ($LASTEXITCODE -ne 0) { throw 'Docker daemon no está disponible.' }
    & supabase stop --no-backup *> $null
    Start-Sleep -Seconds 2
    foreach ($port in $ports) { Assert-LocalPort $port }
    foreach ($test in $tests) { if (-not (Test-Path -LiteralPath (Join-Path $root "supabase/tests/$test"))) { throw "Falta prueba: $test" } }

    # Prohibido: --linked, --db-url, supabase link y secretos remotos.
    Invoke-LocalSupabase @('start')
    $started = $true
    Invoke-LocalSupabaseWithRetry @('db','reset','--local','--no-seed')
    foreach ($test in $tests) { Invoke-LocalSupabase @('test','db','--local',(Join-Path 'supabase/tests' $test)) }

    $clientSources = @(Get-ChildItem -Recurse -File (Join-Path $root 'app/src/main'),(Join-Path $root 'web/src') | Where-Object { $_.Extension -in '.kt','.ts','.tsx' })
    $clientMatches = @(Select-String -LiteralPath $clientSources.FullName -Pattern 'SUPABASE_SERVICE_ROLE_KEY|service_role' -ErrorAction Stop)
    if ($clientMatches.Count -gt 0) { throw 'service_role aparece en código cliente Android o Web.' }

    $edgeSources = Get-ChildItem -Recurse -File (Join-Path $root 'supabase/functions') -Filter index.ts
    foreach ($function in $edgeSources) {
        $source = Get-Content -LiteralPath $function.FullName -Raw -Encoding UTF8
        if ($source -match 'SUPABASE_SERVICE_ROLE_KEY' -and $source -notmatch 'Deno\.env\.get\(''SUPABASE_SERVICE_ROLE_KEY''\)') { throw "service_role no está limitado a entorno de servidor: $($function.Directory.Name)" }
    }
    Write-Host 'PASS: Auditoría local de RLS, RPC y Edge Functions completada.' -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    if ($started) { & supabase stop --no-backup *> $null; Write-Host 'INFO: Stack local detenido y volúmenes eliminados.' -ForegroundColor DarkYellow }
}
