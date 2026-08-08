# Plan de pruebas de migración 0036

## Objetivo

Demostrar que 0036 deja la matriz mínima de `service_role`, conserva el contrato `SECURITY DEFINER` de 0033 y no cambia datos, RLS, policies, owners, memberships, default privileges, `EXECUTE` ni `USAGE` del esquema.

## Límites de esta tarea

La revisión original realizó pruebas estáticas y locales. Posteriormente,
staging completó `0036_HISTORY`, `0036_POSTFLIGHT` y `0036_SMOKE` en PASS.
Los pasos siguientes se conservan como gate reproducible antes de cualquier
promoción. Este commit documental no ejecuta SQL, Supabase remoto ni deploy.

## Revisión estática

- [x] Sólo existe una migración activa con prefijo `0036`.
- [x] La migración está envuelta en `BEGIN`/`COMMIT`.
- [x] No contiene `GRANT ALL`.
- [x] No contiene DML de datos.
- [x] No contiene cambios de RLS, policies, ownership, memberships o default privileges.
- [x] No cambia `anon`, `authenticated` ni `PUBLIC`.
- [x] No cambia ACL de funciones ni `USAGE` de `public`.
- [x] Valida privilegio efectivo y ACL directa sin usar `acldefault()` ni arrays ACL vacíos artificiales.
- [x] Pasa `relacl`, `attacl` y `proacl` directamente a `aclexplode()`; una ACL `NULL` produce cero filas.
- [x] Valida grants efectivos, grant options y ACL directas a nivel de tabla y columna.
- [x] Valida `MAINTAIN` sólo cuando PostgreSQL lo soporta.
- [x] Falla antes de confirmar si la matriz o el contrato RPC no coincide.

## Regresión SQLSTATE 22023

- [x] Los cuatro patrones ACL prohibidos indicados para esta corrección tienen cero apariciones en el conjunto activo 0036.
- [x] Las 37 expresiones SQL corregidas usan directamente la ACL almacenada en el catálogo.
- [ ] Prueba PostgreSQL local de `aclexplode(NULL::aclitem[])` y ACL real: no disponible porque Docker Engine no está activo y no hay `psql` local.

## Pruebas locales solicitadas

Ejecutar desde `web/`:

```powershell
pnpm.cmd run build
pnpm.cmd run test:supervisor-scope
pnpm.cmd run test:employee-code
pnpm.cmd run test:edge-dependencies
```

Ejecutar desde la raíz del repositorio:

```powershell
git diff --check
```

Resultados de esta ejecución local:

| Comando | Resultado |
|---|---|
| `pnpm.cmd run build` | PASS; sólo advertencias no bloqueantes de chunks/imports dinámicos |
| `pnpm.cmd run test:supervisor-scope` | PASS |
| `pnpm.cmd run test:employee-code` | PASS |
| `pnpm.cmd run test:edge-dependencies` | PASS; 6 funciones, `supabase-js 2.110.2` |
| `git diff --check` | PASS; sólo avisos de conversión LF/CRLF en archivos preexistentes |

Como los dieciséis archivos modificados para esta corrección todavía están sin seguimiento, `git diff --check` no los incluye. Se ejecutó además una lectura línea por línea de esos dieciséis archivos para detectar espacios o tabuladores finales y marcadores de conflicto; PASS, sin hallazgos.

Estas pruebas no ejecutan la migración ni demuestran el estado de ACL; sólo cubren compilación y contratos estáticos de aplicación.

## Gate reproducible en staging

1. Confirmar el baseline real de staging. Si ya contiene 0035, aplicar sólo 0036; si parte de 0029, aplicar 0030–0036 en orden y sin saltos.
2. Inmediatamente antes de 0036, ejecutar en modo SELECT-only las consultas 4, 5 y 6 de `migration-0036-postflight.sql` y conservar la salida como snapshot de RLS/policies.
3. Aplicar únicamente las migraciones pendientes hasta 0036, sólo en staging.
4. Confirmar que 0036 termina con `COMMIT`; cualquier excepción debe revertir todos sus cambios.
5. Ejecutar completo `migration-0036-postflight.sql`.
6. Exigir `all_privileges_match = true` en las 40 filas de salida, incluidos los campos de grant option y columna: las 40 son aplicables en PostgreSQL 17+; las cinco filas `MAINTAIN` son N/A y pasan por compatibilidad en versiones anteriores.
7. Exigir `all_rpc_checks_match = true` para las ocho RPC.
8. Exigir `all_rpc_owner_privileges_match = true` para todas las operaciones directas de tabla declaradas por las ocho RPC.
9. Exigir `all_rls_flags_match = true` y `all_policy_names_match = true`.
10. Comparar exactamente los fingerprints y definiciones de policies antes/después.
11. Repetir la lógica de 0036 en el entorno aislado y confirmar el mismo resultado para demostrar idempotencia.

## Pruebas funcionales reproducibles en staging

- Invocar las rutas Edge de listado, creación, actualización, cambio de estado y reintentos idempotentes de acceso.
- Crear o actualizar un supervisor con sucursal y departamentos mediante las RPC de 0033.
- Confirmar que `guardar_alcance_supervisor_internal(jsonb)` puede sustituir el alcance dentro de una transacción.
- Confirmar que `service_role` no puede hacer `SELECT`, `INSERT`, `UPDATE` ni `DELETE` directo en las dos tablas de alcance.
- Confirmar que `service_role` puede leer `profiles` y `roles`.
- Confirmar que `service_role` puede leer, insertar y actualizar `empleados`, pero no eliminarlo ni truncarlo.
- Ejecutar smoke tests de `user-provisioning`, `employee-management`, `device-enrollment`, `employee-sync`, `employee-upsert` y `attendance-sync` con las versiones realmente desplegadas.

## Criterio de promoción

No promover mientras algún booleano global del postflight sea `false`, falte una RPC, cambie un fingerprint de policy o falle un smoke test. No corregir el fallo concediendo permisos directos en las tablas de alcance.
