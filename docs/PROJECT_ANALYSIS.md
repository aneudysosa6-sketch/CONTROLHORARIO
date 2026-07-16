# Análisis integral del proyecto CONTROLHORARIO

Fecha de auditoría: 2026-07-16  
Alcance: inspección estática de Android, Web, Supabase, scripts y documentación. No se ejecutaron migraciones, pruebas, builds ni despliegues. No se modificó código funcional.

## Fuente y criterio

La fuente oficial usada para evaluar el objetivo es `docs/00_LEER_PRIMERO.md` y los documentos oficiales superiores `01` a `13`: Android + Web + Supabase, sincronización offline, lector 2Connect, un rol por usuario, auditoría centralizada y los módulos oficiales definidos allí. El subdirectorio `docs/_legacy` fue leído por completitud, pero se clasifica como histórico por su propio nombre y no se usa para contradecir la documentación oficial vigente.

## 1. Inventario completo de módulos Android

Proyecto Gradle de un solo módulo `:app`; Kotlin, Jetpack Compose, Navigation Compose, Room, WorkManager, Biometric y librería 2Connect (`fplib-reader-v3.jar`). Room está en versión 31.

| Dominio | Implementación localizada |
|---|---|
| Acceso, sesión y roles | `auth`, `session`, `ui/login`; login Supabase y sesión/local de usuario |
| Inicio y dashboard | `ui/home`, `dashboard`, `AndroidDashboard` |
| Empleados | alta, edición, lista, perfil, expediente, documentos, historial de asistencia y ficha/historial de nómina |
| Organización | empresa, sucursales, departamentos, cargos, horarios y calendario laboral |
| Asistencia y jornadas | ponche, kiosco, PIN/huella, máquina de estados, incidencias, revisión y outbox/sincronización |
| Biometría | registro de huella, `EmployeeBiometricEntity`, seguridad y adaptador externo `TwoConnectFingerprintManager` |
| Dispositivos | enrolamiento, identidad Keystore, sincronización de empleados, Worker/Scheduler y panel de sincronización |
| Supervisión | login, administración, panel, jornadas, eventos, permisos, asignaciones y horarios |
| Administración | panel y secciones Empresa, Sucursales, Departamentos, Cargos, Usuarios, Horarios, Jornadas, Dispositivos, Seguridad y Apariencia |
| Nómina | configuración, cálculo local, validación, PDF/exportación, historial y nómina general |
| Préstamos | entidad, repositorio, ViewModel y pantalla de solicitudes/gestión local |
| Portal empleado | `EmployeeSelfServiceScreen` con perfil/ganancias/préstamos y API RPC; existe además una implementación heredada embebida en navegación |
| Vacaciones y permisos | solicitudes de vacaciones y permisos de empleado |
| Reportes y eventos | pantalla de reportes, `AppEvent` y `SupervisorEvent`; centro de incidencias |
| Componentes y navegación | sistema visual OSINET y `AppNavigation.kt` |

Persistencia Room inventariada: `app_users`, `app_events`, `attendance_records`, `branches`, `company_settings`, `departments`, `device_enrollment`, `employee_biometrics`, `employee_documents`, `employee_payroll_settings`, `employee_permission_requests`, `journeys`, `journey_outbox`, `journey_conflicts`, `labor_calendar_days`, `loans`, `medical_license_daily_payments`, `payroll_history`, `payroll_settings`, revisiones de asistencia, supervisores/asignaciones/permisos/eventos/horarios, `vacations` y plantillas de horario.

## 2. Inventario completo de módulos Web

Aplicación React + Vite + TypeScript. Usa Supabase JS, React Router, jsPDF, XLSX y CSS propio.

| Módulo | Páginas/servicios principales |
|---|---|
| Autenticación y bootstrap | `AuthPages`, `LoginPage`, `BootstrapGate`, `BootstrapPage`, `authService` |
| Dashboard | `DashboardPage`, `Rc2DashboardPage`, `dashboardService`, diagnósticos |
| Empleados | lista, ficha y formulario; servicio, política de código y ficha de pago |
| Jornadas | `JourneyPages`, contrato de asistencia y `journeyService` |
| Supervisores | `SupervisorPages`, `supervisorService` |
| Nómina | `PayrollPage`, servicio y exportaciones XLSX/PDF |
| Administración | `SystemAdministrationPage`, `administrationService` |
| Dispositivos | `DevicesPage`, `deviceService` |
| Portal empleado y préstamos | `EmployeePortalPage`, `LoanRequestsPage`, `employeePortalService` |
| Aprovisionamiento | `UserProvisioningPage`, `userProvisioningService` |
| Operaciones heredadas | `OperationsPages`, `data/mockData.ts`, `services/storage.ts` |
| Infraestructura transversal | cliente Supabase, contexto de autenticación, layouts Admin/Empleado, navegación y componentes UI |

## 3. Inventario de tablas Supabase

Inventario derivado de `supabase/migrations` actual (no del estado desplegado):

| Migración | Tablas creadas o introducidas |
|---|---|
| 0001 | `companies`, `branches`, `departments`, `positions`, `profiles`, `roles` |
| 0002 | `empleados`, `permisos`, `rol_permisos`, `perfil_permisos`, `perfil_sucursales`, `perfil_departamentos` |
| 0003 | `user_provisioning_audit` |
| 0005 | `empleado_biometrias`, `empleado_biometria_auditoria` |
| 0006 | `dispositivos_android`, `codigos_enrolamiento_dispositivo`, `credenciales_dispositivo`, `dispositivo_auditoria` |
| 0008 | `jornadas`, `jornada_eventos`, `jornada_incidencias`, `jornada_conflictos`, `jornada_auditoria` |
| 0009 | `horarios_empleados`, `notificaciones_internas`, `supervisor_auditoria` |
| 0010 | `nomina_periodos`, `nominas`, `nomina_detalles`, `nomina_reglas`, `nomina_reglas_empleado`, `nomina_ajustes`, `nomina_prestamos`, `nomina_creditos`, `nomina_descuentos`, `nomina_archivos`, `nomina_auditoria` |
| 0011 | `administracion_auditoria` |
| 0013 | `prestamo_solicitudes`, `prestamo_movimientos`, `prestamo_solicitud_auditoria` |

Las migraciones 0004, 0007 y 0012 amplían permisos, columnas, relaciones o lógica existente; no crean tablas con `CREATE TABLE`. No se puede confirmar desde el repositorio cuáles de estas tablas existen en la instancia remota.

## 4. Inventario de migraciones

| Archivo | Propósito |
|---|---|
| `0001_FINAL.sql` | núcleo multiempresa, organización, perfiles, roles y RLS inicial |
| `0002_FINAL.sql` | empleados, permisos, alcances y autorización granular |
| `0003_FINAL.sql` | auditoría y aprovisionamiento de usuarios |
| `0004_admin_employee_permissions.sql` | corrección idempotente de permisos de empleados para administradores |
| `0005_employee_biometrics_foundation.sql` | base de metadatos/cifrado biométrico y auditoría |
| `0006_android_device_enrollment.sql` | enrolamiento, credenciales y auditoría de dispositivo |
| `0007_employee_supervisor_sync.sql` | relación opcional empleado-supervisor para sincronización |
| `0008_rc2_attendance_engine.sql` | motor de jornadas, eventos, conflictos, incidencias y sincronización |
| `0009_rc3_supervisor_scoped_operations.sql` | alcance del supervisor, horarios y notificaciones internas |
| `0010_rc4_payroll_engine.sql` | motor de nómina multiempresa, períodos, reglas, préstamos/créditos y auditoría |
| `0011_rc35_system_administration.sql` | administración del sistema, permisos y auditoría |
| `0012_rc4_employee_pay_alignment.sql` | alineación de ficha salarial con cálculo RC4 |
| `0013_employee_portal_loans.sql` | portal de empleado y ciclo de solicitudes/movimientos de préstamo |

Existen tres migraciones en `migrations_archivadas/`; no pertenecen a la cadena vigente y no deben aplicarse junto con la actual.

## 5. Inventario de Edge Functions

| Función | Responsabilidad observada |
|---|---|
| `user-provisioning` | bootstrap, listado, creación, invitación y aprovisionamiento de usuarios Auth/perfiles |
| `employee-management` | alta/edición y activación/desactivación de empleados; valida permisos y PIN con hash BCrypt |
| `device-enrollment` | canje de código, listado, generación de código y revocación de dispositivos |
| `employee-sync` | descarga paginada de empleados para un dispositivo autenticado |
| `attendance-sync` | recepción en lote de eventos offline de jornada, idempotencia y resultados por operación |

`config.toml` declara `verify_jwt = false` para las tres funciones de dispositivo/sincronización, porque implementan autenticación propia. La validación de credencial y alcance debe mantenerse dentro de los handlers; es un punto de seguridad de alta criticidad.

## 6. Inventario de RPC y funciones SQL

Funciones de soporte/autorización: `set_updated_at`, `normalizar_empleado`, `obtener_empresa_actual`, `obtener_rol_actual`, `obtener_empleado_actual_id`, `es_empleado_actual`, `tiene_permiso`, `bootstrap_tenant_internal`, `provision_user_internal`, `listar_estados_biometricos_empleados`, `enroll_android_device_internal`.

Jornadas y supervisor: `registrar_evento_jornada_dispositivo`, `cerrar_jornadas_incompletas`, `cerrar_jornadas_vencidas`, `establecer_jornada_habilitada`, `evaluar_tardanza_jornada`, `marcar_incidencia_jornada_leida`, `resolver_jornada_pendiente`, `puede_ver_jornada`, `es_supervisor_actual`, `supervisor_puede_ver_empleado`, `puede_operar_empleado_rc3`, `validar_alcance_supervisor`, `validar_cambio_sucursal_supervisor`, `proteger_sucursal_asignada_supervisor`, `auditar_asignacion_supervisor`, `dashboard_supervisor`, `listar_empleados_supervisor`, `listar_horarios_supervisor`, `listar_jornadas_supervisor`, `listar_incidencias_supervisor`, `guardar_horario_supervisor`, `registrar_jornada_manual_supervisor`, `corregir_jornada_supervisor`, `resolver_incidencia_supervisor`.

Nómina: `nomina_empresa_autorizada`, `listar_empleados_nomina`, `listar_nomina_periodos`, `crear_periodo_nomina`, `obtener_reglas_nomina`, `configurar_regla_nomina`, `calcular_nomina`, `obtener_nomina`, `cambiar_estado_nomina`, `marcar_nomina_desactualizada`, `aplicar_descuentos_nomina`, `crear_prestamo_nomina`, `cambiar_estado_prestamo_nomina`, `crear_credito_nomina`, `cancelar_credito_nomina`, `registrar_exportacion_nomina`, `guardar_ficha_pago_empleado`, `obtener_ficha_pago_empleado`.

Administración: `administracion_autorizada`, `obtener_administracion_sistema`, `actualizar_empresa_administracion`, `actualizar_apariencia_administracion`, `guardar_sucursal_administracion`, `guardar_departamento_administracion`, `guardar_cargo_administracion`, `guardar_rol_administracion`, `asignar_permiso_rol_administracion`, `actualizar_rol_usuario_administracion`, `actualizar_estado_usuario_administracion`.

Portal/préstamos: `obtener_portal_empleado`, `crear_solicitud_prestamo`, `cancelar_solicitud_prestamo`, `listar_solicitudes_prestamo_admin`, `gestionar_solicitud_prestamo`, `registrar_movimiento_descuento_prestamo`.

`calcular_nomina`, `establecer_jornada_habilitada`, `puede_ver_jornada` y `resolver_jornada_pendiente` se redefinen en migraciones posteriores: el estado efectivo depende de aplicar la cadena completa en orden.

## 7. Inventario de RLS

RLS está habilitado en las tablas de organización/identidad (0001), empleados/permisos/alcances (0002), auditoría de aprovisionamiento (0003), biometría (0005), dispositivos (0006), jornadas (0008), supervisor (0009), auditoría administrativa (0011) y préstamos (0013). Las tablas RC4 de nómina reciben políticas dinámicamente en 0010 para lectura autorizada por empresa y `nomina.ver`.

Políticas explícitas principales:

- Organización: selección por empresa propia; gestión de sucursales, departamentos, cargos, perfiles y roles para administradores/permiso correspondiente.
- Empleados y permisos: lectura por alcance, alta/edición autorizada y gestión de perfiles, roles, sucursales y departamentos.
- Jornadas: lectura limitada por empresa y `puede_ver_jornada` para jornadas, eventos, incidencias, auditoría y conflictos.
- Supervisor: reemplaza/refuerza lectura de empleados y limita horarios, notificaciones y auditoría al alcance del supervisor.
- Nómina: políticas generadas por tabla, limitadas a empresa actual y permiso `nomina.ver`.
- Administración: lectura de auditoría y políticas de gestión por permisos de configuración.
- Préstamos: lectura de solicitudes y movimientos limitada al empleado propio o a permisos administrativos.

No se observan políticas directas de cliente para todas las tablas sensibles de biometría y dispositivo; su acceso esperado es mediante funciones/RPC de servidor. Antes de desplegar debe probarse denegación explícita para `anon`, `authenticated`, otro tenant y usuario inactivo.

## 8. Inventario de scripts

Hay 18 scripts PowerShell de validación estática: `verify_critical_flows`; autorización Web y empleados; login/dashboard; dashboard real; biometría; enrolamiento y sincronización de empleados/dispositivo Android; RC2 asistencia; RC3 supervisor; RC3.5 administración; RC4 nómina, navegación y ficha salarial; portal/préstamos; y aprovisionamiento. También existe `web/scripts/test-rc4-exports.mjs`.

Los scripts verifican principalmente presencia de contratos y patrones de texto. No sustituyen pruebas de migración, RLS real, Edge Functions desplegadas, lector 2Connect, WorkManager ni pruebas end-to-end.

## 9. Dependencias entre Android, Web y Supabase

```text
Android (Room + 2Connect + WorkManager)
  ├─ Auth/REST RPC ────────────────────────────────┐
  ├─ device-enrollment / employee-sync Edge Fn ────┼─> Supabase Auth + tablas + RLS + RPC
  └─ attendance-sync Edge Fn / outbox ─────────────┘

Web (Supabase JS)
  ├─ Auth, tablas con RLS y RPC ────────────────────> Supabase
  └─ device-enrollment / employee-management /
     user-provisioning Edge Functions ─────────────> Supabase service-side
```

- Android conserva operación offline en Room; requiere dispositivo enrolado, empleados sincronizados, identidad remota y la Edge Function de asistencia para converger con Supabase.
- Web es la consola conectada: consume Auth, tablas protegidas por RLS, RPC y funciones de gestión.
- Supabase concentra usuarios, empresa, permisos, jornadas remotas, nómina, auditoría, préstamos y dispositivos. Las migraciones y funciones deben desplegarse como unidad compatible antes de habilitar flujos conectados.
- PIN + huella 2Connect es responsabilidad de Android. Web solo debe manejar estado/administración, nunca plantillas.

## 10. Código duplicado

1. **Portal empleado Android:** `EmployeeSelfServiceScreen` + `EmployeePortalApi` usa RPC real, mientras `AppNavigation.kt` contiene otro `EmployeePortalScreen` que modela préstamos/historial en estado local. Es una duplicación funcional con resultados distintos.
2. **Nómina:** Android mantiene motores, entidades, pantallas e historial locales; Web usa RPC del motor SQL RC4. La doble lógica de cálculo exige una decisión de fuente de verdad y pruebas de paridad antes de cualquier eliminación.
3. **Sincronización de empleado/dispositivo:** existe `employee-sync` independiente y una rama `employee-sync` dentro de `device-enrollment`. Debe consolidarse o documentarse claramente el contrato de cada endpoint.
4. **Autorización/RPC Web:** varios servicios repiten wrappers de llamada y manejo de error. No es un error funcional, pero aumenta divergencia de mensajes y telemetría.

No se encontraron archivos Kotlin/TypeScript/TSX idénticos por hash.

## 11. Código muerto

- `web/src/services/storage.ts` no tiene importaciones desde `web/src`; usa `mockData` y es candidato a código muerto.
- `AppNavigation.kt` define `ModuleScreen`; no se encontró uso fuera de su definición, por lo que es candidato a eliminación tras una comprobación de compilación.
- `web/vite.config.js`, `web/vite.config.d.ts`, `web/tsconfig.app.tsbuildinfo` y `web/tsconfig.node.tsbuildinfo` parecen productos generados junto al origen TypeScript. Deben excluirse del código mantenido si no están deliberadamente versionados.

No se elimina ninguno de estos elementos en esta auditoría.

## 12. Código obsoleto

- `docs/_legacy/`, `supabase/migrations_archivadas/`, `app/*_DOCS/`, `rc3` y `REPARACION_REALIZADA.txt` son material histórico o de entrega, no módulos de producción.
- `web/src/data/mockData.ts` y `OperationsPages.tsx` conservan una ruta con datos simulados; contradice la dirección de datos reales de los módulos principales y debe aislarse o retirarse sólo cuando se confirme que no forma parte de un flujo soportado.
- Las configuraciones Vite JavaScript/declaración y los `*.tsbuildinfo` descritos arriba son candidatos obsoletos frente a `vite.config.ts` y la configuración TypeScript actual.

## 13. Módulos incompletos

| Módulo oficial | Evidencia estática de brecha |
|---|---|
| Biometría 2Connect | existe integración Android local, pero faltan pruebas físicas obligatorias y la sincronización segura completa de plantillas no está demostrada |
| Offline/jornadas | existe outbox/Worker y Edge Function, pero falta validación integrada contra infraestructura y resolución real de conflictos |
| Nómina | RC4 Web/Supabase está versionado; Android conserva un motor local distinto y no hay evidencia de paridad ni despliegue |
| Portal empleado | Web y nueva pantalla Android usan RPC, pero subsiste portal local duplicado y no hay prueba de extremo a extremo |
| Préstamos | ciclo Supabase existe desde 0013, mientras Android local y portal embebido no están alineados |
| Reportes | existe pantalla Android y referencia documental, pero no se observa un módulo Web/Supabase equivalente completo de reportes operativos |
| Eventos | hay entidades y notificaciones/supervisión, pero falta la demostración de un único centro transversal entre clientes |
| Administración | Web está conectada; Android es una UI/cliente adicional y necesita pruebas reales de permisos, alcance y consistencia |

## 14. Funcionalidades pendientes

1. Aplicación controlada de la cadena de migraciones y validación contra una instancia no productiva.
2. Pruebas RLS multiempresa, usuario inactivo, permisos mínimos y denegación de tablas sensibles.
3. Despliegue controlado y pruebas de las cinco Edge Functions.
4. Pruebas reales de hardware 2Connect, USB, caída/reconexión, PIN, huella y kiosco.
5. Paridad formal de cálculo de nómina Android/Supabase, con casos dorados y decisión explícita de autoridad.
6. Consolidación del portal Android y del contrato de préstamo.
7. Pruebas end-to-end de enrolamiento, descarga de empleados, outbox de jornada, idempotencia y conflicto.
8. Implementación/confirmación de reportes reales y auditoría transversal consultable.
9. Revisión de gestión de secretos/configuración y flujo de despliegue reproducible.

## 15. Riesgos técnicos

| Prioridad | Riesgo | Impacto |
|---|---|---|
| Crítica | Cadena de migraciones versionada sin evidencia de estado remoto | Web/Android pueden llamar RPC/tablas inexistentes o con versiones diferentes |
| Crítica | Dos fuentes de cálculo de nómina | pagos divergentes y pérdida de trazabilidad |
| Alta | Endpoint con `verify_jwt=false` | un fallo en validación propia expone operaciones de dispositivo/sincronización |
| Alta | PIN/biometría local y sincronización parcial | riesgo de seguridad, inconsistencia offline y dependencia de hardware no validado |
| Alta | RLS no probada en infraestructura | posible fuga interempresa o bloqueo funcional |
| Alta | `AppNavigation.kt` concentra navegación y pantallas | alto acoplamiento, revisiones difíciles y regresiones |
| Media | Portal y préstamos duplicados | experiencias incoherentes y datos que no convergen |
| Media | Dependencias Web en `latest` | builds no reproducibles y cambios inesperados |
| Media | Artefactos/Mocks heredados versionados | rutas accidentalmente demostrativas o uso de datos falsos |
| Media | Scripts mayormente estáticos | falsa sensación de cobertura sin validar servicio, RLS ni hardware |

## 16. Plan de reorganización priorizado

### P0 — Baseline y seguridad

1. Declarar un manifiesto de versiones/despliegue de Supabase y comprobar la cadena 0001–0013 desde cero en entorno aislado.
2. Ejecutar matriz RLS y contratos de RPC/Edge Functions; bloquear el avance si falla aislamiento de tenant, permisos o dispositivo revocado.
3. Establecer contratos versionados compartidos para Auth, empleado, jornada, préstamo y nómina; no cambiar clientes antes de fijarlos.

### P1 — Convergencia de dominio

4. Decidir y documentar la fuente de verdad de nómina; conservar el otro motor solo como compatibilidad hasta probar paridad centavo a centavo.
5. Consolidar portal de empleado Android en la implementación RPC y retirar la alternativa sólo después de pruebas funcionales.
6. Separar `AppNavigation.kt` por dominios sin cambiar rutas existentes; mover pantallas locales embebidas a módulos propios.
7. Unificar el contrato `employee-sync`/`device-enrollment` y formalizar idempotencia, cursor, ACK y errores.

### P2 — Calidad y mantenimiento

8. Sustituir wrappers RPC repetidos por infraestructura común en Web con errores tipados y observabilidad.
9. Aislar/eliminar artefactos generados, mocks y documentos de entrega después de comprobar referencias y build.
10. Añadir pruebas de integración reales: SQL/RLS, Edge Functions, Android offline y flujos Web, más matriz física del 2Connect.
11. Completar reportes y centro de eventos como capacidades conectadas y auditables, según los módulos oficiales.

## Conclusión

El repositorio sí contiene los cuatro pilares requeridos —Android, Web, Supabase y documentación— y una base funcional extensa. El principal trabajo no es añadir otro cliente, sino hacer converger las implementaciones locales y remotas, validar la infraestructura y retirar rutas heredadas una vez haya paridad verificable.
