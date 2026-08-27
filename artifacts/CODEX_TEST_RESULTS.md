# Resultados de pruebas - FINAL VIGENTE

Fecha: 2026-08-24
Alcance: ultimo estado funcional P0 antes de la reconciliacion documental.
JAVA_HOME: `C:\Program Files\Android\Android Studio\jbr`

Este documento contiene una sola fotografia vigente. No se presentan como actuales hashes ni estadisticas de ejecuciones anteriores.

## Android

Comando ejecutado:

```powershell
gradlew.bat :app:testDebugUnitTest :app:lintDebug :app:assembleDebug --no-daemon
```

| Validacion | Resultado vigente |
|---|---|
| `:app:testDebugUnitTest` | PASS |
| `:app:lintDebug` | PASS |
| `:app:assembleDebug` | PASS |
| Gradle | BUILD SUCCESSFUL |

Durante la iteracion se corrigieron el alcance de `remoteId` en `JourneyViewModel` y una prueba Phase4 heredada. El comando completo posterior finalizo correctamente.

## Web

| Comando | Resultado vigente |
|---|---|
| `pnpm install --frozen-lockfile` | PASS |
| `pnpm run test:employee-code` | PASS |
| `pnpm run test:supervisor-scope` | PASS |
| `pnpm run test:edge-dependencies` | PASS |
| `pnpm run test:device-enrollment-security` | PASS |
| `pnpm run test:spreadsheet-export-security` | PASS |
| `pnpm run test:p0-contracts` | PASS |
| `pnpm run build` | PASS |

Vite conserva advertencias no bloqueantes por chunks mayores de 500 kB.

## PostgreSQL y Supabase local

| Validacion | Resultado vigente |
|---|---|
| `supabase test db supabase/tests/0050_p0_functional_contracts.sql` | NO EJECUTADO |
| `supabase start` | BLOQUEADO: Docker Desktop Linux Engine no disponible |
| Migracion 0050 en STAGING | NO APLICADA |
| RLS/SECURITY DEFINER 0050 en PostgreSQL | NO VALIDADOS |
| Edge Functions en STAGING | NO DESPLEGADAS |

No se usaron valores ficticios como evidencia funcional.

## APK FINAL VIGENTE

| Propiedad | Resultado |
|---|---|
| Archivo | `app/build/outputs/apk/debug/app-debug.apk` |
| Paquete | `com.example.controlhorario.staging` |
| STAGING `[STAGING_PROJECT_REF]` | PRESENTE |
| Produccion `[PRODUCTION_PROJECT_REF]` | AUSENTE |
| Firma | APK Signature Scheme v2 verificada |
| Certificado SHA-256 | `[OPERATIONAL_SHA256_REDACTED]` |
| APK SHA-256 FINAL | `[OPERATIONAL_SHA256_REDACTED]` |

El APK no fue instalado.

## GIT FINAL VIGENTE

| Comando | Resultado vigente |
|---|---|
| `git diff --check` | PASS, sin errores de whitespace |
| `git status --short` | Ejecutado; worktree mixto y sin commit |
| `git diff --stat` | 87 archivos tracked modificados, 2574 inserciones, 1641 eliminaciones |
| `git diff --name-status` | 87 archivos tracked modificados |

Los avisos LF a CRLF son informativos y no son hallazgos de `git diff --check`.

## Pruebas externas no realizadas

- No se aplicaron migraciones.
- No se desplegaron Edge Functions.
- No se ejecutaron pgTAP 0050 ni pruebas RLS.
- No se probaron terminales fisicos, camara, rostro, TwoConnect, audio/TTS ni concurrencia multi-terminal.
- No se modifico produccion.
