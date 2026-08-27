# Cambios vigentes de base de datos

Fecha de reconciliacion: 2026-08-24
Estado remoto: ninguna migracion de esta fase fue aplicada a STAGING o produccion.

## Cadena local

| Migracion | Proposito |
|---|---|
| `0045_kiosk_face_mode_manage.sql` | Gestion de modo facial/quiosco |
| `0046_supervisor_multi_branch_scope.sql` | Alcance supervisor multi-sucursal/departamento |
| `0047_random_employee_codes.sql` | Codigos aleatorios unicos de empleado |
| `0048_attendance_chronology_guards.sql` | Cronologia y guardas de asistencia |
| `0049_employee_messages.sql` | Mensajes efimeros, recibos y audio privado |
| `0050_p0_functional_contracts.sql` | Reconciliacion funcional P0 |

El orden es obligatorio: 0050 depende de contratos de alcance, empleados, asistencia y mensajes definidos o ampliados por las migraciones anteriores.

## Migracion 0050_p0_functional_contracts.sql

### Terminal GENERAL

- Define el uso GENERAL como elegibilidad de todos los empleados activos de la misma empresa.
- La sucursal configurada no filtra empleados; se conserva como ubicacion de la marcacion.
- La elegibilidad vuelve a comprobarse en servidor antes de registrar asistencia.

### Terminal DEPARTMENTS

- Persiste modo, sucursal, uno o mas departamentos y revision de configuracion.
- Exige departamentos activos compatibles con la sucursal.
- Proporciona funciones de configuracion/elegibilidad para Edge y sincronizacion.
- El rechazo fuera de alcance usa el contrato `TERMINAL NO AUTORIZADO PARA SU DEPARTAMENTO`.

### Revision de autorizacion

- Agrega revision server-authoritative y triggers para invalidar permisos/sesiones cacheadas.
- Expone RPC de revision/guardas consumidas por Web y Android.
- Los clientes no necesitan logout ni reinicio para observar un cambio.

### Licencias

- Agrega persistencia versionada y dias de licencia.
- Implementa alta directa, edicion solo hacia adelante, cancelacion y consulta.
- Restringe porcentaje a 0-100 y usa dias calendario.
- Calcula pago por dia como `salario mensual / 30 * porcentaje`.
- Regenera valores aplicables cuando cambia el salario.
- Proporciona comprobacion de licencia activa para asistencia/nomina.

### NO PAGAR

- Agrega resolucion persistente y auditable de jornadas incompletas.
- Usa intervalos demostrables cuando existen.
- Solo permite horas manuales de 0 a 8 cuando el unico evento es INICIAR.
- Impide edicion cuando la nomina correspondiente esta cerrada.
- Conserva actor, motivo, fecha y valores necesarios para auditoria.

### AJUSTES ANTERIORES

- Captura diferencias posteriores al cierre sin reabrir ni mutar el periodo original.
- Usa clave/guardas de idempotencia para evitar duplicados.
- Aplica el ajuste una sola vez en la siguiente nomina abierta.
- Expone detalle de periodo origen, empleado, concepto, monto y motivo.
- Incluye wrapper de calculo de nomina P0.

### EMPLEADO EN LISTA NEGRA

- Materializa/refresca evaluacion mensual por ausencias, tardanzas y jornadas incompletas.
- Permite reporte consolidado e individual.
- No participa en la elegibilidad de asistencia y no bloquea marcaciones.

### Mensajes offline

- Amplia funciones de precarga y recibo para sincronizacion de terminales.
- Conserva semantica de primera recepcion, idempotencia y tombstones.
- El contenido pendiente puede precargarse; la auditoria de recibo no debe copiar texto/audio.

## RLS y alcance

- Las tablas P0 habilitan politicas por empresa y permiso aplicable.
- El acceso directo del cliente queda limitado; operaciones sensibles pasan por RPC.
- La revision fue estatica y verifico intencion de aislamiento multiempresa y grants minimos.
- RLS 0050 no fue ejecutada ni validada con identidades reales.

## SECURITY DEFINER

- Las funciones SECURITY DEFINER de 0050 fueron revisadas estaticamente para validar autenticacion, empresa, permiso y alcance antes de operar.
- Las funciones de terminal derivan empresa/sucursal del dispositivo autenticado y no de datos confiados al cliente.
- Las funciones de nomina/licencias/resoluciones conservan controles de estado e idempotencia.
- Grants, `search_path` efectivo y comportamiento bajo roles reales deben comprobarse en PostgreSQL/STAGING.
- La revision estatica no constituye aprobacion para produccion.

## Constraints e indices

La migracion incluye controles para modos GENERAL/DEPARTMENTS, porcentajes, rangos de fecha, estados, horas manuales, claves de empresa/empleado/periodo y relaciones activas. Incluye indices orientados a revision de autorizacion, configuracion de terminal, busquedas por empleado/periodo, licencias activas, resoluciones, ajustes, lista negra y recibos. Su eficacia y planes de consulta no fueron medidos en STAGING.

## Idempotencia

- Cambios de autorizacion y configuracion avanzan revisiones monotonicamente.
- Resoluciones NO PAGAR conservan una identidad auditable por jornada.
- Ajustes anteriores poseen guardas para no repetirse al recalcular nomina.
- Recibos de mensajes aceptan una primera recepcion y duplicados seguros.
- La prueba SQL 0050 cubre contratos estructurales/idempotentes de forma portable, pero no fue ejecutada.

## Prueba SQL 0050

Archivo: `supabase/tests/0050_p0_functional_contracts.sql`.

- Creado para pgTAP.
- No depende de lectura del filesystem del servidor.
- No fue ejecutado porque Docker Desktop Linux Engine no esta disponible.
- No fue ejecutado contra STAGING.

## Riesgos y rollback

- 0050 es amplia y cruza autorizacion, terminales, asistencia, nomina y mensajes; debe revisarse como unidad con sus consumidores Edge/Web/Android.
- Backfills deben validarse con copia representativa y conteos antes/despues.
- Constraints o indices pueden fallar o bloquear si datos historicos violan contratos nuevos.
- SECURITY DEFINER/RLS mal configurados pueden denegar operaciones legitimas o ampliar alcance; requieren pruebas positivas y negativas.
- El rollback no debe improvisarse con drops en produccion. Debe basarse en respaldo, inventario de objetos, reversa ensayada en STAGING y preservacion de auditoria.
- Como 0050 no fue aplicada, el rollback actual consiste en no desplegarla hasta aprobar plan y evidencia.

## Estado explicito

0050 NO APLICADA A STAGING.

pgTAP 0050 NO EJECUTADO.

No se ejecuto `supabase db push`, despliegue Edge ni operacion contra produccion.
