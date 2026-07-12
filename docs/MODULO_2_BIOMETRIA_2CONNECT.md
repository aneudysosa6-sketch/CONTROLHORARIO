# Módulo 2 — Biometría 2Connect

## Estado actual auditado

Android identifica primero al empleado activo por PIN/código en Room. Después exige una plantilla local activa, captura con el lector USB 2Connect y compara únicamente contra la huella del empleado seleccionado. Solo una coincidencia abre las acciones de jornada. La máquina existente conserva `SIN_JORNADA`, `TRABAJANDO`, `EN_PAUSA` y `FINALIZADA`; después del registro, la navegación vuelve al ponchador.

La plantilla vive hoy en `EmployeeBiometricEntity.templateBase64` dentro de Room. No existe todavía sincronización Android–Supabase, identidad UUID remota, outbox biométrica ni autenticación de dispositivo. Por ello esta entrega no modifica el SDK, Room, PIN, kiosco o jornadas.

## Fundación Supabase

`0005_employee_biometrics_foundation.sql` crea una tabla separada multiempresa para ciphertext, versión de formato, tamaño 256/512, nonce, versión de clave, dispositivo, actor, fechas y estado. Un índice parcial impide más de una huella activa por empleado/tipo. La auditoría registra registrar, reemplazar y desactivar.

`anon` y `authenticated` no tienen acceso a las tablas biométricas. La web solo puede ejecutar `listar_estados_biometricos_empleados()`, que devuelve metadatos del tenant autorizado y nunca template/ciphertext. Los permisos son `empleados.biometria_ver`, `empleados.biometria_registrar` y `empleados.biometria_reemplazar`.

## Etapas pendientes

1. Diseñar autenticación y autorización de dispositivos Android.
2. Añadir UUID remoto y outbox mediante migración Room compatible.
3. Implementar cifrado del template antes de persistir y gestión/rotación de claves fuera del cliente web.
4. Implementar registro/reemplazo desde Android y descarga offline segura.
5. Probar lector desconectado, USB, calidad, tamaños reales, reemplazo, red, reintento, tenant y estados de jornada con RT Series / 2C-LDH808.

El módulo no se considera terminado hasta superar pruebas físicas con el lector 2Connect real.

## Módulo 2.1 — identidad segura del dispositivo

La identidad elegida combina un UUID de instalación aleatorio con un par ECDSA P-256 generado en Android Keystore. La clave privada no es exportable. Una credencial opaca se entrega una sola vez al canjear un código administrativo, se conserva cifrada con AES-GCM/Android Keystore y en Supabase solo se guarda su SHA-256.

La migración `0006_android_device_enrollment.sql` separa dispositivos, códigos temporales, credenciales y auditoría por empresa. Los códigos vencen en diez minutos, son de un solo uso y su consumo es transaccional. Las tablas no conceden acceso a `anon` ni `authenticated`; la Edge Function valida permisos administrativos y usa la cuenta de servicio únicamente en servidor.

La web permite listar, autorizar y revocar dispositivos sin mostrar credenciales, claves privadas o templates. La Edge Function se deja versionada pero no desplegada. La conexión de red Android, los desafíos firmados, la migración Room/outbox y la distribución de claves para cifrar templates quedan pendientes hasta definir sus contratos sin degradar el modo offline.

Amenazas consideradas: copia del APK, extracción de preferencias, repetición de códigos, reutilización de credenciales robadas, acceso cruzado entre empresas y exposición accidental de templates. Siguen pendientes la atestación opcional, rotación automática y pruebas de revocación/sincronización con hardware real.

### Implementación Android del enrolamiento

Android bloquea el primer inicio en `Registrar dispositivo`. El código temporal se canjea directamente con `device-enrollment`; el APK genera ECDSA P-256 en Keystore, guarda la credencial con AES-GCM y conserva el `device_id`. La operación `employee-sync` valida la credencial exclusivamente en la Edge Function y devuelve empleados del tenant del dispositivo, sin PIN, hashes de PIN ni biometría.

Room v27 agrega `remoteId`, metadatos de sincronización y el estado local del enrolamiento mediante una migración explícita 26→27. WorkManager ejecuta una descarga inmediata y otra periódica con restricción de red y backoff. Los datos ya sincronizados permanecen en Room para lectura offline; el merge conserva PIN, huella e ID locales preexistentes.

El endpoint no está hardcodeado ni vive en `BuildConfig`: para compilar una instalación conectada se define `CONTROLHORARIO_DEVICE_ENROLLMENT_URL` con la URL HTTPS de la función. No es un secreto. Esta versión no despliega la función ni cambia lector, captura de huella, kiosco o jornadas.
