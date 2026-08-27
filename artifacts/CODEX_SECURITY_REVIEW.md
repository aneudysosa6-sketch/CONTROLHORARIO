# Revisión de seguridad final

Fecha: 2026-08-26
Alcance: cierre terminal-only en STAGING
Producción: no tocada

## Dictamen

Las áreas recientes quedaron revisadas estática y dinámicamente en STAGING:

| Área | Estado |
|---|---|
| Credencial Terminal y Keystore | PASS |
| Firma P-256 | PASS |
| Revocación | PASS |
| Lease offline | PASS |
| Attendance device-only | PASS |
| Anti-replay e idempotencia | PASS |
| Tenant y alcance | PASS |
| RLS | PASS |
| SECURITY DEFINER | PASS |
| Registro facial Android | PASS |
| Duplicidad facial | PASS |
| QR histórico inerte | PASS |
| Salida protegida | PASS |
| Logs sin secretos/embeddings | PASS |

## Controles

- Android no ofrece Login ni módulos administrativos.
- JWT Web o teléfono personal no pueden registrar jornadas ni rostro.
- face-enrollment exige credencial, firma, timestamp, tenant, alcance, tres
  poses, liveness, dimensión, hash e idempotencia.
- attendance-sync exige credencial, dispositivo activo y prueba biométrica.
- Las RPC terminales no se conceden a anon o authenticated.
- Las invitaciones QR pendientes se revocaron y las RPC antiguas fallan
  cerradas.
- service_role permanece únicamente en Edge.
- No se guardan imágenes.
- Los scores de rendimiento y callbacks TTS se registran solo en debug.
- Los entry points de diagnóstico local quedaron desconectados y deshabilitados.

## Evidencia

- Migraciones 0055-0061 en STAGING.
- pgTAP/RLS/RPC: PASS.
- Edge Functions terminales: PASS.
- WP23: enrolamiento, reconocimiento, liveness, jornada, TTS, retiro de
  cámara, reinicio, revocación y salida protegida: PASS.

## Riesgos no bloqueantes

- face_match_margin no tiene calibración poblacional amplia y permanece
  opcional.
- La firma release y la promoción a producción requieren una fase separada.
- PAD avanzado puede evaluarse según riesgo futuro.

## Prohibiciones de cierre

- No producción.
- No push.
- No secretos en Git.
- No artefactos físicos, APK, dumps, logs o calibración en commits.