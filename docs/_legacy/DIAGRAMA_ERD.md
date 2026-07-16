# Diagramas ERD

## General

```mermaid
erDiagram
  COMPANIES ||--o{ PROFILES : tenant
  COMPANIES ||--o{ BRANCHES : tiene
  BRANCHES ||--o{ DEPARTMENTS : agrupa
  DEPARTMENTS ||--o{ POSITIONS : define
  AUTH_USERS ||--|| PROFILES : autentica
  PROFILES ||--o| EMPLEADOS : enlaza
  ROLES ||--o{ ROL_PERMISOS : asigna
  PERMISOS ||--o{ ROL_PERMISOS : incluye
  PROFILES ||--o{ PERFIL_PERMISOS : excepciona
  EMPLEADOS ||--o{ EMPLEADO_HORARIOS : recibe
  HORARIOS ||--o{ EMPLEADO_HORARIOS : asigna
  EMPLEADOS ||--o{ EVENTOS_ASISTENCIA : genera
  EMPLEADOS ||--o{ JORNADAS : consolida
  EMPLEADOS ||--o{ SOLICITUDES : solicita
  SOLICITUDES ||--o{ APROBACIONES_SOLICITUD : recorre
  PERIODOS_NOMINA ||--o{ DETALLES_NOMINA : contiene
  EMPLEADOS ||--o{ DETALLES_NOMINA : cobra
  ARCHIVOS ||--o{ RELACIONES_ARCHIVO : adjunta
  PROFILES ||--o{ AUDITORIA : actua
  DISPOSITIVOS_SINCRONIZACION ||--o{ COLA_SINCRONIZACION : envia
```

## Seguridad

```mermaid
erDiagram
  AUTH_USERS ||--|| PROFILES : identidad
  COMPANIES ||--o{ PROFILES : aisla
  ROLES ||--o{ PROFILES : clasifica
  ROLES ||--o{ ROL_PERMISOS : base
  PERMISOS ||--o{ ROL_PERMISOS : capacidad
  PROFILES ||--o{ PERFIL_PERMISOS : excepcion
  PROFILES ||--o{ PERFIL_SUCURSALES : alcance
  PROFILES ||--o{ PERFIL_DEPARTAMENTOS : alcance
  PROFILES ||--o{ SESIONES_DISPOSITIVOS : inicia
  PROFILES ||--o{ HISTORIAL_PERMISOS : audita
```

## Empleados y horarios

```mermaid
erDiagram
  EMPLEADOS ||--o{ CONTACTOS_EMERGENCIA : tiene
  EMPLEADOS ||--o{ DOCUMENTOS_EMPLEADO : posee
  EMPLEADOS ||--o{ HISTORIAL_LABORAL : historiza
  EMPLEADOS ||--o{ HISTORIAL_SALARIAL : historiza
  EMPLEADOS ||--o{ ASIGNACIONES_EMPLEADO : asigna
  HORARIOS ||--o{ HORARIO_DETALLES : compone
  EMPLEADOS ||--o{ EMPLEADO_HORARIOS : recibe
  HORARIOS ||--o{ EMPLEADO_HORARIOS : aplica
  TURNOS ||--o{ ROTACIONES_TURNOS : rota
  EMPLEADOS ||--o{ CALENDARIO_EMPLEADO : materializa
```

## Asistencia

```mermaid
erDiagram
  EMPLEADOS ||--o{ EVENTOS_ASISTENCIA : registra
  DISPOSITIVOS_PONCHE ||--o{ EVENTOS_ASISTENCIA : origina
  UBICACIONES_PONCHE ||--o{ EVENTOS_ASISTENCIA : valida
  EMPLEADOS ||--o{ JORNADAS : consolida
  JORNADAS ||--o{ PAUSAS : contiene
  EVENTOS_ASISTENCIA ||--o{ CORRECCIONES_ASISTENCIA : corrige
  CORRECCIONES_ASISTENCIA ||--o{ APROBACIONES_CORRECCION : aprueba
  JORNADAS ||--o{ INCIDENCIAS_ASISTENCIA : detecta
```

## Solicitudes

```mermaid
erDiagram
  TIPOS_SOLICITUD ||--o{ SOLICITUDES : clasifica
  EMPLEADOS ||--o{ SOLICITUDES : crea
  SOLICITUDES ||--o{ APROBACIONES_SOLICITUD : niveles
  SOLICITUDES ||--o| VACACIONES : detalle
  SOLICITUDES ||--o| PERMISOS_LABORALES : detalle
  SOLICITUDES ||--o| INCAPACIDADES : detalle
  SOLICITUDES ||--o| LICENCIAS : detalle
  SOLICITUDES ||--o| SOLICITUDES_HORAS_EXTRA : detalle
```

## Nómina

```mermaid
erDiagram
  PERIODOS_NOMINA ||--o{ DETALLES_NOMINA : contiene
  EMPLEADOS ||--o{ DETALLES_NOMINA : recibe
  CONCEPTOS_NOMINA ||--o{ REGLAS_NOMINA : calcula
  PERIODOS_NOMINA ||--o{ NOVEDADES_NOMINA : incorpora
  DETALLES_NOMINA ||--o{ DEDUCCIONES : descuenta
  DETALLES_NOMINA ||--o{ INGRESOS_ADICIONALES : suma
  PERIODOS_NOMINA ||--o{ EXPORTACIONES_NOMINA : exporta
  PERIODOS_NOMINA ||--o{ HISTORIAL_PROCESAMIENTO_NOMINA : audita
```

## Sincronización

```mermaid
erDiagram
  DISPOSITIVOS_SINCRONIZACION ||--o{ COLA_SINCRONIZACION : produce
  COLA_SINCRONIZACION ||--o| CONFLICTOS_SINCRONIZACION : detecta
  DISPOSITIVOS_SINCRONIZACION ||--o{ ESTADOS_SINCRONIZACION : cursor
  EMPLEADOS ||--o{ COLA_SINCRONIZACION : contexto
```

## Clasificación

- Maestras: empresas, sucursales, departamentos, puestos, roles, permisos, conceptos, horarios.
- Transaccionales: solicitudes, jornadas, nómina en proceso, trabajos de exportación.
- Históricas/append-only: eventos de asistencia, correcciones, auditoría, historial salarial, historial laboral, historial de permisos y procesamiento de nómina.
- No deben borrarse físicamente: asistencia sincronizada, correcciones, aprobaciones, nómina aprobada, auditoría, eventos de seguridad y conflictos resueltos.

Las relaciones 1:1 separan identidad/perfil/empleado; 1:N modelan pertenencia e históricos; N:M se implementan con tablas puente para permisos, horarios y alcances.
