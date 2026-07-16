# Panel administrativo web

## Plataformas

OSINET Time ERP Enterprise ahora conserva dos superficies independientes dentro del repositorio:

- `app/`: aplicación Android existente, fuente local de operación con Kotlin, Jetpack Compose, Room y MVVM.
- `web/`: panel administrativo React/TypeScript preparado para Vercel.

## Responsabilidades

Android mantiene el ponchador operativo PIN → huella 2Connect → registro de jornada, Room local y la operación móvil. No se modificó su lógica.

La web ofrece inicio de sesión demostrativo, panel, empleados, auditoría de asistencia, jornadas, kiosco web, reportes, nómina y configuración. El kiosco permite identificar por PIN; el botón de huella informa que la verificación real requiere Android o un dispositivo compatible y no simula biometría.

## Datos e integración futura

Esta versión web usa datos simulados organizados en `src/data`, interfaces en `src/types` y servicios en `src/services`. `localStorage` solo mantiene sesión y cambios temporales de empleados. Reportes y nómina descargan archivos demostrativos.

La integración futura debe usar una API autenticada como punto de sincronización entre la fuente Android/Room y la web. Deben definirse resolución de conflictos, auditoría, autorización por rol, cifrado en tránsito y funcionamiento offline antes de sincronizar datos reales. La web no debe conectarse directamente a Room.

## Vercel

- Root Directory: `web`
- Framework Preset: Vite
- Build Command: `npm run build`
- Output Directory: `dist`
- Install Command: `npm install`

`web/vercel.json` incluye el rewrite SPA necesario. No configurar secretos dentro del repositorio; usar variables cifradas de Vercel cuando exista una API real.
