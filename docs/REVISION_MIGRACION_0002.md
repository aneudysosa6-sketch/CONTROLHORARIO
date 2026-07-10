# Revisión de `0002_empleados_permisos_portal.sql`

## Veredicto

La versión original generada no debía ejecutarse. Fue corregida en este trabajo y ahora encaja conceptualmente con el modelo objetivo, pero sigue **pendiente de prueba local real** junto con `0001` y el seed. No se autoriza producción hasta superar `supabase db reset` y pruebas RLS multiempresa.

## Hallazgos

| Severidad | Hallazgo original | Resolución |
|---|---|---|
| Crítico | `perfil_id` tenía FK simple `SET NULL` y FK compuesta `RESTRICT`, con acciones contradictorias. | Se dejó una FK compuesta y `ON DELETE SET NULL (perfil_id)` compatible con PG17. |
| Alto | `profiles` heredaba lectura de todos los perfiles del tenant y mutaciones basadas solo en código `admin`. | `0002` elimina esas políticas y crea políticas granulares con `usuarios.administrar`. |
| Alto | No existía alcance explícito ni soporte para supervisar múltiples áreas. | Añadido `alcance` a asignaciones y tablas `perfil_sucursales`/`perfil_departamentos` con RLS. |
| Alto | `empleados.editar` permitía marcar `desvinculado` sin permiso de desactivar. | El `WITH CHECK` exige `empleados.desactivar` para inactividad/desvinculación. |
| Medio | `profiles` y `empleados` duplican nombre, teléfono, foto y código. | Se documenta `empleados` como fuente laboral; normalización definitiva se planifica sin romper 0001. |
| Medio | Los permisos `.ver_todos` mezclan acción y alcance. | Se conservan por compatibilidad, pero `alcance` queda explícito; normalización futura planificada. |
| Medio | Catálogo global de permisos depende de seed posterior. | Denegación predeterminada es segura; despliegue debe incluir seed transaccionalmente probado. |
| Bajo | Nombres 0001 en inglés y 0002 en español. | Se conservan nombres reales ya ejecutados; documentación declara la excepción. |

## RLS y funciones

- `tiene_permiso` usa `SECURITY DEFINER`, `search_path=''`, objetos calificados y denegación final.
- No se detectaron `USING (true)`, políticas `anon` abiertas ni empresa libre del cliente.
- Las consultas recursivas se evitan porque helpers privilegiados leen `profiles`/asignaciones sin pasar por sus propias políticas.
- `authenticated` no puede escribir `empresa_id`, `perfil_id`, `salario` ni `pin_hash` directamente.
- Gestión de permisos excluye el perfil y rol propios; alcance adicional valida mismo tenant.

## Compatibilidad con 0001 ejecutada

La migración usa los nombres reales `companies`, `profiles`, `roles`, `branches`, `departments`, `positions` y agrega la unicidad `(company_id,id)` requerida en profiles. Los `DROP POLICY` apuntan a nombres exactos creados por `0001`; por ello `0002` presupone que el esquema remoto coincide con la migración versionada. Antes de aplicar, `supabase db pull/diff` debe confirmar ausencia de drift.

## Resumen exacto de cambios a 0002

1. FK de perfil consolidada con unlink seguro.
2. Desactivación reforzada.
3. `alcance` agregado a `rol_permisos` y `perfil_permisos`.
4. Creadas `perfil_sucursales` y `perfil_departamentos`, grants, índices y RLS.
5. Reemplazadas cuatro políticas de profiles heredadas.
6. Seed actualizado para alcances `propio/departamento/empresa`.

## Pendientes antes de ejecutar

1. Instalar Supabase CLI y levantar stack local.
2. Ejecutar desde cero 0001→0002→seed.
3. Probar dos empresas, usuario inactivo, todos los alcances y auto-escalación.
4. Validar sintaxis PG17 de `ON DELETE SET NULL (perfil_id)` en el runtime Supabase local.
5. Añadir tests pgTAP de funciones y políticas.
6. Comparar la base remota ya migrada con `0001`; cualquier drift requiere migración compensatoria, no edición manual.

Estado final: **corregida documentalmente, no ejecutada y no aprobada todavía para producción**.
