$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$migration = Join-Path $root 'supabase/migrations/0011_rc35_system_administration.sql'
$webPage = Join-Path $root 'web/src/pages/SystemAdministrationPage.tsx'
$webService = Join-Path $root 'web/src/modules/administration/administrationService.ts'
$webRoutes = Join-Path $root 'web/src/App.tsx'
$androidScreen = Join-Path $root 'app/src/main/java/com/example/controlhorario/ui/administration/SystemAdministrationScreen.kt'
$androidRoutes = Join-Path $root 'app/src/main/java/com/example/controlhorario/ui/navigation/AppNavigation.kt'

foreach ($file in @($migration,$webPage,$webService,$webRoutes,$androidScreen,$androidRoutes)) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Falta contrato RC3.5: $file" }
}

$sql = Get-Content -LiteralPath $migration -Raw
$web = (Get-Content -LiteralPath $webPage -Raw) + (Get-Content -LiteralPath $webService -Raw) + (Get-Content -LiteralPath $webRoutes -Raw)
$android = (Get-Content -LiteralPath $androidScreen -Raw) + (Get-Content -LiteralPath $androidRoutes -Raw)
$sections = 'empresa','sucursales','departamentos','cargos','usuarios','horarios','jornadas','dispositivos','seguridad','apariencia'
$androidRouteNames = 'admin_empresa','admin_sucursales','admin_departamentos','admin_cargos','admin_usuarios','admin_horarios','admin_jornadas','admin_dispositivos','admin_seguridad','admin_apariencia'
$permissions = 'configuracion.ver','configuracion.empresa','configuracion.sucursales','configuracion.departamentos','configuracion.cargos','configuracion.horarios','configuracion.jornadas','configuracion.seguridad','configuracion.apariencia'

foreach ($section in $sections) {
    if ($web -notmatch [regex]::Escape("/administracion/$section")) { throw "Falta ruta Web independiente: $section" }
    if ($web -notmatch "key:'$section'") { throw "Falta tarjeta Web: $section" }
    if ($android -notmatch [regex]::Escape('("' + $section + '"')) { throw "Falta categoría Android: $section" }
}
foreach ($route in $androidRouteNames) { if ($android -notmatch [regex]::Escape($route)) { throw "Falta ruta Android: $route" } }
foreach ($permission in $permissions) { if ($sql -notmatch [regex]::Escape($permission)) { throw "Falta permiso RC3.5: $permission" } }

if ($sql -notmatch 'create or replace function public\.obtener_administracion_sistema') { throw 'Falta RPC de fuente real compartida.' }
if ($sql -notmatch 'administracion_auditoria enable row level security') { throw 'Falta RLS en auditoría administrativa.' }
if ($sql -notmatch 'company_id=public\.obtener_empresa_actual\(\)' -or $sql -notmatch 'empresa_id=public\.obtener_empresa_actual\(\)') { throw 'Falta aislamiento multiempresa explícito.' }
if ($web -notmatch 'AdministrationError' -or $web -notmatch 'details' -or $web -notmatch 'hint') { throw 'Web no conserva errores PostgREST completos.' }
if ($web -notmatch 'overview\.company\.name') { throw 'Web no muestra la empresa real autenticada.' }
if ($web -match 'ACME Dominicana|mockData|versión demo|muestra segura') { throw 'Administración Web contiene valores ficticios.' }
if ($android -notmatch 'AdministrationVisibilityPolicy\.visibleSections') { throw 'Android no filtra categorías por permisos efectivos.' }
if ($android -notmatch 'Text\("←"') { throw 'Falta flecha superior Android.' }
if ($android -match 'SettingsMenuScreen') { throw 'Permanece el menú Android genérico anterior.' }
$androidScreenText = Get-Content -LiteralPath $androidScreen -Raw
if ($androidScreenText -match 'OSINETSecondaryButton\("Volver"') { throw 'Permanece el botón inferior Volver.' }
if ($androidScreenText -match 'Kiosk|Kiosco|2Connect|Fingerprint') { throw 'Administración Android mezcla alcance kiosco/2Connect.' }

Write-Output 'OK RC3.5: categorías, rutas, datos reales, permisos, RLS, errores y navegación Web/Android cumplen el contrato estático.'
