# ROADMAP POST-ACEPTACIÓN

Fecha base: 2026-08-26

## 1. Completado

- Android terminal-only sin Login ni dashboard.
- Registro de dispositivo con código temporal y P-256.
- Cámara directa con lease válido.
- Bloqueo por revocación o autorización inválida.
- Registro facial dentro del Terminal.
- Conteo y botón de pendientes.
- Tres poses, liveness y FaceNet-128.
- Protección de duplicados.
- Threshold primario y margin opcional.
- Jornada física completa en WP23.
- TTS de las cuatro acciones.
- Retiro de cámara.
- QR facial retirado.
- RLS, tenant, SECURITY DEFINER, Edge y STAGING de fase validados.

## 2. P1 - Preparación de producción

### Firma y distribución Android

- definir versionCode/versionName;
- crear/custodiar keystore release;
- generar APK/AAB release;
- validar actualización preservando datos;
- planificar rollout y rollback.

### Promoción Supabase

- backup y preflight;
- confirmar historial de migraciones;
- aplicar delta secuencial;
- desplegar solo Edge requeridas;
- smoke tests positivos y negativos;
- postflight y monitoreo.

### Promoción Web

- revisión exacta;
- variables de producción;
- CSP de producción;
- build reproducible;
- deploy y rollback;
- smoke tests de roles, permisos y administración.

## 3. P2 - Mejoras no bloqueantes

### Calibración poblacional

Recoger muestras genuinas e impostor suficientes para evaluar si conviene
configurar face_match_margin. No cambiar threshold automáticamente.

Criterios:

- población representativa;
- métricas FAR/FRR;
- iluminación y distancias reales;
- valores numéricos sin imágenes ni embeddings;
- rollback de configuración.

### PAD avanzado

Evaluar certificación contra foto, pantalla o máscara si el análisis de riesgo
lo exige. El liveness actual por parpadeo permanece activo.

### Observabilidad

- métricas de sincronización;
- alertas por revocación/replay;
- correlation ID;
- retención segura;
- sin PII ni biometría.

### Calidad de plataforma

- fijar dependencias Web aún declaradas como latest;
- modularizar navegación terminal sin cambiar comportamiento;
- consolidar el motor de nómina;
- completar N8N con outbox y firma.

## 4. Regla de avance

Una mejora pasa a completada solo con implementación, prueba, seguridad,
despliegue en el entorno autorizado y documentación. Ninguna mejora futura
reabre la aceptación terminal actual por sí sola.