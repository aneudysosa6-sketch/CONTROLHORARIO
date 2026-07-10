# Database RLS

| Tabla | Leer | Crear/editar/eliminar | Permiso/alcance |
|---|---|---|---|
| companies | miembro activo | admin autorizado | tenant/empresa |
| roles, branches | tenant | administración | roles/configuración; empresa |
| departments, positions | tenant | admin/RRHH | empresa |
| profiles | propio o administrador | solo User Provisioning desde 0003 | usuarios.administrar |
| empleados | propio/D/S/E | columnas permitidas; sensibles solo servidor | empleados.* |
| permisos | propios o administración | catálogo por migración | permisos.administrar |
| rol/perfil permisos | propio o admin | terceros, sin autoescalación | permisos.administrar |
| perfil sucursales/departamentos | propio/admin | terceros autorizados | permisos.administrar |
| provisioning audit | admin del tenant | solo RPC servidor; sin update/delete | usuarios.administrar |

Helpers usan `SECURITY DEFINER`, `search_path=''`, objetos calificados y grants mínimos. `anon` no accede.
