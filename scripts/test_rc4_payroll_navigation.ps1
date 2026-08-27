$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$navigation = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/app/navigation.ts')
$layout = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/layouts/AdminLayout.tsx')
$app = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/App.tsx')
$payroll = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/PayrollPage.tsx')
$denied = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/pages/AuthPages.tsx')
$adapter = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'web/src/infrastructure/permissions/permissionAdapter.ts')
$migration = Get-Content -Raw -Encoding UTF8 (Join-Path $root 'supabase/migrations/0010_rc4_payroll_engine.sql')

$routes = '/nomina','/nomina?vista=periodos','/nomina?vista=prestamos','/nomina?vista=creditos','/nomina?vista=historial'
if ($navigation -notmatch "section:'N.MINA'") { throw 'Missing NOMINA sidebar section.' }
foreach ($route in $routes) {
    $contract = [regex]::Escape("to:'$route'") + ".+section:'N.MINA',permission:'nomina.ver'"
    if ($navigation -notmatch $contract) { throw "Missing protected payroll link: $route" }
}
if (($navigation | Select-String -Pattern "section:'N.MINA',permission:'nomina.ver'" -AllMatches).Matches.Count -ne 5) { throw 'NOMINA must contain exactly five RC4 links.' }
foreach ($label in 'Procesamiento','Historial') { if ($navigation -notmatch "label:'$label'") { throw "Missing payroll label: $label" } }
if ($app -notmatch 'path="/nomina" element={<RequirePermission permission="nomina\.ver"><PayrollPage/></RequirePermission>}') { throw 'Direct /nomina reload is not guarded by nomina.ver or does not render PayrollPage.' }
if (($app | Select-String -Pattern '<PayrollPage/>' -AllMatches).Matches.Count -ne 1) { throw 'Duplicate payroll screen or route found.' }
if ($adapter -notmatch 'items\.filter\(item=>reader\.has\(item\.permission\)\)') { throw 'Sidebar does not filter permissions strictly.' }
if ($layout -notmatch 'visibleNavigationItems\(navigationItems,createPermissionReader\(session\?\.permissions\)\)') { throw 'AdminLayout does not use effective session permissions.' }
if ($layout -notmatch 'current===to') { throw 'Sidebar does not distinguish RC4 views by full URL.' }
if ($payroll -notmatch 'useSearchParams' -or $payroll -notmatch "view==='prestamos'" -or $payroll -notmatch "view==='creditos'" -or $payroll -notmatch "view==='historial'") { throw 'PayrollPage does not restore requested view after reload.' }
if ($denied -notmatch '<span>403</span>') { throw 'Missing visible 403 for denied payroll access.' }
if ($migration -notmatch "where r\.code in\('admin','payroll'\)" -or $migration -match "r\.code in\([^\)]*supervisor") { throw 'RC4 base grants do not separate admin and supervisor.' }
if (($navigation + $payroll) -match 'mockData|version demo|safe sample') { throw 'RC4 navigation contains mocks.' }

Write-Output 'OK RC4 navigation: admin with nomina.ver sees five links; supervisor without it sees none; /nomina renders PayrollPage and denied access shows 403.'
