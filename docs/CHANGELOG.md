# CHANGELOG

Este archivo registra hitos arquitectonicos y funcionales. No reemplaza el
historial Git ni enumera cada correccion menor.

## 2026-08-02 - Dependencias reproducibles de Edge Functions

### Corregido

- Las seis Edge Functions dejaron de resolver `@supabase/supabase-js@2`.
- Todas usan el alias por funcion fijado en `2.110.2`.
- Cada funcion conserva un `deno.lock` v5 con transitivos e integridades.
- Se eliminaron los imports remotos directos de `user-provisioning` y
  `employee-upsert`.

### Agregado

- Control `test:edge-dependencies` contra imports flotantes o directos.
- Type-check congelado por funcion como preflight de deploy.
- Planes de prueba y rollback exclusivos para staging.

### Validado

- `deno cache --frozen` y `deno check --frozen`: seis funciones en PASS.
- Build Web, pruebas de supervisor/empleado y guard de dependencias: PASS.
- Staging: `0036_HISTORY`, `0036_POSTFLIGHT` y `0036_SMOKE` en PASS; esto no
  acredita un redeploy de las Edge Functions con el pin nuevo.
- Produccion: migraciones `0030`-`0036` y Edge Functions fijadas pendientes;
  el estado sigue **NO-GO**.
- Durante esta validacion no se ejecuto deploy, SQL, `db push` ni push;
  produccion no se toco.

## 2026-07-27 - Identidad visual Control Horario

### Agregado

- Marca vectorial rostro-reloj.
- Logo horizontal y variante monocromatica Web.
- Favicon oficial.
- Launcher adaptativo y redondo Android.
- Capa monocromatica para iconos tematicos.
- Splash nativo Android.

### Actualizado

- Encabezados administrativos y del portal.
- Login y bootstrap Web.
- Login Android.
- Metadatos del documento Web.

### Sin cambios

- Autenticacion.
- Navegacion.
- Permisos.
- Supabase.

## 2026-07-27 - Documentacion oficial consolidada

### Agregado

- Punto de entrada unico `00_LEER_PRIMERO.md`.
- Estado real de Android, Web, Supabase, Edge Functions y N8N.
- Arquitectura, fuentes de verdad y limites.
- Constitucion y decisiones de arquitectura.
- Guias de desarrollo, UI/UX, despliegue y plataforma.
- Roadmap priorizado.

### Retirado

- Documentos top-level obsoletos.
- Auditorias paralelas.
- Carpeta `_legacy`.
- Referencias documentales contradictorias.

### Validado

- El cambio se limita a `docs`.
- No se modifico codigo de Android, Web, Supabase, Edge Functions ni N8N.

## 2026-07-27 - Compatibilidad Android de rol empleado

### Corregido

- Android reconoce `EMPLEADO`, `EMPLEADOS`, `EMPLOYEE` y `EMPLOYEES`.
- Todos resuelven a Dashboard Empleado.
- Se agregaron pruebas de aliases.

### Validado

- `:app:testDebugUnitTest`: exitoso.
- `:app:assembleDebug`: exitoso.
- `:app:lintDebug`: exitoso.

## Migracion 0030 - Canonicalizacion de empleado

Estado: local, pendiente de remoto al 2026-07-27.

### Agregado

- Normalizacion central de `empleado`, `empleados`, `employee` y `employees`
  hacia `EMPLEADO`.
- Conservacion de `role_code_original`.

### Pendiente

- `supabase db push --linked`.
- Prueba remota de `obtener_mi_autorizacion()`.

## Migracion 0029 - Autenticacion y autorizacion unificadas

### Agregado

- Contrato `obtener_mi_autorizacion()`.
- Rol original y canonico.
- Permisos efectivos.
- Sucursales/departamentos.
- Limpieza de autorizacion al cambiar rol.
- Unificacion de bootstrap de sesion.

### Corregido

- Uso de `departments.is_active` en lugar de una columna textual inexistente.

## Migracion 0028 - Supervisor

### Agregado

- Normalizacion de aliases de supervisor.
- Alcance por asignaciones.
- Mensajes funcionales para falta de departamentos/permisos.

## Migracion 0027 - Candidatos de acceso

### Corregido

- El listado de empleados disponibles para acceso solo considera empleados
  activos.
- La correccion se aplico en una migracion nueva, sin reescribir `0022`.

## Migraciones 0024 a 0026 - Ciclo de vida del empleado

### Agregado

- Codigo de empleado de seis digitos.
- Registro y auditoria de codigo.
- Retiro de autenticacion por PIN.
- Terminacion y reactivacion.
- Auditoria de ciclo de vida.

## Migraciones 0022 y 0023 - Accesos y rostro

### Agregado

- Funciones internas de gestion de accesos.
- Auditoria de provision.
- Tombstone de perfiles.
- Primer enrolamiento facial.
- Auditoria facial.

## Migraciones 0019 a 0021 - Nomina y kiosco

### Agregado

- Total de dashboard de nomina.
- Piso de neto y metadatos de descuento.
- Resolucion de conflicto remoto.
- Configuracion facial de kiosco.

## Migraciones 0014 a 0018 - Operacion Android

### Agregado

- Sucursales y alcance relacionado.
- Prueba biometrica para jornada.
- Ganancias/correcciones.
- Proteccion de roles.
- Idempotencia de carga.
- Embedding facial.

## Hitos de plataforma

### Android

- Compose y navegacion por rol.
- Room hasta version 39.
- Outbox y WorkManager.
- Device Owner/kiosco.
- Firma ECDSA.
- FaceNet/ML Kit.
- SDK 2Connect.

### Web

- React/Vite/TypeScript.
- AuthProvider con Supabase.
- Guards por permisos.
- Resolver por rol canonico.
- Modulos de empleados, accesos, jornadas, nomina, prestamos y reportes.
- UI responsive OSINET.

### Supabase

- RLS multiempresa.
- RPC funcionales.
- Auditorias por dominio.
- Seis Edge Functions.

### N8N

- Adaptador Web no bloqueante.
- Eventos tipados.
- Integracion todavia parcial.
