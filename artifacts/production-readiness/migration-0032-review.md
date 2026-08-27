# Revision estatica de la migracion 0032

Estado: preparada para revision; no aplicada ni ejecutada.

Migracion revisada:
`supabase/migrations/0032_dashboard_access_permission.sql`.

## Causa confirmada

La ruta Web `/dashboard` requiere `portal.ver_dashboard`. El codigo existe en
`supabase/seed.sql`, pero no era creado por ninguna migracion. Las migraciones
0009 y 0029 intentaban asignarlo mediante un `JOIN` contra
`public.permisos`; en un entorno construido solo con migraciones ese `JOIN` no
encontraba la fila y no generaba la asignacion.

0032 convierte el permiso en parte reproducible del historial de migraciones y
elimina la dependencia funcional de `seed.sql`.

## Fila de catalogo

| Campo | Valor normalizado por 0032 |
|---|---|
| `codigo` | `portal.ver_dashboard` |
| `nombre` | `Ver dashboard` |
| `descripcion` | `Permite consultar el panel inicial del portal.` |
| `modulo` | `portal` |
| `activo` | `true` |

El nombre coincide con el seed vigente. La descripcion coincide con el
catalogo historico versionado en `architecture/LEGACY_seed.sql` y sigue el
estilo verbal de las descripciones actuales.

## Roles y asignaciones objetivo

La poblacion queda limitada exactamente a roles que cumplan:

```sql
upper(code) IN ('ADMIN', 'SUPERVISOR')
AND is_active = true
```

Para cada rol objetivo, el par `(rol_id, permiso_id)` queda con:

- `permitido = true`;
- `alcance = 'empresa'`.

Un rol inactivo, un alias distinto de los dos codigos indicados o un rol
creado despues de aplicar 0032 no recibe una asignacion por esta migracion.

## Estrategia idempotente

1. La migracion se ejecuta dentro de una unica transaccion.
2. `public.permisos.codigo` es unico; el primer `ON CONFLICT` crea, reactiva o
   normaliza solamente `portal.ver_dashboard`.
3. La clave primaria de `public.rol_permisos` es
   `(rol_id, permiso_id)`; el segundo `ON CONFLICT` crea o normaliza cada par
   objetivo sin duplicarlo.
4. Ambos `DO UPDATE` usan `IS DISTINCT FROM`, por lo que una segunda ejecucion
   con el estado esperado no genera actualizaciones materiales.
5. La consulta de asignacion lee el permiso creado en la misma transaccion y
   no consulta `seed.sql`.

Las migraciones 0009 y 0029 usaban alcance `departamento` para la asignacion
del permiso generico al supervisor. 0032 normaliza expresamente esa asignacion
a `empresa`, conforme al requisito actual. El permiso funcional
`supervisor.dashboard` no se modifica y conserva su propio alcance.

## Efecto esperado por entorno

### Staging

- crea la fila de catalogo ausente;
- asigna el permiso a los ADMIN y SUPERVISOR activos existentes;
- corrige el bloqueo inicial del supervisor sin tocar la Web ni sus guards.

### Produccion

- conserva el mismo ID de la fila preexistente;
- normaliza sus metadatos y estado solo si difieren;
- conserva o normaliza la asignacion ADMIN a `true/empresa`;
- no crea una asignacion SUPERVISOR si no existe dicho rol activo.

## Alcance de seguridad

La migracion no contiene cambios de:

- Web, rutas, guards o bypasses;
- RLS o policies;
- grants;
- funciones o Edge Functions;
- otras filas de `public.permisos`;
- `public.perfil_permisos`;
- asignaciones de otros permisos.

La revision estatica demuestra este limite porque ambos DML referencian
exclusivamente `portal.ver_dashboard`. La comprobacion historica de que ningun
estado no objetivo cambio durante la ventana requiere comparar la huella del
postflight con una preimagen archivada; un SELECT ejecutado solo despues no
puede demostrar por si mismo un hecho anterior.

## Postflight y reversibilidad

`migration-0032-postflight.sql` comprueba el catalogo, cada rol objetivo, las
asignaciones `true/empresa`, la permanencia de `supervisor.dashboard` y la
huella del estado no objetivo.

Antes de aplicar 0032 se debe archivar la fila objetivo y cada par de
asignacion, junto con la huella no objetivo. El rollback posterior a `COMMIT`
es compensatorio y depende de esa preimagen. En produccion el permiso ya
existia y nunca debe borrarse como rollback.

## Veredicto

0032 es atomica, reproducible, acotada al permiso de acceso al dashboard y a
los roles activos ADMIN/SUPERVISOR. En este trabajo solo se preparo y reviso
estaticamente: no se ejecuto SQL, Supabase, `db push`, deploy, commit ni push.
