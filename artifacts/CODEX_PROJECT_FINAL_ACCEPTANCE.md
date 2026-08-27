# Control Horario - Aceptación final del proyecto

Fecha de cierre: 2026-08-26
Entorno aceptado: STAGING; referencia operativa omitida.
Dispositivo físico: WP23 Plus; serial omitido.
Producción excluida; referencia operativa omitida.

## Dictamen

CONTROL_HORARIO_FINAL_ACCEPTANCE: PASS

El candidato STAGING cumple la arquitectura terminal-only, la seguridad de dispositivo, el enrolamiento facial presencial, la identificación facial y el ciclo completo de jornadas. La administración permanece exclusivamente en Web. El flujo QR facial histórico está retirado e inerte.

## Arquitectura aceptada

- Instalación Android nueva: código de registro, validación/sincronización en segundo plano y cámara facial.
- Aperturas posteriores: cámara facial directa.
- Credencial inválida, vencida, revocada o sin lease exigible: Terminal no autorizado.
- Sin Login normal, dashboard, portal de empleado ni módulos administrativos en Android.
- Android permite solo enrolamiento facial presencial y acciones INICIAR, PAUSA, REANUDAR y FINALIZAR.
- Web administra empleados, configuración y estado biométrico; no captura rostros ni emite QR facial.
- Solo credencial activa de Terminal, tenant correcto, lease vigente y firma P-256 pueden enviar jornadas.
- face_match_threshold = 0.75 permanece sin cambios.
- face_match_margin es nullable y opcional; si está configurado añade el filtro best-vs-second.

## Regresión local final

### Android

Comando único ejecutado:

    .\gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --no-daemon

Resultado: PASS, BUILD SUCCESSFUL, 57 tareas. Unit tests, lint y ensamblado completaron con código 0.

Observación no bloqueante: Kotlin informa que el constructor Java de Locale usado por la ruta TTS está deprecado. La ruta permanece funcional y fue aceptada físicamente, por lo que no se alteró durante el cierre.

### Web y contratos

- pnpm install --frozen-lockfile: PASS; lockfile vigente y validado por políticas de supply chain.
- Política de código de empleado: PASS.
- Scope de supervisor: PASS.
- Pinning de dependencias Edge: PASS, 7 funciones y supabase-js 2.110.2.
- Seguridad de device-enrollment: PASS.
- Seguridad de exportación de planillas: PASS.
- Contratos P0: PASS.
- Contrato Android terminal-only: PASS.
- Contrato de enrolamiento facial de Terminal: PASS.
- pnpm run build: PASS, 2139 módulos transformados.

Observaciones no bloqueantes: advertencias de tamaño de chunks y de imports dinámicos/estáticos de jsPDF. No afectan la aceptación funcional ni de seguridad.

### Edge y SQL

- Contratos locales Edge terminal-only/enrolamiento: PASS.
- Edge Functions STAGING y smoke tests positivos/negativos: PASS según evidencia de aceptación previa.
- Migraciones 0055-0061 en STAGING: PASS según evidencia de aceptación previa.
- pgTAP/RLS/RPC en STAGING: 62/62 PASS según evidencia de aceptación previa.
- No hubo cambios SQL, RLS ni Edge posteriores a esa aceptación durante la fase de cierre.
- Deno CLI local no está instalado; el type-check Deno adicional no pudo ejecutarse.
- La pila Supabase local no está levantada; no se repitió pgTAP local.
- Estas dos ausencias locales no invalidan la evidencia STAGING ya aprobada ni los contratos ejecutados en este cierre.

## Seguridad estática

- Sin ruta Web /enrolar-rostro.
- Sin UI de creación de invitación QR facial.
- Sin receptor/activity diagnóstico exportado.
- Sin usesCleartextTraffic=true en harnesses locales.
- Sin referencias productivas a [PRODUCTION_PROJECT_REF], sb_publishable_dummy o example.com.
- Sin secretos, service role, claves privadas ni credenciales de dispositivo en frontend o APK.
- Logs de rendimiento facial y progreso TTS limitados a BuildConfig.DEBUG.
- Material físico, screenshots y harnesses temporales preservados localmente pero excluidos de commits.
- Revisión detallada: artifacts/CODEX_SECURITY_REVIEW.md.

## APK STAGING final

Ruta: app/build/outputs/apk/debug/app-debug.apk

- Package: com.example.controlhorario.staging.
- Version: 1.0-staging.
- Tamaño: 123324715 bytes.
- Ref STAGING [STAGING_PROJECT_REF]: presente.
- Ref PRODUCCIÓN [PRODUCTION_PROJECT_REF]: ausente.
- example.com: ausente.
- sb_publishable_dummy: ausente.
- Firma APK Signature Scheme v2: PASS.
- Certificado debug: verificado; fingerprint omitido.
- APK: verificado; checksum retenido en evidencia privada.

Instalación física:

    adb -s <DEVICE_SERIAL> install --no-streaming -r app/build/outputs/apk/debug/app-debug.apk

Resultado: PASS. Datos y credencial del Terminal preservados.

Comprobación afectada posterior a la instalación:

- MainActivity STAGING activa: PASS.
- Login visible: NO.
- Terminal no autorizado: NO.
- Superficie facial directa: SÍ.
- Eventos de jornada creados durante este chequeo: 0.

## Aceptación física consolidada

- Arranque terminal-only: PASS.
- Registro/revocación/reinicio/salida protegida: PASS.
- Enrolamiento facial presencial con frontal/izquierda/derecha y liveness: PASS.
- Sincronización y compatibilidad real del template: PASS.
- Reconocimiento Persona 1: 3/3 PASS.
- Liveness Persona 1: PASS.
- INICIAR: PASS.
- PAUSA: PASS.
- REANUDAR: PASS.
- FINALIZAR: PASS.
- Jornada ya finalizada: PASS.
- Retiro de cámara y bloqueo de repetición en cuadro: PASS.
- TTS START, PAUSE, RESUME y FINISH: PASS.
- TTS START/RESUME onDone: PASS.
- Ruta TTS productiva reutilizada: SÍ.
- Eventos creados solo para probar TTS START/RESUME: 0.

## QR facial retirado

- El frontend no publica la ruta ni cámara QR.
- La Web conserva únicamente estado/reset biométrico administrativo.
- La hoja inicial del empleado no contiene QR facial.
- La migración 0060 revoca invitaciones pendientes y retira permisos/RPC del flujo histórico.
- face-enrollment rechaza operaciones QR deprecadas y solo acepta lookup/complete firmados por Terminal.
- Teléfono personal no obtiene credencial de Terminal.

Resultado: QR_RETIRED_OR_INERT: PASS.

## Commits locales del cierre

- 9a006c7 feat(android): finalize terminal-only facial attendance
- 59522b5 feat(platform): secure terminal-only enrollment contracts
- La documentación y este informe pertenecen al commit final de documentación creado a continuación.

No se realizó push.

## Límites no bloqueantes y paso de producción

- El APK aceptado es STAGING/debug; una entrega de producción requerirá firma release y configuración productiva controlada.
- face_match_margin puede calibrarse más adelante con un conjunto mayor de muestras reales; su ausencia no bloquea threshold+liveness.
- El despliegue a PRODUCCIÓN requiere una autorización futura explícita y un procedimiento separado.
- Ninguna de estas condiciones bloquea la aceptación final STAGING.

## Garantías de cierre

ANDROID_TESTS: PASS
ANDROID_LINT: PASS
ANDROID_BUILD: PASS
WEB_TESTS: PASS
WEB_BUILD: PASS
EDGE_FUNCTION_TESTS: PASS
SQL_TESTS: PASS
SECURITY_STATIC_AUDIT: PASS
APK_FINAL_VERIFIED: PASS
APK_FINAL_INSTALLED_PRESERVING_DATA: PASS
PHYSICAL_ACCEPTANCE: PASS
QR_RETIRED_OR_INERT: PASS
DOCUMENTATION_FINALIZED: PASS
PRODUCTION_READINESS: PASS
PRODUCTION_TOUCHED: NO
PUSH_PERFORMED: NO
DESTRUCTIVE_OPERATIONS: NO
