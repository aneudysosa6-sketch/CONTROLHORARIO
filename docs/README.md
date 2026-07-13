# OSINET Time ERP Enterprise

**Versión documental:** 1.0  
**Fecha:** 2026-07-07  
**Plataforma:** Android  
**Lenguaje:** Kotlin  
**UI:** Jetpack Compose  
**Arquitectura:** MVVM  
**Base de datos:** Room Database  
**Backend:** No requerido en esta fase  
**Firebase:** No usar

## Propósito

OSINET Time ERP Enterprise es un sistema Android empresarial para Recursos Humanos, asistencia, control horario, nómina, vacaciones, permisos, huellas, reportes.

El proyecto no debe tratarse como una app sencilla. Debe tratarse como un ERP empresarial local, modular, escalable y mantenible.

## Regla principal

Nunca eliminar funcionalidades existentes.  
Nunca reemplazar pantallas completas sin analizar.  
Nunca crear placeholders.  
Nunca inventar clases.  
Siempre leer la arquitectura antes de modificar.

## Flujo principal

1. Pantalla inicial con dos accesos:
   - Administrador
   - Empleado

2. Administrador:
   - Acceso total al ERP.
   - Gestión de empleados.
   - Asistencia.
   - Nómina.
   - Vacaciones.
   - Permisos.
   - Huellas.
   - Reportes.
   - módulos internos.
   - Configuración.

3. Empleado:
   - Solo puede registrar asistencia.
   - Ingresa código numérico.
   - El sistema identifica el empleado.
   - Solicita huella.
   - Registra ponche.

## Código de empleado

El código debe generarse automáticamente:

- 00001
- 00002
- 00003

Nunca debe depender de escritura manual por parte del administrador.

## Estructura recomendada

```text
app/src/main/java/com/example/controlhorario/
├── database
├── repository
├── engine
├── model
├── ui
├── navigation
├── security
├── session
└── payroll
```

## Antes de modificar

Leer:

- AGENT_RULES.md
- CONTINUE_PROJECT_RULES.md
- PROJECT_CONTEXT.md
- PROJECT_RULES.md
- OSINET_PROJECT_GUIDE.md
