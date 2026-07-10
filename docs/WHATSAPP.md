# WHATSAPP.md

# Integración WhatsApp / N8N

## Objetivo

Preparar mensajes para automatización externa mediante N8N.

## Principios

- No enviar desde Compose.
- Crear cola local.
- Registrar estado del mensaje.
- Permitir reintentos.
- Preparar payload claro.

## Estados

- PENDING
- SENT
- ERROR
- CANCELLED

## Usos

- Notificación de nómina.
- Recordatorio de asistencia.
- Alerta de permiso.
- Confirmación de vacaciones.
