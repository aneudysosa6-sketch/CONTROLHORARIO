# AUTENTICACIÓN Y AUTORIZACIÓN

Última actualización: 2026-08-26

## 1. Dos modelos separados

CONTROL HORARIO no mezcla usuario Web y Terminal Android.

### Web

Supabase Auth identifica al usuario. PostgreSQL devuelve autorización vigente:

- perfil;
- empresa;
- rol canónico;
- permisos;
- sucursales;
- departamentos;
- estado activo.

La Web usa esos datos para guards y presentación. RLS/RPC vuelven a validar.

### Android

Android no tiene Login normal. Su identidad operativa contiene:

- installation ID;
- device ID;
- credencial cifrada;
- clave privada P-256 no exportable;
- empresa y configuración recibidas del servidor;
- lease offline vigente.

Un JWT de usuario o teléfono personal no sustituye una credencial Terminal.

## 2. Registro del Terminal

1. Web genera un código temporal de dispositivo.
2. Android presenta únicamente el campo de código.
3. Android crea la clave P-256 en Keystore.
4. device-enrollment valida código, expiración, uso, tenant y clave.
5. El servidor crea dispositivo y credencial.
6. Android cifra la credencial.
7. Android sincroniza configuración, empleados y rostros.
8. Android abre cámara sin pantalla intermedia.

El código no es una credencial permanente.

## 3. Revalidación y lease

employee-sync renueva evidencia de autorización y devuelve:

- validated_at;
- credential_expires_at;
- offline_lease_expires_at.

La cámara solo abre con estado autorizado dentro del lease. Un 401/403 de
funciones de Terminal bloquea localmente la operación. Revocación, vencimiento
o tenant inválido nunca caen a Login.

## 4. Jornadas

attendance-sync exige:

- x-device-id;
- x-device-credential;
- dispositivo activo;
- empresa coincidente;
- empleado elegible;
- firma P-256;
- prueba biométrica fresca;
- timestamp ISO válido;
- idempotencia y anti-replay.

La RPC de jornada no es ejecutable por anon ni authenticated.

## 5. Registro facial

face-enrollment terminal exige:

- credencial activa;
- P-256 sobre request ID, dispositivo, timestamp y hash del body;
- timestamp fresco;
- lookup limitado al alcance del Terminal;
- empleado activo con horario y día libre;
- tres poses;
- liveness;
- FaceNet-128 de dimensión 128;
- hash de embedding;
- duplicidad e idempotencia en PostgreSQL.

JWT Web, anon y teléfono personal no pueden completar el alta.

## 6. Administración Web

El Login Web sí existe y protege:

- empleados;
- horarios;
- jornadas administrativas;
- nómina;
- reportes;
- usuarios;
- roles;
- permisos;
- sucursales;
- departamentos;
- dispositivos.

Ocultar un menú no autoriza. Cada ruta usa guard y cada operación remota valida
empresa, permiso y alcance.

## 7. Salida protegida Android

El gesto oculto abre una autenticación específica para salir del kiosco. No es
el Login inicial y no monta módulos administrativos. Una autenticación exitosa
solo permite mantenimiento mínimo:

- sincronizar;
- consultar estado del Terminal;
- volver a cámara;
- desregistrar con confirmación.

## 8. Datos y logs prohibidos

Nunca registrar ni exponer:

- access/refresh token;
- service_role;
- credencial Terminal;
- clave privada;
- contraseña;
- embedding;
- imagen facial;
- payload completo de empleado.

Se permiten correlation ID, código técnico, conteos, estado y métricas
numéricas no biométricas en debug/STAGING.

## 9. Fallo seguro

- Sin credencial: registro.
- Credencial revocada o inválida: TERMINAL NO AUTORIZADO.
- Lease vencido: revalidación obligatoria antes de cámara.
- Dispositivo de otra empresa: rechazo.
- JWT normal en endpoint Terminal: rechazo.
- QR antiguo: 410 FACE_QR_ENROLLMENT_DEPRECATED.
- Replay: rechazo o duplicate según contrato idempotente.

## 10. Producción

Ningún dato, deploy o validación de esta fase se ejecutó contra
[PRODUCTION_PROJECT_REF].