# Portal: roles y permisos

## Principio de acceso

Todos los empleados podrán tener una cuenta de Supabase Auth y acceder al portal, pero disponer de un empleado no crea acceso automáticamente. La separación es:

```text
auth.users  → identidad y autenticación
profiles    → empresa, rol y estado de acceso
empleados   → expediente laboral
roles       → agrupación base de capacidades
permisos    → acciones autorizables
```

`empleados.perfil_id` es nullable y único: RRHH puede crear primero el expediente laboral y enlazarlo después con una cuenta. Un perfil solo puede pertenecer a un empleado.

## Resolución efectiva

La función `public.tiene_permiso(codigo)` aplica este orden:

1. Si existe una fila en `perfil_permisos`, utiliza su valor `permitido`.
2. De lo contrario, utiliza `rol_permisos`.
3. Si no existe ninguna asignación activa, devuelve `false`.

No existe acceso implícito. Una excepción individual puede conceder o denegar, y siempre prevalece sobre el rol.

## Roles iniciales

- `employee`: portal y datos personales.
- `supervisor`: capacidades personales más alcance de departamento.
- `hr`: gestión laboral, horarios y reportes globales.
- `payroll`: nómina, asistencia y reportes globales. Este rol se agrega en el seed porque no existía en `0001`.
- `admin`: todos los permisos activos.

Los cargos de `positions` no conceden acceso. Por ejemplo, el cargo laboral Gerente no equivale automáticamente a un rol administrativo.

## Menú del portal

El frontend debe construir cada sección según permisos efectivos. Ejemplos:

- Dashboard: `portal.ver_dashboard`.
- Mi perfil: `perfil.ver_propio`.
- Empleados: cualquiera de `empleados.ver_propio`, `empleados.ver_departamento` o `empleados.ver_todos`.
- Asistencia: capacidades `asistencia.*` correspondientes.
- Horarios: `horarios.ver_propio` o `horarios.ver_todos`.
- Nómina: `nomina.ver_propia` o `nomina.ver_todas`.
- Reportes: permisos `reportes.*`.
- Administración: `usuarios.administrar`, `roles.administrar`, `permisos.administrar` o `configuracion.administrar`.

Ocultar un botón mejora la experiencia, pero no autoriza ni protege datos. Cada consulta o cambio debe superar RLS y las funciones de autorización en Supabase.

## Alcance de datos

- Empleado: únicamente su expediente enlazado.
- Supervisor: empleados de su empresa y su departamento.
- RRHH o administrador: empleados de su empresa cuando su permiso lo autoriza.
- Ningún rol puede atravesar `empresa_id`.

Las columnas `empresa_id`, `perfil_id`, `salario` y `pin_hash` no tienen escritura directa para `authenticated`. Su gestión debe hacerse mediante un backend o RPC específico, revisado y transaccional. No se debe guardar un PIN sin hash bcrypt o Argon2.

## Crear y enlazar un usuario

No existe trigger automático sobre `auth.users`. `profiles` necesita empresa, rol y nombre confiables, y esos valores no deben tomarse de `raw_user_meta_data` enviado por el cliente.

Flujo recomendado desde una Edge Function o backend confiable:

1. Un administrador con `usuarios.administrar` selecciona un empleado sin `perfil_id`.
2. El backend valida que administrador, rol y empleado pertenecen a la misma empresa.
3. Crea la identidad Auth con correo confirmado según la política empresarial.
4. En una operación controlada crea `profiles` usando `auth.users.id`, la empresa del administrador y un rol no privilegiado explícito.
5. Enlaza `empleados.perfil_id` con el nuevo perfil.
6. Registra auditoría y envía un flujo de establecimiento de contraseña; nunca genera una contraseña fija en SQL.

Para el primer administrador, crear el usuario desde Supabase Auth o un script backend protegido y luego, con una conexión administrativa segura, insertar su fila `profiles` apuntando al rol `admin` de OSINET y enlazarla al empleado correspondiente. Este bootstrap no debe exponerse como política RLS ni ejecutarse desde el navegador.

Procedimiento reproducible recomendado:

1. Crear o invitar al usuario desde la sección **Authentication → Users** de Supabase. No asignar empresa ni rol mediante metadata.
2. Copiar únicamente su UUID de `auth.users`.
3. Crear una migración de bootstrap versionada con `supabase migration new bootstrap_primer_admin`.
4. En esa migración, dentro de una transacción y sustituyendo `UUID_AUTH_REAL`, insertar primero el empleado sin perfil, luego el perfil y finalmente enlazarlos:

```sql
do $$
declare
  v_empresa uuid;
  v_rol uuid;
  v_sucursal uuid;
  v_departamento uuid;
  v_puesto uuid;
  v_empleado uuid;
  v_auth_user constant uuid := 'UUID_AUTH_REAL';
begin
  select id into strict v_empresa from public.companies where slug = 'osinet';
  select id into strict v_rol from public.roles where company_id = v_empresa and code = 'admin';
  select id into strict v_sucursal from public.branches where company_id = v_empresa and is_main;
  select id into strict v_departamento from public.departments where company_id = v_empresa and code = 'ADMIN';
  select id into strict v_puesto from public.positions where company_id = v_empresa and code = 'ADMINISTRADOR';

  insert into public.empleados (
    empresa_id, sucursal_id, departamento_id, puesto_id,
    codigo_empleado, nombre_completo, estado_laboral, activo
  ) values (
    v_empresa, v_sucursal, v_departamento, v_puesto,
    '00001', 'Administrador inicial', 'activo', true
  ) returning id into v_empleado;

  insert into public.profiles (
    id, company_id, role_id, branch_id, department_id, position_id,
    employee_code, full_name, status
  ) values (
    v_auth_user, v_empresa, v_rol, v_sucursal, v_departamento, v_puesto,
    '00001', 'Administrador inicial', 'active'
  );

  update public.empleados set perfil_id = v_auth_user where id = v_empleado;
end
$$;
```

5. Revisar esa migración, aplicarla mediante Supabase CLI y retirarla de cualquier proceso reutilizable si solo corresponde al entorno inicial. No incluir contraseña, token ni PIN.

Para aplicar `0001`, `0002` y el seed en un proyecto enlazado, desde la raíz del repositorio:

```bash
supabase login
supabase link --project-ref TU_PROJECT_REF
supabase migration list
supabase db push --include-seed
```

Antes de producción se recomienda ejecutar `supabase db reset` en un entorno local o rama aislada. No se debe probar por primera vez sobre la base productiva.

## Cambios de permisos

Un usuario con `permisos.administrar` puede administrar asignaciones dentro de su propia empresa, excepto su propio perfil y su propio rol. El catálogo global `permisos` permanece de solo lectura para clientes y se modifica mediante migraciones/seed versionados.
