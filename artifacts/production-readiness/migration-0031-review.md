# Revision estatica de la migracion 0031

Estado: lista para revision; no aplicada ni ejecutada.

Migracion revisada: `supabase/migrations/0031_admin_access_permissions.sql`.

## Problema y contrato real

El hallazgo operacional aportado para este trabajo compara staging con
produccion. La revision estatica confirma su causa de bootstrap:
`supabase/seed.sql` contiene los tres permisos administrativos, pero ninguna
migracion entre `0001` y `0030` los incorpora al catalogo. Un entorno
reconstruido solo con migraciones queda incompleto para la seccion usuarios.

`public.obtener_administracion_sistema()` usa dos contratos distintos:

- Entrada al RPC: `configuracion.administrar` o `configuracion.ver`.
- Seccion `usuarios`: `usuarios.administrar`, `roles.administrar` o
  `permisos.administrar`.

La migracion 0031 corrige exclusivamente el segundo contrato. De los codigos de
entrada, `0011_rc35_system_administration.sql` versiona `configuracion.ver` y
lo asigna a los ADMIN activos existentes en ese momento. La sesion de staging
del hallazgo ya supera esa puerta. `configuracion.administrar` tambien aparece
en el seed y no es creado por las migraciones 0001-0030, pero el RPC usa OR y
no es la causa del fallo confirmado. Ampliar 0031 para corregir ese cuarto
codigo queda fuera del alcance solicitado.

## Filas objetivo

| codigo | nombre | descripcion | modulo | activo |
|---|---|---|---|---|
| `usuarios.administrar` | Administrar usuarios | Gestiona usuarios, estados de acceso y asignaciones de rol de la empresa. | `administracion` | `true` |
| `roles.administrar` | Administrar roles | Gestiona roles de autorizacion de la empresa. | `administracion` | `true` |
| `permisos.administrar` | Administrar permisos | Gestiona permisos asignados a los roles de la empresa. | `administracion` | `true` |

Los nombres coinciden con el catalogo de `seed.sql`. El modulo
`administracion` coincide con ese catalogo y con los permisos `usuarios.*`
creados en la migracion 0022. Las descripciones siguen el estilo verbal de los
permisos versionados en 0011 y 0022.

## Esquema verificado

La definicion vigente de `public.permisos` en `0002_FINAL.sql` expone
`codigo`, `nombre`, `descripcion`, `modulo`, `activo`, `created_at` y
`updated_at`; `codigo` es unico. Las fechas de filas nuevas usan los valores
por defecto del esquema. En una actualizacion real, el trigger
`permisos_set_updated_at` mantiene `updated_at`.

`public.rol_permisos` usa la clave primaria `(rol_id, permiso_id)` y expone
`permitido`, `alcance` y `created_at`. No tiene columna `updated_at`. El valor
`empresa` esta permitido por su restriccion de alcance.

## Estrategia de la migracion

1. La transaccion hace upsert de los tres codigos por la restriccion unica de
   `public.permisos.codigo`.
2. En conflicto normaliza nombre, descripcion, modulo y `activo = true`.
3. Selecciona todos los roles existentes que cumplen exactamente
   `upper(code) = 'ADMIN'` e `is_active = true`.
4. Genera los tres pares rol-permiso y los inserta por la clave primaria.
5. En conflicto de asignacion actualiza unicamente `permitido = true` y
   `alcance = 'empresa'`; conserva `created_at`.
6. Los predicados `IS DISTINCT FROM` evitan actualizaciones sin cambios y, en
   particular, que una segunda ejecucion altere `updated_at` sin necesidad.

El resultado es atomico, repetible y no crea duplicados. La segunda sentencia
consulta `public.permisos` directamente, por lo que tambien encuentra filas que
ya existian antes de la migracion.

## Seguridad y limites deliberados

- No modifica RLS, policies, grants, funciones, Web ni el bypass Web actual.
- No usa `seed.sql` como dependencia.
- No selecciona roles por nombre ni por aliases canonicos: replica exactamente
  el criterio solicitado sobre `roles.code` y evita ampliar privilegios a
  `adm`, `administrador`, `administrator` o `super_admin`.
- Por mandato de asignar a todos los ADMIN activos, no filtra el estado de
  `public.companies`. Un rol `admin` activo de una empresa inactiva tambien
  queda asignado. Como `tiene_permiso(text)` no usa `companies.status`, la
  revision previa a promover debe inventariar esos casos; excluirlos requeriria
  una decision funcional distinta al alcance solicitado. El diseño adopta
  expresamente esta poblacion porque el requisito no condiciona el estado de
  la empresa; el postflight la reporta, pero no la trata como fallo de 0031.
- Es un backfill para roles ADMIN activos al momento de aplicacion. Un rol
  creado o reactivado despues necesita el flujo normal de asignacion.
- No modifica `public.perfil_permisos`. Una denegacion individual tiene
  prioridad sobre el permiso del rol y el postflight con JWT la mostrara.
- `alcance = 'empresa'` es parte del contrato persistido, aunque la version
  vigente de `tiene_permiso(text)` resuelve el booleano sin consultar alcance.
- Por requisito, un codigo preexistente pero inactivo se reactiva globalmente;
  eso hace efectivas sus asignaciones preexistentes tambien fuera del ADMIN.
  Asimismo, una asignacion ADMIN preexistente con denegacion o alcance distinto
  se normaliza a `true/empresa`. Estos cambios exigen baseline antes de aplicar.

## Validacion estatica y postflight

La revision debe confirmar:

- exactamente los tres codigos y metadatos esperados;
- conflicto por `permisos.codigo` y por `(rol_id, permiso_id)`;
- actualizacion de asignaciones limitada a `permitido` y `alcance`;
- predicado exacto `upper(r.code) = 'ADMIN'` con rol activo;
- ausencia de cambios de RLS, policies, grants y funciones;
- cierre atomico con `COMMIT`;
- ausencia de errores de whitespace mediante `git diff --check`.

El PASS de datos tambien exige que cada rol ADMIN objetivo tenga al menos uno
de los dos permisos de entrada del RPC. Esa comprobacion no amplia el DML de
0031: solo demuestra que la correccion de la seccion usuarios puede ser
alcanzada. La validacion definitiva de overrides individuales sigue siendo la
prueba con JWT.

`migration-0031-postflight.sql` es de solo lectura. Sus primeras verificaciones
pueden ejecutarse con privilegios de diagnostico; la ultima debe ejecutarse con
el JWT de un ADMIN valido. Un resultado sin JWT queda marcado como no ejecutado,
nunca como aprobado. El PASS de extremo a extremo exige que el RPC devuelva
`sections.usuarios = true`.

Antes de una futura aplicacion se debe congelar el flujo de cambios, archivar un
baseline exacto de las tres filas de catalogo y de cada par ADMIN-permiso, y
capturar la postimagen inmediatamente despues. Ese baseline es necesario para
la compensacion descrita en `migration-0031-rollback-plan.md`.

## Veredicto

La migracion es una correccion reproducible limitada a los tres codigos
solicitados y a los roles ADMIN activos. En este trabajo solo se preparo y
reviso estaticamente: no se ejecuto SQL, Supabase, `db push`, deploy, commit ni
push.
