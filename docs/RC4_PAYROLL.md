# RC4 — Motor completo de nómina

Estado: implementación preparada para despliegue de prueba. La migración no ha sido desplegada y RC4 no se considera cerrada hasta completar las pruebas manuales descritas al final.

## Arquitectura

PostgreSQL es la única autoridad de cálculo. La Web no reproduce fórmulas: crea períodos, carga ajustes, invoca RPC, presenta snapshots persistidos y genera archivos desde esos snapshots. Android no fue modificado y no administra ni expone nómina.

El motor `RC4_SQL_V1` consume `jornadas` RC2 con estado `FINALIZADA`, sin `revision_pendiente` y sin conflictos abiertos. No consume `attendance_records` ni usa permisos como fuente de horas.

## Modelo

La migración `0010_rc4_payroll_engine.sql` crea:

- `nomina_reglas` y `nomina_reglas_empleado`: divisores, jornada diaria, recargos e impuestos explícitos y versionados.
- `nomina_periodos`, `nominas` y `nomina_detalles`: período, cabecera y snapshot por empleado.
- `nomina_prestamos`, `nomina_creditos`, `nomina_ajustes` y `nomina_descuentos`: saldos y ajustes trazables.
- `nomina_auditoria` y `nomina_archivos`: cambios y metadatos de exportación.

Todas las relaciones sensibles incluyen `empresa_id`. Las tablas tienen RLS, lectura limitada a la empresa actual con `nomina.ver` y escritura exclusivamente mediante RPC que vuelve a validar empresa y permiso.

## Reglas del motor

- Quincenal/quincenal y mensual/mensual: salario configurado; mensual en quincena: salario / 2; quincenal en mes: salario × 2.
- Divisor quincenal y horas por día: configurables; valores iniciales 15 y 8 por compatibilidad con la regla vigente.
- Extra/nocturna: valor hora × (1 + porcentaje configurado).
- AFP, SFS y otros impuestos: monto o porcentaje configurado. Todos inician en cero; no se inventan porcentajes legales.
- Préstamo/crédito: `min(pendiente, descuento_periodo)`. Los saldos solo cambian al cerrar, nunca al previsualizar o recalcular.
- Un cambio de jornada marca una nómina calculada como desactualizada y genera auditoría. Una nómina cerrada no se recalcula.

Estados: `BORRADOR → CALCULADA → EN_REVISION → APROBADA → CERRADA`. Se permite `ANULADA` antes del cierre con permiso y motivo. No hay retroceso desde `CERRADA`.

## Web

La ruta `/nomina` requiere `nomina.ver` e incluye períodos, cálculo, revisión, aprobación, cierre, detalle, ajustes manuales, préstamos, créditos, plantilla Excel, vista previa de importación, Excel final de tres hojas, PDF y auditoría. Los errores conservan código, mensaje, detalles y sugerencia de Supabase. No se usan mocks de nómina.

## Permisos y RLS

RC4 añade `nomina.ver`, `nomina.generar`, `nomina.editar`, `nomina.aprobar`, `nomina.cerrar`, `nomina.anular`, `nomina.exportar`, `nomina.prestamos`, `nomina.creditos` y `nomina.descuentos`.

Se asignan a roles activos `admin` y `payroll`. Supervisor no recibe permisos de nómina por defecto. RLS está activo en todas las tablas RC4 y no se confía en filtros frontend.

## Pruebas manuales pendientes

Los contratos automatizados están en `scripts/test_rc4_payroll.ps1` y `supabase/tests/0010_rc4_payroll_contract.sql`. La prueba SQL requiere una instancia local o de prueba con pgTAP y la migración aplicada.

Antes de declarar RC4 terminada se debe:

1. Aplicar `0010` en prueba y ejecutar pgTAP.
2. Verificar admin, payroll, supervisor, empleado y usuario de otra empresa.
3. Probar jornadas finales, pendientes y con conflicto.
4. Probar cálculo, recálculo, revisión, aprobación, cierre y anulación.
5. Confirmar remanentes y saldos cero de préstamos/créditos.
6. Abrir y contrastar plantilla, Excel final y PDF.
7. Cambiar una jornada calculada y confirmar desactualización/auditoría.

No se despliega Supabase ni se hace push como parte de RC4.
