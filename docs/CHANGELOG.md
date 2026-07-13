# CHANGELOG.md

## 2026-07-12 — Alcance interno definitivo

- Eliminado el código Android dedicado a integraciones y automatizaciones externas de mensajería.
- Eliminadas colas, entidades, DAOs, repositorios, pantallas, ViewModels, cliente HTTP y motores exclusivos de ese alcance.
- Nómina queda enfocada en cálculo, revisión, aprobación, historial y descargas Excel/PDF.
- Se conserva el sistema interno `AppEvent`/`SupervisorEvent`, incluyendo el borde neón azul para eventos nuevos.
- No se modificaron migraciones históricas: las entidades eliminadas nunca formaron parte de `AppDatabase` v28.
- CONTROLHORARIO no incluye Gmail, WhatsApp ni n8n. Las alertas y notificaciones son internas.

## 2026-07-12

- Implementado Módulo 2.2 de sincronización incremental mediante `employee-sync`, autenticación del dispositivo, aislamiento por empresa, payload activo sin PIN/biometría y tombstones mínimos para bajas.
- Room actualizado a v28 con merge por `remoteId`, preservación de datos locales y WorkManager al enrolar, abrir, recuperar Internet y cada seis horas.
- Añadida pantalla temporal de métricas y pruebas de seguridad, merge, reintentos, migración y scheduling. Supabase no fue desplegado.

## 2026-07-11

- Añadida migración idempotente `0004_admin_employee_permissions.sql`: asegura el código real `empleados.ver_todos` y asigna ver/crear/editar/desactivar con alcance empresa a roles `admin` activos, sin modificar RLS.
- Implementado el módulo web Empleados sobre Supabase: lista con búsqueda/filtros, alta, edición, detalle, activación/desactivación, catálogos organizativos y estadísticas reales de personal en dashboard.
- Añadida `employee-management` para mutaciones sensibles: fuerza tenant desde profile, valida permisos, código/correo únicos y PIN bcrypt único sin exponer PIN ni `service_role`; preparada la UI de huella 2Connect sin captura web.
- Corregida la hidratación del login: PostgREST encontraba ambiguo el embed de `roles` por las FKs simple y compuesta; ahora consulta primero el profile propio por UUID Auth y después valida el rol mediante `role_id + company_id`, con errores diferenciados de RLS, fila ausente y rol inválido.
- Normalizada la validación de `USER_PROVISIONING_BOOTSTRAP_SECRET`: variable y header `x-bootstrap-secret` eliminan solo espacios exteriores antes de la comparación exacta; añadido log temporal de presencia/configuración/coincidencia sin imprimir valores.
- Corregida la autorización del bootstrap: antes de `action=bootstrap`, la pantalla vuelve a autenticar correo/contraseña con `signInWithPassword`, valida la sesión y deja que `functions.invoke` adjunte el JWT; si la operación falla después del login, cierra la sesión.
- Añadido `BootstrapGate` como destino explícito de `/`; la ruta raíz ya no pasa por dashboard/login y decide entre `/bootstrap` y `/login` mediante `bootstrap-status`, sin consultar sesión.
- Corregido el arranque web para consultar mediante Edge Function si `profiles` está vacío y redirigir automáticamente de `/login` a `/bootstrap` sin exigir sesión.
- El bootstrap exitoso ahora cierra la sesión temporal y devuelve a `/login`; si el usuario autenticado ya tiene profile, `/bootstrap` continúa bloqueado y redirige al dashboard.
- Añadida la ruta pública `/bootstrap` para iniciar sesión con el primer usuario Auth y crear de forma transaccional empresa, rol administrador, sucursal principal, profile y empleado opcional.
- El secreto efímero se envía exclusivamente en `x-bootstrap-secret`, permanece solo en memoria del formulario y se limpia después de cada intento.
- La ruta detecta profiles existentes, refresca sesión y permisos al finalizar y redirige al dashboard sin exponer `service_role` ni nuevos secretos Vite.
- Ampliadas las pruebas estáticas de User Provisioning para cubrir ruta pública, campos, header seguro y bloqueo posterior al bootstrap.

## 2026-07-10

- Añadido User Provisioning mediante Edge Function y RPC transaccional exclusiva de `service_role`.
- Revocada la escritura cliente directa sobre `profiles` y añadida auditoría inmutable de aprovisionamiento.
- Incorporado bootstrap de primer administrador y la herramienta web “Sincronizar usuarios Auth”.
- Añadidas pruebas de contratos de autorización, tenant, bootstrap, detección y rutas protegidas.

- Implementada autenticación web real con Supabase Auth, recuperación/cambio de contraseña y cierre/restauración de sesión.
- Añadidos permisos efectivos, menú dinámico, rutas protegidas y pantalla de acceso denegado.
- Eliminadas credenciales web demo y persistencia Android de contraseñas en SharedPreferences.
- Auditadas las entidades Room huérfanas y eliminado el fallback destructivo.

- Agregado panel administrativo web independiente en `web/` con React, TypeScript, Vite y React Router.
- Incorporadas rutas protegidas, empleados, asistencia, jornadas, kiosco web, reportes, nómina y configuración con datos demostrativos.
- Configurado despliegue SPA en Vercel y documentada la separación Android/web en `WEB_ADMIN_PANEL.md`.
- La aplicación Android y su ponchador PIN + huella no fueron modificados.
- Agregada migración inicial Supabase PostgreSQL en `supabase/migrations/0001_initial_schema.sql` con modelo multiempresa, integridad referencial, índices y RLS seguro.
- Agregados `supabase/seed.sql` y `docs/SUPABASE_DATABASE.md`; la migración no fue ejecutada.
- Agregada `0002_empleados_permisos_portal.sql` con expediente laboral, permisos granulares, funciones de autorización y RLS por alcance.
- Actualizado el seed con el rol `payroll`, catálogo de permisos y asignaciones por rol; no se crearon usuarios Auth.
- Documentado el portal, aprovisionamiento seguro y enlace usuario-perfil-empleado en `PORTAL_ROLES_Y_PERMISOS.md`.
- Creado el plano integral Supabase/Android/web en diez documentos de arquitectura, datos, ERD, seguridad, sincronización y negocio.
- Revisada y corregida la migración `0002` antes de su ejecución: FK de perfil, desactivación, alcances múltiples y políticas granulares de `profiles`.
- Confirmado que no se ejecutaron migraciones, no se crearon objetos Supabase reales y no se modificaron Android ni web.
- Investigados Frappe HR, Odoo HR, OrangeHRM, Kimai y repositorios OCA mediante fuentes oficiales; documentados patrones adoptados y descartados.
- Creada auditoría modular, protección biométrica, mapa de navegación/acciones, plan gradual y matriz de regresión.
- Extraída la navegación web a configuración jerárquica con adaptador de permisos, sin añadir rutas vacías ni mover código Android.
- Agregado `scripts/verify_critical_flows.ps1` para proteger BiometricPrompt, 2Connect, PIN, kiosco, cuatro eventos y Room.
- Verificados `vite build` y `:app:assembleDebug` correctamente; no se cambiaron fórmulas ni porcentajes de nómina.

## 2026-07-07

- Creado paquete profesional de documentación OSINET.
- Agregadas reglas para Continue.
- Agregadas reglas para arquitectura ERP.
- Documentado flujo Administrador / Empleado.
- Documentado flujo de ponche con código y huella.

## 2026-07-09

- Agregado módulo Préstamos.
- Registrada tabla loans y LoanDao en AppDatabase v24.
- Agregada pantalla LoansScreen con solicitud, aprobación, entrega, pagos y balance.
- Conectado acceso desde Panel Administrador con PermissionCatalog.LOANS.
- Agregado rol Encargado con sucursal asignada desde Usuarios.
- Agregado Panel Encargado para eventos y activación/desactivación de empleados por sucursal.
- Agregado botón Activar modo PIN en el panel principal.
- Agregada sesión persistente hasta Cerrar sesión.
- Cambiado subtítulo de login a CONTROL HORARIO IA.
- Movido Usuarios a Configuración.
- Registro de huella movido al flujo de Agregar empleado.
- Agregada foto de perfil al empleado.
- Agregado Dashboard Asistencias en Centro de Incidencias con filtro por fecha, historiales y finalización manual de jornadas.
- Agregado permiso Dashboard Asistencias.
- Agregado botón Descargar nómina activado solo con plantilla válida.
- Departamento ahora selecciona Encargado desde usuarios encargados de la sucursal.
- En Préstamos, Pendientes, Aprobados y Entregados ahora abren historial filtrado con acciones.
- Portal del Empleado: Médico y Licencia Médica ahora permiten cargar archivo, foto de galería o foto tomada con cámara.
- Agregado módulo Permisos Empleados con recepción, revisión de adjuntos, aprobación, rechazo con motivo y cálculo diario de licencia médica para nómina.
- Agregada pantalla Modo Kiosko con accesos PIN y HUELLA, manteniendo el flujo PIN + huella para el ponche.
- Restaurado `docs/00_LEER_PRIMERO.md` para continuidad del proyecto.
