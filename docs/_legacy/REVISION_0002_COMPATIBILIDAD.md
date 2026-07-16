# Revisión de compatibilidad 0001 → 0002

## Resultado

El archivo corregido es `supabase/migrations/0002_empleados_permisos_portal_FIXED.sql`. Sustituye al archivo anterior para evitar que Supabase CLI interprete dos migraciones con la misma versión `0002`. No se ejecutó SQL ni se modificó Supabase.

**Veredicto estático: compatible para ejecutarse inmediatamente después de `0001_initial_schema.sql`.** La confirmación se basa en comparación de definiciones versionadas y en protección explícita del único objeto reportado como existente en la base aplicada. Sigue siendo recomendable validar la secuencia en un Supabase local antes de producción.

## Conflicto que producía error

### `profiles_company_id_id_unique`

La versión anterior ejecutaba incondicionalmente:

```sql
alter table public.profiles
  add constraint profiles_company_id_id_unique unique (company_id, id);
```

PostgreSQL rechaza `ADD CONSTRAINT` cuando ya existe una restricción con ese nombre. La instancia Supabase ya migrada contiene `profiles_company_id_id_unique`, aunque el archivo `0001` actualmente versionado no muestra esa declaración independiente. Esta diferencia indica drift entre el historial aplicado y el archivo local.

La versión corregida consulta `pg_catalog.pg_constraint` para la relación exacta `public.profiles`. Solo crea la restricción si falta. Esto cubre ambos escenarios sin perder la unicidad requerida por la FK compuesta de `empleados(empresa_id, perfil_id)`.

No se usó `ADD CONSTRAINT IF NOT EXISTS` porque PostgreSQL 17 no ofrece esa forma para restricciones de tabla.

## Inventario comparado

| Categoría | Resultado | Acción |
|---|---|---|
| Tablas | `0002` crea únicamente `empleados`, `permisos`, `rol_permisos`, `perfil_permisos`, `perfil_sucursales` y `perfil_departamentos`; ninguna existe en `0001`. | Sin cambios. |
| Constraints | Conflicto confirmado en `profiles_company_id_id_unique`. Las restricciones de empleados y permisos son nuevas. | Creación condicional por catálogo. |
| Índices | No hay nombres repetidos ni índices equivalentes de `0001` recreados por `0002`. Los índices nuevos corresponden a tablas nuevas. | Sin cambios. |
| Triggers | `0002` no recrea triggers de `0001`; reutiliza `set_updated_at()` para tablas nuevas. | Sin cambios. |
| Funciones | `obtener_empresa_actual`, `obtener_rol_actual`, `normalizar_empleado`, `tiene_permiso`, `obtener_empleado_actual_id` y `es_empleado_actual` son nuevas. `set_updated_at()` no se redefine. | Sin cambios. |
| Políticas RLS | No existen políticas nuevas con nombres de `0001`. Cuatro políticas de `profiles` se eliminan deliberadamente y se sustituyen por políticas granulares. | `DROP POLICY IF EXISTS` para tolerar el estado aplicado sin debilitar las políticas nuevas. |
| Grants | Los grants de `0002` recaen sobre funciones/tablas nuevas. No duplican grants de `0001`. | Sin cambios. |
| Revokes | Los revokes protegen objetos nuevos. No revocan nuevamente objetos de `0001`. | Sin cambios. |
| Comentarios | Todos documentan objetos o columnas nuevas. No sustituyen comentarios de `0001`. | Sin cambios. |
| `ALTER TABLE` | El alter de `profiles` es funcionalmente necesario para la FK compuesta, pero no podía ser incondicional. Los alters de `empleados` agregan FKs nuevas. | Solo el alter de `profiles` pasó a bloque condicional. |
| RLS habilitada | `0002` habilita RLS exclusivamente en sus seis tablas nuevas. | Sin cambios. |

## Políticas reemplazadas intencionalmente

Estas operaciones no son duplicados:

- elimina `profiles_select_own_company`;
- elimina `profiles_insert_by_admin`;
- elimina `profiles_update_by_admin`;
- elimina `profiles_delete_by_admin`;
- crea `profiles_select_granular`, `profiles_insert_granular`, `profiles_update_granular` y `profiles_delete_granular`.

El reemplazo conserva aislamiento por empresa y cambia la autorización basada únicamente en rol por `usuarios.administrar`. Los `DROP POLICY` ahora llevan `IF EXISTS`; las cuatro políticas granulares continúan siendo obligatorias y se crean sin tolerancia silenciosa a duplicados.

## Reglas preservadas

- aislamiento multiempresa mediante claves compuestas;
- enlace único y opcional entre profile y empleado;
- normalización y restricciones laborales;
- PIN únicamente como hash bcrypt/Argon2;
- permisos efectivos por rol y excepciones individuales;
- alcances propio, departamento, sucursal, empresa y global;
- privilegios mínimos de `authenticated`;
- RLS en todas las tablas expuestas;
- prohibición de escritura cliente sobre salario, PIN y enlace de profile;
- reemplazo granular de las políticas heredadas de `profiles`.

## Confirmación

La revisión no encontró tablas, índices, triggers, funciones, políticas nuevas, grants, revokes o comentarios de `0002` que dupliquen objetos creados por el archivo `0001`. El único conflicto de creación encontrado/reportado quedó protegido sin eliminar funcionalidad. El archivo está preparado para la secuencia `0001_initial_schema.sql` → `0002_empleados_permisos_portal_FIXED.sql`.
