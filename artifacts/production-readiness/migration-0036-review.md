# Revisión de migración 0036: privilegios mínimos de `service_role`

## Estado

Validada en staging. Después de dos intentos fallidos con SQLSTATE `22023`
(`ACL arrays must be one-dimensional`), la versión corregida completó
`0036_HISTORY`, `0036_POSTFLIGHT` y `0036_SMOKE` en PASS. Producción sigue
pendiente de las migraciones `0030`-`0036` y permanece **NO-GO**. Este commit
documental no ejecuta SQL, Supabase, deploy ni cambios remotos.

La 0036 local anterior no correspondía a esta remediación: mezclaba cambios de datos, roles y funciones. Se preservó fuera de la secuencia activa como `unconfirmed-0036_production_precheck_remediation.sql`; no se reutilizó como base. La única migración activa con prefijo `0036` es ahora `0036_service_role_privilege_remediation.sql`.

## Corrección de SQLSTATE 22023

La causa era fabricar un array ACL vacío como fallback. PostgreSQL representa ese literal sin la dimensionalidad exigida por `aclexplode()`. La corrección pasa `relacl`, `attacl` y `proacl` directamente; si el catálogo contiene `NULL`, `aclexplode()` produce cero filas.

Se corrigieron 37 expresiones SQL: cinco en la migración, cuatro en el postflight, quince en los cinco prechecks/diagnósticos staging con nombre 0036 y trece inspecciones residuales encontradas por la búsqueda completa del repositorio. También se actualizó la descripción documental que reproducía el patrón. Los artifacts `unconfirmed-*` permanecen archivados y no deben usarse para validar esta migración activa.

## Alcance y estado final

La migración modifica únicamente ACL de tabla y, si existen, las ACL de columna correspondientes almacenadas para `service_role` en cinco tablas:

| Tabla | Privilegios directos finales |
|---|---|
| `public.profiles` | `SELECT` |
| `public.roles` | `SELECT` |
| `public.empleados` | `SELECT`, `INSERT`, `UPDATE` |
| `public.perfil_sucursales` | ninguno |
| `public.perfil_departamentos` | ninguno |

Todos los demás privilegios de tabla, incluidos `DELETE`, `TRUNCATE`, `REFERENCES`, `TRIGGER` y `MAINTAIN` cuando existe, deben quedar en `false`.

## Implementación

1. Inicia una transacción explícita.
2. Ejecuta `REVOKE ALL PRIVILEGES` únicamente sobre las cinco tablas y únicamente desde `service_role`.
3. Concede de nuevo sólo `SELECT` en `profiles` y `roles`.
4. Concede de nuevo sólo `SELECT`, `INSERT` y `UPDATE` en `empleados`.
5. No concede nada en las tablas de alcance.
6. Valida la matriz efectiva y la ACL directa antes de confirmar la transacción.

`REVOKE ALL PRIVILEGES` es una operación de reducción y no infringe la prohibición de `GRANT ALL`. Es idempotente: repetir el archivo vuelve a retirar los permisos y reconstruye la misma lista mínima.

## Tratamiento de `MAINTAIN`

El entorno local revisado usa PostgreSQL 17; esto no se usa como suposición
sobre producción. La sentencia `REVOKE ALL PRIVILEGES` retira también
`MAINTAIN` cuando la versión conectada lo soporta, pero mantiene compatibilidad
sintáctica con versiones anteriores que no reconocen `REVOKE MAINTAIN`
explícito.

La validación añade `MAINTAIN` a la matriz sólo cuando `server_version_num >= 170000`. El postflight usa la misma condición y lo marca como no aplicable en versiones anteriores.

## Validación fail-closed

Antes de `COMMIT`, la migración exige simultáneamente:

- que el privilegio efectivo coincida con la matriz esperada;
- que la ACL almacenada directamente coincida con esa matriz;
- que ninguna ruta efectiva ni concesión directa conserve `WITH GRANT OPTION`;
- que no exista otro tipo de privilegio directo fuera de la lista permitida;
- que no quede ACL directa de columna para `service_role` y que ninguna ACL de columna alternativa amplíe la matriz efectiva;
- que las ocho RPC internas creadas por 0033 existan, sean `SECURITY DEFINER` y sigan siendo ejecutables por `service_role`;
- que el owner de `guardar_alcance_supervisor_internal(jsonb)` tenga ACL de tabla, `USAGE` de schema, bypass seguro de RLS y acceso a la secuencia identity requeridos por sus lecturas, bloqueos, inserciones y eliminaciones.

La ACL directa se inspecciona pasando `relacl`, `attacl` o `proacl` directamente a `aclexplode()`. Una ACL `NULL` produce cero filas: no se fabrica un array vacío y no se usa `acldefault()`, por lo que ownership no se clasifica como una concesión almacenada. El `REVOKE` de tabla retira los grants de columna correspondientes que puede revocar, y el guard rechaza cualquier ACL directa de columna residual. Si queda acceso excesivo por `PUBLIC`, herencia, ownership, superusuario u otra ruta, la comprobación efectiva falla y toda la transacción revierte.

## RPC y Edge Functions

0033 reemplaza el DML directo en `perfil_sucursales` y `perfil_departamentos` mediante RPC `SECURITY DEFINER`. `guardar_alcance_supervisor_internal(jsonb)` realiza `SELECT`, `INSERT` y `DELETE` sobre esas tablas con los privilegios de su owner.

La revisión estática de las Edge Functions encontró estas dependencias directas:

- `profiles`: `SELECT`;
- `roles`: `SELECT`;
- `empleados`: `SELECT`, `INSERT`, `UPDATE`;
- tablas de alcance: ninguna; se usan las RPC de 0033.

La 0036 no altera funciones, owners, `EXECUTE` ni `USAGE` del esquema. Revocar `TRIGGER` tampoco impide que se disparen triggers ya creados; sólo elimina la capacidad de crear triggers sobre esas tablas.

El postflight enumera el owner de cada una de las ocho RPC y comprueba los privilegios efectivos, `USAGE` del schema, bypass de RLS y acceso a secuencia identity requeridos por todas sus operaciones directas de tabla. Esto incluye `UPDATE` para las consultas `SELECT ... FOR UPDATE`, además de los `INSERT`, `UPDATE` y `DELETE` explícitos.

## Exclusiones verificables por revisión estática

La migración no contiene cambios de:

- datos;
- RLS o policies;
- ownership;
- memberships o herencia de roles;
- default privileges;
- ACL de `anon`, `authenticated` o `PUBLIC`;
- funciones o su `EXECUTE`;
- `USAGE` del esquema `public`.

## Riesgos residuales

- El PASS de staging no sustituye el preflight ni el postflight de producción;
  allí la matriz y los owners deben confirmarse al aplicar la secuencia pendiente.
- El fingerprint de policies sólo demuestra inmutabilidad si se captura inmediatamente antes de 0036 y se compara externamente con el resultado posterior; el postflight aislado no conoce el baseline.
- Las pruebas TypeScript no ejecutan SQL ni prueban ACL; se requiere validación SQL en staging antes de promoción.
- Una Edge Function desplegada distinta del código local podría conservar una dependencia no visible aquí.
- Si existe una concesión dependiente que impida el `REVOKE` sin `CASCADE`, la migración fallará y hará rollback. Se evita `CASCADE` deliberadamente para no ampliar el impacto.
