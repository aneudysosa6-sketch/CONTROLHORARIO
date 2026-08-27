# SUPABASE

Última actualización: 2026-08-26

## 1. Entornos

- STAGING: [STAGING_PROJECT_REF].
- PRODUCCIÓN: [PRODUCTION_PROJECT_REF].
- Producción no fue tocada durante la implementación ni aceptación terminal.

## 2. Responsabilidad

Supabase proporciona:

- Auth para usuarios Web;
- PostgreSQL como fuente de verdad;
- PostgREST y RPC;
- RLS;
- Edge Functions;
- secretos de runtime;
- auditoría.

Android no usa un JWT Web para jornadas. Usa identidad Terminal.

## 3. Migraciones terminales

| Migración | Propósito |
|---|---|
| 0055 | Fundación histórica del flujo QR y lease |
| 0056 | Prueba biométrica y anti-replay de jornadas |
| 0057 | Intercambio QR de un solo uso, histórico |
| 0058 | Sesión QR reanudable, histórico |
| 0059 | Corrección de auditoría QR, histórico |
| 0060 | Alta facial exclusiva del Terminal y cierre QR |
| 0061 | Recuperación canónica de jornada y nómina |

0055-0059 no se reescriben. 0060 las deja inertes operativamente sin borrar
historial.

## 4. Estado STAGING

En [STAGING_PROJECT_REF]:

- migraciones 0055-0061: PASS;
- pgTAP/RLS/RPC de fase: PASS;
- device-enrollment: PASS;
- employee-sync: PASS;
- face-enrollment: PASS;
- attendance-sync: PASS;
- validación física WP23: PASS.

No se requiere repetir la batería remota si SQL, RPC, RLS y Edge no cambian.

## 5. Edge Functions de Terminal

### device-enrollment

Intercambia un código temporal por identidad Terminal. Valida:

- formato y vigencia;
- uso único;
- tenant opcional coincidente;
- installation ID;
- clave P-256;
- configuración asignada.

### employee-sync

Valida credencial activa y dispositivo. Devuelve solo datos del tenant y
alcance del Terminal, incluyendo lease y conteo facial pendiente.

### face-enrollment

Solo admite lookup y complete con:

- credencial Terminal;
- firma P-256;
- request ID;
- timestamp fresco;
- alcance;
- horario y día libre;
- liveness y tres poses;
- hash y dimensión FaceNet-128;
- duplicidad e idempotencia.

Create, exchange, revoke o cualquier token QR devuelven
FACE_QR_ENROLLMENT_DEPRECATED.

### attendance-sync

Exige credencial Terminal y prueba P-256/biométrica. Revalida empleado,
sucursal, tenant, timestamp, versión, idempotencia y anti-replay.

## 6. verify_jwt false

Las funciones anteriores usan verify_jwt false porque no se autentican con el
JWT estándar del gateway. Esto no implica acceso anónimo.

Cada handler rechaza la ausencia de su credencial específica antes de usar
service_role. El secreto solo existe en el runtime Edge.

## 7. RLS y SECURITY DEFINER

Reglas:

- RLS habilitada en tablas expuestas;
- tenant derivado de identidad;
- denegación por defecto;
- funciones con search_path controlado;
- grants mínimos;
- anon y authenticated sin ejecución de RPC de Terminal;
- auditoría para operaciones sensibles.

La RPC de eliminación facial Web sí se concede a authenticated, pero valida
usuario, empresa, permiso y alcance.

## 8. QR histórico

- Invitaciones y sesiones permanecen para auditoría.
- No existen grants operativos de creación/canje/finalización.
- Las invitaciones pendientes fueron revocadas.
- La Edge devuelve 410.
- Web no ofrece UI ni ruta.
- No se ejecuta DROP destructivo.

## 9. Datos sensibles

- service_role no sale de Edge.
- No se registran credenciales.
- No se registran embeddings.
- No se guardan imágenes.
- Los logs usan correlation ID y códigos estables.
- La publishable key puede existir en clientes y depende de RLS.

## 10. Promoción

La promoción a producción requiere una autorización distinta y explícita.
Antes de cualquier operación se debe comprobar el project ref y ejecutar
preflight, backup, delta, smoke tests y rollback. Este documento no autoriza
tocar [PRODUCTION_PROJECT_REF].