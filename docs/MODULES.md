# MODULES.md

# Módulos oficiales

## 1. Empleados

Gestión completa de empleados:

- Código automático.
- Perfil.
- Departamento.
- Sucursal.
- Cargo.
- Contacto.
- Estado activo/inactivo.
- Configuración de nómina.
- Huella.
- Historial.

## 2. Asistencia

Registro de jornada:

- Iniciar jornada.
- Pausar.
- Reanudar.
- Finalizar.
- Validación por huella.
- Registro por empleado.
- Reporte diario.

## 3. Nómina

Funciones:

- Cálculo de salario.
- Descuentos.
- Ingresos.
- Historial.
- Reportes.
- Exportación.

## 4. Vacaciones

Funciones:

- Solicitud.
- Aprobación.
- Rechazo.
- Historial.
- Días disponibles.
- Supervisores.

## 5. Permisos

Funciones:

- Permisos laborales.
- Aprobación por supervisor.
- Motivos.
- Estado.
- Historial.

## 5.1. Préstamos

Funciones:

- Solicitud por empleado.
- Aprobación o rechazo.
- Entrega del dinero.
- Descuento por nómina.
- Pagos parciales.
- Balance pendiente.
- Historial por estado.

## 5.2. Encargado de Sucursal

Funciones:

- Crear usuario encargado desde Usuarios.
- Asignar una sucursal.
- Ver eventos de esa sucursal.
- Activar o desactivar empleados de esa sucursal.
- Acceder a modo PIN.
- Sin acceso a Nómina por defecto.

## 6. Huellas

Funciones:

- Registro de huella.
- Validación para ponche.
- Estado biométrico por empleado.

## 7. Notificaciones internas

Funciones:

- Centro de incidencias y eventos locales.
- Alertas nuevas con borde neón azul.
- Alcance por empresa, sucursal, supervisor y permisos.
- Estado pendiente/atendido dentro del producto.
- Sin entrega, colas ni reintentos de mensajería externa.

## 8. Reportes

Funciones:

- Asistencia.
- Nómina.
- Empleados.
- Vacaciones.
- Permisos.
- Exportación futura PDF/Excel.

## Módulos eliminados definitivamente

- Integraciones de correo externo.
- Integraciones de mensajería externa.
- Automatizadores y endpoints externos de mensajería.

CONTROLHORARIO no incluye Gmail, WhatsApp ni n8n. Las alertas y notificaciones son internas.
