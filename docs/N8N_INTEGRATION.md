# N8N_INTEGRATION.md

# Integración con N8N

## Objetivo

Permitir automatización externa sin que la app dependa de un backend propio.

## Estrategia

- La app crea eventos locales.
- Los eventos se guardan en cola.
- N8N puede consumirlos en una fase futura.
- La app mantiene control local.

## Eventos sugeridos

- EMPLOYEE_CREATED
- ATTENDANCE_REGISTERED
- PAYROLL_GENERATED
- VACATION_APPROVED
- PERMISSION_APPROVED
