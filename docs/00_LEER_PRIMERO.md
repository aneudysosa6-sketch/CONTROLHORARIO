# CONTROL HORARIO - LEER PRIMERO

Estado: documentacion oficial  
Ultima auditoria integral: 2026-07-27  
Alcance: Android, Web, Supabase, Edge Functions, N8N y operacion

## 1. Proposito

Esta carpeta es la fuente documental oficial de CONTROL HORARIO. Sustituye las
auditorias, reglas, hojas de ruta y documentos historicos que existian antes de
la consolidacion del 2026-07-27.

Una nueva sesion de trabajo debe comenzar con:

> Lee `docs/00_LEER_PRIMERO.md` y sigue el orden de lectura indicado.

No se debe usar una copia antigua, un documento externo o una conversacion
anterior como autoridad si contradice este conjunto.

## 2. Regla de autoridad

La prioridad de evidencia es:

1. Estado real del codigo y del entorno desplegado.
2. Contratos de base de datos y migraciones aplicadas.
3. Esta documentacion oficial.
4. Comentarios de codigo, reportes y conversaciones anteriores.

Si el codigo real contradice esta documentacion, no se debe ocultar la
diferencia. Se debe detener el cambio, confirmar el comportamiento real y
actualizar el documento afectado en el mismo trabajo.

## 3. Orden obligatorio de lectura

| Orden | Documento | Motivo |
|---|---|---|
| 1 | [00_LEER_PRIMERO.md](./00_LEER_PRIMERO.md) | Reglas de uso de la documentacion |
| 2 | [PROJECT_CONSTITUTION.md](./PROJECT_CONSTITUTION.md) | Principios no negociables |
| 3 | [01_ESTADO_PROYECTO.md](./01_ESTADO_PROYECTO.md) | Estado real y deudas actuales |
| 4 | [02_ARQUITECTURA_GENERAL.md](./02_ARQUITECTURA_GENERAL.md) | Limites, flujos y fuentes de verdad |
| 5 | [03_AUTENTICACION_Y_AUTORIZACION.md](./03_AUTENTICACION_Y_AUTORIZACION.md) | Sesion, roles, permisos y alcance |
| 6 | [04_BASE_DATOS.md](./04_BASE_DATOS.md) | Esquema, migraciones, RPC y RLS |
| 7 | [05_MODULOS_IMPLEMENTADOS.md](./05_MODULOS_IMPLEMENTADOS.md) | Inventario funcional por modulo |
| 8 | [ARCHITECTURE_DECISIONS.md](./ARCHITECTURE_DECISIONS.md) | Decisiones aceptadas y pendientes |
| 9 | Documento de plataforma | Android, Web, Supabase, N8N o despliegue |
| 10 | [07_REGLAS_DESARROLLO.md](./07_REGLAS_DESARROLLO.md) | Forma segura de implementar |
| 11 | [ROADMAP.md](./ROADMAP.md) | Prioridades posteriores |
| 12 | [CHANGELOG.md](./CHANGELOG.md) | Hitos relevantes |

Documentos de plataforma:

- [06_UI_UX_GUIDE.md](./06_UI_UX_GUIDE.md)
- [08_ANDROID.md](./08_ANDROID.md)
- [09_WEB.md](./09_WEB.md)
- [10_SUPABASE.md](./10_SUPABASE.md)
- [11_N8N.md](./11_N8N.md)
- [12_DEPLOYMENT.md](./12_DEPLOYMENT.md)

## 4. Resumen ejecutivo del sistema

CONTROL HORARIO es una plataforma de gestion laboral con:

- Aplicacion Android para operacion, kiosco, marcacion, biometria y trabajo
  con conectividad intermitente.
- Aplicacion Web para administracion, supervision, empleados, jornadas,
  nomina, prestamos, reportes y configuracion organizacional.
- Supabase Auth como identidad y PostgreSQL como fuente remota de datos,
  autorizacion, alcance y auditoria.
- Edge Functions como frontera privilegiada para operaciones que requieren
  `service_role` o credenciales de dispositivo.
- Un adaptador Web para notificaciones hacia N8N. Los workflows de N8N no
  forman parte del repositorio y todavia no constituyen un subsistema
  operativo completo.

## 5. Fuentes de verdad no negociables

| Dato | Fuente oficial |
|---|---|
| Identidad autenticada | Supabase Auth |
| Perfil, empresa y estado de cuenta | PostgreSQL/Supabase |
| Rol vigente | `public.obtener_mi_autorizacion()` |
| Codigo de rol para navegar | `role_code_canonical` |
| Permisos | `permission_codes` devuelto por autorizacion remota |
| Sucursales y departamentos visibles | Asignaciones remotas, RPC y RLS |
| Tokens de sesion | Persistencia oficial de Supabase Auth |
| Jornadas remotas | Tablas y RPC de jornadas en Supabase |
| Cola Android sin conexion | Room y WorkManager, hasta sincronizar |
| Resultados oficiales de nomina | Registros persistidos por el motor SQL |
| Documentacion | Los 17 archivos de esta carpeta |

## 6. Reglas criticas antes de cambiar codigo

1. No modificar una migracion historica ya aplicada.
2. Crear una migracion nueva para cualquier cambio de esquema o funcion SQL.
3. No guardar roles, permisos, empresa, departamentos o alcance como fuente
   persistente de autorizacion.
4. Restaurar tokens y volver a consultar autorizacion remota antes de navegar.
5. Navegar con `role_code_canonical`, nunca con nombre de rol ni alias local.
6. Autorizar con codigos de permiso remotos, nunca por apariencia de rol.
7. Calcular el alcance del supervisor en servidor y reforzarlo con RLS.
8. No usar `service_role` en Android, Web ni otro cliente publico.
9. No desactivar RLS para resolver un problema funcional.
10. No duplicar normalizacion de roles, permisos o reglas de alcance.
11. No registrar tokens, contrasenas, plantillas biometricas ni datos
    personales sensibles.
12. Actualizar esta documentacion cuando cambie un contrato real.

## 7. Estado que debe conocerse antes de empezar

- Las migraciones `0001` a `0029` aparecen aplicadas en el proyecto Supabase
  vinculado al momento de la auditoria.
- `0030_fix_employee_role_canonicalization.sql` existe localmente y su
  aplicacion remota esta pendiente.
- Android contiene una compatibilidad transitoria para los alias
  `EMPLEADOS`, `EMPLOYEE` y `EMPLOYEES`.
- La arquitectura de sesion Android ya persiste tokens y recarga la
  autorizacion desde Supabase.
- La Web usa el RPC unificado, pero conserva adaptadores locales y un bypass
  administrativo que deben eliminarse en un trabajo posterior controlado.
- Android y SQL tienen implementaciones de calculo de nomina. El resultado
  oficial es el persistido en Supabase; la duplicacion sigue siendo una deuda.
- El reconocimiento facial no implementa deteccion de vida.
- La integracion N8N es un adaptador no bloqueante desde Web; no hay workflows
  versionados en este repositorio.

El detalle y la prioridad de cada punto estan en
[01_ESTADO_PROYECTO.md](./01_ESTADO_PROYECTO.md).

## 8. Convencion de estado

Los documentos usan estas etiquetas:

| Estado | Significado |
|---|---|
| Operativo | Implementado y utilizado por el flujo actual |
| Parcial | Implementado, pero falta cobertura, despliegue o una rama funcional |
| Base implementada | Existe infraestructura, no una capacidad completa |
| Pendiente de validar | El codigo existe, pero no hay evidencia suficiente del entorno real |
| Legacy/no productivo | Existe, pero no debe considerarse parte del producto oficial |

## 9. Criterio para una nueva tarea

Antes de editar:

1. Identificar la fuente de verdad afectada.
2. Leer el documento de arquitectura y el de plataforma correspondiente.
3. Confirmar si existe una decision registrada.
4. Revisar el codigo real una sola vez y no trabajar por intuicion.
5. Proponer el cambio minimo que preserve seguridad y compatibilidad.
6. Definir pruebas y despliegue antes de modificar.

Despues de editar:

1. Ejecutar las validaciones aplicables.
2. Registrar cualquier despliegue realmente realizado.
3. Actualizar los documentos afectados.
4. Agregar un hito a `CHANGELOG.md` solo si el cambio es relevante.
5. Ajustar `ROADMAP.md` si cambia una prioridad o deuda.

## 10. Alcance de esta consolidacion

La auditoria documental no cambio Android, Web, Supabase, Edge Functions ni
N8N. Describe el estado encontrado y establece el contrato para trabajos
futuros. Los estados remotos son una fotografia del 2026-07-27 y deben
confirmarse de nuevo antes de un despliegue.
