# User Provisioning

## Decisión de arquitectura

CONTROLHORARIO usa una **Supabase Edge Function** como servicio único. Una RPC cliente no puede listar, crear ni invitar identidades de `auth.users`; esas operaciones requieren Admin API. La Edge Function valida el JWT y `usuarios.administrar`, fuerza el tenant desde el profile del operador y mantiene `service_role` únicamente como secreto del servidor.

La función pública `public.provision_user_internal(jsonb)` es una operación interna transaccional. Aunque está en `public` para que PostgREST pueda invocarla, se revoca a `public`, `anon` y `authenticated`, y se concede exclusivamente a `service_role`. Crea el profile, aplica excepciones de permisos, enlaza el empleado y registra auditoría en una sola transacción.

## Flujo completo

1. Un administrador abre **Administración → Sincronizar usuarios**.
2. El navegador llama `user-provisioning` con su JWT publicable, nunca con `service_role`.
3. El servicio comprueba sesión, profile activo y `usuarios.administrar`.
4. `list` usa Admin API para comparar `auth.users` con `profiles` y devuelve únicamente identidades pendientes.
5. El administrador puede seleccionar una identidad existente o invitar una nueva, asignar rol y enlazar un empleado libre.
6. La empresa se toma del operador en el servidor. IDs de otro tenant son rechazados nuevamente por la RPC.
7. Profile, permisos opcionales, enlace laboral y auditoría se confirman juntos. Si la creación Auth con contraseña falla después, la identidad recién creada se elimina como compensación; una invitación fallida queda visible para reintento.

Los clientes ya no tienen privilegios `INSERT`, `UPDATE` ni `DELETE` sobre `profiles`. RLS permanece activa para lectura. Android no cambia: la separación `auth.users`/`profiles` y el vínculo opcional con `empleados` siguen siendo compatibles con su futura sincronización.

## Bootstrap del primer administrador

La web expone `/bootstrap` únicamente como punto de entrada inicial. La pantalla autentica al usuario existente con Supabase Auth, comprueba si su UUID ya tiene `profiles` y, si existe, redirige al dashboard. Si falta, solicita empresa, razón social, slug, nombre del administrador, correo autenticado, sucursal principal, código de empleado opcional, zona horaria fija `America/Santo_Domingo` y el secreto temporal.

Al abrir `/login`, el cliente invoca la acción pública `bootstrap-status`. La función consulta `profiles` con sus credenciales de servidor y responde únicamente `bootstrap_required: boolean`; no expone filas, conteos, usuarios ni secretos. Si no hay profiles, la web redirige a `/bootstrap`. Tras crear el primer profile, cierra la sesión usada durante la activación y vuelve a `/login` para un inicio normal.

La ruta inicial `/` monta `BootstrapGate`, que no consume `AuthContext` ni inspecciona sesiones. El gate espera `bootstrap-status` y sustituye la URL por `/bootstrap` cuando no existe ningún profile o por `/login` cuando el sistema ya fue inicializado. Las rutas desconocidas regresan a `/` para pasar por la misma decisión segura.

El secreto se conserva solo en estado de memoria mientras el formulario está abierto, se envía como `x-bootstrap-secret` y se limpia tras cada intento. No se guarda en `localStorage`, `sessionStorage`, variables `VITE_*` ni archivos. La Edge Function vuelve a validar el JWT, el secreto y que el conteo global de profiles sea cero; la UI no sustituye esas garantías del servidor.

Inmediatamente antes de enviar `action=bootstrap`, `BootstrapPage` ejecuta `supabase.auth.signInWithPassword` con el correo y contraseña mantenidos únicamente en memoria y exige que la respuesta incluya una sesión. Luego usa `supabase.functions.invoke`, sin construir el encabezado `Authorization`; el SDK adjunta el JWT de esa sesión. Un error de autenticación se muestra sin invocar la función y un error posterior cierra la sesión antes de permitir otro intento.

El bootstrap existe para resolver el ciclo inicial cuando no hay profiles:

1. Aplicar por CLI `0001`, `0002`, `0003` y seed en un entorno de ensayo.
2. Desplegar `user-provisioning` y configurar un secreto aleatorio largo `USER_PROVISIONING_BOOTSTRAP_SECRET` con `supabase secrets set`; nunca colocarlo en Vite.
3. Crear o invitar el primer usuario mediante Supabase Auth. Iniciar sesión para obtener su JWT.
4. Invocar una sola vez la Edge Function con acción `bootstrap`, encabezado `x-bootstrap-secret` y payload con `company_id`, `role_id` del rol `admin`, `full_name`, `status: active` y opcional `employee_id`.
5. La función exige que el conteo de profiles sea exactamente cero y aprovisiona al mismo usuario dueño del JWT.
6. Eliminar/rotar inmediatamente `USER_PROVISIONING_BOOTSTRAP_SECRET`. Desde entonces toda administración requiere `usuarios.administrar`.

Ejemplo conceptual (sustituir valores, no guardar el JWT en archivos):

```bash
curl -X POST "$SUPABASE_URL/functions/v1/user-provisioning" \
  -H "Authorization: Bearer $USER_JWT" \
  -H "Content-Type: application/json" \
  -H "x-bootstrap-secret: $BOOTSTRAP_SECRET" \
  -d '{"action":"bootstrap","company_id":"...","role_id":"...","full_name":"Administrador OSINET","status":"active"}'
```

## Archivos y despliegue futuro

- `supabase/migrations/0003_FINAL.sql`: auditoría, revocaciones, provisioning y bootstrap transaccional.
- `supabase/functions/user-provisioning/`: servicio de Admin API.
- `web/src/pages/UserProvisioningPage.tsx`: herramienta administrativa.
- `scripts/test_user_provisioning.ps1`: contratos de seguridad estáticos.

Esta entrega no aplica migraciones, no despliega la función y no modifica Supabase real. Antes de hacerlo: ejecutar reset local, pruebas multiempresa, bootstrap descartable, invitación, reintento, empleado ya enlazado, rol cruzado, usuario sin permiso y auditoría.
