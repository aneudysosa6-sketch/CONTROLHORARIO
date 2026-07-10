# Protección del flujo biométrico

## Implementación actual protegida

| Flujo | Clases/pantallas | Dependencias |
|---|---|---|
| BiometricPrompt del dispositivo | `BiometricAuthManager`, `AttendanceScreen` | `androidx.biometric:biometric:1.1.0`, FragmentActivity |
| Lector USB 2Connect | `TwoConnectFingerprintManager`, `EmployeePunchScreen`, `FingerprintRegistrationScreen` | `fplib-reader-v3.jar`, USB/OTG, vendor/product IDs |
| Estado y persistencia | `EmployeePunchViewModel`, `EmployeeBiometricRepository/Dao/Entity`, `AttendanceViewModel` | Room, coroutines |
| Navegación | `AppNavigation`: kiosco → PIN/HUELLA → punch → asistencia verificada | Navigation Compose |

## Flujo 2Connect

PIN de 5 dígitos → empleado activo → plantilla local existente → permiso USB → captura → comparación SDK → `biometricVerified=true` → pantalla con iniciar/pausar/reanudar/finalizar → registro Room. Error, timeout, desconexión o score inválido no registran asistencia.

## BiometricPrompt

Acepta `BIOMETRIC_STRONG` o credencial del dispositivo, ejecuta callback principal y registra solo el éxito. Cancelación, error o autenticación fallida retornan mensaje; no deben convertirse en éxito por reintento de UI.

## Offline y privacidad

El ponche actual funciona localmente con Room. Supabase recibirá únicamente resultado, empleado, dispositivo autorizado, instante, acción e idempotency key. Nunca imagen ni plantilla biométrica. El `templateBase64` local de 2Connect es un riesgo legado: no se sincroniza; debe cifrarse/retirarse con una migración Android específica y pruebas de hardware.

## Compatibilidad

2Connect reconoce USB IDs `0453:9005`, `2009:7638`, `2109:7638`, `0483:5720`; requiere OTG, permiso USB y Activity activa. BiometricPrompt requiere Android API compatible; minSdk del proyecto es 28.

## Regresiones a bloquear

- desaparición de PIN o HUELLA del kiosco;
- bypass de plantilla/biometría;
- cambio de los cuatro tipos de acción;
- pérdida de permiso USB o receiver seguro;
- almacenamiento remoto de plantilla;
- navegación directa a asistencia sin verificación;
- doble ponche por recomposición/reintento.

## Pruebas necesarias

La verificación `scripts/verify_critical_flows.ps1` comprueba contratos estructurales. Faltan pruebas instrumentadas con dispositivo real: permiso concedido/denegado, attach/detach, timeout, dedo incorrecto, cancelación, proceso recreado, cuatro eventos, offline/reinicio y duplicado. Deben ejecutarse antes y después de cada movimiento Android.
