# Módulo 2.2 — Sincronización de empleados Android ↔ Supabase

## Seguridad y contrato

La Edge Function independiente `employee-sync` autentica `x-device-id` y la credencial opaca contra su hash, comprueba que el dispositivo siga activo y obtiene la empresa exclusivamente de esa credencial. Los registros completos incluyen solo empleados activos del tenant. Las bajas se comunican como tombstones mínimos con `remote_id` y `updated_at` para desactivar la copia local sin exponer sus datos.

La función nunca selecciona ni devuelve PIN, `pin_hash`, templates o metadatos biométricos. La descarga usa páginas de 500 elementos y un cursor estable `(updated_at,id)`.

## Android y Room

Android usa `remoteId` como identidad estable y evita duplicados enlazando una fila local existente por código solamente durante la primera asociación. El merge conserva el ID Room, PIN, foto, estado/template biométrico y demás datos offline. Solo actualiza código, nombre, teléfono, correo, sucursal, departamento, cargo, supervisor, estado laboral, fecha de ingreso, salario, tipo de pago y `updated_at` remotos.

Room v28 agrega los campos laborales remotos y el cursor mediante una migración explícita 27→28. La relación `supervisor_id` se incorpora al esquema Supabase mediante `0007_employee_supervisor_sync.sql` y queda pendiente de despliegue autorizado.

## Ejecución y observabilidad

WorkManager solicita sincronización al registrar el dispositivo, al abrir la app, cada seis horas y al recuperar conectividad. Los errores de red, HTTP 429 y 5xx reintentan con backoff; credenciales inválidas y dispositivos revocados fallan sin reintentos infinitos.

La pantalla temporal `Empleados sincronizados` muestra total descargado, activos, inactivos y fecha de última sincronización.

## Alcance

La función y la migración Supabase están versionadas pero no desplegadas. Este módulo no modifica el lector 2Connect, captura de huellas, modo kiosco, jornadas ni nómina.
