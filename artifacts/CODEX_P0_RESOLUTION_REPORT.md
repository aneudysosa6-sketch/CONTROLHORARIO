# FASE P0 - Resolucion de conflictos funcionales

Fecha: 2026-08-24

## Alcance ejecutado

La fase se implemento exclusivamente en el repositorio local. No se realizaron commits, despliegues, migraciones remotas, instalaciones de APK ni operaciones sobre telefonos. Produccion `[PRODUCTION_PROJECT_REF]` no fue tocada.

## P0.1 Terminal facial GENERAL

- GENERAL sincroniza empleados activos de toda la empresa sin filtrar por sucursal.
- La consulta conserva aislamiento estricto por `empresa_id`.
- La sucursal del terminal se fuerza como ubicacion de la marcacion; se ignora cualquier sucursal aportada por el cliente.
- Empleados inactivos se entregan como tombstones locales.

## P0.2 Terminal facial DEPARTMENTS

- Se agregaron modo `GENERAL`/`DEPARTMENTS`, revision de configuracion y relaciones de departamentos.
- El alta y la edicion Web exigen sucursal y al menos un departamento activo para `DEPARTMENTS`.
- Cambiar sucursal limpia selecciones anteriores.
- `employee-sync` filtra por departamentos y reinicia el cursor cuando cambia la revision.
- `attendance-sync` consulta elegibilidad autoritativa antes de leer estado o registrar.
- Rechazo contractual: `TERMINAL NO AUTORIZADO PARA SU DEPARTAMENTO`.

## P0.3 Autorizacion inmediata

- La migracion incorpora revision de autorizacion y triggers sobre perfil, rol, permisos y alcance.
- Web rehidrata autorizacion cada cinco segundos, al recuperar foco y al volver a estado visible.
- Android revalida la sesion cada cinco segundos sin requerir cierre de sesion o reinicio.
- Las rutas y RPC siguen protegidas por permisos actuales del servidor; una cuenta inactiva pierde la sesion local.

## P0.4 Licencias

- Se implemento licencia directa versionada, sin aprobar/rechazar.
- Alta, edicion desde el inicio original hacia adelante y cancelacion.
- Dias calendario inclusivos.
- Pago diario: `salario mensual / 30 * porcentaje / 100`.
- Regeneracion al cambiar salario y bloqueo de marcaciones durante licencia activa en el contrato SQL.
- Android elimino aprobar/rechazar para `LICENCIA_MEDICA`; Web tiene pantalla RPC dedicada.

## P0.5 NO PAGAR

- Resolucion `NO_PAY` o reconocimiento demostrable.
- Horas manuales de 0 a 8 solo cuando el unico evento es `INICIAR`.
- En cualquier otro caso se usan unicamente intervalos cerrados demostrables.
- Persistencia auditable y bloqueo de edicion con nomina cerrada en el RPC.
- Android y Web eliminaron aprobar/rechazar/editar como decisiones de este flujo.

## P0.6 Ajustes de periodos anteriores

- Captura de delta posterior al cierre.
- Clave idempotente por origen/version/concepto.
- Aplicacion en la siguiente nomina mediante `calcular_nomina_p0`.
- Consulta detallada en Web.

## P0.7 Lista negra mensual

- Seguimiento mensual con multiples motivos y umbrales estrictos.
- Reporte individual, resumen, detalle e impresion Web.
- No participa en la elegibilidad ni bloquea marcaciones.

## P1 asociado - Mensajes offline precargados

- `employee-sync` devuelve mensajes pendientes solo para empleados elegibles del terminal.
- Android conserva una cola cifrada AES-GCM respaldada por Android Keystore.
- Audio se descarga durante la precarga; una falla de precarga hace reintentable el worker.
- El evento local exitoso entrega el primer mensaje precargado del empleado aun sin red.
- La primera confirmacion valida gana en servidor y la reconciliacion elimina tombstones y contenido local.

## Base de datos

- Nueva migracion: `supabase/migrations/0050_p0_functional_contracts.sql`.
- Nuevo pgTAP: `supabase/tests/0050_p0_functional_contracts.sql`.
- No se reutilizaron migraciones 0045-0049.
- No se aplico la migracion a STAGING ni a produccion.

## Validacion local

- Android `:app:testDebugUnitTest`: PASS.
- Android `:app:lintDebug`: PASS.
- Android `:app:assembleDebug`: PASS.
- Web `pnpm install --frozen-lockfile`: PASS.
- Tests Web obligatorios y `test:p0-contracts`: PASS.
- Web `pnpm run build`: PASS, con advertencias no bloqueantes de tamano de chunks.
- pgTAP: BLOQUEADO EXTERNAMENTE; Docker Desktop no esta disponible y la base local no puede iniciar.

## APK

- Ruta: `app/build/outputs/apk/debug/app-debug.apk`.
- Paquete: `com.example.controlhorario.staging`.
- Referencia STAGING `[STAGING_PROJECT_REF]`: presente.
- Referencia produccion `[PRODUCTION_PROJECT_REF]`: ausente.
- Firma: valida, APK Signature Scheme v2, un firmante debug.
- Certificado SHA-256: `[OPERATIONAL_SHA256_REDACTED]`.
- APK SHA-256: `[OPERATIONAL_SHA256_REDACTED]`.

## Limites de verificacion

- STAGING no se declara integrado ni desplegado; solo se verifico su referencia dentro del APK.
- La migracion y pgTAP requieren Docker Desktop local o una ejecucion posterior autorizada en STAGING.
- Terminal facial fisico, audio offline y cambios de autorizacion multiusuario quedan en checklist manual.

## Estado

P0_GENERAL_TERMINAL: PASS

P0_DEPARTMENT_TERMINAL: PASS

P0_IMMEDIATE_AUTHORIZATION: PASS

P0_LICENSES: PASS

P0_NO_PAY: PASS

P0_PRIOR_ADJUSTMENTS: PASS

P0_BLACKLIST: PASS

OFFLINE_MESSAGES_PRELOAD: PASS

ANDROID_TESTS: PASS

ANDROID_LINT: PASS

ANDROID_ASSEMBLE: PASS

WEB_TESTS: PASS

WEB_BUILD: PASS

GIT_DIFF_CHECK: PASS

PRODUCTION_TOUCHED: NO

COMMITS_CREATED: NO

DEPLOYMENTS_PERFORMED: NO
