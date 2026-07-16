# Auditoría de seguridad: RLS, RPC y Edge Functions

Fecha: 2026-07-16. Alcance local: cadena oficial 0001–0013, funciones SQL, políticas RLS, grants y código de Edge Functions. No se usó `supabase link`, producción ni credenciales remotas.

## Estado P0: COMPLETADO

El 2026-07-16, `scripts/verify_supabase_security.ps1` finalizó con **PASS**: los contratos de aislamiento RLS (21 pruebas) y RPC/grants/`SECURITY DEFINER` (16 pruebas) aprobaron en Supabase local. El stack local y sus volúmenes fueron eliminados al finalizar.

## Resultado de controles SQL

Los contratos locales crean Empresa A/B, administradores, supervisor, empleado e identidad inactiva. Comprueban aislamiento bilateral de empleados, ausencia de lectura para usuario inactivo, alcance de supervisor por sucursal/departamento, mínimo privilegio de empleado, y denegación directa de tablas biométricas, dispositivos y credenciales.

También comprueban que las funciones `SECURITY DEFINER` propias fijan `search_path`, no conceden ejecución a `PUBLIC`, que las RPC redefinidas mantienen su firma/grant final y que RLS está activo para empleados, jornadas, nómina, préstamos, dispositivos y biometría.

## Edge Functions

| Función | Autenticación | Revocación/replay/auditoría |
|---|---|---|
| `user-provisioning` | JWT validado y permiso `usuarios.administrar`; bootstrap con secreto de servidor | bootstrap se cierra tras primer profile; audita por RPC |
| `employee-management` | JWT validado, profile activo y permisos de empleados | valida tenant y PIN hash; no hay idempotencia explícita para mutaciones |
| `device-enrollment` | `verify_jwt=false`; canje por código o JWT+permiso en acciones administrativas | código de un uso/vencimiento, credencial revocable y auditoría de dispositivo |
| `employee-sync` | `verify_jwt=false`; `x-device-id` + credencial opaca validada en servidor | comprueba dispositivo/credencial/estado; auditoría de último uso; lectura idempotente |
| `attendance-sync` | `verify_jwt=false`; credencial de dispositivo | idempotency key por evento, dispositivo revocado debe denegarse y el motor registra auditoría |

`SUPABASE_SERVICE_ROLE_KEY` se lee únicamente con `Deno.env` dentro de Edge Functions. El verificador falla si aparece en Android o Web.

## Riesgos pendientes

- Las funciones con `verify_jwt=false` dependen totalmente de validación propia; se debe conservar la cobertura de credencial revocada y tenant en pruebas de integración HTTP.
- No se observó un rate limit explícito y uniforme en todos los handlers Edge; requiere decisión de infraestructura antes de producción.
- La advertencia del lint local sobre `v_id` sin uso en `crear_solicitud_prestamo` no es una vulnerabilidad demostrada.

## Ejecución

Ejecutar: `powershell -ExecutionPolicy Bypass -File scripts/verify_supabase_security.ps1`. El script inicia, reinicia y detiene exclusivamente Supabase local y sus volúmenes.
