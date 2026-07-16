# Reporte de preflight Supabase

Fecha: 2026-07-16  
Alcance: validación estática y preflight local exclusivamente. No se usó `supabase link`, `--linked`, `--db-url`, credenciales remotas ni `service_role` remoto.

## Migraciones oficiales encontradas

La única cadena autorizada es la carpeta `supabase/migrations/`, en este orden exacto:

1. `0001_FINAL.sql`
2. `0002_FINAL.sql`
3. `0003_FINAL.sql`
4. `0004_admin_employee_permissions.sql`
5. `0005_employee_biometrics_foundation.sql`
6. `0006_android_device_enrollment.sql`
7. `0007_employee_supervisor_sync.sql`
8. `0008_rc2_attendance_engine.sql`
9. `0009_rc3_supervisor_scoped_operations.sql`
10. `0010_rc4_payroll_engine.sql`
11. `0011_rc35_system_administration.sql`
12. `0012_rc4_employee_pay_alignment.sql`
13. `0013_employee_portal_loans.sql`

Quedan excluidos por completo `supabase/migrations_archivadas/`, material legacy y scripts manuales ajenos a `scripts/verify_supabase_preflight.ps1`.

## Orden y objetos principales

| Migración | Objetos principales |
|---|---|
| 0001 | `companies`, organización, `profiles`, `roles`, helper privado, trigger común `set_updated_at`, grants/RLS iniciales |
| 0002 | `empleados`, permisos y alcances; triggers de normalización/actualización y RPC de tenant/permisos |
| 0003 | auditoría y RPC internas de bootstrap/provisioning, sólo `service_role` local/servidor |
| 0004 | corrección idempotente del catálogo/asignación de permisos de empleados |
| 0005 | tablas biométricas, auditoría y RPC de estado sin exponer plantillas |
| 0006 | tablas y RPC internas de enrolamiento/credencial de dispositivo |
| 0007 | relación `supervisor_id` de empleados e índice/relación de sincronización |
| 0008 | jornadas, eventos, incidencias, conflictos, auditoría, triggers y RPC de asistencia |
| 0009 | horarios, notificaciones, auditoría de supervisor, alcance y RPC de operación supervisada |
| 0010 | tablas/motor RC4 de nómina, trigger de nómina desactualizada, políticas/grants por permisos |
| 0011 | columnas/configuración administrativa, auditoría, RPC y políticas de administración |
| 0012 | columnas/ficha salarial, redefinición de cálculo RC4 y grants de ficha de pago |
| 0013 | solicitudes/movimientos/auditoría de préstamo, portal, trigger de movimiento y RPC del ciclo |

## Redefiniciones detectadas

- `establecer_jornada_habilitada`, `puede_ver_jornada` y `resolver_jornada_pendiente`: 0008 → 0009.
- `calcular_nomina`: 0010 → 0012.
- Políticas de lectura de `empleados`: 0002 → 0009, con eliminación/recreación para incorporar alcance supervisor.
- Grants y políticas de organización: 0001 → 0011, ajustados a permisos granulares.

Estas redefiniciones son válidas sólo al aplicar la cadena completa y ordenada; aplicar archivos aislados no es soportado.

## Pruebas incluidas

`supabase test db --local` ejecutará individualmente:

- `architecture_contracts.sql` (convertida a contrato pgTAP válido: plan, aserción y `finish()`)
- `0010_rc4_payroll_contract.sql`
- `0011_rc35_system_administration_contract.sql`
- `0012_rc4_employee_pay_alignment.sql`
- `0013_employee_portal_loans.sql`

El script también ejecuta `supabase db lint --local --fail-on error` después de `supabase db reset --local --no-seed`.

## Errores encontrados

1. **Bloqueante externo:** Supabase CLI no está disponible en `PATH` en el equipo auditado.
2. **Bloqueante externo:** Docker CLI/daemon no está disponible en el equipo auditado.
3. **Corregido en pruebas:** `architecture_contracts.sql` no emitía TAP/plan para `supabase test db`; se añadió la estructura pgTAP mínima sin cambiar el contrato comprobado.

No se detectó una migración adicional en la cadena oficial ni se modificó ninguna migración SQL oficial.

## Riesgos

- Hasta ejecutar el preflight local, no hay prueba de que la cadena aplique sin errores de SQL, dependencias, triggers, grants o RLS.
- Las funciones redefinidas requieren que el historial completo se aplique en orden.
- Las pruebas existentes cubren contratos de estructura y privilegios; no sustituyen una matriz de RLS con usuarios/tenants reales ni pruebas de Edge Functions.
- El `--no-seed` evita que datos de ejemplo oculten fallos de esquema; las pruebas deben ser autosuficientes.

## Resultado final

**FAIL — bloqueado antes de crear el entorno local por ausencia de Supabase CLI y Docker.** No se conectó a producción ni se alteró dato remoto.

## Pasos pendientes con autorización o credenciales

1. Instalar/autorizar Supabase CLI y Docker Desktop, y arrancar el daemon local.
2. Ejecutar desde la raíz: `powershell -ExecutionPolicy Bypass -File scripts/verify_supabase_preflight.ps1`.
3. Revisar el resultado local de migraciones, lint y pgTAP. No se requieren credenciales de Supabase ni autorización de producción para ese paso.
4. Sólo después de un PASS local, solicitar autorización separada para una matriz de RLS con identidades de prueba y para cualquier despliegue.
