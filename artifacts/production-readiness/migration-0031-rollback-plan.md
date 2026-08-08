# Plan de compensacion para la migracion 0031

Estado: plan documental; no ejecutado.

## Principio

Si 0031 falla antes de `COMMIT`, PostgreSQL revierte toda la transaccion. Si ya
fue aplicada, no se debe editar la migracion historica: se debe preparar una
nueva migracion compensatoria, por ejemplo
`0032_compensate_admin_access_permissions.sql`.

La compensacion no puede borrar permisos por codigo a ciegas. Las referencias
de `public.rol_permisos` y `public.perfil_permisos` a `public.permisos` tienen
`ON DELETE CASCADE`; un borrado no probado podria eliminar asignaciones
legitimas o cambios posteriores.

## Evidencia obligatoria antes de aplicar 0031

Congelar primero los cambios de roles y permisos. Luego guardar por entorno un
baseline fechado, identificado por proyecto y snapshot, que incluya:

- las filas completas de `public.permisos` para los tres codigos, o evidencia
  de que cada una no existia;
- todos los pares `(rol_id, permiso_id)` para roles ADMIN activos, con
  `permitido`, `alcance` y `created_at`, o evidencia de ausencia;
- los IDs de permiso y rol, empresa, codigo original del rol y estado activo;
- cualquier fila de `public.perfil_permisos` que use esos IDs;
- resultado del comparador y aprobacion de la ventana de cambio.

Inmediatamente despues de 0031 se debe capturar una postimagen exacta y un
manifiesto de los IDs y pares insertados o modificados. El baseline, la
postimagen y el manifiesto deben almacenarse de forma integra y con acceso
restringido. Para produccion tambien se exige un backup verificable y una
prueba documentada de restauracion antes de autorizar la ventana.

El baseline debe almacenarse fuera de las tablas afectadas y conservarse junto
con la evidencia de aplicacion. Sin esa preimagen no existe una reversión
destructiva segura.

## Matriz de compensacion

| Estado demostrado antes de 0031 | Accion de la futura 0032 |
|---|---|
| Permiso preexistente | Restaurar exactamente `nombre`, `descripcion`, `modulo` y `activo` desde el baseline; no cambiar su ID ni `created_at`. El trigger fijara un nuevo `updated_at` que documenta la compensacion. |
| Permiso ausente y creado solo por 0031 | Considerar retirarlo solo despues de compensar asignaciones y demostrar que no tiene referencias ni adopcion posterior. |
| Asignacion preexistente | Restaurar exactamente `permitido` y `alcance`; conservar el par y su `created_at`. |
| Asignacion ausente y creada solo por 0031 | Retirar solo ese par exacto `(rol_id, permiso_id)`, si no hubo una decision posterior que lo legitime. |
| Preexistencia o cambios posteriores inciertos | No borrar ni restaurar automaticamente; detener la compensacion y aplicar una correccion hacia adelante. |

## Diseño de la futura migracion compensatoria

La 0032 debe ser revisada con los valores concretos del baseline y ejecutarse
en una sola transaccion:

1. Validar que el entorno y los IDs coinciden con la evidencia archivada.
2. Bloquear o congelar temporalmente el flujo que modifica roles y permisos.
3. Restaurar primero las asignaciones que ya existian antes de 0031.
4. Retirar unicamente los pares demostrablemente creados por 0031.
5. Restaurar los metadatos y estados de permisos preexistentes.
6. Para un permiso nuevo de 0031, verificar que no quedan referencias en
   `rol_permisos` ni `perfil_permisos` y que no fue adoptado despues. Solo con
   ambas pruebas puede evaluarse su retiro por ID exacto.
7. Si una prueba falla, abortar toda la transaccion.
8. Ejecutar un postflight compensatorio y archivar el resultado.

`public.rol_permisos` no tiene `updated_at`; por ello no basta con comparar una
fecha para detectar cambios posteriores. La compensacion requiere una ventana
controlada, revision manual de auditoria disponible y aprobacion explicita.

## Opcion segura sin baseline

Si 0031 ya fue aplicada y no existen baseline, postimagen y manifiesto fiables,
queda prohibida una 0032 destructiva. La accion segura es no eliminar filas de
catalogo ni asignaciones. Se debe conservar el estado y crear una migracion
hacia adelante que corrija el problema concreto. Como alternativa conservadora,
una fila de catalogo nueva puede permanecer sin asignaciones; no se debe borrar
mientras su procedencia o sus dependencias sean inciertas.

## Verificacion posterior

La compensacion solo puede declararse completa cuando se confirme que:

- cada fila preexistente coincide en sus campos funcionales con su preimagen y
  el nuevo `updated_at` queda registrado como evidencia de la compensacion;
- solo se retiraron pares demostrablemente introducidos por 0031;
- no se afectaron excepciones de perfil;
- no quedaron referencias huerfanas ni se activaron cascadas inesperadas;
- RLS, policies, grants, funciones y Web permanecen sin cambios.

Este documento propone la estrategia; no crea ni ejecuta la futura 0032.
