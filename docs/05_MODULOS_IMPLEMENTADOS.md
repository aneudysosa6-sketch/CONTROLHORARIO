# MODULOS IMPLEMENTADOS

## 1. Criterio

Este inventario describe capacidades encontradas en el codigo real. No
convierte una pantalla, una tabla o un prototipo aislado en un modulo
completamente operativo.

| Estado | Criterio |
|---|---|
| Operativo | Flujo principal implementado y conectado |
| Parcial | Flujo util con ramas o validaciones pendientes |
| Base implementada | Infraestructura disponible sin cierre operativo |
| Pendiente de validar | Requiere evidencia remota o hardware |
| Legacy/no productivo | No debe utilizarse como referencia de producto |

## 2. Inventario general

| Modulo | Android | Web | Supabase | Estado general |
|---|---|---|---|---|
| Auth y sesion | Si | Si | Si | Operativo |
| Roles, permisos y alcance | Si | Si | Si | Operativo con deuda Web |
| Empresas y organizacion | Parcial | Si | Si | Operativo |
| Empleados | Si | Si | Si | Operativo |
| Accesos de usuario | Parcial | Si | Si | Operativo Web |
| Jornadas | Si | Si | Si | Operativo |
| Dashboard supervisor | Si | Si | Si | Operativo |
| Nomina | Si | Si | Si | Operativo con riesgo |
| Prestamos | Local | Si | Si | Parcial |
| Reportes | Parcial | Si | Si | Parcial |
| Portal empleado | Si | Si | Si | Parcial |
| Kiosco | Si | Mock | Si | Operativo Android |
| Rostro | Si | No | Si | Parcial |
| Huella 2Connect | Si | No | Local | Parcial |
| Dispositivos Android | Si | Si | Si | Operativo |
| N8N/notificaciones | No | Adaptador | Indirecto | Base implementada |
| Auditoria | Parcial UI | Parcial UI | Si | Operativo en datos |

## 3. Autenticacion y sesion

Hace:

- login con Supabase Auth;
- persistencia y renovacion de tokens;
- restauracion automatica;
- autorizacion remota;
- cambio de rol detectado al reiniciar;
- cierre y limpieza de sesion;
- rechazo de cuenta inactiva.

No debe hacer:

- guardar contrasena;
- persistir rol o permiso como autoridad;
- navegar antes de cargar autorizacion.

Referencia:
[03_AUTENTICACION_Y_AUTORIZACION.md](./03_AUTENTICACION_Y_AUTORIZACION.md).

## 4. Roles, permisos y alcance

Hace:

- normalizacion de rol en SQL;
- retorno de rol original y canonico;
- permisos efectivos;
- asignacion de sucursales y departamentos;
- alcance de supervisor;
- resolucion de dashboard por rol canonico.

Deuda:

- remover bypass y aliases locales de autorizacion Web;
- desplegar la canonicalizacion `0030`;
- ampliar pruebas RLS multiempresa.

## 5. Organizacion

Entidades:

- empresa;
- sucursal;
- departamento;
- posicion;
- configuracion de empresa;
- supervisor y asignaciones.

Web contiene pantallas y servicios de administracion organizacional. Android
sincroniza la estructura necesaria para operacion. Supabase conserva la
autoridad.

## 6. Empleados

Hace:

- alta y edicion;
- codigo autoritativo de seis digitos;
- asignacion organizacional;
- sincronizacion Android;
- carga offline con idempotencia;
- terminacion y reactivacion;
- auditoria del ciclo de vida;
- asociacion de usuario y biometria.

Edge Functions:

- `employee-management`
- `employee-sync`
- `employee-upsert`

Regla:

- el codigo de empleado se genera/valida en servidor;
- un empleado terminado no debe aparecer como candidato activo para acceso.

## 7. Accesos de usuario

Web permite listar candidatos, crear usuarios y administrar acceso mediante
`user-provisioning`.

Hace:

- listar empleados activos disponibles;
- crear el primer usuario aunque no existan accesos previos;
- aplicar rol y relacion con perfil;
- registrar auditoria;
- conservar tombstone de perfiles cuando aplica.

No hace:

- conceder permisos globales desde el cliente;
- usar estados de empleado inventados;
- modificar Supabase Auth directamente desde el navegador con privilegios.

## 8. Jornadas

Estados principales:

- `SIN_INICIAR`
- `EN_CURSO`
- `EN_PAUSA`
- `FINALIZADA`

Acciones:

- `INICIAR`
- `PAUSAR`
- `REANUDAR`
- `FINALIZAR`

Android:

- maquina de estados;
- prueba biometrica;
- firma ECDSA;
- Room;
- outbox;
- sincronizacion y conflictos.

Web:

- consulta por filtros;
- vista responsive;
- duracion en horas/minutos;
- acciones condicionadas a permisos;
- estados, carga, error y vacio.

Supabase:

- estado remoto;
- eventos;
- incidencias;
- conflictos;
- auditoria;
- correcciones controladas.

## 9. Dashboard supervisor

Hace:

- resuelve rol `SUPERVISOR`;
- exige permiso de supervisor;
- calcula metricas con alcance;
- acepta varios departamentos asignados;
- deniega departamentos ajenos;
- muestra mensaje funcional sin asignaciones.

No debe:

- requerir permiso administrativo;
- usar acceso global;
- filtrar solo en cliente.

## 10. Nomina

Web/Supabase:

- periodos;
- calculo;
- reglas;
- ajustes;
- descuentos;
- prestamos y creditos;
- cambios de estado;
- exportacion;
- auditoria;
- dashboard.

Android:

- configuracion y calculo local;
- historial Room;
- PDF/CSV.

Estado arquitectonico:

- el motor SQL y sus registros son oficiales;
- el motor Android es una implementacion paralela pendiente de alineacion;
- no se debe aprobar una nomina financiera solo con el resultado local.

## 11. Prestamos

Web/Supabase:

- solicitud desde portal;
- movimientos;
- aprobacion/rechazo;
- auditoria;
- integracion con nomina.

Android:

- entidades, DAO, repositorio y UI local.

Deuda:

- definir sincronizacion y equivalencia de estados;
- evitar dos historiales independientes.

## 12. Portal del empleado

Web:

- seleccion por rol `EMPLEADO`;
- datos del empleado;
- modulos visibles por permiso;
- solicitudes de prestamos.

Android:

- dashboard del empleado;
- jornadas y capacidades locales segun permiso;
- acceso desde resolver canonico.

Deuda:

- RRHH, NOMINA y AUDITOR usan actualmente un destino Web generico;
- completar experiencias dedicadas sin conceder permisos por rol.

## 13. Reportes

Hace:

- consulta de datos reales para jornadas, empleados y nomina;
- exportaciones en modulos concretos;
- vistas administrativas y supervisoras.

Estado: parcial.

Algunas vistas conservan campos de presentacion o ramas de solo lectura que
dependen del contrato disponible. Cada reporte debe validar origen, zona
horaria, moneda, filtros de empresa y permiso.

## 14. Kiosco Android

Hace:

- Device Admin/Device Owner;
- lock task;
- interfaz inmersiva;
- restauracion al arrancar;
- identidad criptografica del dispositivo;
- configuracion remota;
- marcacion por empleado y biometria.

El `/kiosco` Web usa datos mock y no es el kiosco oficial. Debe separarse como
demo o retirarse antes de considerarlo productivo.

## 15. Biometria facial

Hace:

- deteccion facial con ML Kit;
- embedding FaceNet de 128 dimensiones;
- cache local cifrada con Android Keystore;
- identificacion 1:N;
- politica de muestras consecutivas;
- sincronizacion remota y auditoria inicial.

No hace:

- liveness;
- deteccion de presentacion;
- garantia contra foto, pantalla o mascara.

## 16. Huella 2Connect

Hace:

- deteccion USB;
- apertura del lector;
- captura;
- enrolamiento;
- almacenamiento local de plantilla;
- comparacion con SDK del fabricante.

Estado: parcial hasta completar pruebas fisicas por modelo, version Android,
reconexion USB, permisos, calidad de huella y recuperacion despues de error.

## 17. Dispositivos y sincronizacion

Hace:

- codigo de enrolamiento;
- identidad del dispositivo;
- clave ECDSA;
- credencial cifrada;
- auditoria;
- sincronizacion de empleados;
- subida de empleados;
- sincronizacion de jornadas;
- reintentos con WorkManager.

La credencial de dispositivo no reemplaza la sesion de usuario para operaciones
de usuario. Cada endpoint valida su propio tipo de actor.

## 18. N8N y notificaciones

Eventos disponibles en el adaptador:

- cambio de departamento;
- cambio de supervisor;
- nomina generada;
- prestamo aprobado;
- prestamo rechazado;
- empleado desactivado.

Estado: base implementada. No hay garantia de entrega, workflows versionados o
auditoria remota en este repositorio.

## 19. Auditoria

Supabase contiene tablas de auditoria para dominios sensibles. La UI no expone
todavia una experiencia unificada de auditoria.

Toda nueva operacion sobre identidad, acceso, empleado, jornada, biometria,
nomina, prestamo o dispositivo debe identificar:

- actor;
- empresa;
- entidad;
- accion;
- fecha;
- resultado;
- correlation/idempotency ID cuando aplique.

## Biometría facial: estado final

El Terminal Android autorizado incorpora enrolamiento presencial por código de empleado, captura frontal/izquierda/derecha, liveness, control de duplicado y confirmación segura al servidor. La identificación 1:N exige liveness y `best_score >= face_match_threshold`; si `face_match_margin` tiene valor se exige además la diferencia best-vs-second, y si es `null` se omite solo ese filtro adicional. Web muestra estado y permite restablecimiento administrativo, pero no ofrece cámara ni QR de enrolamiento.

La ruta Web de kiosco/QR facial está retirada y no forma parte del producto final. Android no contiene Login, dashboard ni módulos administrativos.
