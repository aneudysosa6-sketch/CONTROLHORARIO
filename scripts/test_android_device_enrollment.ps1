$ErrorActionPreference='Stop'
function Has($path,$pattern,$label){if(-not(Select-String -LiteralPath $path -Pattern $pattern -Quiet)){throw "FALLO: $label"};Write-Host "OK: $label"}
Has 'app/src/main/java/com/example/controlhorario/security/DeviceIdentityManager.kt' 'AndroidKeyStore' 'Keystore'
Has 'app/src/main/java/com/example/controlhorario/device/DeviceEnrollmentScreen.kt' 'completeEnrollment' 'pantalla registra credencial'
Has 'app/src/main/java/com/example/controlhorario/device/EmployeeSyncWorker.kt' 'CoroutineWorker' 'WorkManager'
Has 'app/src/main/java/database/DatabaseProvider.kt' 'Migration\(26,27\)' 'migracion Room explicita'
Has 'app/src/main/java/model/Employee.kt' 'remoteId' 'UUID remoto en empleado'
Has 'supabase/functions/device-enrollment/index.ts' "action==='employee-sync'" 'sync autenticada por dispositivo'
Has 'gradle.properties' '^CONTROLHORARIO_DEVICE_ENROLLMENT_URL=https://heiafcxsvfhinygzxsdk\.supabase\.co/functions/v1/device-enrollment$' 'URL HTTPS de produccion'
Has 'app/build.gradle.kts' 'providers\.gradleProperty\("CONTROLHORARIO_DEVICE_ENROLLMENT_URL"\)' 'URL cargada desde configuracion de aplicacion'
Has 'app/src/main/java/com/example/controlhorario/device/EmployeeSyncWorker.kt' 'getString\(R\.string\.device_enrollment_url\)' 'employee-sync carga URL en runtime'
& rg -n 'service_role|SUPABASE_SERVICE_ROLE_KEY|supabase.*key' app/src/main --glob '*.kt' --glob '*.xml'
if($LASTEXITCODE -eq 0){throw 'FALLO: secreto o service role dentro del APK'}
& rg -n 'TwoConnectFingerprintManager|FPRegModule|MatchTemplate' app/src/main/java/com/example/controlhorario/device app/src/main/java/database/DeviceEnrollmentEntity.kt
if($LASTEXITCODE -eq 0){throw 'FALLO: enrolamiento acoplado a 2Connect'}
Write-Host 'Flujo Android de enrolamiento y sincronizacion verificado.'
