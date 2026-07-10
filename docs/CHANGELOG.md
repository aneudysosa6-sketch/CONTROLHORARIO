# CHANGELOG.md

## 2026-07-10

- Agregado panel administrativo web independiente en `web/` con React, TypeScript, Vite y React Router.
- Incorporadas rutas protegidas, empleados, asistencia, jornadas, kiosco web, reportes, nómina y configuración con datos demostrativos.
- Configurado despliegue SPA en Vercel y documentada la separación Android/web en `WEB_ADMIN_PANEL.md`.
- La aplicación Android y su ponchador PIN + huella no fueron modificados.

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
