# Migración 0030 — Plan de prueba en staging

## Reglas

- Usar únicamente datos sintéticos.
- No usar el proyecto `controlhorario-prod`.
- No incluir project refs completos, tokens, contraseñas ni datos personales en
  la evidencia.
- No promover cambios a producción durante este plan.
- Registrar comandos, responsables, tiempos observados y resultados sin
  secretos.

## Secuencia

1. Crear o identificar un proyecto staging separado.
2. Confirmar por nombre, organización y referencia enmascarada que no sea `controlhorario-prod`.
3. Aplicar y verificar en staging las migraciones `0001` a `0029`.
4. Ejecutar `migration-0030-preflight.sql` y revisar todos los resultados.
5. Ejecutar un dry-run de las migraciones pendientes con el mecanismo aprobado para staging.
6. Aplicar `0030` únicamente en staging.
7. Ejecutar `migration-0030-postflight.sql` y confirmar cada comprobación.
8. Probar login con roles canónicos y con los aliases sintéticos `EMPLEADO`, `EMPLEADOS`, `EMPLOYEE` y `EMPLOYEES`.
9. Probar restauración de sesión antes y después de la migración.
10. Confirmar que `role_code_canonical` sea `EMPLEADO` para los cuatro aliases.
11. Probar que un usuario inactivo sea rechazado.
12. Probar que un usuario autenticado sin perfil sea rechazado.
13. Probar que un usuario de empresa A no acceda a recursos de empresa B.
14. Probar un supervisor limitado a sus departamentos y sucursales asignados.
15. Probar Android: login, restauración, dashboard y portal de empleado.
16. Probar Web: login, restauración, `/dashboard` y `/mi-portal`.
17. Probar las Edge Functions relacionadas, especialmente cambio de rol mediante `user-provisioning`, y confirmar que las demás no regresen.
18. Registrar evidencia de resultados, locks, duración observada, sesiones y logs sin secretos.
19. Probar en staging la estrategia de rollback o una migración compensatoria revisada, sin alterar manualmente el historial.
20. Emitir una decisión formal separada para producción.

## Casos mínimos

| Caso | Resultado esperado |
|---|---|
| `EMPLEADO` | Canonical `EMPLEADO`; acceso según permisos |
| `EMPLEADOS` | Canonical `EMPLEADO`; sin denegación incorrecta |
| `EMPLOYEE` | Canonical `EMPLEADO`; acceso según permisos |
| `EMPLOYEES` | Canonical `EMPLEADO`; sin dashboard desconocido |
| Usuario inactivo | Rechazo controlado |
| Usuario sin perfil | Rechazo `PROFILE_NOT_FOUND` o equivalente |
| Empresa A contra B | Sin lectura ni operación cruzada |
| Supervisor limitado | Solo alcance asignado |
| Cambio entre aliases de empleado | No limpiar permisos o alcance por cambio de familia inexistente |
| Rol realmente distinto | Limpiar excepciones y alcance conforme al trigger |

## Evidencia requerida

- Identificación enmascarada del proyecto staging.
- Estado del historial antes y después.
- Resultados agregados de preflight y postflight.
- Matriz de pruebas de roles, sesiones, empresas y plataformas.
- Inventario de versiones Android/Web usadas.
- Resultado de `user-provisioning` y comprobación de no regresión.
- Locks y duración observados, sin estimaciones inventadas.
- Resultado del ensayo de rollback o compensación.
- Firmas de QA, backend/Supabase y seguridad.

## Criterio de salida

La prueba de staging solo se aprueba si todos los controles pasan, no quedan
inconsistencias de tenant o autorización, el rollback está ensayado y existe
evidencia suficiente para una decisión posterior. La aprobación de staging no
autoriza producción ni cierra G07.
