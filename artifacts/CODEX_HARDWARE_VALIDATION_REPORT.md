# CODEX HARDWARE VALIDATION REPORT

Fecha: 2026-08-24
Rama: `feature/production-readiness`
Proyecto autorizado: STAGING `[STAGING_PROJECT_REF]`
Proyecto prohibido: PRODUCCION `[PRODUCTION_PROJECT_REF]`

## 1. Resultado ejecutivo

La fase de hardware no pudo ejecutar escenarios fisicos porque no se obtuvo una sesion ADB utilizable con el telefono. El OUKITEL fue visible mediante el anuncio mDNS `adb-<DEVICE_SERIAL>-<SESSION_SUFFIX>`, pero el endpoint `_adb-tls-connect._tcp` anunciado rechazo cada conexion con error Windows 10061. `adb devices -l` permanecio vacio.

La validacion se detuvo de forma segura antes de instalar o modificar el dispositivo. No se ejecuto ninguna operacion destructiva. El APK STAGING candidato si pudo verificarse completamente de forma local.

En la tabla final, `FAIL` para escenarios fisicos significa requisito de aceptacion no ejecutado por bloqueo de conexion del dispositivo; no representa un fallo funcional observado en Android.

## 2. Descubrimiento del dispositivo

- ADB no estaba inicialmente en `PATH`.
- Se utilizo el ejecutable del SDK local en `Android\Sdk\platform-tools\adb.exe`.
- El daemon ADB local inicio correctamente.
- `adb devices -l`: ningun dispositivo conectado o autorizado.
- `adb mdns services`: anuncio detectado para `adb-<DEVICE_SERIAL>-<SESSION_SUFFIX>`.
- El identificador es consistente con el OUKITEL WP23 Plus esperado.
- La conexion al endpoint descubierto dinamicamente fue rechazada con `10061`.
- Se refresco mDNS y se repitio una vez el intento tras validar el APK; el resultado fue el mismo.
- No se uso un serial ni endpoint historico hardcodeado.

Dispositivo utilizable: NO.

## 3. Dispositivo y Android

- Modelo esperado/anunciado: OUKITEL WP23 Plus, inferido del nombre mDNS.
- Modelo mediante `getprop`: no disponible por falta de sesion ADB.
- Version Android: no disponible por falta de sesion ADB.
- Serial ADB autorizado: no disponible.
- Estado Device Owner: no consultable. Se conserva la linea base segura de NO asumir Device Owner.

## 4. APK STAGING

APK candidato:

<LOCAL_PATH_REDACTED>

- Package: `com.example.controlhorario.staging`.
- Tamano: 122,686,079 bytes.
- SHA-256: `[OPERATIONAL_SHA256_REDACTED]`.
- Firma APK: verificada correctamente por `apksigner`.
- Referencia STAGING `[STAGING_PROJECT_REF]`: presente, 9 coincidencias.
- Referencia PRODUCCION `[PRODUCTION_PROJECT_REF]`: ausente.
- `example.com`: ausente.
- `sb_publishable_dummy`: ausente.

No se genero otro APK porque no hubo cambios Android. No se instalo el APK porque no existia una sesion ADB segura.

## 5. Instalacion y persistencia

- `adb install --no-streaming -r`: no ejecutado.
- Aplicacion instalada en el telefono: no consultable.
- Version instalada: no consultable.
- Sesion previa: no consultable.
- Enrolamiento previo: no consultable.
- Configuracion local previa: no consultable.
- Datos alterados por esta fase: NO.
- Datos eliminados por esta fase: NO.

No se puede afirmar que una actualizacion preserve enrolamiento/configuracion hasta completar una instalacion `-r` con el dispositivo conectado.

## 6. Camara y reconocimiento

Estado: NO EJECUTADO, bloqueado por conexion ADB/dispositivo.

No fue posible validar:

- Camara frontal o trasera.
- Orientacion.
- Deteccion de uno o multiples rostros.
- Distancia e iluminacion.
- Indicaciones de acercarse, alejarse o mirar al frente.
- Retiro del rostro tras una accion.
- Liveness.

## 7. Registro facial

Estado: NO EJECUTADO, bloqueado por conexion ADB/dispositivo.

No se capturaron imagenes ni se generaron o expusieron embeddings. No se realizaron cambios sobre empleados STAGING.

## 8. Reconocimiento y acciones de jornada

Estado: NO EJECUTADO, bloqueado por conexion ADB/dispositivo.

No fue posible ejecutar fisicamente:

- INICIAR JORNADA.
- PAUSA.
- REANUDAR.
- FINALIZAR.
- Mensajes visuales posteriores.
- Retorno a camara.
- Requisito de abandonar el cuadro.

La logica servidor correspondiente permanece aprobada por la fase STAGING previa.

## 9. Audio y TTS

Estado: NO EJECUTADO, bloqueado por conexion ADB/dispositivo.

No se pudo verificar volumen, velocidad, frases, prueba de voz ni ausencia de vibraciones/tonos adicionales.

## 10. Mensajes y modo offline

Estado: NO EJECUTADO, bloqueado por conexion ADB/dispositivo.

No se manipulo Wi-Fi ni conectividad, porque no existia un metodo ADB de recuperacion confirmado. No se pudo validar entrega offline de mensajes ni sincronizacion posterior.

## 11. Asistencia offline

Estado: NO EJECUTADO, bloqueado por conexion ADB/dispositivo.

No fue posible comprobar almacenamiento local, timestamp original, terminal/sucursal fisica ni idempotencia desde hardware. Estos contratos permanecen aprobados a nivel servidor/STAGING.

## 12. Terminal GENERAL y DEPARTMENTS

Estado fisico GENERAL: NO EJECUTADO.
Estado fisico DEPARTMENTS: NO EJECUTADO.

No se pudo reconocer empleados ni comprobar mensajes fisicos. Los contratos STAGING de ambos modos permanecen en PASS y no fueron repetidos.

## 13. Estados especiales

Estado: NO EJECUTADO.

No se probaron fisicamente LICENCIA, VACACIONES, INACTIVO, PENDIENTE, BLOQUEADO ni JORNADA YA FINALIZADA.

## 14. Pantalla de espera

Estado: NO EJECUTADO.

No se modifico temporalmente ningun timeout.

## 15. Salida de terminal y lock task

Estado: NO EJECUTADO.

No se pudo validar pulsacion de cinco segundos, credenciales, permiso, retorno al panel o persistencia. No se intento aprovisionar Device Owner. Lock task profesional permanece bloqueado por la precondicion Device Owner.

## 16. Reinicio y persistencia

Estado: NO EJECUTADO.

No se reinicio la aplicacion ni el telefono. No se realizo factory reset.

## 17. Multi-terminal

Estado: `BLOCKED_SECOND_DEVICE`.

Solo se detecto un anuncio de dispositivo y no hubo una sesion ADB utilizable. La logica servidor multi-terminal ya estaba validada en STAGING.

## 18. Smoke HTTP autenticado

Estado: `BLOCKED_CREDENTIALS`.

No existen credenciales administrativas o de usuario de prueba disponibles para crear y retirar de forma segura una identidad temporal STAGING. No se reutilizaron credenciales reales ni se imprimieron tokens.

## 19. Operaciones prohibidas

No se ejecuto:

- `adb uninstall`.
- `adb shell pm clear`.
- Factory reset.
- `dpm set-device-owner`.
- Eliminacion de cuentas.
- Eliminacion de usuarios o espacios privados.
- Manipulacion de red del telefono.
- Instalacion de APK.
- `git push`.
- Operaciones sobre PRODUCCION.

## 20. Errores y correcciones

Error externo:

- El servicio wireless ADB se anuncia por mDNS, pero rechaza la conexion TCP en el endpoint anunciado.

Correcciones de codigo: ninguna. No se observo un bug Android porque la aplicacion no pudo ejecutarse en hardware.

Accion necesaria fuera del repositorio:

- Habilitar o refrescar Depuracion inalambrica en el OUKITEL, o conectarlo por USB con autorizacion ADB, hasta que aparezca como `device` en `adb devices -l`.

## 21. Commits adicionales

No hubo correcciones de codigo. El unico cambio local de esta fase es este informe documental.

## 22. Resultado final

```text
DEVICE_DETECTED: NO
STAGING_APK_INSTALLED: NO
DATA_PRESERVED: YES

CAMERA: FAIL
FACE_ENROLLMENT: FAIL
FACE_RECOGNITION: FAIL
LIVENESS: FAIL
JOURNEY_ACTIONS: FAIL
TTS_AUDIO: FAIL
OFFLINE_ATTENDANCE: FAIL
OFFLINE_MESSAGES: FAIL
WAIT_SCREEN: FAIL
GENERAL_TERMINAL_HARDWARE: FAIL
DEPARTMENT_TERMINAL_HARDWARE: FAIL
KIOSK_EXIT: FAIL
RESTART_PERSISTENCE: FAIL

DEVICE_OWNER: NO
LOCK_TASK_PROFESSIONAL: BLOCKED_DEVICE_OWNER
MULTI_TERMINAL_HARDWARE: BLOCKED_SECOND_DEVICE
AUTHENTICATED_HTTP_SMOKE: BLOCKED_CREDENTIALS

LOCAL_FIXES_REQUIRED: NO
ADDITIONAL_COMMITS: 1

PRODUCTION_TOUCHED: NO
DESTRUCTIVE_OPERATIONS: NO
PUSH_PERFORMED: NO

CONTROL_HORARIO_READY_FOR_FINAL_ACCEPTANCE: NO
```

La aceptacion final requiere restablecer una conexion ADB no destructiva y ejecutar los escenarios fisicos pendientes. El APK candidato ya cumple package, firma, hash y guardas STAGING.