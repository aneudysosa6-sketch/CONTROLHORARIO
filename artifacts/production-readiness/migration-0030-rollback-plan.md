# Migración 0030 — Plan de rollback

## Alcance

Este documento no contiene SQL ejecutable. Describe la respuesta segura si
`0030_fix_employee_role_canonicalization.sql` falla en staging o presenta una
regresión después de completarse.

## Posibilidad real de rollback

Si la migración falla antes del `commit`, PostgreSQL debe revertir
automáticamente el reemplazo de la función y el bloque de comprobación.

Si la migración ya terminó, el rollback debe implementarse como una migración
compensatoria nueva, revisada y aprobada. Esa migración restauraría la
definición anterior de `private.normalizar_codigo_rol(text)` tomada de `0029`.
No se debe editar `0030`, borrar registros del historial ni usar reparación
manual del historial.

## Datos recuperables y no recuperables

`0030` no modifica filas, por lo que no se identifica pérdida directa de datos
que recuperar. Sin embargo, entre la aplicación y la compensación podrían
ocurrir restauraciones de sesión o cambios de rol con decisiones distintas de
canonicalización. Esos efectos operativos deben auditarse; no pueden
reconstruirse únicamente restaurando la función.

## Backup necesario

- Backup verificable del proyecto staging antes de la prueba.
- Captura de la definición, owner, grants y configuración de
  `private.normalizar_codigo_rol(text)`.
- Captura del historial de migraciones hasta `0029`.
- Inventario agregado de roles por código, sin datos personales.
- Evidencia de configuración de los RPC consumidores y del trigger de cambio
  de rol.
- Para producción futura, backup conforme a la política operativa vigente y
  prueba previa de restauración.

## Objetos que deberían restaurarse

| Objeto | Restauración esperada |
|---|---|
| `private.normalizar_codigo_rol(text)` | Definición exacta anterior de `0029` |
| Owner y grants de la función | Confirmar que no cambiaron; restaurar solo mediante migración compensatoria aprobada |
| Historial de migraciones | No manipular; registrar la compensación como una migración nueva |

## Criterios para abortar

- El proyecto seleccionado no es staging o puede confundirse con producción.
- El historial no contiene exactamente la secuencia esperada hasta `0029`.
- El preflight detecta firma, owner, grants o `search_path` inesperados.
- Hay aliases o roles no reconocidos sin explicación del responsable funcional.
- Existen inconsistencias de empresa entre perfiles, roles o empleados.
- No existe backup verificable o no se ha probado su restauración.
- Se observa espera de locks que excede la ventana aprobada.
- Falla cualquier comprobación de aliases, login, sesión, permisos o tenant.
- Android, Web o `user-provisioning` presentan una regresión.
- No hay responsable disponible para autorizar la compensación.

## Respuesta ante fallo

| Momento | Acción |
|---|---|
| Antes de aplicar | Detener la prueba, conservar evidencia y corregir el plan |
| Durante la transacción | Dejar que PostgreSQL revierta; no manipular el historial |
| Después del `commit`, sin tráfico | Suspender pruebas y evaluar migración compensatoria |
| Después del `commit`, con actividad | Bloquear promoción, preservar logs, evaluar sesiones y cambios de rol, y decidir compensación |

## Aprobación

La activación de una migración compensatoria requiere aprobación conjunta del
responsable de backend/Supabase, seguridad, QA y propietario de producción.
La ejecución operativa debe quedar asignada a una persona autorizada distinta
del revisor que emitió este documento.
