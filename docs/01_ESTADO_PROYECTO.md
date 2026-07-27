# ESTADO REAL DEL PROYECTO

Fecha de corte: 2026-07-27  
Tipo de revision: auditoria estatica del repositorio y consulta de metadatos
del proyecto Supabase vinculado

## 1. Resumen

CONTROL HORARIO tiene una base funcional amplia. Android, Web y Supabase ya
comparten un contrato de autorizacion remota basado en
`obtener_mi_autorizacion()`. El sistema tambien posee sincronizacion offline,
administracion de empleados, jornadas, nomina, prestamos, biometria y
operacion en modo kiosco.

No todo esta cerrado. Las principales deudas son la migracion `0030` pendiente
en remoto, autorizacion Web todavia parcialmente duplicada, dos motores de
nomina, ausencia de liveness facial, validacion limitada del lector 2Connect y
una integracion N8N que aun no incluye workflows versionados.

## 2. Estado por capa

| Capa | Estado | Evidencia principal | Observacion |
|---|---|---|---|
| Android | Operativo | Modulo `app`, Compose, Room v39, WorkManager | Build, lint y pruebas unitarias pasaron el 2026-07-27 |
| Web | Operativo con deuda | React, Vite, TypeScript, Supabase JS | La autorizacion remota funciona; quedan adaptadores locales |
| Supabase Auth | Operativo | Sesiones, refresh token, usuarios Auth | Es la unica identidad valida |
| PostgreSQL | Operativo | Migraciones `0001` a `0029` remotas | `0030` esta pendiente de `db push` |
| Edge Functions | Operativo | Seis funciones remotas activas | Debe verificarse cada handler con `verify_jwt=false` |
| RLS y permisos | Operativo con validacion pendiente | Politicas y RPC por empresa/alcance | Requiere pruebas multiempresa sistematicas |
| Biometria facial | Parcial | FaceNet local y embeddings cifrados | No hay deteccion de vida/PAD |
| Huella 2Connect | Parcial | SDK y flujo local implementados | Falta matriz formal de pruebas con hardware |
| Nomina | Operativo con riesgo | Motor SQL y motor local Android | Existe duplicacion de reglas |
| N8N | Base implementada | Adaptador Web y eventos | No hay workflows ni cola durable en el repo |
| Despliegue Web | Pendiente de validar | `vercel.json` y build Vite | Esta auditoria no desplego ni verifico produccion |

## 3. Validaciones conocidas

Ultima evidencia local disponible:

| Validacion | Resultado | Fecha |
|---|---|---|
| `gradlew.bat :app:testDebugUnitTest` | `BUILD SUCCESSFUL` | 2026-07-27 |
| `gradlew.bat :app:assembleDebug` | `BUILD SUCCESSFUL` | 2026-07-27 |
| `gradlew.bat :app:lintDebug` | Exito, codigo de salida 0 | 2026-07-27 |
| Build Web | No repetido durante esta auditoria documental | 2026-07-27 |
| Prueba E2E remota completa | No ejecutada durante esta auditoria | 2026-07-27 |

Estas evidencias no sustituyen una nueva validacion cuando cambie codigo.

## 4. Estado funcional

### Autenticacion y autorizacion

Estado: operativo.

- Supabase Auth administra credenciales, access token y refresh token.
- Android persiste solo los datos necesarios para restaurar Auth.
- Android reconstruye `AuthenticatedPrincipal` con autorizacion remota.
- Web hidrata la sesion con `obtener_mi_autorizacion()`.
- El servidor devuelve rol original, rol canonico, permisos y alcance.
- `role_code_canonical` es el contrato de navegacion.

Deuda:

- La Web conserva un bypass local para administrador.
- La Web mantiene adaptadores de alias de permisos.
- Algunos guards Web todavia miran valores originales en lugar del contrato
  canonico.

### Empleados y accesos

Estado: operativo.

- Alta y mantenimiento Web mediante `employee-management`.
- Provision de usuarios mediante `user-provisioning`.
- Codigo de empleado de seis digitos generado de forma autoritativa.
- Terminacion y reactivacion con auditoria.
- Listado de accesos limitado a empleados activos desde la migracion `0027`.

Deuda:

- Confirmar regularmente paridad entre Edge Functions locales y versiones
  desplegadas.
- Conservar mensajes funcionales sin exponer errores SQL.

### Jornadas

Estado: operativo con trabajo offline.

- Estado local de jornada en Android.
- Outbox, idempotencia, version conocida y resolucion de conflicto.
- Verificacion de dispositivo y prueba ECDSA en sincronizacion.
- Consulta Web por alcance y RLS.
- Dashboard de supervisor limitado a asignaciones.

Deuda:

- Mantener pruebas de concurrencia y multi-dispositivo.
- Documentar criterios operativos para correcciones manuales.

### Nomina

Estado: operativo con riesgo arquitectonico.

- Supabase contiene periodos, detalles, reglas, ajustes, prestamos, creditos,
  descuentos, archivos y auditoria.
- La Web consume RPC del motor SQL.
- Android mantiene un motor local y exportacion PDF/CSV.

Riesgo:

- Dos implementaciones pueden producir resultados diferentes.
- Hasta cerrar la decision, solo los resultados persistidos en Supabase son
  oficiales.

### Prestamos

Estado: parcial.

- El portal Web posee solicitudes y movimientos remotos.
- Android contiene entidades y pantallas locales.

Deuda:

- Unificar contratos y estados entre el portal remoto y la experiencia local.

### Biometria y kiosco

Estado: parcial operativo.

- Kiosco Android soporta Device Owner/Device Admin, lock task, arranque e
  interfaz inmersiva.
- FaceNet genera embeddings locales y los guarda cifrados.
- El lector 2Connect posee captura, enrolamiento y comparacion local.

Deuda:

- No existe liveness facial.
- La precision y recuperacion del lector deben validarse con hardware real.
- Persisten algunos textos de UI que mezclan facial y huella.

### N8N

Estado: base implementada.

- La Web puede emitir eventos HTTP no bloqueantes.
- Existen tipos de eventos para organizacion, nomina, prestamos y empleados.

Deuda:

- No hay workflows exportados.
- No hay firma del webhook, cola durable ni registro de entrega.
- La llamada nace en el navegador y no debe transportar secretos.

## 5. Estado remoto Supabase

Fotografia del 2026-07-27:

| Elemento | Estado remoto observado |
|---|---|
| Migraciones | `0001` a `0029` presentes |
| Migracion `0030` | No aplicada |
| `user-provisioning` | Activa, version 11 |
| `employee-management` | Activa, version 4 |
| `device-enrollment` | Activa, version 3 |
| `employee-sync` | Activa, version 12 |
| `attendance-sync` | Activa, version 4 |
| `employee-upsert` | Activa, version 6 |

La lista remota informa `verify_jwt=false` para las seis funciones. Esto no
significa acceso anonimo por si solo: los handlers implementan validacion
manual de JWT o credenciales de dispositivo. Cada cambio debe revisar esa
validacion antes del despliegue.

## 6. Riesgos priorizados

| Prioridad | Riesgo | Consecuencia |
|---|---|---|
| P0 | `0030` no aplicada en remoto | El servidor puede devolver `EMPLEADOS` |
| P1 | Bypass y adaptadores de permiso en Web | Diferencia con el contrato remoto |
| P1 | Dos motores de nomina | Resultados financieros divergentes |
| P1 | Cobertura RLS multiempresa incompleta | Fuga o bloqueo de datos por tenant |
| P1 | Funciones con JWT manual | Error de handler puede abrir una operacion |
| P1 | Kiosco Web con datos mock | Confusion entre demo y producto |
| P2 | Sin liveness facial | Riesgo de presentacion o suplantacion |
| P2 | Huella sin matriz de hardware | Fallos no reproducidos en campo |
| P2 | N8N sin cola ni workflow versionado | Notificaciones perdidas |
| P2 | Dependencias Web con `latest` | Builds no reproducibles |
| P2 | Navegacion Android monolitica | Mayor riesgo de regresion |

## 7. Siguientes objetivos

El orden oficial esta en [ROADMAP.md](./ROADMAP.md). Los primeros resultados
esperados son:

1. Aplicar y verificar `0030` en Supabase remoto.
2. Eliminar decisiones locales de autorizacion Web.
3. Probar RLS y alcance con dos empresas y varios departamentos.
4. Declarar y hacer cumplir un unico motor oficial de nomina.
5. Separar o retirar el kiosco Web mock.
6. Llevar N8N a una integracion de servidor auditable.

## 8. Lo que esta auditoria no afirma

- No afirma que Vercel tenga hoy la misma revision local.
- No afirma que las Edge Functions locales sean byte a byte iguales a remoto.
- No afirma que todos los flujos hayan sido probados con hardware real.
- No afirma que N8N este desplegado.
- No afirma que la migracion `0030` ya este aplicada.
- No convierte una deuda documentada en funcionalidad completada.
