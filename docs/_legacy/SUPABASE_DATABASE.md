# Base de datos Supabase

## Objetivo

La capa PostgreSQL de CONTROLHORARIO se administra exclusivamente mediante migraciones versionadas en `supabase/migrations/`. No se deben crear ni modificar tablas directamente en el editor SQL remoto, porque eso rompe el historial reproducible del esquema.

Las migraciones `0001_initial_schema.sql` y `0002_empleados_permisos_portal.sql` son compatibles con PostgreSQL 17 de Supabase. La primera prepara la estructura organizativa multiempresa; la segunda agrega empleados y autorización granular. `supabase/seed.sql` contiene datos maestros de OSINET sin usuarios, contraseñas ni secretos.

## Estructura

| Tabla | Responsabilidad |
|---|---|
| `companies` | Tenant o empresa propietaria de los datos. |
| `profiles` | Perfil empresarial 1:1 de una identidad de `auth.users`. |
| `roles` | Roles de autorización por empresa. |
| `branches` | Sucursales o unidades operativas. |
| `departments` | Departamentos corporativos o asociados a una sucursal. |
| `positions` | Cargos laborales, opcionalmente asociados a un departamento. |
| `empleados` | Expediente laboral, opcionalmente enlazado a un perfil. |
| `permisos` | Catálogo global de capacidades. |
| `rol_permisos` | Asignación base de capacidades a roles. |
| `perfil_permisos` | Excepciones individuales que prevalecen sobre el rol. |

Todas las tablas usan UUID, `created_at` y `updated_at`. Los UUID nuevos se generan con `extensions.gen_random_uuid()`, excepto `profiles.id`, que reutiliza el UUID de `auth.users.id`.

## Relaciones

```text
auth.users 1 ── 1 profiles
companies  1 ── N profiles
companies  1 ── N roles
companies  1 ── N branches
companies  1 ── N departments
companies  1 ── N positions
branches   1 ── N departments
departments 1 ─ N positions

profiles N ── 1 roles
profiles N ── 1 branches
profiles N ── 1 departments
profiles N ── 1 positions
auth.users 1 ── 1 profiles 1 ── 0..1 empleados
roles N ── N permisos (rol_permisos)
profiles N ── N permisos (perfil_permisos)
```

Las claves foráneas compuestas `(company_id, foreign_id)` garantizan que un perfil, cargo o departamento no pueda apuntar a una fila de otra empresa. Este control complementa RLS y protege incluso operaciones internas incorrectas.

## Roles

`roles` controla autorización; `positions` representa el cargo laboral. Son conceptos separados para que un empleado con cargo “Gerente” pueda tener un rol de acceso diferente.

El seed crea estos roles iniciales:

- `admin`: administración total del tenant.
- `hr`: gestión de perfiles y estructura organizativa.
- `supervisor`: supervisión operativa futura.
- `employee`: acceso de empleado futuro.
- `payroll`: procesamiento, aprobación y descarga de nómina.

Los códigos son estables y se usan en las políticas. Los nombres pueden adaptarse a la organización.

## Seguridad y RLS

RLS está activado en las seis tablas. No se crean políticas para `anon`, no existen expresiones `USING (true)` y no se utiliza `service_role`.

El rol PostgreSQL `authenticated` recibe únicamente los privilegios SQL que puede necesitar la aplicación; cada operación también debe superar su política RLS:

- Un usuario activo solo puede leer filas de su propia empresa.
- `admin` puede administrar empresa, roles, sucursales y perfiles de su tenant.
- `admin` y `hr` pueden administrar departamentos y cargos del tenant.
- Un administrador no puede eliminar su propio perfil mediante la Data API.
- No existe una política cliente para crear empresas ni para el primer perfil administrador.

El aprovisionamiento inicial de cada tenant debe realizarse posteriormente mediante un flujo backend confiable y transaccional. No debe resolverse abriendo una política temporal.

Las funciones `private.current_company_id()` y `private.has_company_role()` usan `SECURITY DEFINER` para evitar recursión al consultar `profiles` desde sus propias políticas. Ambas fijan un `search_path` vacío, referencian objetos con esquema explícito, revocan acceso público y solo permiten ejecución a `authenticated`. El esquema `private` no debe exponerse mediante la Data API.

`0002` añade `obtener_empresa_actual()`, `obtener_rol_actual()`, `tiene_permiso()`, `obtener_empleado_actual_id()` y `es_empleado_actual()`. La resolución de permisos es excepción de perfil, luego rol y finalmente denegación. Las funciones no aceptan un tenant elegido por el cliente y usan `auth.uid()`.

RLS en `empleados` permite el registro propio, el departamento o toda la empresa según permisos efectivos. Las asignaciones de permisos solo pueden administrarse dentro del tenant por usuarios autorizados y nunca sobre su propio perfil o rol. El catálogo de permisos no admite escritura desde clientes.

La revisión integral previa a ejecutar `0002` añadió alcance explícito a las asignaciones (`propio`, `departamento`, `sucursal`, `empresa`, `global`) y las tablas `perfil_sucursales` y `perfil_departamentos`. También reemplaza en `0002` las políticas amplias de `profiles` creadas por `0001` con políticas basadas en `usuarios.administrar`.

## Integridad e índices

El esquema incluye:

- Restricciones `CHECK` para estados, formatos, longitudes y niveles.
- Unicidad por empresa para códigos y nombres de catálogos.
- Una sola sucursal principal por empresa mediante índice parcial único.
- Índices para `company_id`, estados y claves foráneas frecuentes.
- Trigger `public.set_updated_at()` en las seis tablas.
- Eliminación en cascada solo desde `companies` hacia catálogos y desde `auth.users` hacia su perfil; relaciones organizativas usan `RESTRICT` para impedir pérdidas accidentales.

## Seed

`supabase/seed.sql` agrega de forma idempotente:

- Empresa OSINET.
- Sucursal principal en Santo Domingo.
- Departamentos: Administración, Recursos Humanos, Operaciones, Tecnología y Contabilidad.
- Cargos: Administrador, Supervisor, Empleado, Nómina y Gerente.
- Roles base de autorización.
- Rol de Nómina, catálogo granular y asignaciones iniciales por rol.

El seed no crea filas en `auth.users` ni `profiles` y no contiene credenciales.

## Flujo de migraciones

Crear migraciones nuevas con Supabase CLI y revisarlas en control de versiones:

```bash
supabase migration new nombre_del_cambio
```

Aplicarlas primero en un entorno local o rama aislada:

```bash
supabase db reset
```

Cuando estén probadas y aprobadas, una persona responsable puede desplegarlas:

```bash
supabase db push
```

El seed se incluye explícitamente cuando corresponda:

```bash
supabase db push --include-seed
```

Estos comandos son documentación del flujo. La migración inicial no fue ejecutada durante su creación.

## Próximas migraciones

Jornadas, eventos de asistencia, nómina operativa y auditoría deben incorporarse en migraciones posteriores. Cada tabla operativa deberá incluir tenant, claves foráneas de la misma empresa, índices y políticas RLS antes de exponerse a la web.

El flujo de portal, construcción de menú y aprovisionamiento de usuarios está documentado en `PORTAL_ROLES_Y_PERMISOS.md`.

El plano oficial del modelo futuro está distribuido en `ARQUITECTURA_GENERAL_CONTROLHORARIO.md`, `MODELO_DATOS_COMPLETO.md`, `DIAGRAMA_ERD.md`, `MATRIZ_ROLES_PERMISOS.md`, `PLAN_MIGRACIONES_SUPABASE.md`, `SINCRONIZACION_ANDROID_ROOM_SUPABASE.md`, `FLUJOS_DE_NEGOCIO.md`, `SEGURIDAD_Y_RLS.md` y `STORAGE_REALTIME_EDGE_FUNCTIONS.md`. El estado ejecutable de `0002` se controla en `REVISION_MIGRACION_0002.md`.
