# Plan de compensacion para la migracion 0032

Estado: plan documental; no ejecutado.

## Principio

Si 0032 falla antes de `COMMIT`, PostgreSQL revierte toda la transaccion. Si ya
fue aplicada, no se debe editar la migracion historica ni borrar por codigo: se
debe preparar una nueva migracion compensatoria con el siguiente numero
disponible.

La compensacion no puede eliminar `portal.ver_dashboard` a ciegas. Las claves
foraneas de `public.rol_permisos` y `public.perfil_permisos` usan
`ON DELETE CASCADE`; borrar el permiso podria retirar asignaciones legitimas o
cambios posteriores.

## Evidencia obligatoria antes de aplicar 0032

Congelar durante la ventana los cambios de roles y permisos y archivar, por
entorno:

- identificador del proyecto, entorno, fecha y migration head;
- fila completa de `public.permisos` para `portal.ver_dashboard`, o evidencia
  de que no existia;
- todos los roles objetivo con `id`, `company_id`, `code` e `is_active`;
- cada par objetivo `(rol_id, permiso_id)` con `permitido`, `alcance` y
  `created_at`, o evidencia de ausencia;
- todas las referencias del permiso en `rol_permisos` y
  `perfil_permisos`, incluso las ajenas a los roles objetivo;
- las tres huellas del bloque 06 de `migration-0032-postflight.sql`.

Inmediatamente despues de 0032 se debe capturar una postimagen y un manifiesto
de los IDs y pares insertados o modificados. Sin preimagen, postimagen y
manifiesto fiables no existe rollback destructivo seguro.

## Matriz de compensacion

| Estado demostrado antes de 0032 | Accion compensatoria |
|---|---|
| Permiso preexistente | Restaurar exactamente `nombre`, `descripcion`, `modulo` y `activo` desde la preimagen. Conservar su ID y `created_at`; no borrarlo. |
| Permiso ausente y creado por 0032 | Considerar retirarlo solo por su UUID exacto, despues de compensar los pares creados por 0032 y confirmar que no quedan referencias ni adopcion posterior. |
| Asignacion preexistente | Restaurar exactamente `permitido` y `alcance`, incluido `departamento` si ese era su estado anterior. Conservar el par y `created_at`. |
| Asignacion ausente y creada por 0032 | Retirar solo el par exacto `(rol_id, permiso_id)` probado por el manifiesto, siempre que siga coincidiendo con la postimagen de 0032. |
| Preexistencia o cambios posteriores inciertos | No borrar ni sobrescribir; abortar la compensacion destructiva y preparar una correccion hacia adelante. |

## Diferencia por entorno conocido

### Produccion

`portal.ver_dashboard` ya existia antes de 0032. Un rollback nunca debe
eliminarlo. Debe restaurar sus metadatos y las asignaciones preexistentes desde
el baseline exacto. La ausencia actual de un rol SUPERVISOR no autoriza borrar
el permiso ni la asignacion ADMIN.

### Staging

El permiso estaba ausente antes de 0032. Solo podria evaluarse su eliminacion
si esa ausencia fue archivada, el manifiesto demuestra que 0032 lo creo, no
hubo adopcion posterior y no queda ninguna referencia en `rol_permisos` ni
`perfil_permisos`. Si cualquiera de esas pruebas falla, debe conservarse la
fila y aplicarse una correccion hacia adelante.

## Orden de una futura migracion compensatoria

1. Validar proyecto, entorno, migration head e IDs contra la evidencia.
2. Mantener congelados los cambios de roles y permisos.
3. Bloquear la compensacion si la postimagen actual difiere del manifiesto.
4. Restaurar primero las asignaciones que ya existian antes de 0032.
5. Retirar unicamente los pares demostrablemente creados por 0032.
6. Restaurar los metadatos y el estado del permiso si era preexistente.
7. Si el permiso era nuevo, comprobar cero referencias en
   `rol_permisos` y `perfil_permisos` antes de considerar eliminarlo por UUID.
8. Abortar toda la transaccion si cualquier precondicion falla.
9. Ejecutar un postflight compensatorio y archivar sus resultados.

`public.rol_permisos` no tiene `updated_at`; por ello no se puede inferir que
una fila no cambio usando solo timestamps. La ventana controlada, la preimagen
y el manifiesto son obligatorios.

## Opcion segura sin baseline

Si 0032 ya fue aplicada sin preimagen, postimagen y manifiesto verificables, la
unica opcion segura es no borrar ni sobrescribir filas. Se debe conservar el
estado y crear una migracion hacia adelante que corrija el problema concreto.

Este documento define la estrategia; no crea ni ejecuta SQL de rollback.
