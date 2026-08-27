# DESPLIEGUE

Última actualización: 2026-08-26

## 1. Regla absoluta

STAGING y PRODUCCIÓN son entornos distintos.

- STAGING: [STAGING_PROJECT_REF].
- PRODUCCIÓN: [PRODUCTION_PROJECT_REF].

La aceptación actual no autoriza desplegar a producción.

## 2. Android STAGING

Configuración esperada:

- package com.example.controlhorario.staging;
- URLs HTTPS del proyecto STAGING;
- publishable key de STAGING;
- ninguna referencia al proyecto de producción;
- ninguna URL example.com;
- ningún valor sb_publishable_dummy.

Regresión:

gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --no-daemon

APK:

app/build/outputs/apk/debug/app-debug.apk

Verificación:

- package;
- referencia STAGING presente;
- referencia producción ausente;
- firma APK;
- SHA-256.

Si el código Android cambia después de una prueba física, instalar con adb
install --no-streaming -r para preservar datos y repetir solo el área afectada.

## 3. Web STAGING

Desde web:

pnpm install --frozen-lockfile

Ejecutar cada script test definido en package.json y después:

pnpm run build

Comprobar:

- variables de STAGING;
- HTTPS;
- CSP limitada al proyecto aprobado;
- ausencia de rutas QR;
- ausencia de secretos;
- salida web/dist.

## 4. SQL y Edge

No repetir toda la validación remota por rutina.

Solo cuando exista delta en migraciones, RLS, RPC o Edge:

1. Confirmar project ref STAGING.
2. Revisar el delta.
3. Aplicar o desplegar únicamente lo afectado.
4. Ejecutar casos positivos y negativos del área.
5. Revisar logs.
6. Confirmar que producción no fue tocada.

Las funciones con autenticación interna se despliegan con no-verify-jwt solo
cuando su handler conserva la validación específica.

## 5. QR facial

No desplegar una Web pública de enrolamiento facial. La arquitectura vigente
usa exclusivamente el Terminal Android. Las estructuras SQL históricas se
mantienen inertes y no se eliminan.

## 6. Evidencia aceptada

STAGING ya demostró:

- migraciones 0055-0061;
- pgTAP/RLS/RPC;
- Edge terminales;
- terminal-only;
- registro facial Android;
- jornada completa;
- revocación, lease y replay;
- TTS y hardware WP23.

## 7. Preparación de producción

READY FOR PRODUCTION PREPARATION significa que puede iniciarse un plan de
promoción, no que producción esté desplegada.

La preparación debe incluir:

- commit/revisión exacta;
- firma release y custodia del keystore;
- backup;
- inventario de secretos;
- migraciones preflight/postflight;
- deploy Edge selectivo;
- deploy Web selectivo;
- rollout Android;
- smoke tests;
- rollback;
- observabilidad y responsables.

## 8. Prohibiciones

- No usar producción para pruebas.
- No ejecutar db reset remoto.
- No editar migraciones aplicadas.
- No desplegar todas las Edge por costumbre.
- No colocar service_role en cliente.
- No distribuir APK debug como release final.
- No hacer push desde una fase local sin autorización.