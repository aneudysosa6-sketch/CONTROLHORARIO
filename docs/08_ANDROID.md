# ANDROID TERMINAL-ONLY

Última actualización: 2026-08-26

## 1. Propósito único

La aplicación Android CONTROL HORARIO registra jornadas desde un Terminal
autorizado y registra rostros pendientes dentro de ese Terminal.

No contiene:

- Login normal;
- dashboard;
- portal del empleado;
- empleados u horarios administrativos;
- nómina o reportes;
- usuarios, roles o permisos;
- administración de dispositivos.

## 2. Compilación STAGING

- Módulo: app.
- Namespace: com.example.controlhorario.
- Package debug/STAGING: com.example.controlhorario.staging.
- Min SDK: 28.
- Target SDK: 36.
- Compile SDK: 36.1.
- Modelo: FaceNet-128.

El APK esperado es app/build/outputs/apk/debug/app-debug.apk.

## 3. Arranque visible

Sin dispositivo registrado:

Código de registro -> validación/sync en segundo plano -> cámara.

Con credencial y lease válidos:

Cámara directamente.

Con credencial inválida, vencida, revocada o revalidación obligatoria fallida:

TERMINAL NO AUTORIZADO.

No se muestra bienvenida, éxito de registro ni estado intermedio.

## 4. Identidad Terminal

DeviceIdentityManager mantiene:

- installation ID local;
- device ID;
- credencial cifrada con AES-GCM/Keystore;
- clave EC secp256r1 no exportable;
- firma SHA256withECDSA.

TerminalAuthorizationManager mantiene:

- fase de autorización;
- instante de validación;
- vencimiento de credencial;
- vencimiento de lease offline;
- motivo de bloqueo seguro.

La cámara solo se presenta cuando TerminalStartupPolicy devuelve AUTHORIZED.

## 5. Sincronización

employee-sync descarga únicamente el alcance del Terminal:

- empleados elegibles;
- configuración facial;
- sucursal y departamentos;
- rostros autorizados;
- conteo de pendientes;
- lease actualizado;
- mensajes operativos.

Los embeddings se cifran antes de persistirse en Room. Room es cache y outbox,
no autoridad remota.

## 6. Registro facial pendiente

El botón aparece solo si pending_face_count es mayor que cero.

Flujo:

1. Introducir código de seis dígitos.
2. Confirmar empleado elegible.
3. Capturar frontal.
4. Capturar izquierda.
5. Capturar derecha.
6. Validar parpadeo.
7. Promediar y normalizar en memoria.
8. Firmar request P-256.
9. Confirmar en servidor.
10. Cifrar únicamente la plantilla confirmada.
11. Volver a cámara.

El servidor vuelve a validar:

- dispositivo activo;
- credencial;
- empresa;
- alcance;
- empleado activo;
- jornada habilitada;
- horario semanal;
- al menos un día libre;
- rostro todavía ausente;
- duplicidad;
- dimensión y norma;
- idempotencia.

El alta no crea eventos de jornada.

## 7. Identificación 1:N

1. CameraX entrega frames.
2. ML Kit detecta y encuadra.
3. Liveness valida parpadeo.
4. FaceNet crea embedding de 128 valores.
5. El motor compara coseno por empleado.
6. Se exige best_score mayor o igual al threshold.
7. Si existe margin, se exige best_score menos second_best_score mayor o igual
   al margin.
8. Si margin es null, se omite solo ese filtro.
9. Se exigen muestras consecutivas antes de confirmar.

Threshold actual: 0.75. No se modificó durante la aceptación.

## 8. Jornada

Después del reconocimiento se ofrece exactamente una acción válida:

- INICIAR;
- PAUSAR;
- REANUDAR;
- FINALIZAR.

Cada evento conserva timestamp original, device ID, sucursal, prueba biométrica,
firma e idempotency key. El servidor decide el estado canónico.

Después de cada acción:

- se reproduce TTS;
- se muestra "Retírate de la cámara para continuar";
- el mismo rostro no dispara otra identificación hasta abandonar el cuadro.

## 9. TTS

Se usa una sola instancia TextToSpeech con idioma es-BO y el listener real de
progreso.

Frases:

- INICIAR: Bienvenido, primer nombre.
- PAUSAR: Recuerda volver a la hora asignada, primer nombre.
- REANUDAR: Gracias por volver, primer nombre.
- FINALIZAR: Adiós, que tengas un excelente resto del día, primer nombre.

Las cuatro fueron escuchadas físicamente en WP23. Los logs de progreso quedan
limitados a debug.

## 10. Kiosco y mantenimiento

- Back bloqueado.
- Modo inmersivo y lock task restaurables.
- Boot receiver abre MainActivity solo si hay dispositivo registrado.
- Salida protegida mediante gesto y autenticación.
- El mantenimiento permite sincronizar, volver o desregistrar.
- No abre módulos administrativos.

## 11. QR

Android no escanea QR facial. Un teléfono personal no se convierte en Terminal.
El flujo QR histórico está deprecado por 0060.

## 12. Seguridad

- TLS obligatorio.
- Cleartext deshabilitado en app.
- service_role prohibido.
- Credencial nunca se registra.
- Clave privada no exportable.
- No persistir imágenes.
- No registrar embeddings.
- Scores de rendimiento solo en debug.
- Revocación y lease bloquean cámara y jornada.

## 13. Pruebas

Regresión local final:

gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --no-daemon

Cobertura relevante:

- arranque terminal;
- margen null y configurado;
- liveness;
- pendientes;
- retiro de cuadro;
- jornada y autorización;
- TTS;
- revocación.

La evidencia física aprobada no se repite salvo cambios funcionales.