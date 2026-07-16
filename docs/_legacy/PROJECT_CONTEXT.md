# PROJECT_CONTEXT.md

# Contexto Maestro del Proyecto

## Nombre

OSINET Time ERP Enterprise

## Visión

Crear un ERP Android local para Recursos Humanos y operación empresarial, comparable conceptualmente a sistemas como Softland, Nomiplus, SPN y SAP HR en escala Android.

## Principios

- Funciona localmente.
- No depende de Firebase.
- No depende de backend.
- Room Database es la fuente de verdad local.
- Jetpack Compose es la capa visual.
- MVVM organiza el flujo de datos.
- Cada módulo debe poder crecer sin romper otros módulos.

## Roles principales

### Administrador

Tiene acceso completo al ERP.

Puede gestionar:

- Empleados
- Asistencia
- Nómina
- Vacaciones
- Permisos
- Huellas
- Reportes
- Comunicación interna
- Configuración
- Seguridad
- Empresas
- Sucursales
- Departamentos

### Empleado

Acceso limitado.

Solo puede:

- Escribir su código.
- Verificarse con huella.
- Registrar asistencia.

No puede acceder al ERP.

## Problemas históricos que deben evitarse

En versiones previas se detectaron:

- Carpetas duplicadas fuera del paquete correcto.
- Clases duplicadas.
- AppNavigation reemplazado por placeholder.
- Pantalla blanca.
- Continue inventando clases inexistentes.
- AppDatabase con referencias rotas.
- Módulos mezclados de arquitecturas antiguas y nuevas.

Esta documentación existe para evitar repetir esos problemas.
