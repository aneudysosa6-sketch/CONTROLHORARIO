# Modelo de datos completo

## Convenciones

- Nombres nuevos en español; se conservan `companies`, `profiles`, `roles`, `branches`, `departments` y `positions` porque `0001` ya fue aplicada.
- UUID, `empresa_id`, `created_at`, `updated_at` y, cuando aplique, `version bigint` para control optimista.
- Borrado lógico mediante `activo`, `estado` o `deleted_at`; históricos no se eliminan.
- Dinero: `numeric(14,2)` y moneda ISO. Nunca `double` en PostgreSQL.
- JSONB solo para snapshots, payloads externos y auditoría, no para sustituir relaciones.

## A. Empresa y organización

Existentes: `companies`, `branches`, `departments`, `positions`. Propuestas: `configuracion_empresa` (1:1), `feriados` (empresa/sucursal, fecha), `calendarios_laborales` y su relación con feriados. Las tablas existentes mantienen sus nombres reales; los alias españoles son conceptuales.

## B. Identidad y seguridad

`auth.users` 1:1 `profiles`; `profiles` contiene acceso, no expediente laboral. `roles`, `permisos`, `rol_permisos`, `perfil_permisos`, `perfil_sucursales`, `perfil_departamentos`. Futuras: `sesiones_dispositivos`, `dispositivos_autorizados`, `intentos_acceso`, `auditoria`, `eventos_seguridad`, `historial_permisos`.

Alcance efectivo: excepción de perfil > rol > denegar, con `propio/departamento/sucursal/empresa/global`. Las tablas de asignación múltiple amplían el departamento y sucursal principal del perfil.

## C. Empleados

`empleados` es la fuente laboral. `profiles.full_name/phone/avatar_url/employee_code` queda como snapshot de acceso legado hasta una migración de normalización; no debe editarse independientemente.

Tablas: `contactos_emergencia`, `documentos_empleado`, `cuentas_bancarias_empleado`, `historial_laboral`, `historial_salarial`, `asignaciones_empleado`, `datos_fiscales_empleado`. Cuentas, fiscalidad y salarios son acceso servidor/RRHH; valores bancarios deben cifrarse por campo o tokenizarse.

## D. Horarios y turnos

- `horarios`: plantilla, zona horaria, tolerancias, descanso y reglas extra.
- `horario_detalles`: día ISO, inicio, fin, `cruza_medianoche`, descanso.
- `empleado_horarios`: vigencia y prioridad.
- `turnos`, `rotaciones_turnos`, `excepciones_horario`, `calendario_empleado`.

La asignación vigente se resuelve por: excepción temporal > calendario generado > rotación > horario base. No se sobrescribe una asignación histórica.

## E. Asistencia

- `eventos_asistencia`: append-only, UUID cliente, tipo, método, origen, timestamps servidor/dispositivo, GPS, dispositivo e idempotency key.
- `jornadas`: agregado derivado/versionado por empleado y fecha laboral.
- `pausas`: intervalos derivados.
- `correcciones_asistencia` y `aprobaciones_correccion`: nunca reescriben el evento original.
- `incidencias_asistencia`, `ubicaciones_ponche`, `dispositivos_ponche`.

Tipos: `iniciar_jornada`, `iniciar_pausa`, `reanudar_jornada`, `finalizar_jornada`. Métodos: `pin`, `biometria`, `administrador`, `webauthn`, `manual`, `importacion`. Orígenes: `android`, `web`, `kiosco`, `administrador`, `importacion`, `sincronizacion_offline`.

## F. Solicitudes

`tipos_solicitud`, `solicitudes`, `aprobaciones_solicitud` (nivel, decisor, estado), `vacaciones`, `permisos_laborales`, `incapacidades`, `licencias`, `solicitudes_horas_extra`. Se usa `permisos_laborales` para no confundir con el catálogo de autorización `permisos` ya creado.

## G. Nómina

`periodos_nomina`, `conceptos_nomina`, `reglas_nomina`, `novedades_nomina`, `detalles_nomina`, `deducciones`, `ingresos_adicionales`, `horas_extra_nomina`, `exportaciones_nomina`, `plantillas_nomina`, `archivos_nomina`, `historial_procesamiento_nomina`.

Un período aprobado se vuelve inmutable. Reprocesar crea una versión. `detalles_nomina` guarda snapshots de salario, horas, conceptos, bruto y neto para reproducibilidad.

## H–J. Reportes, notificaciones y archivos

- Reportes: `reportes_guardados`, `configuraciones_reporte`, `exportaciones_reporte`, `trabajos_exportacion`.
- Notificaciones: `notificaciones`, `preferencias_notificacion`, `dispositivos_push`, `plantillas_notificacion`.
- Archivos: `categorias_archivo`, `archivos` (bucket, ruta, hash, MIME, tamaño, retención), `relaciones_archivo` (entidad/tipo/id). El binario vive en Storage.

## K. Sincronización

`cola_sincronizacion`, `conflictos_sincronizacion`, `dispositivos_sincronizacion`, `estados_sincronizacion`. Cada comando tiene UUID/idempotency key, entidad, operación, versión base, timestamp dispositivo, intentos, error y estado. El servidor conserva `server_updated_at`; Room conserva `last_synced_at`.

## L. Auditoría

`auditoria` append-only: empresa, actor, dispositivo, acción, entidad, entidad_id, before/after JSONB filtrado, IP, user-agent, origen y fecha. `cambios_sensibles`, `eventos_seguridad`, `historial_permisos` especializan eventos críticos.

## Borrado y retención

| Categoría | Política |
|---|---|
| Catálogos/empleados | Borrado lógico; anonimización controlada cuando legalmente proceda. |
| Asistencia/correcciones | Inmutables; retención mínima definida por legislación/empresa. |
| Nómina | Inmutable tras aprobación; mínimo 10 años recomendado, validación legal local pendiente. |
| Auditoría/seguridad | Append-only; 7 años recomendado, con particionado y archivo. |
| Archivos temporales | TTL por categoría; eliminación registrada. |
| Auth/sesiones | Revocables; eventos de seguridad permanecen. |

## Catálogos

Estados, tipos de evento, método, origen, conceptos, tipos de solicitud y clases de archivo deben ser CHECK/enum estable o tablas catálogo cuando sean configurables. Los textos libres no controlan lógica empresarial.
