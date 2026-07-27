# DESPLIEGUE

## 1. Principio

Un archivo local modificado no equivale a un despliegue. Cada capa tiene su
propio artefacto, entorno, validacion y evidencia.

Nunca ejecutar un comando remoto sin confirmar:

- proyecto;
- cuenta;
- branch/revision;
- entorno;
- cambios pendientes;
- plan de recuperacion.

## 2. Orden recomendado

Cuando un cambio afecta varias capas:

1. Migracion compatible.
2. RPC/RLS.
3. Edge Function.
4. Web/Android consumidor compatible.
5. Activacion funcional.
6. Monitoreo.

Preferir compatibilidad hacia atras:

- servidor acepta cliente anterior;
- cliente nuevo tolera servidor anterior durante una ventana controlada;
- retirar compatibilidad despues de confirmar adopcion.

## 3. Entornos

El repositorio contiene configuracion local y un proyecto Supabase vinculado.
La auditoria no confirma una separacion completa de desarrollo, staging y
produccion.

Antes de desplegar se debe documentar:

| Dato | Ejemplo de valor, no secreto |
|---|---|
| Entorno | desarrollo/staging/produccion |
| Proyecto Supabase | project ref confirmado |
| Proyecto Vercel | nombre/ID confirmado |
| Version Android | versionName/versionCode |
| Revision | commit o artefacto |
| Operador | responsable |
| Fecha | ISO-8601 |

## 4. Android

### Debug

```powershell
.\gradlew.bat :app:testDebugUnitTest
.\gradlew.bat :app:assembleDebug
.\gradlew.bat :app:lintDebug
```

Artefacto habitual:

```text
app/build/outputs/apk/debug/app-debug.apk
```

### Release

Antes:

- definir versionCode/versionName;
- configurar firma fuera del repositorio;
- confirmar min/target SDK;
- confirmar URL y anon key del entorno;
- revisar shrink/ProGuard si se habilita;
- probar SDK 2Connect;
- probar modelo TFLite incluido;
- confirmar Device Owner/kiosco.

La auditoria no confirmo una canalizacion release firmada. No se debe distribuir
un APK debug como release oficial.

### Pruebas de dispositivo

- login/restauracion;
- cambio de rol;
- modo avion;
- reinicio;
- jornada pendiente;
- conflicto;
- camara;
- FaceNet;
- lector USB;
- boot receiver;
- lock task;
- revocacion del dispositivo.

## 5. Web

### Build

```powershell
cd web
pnpm install
pnpm run build
```

Artefacto:

```text
web/dist/
```

### Variables

- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_ANON_KEY`
- `VITE_N8N_BASE_URL`, solo si la integracion esta autorizada;
- timeout/reintentos N8N cuando esten definidos.

No colocar secretos en variables `VITE_*`.

### Vercel

El repositorio contiene `web/vercel.json` con rewrite de SPA.

Checklist:

1. Confirmar proyecto Vercel real.
2. Confirmar root directory `web`.
3. Confirmar comando de build.
4. Confirmar output `dist`.
5. Confirmar variables por entorno.
6. Construir local.
7. Desplegar revision exacta.
8. Probar `/login`.
9. Probar refresh en `/dashboard`.
10. Probar `/accesos` y `/jornadas`.
11. Probar rol canonico y permisos.
12. Revisar consola/red sin secretos.

Esta auditoria no ejecuto un deploy Vercel.

## 6. Supabase migrations

### Preflight

```powershell
supabase migration list --linked
```

Confirmar:

- proyecto correcto;
- migraciones locales;
- historial remoto;
- SQL sin referencias a columnas inexistentes;
- impacto en funciones/RLS;
- compatibilidad de clientes.

### Push

```powershell
supabase db push --linked
```

### Postflight

```powershell
supabase migration list --linked
```

Ademas:

- probar RPC cambiado;
- probar RLS;
- revisar logs;
- confirmar auditoria;
- registrar resultado.

Pendiente actual:

- aplicar `0030_fix_employee_role_canonicalization.sql`.

## 7. Edge Functions

### Lista

```powershell
supabase functions list
```

### Deploy

```powershell
supabase functions deploy <function-name>
```

No desplegar todas por costumbre. Desplegar solo las modificadas y sus
dependencias confirmadas.

Checklist:

- modelo JWT/dispositivo;
- secretos;
- CORS;
- schema de entrada;
- permisos;
- tenant;
- idempotencia;
- errores;
- logs;
- version remota nueva;
- caso feliz y denegado.

## 8. N8N

No existe despliegue versionado en este repositorio.

Un despliegue N8N debe registrar:

- instancia;
- workflow ID/version;
- endpoint;
- autenticacion;
- credenciales;
- canales;
- prueba;
- rollback/desactivacion;
- propietario.

No configurar un secreto de webhook en Web.

## 9. Orden especifico para `0030`

1. Confirmar proyecto Supabase vinculado.
2. Revisar que remoto termine en `0029`.
3. Ejecutar `supabase db push --linked`.
4. Confirmar `0030` en remoto.
5. Probar un usuario con `role_code_original = empleados`.
6. Confirmar `role_code_canonical = EMPLEADO`.
7. Reabrir Android con sesion persistente.
8. Confirmar Dashboard Empleado.
9. Refrescar Web.
10. Confirmar Portal Empleado.
11. Revisar logs sin tokens.

## 10. Recuperacion

### Base de datos

- crear migracion compensatoria;
- no editar historia;
- conservar compatibilidad;
- restaurar backup solo con procedimiento aprobado.

### Edge Function

- desplegar version conocida compatible;
- revisar contrato SQL;
- revocar credenciales si hubo exposicion.

### Web

- volver a una version Vercel conocida;
- mantener base de datos compatible;
- confirmar variables.

### Android

- publicar version correctiva;
- no asumir actualizacion inmediata de todos los dispositivos;
- mantener servidor compatible durante adopcion.

## 11. Evidencia de despliegue

Cada entrega debe responder:

- que artefacto;
- que entorno;
- que comando;
- resultado;
- version;
- prueba posterior;
- deuda pendiente.

No usar:

- `deberia estar desplegado`;
- `parece aplicado`;
- `seguramente funciona`.

## 12. Estado al corte

| Capa | Estado |
|---|---|
| Android debug | Build/test/lint correctos el 2026-07-27 |
| Android release | No verificado |
| Web local | No reconstruido en esta auditoria documental |
| Vercel | Configuracion en repo; despliegue no verificado |
| Supabase DB | `0001`-`0029` remoto; `0030` pendiente |
| Edge Functions | Seis activas, versiones registradas en `10_SUPABASE.md` |
| N8N | Despliegue no demostrado |
