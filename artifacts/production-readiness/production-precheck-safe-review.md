# Revisión de `production-promotion-precheck-summary-safe-v2.sql`

## Causa exacta del segundo error

El segundo error `syntax error at or near "::"` en el script original viene de la fila de `empleados` dentro de `service_tables`:

`'false')::text),`

Ese patrón dejaba un cierre inconsistente del `concat(...)` y un `::text` aplicado de forma inválida.

## Por qué esta revisión no lo detectó antes

La intervención anterior corrigió parcialmente el mismo bloque y mantuvo parte de la construcción con `CONCAT/CHR`; al no rehacerse por completo, quedó una rama de sintaxis corrupta en ese tramo y el parser reportó el fallo cerca de `service_role_state`.

## Bloque reescrito

Se creó **`artifacts/production-readiness/production-promotion-precheck-summary-safe-v2.sql`** (sin sobrescribir el archivo previo) y se reescribió únicamente `service_tables` de esta forma:

```sql
service_tables(relation_name, expected_select, expected_insert, expected_update, expected_delete) as (
  values
    ('profiles', true, false, false, false),
    ('roles', true, false, false, false),
    ('empleados', true, true, true, false),
    ('perfil_sucursales', false, false, false, false),
    ('perfil_departamentos', false, false, false, false)
)
```

`service_privilege_state` ahora consume estas columnas para calcular `expected_effective_after_0035`, y `service_table_state` construye `expected_after_0035` a partir de esas columnas.

## Causa exacta del reporte residual

- `LINE 1449` (bloque original): expresión de `empleados` con cierre de argumentos/casts roto.
- `service_role_state as (...)` ya no es la causa principal; aparece visible por el efecto dominó del parser al encontrar la secuencia de CTE incompleta.

## Método de validación aplicado

1. Intento de validación con parser real local:
   - PostgreSQL `psql`: no instalado;
   - Docker/PostgreSQL local: sin acceso al socket `docker_engine`;
   - `supabase` CLI: no utilizable por bloqueo del entorno (telemetría/configuración).
2. Validación sintáctica estática reproducible ejecutada localmente sobre el archivo completo:
   - balanceo de paréntesis (saldo final `0`);
   - conteo de sentencias por `;` fuera de literales/comentarios (`1` sentencia);
   - confirmación de un `WITH` inicial y una selección final única (`from all_rows a`);
   - verificación de `check_name,status,actual_value,expected_value,severity,instruction`;
   - barrido de palabras destructivas fuera de strings/comentarios (`INSERT/UPDATE/DELETE/CREATE/ALTER/DROP/TRUNCATE/GRANT/REVOKE/CALL/DO/EXECUTE`) sin hallazgos.

## Resultado

- Se corrigió la expresión defectuosa y se evitó el patrón inválido.
- Se mantiene la intención del precheck y el conjunto de checks (incluido `FINAL_DECISION`) sin cambios funcionales.
- Archivo nuevo creado: `artifacts/production-readiness/production-promotion-precheck-summary-safe-v2.sql`.
- No se ejecutó SQL contra entorno remoto ni se tocó producción.
- El bloque `checks` no fue modificado respecto a `production-promotion-precheck-summary-safe.sql` (se conservaron índices y estructura del chequeo).
