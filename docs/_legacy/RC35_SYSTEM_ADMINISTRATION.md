# RC3.5 — Administración del sistema

## Fuente de verdad

La empresa, las secciones visibles y los conteos proceden de `obtener_administracion_sistema()`. La RPC resuelve `company_id` desde el profile autenticado y calcula cada autorización con permisos efectivos. Web y Android no aceptan un tenant enviado por el cliente.

## Categorías y rutas

| Categoría | Web | Android |
|---|---|---|
| Empresa | `/administracion/empresa` | `admin_empresa` |
| Sucursales | `/administracion/sucursales` | `admin_sucursales` |
| Departamentos | `/administracion/departamentos` | `admin_departamentos` |
| Cargos | `/administracion/cargos` | `admin_cargos` |
| Usuarios | `/administracion/usuarios` | `admin_usuarios` |
| Horarios | `/administracion/horarios` | `admin_horarios` |
| Jornadas | `/administracion/jornadas` | `admin_jornadas` |
| Dispositivos | `/administracion/dispositivos` | `admin_dispositivos` |
| Seguridad | `/administracion/seguridad` | `admin_seguridad` |
| Apariencia | `/administracion/apariencia` | `admin_apariencia` |

Web ofrece las operaciones administrativas completas. Android muestra contexto y conteos reales con rutas independientes, sin duplicar las reglas de mantenimiento Web ni mezclar el modo kiosco.

## Seguridad

- Los permisos `configuracion.*` se asignan por defecto solo al rol administrador.
- Supervisores requieren concesión explícita; empleados no reciben acceso administrativo.
- Las mutaciones son RPC `security definer` que vuelven a validar permiso y empresa.
- Las políticas de empresa, sucursales, departamentos y cargos validan permiso efectivo y tenant.
- Cada cambio sensible exige motivo y se registra en `administracion_auditoria`, protegida por RLS.
- No se almacenan sesiones, contraseñas ni tokens en la auditoría.

## Despliegue pendiente

La migración `0011_rc35_system_administration.sql` y el ajuste de `device-enrollment` quedan preparados, pero no se desplegaron. Las pruebas de integración con Supabase deben ejecutarse después de aplicar la migración en un entorno autorizado.
