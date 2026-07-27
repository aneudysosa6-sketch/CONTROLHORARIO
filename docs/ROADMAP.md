# ROADMAP

Fecha base: 2026-07-27

## 1. Principios

- Seguridad antes que amplitud.
- Una sola fuente de verdad.
- Cerrar despliegues antes de agregar funciones.
- Eliminar duplicacion antes de extender reglas.
- No presentar mocks o adaptadores como producto completo.
- Cada item tiene criterio verificable de cierre.

## 2. Completado

| Capacidad | Estado |
|---|---|
| Supabase Auth | Operativo |
| Sesion persistente Android | Operativo |
| Recarga remota de autorizacion | Operativo |
| Rol original/canonico | Operativo |
| Navegacion Android por rol | Operativo |
| Compatibilidad de aliases de empleado Android | Operativo |
| Dashboard Web por rol canonico | Operativo |
| Permiso Web oficial de dashboard | Operativo |
| Gestion Web de empleados | Operativo |
| Gestion Web de accesos | Operativo |
| Jornadas Android offline | Operativo |
| Panel Web de jornadas | Operativo |
| Alcance de supervisor | Operativo |
| Room v39 sin fallback destructivo | Operativo |
| Edge Functions principales | Desplegadas |
| Documentacion oficial consolidada | Completado |

## 3. P0 - Cierre inmediato

### R-001 - Aplicar migracion 0030

Objetivo:

- remoto devuelve `EMPLEADO` para aliases de empleado.

Criterios:

- `supabase db push --linked` exitoso;
- remoto lista `0030`;
- `role_code_original = empleados`;
- `role_code_canonical = EMPLEADO`;
- Android abre Dashboard Empleado;
- Web abre Portal Empleado.

### R-002 - Confirmar revision Web desplegada

Objetivo:

- Vercel ejecuta la misma arquitectura documentada.

Criterios:

- proyecto/revision identificados;
- build exitoso;
- login;
- refresh de `/dashboard`;
- `/accesos`;
- `/jornadas`;
- permisos y rol canonico comprobados.

## 4. P1 - Seguridad y consistencia

### R-101 - Eliminar autorizacion duplicada Web

Alcance:

- bypass administrativo;
- aliases locales de permisos;
- guard por rol original;
- acceso con permisos requeridos vacios.

Criterios:

- solo permisos remotos;
- solo rol canonico;
- pruebas positivas/negativas;
- build Web.

### R-102 - Matriz RLS multiempresa

Alcance:

- perfiles;
- empleados;
- jornadas;
- nomina;
- prestamos;
- organizacion;
- biometria;
- dispositivos.

Criterios:

- empresa A no consulta B;
- supervisor solo asignaciones;
- empleado solo datos propios;
- perfil inactivo denegado;
- resultados documentados.

### R-103 - Auditar `verify_jwt=false`

Alcance:

- seis Edge Functions activas.

Criterios:

- actor/credencial;
- tenant;
- permiso;
- schema;
- idempotencia;
- rate/replay;
- logs;
- caso anonimo denegado.

### R-104 - Unificar nomina

Decision:

- retirar motor Android o convertirlo en consumidor/estimador del motor SQL.

Criterios:

- una implementacion oficial;
- casos numericos;
- misma redondez/moneda;
- auditoria;
- exportacion igual al persistido.

### R-105 - Retirar o aislar kiosco Web mock

Criterios:

- no accesible como funcion productiva;
- demo claramente etiquetada o eliminada;
- Android permanece kiosco oficial.

## 5. P2 - Robustez operativa

### R-201 - Dashboards Web dedicados

Roles:

- RRHH;
- NOMINA;
- AUDITOR.

Criterios:

- componente propio;
- permisos remotos;
- sin fallback administrativo;
- responsive;
- estados completos.

### R-202 - Hardware 2Connect

Criterios:

- modelos de dispositivo;
- versiones Android;
- permisos USB;
- captura/enrolamiento/match;
- reconexion;
- reinicio;
- manejo de baja calidad;
- reporte de campo.

### R-203 - Liveness facial

Antes de implementar:

- ADR aprobada;
- evaluacion de privacidad;
- metrica FAR/FRR;
- fallback;
- soporte offline;
- costo/licencia.

Criterio:

- deteccion de presentacion validada. No solo multiples frames.

### R-204 - Pruebas offline y conflicto

Criterios:

- cierre forzado;
- modo avion;
- dos dispositivos;
- replay;
- version antigua;
- conflicto;
- backoff;
- recuperacion.

### R-205 - Dependencias Web reproducibles

Criterios:

- retirar `latest`;
- lockfile estable;
- build limpio;
- politica de actualizacion.

### R-206 - Reducir riesgo de navegacion Android

Criterios:

- separar grafos por dominio sin crear un segundo resolver;
- pruebas de rutas;
- back stack documentado;
- sin refactorizacion funcional simultanea.

## 6. P3 - Integraciones y operacion

### R-301 - N8N de servidor

Criterios:

- outbox;
- dispatcher seguro;
- webhook firmado;
- workflow versionado;
- idempotencia durable;
- reintentos;
- dead-letter;
- auditoria de entrega;
- monitoreo.

### R-302 - Entornos formales

Criterios:

- desarrollo;
- staging;
- produccion;
- proyectos/secretos separados;
- promocion de migraciones;
- datos de prueba;
- rollback.

### R-303 - Pipeline CI/CD

Criterios:

- Android test/build/lint;
- Web build;
- checks SQL;
- validacion de Edge;
- artefactos versionados;
- aprobacion de despliegue.

### R-304 - Observabilidad unificada

Criterios:

- correlation ID;
- errores por capa;
- metricas de sincronizacion;
- alertas de Edge/N8N;
- retencion segura;
- sin PII sensible.

### R-305 - Auditoria funcional en UI

Criterios:

- consulta por permiso;
- filtros;
- actor/accion/fecha/resultado;
- tenant;
- exportacion controlada.

## 7. Futuro condicionado

No iniciar sin ADR y caso de negocio:

- nuevos canales biometricos;
- geolocalizacion continua;
- nuevos proveedores de mensajeria;
- motor externo de nomina;
- multi-region;
- kiosco Web productivo;
- analitica avanzada.

## 8. Fuera de alcance actual

- reemplazar Supabase Auth;
- desactivar RLS;
- service role en cliente;
- acceso global de supervisor;
- volver a PIN;
- guardar contrasenas;
- reescribir migraciones;
- crear permisos solo para resolver UI;
- mantener dos fuentes oficiales de nomina.

## 9. Regla de avance

Un item pasa a completado solo con:

1. Implementacion.
2. Pruebas.
3. Despliegue cuando aplique.
4. Verificacion en entorno objetivo.
5. Seguridad.
6. Documentacion.
7. Evidencia registrada.

Si falta una condicion, el estado es parcial o pendiente, no completado.
