# CONTROLHORARIO — 0044 FUNDACIÓN CANÓNICA (CANDIDATO)

**Estado:** candidato para auditoría y pruebas en STAGING. **NO aplicar en producción.**

## Alcance implementado

- Cutover por empresa con `estado` por defecto `INACTIVO`.
- Identidad económica estable por empresa + empleado + fecha + concepto.
- Cinco conceptos canónicos únicamente:
  - `SALARY_DAY_BASE`
  - `SALARY_DAY_ADJUSTMENT`
  - `SALARY_DAY_OVERTIME`
  - `HOLIDAY_NORMAL_PREMIUM`
  - `SALARY_30DAY_COMPLEMENT`
- Reconciliación privada y explícita; 0044 no instala triggers automáticos sobre 0043.
- Deltas append-only en `public.nomina_movimientos_tiempo_real`.
- Cada revisión de fuente queda registrada mediante `CONTROL` monto 0.
- Source key encadenado e idempotente por identidad, predecesor, revisión/input_hash y target.
- Fuente desaparecida: target 0 mediante evento `ABSENT`, sin UPDATE/DELETE histórico.
- Reducción por debajo de dinero ya consumido: el pago histórico no se reescribe; el exceso queda como crédito residual en un `CONTROL` monto 0.
- El crédito residual todavía **no se aplica como DEDUCCIÓN** en 0044.

## Fuera de alcance de 0044

- AFP/SFS.
- Préstamos, créditos y demás deducciones.
- Cambios a `private.movimiento_nomina_es_pagable`.
- Cambios a `private.listar_pagos_pendientes_movimientos`.
- Cambios a `public.obtener_resumen_pagos_tiempo_real`.
- Cambios a `public.listar_historial_pagos`.
- Cambios a `public.registrar_pago_empleado`.
- Desactivar o reemplazar triggers/guards de 0038.
- Activar automáticamente el cutover.
- Backfill automático.

## Propiedad shadow de 0044

Los movimientos `CANONICAL_SALARY_*` no llevan `jornada_id` ni `journey_dependencies` y no se vuelven pagables con la función 0038 actual. 0046 será responsable de integrar el pago/cutover explícito.

## Pruebas incluidas

`supabase/tests/0044_canonical_payroll_foundation.sql` cubre:

- estructura, RLS y privilegios;
- cutover INACTIVO;
- conservación de guards 0038;
- ausencia de triggers automáticos 0044;
- cuatro objetivos diarios y complemento de febrero;
- ajuste negativo como `REVERSO_DEVENGO`;
- revisión con mismo target sin duplicación monetaria;
- revisión con cambio económico por delta;
- desaparición a target 0;
- reaparición de la misma revisión/hash después de `ABSENT`;
- orden estable de eventos dentro de una misma transacción;
- reducción no pagada sin crédito ficticio;
- reducción que cruza dinero ya pagado con crédito residual `CONTROL 0`;
- preservación byte-a-byte del header de pago sintético;
- cancelación append-only de un crédito residual aún no aplicado;
- ausencia de AFP/SFS en 0044;
- identidad económica inmutable.

## Validación realizada antes de entregar

Validación estática únicamente:

- no aparece `default 'ACTIVE'`;
- no se usa `movimiento_tiempo_real_id`;
- se usa `nomina_pago_movimientos.movimiento_id`;
- todos los `CONTROL` generados por 0044 usan monto 0;
- `extensions.digest()` está cualificado;
- no se reemplaza `registrar_pago_empleado`;
- no se reemplaza `movimiento_nomina_es_pagable`;
- no se instalan triggers sobre resoluciones/complementos/ledger 0038;
- se usan columnas reales 0043: `fecha_local`, `revision`, `input_hash`;
- están presentes los cinco conceptos canónicos.

**Importante:** aún no se ha ejecutado pgTAP contra STAGING. El siguiente paso es revisar hash y `db push --dry-run`; no aplicar 0044 hasta completar esa validación.
