# DECISIONES DE ARQUITECTURA

## 1. Convencion

Estados:

- `Aceptada`: norma vigente.
- `Provisional`: norma vigente con salida pendiente.
- `Pendiente`: requiere decision.
- `Reemplazada`: se conserva como historial.

## ADR-001 - Supabase Auth como identidad

Estado: Aceptada  
Fecha: 2026-07-27, documentacion de una decision ya implementada

Contexto:

El sistema necesita una identidad consistente entre Android, Web y funciones
remotas.

Decision:

Supabase Auth es la unica autoridad de credenciales y tokens. `profiles`
extiende la identidad con datos de aplicacion.

Consecuencias:

- no se guardan contrasenas locales;
- no se reactiva el PIN;
- cada perfil debe vincularse con `auth.uid()`;
- una sesion Auth necesita autorizacion de aplicacion.

## ADR-002 - Persistir Auth, no autorizacion

Estado: Aceptada

Contexto:

Un usuario puede cambiar de rol, permisos, empresa, departamentos o estado
mientras su sesion sigue vigente.

Decision:

Persistir access token, refresh token y expiracion. Recargar autorizacion remota
en cada bootstrap y reemplazar el principal completo.

Consecuencias:

- los cambios remotos se detectan sin logout;
- una red temporal requiere estado recuperable;
- no se usa un rol guardado para navegar.

## ADR-003 - Rol canonico de servidor

Estado: Aceptada

Contexto:

Existen aliases como `sup`, `supervisor`, `empleados` y `employee`.

Decision:

SQL produce `role_code_canonical`. Los clientes conservan el original para log,
pero navegan solo con el canonico.

Consecuencias:

- una funcion central mantiene aliases;
- `0030` corrige aliases de empleado;
- Android mantiene compatibilidad temporal hasta el despliegue.

## ADR-004 - Permisos y alcance remotos

Estado: Aceptada

Contexto:

Los roles no expresan por si solos cada capacidad ni los departamentos
permitidos.

Decision:

`permission_codes` controla capacidades. Asignaciones, RPC y RLS controlan
alcance.

Consecuencias:

- no hay bypass admin;
- no hay permiso vacio;
- supervisor sin asignacion no recibe toda la empresa;
- ocultar UI no sustituye servidor.

## ADR-005 - Un resolver de dashboard por plataforma

Estado: Aceptada

Contexto:

Login, bootstrap y pantallas habian acumulado decisiones repetidas de destino.

Decision:

Cada cliente tiene un resolver unico que consume el mismo rol canonico.

Consecuencias:

- Android usa `DashboardResolver`;
- Web usa su resolver por rol canonico;
- los permisos controlan entrada/modulos, no seleccion de rol;
- no hay fallback administrativo.

## ADR-006 - Migraciones historicas inmutables

Estado: Aceptada

Contexto:

Editar SQL ya aplicado rompe la reproducibilidad entre local y remoto.

Decision:

Toda correccion se agrega como nueva migracion secuencial.

Consecuencias:

- `0022` no se modifica;
- cambios posteriores usan `CREATE OR REPLACE FUNCTION`;
- recuperacion mediante migracion compensatoria;
- historial remoto antes de push.

## ADR-007 - Room como cache y outbox Android

Estado: Aceptada

Contexto:

Android debe operar con conectividad intermitente.

Decision:

Room conserva estado local, cache y outbox. WorkManager sincroniza con
idempotencia y version conocida.

Consecuencias:

- PostgreSQL sigue siendo autoridad;
- conflictos se registran;
- no hay fallback destructivo de Room;
- toda mutacion offline tiene ID estable.

## ADR-008 - Edge Functions como frontera privilegiada

Estado: Aceptada

Contexto:

Crear usuarios, administrar empleados y validar dispositivos requiere
privilegios no aptos para el cliente.

Decision:

Las Edge Functions contienen `service_role` y validan actor/tenant/permiso o
credencial de dispositivo.

Consecuencias:

- ningun cliente contiene service role;
- `verify_jwt=false` exige validacion manual completa;
- los handlers deben ser idempotentes y auditables.

## ADR-009 - Biometria local cifrada

Estado: Aceptada

Contexto:

Kiosco necesita identificacion rapida y puede perder conectividad.

Decision:

Procesar FaceNet en dispositivo, cifrar embeddings locales y mantener
plantillas 2Connect en almacenamiento local controlado.

Consecuencias:

- Android Keystore es obligatorio;
- no se registran plantillas;
- sincronizacion facial es restringida;
- liveness permanece una capacidad separada y pendiente.

## ADR-010 - Resultado de nomina oficial en Supabase

Estado: Provisional

Contexto:

Existen un motor SQL y un motor local Android.

Decision:

Hasta unificar la implementacion, solo el resultado persistido y auditado en
Supabase es oficial. Android no aprueba ni reemplaza ese resultado.

Consecuencias:

- reglas nuevas deben implementarse primero en el motor oficial;
- comparar paridad;
- retirar o convertir el motor local en estimador;
- la decision final de consolidacion sigue pendiente.

## ADR-011 - Notificaciones no bloqueantes

Estado: Provisional

Contexto:

Una falla de N8N no debe revertir una operacion de dominio exitosa.

Decision:

La notificacion es secundaria y no bloqueante.

Consecuencias:

- el adaptador actual captura fallos;
- antes de produccion se requiere outbox, firma, entrega durable y auditoria;
- no hay secretos en Web.

## ADR-012 - Sistema visual OSINET

Estado: Aceptada

Contexto:

Existen tokens OSINET actuales y restos de temas Android antiguos.

Decision:

Componentes nuevos usan la paleta oscura azul y tokens de plataforma descritos
en `06_UI_UX_GUIDE.md`.

Consecuencias:

- no nuevos colores hardcoded;
- retirar gradualmente temas violetas/verdes legados;
- mantener semantica equivalente entre Web y Android.

## ADR-013 - Documentacion consolidada

Estado: Aceptada

Contexto:

La carpeta `docs` contenia reglas, auditorias y copias legacy contradictorias.

Decision:

Mantener exactamente el conjunto oficial enlazado desde
`00_LEER_PRIMERO.md`. Integrar cambios en esos documentos en vez de crear
reportes paralelos.

Consecuencias:

- una nueva sesion tiene un punto de entrada;
- se retiraron documentos obsoletos;
- la documentacion forma parte de Definition of Done.

## ADR-014 - Kiosco oficial en Android

Estado: Aceptada

Contexto:

Android tiene Device Owner, lock task, biometria y sincronizacion. Web tiene
una ruta `/kiosco` con mock data.

Decision:

El kiosco operativo oficial es Android. La ruta Web es demo/legacy hasta que se
retire o se apruebe un producto Web separado.

Consecuencias:

- no usar `/kiosco` Web en operaciones;
- no copiar mock data;
- cualquier kiosco Web futuro requiere arquitectura y seguridad propias.

## Decisiones pendientes

| ID | Tema | Pregunta |
|---|---|---|
| ADP-001 | Nomina | Retirar motor Android o convertirlo en cliente del SQL |
| ADP-002 | N8N | Crear outbox/dispatcher en Edge o servicio dedicado |
| ADP-003 | Liveness | Proveedor y politica de presentacion facial |
| ADP-004 | Dashboards Web | Componentes dedicados RRHH/NOMINA/AUDITOR |
| ADP-005 | Entornos | Separacion formal dev/staging/prod |
| ADP-006 | UI Android | Convergencia de tokens y tipografia |

Una decision pendiente no autoriza una implementacion improvisada.
