# PAYROLL.md

# Nómina

## Objetivo

Calcular y documentar pagos de empleados.

## Componentes

- PayrollEntity
- PayrollDao
- PayrollRepository
- PayrollEngine
- PayrollViewModel
- PayrollScreen

## Conceptos

- Salario base.
- Horas trabajadas.
- Ingresos.
- Descuentos.
- Neto a pagar.
- Historial.

## Reglas

No mezclar modelos antiguos y nuevos.  
No crear PayrollResult duplicado.

## Alcance definitivo

Nómina conserva cálculo, vista previa, edición, aprobación, generación, historial, auditoría y descarga en Excel/PDF. No incluye estados, botones, reintentos ni entrega mediante mensajería externa.

CONTROLHORARIO no incluye Gmail, WhatsApp ni n8n. Las alertas y notificaciones son internas.
