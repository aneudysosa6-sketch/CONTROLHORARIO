# CONTROL HORARIO - Cierre de despliegue PROD

Fecha de cierre: 2026-08-26 (America/La_Paz)

## Estado final

- PRODUCTION_ROLLOUT: PASS
- WP23_CANARY_REGISTERED: PASS
- TERMINAL_ONLY_STARTUP: PASS
- CONTROL_HORARIO_PRODUCTION_READY: YES
- PUSH_PERFORMED: NO
- DESTRUCTIVE_OPERATIONS: NO

## Alcance

- Supabase PROD: proyecto productivo configurado; referencia omitida.
- Web Vercel PROD: proyecto productivo configurado; identificador omitido.
- Deployment inmutable: READY; URL operativa omitida.
- Alias PROD: asociado; URL operativa omitida.
- Terminal fisico: OUKITEL WP23 Plus

## Backup y base de datos

- Backup previo al rollout: PASS
- Schema backup: verificado; checksum retenido en evidencia privada.
- Data backup: verificado; checksum retenido en evidencia privada.
- Migraciones PROD 0038-0061: PASS
- pgTAP focalizado: 88 assertions PASS
- Extension pgTAP temporal no persistida: PASS

## Edge Functions PROD

- device-enrollment: DEPLOYED
- face-enrollment: DEPLOYED
- employee-sync: DEPLOYED
- attendance-sync: DEPLOYED
- Gateway verify_jwt=false, con autenticacion interna contractual obligatoria
- Smokes negativos autorizados: PASS
- QR facial legado: HTTP 410, inactivo
- Jornadas reales creadas durante smokes/canary: 0

## Canary WP23

- Codigo PROD consumido una sola vez: PASS
- Flujo visible: codigo de registro -> camara facial
- Login o pantalla intermedia: NONE
- Device ID vigente: PRESENTE Y UNICO; valor omitido.
- Company assignment: VALIDADA; identificador omitido.
- Branch assignment: VALIDADA Y ACTIVA; identificador omitido.
- Installation ID presente: YES
- Public key P-256 SPKI valida: YES
- Public key fingerprint: VALIDADO; valor retenido en evidencia privada.
- Credential activa, no revocada y ligada a device/company: PASS
- Credential vigente al cierre: PASS.
- Conexion y uso recientes al cierre: PASS.
- Offline lease: 24 horas
- Configuration revision: 2
- Face-only enabled: YES

## Unicidad y auditoria

- Active devices: 1
- Distinct installations: 1
- Active credentials: 1
- Active unused enrollment codes: 0
- Duplicado activo recreado por el canary: NO
- Registro de auditoria del dispositivo vigente: PRESENT
- Historial previo: no eliminado por este post-canary

## Sincronizacion y logs

- Configuracion del terminal sincronizada: PASS
- device-enrollment HTTP 200 en ventana canary: 1
- employee-sync HTTP 200 en ventana canary: 4
- Requests relevantes observados: 5
- HTTP 5xx relevantes: 0
- Journey events en PROD durante canary: 0
- Journeys en PROD durante canary: 0

## Contratos de seguridad

- Revocacion independiente del score: PASS
- Lease obligatorio: PASS
- Attendance exclusivo para terminal: PASS
- P-256, deviceId, tenant, eventId, idempotencia y anti-replay: PASS
- JWT normal/telefono personal para Attendance: REJECTED
- Suites ya aprobadas no fueron repetidas durante post-canary

## Web PROD

- Deployment target: production
- Deployment status: Ready
- Alias PROD asociado: PASS
- Build apunta exclusivamente a Supabase PROD: PASS
- Referencias STAGING en bundle PROD: NONE
- HTTPS/CSP autenticados: PASS
- Vercel Authentication: ENABLED

## Cierre operativo

El WP23 quedo enrolado como el unico terminal fisico vigente de PRODUCCION. La credencial, la clave publica P-256, el tenant, la sucursal, la configuracion, el lease y la sincronizacion quedaron correlacionados. El canary no creo jornadas ni duplicados activos, los accesos Edge observados finalizaron sin errores 5xx y el deployment Web PROD permanece Ready.

PRODUCTION_FINAL_STATUS: PASS
