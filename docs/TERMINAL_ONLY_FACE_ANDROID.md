# Android terminal-only y registro facial

Fecha normativa: 2026-08-25.

## Regla de producto

Android CONTROL HORARIO es exclusivamente un Terminal autorizado. Una instalación nueva muestra
solo el código de registro y, después de validar y sincronizar en segundo plano, abre la cámara.
Las aperturas posteriores con credencial y lease válidos abren la cámara directamente. Una
credencial inválida, vencida, revocada o fuera de lease muestra TERMINAL NO AUTORIZADO. No existe
Login normal ni navegación administrativa.

La cámara reconoce empleados para INICIAR, PAUSA, REANUDAR y FINALIZAR. Además muestra
Registrar rostro nuevo (N pendientes) solo cuando el conteo autoritativo del servidor es mayor que
cero. El alta facial es una operación separada y nunca crea una jornada automáticamente.

## Registro facial en Terminal

1. El Terminal sincroniza el conteo de empleados sin rostro que pertenecen a su empresa y alcance.
2. GENERAL admite el alcance canónico de empresa; DEPARTMENTS exige un departamento configurado.
3. El empleado debe estar activo, habilitado para jornada, tener horario semanal vigente y al menos
   un día libre. Sin ello se muestra SUPERVISOR DEBE ASIGNAR HORARIO Y DÍA LIBRE.
4. El operador introduce únicamente el código de seis dígitos y confirma nombre/código.
5. Android exige un rostro, distancia, encuadre, iluminación, frontal, izquierda, derecha y un
   parpadeo real. Solo se reintenta la pose pendiente.
6. FaceNet-128 produce tres embeddings transitorios; se promedian y normalizan en memoria.
7. La confirmación requiere conexión, credencial activa, empresa, alcance, firma P-256 del Keystore,
   timestamp fresco, idempotencia y ausencia de duplicado facial.
8. PostgreSQL guarda atómicamente la plantilla. Android cifra localmente únicamente la plantilla
   devuelta por el servidor y vuelve a la cámara.
9. Para marcar jornada, el empleado debe retirarse y ser reconocido nuevamente.

No se guardan fotos. Los buffers se liberan y los embeddings no aparecen en logs.

## Web

Toda administración continúa en Web. La ficha muestra solo PENDIENTE o ENROLADO. Un usuario con el
permiso y alcance existente de biometría puede eliminar el rostro; el empleado vuelve al conteo del
Terminal tras sincronización. La creación de empleados no genera QR y el PDF inicial no contiene QR,
token ni credencial.

## QR deprecado

Desde la migración 0060 no se crean invitaciones QR. Las pendientes se revocan sin borrar historial,
los RPC de creación/canje/finalización fallan con FACE_QR_ENROLLMENT_DEPRECATED y la ruta pública Web
no existe. Un teléfono personal o JWT normal no puede consultar ni confirmar un alta facial.

## Seguridad y compatibilidad

- Modelo FaceNet-128, entrada 160 x 160 x 3, salida normalizada de 128 valores.
- Credencial cifrada y clave P-256 no exportable en Android Keystore.
- Edge con no-verify-jwt sigue cerrada: valida credencial específica, dispositivo, tenant y firma.
- La RPC revalida estado, alcance, horario, día libre, rostro ausente, duplicado e idempotencia.
- La asistencia conserva su contrato independiente de credencial, proof biométrico y anti-replay.
- face_match_margin no se inventa; permanece null hasta disponer de muestras reales suficientes.

## Decisión final sobre threshold y margin

`face_match_threshold` conserva su valor operativo y es el criterio primario. `face_match_margin` permanece nullable: cuando está configurado añade una comprobación de ambigüedad best-vs-second; cuando es `null`, esa comprobación adicional no aplica y la identificación puede continuar si liveness y threshold pasan. Con una sola identidad no existe segundo candidato y el margin tampoco aplica.
