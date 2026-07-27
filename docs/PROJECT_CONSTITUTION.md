# CONSTITUCION DEL PROYECTO CONTROL HORARIO

Version: 1.0  
Ratificada: 2026-07-27

## Preambulo

CONTROL HORARIO administra identidad, tiempo laboral, biometria y dinero. La
velocidad de entrega nunca justifica debilitar aislamiento, trazabilidad o
fuentes de verdad.

Esta constitucion define los principios no negociables. Una decision tecnica
puede evolucionar, pero debe respetarlos o proponer una enmienda explicita.

## Articulo 1. Verdad verificable

Toda afirmacion sobre el sistema debe respaldarse con:

- codigo real;
- contrato SQL;
- estado de despliegue;
- resultado de prueba;
- documento oficial actualizado.

No se reporta como terminado lo que solo fue editado localmente.

## Articulo 2. Identidad unica

Supabase Auth es la identidad remota oficial.

- No hay sistema paralelo de contrasenas.
- No se guardan contrasenas en Room, Web Storage ni tablas de aplicacion.
- El PIN legado no se reactiva.
- El ID Auth se vincula con un perfil de aplicacion.

## Articulo 3. Autorizacion remota

Rol, permisos, empresa y alcance se obtienen de Supabase.

- `obtener_mi_autorizacion()` es el contrato central.
- Los tokens pueden persistir.
- La autorizacion se recarga al iniciar.
- Un cliente no concede permisos por rol.
- Una lista vacia no concede acceso.
- Una cuenta inactiva no conserva acceso por tener token.

## Articulo 4. Rol canonico

El servidor normaliza aliases. Los clientes navegan con
`role_code_canonical`.

- `role_code_original` es diagnostico.
- `role_name` es presentacion.
- No existen routers alternativos por pantalla.
- Un rol desconocido se deniega de forma funcional.

## Articulo 5. Menor privilegio

- `service_role` solo existe en backend seguro.
- RLS permanece activa.
- El supervisor no obtiene acceso global.
- El administrador necesita permisos asignados.
- El cliente no decide el tenant efectivo.
- Toda excepcion es explicita, auditada y revisable.

## Articulo 6. Aislamiento multiempresa

Cada operacion confirma:

- actor;
- empresa;
- entidad;
- permiso;
- alcance.

La UI no sustituye controles de servidor. Un ID valido de otra empresa sigue
siendo acceso denegado.

## Articulo 7. Migraciones inmutables

Una migracion aplicada no se modifica.

- Las correcciones se agregan en una migracion nueva.
- Las funciones se reemplazan con SQL compatible.
- El historial remoto se consulta antes de un push.
- Una recuperacion usa migracion compensatoria.

## Articulo 8. Offline controlado

Room y WorkManager permiten continuidad, no una segunda verdad.

- Toda mutacion offline es idempotente.
- Los conflictos son visibles.
- El servidor decide el estado remoto final.
- La sincronizacion no sobreescribe silenciosamente.

## Articulo 9. Datos biometricos

- Minimizacion.
- Cifrado.
- Acceso restringido.
- Auditoria de enrolamiento.
- Sin logs de plantillas.
- Diferencia explicita entre huella, rostro y biometria del sistema.
- No se afirma liveness si no existe.

## Articulo 10. Integridad financiera

Los resultados oficiales de nomina son los persistidos y auditados en
Supabase.

- Una calculadora local no aprueba una nomina.
- Las reglas tienen version y evidencia.
- Ajustes, descuentos, prestamos y creditos son trazables.
- Dos motores no pueden evolucionar independientemente.

## Articulo 11. Errores seguros

El usuario recibe un mensaje funcional. El soporte recibe un codigo tecnico y
correlation ID.

No se muestran:

- SQL;
- stack trace;
- tokens;
- claves;
- detalles internos del tenant.

## Articulo 12. Experiencia coherente

- UI OSINET oscura y legible.
- Estados de carga, vacio, error y permiso.
- Responsive Web.
- Accesibilidad.
- Acciones reales segun permiso.
- Sin mock presentado como produccion.

## Articulo 13. Integraciones no bloqueantes

Una notificacion no invalida una transaccion de dominio ya exitosa.

- Eventos idempotentes.
- Entrega auditable.
- Secretos fuera del cliente.
- Reintentos durables antes de considerar una integracion completa.

## Articulo 14. Cambios pequenos y completos

Un cambio debe ser:

- limitado a la causa;
- compatible;
- probado;
- desplegado cuando aplique;
- documentado;
- reversible.

No se aprovecha una correccion puntual para una refactorizacion no aprobada.

## Articulo 15. Documentacion oficial

Los 17 documentos de `docs` forman el manual del proyecto.

- No se crean auditorias paralelas.
- Un cambio de contrato actualiza el documento correspondiente.
- Un hito actualiza el changelog.
- Una decision actualiza ADR.
- Una prioridad actualiza roadmap.

## Articulo 16. Definicion de exito

Una funcionalidad es exitosa cuando:

1. Cumple el caso funcional.
2. Niega casos no autorizados.
3. Respeta empresa y alcance.
4. Tolera fallos esperados.
5. No expone secretos.
6. Tiene evidencia de prueba.
7. Tiene evidencia de despliegue si aplica.
8. La documentacion coincide.

## Gobierno

Las decisiones arquitectonicas se registran en
[ARCHITECTURE_DECISIONS.md](./ARCHITECTURE_DECISIONS.md).

Una enmienda a esta constitucion debe:

1. Explicar el problema.
2. Identificar articulos afectados.
3. Describir riesgo.
4. Proponer controles equivalentes o mejores.
5. Recibir aprobacion explicita.
6. Incrementar version y fecha.

Una conversacion, comentario o workaround no modifica la constitucion.
