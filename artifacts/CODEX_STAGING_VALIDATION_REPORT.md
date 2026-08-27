# CODEX STAGING VALIDATION REPORT

Fecha: 2026-08-24
Rama: `feature/production-readiness`
Proyecto autorizado: STAGING `[STAGING_PROJECT_REF]`
Proyecto prohibido: PRODUCCION `[PRODUCTION_PROJECT_REF]`

## 1. Resultado ejecutivo

La integracion real de CONTROL HORARIO contra STAGING quedo validada local y remotamente. El historial de migraciones esta reconciliado hasta `0053`; los contratos pgTAP, RLS, RPC, terminales, autorizacion inmediata, mensajes, licencias, NO PAGO, ajustes de periodos anteriores y blacklist pasan. Las seis Edge Functions objetivo estan activas en STAGING y rechazan solicitudes anonimas.

No se ejecuto ninguna operacion contra PRODUCCION. No se hizo `push`, no se instalo APK y no se realizaron operaciones destructivas sobre telefonos.

Persisten dos validaciones externas: smoke HTTP positivo de Edge/Web con una sesion autenticada real, por ausencia de credenciales de usuario de prueba, y validacion fisica de hardware facial. Ninguna impidio completar las validaciones de base de datos, RLS, RPC y contratos locales.

## 2. Guardas y alcance remoto

- `supabase/.temp/project-ref` fue comprobado antes de cada operacion remota.
- La referencia confirmada fue siempre `[STAGING_PROJECT_REF]`.
- La referencia `[PRODUCTION_PROJECT_REF]` fue tratada como prohibida.
- `web/.env.local` contiene una URL de STAGING real y una clave publicable no placeholder.
- No se imprimieron claves, tokens, contrasenas ni contenido de dumps.
- No se usaron `example.com` ni `sb_publishable_dummy` como evidencia.

## 3. Backup previo

Resultado: PASS.

Se genero un backup logico de esquema y datos de `public` antes de aplicar las migraciones pendientes. Los archivos quedaron fuera del repositorio, en un directorio temporal con ACL restringida:

<LOCAL_PATH_REDACTED>

- Schema SHA-256: `[OPERATIONAL_SHA256_REDACTED]`
- Data SHA-256: `[OPERATIONAL_SHA256_REDACTED]`
- Advertencia no bloqueante de `pg_dump`: dependencias circulares entre `empleados`, `empleado_ciclo_laboral_auditoria` y `nomina_suspensiones_laborales`. Una restauracion de datos debe deshabilitar triggers temporalmente o usar ordenamiento controlado.

## 4. Migraciones

Resultado: PASS.

Estado inicial:

- `0001` a `0045`: local y remoto reconciliados.
- Dry-run inicial: solo `0046` a `0050` pendientes.
- `0046` a `0050`: aplicadas correctamente a STAGING.

Remediaciones derivadas de la validacion:

- `0051_kiosk_exit_role_hardening.sql`: retira `kiosk.pin_mode_exit` de los roles canonicos SUPERVISOR y EMPLEADO.
- `0052_security_definer_acl_hardening.sql`: retira ejecucion publica/cliente de ocho funciones internas `SECURITY DEFINER` y corrige `nomina_distribuir_descuentos_v3` de `IMMUTABLE` a `STABLE`.
- `0053_license_idempotency_no_pay_cap.sql`: resuelve replays de licencias antes del control de solapamiento y limita toda ruta de NO PAGO a ocho horas pagables.

El dry-run de `0053` mostro exclusivamente esa migracion. La lista final de la CLI confirmo `local=0053` y `remote=0053`.

## 5. Reconstruccion y diff

- La reconstruccion shadow requirio retirar temporalmente, solo en una copia segura, el BOM UTF-8 de la migracion historica aplicada `0041_restore_kiosk_exit_permission.sql`.
- La migracion aplicada original no fue editada.
- El diff obtenido fue vacio, SHA-256 `[OPERATIONAL_SHA256_REDACTED]`.
- Las remediaciones posteriores quedaron reconciliadas mediante historial remoto, lint y contratos funcionales.

## 6. pgTAP y contratos funcionales

Resultado: PASS.

- Barrido completo: 33 archivos y 1,056 aserciones ejecutadas sin fallos de asercion.
- Tres archivos no pudieron abrir una conexion nueva durante el barrido paralelo por rechazo transitorio de STAGING.
- `0054_staging_payroll_p0_integration.sql`: reejecutado aisladamente, 52 pruebas, PASS.
- `architecture_contracts.sql`: reejecutado aisladamente, 1 prueba, PASS.
- `jornadas_p1_contracts.sql`: reejecutado aisladamente, 10 pruebas, PASS.
- Cobertura unica efectiva: 1,119 aserciones aprobadas.
- `0024` y `0025`: SKIP explicito porque sus contratos fueron sustituidos por `0047_random_employee_codes.sql`, que paso.

Contratos destacados:

- RLS multiempresa y alcance de supervisor: 21 pruebas, PASS.
- RPC de seguridad: 16 pruebas, PASS.
- Terminal, autorizacion inmediata y mensajes: 31 pruebas, PASS.
- Licencias, NO PAGO, ajustes anteriores y blacklist: 52 pruebas, PASS.
- Hardening de salida kiosk: PASS.
- ACL `SECURITY DEFINER`: PASS.

## 7. Terminales y autorizacion inmediata

Resultado: PASS en contratos STAGING.

Se valido:

- Terminal GENERAL para empleados activos de la misma empresa en multiples sucursales.
- Rechazo de otra empresa e inactivos.
- Conservacion de la sucursal fisica del terminal.
- Terminal DEPARTMENTS con uno o varios departamentos.
- Rechazo de seleccion vacia y empleados fuera de alcance.
- Efecto inmediato de cambio de departamento y sucursal.
- Limpieza de departamentos al cambiar de sucursal.
- Incremento de `authorization_revision` al retirar/restaurar permisos.
- Rechazo inmediato de revision obsoleta y permiso revocado.
- Perdida inmediata de autorizacion al desactivar un perfil.

La validacion fisica de reconocimiento facial y marcaje en telefono permanece como siguiente fase de hardware.

## 8. Licencias

Resultado: PASS.

Se valido:

- Creacion directa e idempotencia.
- Tres dias calendario.
- Formula `salario / 30 * porcentaje`.
- Historial append-only y revision 2.
- Recalculo `HACIA_ADELANTE` sin modificar el primer dia.
- Cancelacion y eliminacion de dias pagables.
- Bloqueo inmediato del terminal durante licencia activa.
- Restauracion inmediata de elegibilidad al cancelar.

Defecto encontrado y corregido: un replay con la misma `idempotency_key` llegaba primero al control de solapamiento y devolvia `LICENSE_DATE_OVERLAP`.

## 9. NO PAGO

Resultado: PASS.

Se valido:

- Horas manuales entre 0 y 8.
- Rechazo de 8.01 horas manuales.
- Calculo desde ultimo evento `PAUSAR`.
- Calculo desde minutos acumulados despues de `REANUDAR`.
- Monto basado en `salario / 30 / 8`.
- Cero resoluciones persistidas con mas de ocho horas.

Defecto encontrado y corregido: las rutas calculadas almacenaban 10.50 y 10.00 horas, produciendo pago de horas extra dentro de NO PAGO.

## 10. Ajustes de periodos anteriores

Resultado: PASS.

Se valido:

- Detalle de nomina cerrada permanece congelado.
- Una correccion posterior crea exactamente un ajuste.
- Delta economico correcto.
- Estado inicial `PENDIENTE`.
- Aplicacion al siguiente periodo.
- Retry idempotente sin duplicar el monto.
- Estado `RESERVADO` antes del cierre.
- Estado `APLICADO` al cerrar el periodo receptor.

## 11. Blacklist mensual

Resultado: PASS.

Se validaron las cuatro categorias:

- `AUSENCIAS`: 6 eventos.
- `TARDANZA`: 6 eventos.
- `SIN FINALIZAR JORNADA`: 6 eventos.
- `MODIFICADOS`: 1 dia.

Tambien se valido el reporte individual, la persistencia y archivado al avanzar de mes, y que pertenecer a blacklist no bloquea la elegibilidad de asistencia.

## 12. Mensajes a empleados

Resultado: PASS.

Se valido:

- Preload GENERAL de mensajes para empleado de otra sucursal de la misma empresa.
- Ausencia de fuga entre empresas.
- Un solo mensaje pendiente por empleado.
- Primera confirmacion aceptada.
- Confirmaciones posteriores idempotentes como `duplicate`.
- Eliminacion del contenido pendiente y conservacion de un unico tombstone de recepcion.

## 13. RLS y SECURITY DEFINER

Resultado: PASS.

RLS cubre:

- Aislamiento de lectura y escritura entre empresas.
- Alcance por departamentos para supervisor.
- Acceso propio de empleado.
- Denegacion para perfiles inactivos.
- Ausencia de acceso cliente directo a tablas sensibles.

Se retiro ejecucion de `public`, `anon`, `authenticated` y `service_role` a estas funciones internas:

- `private.capture_prior_adjustment_0050()`
- `private.cleanup_terminal_departments_0050()`
- `private.complete_prior_adjustments_0050()`
- `private.salary_change_license_days_0050()`
- `public.calcular_ganancia_jornada(uuid)`
- `public.rls_auto_enable()`
- `public.trg_calcular_ganancia_jornada()`
- `public.trg_completar_evento_jornada_p1()`

## 14. Lint de base de datos

Resultado: PASS con advertencias no bloqueantes.

`supabase db lint --linked --schema public --level warning --fail-on error` termino con codigo 0 y sin errores.

Advertencias:

- `public.calcular_nomina`: variable `v_pending` no leida.
- `public.crear_solicitud_prestamo`: variable `v_id` no usada.

## 15. Edge Functions

Resultado de despliegue: PASS.

Funciones desplegadas exclusivamente a `[STAGING_PROJECT_REF]`, activas y sin `prune`:

- `user-provisioning`: version 11.
- `employee-management`: version 5.
- `device-enrollment`: version 3.
- `employee-sync`: version 3.
- `employee-upsert`: version 3.
- `attendance-sync`: version 2.

Smoke anonimo:

- `attendance-sync`: 401.
- `device-enrollment`: 401.
- `employee-management`: 401.
- `employee-sync`: 401.
- `employee-upsert`: 401.
- `user-provisioning`: 400 por payload/sesion ausente.
- Ninguna funcion devolvio 2xx anonimo ni 5xx.

Bloqueo externo: no existe en la configuracion local una cuenta/sesion autenticada de prueba ni credencial administrativa que permita ejecutar un smoke HTTP positivo sin crear o exponer secretos. Se completaron en su lugar los contratos DB/RPC y de autorizacion subyacentes.

## 16. Web contra STAGING

Resultado de conectividad/configuracion: PASS.

- Referencia STAGING presente.
- Referencia PRODUCCION ausente.
- Placeholders ausentes.
- `/auth/v1/settings`: HTTP 200.
- REST de `companies` con clave publicable y sin sesion: HTTP 401 esperado; lectura anonima denegada.

Bloqueo externo: smoke positivo de navegacion autenticada requiere credenciales de usuario de prueba no disponibles. No se modifico codigo Web durante esta fase, por lo que no se repitio una compilacion no afectada.

## 17. Android y dispositivos

- No se modifico codigo Android durante esta fase.
- `JAVA_HOME` usado para comandos aplicables: `C:\Program Files\Android\Android Studio\jbr`.
- No se instalo APK.
- No se ejecuto `pm clear`.
- No se desinstalo la aplicacion.
- No se uso `set-device-owner`.
- No se eliminaron usuarios ni cuentas.
- No se hizo factory reset.

## 18. Commits locales

- `af1dda6 test(database): stabilize remote pgtap harness`
- `28bcd9c fix(database): close staging authorization and payroll gaps`
- El informe se confirma en un commit documental separado.

No se realizo `push`.

## 19. Exclusiones intencionales preservadas

Estos archivos no forman parte de los commits de esta fase:

- `.idea/deploymentTargetSelector.xml`
- `artifacts/AppNavigation-diff.txt`
- `artifacts/POST_CODEX_GIT_REVIEW.txt`
- `artifacts/POST_P0_GIT_REVIEW.txt`

## 20. Pendientes reales

- Validacion fisica en hardware facial y telefonos.
- Smoke HTTP positivo Edge/Web con una sesion autenticada de prueba provista externamente.
- Ensayo de restauracion del backup en un entorno desechable, considerando FKs circulares.
- Limpieza opcional de las dos variables no usadas reportadas por lint.
- Normalizacion futura del BOM historico de `0041` solo mediante procedimiento compatible con migraciones ya aplicadas; no editar la migracion aplicada.

## 21. Estados finales

```text
STAGING_PROJECT_CONFIRMED: YES
PRODUCTION_TOUCHED: NO
STAGING_BACKUP: PASS
MIGRATION_DRY_RUN: PASS
MIGRATIONS_0045_0050: PASS
PGTAP: PASS
RLS_MULTI_TENANT: PASS
SECURITY_DEFINER_REVIEW: PASS
EDGE_DEPLOYMENT_STAGING: PASS
GENERAL_TERMINAL_STAGING: PASS
DEPARTMENT_TERMINAL_STAGING: PASS
IMMEDIATE_AUTHORIZATION_STAGING: PASS
LICENSES_STAGING: PASS
NO_PAY_STAGING: PASS
PRIOR_ADJUSTMENTS_STAGING: PASS
BLACKLIST_STAGING: PASS
MESSAGES_CONTRACT_STAGING: PASS
LOCAL_FIXES_REQUIRED: YES
ADDITIONAL_LOCAL_COMMITS: 3
PUSH_PERFORMED: NO
APK_INSTALLED: NO
DESTRUCTIVE_DEVICE_OPERATIONS: NO
HARDWARE_VALIDATION_REMAINING: YES
SAFE_TO_BEGIN_HARDWARE_VALIDATION: YES
```