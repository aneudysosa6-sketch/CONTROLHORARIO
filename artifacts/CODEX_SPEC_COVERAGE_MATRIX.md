# Matriz vigente de cobertura de la especificacion maestra

Fecha de reconciliacion: 2026-08-24
Alcance: estado local previo a commits selectivos. Esta matriz no declara validacion E2E.

## Significado de estados

| Estado | Significado |
|---|---|
| IMPLEMENTADO_LOCALMENTE | El contrato y el codigo local requerido existen y las validaciones locales aplicables pasaron; aun puede requerir STAGING o hardware. |
| PARCIAL | Existe implementacion util, pero queda una brecha real de codigo o cobertura local. |
| BLOQUEADO_STAGING | La evidencia restante depende de migraciones, RLS, Edge Functions o datos/sesiones reales de STAGING. |
| BLOQUEADO_HARDWARE | La evidencia restante depende de terminales, telefonos, camara, biometria, audio o conectividad fisica. |

## Cobertura unica vigente

| Area | Requisito | Estado vigente | Evidencia local | Validacion restante |
|---|---|---|---|---|
| Roles y alcance | Roles personalizados y permisos efectivos | PARCIAL | Politicas Android, administracion Web, navegacion y user-provisioning | Completar equivalencia administrativa Android si la especificacion la exige |
| Roles y alcance | Autorizacion server-authoritative sin logout ni reinicio | IMPLEMENTADO_LOCALMENTE | Revision de autorizacion 0050, guardas, refresco Web/Android y tests/build | Sesiones simultaneas reales en STAGING |
| Roles y alcance | Supervisor multi-sucursal y por departamentos | IMPLEMENTADO_LOCALMENTE | Migracion 0046, politicas Android/Web y test de alcance | RLS y usuarios reales en STAGING |
| Roles y alcance | Aislamiento multiempresa | BLOQUEADO_STAGING | Filtros por empresa, RLS y SECURITY DEFINER revisados estaticamente | Pruebas cruzadas con identidades de empresas distintas |
| Empresa | Ciclo de vida de empresa | PARCIAL | Dominio y pantallas existentes | Persistencia remota y reglas de inactivacion E2E |
| Empresa | Ciclo de vida de sucursales | PARCIAL | DAO, repositorio, ViewModel y UI | Persistencia remota y dependencias activas |
| Empresa | Ciclo de vida de departamentos | PARCIAL | DAO, repositorio, ViewModel y UI | Persistencia remota y dependencias activas |
| RRHH | Codigo aleatorio unico de empleado | IMPLEMENTADO_LOCALMENTE | Migracion 0047, politica Android y test Web/Android | Concurrencia real en STAGING |
| RRHH | Ficha integral de empleado | PARCIAL | Repositorios Android y modulo Web | Flujo completo, adjuntos y RLS E2E |
| RRHH | EMPLEADO EN LISTA NEGRA mensual y no bloqueante | IMPLEMENTADO_LOCALMENTE | Migracion 0050, refresco/reporte y politica P0 | Datos mensuales e impresion en STAGING; nunca bloquea marcaciones |
| Licencias | Licencia directa sin aprobar/rechazar | IMPLEMENTADO_LOCALMENTE | Versionado 0050, RPC, RLS, Android/Web y tests P0 | Nomina y bloqueo de marcacion E2E en STAGING |
| Licencias | Calculo de licencia por dias calendario y salario / 30 | IMPLEMENTADO_LOCALMENTE | Dias versionados, porcentaje 0-100 y regeneracion por salario | Casos de nomina con datos reales |
| Licencias | Edicion hacia adelante y cancelacion auditable | IMPLEMENTADO_LOCALMENTE | RPC de editar/cancelar y estados ACTIVE/CANCELLED | Concurrencia y auditoria en STAGING |
| Vacaciones | Vacaciones y saldo disponible | PARCIAL | DAO, repositorio y politica local | Transaccion remota y RLS integral |
| Prestamos | Prestamo, saldo, cuotas y abonos | PARCIAL | DAO, repositorio y motor de descuentos | Concurrencia de abonos y ledger remoto |
| Asistencia | Cronologia de jornadas | IMPLEMENTADO_LOCALMENTE | Migracion 0048, contrato Android, Edge y prueba SQL portable | pgTAP contra PostgreSQL |
| Asistencia | Idempotencia de eventos | IMPLEMENTADO_LOCALMENTE | Idempotency keys, worker y guardas Edge/SQL | Dos terminales reales |
| Asistencia | Registro y sincronizacion offline | BLOQUEADO_HARDWARE | Room, WorkManager y clientes de sincronizacion | Desconexion y recuperacion en terminal fisico |
| Asistencia | NO PAGAR con intervalos demostrables | IMPLEMENTADO_LOCALMENTE | Resolucion auditable 0050, Android/Web y politica P0 | Jornadas reales y nomina abierta/cerrada en STAGING |
| Asistencia | Horas manuales 0-8 solo cuando existe unicamente INICIAR | IMPLEMENTADO_LOCALMENTE | Restricciones SQL y UI/politica P0 | Prueba transaccional en PostgreSQL |
| Dispositivos | Enrolamiento y revocacion | IMPLEMENTADO_LOCALMENTE | P-256, credenciales, expiracion y device-enrollment | Enrolamiento real en STAGING/hardware |
| Dispositivos | Terminal GENERAL para empleados activos de toda la empresa | IMPLEMENTADO_LOCALMENTE | 0050, Edge sync/enrollment/attendance, Web y politica P0 | E2E en terminal; la sucursal solo es ubicacion de la marcacion |
| Dispositivos | Terminal DEPARTMENTS con uno o mas departamentos activos | IMPLEMENTADO_LOCALMENTE | 0050, configuracion Web, revision/cursor y elegibilidad server-authoritative | E2E y rechazo literal en terminal fisico |
| Dispositivos | Reconocimiento facial | BLOQUEADO_HARDWARE | UI, sincronizacion y compilacion Android | Camara, modelo y condiciones reales |
| Dispositivos | Lector TwoConnect | BLOQUEADO_HARDWARE | Integracion compila y correcciones aprobadas preservadas | Lector fisico autorizado |
| Dispositivos | Salida segura de quiosco | BLOQUEADO_HARDWARE | KioskManager, coordinador y tests locales | Lock task y politicas del telefono |
| Nomina | Tarifa hora salario mensual / 30 / 8 | IMPLEMENTADO_LOCALMENTE | PayrollMoneyPolicy y motor general | Comparacion con nomina real |
| Nomina | Redondeo monetario y neto no negativo | IMPLEMENTADO_LOCALMENTE | Politica monetaria y tests Android | Casos contables reales |
| Nomina | Deduccion de prestamos limitada por saldo/neto | PARCIAL | Motor y repositorio existentes | Ledger y concurrencia en STAGING |
| Nomina | AJUSTES ANTERIORES idempotentes en la siguiente nomina | IMPLEMENTADO_LOCALMENTE | Captura 0050, wrapper de nomina, detalle y Web | Periodos cerrados/abiertos reales en STAGING |
| Nomina | Libro mayor, pagos y cierre | PARCIAL | Motor, exportes y pantallas existentes | Transacciones remotas y conciliacion |
| Portal | Portal derivado de la sesion | PARCIAL | Contexto de autenticacion, rutas y servicios | RLS y datos reales |
| Reportes | Reportes por alcance | PARCIAL | Paginas, filtros y exportes | Revision visual y datos STAGING |
| Reportes | Neutralizacion de formulas en hojas | IMPLEMENTADO_LOCALMENTE | Politicas Android/Web y tests de exportacion | Apertura manual en Excel/LibreOffice |
| Mensajes | Permiso, menu y envio dirigido | IMPLEMENTADO_LOCALMENTE | Migracion 0049, navegacion y pagina Web | RLS/Storage en STAGING |
| Mensajes | Un pendiente por empleado | IMPLEMENTADO_LOCALMENTE | Restricciones 0049 y prueba SQL preparada | pgTAP en PostgreSQL |
| Mensajes | Texto, voz del sistema y audio de hasta 30 s | BLOQUEADO_HARDWARE | UI, cifrado local, Storage privado y reproductor | TTS, microfono y audio real |
| Mensajes | Entrega despues de una marcacion exitosa | IMPLEMENTADO_LOCALMENTE | Attendance sync, JourneyViewModel e inbox | E2E en STAGING/hardware |
| Mensajes | Primera recepcion gana e idempotencia multi-terminal | IMPLEMENTADO_LOCALMENTE | RPC/receipt, tombstones y cola local | Dos terminales reales |
| Mensajes | Precarga offline cifrada | IMPLEMENTADO_LOCALMENTE | Employee sync, audio precargado, AES-GCM e inbox | Desconexion real, audio y multi-terminal |
| Auditoria | Auditoria de mensajes sin contenido | IMPLEMENTADO_LOCALMENTE | Esquema 0049, tombstones y logs minimizados | Consulta remota en STAGING |
| Auditoria | Auditoria P0 de licencias, NO PAGAR y ajustes | IMPLEMENTADO_LOCALMENTE | Tablas/RPC 0050 y metadatos de actor/motivo | Evidencia transaccional en STAGING |
| Sesiones | Revocacion y refresco de autorizacion | IMPLEMENTADO_LOCALMENTE | Revision 0050, AuthContext y SessionCoordinator | E2E multiusuario |
| Seguridad | Logs sin secretos, embeddings ni contenido | IMPLEMENTADO_LOCALMENTE | Revision estatica Android/Edge y errores publicos normalizados | Revision operativa en STAGING |
| Seguridad | Configuracion activa solo de STAGING | IMPLEMENTADO_LOCALMENTE | APK staging verificado; referencia de produccion ausente | Repetir antes de cualquier despliegue |
| Base de datos | Migraciones 0045 a 0050 | BLOQUEADO_STAGING | SQL y pruebas locales presentes en orden | No aplicadas a STAGING; pgTAP 0050 no ejecutado |
