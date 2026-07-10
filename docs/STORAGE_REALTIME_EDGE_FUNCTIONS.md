# Storage, Realtime y Edge Functions

## Buckets propuestos

Todos privados excepto logos publicados explícitamente. Ruta: `{empresa_id}/{entidad_id}/{uuid}.{ext}`; nunca usar nombre original como autorización.

| Bucket | Público | Máximo / MIME | Acceso | Retención |
|---|---:|---|---|---|
| company-logos | opcional lectura | 5 MB; png/jpeg/webp/svg saneado | admin escribe | mientras empresa activa |
| employee-photos | no | 10 MB; jpeg/png/webp | propio/RRHH lee; RRHH escribe | vínculo laboral + plazo legal |
| employee-documents | no | 25 MB; PDF/imágenes | propio autorizado/RRHH | categoría/legal |
| payroll-imports | no | 50 MB; xlsx/csv | nómina escribe/lee | 1 año o política |
| payroll-exports | no | 100 MB; xlsx/pdf/csv | nómina autorizada | 10 años recomendado |
| report-exports | no | 100 MB; pdf/xlsx/csv | creador/alcance | 30–90 días |
| request-attachments | no | 25 MB; PDF/imágenes | solicitante/aprobadores | solicitud + plazo legal |

RLS de `storage.objects` extrae `empresa_id` del primer segmento, lo compara con el profile y exige permiso/relación. Delete requiere capacidad específica y retención cumplida. Upload se completa mediante Edge Function: valida MIME real, tamaño, hash, antivirus futuro y crea `archivos` + `relaciones_archivo`. URLs firmadas cortas; no buckets públicos por comodidad.

## Realtime

- `eventos_asistencia`: dashboard escucha INSERT de su empresa; payload sin PIN/biometría.
- `jornadas`: dashboard escucha cambios de estado agregados.
- `notificaciones`: Android/web escucha filas propias.
- `solicitudes`: solicitante y aprobadores escuchan cambios autorizados.
- `cola_sincronizacion`: no publicar generalmente; Android recibe ACK por respuesta RPC y hace pull incremental. Realtime solo para diagnóstico interno agregado.

Suscripción siempre con filtro `empresa_id=eq.<tenant>` y RLS; además filtrar empleado cuando sea propio. Evitar tablas de nómina, auditoría, PIN, seguridad, cuentas bancarias y documentos en Realtime. Desuscribir al cerrar sesión/cambiar empresa y usar una suscripción por dominio, no por fila.

## Edge Functions

| Función | Entrada/validación | Permiso/tablas | Respuesta, idempotencia y auditoría |
|---|---|---|---|
| create-company-user | empleado, email, rol; mismo tenant, empleado libre | usuarios.administrar; Auth/profiles/empleados | user/profile; key por empleado+email; alta auditada |
| link-user-to-employee | user/empleado | usuarios.administrar; profiles/empleados | enlace; unique/idempotente; before/after |
| verify-employee-pin | código, PIN, device, nonce | dispositivo habilitado; empleados/intentos | challenge corto; rate limit; nunca log PIN |
| register-attendance | challenge, evento UUID, GPS/device/time | asistencia.registrar_propia; eventos/jornadas | ACK estable; idempotency key; evidencia |
| correct-attendance | evento, motivo, cambio | asistencia.corregir; correcciones/aprobaciones | solicitud/resultado; no muta original |
| process-payroll | período, versión | nomina.procesar; tablas nómina/asistencia | job/version; lock idempotente; historial |
| generate-payroll-export | período/formato | nomina.descargar; detalles/Storage | job + URL firmada; hash y auditoría |
| generate-report-export | reporte/filtros | reportes.exportar; vistas/Storage | trabajo asíncrono; key de filtros |
| upload-private-document | categoría, entidad, metadata | archivos permiso/propiedad | upload firmado/archivo; hash y escaneo |
| revoke-user-sessions | usuario/motivo | usuarios.administrar o propio | sesiones revocadas; evento seguridad |

Errores normalizados 400 validación, 401 identidad, 403 alcance, 409 idempotencia/conflicto, 422 estado de negocio, 429 rate limit y 500 con correlation ID. Cada función valida JWT; no confía en rol/empresa del JSON. Secretos solo en variables protegidas de la función.
