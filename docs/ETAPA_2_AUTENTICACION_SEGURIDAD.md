# Etapa 2: autenticación, permisos y seguridad

## Web

El panel usa Supabase Auth con correo y contraseña mediante la clave publicable. Restaura la sesión administrada por el SDK, cierra sesión, envía recuperación y permite actualizar la contraseña. No persiste contraseñas en almacenamiento web ni contiene credenciales demo.

Tras autenticar, carga `profiles` y `roles`, exige que ambos estén activos y resuelve permisos efectivos con `tiene_permiso`. `portal.acceder` es obligatorio. El menú se filtra por permisos y cada ruta administrativa tiene guard independiente; un acceso no autorizado termina en `/acceso-denegado`. Ocultar el menú no sustituye RLS.

Variables requeridas: `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`. Nunca se configura `service_role` en Vite. Para probar login real se necesita un proyecto Supabase, un usuario Auth confirmado y su profile/rol/permisos; esta entrega no creó usuarios ni conectó una base real.

## Room y seguridad local

La auditoría identificó cuatro entidades anotadas fuera de `AppDatabase`: `N8NSettingsEntity`, `N8NOutboxEntity`, `N8NSyncLogEntity` y `WhatsAppOutboxEntity`. Son restos de integraciones eliminadas, por lo que registrarlas reintroduciría superficie obsoleta. `SupervisorDepartmentEntity` sí estaba registrada y es operada por `SupervisorDao`.

No cambió el esquema Room ni su versión. Se eliminó `fallbackToDestructiveMigration`, de modo que una migración ausente falla de forma segura en lugar de borrar datos. La sesión Android ya no escribe/restaura la contraseña y limpia el valor heredado al iniciar sesión.

PIN y plantilla 2Connect continúan temporalmente en su formato heredado para mantener datos y hardware. No se añaden imágenes ni plantillas biométricas nuevas, y esos datos no deben sincronizarse. Su retirada requiere una migración compatible, respaldo y rollback.

Riesgo heredado pendiente: el alta automática del administrador Android conserva una contraseña inicial en código y las tablas locales comparan contraseñas/PIN en formato legado. Retirarlo ahora bloquearía instalaciones existentes sin un flujo de aprovisionamiento y migración. Antes de producción conectada se debe sustituir por activación inicial obligatoria y hashes migrados al primer acceso; cualquier credencial real coincidente debe rotarse.

## Límites de verificación

Los builds y verificaciones estáticas prueban integración y presencia de flujos, no autenticación contra infraestructura real. No se ejecutaron migraciones Supabase, no se desplegó producción y no se modificaron reglas de nómina.
