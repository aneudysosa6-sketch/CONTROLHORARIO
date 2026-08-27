# Database Bootstrap

La Edge Function verifica JWT, secreto efímero y cero profiles; llama `bootstrap_tenant_internal`. Una transacción crea primera empresa, rol admin, sucursal, profile, asignación de todos los permisos activos, empleado opcional y auditoría. Supabase Auth crea antes la identidad; SQL nunca maneja contraseña.

Tras éxito: borrar/rotar secreto. Cualquier segundo intento falla. Primer acceso exige Auth confirmado, profile/rol activos y `portal.acceder`. No se requieren INSERT manuales. El catálogo global de permisos debe estar sembrado antes del bootstrap.
