# Checklist manual vigente alineado con la especificacion maestra

Fecha de reconciliacion: 2026-08-24
Estado: pendiente de ejecucion en STAGING y hardware autorizado.

Antes de cualquier operacion remota se debe confirmar que `supabase/.temp/project-ref` contiene exactamente `[STAGING_PROJECT_REF]`. Produccion `[PRODUCTION_PROJECT_REF]` queda fuera de alcance. Las pruebas fisicas no permiten `pm clear`, desinstalacion, `set-device-owner`, eliminacion de cuentas ni factory reset.

## Roles, permisos y alcance

- [ ] Crear un rol personalizado y comprobar acciones permitidas y denegadas.
- [ ] Retirar un permiso con una sesion Web abierta y confirmar aplicacion sin logout ni recarga manual.
- [ ] Cambiar rol o alcance de sucursal/departamento y confirmar navegacion y API actualizadas.
- [ ] Desactivar un usuario Android y confirmar perdida de autorizacion sin reiniciar la aplicacion.
- [ ] Confirmar que un administrador solo administra su empresa.
- [ ] Confirmar que un supervisor ve todas y solo las sucursales/departamentos asignados.
- [ ] Intentar una ruta directa sin permiso y confirmar acceso denegado.
- [ ] Probar aislamiento RLS entre dos empresas.

## Empresa, sucursales y departamentos

- [ ] Crear, editar e inactivar empresa, sucursal y departamento con el permiso correcto.
- [ ] Bloquear inactivacion de sucursal con departamentos o empleados activos.
- [ ] Bloquear inactivacion de departamento con empleados activos.
- [ ] Confirmar que los catalogos inactivos siguen trazables y no se ofrecen para altas.
- [ ] Confirmar que la interfaz no realiza borrado destructivo.

## Recursos Humanos y empleados

- [ ] Crear empleados concurrentemente y confirmar codigos aleatorios unicos de seis digitos, distintos de 000000.
- [ ] Editar ficha, sucursal, departamento, salario, forma de pago y estado laboral.
- [ ] Confirmar que empleado inactivo no registra jornadas ni recibe nuevos mensajes.
- [ ] Confirmar que cambios de sucursal/departamento se propagan por revision sin reenrolar terminales.
- [ ] Confirmar que datos salariales, bancarios y personales no aparecen en logs.
- [ ] Generar la lista negra mensual con mas de 2 ausencias, mas de 5 tardanzas o mas de 5 jornadas incompletas.
- [ ] Confirmar consolidacion de motivos sin duplicar al empleado.
- [ ] Confirmar expresamente que pertenecer a la lista negra no impide una marcacion valida.
- [ ] Abrir e imprimir el reporte individual de lista negra con periodo y motivos.

## Licencias directas

- [ ] Crear una licencia y confirmar estado ACTIVE inmediato, sin circuito de aprobacion.
- [ ] Validar fechas, adjunto y porcentaje de 0 a 100.
- [ ] Probar porcentajes 0, 50 y 100 con calculo `salario mensual / 30 * porcentaje` por dias calendario.
- [ ] Intentar marcar durante una licencia activa y confirmar bloqueo.
- [ ] Editar desde una fecha interna y confirmar versionado solo hacia adelante.
- [ ] Cancelar la licencia y confirmar auditoria y efecto futuro en asistencia/nomina.
- [ ] Cambiar salario y confirmar regeneracion coherente de dias aplicables.

## Vacaciones

- [ ] Registrar vacaciones con rango valido y saldo suficiente.
- [ ] Rechazar rangos invertidos o dias superiores al saldo.
- [ ] Confirmar efecto en asistencia, portal y nomina sin confundirlo con licencias.
- [ ] Confirmar trazabilidad de cambios y saldo.

## Prestamos

- [ ] Registrar un prestamo con monto, cuota, saldo, fecha y empleado validos.
- [ ] Rechazar monto o cuota no positiva.
- [ ] Registrar abonos y comprobar que ninguno supera el saldo.
- [ ] Ejecutar dos abonos concurrentes y confirmar balance consistente.
- [ ] Confirmar que el descuento de nomina no supera saldo ni neto disponible.
- [ ] Comparar saldo, cuotas, abonos y libro mayor.

## Asistencia y jornadas

- [ ] Ejecutar INICIAR, pausa, reanudacion y finalizar en orden.
- [ ] Rechazar timestamps futuros, invalidos o no monotonicos.
- [ ] Repetir una idempotency key y confirmar que no duplica el evento.
- [ ] Registrar sin red y sincronizar al recuperar conectividad.
- [ ] Generar conflicto entre dos terminales y confirmar tratamiento idempotente.
- [ ] Confirmar que la jornada queda persistida antes de mostrar un mensaje.
- [ ] Confirmar que una licencia activa bloquea la marcacion.
- [ ] Confirmar que la lista negra nunca participa como regla de bloqueo.

## NO PAGAR

- [ ] Jornada con solo INICIAR: registrar manualmente 0 horas y confirmar aceptacion.
- [ ] Jornada con solo INICIAR: registrar manualmente 8 horas y confirmar aceptacion.
- [ ] Jornada con solo INICIAR: intentar menos de 0 o mas de 8 horas y confirmar rechazo.
- [ ] Jornada con intervalos demostrables: confirmar que no aparece ni se acepta entrada manual.
- [ ] Resolver una jornada con intervalos usando exclusivamente los eventos existentes.
- [ ] Confirmar que la resolucion conserva jornada, eventos y auditoria.
- [ ] Cerrar la nomina e intentar editar la resolucion; confirmar rechazo.
- [ ] Confirmar actor, motivo, fecha y valores anterior/nuevo.

## Terminal GENERAL

- [ ] Enrolar un terminal GENERAL en sucursal A.
- [ ] Confirmar sincronizacion de empleados activos de sucursales A y B de la misma empresa.
- [ ] Confirmar que un empleado inactivo y uno de otra empresa no pueden marcar.
- [ ] Marcar un empleado de sucursal B y confirmar que se guarda la sucursal A del terminal como ubicacion.
- [ ] Cambiar la sucursal configurada y confirmar que el universo GENERAL sigue siendo toda la empresa.

## Terminal DEPARTMENTS

- [ ] Configurar una sucursal y uno o mas departamentos activos.
- [ ] Confirmar que no se puede guardar DEPARTMENTS sin departamentos.
- [ ] Confirmar acceso de un empleado activo de un departamento autorizado.
- [ ] Confirmar rechazo fuera de alcance con `TERMINAL NO AUTORIZADO PARA SU DEPARTAMENTO`.
- [ ] Cambiar la sucursal y confirmar limpieza de departamentos incompatibles.
- [ ] Desactivar un departamento y confirmar que deja de ser elegible.
- [ ] Mover un empleado a otro departamento y confirmar aplicacion sin reenrolamiento.

## Terminal facial, TwoConnect y quiosco

- [ ] Enrolar un dispositivo con codigo de un solo uso y clave P-256.
- [ ] Revocar el dispositivo y confirmar rechazo de su credencial.
- [ ] Probar registro inicial y reconocimiento facial bajo iluminacion controlada.
- [ ] Probar fallback permitido y salida segura de quiosco.
- [ ] Probar lector TwoConnect sin operaciones destructivas sobre el telefono.
- [ ] Confirmar que logs no contienen credenciales, embeddings, rostros ni respuestas completas.

## Nomina, pagos y ajustes anteriores

- [ ] Calcular tarifa hora como salario mensual / 30 / 8.
- [ ] Confirmar redondeo monetario HALF_UP y neto no negativo.
- [ ] Confirmar conceptos de asistencia, licencias, vacaciones, prestamos y descuentos definidos por la especificacion.
- [ ] Confirmar que una resolucion NO PAGAR usa intervalos demostrables o la excepcion manual 0-8.
- [ ] Corregir asistencia de un periodo cerrado y confirmar que el periodo original no cambia.
- [ ] Confirmar que el ajuste anterior aparece una sola vez en la siguiente nomina abierta.
- [ ] Recalcular y confirmar idempotencia sin duplicar el ajuste.
- [ ] Confirmar detalle con periodo origen, empleado, concepto, monto y motivo.
- [ ] Comparar detalle, libro mayor, PDF y hoja exportada.

## Portal y reportes

- [ ] Confirmar que el empleado se deriva de la sesion y no de un identificador del cliente.
- [ ] Confirmar que cada empleado solo ve su informacion.
- [ ] Probar filtros, totales y alcance por empresa/sucursal/departamento.
- [ ] Confirmar que licencias, NO PAGAR, ajustes anteriores y lista negra aparecen donde corresponde.
- [ ] Exportar valores que comienzan por `=`, `+`, `-` y `@` y confirmar que no ejecutan formulas.
- [ ] Revisar PDF, hoja e impresion en escritorio y movil.

## Mensajes y precarga offline

- [ ] Abrir Mensajes con el permiso requerido.
- [ ] Enviar a alcance general o departamental sin revelar listados de pendientes.
- [ ] Enviar texto y confirmar que una URL no se vuelve navegable.
- [ ] Probar voz del sistema y repeticion.
- [ ] Grabar, previsualizar y enviar audio de hasta 30 segundos; impedir duraciones mayores.
- [ ] Confirmar entrega solo despues de una marcacion persistida con exito.
- [ ] Precargar texto, desconectar y confirmar entrega desde la cola cifrada local.
- [ ] Precargar audio, desconectar y confirmar reproduccion local.
- [ ] Confirmar que un mensaje departamental solo llega al alcance configurado.
- [ ] Marcar primero en terminal A y confirmar que terminal B recibe tombstone y no muestra el mensaje.
- [ ] Reconectar y confirmar una sola recepcion idempotente en servidor.
- [ ] Confirmar que contenido recibido no queda en historial visible ni auditoria.

## Seguridad, APK y cierre

- [ ] Confirmar RLS con usuarios de empresas distintas.
- [ ] Confirmar permisos de ejecucion de RPC SECURITY DEFINER con perfiles permitidos y denegados.
- [ ] Confirmar que no hay tokens, service role, credenciales, embeddings, texto/audio ni datos bancarios en logs.
- [ ] Verificar paquete `com.example.controlhorario.staging`.
- [ ] Verificar referencia STAGING presente y referencia de produccion ausente.
- [ ] Verificar firma y SHA-256 del APK.
- [ ] Ejecutar pruebas fisicas solo en dispositivos autorizados y sin acciones destructivas.

## Cierre físico terminal-only 2026-08-26

- [x] Primera instalación por código de Terminal y aperturas posteriores a cámara.
- [x] Sin Login ni navegación administrativa Android.
- [x] Enrolamiento facial presencial y sincronización de template.
- [x] Reconocimiento Persona 1, threshold 0.75, margin opcional y liveness.
- [x] INICIAR, PAUSA, REANUDAR y FINALIZAR en STAGING.
- [x] Bloqueo hasta abandonar el cuadro y jornada ya finalizada.
- [x] TTS START, PAUSE, RESUME y FINISH audible; START/RESUME confirmados con `onDone`.
- [x] QR facial retirado/inertizado.
- [x] PRODUCCIÓN no tocada.
