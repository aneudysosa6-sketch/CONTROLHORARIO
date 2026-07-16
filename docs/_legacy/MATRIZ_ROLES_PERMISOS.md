# Matriz de roles, permisos y alcance

## Regla

El rol ofrece una base, no una autorización absoluta. `perfil_permisos` puede conceder o denegar; el alcance efectivo limita filas. Orden: excepción individual → rol → denegar.

Leyenda: `P` propio, `D` departamento, `S` sucursal, `E` empresa, `G` global, `—` sin acceso.

| Módulo | super_admin | administrador_empresa | recursos_humanos | supervisor | nomina | auditor | empleado | kiosco |
|---|---|---|---|---|---|---|---|---|
| portal/perfil | G administrar | E administrar | P | P | P | P lectura | P | sesión limitada |
| empleados | G CRUD | E CRUD/desactivar | E CRUD/desactivar | D lectura | E lectura | E lectura | P lectura | — |
| departamentos/sucursales | G administrar | E administrar | E lectura | D/S lectura | E lectura | E lectura | — | — |
| horarios | G administrar | E administrar | E administrar | D lectura | P lectura | E lectura | P | — |
| asistencia | G corregir | E corregir | E lectura/corregir | D corregir limitado | E lectura | E lectura/exportar | P registrar/ver | P registrar |
| solicitudes/vacaciones | G administrar | E aprobar | E aprobar | D aprobar nivel | P crear | E auditar | P crear/ver | — |
| nómina | G administrar | E aprobar | E lectura restringida | — | E procesar/aprobar/exportar | E lectura auditada | P recibo | — |
| reportes | G | E exportar | E exportar | D exportar limitado | E exportar | E exportar | P | — |
| usuarios/roles/permisos | G administrar | E administrar otros | usuarios limitados | — | — | lectura | — | — |
| configuración | G | E administrar | E lectura | — | E lectura | E lectura | — | — |
| auditoría | G | E lectura limitada | E RRHH | D operativa | E nómina | E completa | propia seguridad | propia sesión |
| archivos | G | E administrar | E empleado | D adjuntos | E nómina | E lectura | propios | — |
| dispositivos | G | E administrar | E lectura | D lectura | — | E lectura | propios | dispositivo propio |

## Capacidades normalizadas

Cada módulo usa códigos consistentes: `.ver_propio`, `.ver_departamento`, `.ver_sucursal`, `.ver_empresa`, `.crear`, `.editar`, `.aprobar`, `.corregir`, `.desactivar`, `.exportar`, `.administrar`. Los códigos antiguos `.ver_todos` se mantienen en `0002` por compatibilidad y equivalen a alcance `empresa`; una migración futura puede normalizarlos sin romper clientes.

## Roles definitivos

- `super_admin`: transversal, solo backend, nunca sesión cotidiana ni frontend con privilegio de bypass.
- `administrador_empresa`: reemplazo conceptual del código actual `admin`.
- `recursos_humanos`: código actual `hr`.
- `supervisor`, `nomina` (`payroll`), `empleado` (`employee`).
- `auditor`: lectura y exportación trazable, sin mutaciones.
- `kiosco`: identidad de dispositivo, no usuario humano; solo asistencia validada.

Los códigos existentes se conservan hasta una migración de alias/renombrado planificada. No se deben cambiar directamente en producción.

## Alcance

`rol_permisos.alcance` y `perfil_permisos.alcance` definen el máximo. `perfil_departamentos` y `perfil_sucursales` amplían asignaciones múltiples dentro de la misma empresa. `global` solo es válido para `super_admin`; RLS debe ignorarlo para roles de tenant.
