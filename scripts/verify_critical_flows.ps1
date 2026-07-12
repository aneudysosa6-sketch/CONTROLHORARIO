$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

& (Join-Path $PSScriptRoot 'test_employee_sync_module.ps1')

$checks = @(
    @{ File = 'app/src/main/java/com/example/controlhorario/security/BiometricAuthManager.kt'; Pattern = 'BiometricPrompt'; Name = 'BiometricPrompt' },
    @{ File = 'app/src/main/java/com/example/controlhorario/fingerprint/external/TwoConnectFingerprintManager.kt'; Pattern = 'MatchTemplate'; Name = 'comparación 2Connect' },
    @{ File = 'app/src/main/java/ui/punch/EmployeePunchViewModel.kt'; Pattern = 'REQUIRED_PIN_LENGTH = EmployeeCodePolicy.LENGTH'; Name = 'PIN de cinco dígitos' },
    @{ File = 'app/src/main/java/ui/punch/EmployeePunchViewModel.kt'; Pattern = 'Debe verificar la huella 2Connect antes de ponchar'; Name = 'bloqueo sin huella' },
    @{ File = 'app/src/main/java/com/example/controlhorario/ui/navigation/AppNavigation.kt'; Pattern = 'title = "Modo Kiosko"'; Name = 'modo kiosco' },
    @{ File = 'app/src/main/java/com/example/controlhorario/ui/navigation/AppNavigation.kt'; Pattern = 'title = "PIN"'; Name = 'acceso PIN' },
    @{ File = 'app/src/main/java/com/example/controlhorario/ui/navigation/AppNavigation.kt'; Pattern = 'title = "HUELLA"'; Name = 'acceso huella' },
    @{ File = 'app/src/main/java/ui/punch/EmployeeVerifiedAttendanceScreen.kt'; Pattern = 'INICIO_JORNADA'; Name = 'inicio jornada' },
    @{ File = 'app/src/main/java/ui/punch/EmployeeVerifiedAttendanceScreen.kt'; Pattern = 'AttendanceAction.PAUSA'; Name = 'inicio pausa' },
    @{ File = 'app/src/main/java/ui/punch/EmployeeVerifiedAttendanceScreen.kt'; Pattern = 'AttendanceAction.REANUDAR'; Name = 'reanudar jornada' },
    @{ File = 'app/src/main/java/ui/punch/EmployeeVerifiedAttendanceScreen.kt'; Pattern = 'FIN_JORNADA'; Name = 'fin jornada' },
    @{ File = 'app/src/main/java/database/AppDatabase.kt'; Pattern = 'abstract class AppDatabase'; Name = 'Room' }
)

foreach ($check in $checks) {
    $path = Join-Path $root $check.File
    if (-not (Test-Path -LiteralPath $path)) { throw "Falta archivo crítico: $($check.File)" }
    if (-not (Select-String -LiteralPath $path -SimpleMatch $check.Pattern -Quiet)) {
        throw "Contrato crítico ausente: $($check.Name)"
    }
    Write-Output "OK: $($check.Name)"
}

Write-Output 'Todos los contratos críticos permanecen presentes.'
