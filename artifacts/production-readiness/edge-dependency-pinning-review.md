# Revisión del pinning de dependencias Edge

Estado: paquete local y staging validados. Las seis Edge Functions fijan
`@supabase/supabase-js` en `2.110.2`; `test:edge-dependencies` y el build local
quedaron en PASS.

En staging se redeployó `user-provisioning` v10: `bootstrap-status` respondió
POST 200 y el login ADMIN quedó en PASS. Los logs temporales de cabeceras,
entorno, body, payload y response fueron eliminados; se conservaron únicamente
errores operativos saneados con `requestId`. Producción continúa **NO-GO** y no
fue consultada ni modificada durante esta revisión.

## Resultado

Todas las Edge Functions usan ahora el alias:

```ts
import { createClient } from "@supabase/supabase-js";
```

Cada función mantiene su propio `deno.json`, con la misma resolución exacta:

```json
{
  "imports": {
    "@supabase/supabase-js": "npm:@supabase/supabase-js@2.110.2"
  }
}
```

Se eligió configuración por función, no `supabase/functions/deno.json` global.
Es el patrón que ya usaba el proyecto y el recomendado por Supabase para que el
deploy aísle la configuración de cada función. La configuración global se
considera válida para desarrollo local, pero no es la opción recomendada para
deployment.

## Cómo se determinó `2.110.2`

No se eligió la versión más reciente. `2.110.2` es la única versión exacta
materializada por la evidencia local del entorno validado:

- `attendance-sync/deno.lock` redirigía el import `esm.sh` flotante `@2` a
  `@2.110.2` y conservaba su hash.
- `employee-sync/deno.lock` resolvía `npm:@supabase/supabase-js@2` a
  `2.110.2`, con integridades del paquete y transitivos.
- La caché Deno local conserva el redirect `@2 -> @2.110.2` y el paquete npm
  `@supabase/supabase-js/2.110.2`.
- `web/pnpm-lock.yaml` también resuelve `@supabase/supabase-js` a `2.110.2`;
  se usa solo como corroboración, no como autoridad para Edge.
- Las trazas locales registran deploys satisfactorios de staging con Supabase
  CLI `2.109.1`, pero no conservan el grafo ESZip. Por tanto no demuestran qué
  patch exacto quedó dentro de los bundles remotos ya desplegados.

Conclusión precisa: `2.110.2` es el pin conservador respaldado por locks y
caché local. El redeploy exclusivo a staging y sus smokes son necesarios para
convertirlo en evidencia del bundle remoto.

## Inventario previo de dependencias flotantes

| Función | Referencia flotante previa |
|---|---|
| `attendance-sync` | `deno.json`: `https://esm.sh/@supabase/supabase-js@2` |
| `device-enrollment` | `deno.json`: `https://esm.sh/@supabase/supabase-js@2` |
| `employee-management` | `deno.json`: `https://esm.sh/@supabase/supabase-js@2` |
| `employee-sync` | `deno.json`: `npm:@supabase/supabase-js@2` |
| `employee-upsert` | import directo `npm:@supabase/supabase-js@2` y sin `deno.json` |
| `user-provisioning` | import directo y `deno.json` con `https://esm.sh/@supabase/supabase-js@2`; el import directo evitaba el alias |

Eran siete referencias flotantes en seis funciones. No se encontraron imports
`jsr:`, otras dependencias remotas Edge ni `latest` adicionales dentro de
`supabase/functions`.

El manifiesto Web, fuera del alcance Edge, conserva deuda separada:

- `latest`: `@supabase/supabase-js`, `@vitejs/plugin-react`, `lucide-react`,
  `react`, `react-dom`, `react-router-dom`, `typescript`, `vite`,
  `@types/react` y `@types/react-dom`;
- rangos `^`: `jspdf`, `jspdf-autotable` y `xlsx`.

No se cambiaron esas versiones porque el objetivo es exclusivamente el bundle
de Edge Functions y Web ya posee `pnpm-lock.yaml`.

## Lock y método de resolución

Cada una de las seis funciones tiene ahora un `deno.lock` v5 propio. Los locks
contienen el mismo grafo ya comprobado en `employee-sync`:

- `@supabase/supabase-js@2.110.2`;
- `auth-js`, `functions-js`, `postgrest-js`, `realtime-js` y `storage-js`
  `2.110.2`;
- `@supabase/phoenix@0.4.4`;
- `iceberg-js@0.8.1`;
- `tslib@2.8.1`;
- integridades SRI para cada paquete.

No se hizo una actualización contra el registro. Se reutilizó el grafo exacto
ya generado y validado localmente; después se comprobó en las seis funciones
con Deno `2.5.5`, `deno cache --frozen` y `deno check --frozen`.

La investigación del CLI local determinó que Supabase CLI `2.109.1` usa Edge
Runtime `v1.74.2` para bundling Docker y que ese camino descubre los
`deno.json`/`deno.lock` por función. El bundling server-side con `--use-api`, o
el fallback cuando Docker no está disponible, no transmite el lock como input
del bundle. Por eso el despliegue reproducible de staging debe:

1. confirmar Docker operativo;
2. usar CLI `2.109.1`;
3. usar `--use-docker` y nunca `--use-api`;
4. ejecutar antes `deno check --frozen`.

El specifier npm exacto sigue evitando que cambie `supabase-js` aunque el lock
no fuese consumido; el lock añade la comprobación de transitivos e integridad.

## Archivos de implementación

- `supabase/functions/*/deno.json`: seis aliases exactos; se creó el de
  `employee-upsert`.
- `supabase/functions/*/deno.lock`: seis locks v5 exactos.
- `supabase/functions/user-provisioning/index.ts`: import por alias y alias de
  tipo explícito para el cliente sin esquema generado.
- `supabase/functions/employee-upsert/index.ts`: import por alias.
- `supabase/functions/employee-management/index.ts`: alias de tipo explícito
  para evitar inferencia `never`; no cambia código emitido.
- `web/scripts/test-edge-dependency-pinning.mjs`: guard automatizado.
- `web/package.json`: comando `test:edge-dependencies`.
- Los tres documentos `edge-dependency-*` de este paquete.

No se modificaron `supabase/config.toml`, secrets, `verify_jwt`, lógica de
autenticación, contratos HTTP, migraciones ni base de datos.

## Control automatizado

`pnpm.cmd run test:edge-dependencies` falla si:

- una función con `index.ts` carece de `deno.json` o `deno.lock` propio;
- el alias no apunta exactamente a `npm:@supabase/supabase-js@2.110.2`;
- reaparece un import directo `npm:`, `jsr:` o HTTP;
- aparece `@2`, `latest`, un rango o una versión distinta;
- el lock no contiene el specifier, versión e integridad esperados;
- cualquiera de los seis `index.ts` deja de ser sintácticamente válido.

## Validación local realizada

| Validación | Resultado |
|---|---|
| SHA-256 del binario temporal oficial Deno `2.5.5` | PASS |
| `deno cache --frozen` para las seis funciones | PASS |
| `deno check --frozen` para las seis funciones | PASS |
| `pnpm.cmd run test:edge-dependencies` | PASS, 6 funciones |
| `pnpm.cmd run test:supervisor-scope` | PASS |
| `pnpm.cmd run test:employee-code` | PASS |
| `pnpm.cmd run build` | PASS |

El build conserva avisos ya existentes sobre imports dinámicos inefectivos de
`jspdf`/`jspdf-autotable` y chunks mayores de 500 kB; no produjo errores.

Como diagnóstico adicional, `deno check --all` expuso declaraciones upstream
de `supabase-js` que esperan ambientes Node/WebAuthn. El gate usado es el
`deno check` estándar recomendado para el entrypoint; este sí pasa y valida el
código local, la resolución exacta y el lock congelado.

## Referencias técnicas

- Supabase, gestión de dependencias:
  https://supabase.com/docs/guides/functions/dependencies
- Supabase, seguridad de instalaciones npm:
  https://supabase.com/docs/guides/security/npm-security
- Deno, configuración y lockfile:
  https://docs.deno.com/runtime/reference/deno_json/
- Supabase CLI:
  https://github.com/supabase/cli
- Supabase Edge Runtime:
  https://github.com/supabase/edge-runtime
