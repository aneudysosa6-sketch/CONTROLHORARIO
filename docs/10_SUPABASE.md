# SUPABASE

## 1. Rol en el sistema

Supabase proporciona:

- Auth;
- PostgreSQL;
- PostgREST;
- RPC;
- RLS;
- Edge Functions;
- secretos de runtime;
- metadatos de despliegue.

Es la frontera remota de identidad, datos oficiales, autorizacion y auditoria.

## 2. Estructura del repositorio

```text
supabase/
|-- config.toml
|-- migrations/
|   |-- 0001_...
|   |-- ...
|   `-- 0030_fix_employee_role_canonicalization.sql
`-- functions/
    |-- user-provisioning/
    |-- employee-management/
    |-- device-enrollment/
    |-- employee-sync/
    |-- attendance-sync/
    `-- employee-upsert/
```

## 3. Estado de migraciones

Consulta realizada el 2026-07-27:

| Rango | Local | Remoto |
|---|---|---|
| `0001` a `0029` | Presente | Presente |
| `0030` | Presente | Pendiente |

La migracion pendiente:

- conserva `role_code_original`;
- normaliza aliases de empleado;
- devuelve exactamente `EMPLEADO`;
- actualiza el contrato usado por `obtener_mi_autorizacion()`.

Comando pendiente:

```powershell
supabase db push --linked
```

No se debe reportar como aplicado hasta consultar de nuevo la lista remota y
probar el RPC.

## 4. Autenticacion

Supabase Auth administra:

- usuarios;
- contrasenas cifradas por el servicio;
- access token;
- refresh token;
- expiracion;
- recuperacion de contrasena;
- invalidacion de sesion.

La tabla de perfil no reemplaza `auth.users`, y `auth.users` no contiene por si
sola el contrato de permisos de la aplicacion.

## 5. RPC de autorizacion

`public.obtener_mi_autorizacion()` es el contrato central.

Responsabilidades:

1. Obtener `auth.uid()`.
2. Encontrar perfil vigente.
3. Validar empresa y estado.
4. Resolver rol original.
5. Resolver rol canonico.
6. Calcular permisos efectivos.
7. Calcular sucursales/departamentos.
8. Retornar un JSON estable.

No debe:

- aceptar el rol efectivo desde el cliente;
- confiar en empresa enviada;
- conceder acceso global por alias;
- devolver autorizacion de una sesion anterior.

## 6. Roles

Canonicos:

- `ADMIN`
- `SUPERVISOR`
- `EMPLEADO`
- `RRHH`
- `NOMINA`
- `AUDITOR`

`0028` reforzo normalizacion y alcance de supervisor.  
`0029` unifico autorizacion.  
`0030` corrige aliases de empleado.

La normalizacion debe vivir en una funcion central. No se agregan expresiones
`CASE` distintas en cada RPC.

## 7. Permisos

Tablas:

- `permisos`;
- `rol_permisos`;
- `perfil_permisos`.

Reglas:

- el rol aporta permisos asignados;
- una excepcion de perfil se expresa explicitamente;
- el cliente recibe codigos efectivos;
- admin necesita asignaciones reales;
- el permiso no sustituye alcance;
- el alcance no sustituye permiso.

## 8. Alcance

Tablas:

- `perfil_sucursales`;
- `perfil_departamentos`.

Un RPC de supervisor debe validar:

- usuario autenticado;
- perfil activo;
- empresa;
- permiso;
- asignacion activa;
- departamento activo;
- pertenencia de cada registro.

Si no hay departamentos, debe devolver una causa funcional distinguible. No
debe ampliar a toda la empresa.

## 9. RLS

Principios:

- habilitada en tablas expuestas;
- `auth.uid()` como raiz de identidad;
- `company_id` obligatorio;
- alcance por asignacion;
- autoservicio por empleado vinculado;
- politicas separadas cuando las operaciones difieren;
- denegacion por defecto.

Una funcion `SECURITY DEFINER` no es un bypass automatico. Debe:

- fijar `search_path`;
- validar actor;
- validar tenant;
- validar permiso;
- limitar resultado;
- registrar auditoria cuando corresponda.

## 10. Edge Functions

Estado remoto observado:

| Funcion | Version remota | Uso |
|---|---:|---|
| `user-provisioning` | 11 | Crear/gestionar usuarios y accesos |
| `employee-management` | 4 | Gestion privilegiada de empleados |
| `device-enrollment` | 3 | Enrolar dispositivo Android |
| `employee-sync` | 12 | Descargar datos operativos |
| `attendance-sync` | 4 | Sincronizar eventos de jornada |
| `employee-upsert` | 6 | Subir altas/cambios offline |

Todas aparecian activas el 2026-07-27.

## 11. Modelos de autenticacion de Edge

### Usuario

`user-provisioning` y `employee-management` reciben bearer token y validan:

- usuario;
- perfil;
- empresa;
- permiso;
- payload.

### Dispositivo

Las funciones de dispositivo validan una combinacion segun el endpoint:

- ID de dispositivo;
- credencial;
- estado del enrolamiento;
- firma ECDSA;
- idempotency key;
- empresa vinculada.

No mezclar el modelo de usuario con el de dispositivo.

## 12. `verify_jwt=false`

La lista remota reporto `verify_jwt=false` en las seis funciones. Esto desplaza
la responsabilidad al handler.

Checklist obligatorio:

1. Rechazar cabecera ausente.
2. Validar token/credencial con fuente oficial.
3. Rechazar actor inactivo.
4. Confirmar empresa.
5. Confirmar permiso o capacidad del dispositivo.
6. Validar metodo HTTP.
7. Validar body.
8. Aplicar limites/idempotencia.
9. No retornar secreto.
10. Auditar resultado.

`config.toml` local declara explicitamente `verify_jwt=false` para funciones de
dispositivo. La paridad de configuracion local/remota de las funciones de
usuario debe revisarse antes del siguiente deploy.

## 13. Secretos

Permitidos en entorno de Edge:

- URL del proyecto;
- anon key cuando aplique;
- service role;
- configuracion de integracion.

Prohibidos:

- secretos en Kotlin/TypeScript cliente;
- secretos en `VITE_*`;
- secretos en logs;
- secretos en documentacion;
- archivos `.env` versionados.

## 14. Despliegue de migracion

Secuencia:

```powershell
supabase migration list --linked
supabase db push --linked
supabase migration list --linked
```

Despues:

1. Ejecutar `obtener_mi_autorizacion()`.
2. Confirmar rol original.
3. Confirmar rol canonico.
4. Confirmar permisos.
5. Confirmar alcance.
6. Probar Web y Android.

## 15. Despliegue de funcion

```powershell
supabase functions deploy <function-name>
supabase functions list
```

Antes:

- confirmar proyecto vinculado;
- revisar diff;
- confirmar secretos;
- confirmar modelo de autenticacion;
- confirmar CORS;
- probar localmente cuando sea posible.

Despues:

- revisar version;
- ejecutar caso feliz;
- ejecutar denegacion;
- revisar logs sin datos sensibles;
- confirmar auditoria.

## 16. Observabilidad

Registrar:

- nombre de funcion/RPC;
- request/correlation ID;
- actor presente;
- empresa presente;
- permiso solicitado;
- conteo de alcance;
- codigo PostgreSQL;
- resultado.

No registrar payload completo ni credenciales.

## 17. Recuperacion

Migraciones:

- preferir una migracion compensatoria;
- no editar ni borrar historial;
- no usar reset remoto destructivo.

Edge:

- volver a desplegar una version conocida;
- validar compatibilidad con SQL;
- no dejar un handler antiguo sobre un contrato nuevo sin comprobacion.

## 18. Deudas Supabase

- Aplicar `0030`.
- Probar RLS multiempresa sistematicamente.
- Confirmar paridad local/remota de Edge Functions.
- Revisar los seis handlers con `verify_jwt=false`.
- Consolidar reglas de nomina.
- Documentar contratos RPC con pruebas de forma de respuesta.
