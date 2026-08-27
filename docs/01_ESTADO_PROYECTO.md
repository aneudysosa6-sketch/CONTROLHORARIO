# ESTADO REAL DEL PROYECTO

Fecha de corte: 2026-08-26
Estado: candidato final validado en STAGING
Producción: no tocada

## 1. Resumen

CONTROL HORARIO está cerrado funcionalmente como Terminal Android de jornadas
más Web administrativa. El flujo físico completo fue validado en un WP23 Plus
contra STAGING [STAGING_PROJECT_REF].

## 2. Estado por capa

| Capa | Estado | Evidencia |
|---|---|---|
| Android terminal-only | PASS | Sin Login/dashboard; registro, cámara o no autorizado |
| Registro de dispositivo | PASS | Código de un solo uso, P-256 y credencial cifrada |
| Registro facial Android | PASS | Pendientes, tres poses, liveness, duplicado y confirmación |
| Identificación facial | PASS | FaceNet-128, threshold 0.75 y margen opcional |
| Jornadas | PASS | INICIAR, PAUSA, REANUDAR y FINALIZAR físicas |
| TTS | PASS | Cuatro frases físicas y callbacks onStart/onDone |
| Offline/revocación | PASS | Lease, reinicio, bloqueo y recuperación |
| Web | PASS | Administración; sin ruta ni generación QR facial |
| PostgreSQL | PASS STAGING | Migraciones hasta 0061 |
| RLS/RPC | PASS STAGING | Matriz pgTAP y controles de tenant |
| Edge Functions | PASS STAGING | Enrolamiento, sync y attendance con auth interna |
| Producción | NO TOCADA | Ref [PRODUCTION_PROJECT_REF] fuera de alcance |

## 3. Android normativo

Android ofrece únicamente:

- código de registro cuando no existe credencial;
- cámara cuando la autorización y el lease son válidos;
- TERMINAL NO AUTORIZADO cuando no son válidos;
- registro facial de pendientes dentro del Terminal;
- reconocimiento y acciones de jornada;
- mantenimiento mínimo detrás de salida protegida.

No ofrece Login, dashboard, portal, empleados, horarios, nómina, reportes,
usuarios, roles, permisos ni administración de dispositivos.

## 4. Biometría

- Modelo: FaceNet-128.
- Entrada: 160 x 160 RGB.
- Salida: 128 valores normalizados.
- Threshold: 0.75, sin cambio.
- Margin: nullable y opcional.
- Liveness: parpadeo validado físicamente.
- Plantilla local: cifrada.
- Imágenes: no persistidas.
- Embeddings: no expuestos en logs.
- Duplicidad: validada por servidor dentro de la empresa.

La calibración de un margen adicional con población amplia sigue pendiente
como optimización; no bloquea la aceptación.

## 5. QR facial

La arquitectura QR permanece solo como historial de migraciones:

- no existe ruta pública Web;
- no existe botón para crear/regenerar QR;
- no se imprime QR;
- RPC antiguas fallan con FACE_QR_ENROLLMENT_DEPRECATED;
- grants de canje/finalización antiguos están revocados;
- invitaciones pendientes quedaron revocadas;
- teléfono personal y JWT normal no pueden enrolar.

No se borra el historial de base de datos.

## 6. Seguridad

- Jornadas requieren Terminal, credencial, firma y prueba biométrica.
- Anti-replay e idempotencia están activas.
- El dispositivo revocado queda bloqueado.
- El lease offline tiene vencimiento.
- El servidor deriva empresa y sucursal desde el Terminal.
- RLS y SECURITY DEFINER fueron validados en STAGING.
- service_role no existe en clientes.
- La salida de kiosco requiere autenticación protegida y no concede
  administración Android.

## 7. Validación física aceptada

En WP23 Plus pasaron:

- cámara directa;
- reconocimiento Persona 1;
- liveness;
- INICIAR;
- PAUSA;
- REANUDAR;
- FINALIZAR;
- JORNADA YA FINALIZADA;
- retiro de cámara;
- TTS de las cuatro acciones;
- reinicio;
- revocación;
- salida protegida.

Estas pruebas no deben repetirse salvo cambios funcionales en el área.

## 8. Deudas no bloqueantes

- Calibrar estadísticamente un face_match_margin opcional con una población
  mayor.
- Certificar PAD avanzado si el riesgo futuro lo requiere.
- Definir firma release y canal formal de promoción a producción.
- Continuar la consolidación del motor de nómina y N8N según roadmap.

## 9. Regla de promoción

El estado es READY FOR PRODUCTION PREPARATION, no un despliegue a producción.
La promoción exige revisión separada de secretos, firma release, backups,
migraciones, Edge, Web, smoke tests y plan de rollback.