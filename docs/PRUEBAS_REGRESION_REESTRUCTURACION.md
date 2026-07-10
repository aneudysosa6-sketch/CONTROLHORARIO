# Pruebas de regresión

## Android

- Login administrador/empleado y sesión/cierre.
- Kiosco muestra PIN y HUELLA.
- PIN: longitud, cero inválido, empleado inexistente/inactivo.
- 2Connect: attach/detach, permiso, timeout, plantilla ausente, dedo incorrecto/correcto.
- BiometricPrompt: disponible, cancelación, fallo, error y éxito.
- Cuatro eventos y orden válido; doble toque/idempotencia.
- GPS permitido/denegado y precisión.
- Room offline, reinicio, cola, reintento y duplicado.
- Navegación hacia/desde ponche sin bypass.

## Web

- Login/logout, rutas protegidas y recarga Vercel.
- Menú filtra por permisos y nunca concede acceso por ocultación.
- Dashboard, empleados, asistencia, nómina, descarga y errores.
- Acciones críticas: loading, confirmación, doble envío, éxito/error.
- Responsive y teclado.

## Nómina

Casos dorados con configuración real: licencia y porcentaje ingresado, vacaciones, incapacidad, tardanza, ausencia, horas extras, redondeo, descuentos/bonificaciones y repetibilidad. No se fijan valores legales nuevos en tests.

## Automatización actual

`scripts/verify_critical_flows.ps1` es un guard estructural, no sustituye tests instrumentados. Debe ejecutarse antes/después de refactors. Builds obligatorios: `gradlew.bat :app:assembleDebug` y `npm run build`.
