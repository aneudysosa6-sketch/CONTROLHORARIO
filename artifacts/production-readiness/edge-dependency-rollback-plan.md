# Rollback del pinning de dependencias Edge

Estado: procedimiento preparado, no ejecutado. Aplica primero a staging.
Producción continúa **NO-GO** y este documento no autoriza operaciones allí.
El rollback restaura individualmente las versiones Edge anteriores capturadas
como preimagen, sin volver a resolver dependencias.

## Naturaleza del cambio

Este paquete no cambia base de datos, datos, RLS, policies, grants, secrets ni
contratos HTTP. El cambio remoto futuro se limita al bundle de seis Edge
Functions. Cada deploy es independiente y no existe una transacción distribuida
entre funciones.

Los aliases de tipo añadidos a `user-provisioning` y `employee-management` se
eliminan al compilar y no alteran JavaScript emitido. El riesgo real está en el
método de resolución/bundling de la dependencia.

## Preimagen obligatoria

Antes del primer deploy de staging guardar:

- project-ref aprobado y timestamp UTC;
- `supabase functions list` con versiones anteriores;
- fuente descargada de cada una de las seis funciones;
- hashes SHA-256 de `index.ts`, `deno.json` y locks disponibles;
- valor booleano anterior de `verify_jwt` por función;
- smokes y logs de la versión anterior;
- commit/hash exacto del candidato nuevo.

No guardar tokens, JWT, claves, passwords ni valores de secrets.

Una descarga de la versión anterior no es una copia bit a bit del bundle: las
fuentes antiguas usaban `@2` y podrían resolver otro patch al redeployar. No se
debe presentar esa descarga como rollback reproducible.

## Criterios de detención

Detener inmediatamente la secuencia y no desplegar la función siguiente si:

- Docker deja de estar disponible o el CLI usa bundling API;
- aparece un error de npm, integridad, lock, ESZip o arranque del worker;
- cambia un código HTTP o contrato esperado;
- `verify_jwt` cambia;
- falla login, provisioning, employee-management o aislamiento multiempresa;
- aparecen 4xx/5xx inesperados;
- no puede identificarse qué funciones ya cambiaron de versión.

Registrar las funciones ya desplegadas; no asumir que el lote completo cambió.

## Primera respuesta

1. Suspender el resto de deploys.
2. Mantener la base de datos y secrets sin cambios.
3. Capturar versión, logs, requestId y `DENO_DEPLOYMENT_ID`.
4. Clasificar el fallo como resolución, bundle, arranque, contrato o flujo.
5. Si la función arranca, preferir corrección hacia adelante sobre un
   redeploy flotante.

## Compensación preferida

### Fallo de bundling o lock antes de publicar

No hay cambio remoto: corregir el paquete local, repetir `deno check --frozen`
y reabrir la revisión. No ejecutar ningún rollback remoto.

### Fallo del transporte npm con el mismo SDK

Preparar en una rama/worktree de incidente una compensación que conserve
exactamente `2.110.2` pero restaure el transporte anterior de esa función, por
ejemplo `https://esm.sh/@supabase/supabase-js@2.110.2`, con lock exacto generado
y validado. No restaurar `@2`, `latest` ni rangos. Revisar y probar esa
compensación antes de desplegarla solo a staging.

### Regresión funcional

Los handlers no cambiaron funcionalmente por este paquete. Si aparece una
regresión, primero demostrar si proviene del bundle nuevo o de drift de staging.
Si es necesario restaurar fuente anterior:

1. partir de la preimagen descargada y su hash;
2. sustituir cualquier dependencia flotante de la preimagen por la versión
   exacta previamente comprobada;
3. generar/validar su lock;
4. ejecutar type-check y smoke local;
5. desplegar únicamente la función afectada con project-ref explícito,
   `--no-verify-jwt` y `--use-docker`;
6. repetir smoke y logs.

No existe un comando CLI documentado que restaure automáticamente un ESZip
anterior. La edición Dashboard tampoco ofrece versionado/rollback. Por ello el
GO depende de una preimagen revisada y una compensación ensayada, no de suponer
que la plataforma puede volver atrás con un clic.

## Orden de compensación

Compensar en orden inverso al deploy y solo las funciones que realmente hayan
cambiado:

1. `user-provisioning`;
2. `employee-management`;
3. `employee-upsert`;
4. `employee-sync`;
5. `device-enrollment`;
6. `attendance-sync`.

Después de cada función, ejecutar su smoke antes de continuar. Un fallo aislado
no autoriza redeploy masivo.

## Comando de redeploy compensatorio

Solo después de preparar una preimagen exacta en `$RollbackRoot`:

```powershell
if ([string]::IsNullOrWhiteSpace($StagingProjectRef)) {
  throw 'Falta project-ref explícito de staging'
}
if ($StagingProjectRef -eq $env:CONTROLHORARIO_PROD_PROJECT_REF) {
  throw 'Target de producción rechazado'
}
docker info | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Docker requerido para consumir el lock'
}

supabase functions deploy <FUNCTION_NAME> `
  --workdir $RollbackRoot `
  --project-ref $StagingProjectRef `
  --no-verify-jwt `
  --use-docker
```

Reemplazar `<FUNCTION_NAME>` por una sola función aprobada. No ejecutar el
comando sin haber comprobado que `$RollbackRoot` contiene `deno.json` y
`deno.lock` exactos para ella.

## Objetos que no deben tocarse

- migraciones o historial de migraciones;
- tablas, perfiles, empleados, alcances o auditorías;
- identidades Auth;
- grants, RLS o policies;
- secrets;
- entradas `verify_jwt`;
- funciones que aún conservan su versión anterior;
- datos sintéticos hasta cerrar la investigación, salvo su limpieza funcional
  planificada.

## Cierre

El rollback queda completo únicamente cuando:

- cada función afectada tiene versión remota identificada;
- smokes, auth e aislamiento vuelven a PASS;
- logs no contienen errores de resolución/arranque;
- los datos sintéticos se limpiaron por los flujos aprobados;
- se documentó la causa y se decidió si mantener `2.110.2` mediante npm o
  transporte HTTPS exacto.
