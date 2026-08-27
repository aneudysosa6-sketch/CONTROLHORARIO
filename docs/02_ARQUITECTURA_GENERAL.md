# ARQUITECTURA GENERAL

Última actualización: 2026-08-26

## 1. Contexto

CONTROL HORARIO separa operación física y administración:

- Android: Terminal autorizado, biometría y jornadas.
- Web: administración completa y portales autorizados.
- PostgreSQL: datos oficiales, contratos transaccionales, RLS y auditoría.
- Edge Functions: frontera privilegiada.
- Room/WorkManager: continuidad offline controlada.
- N8N: integración secundaria.

## 2. Diagrama lógico

- Empleado -> Android Terminal-only -> Edge Functions de Terminal -> PostgreSQL.
- Android Terminal-only -> Android Keystore.
- Android Terminal-only <-> Room y WorkManager.
- Usuario administrativo -> Web React/Vite -> Supabase Auth.
- Web -> PostgREST, RPC y Edge Web -> PostgreSQL.
- PostgreSQL -> RLS, SECURITY DEFINER y auditoría.

Android no consume Supabase Auth para su arranque visible. Su identidad
operativa es la credencial del Terminal más la clave P-256 del Keystore.

## 3. Responsabilidades

| Capa | Responsabilidad |
|---|---|
| Android UI | Registro, cámara, enrolamiento pendiente y jornada |
| Android seguridad | Keystore, firma, lease, revocación y salida protegida |
| Room | Cache cifrada y outbox; nunca autoridad remota |
| WorkManager | Sync idempotente y recuperación |
| Web | Administración, supervisión, portal y reportes |
| Supabase Auth | Identidad de usuarios Web |
| Edge | Validar JWT Web o credencial/firma Terminal según endpoint |
| PostgreSQL | Regla transaccional, tenant, alcance y auditoría |
| RLS | Denegación por defecto entre usuarios y empresas |

## 4. Navegación Android

El grafo visible solo resuelve:

1. Registro de dispositivo.
2. Cámara.
3. Terminal no autorizado.

Desde cámara se accede a:

- registro facial de pendientes;
- acción de jornada después de reconocimiento;
- salida protegida mediante gesto oculto.

El mantenimiento mínimo no es un dashboard y no concede administración.

## 5. Arranque

La política de arranque usa dispositivo, credencial y lease:

- sin identidad completa: registro;
- autorización válida dentro de lease: cámara;
- bloqueado, vencido o pendiente de revalidación obligatoria: no autorizado.

La validación y sincronización posteriores a un código válido no introducen una
pantalla visible intermedia.

## 6. Flujo facial

Alta:

Terminal -> código empleado -> tres poses -> liveness -> FaceNet-128 ->
Edge firmada -> RPC atómica -> plantilla remota -> cache local cifrada.

Identificación:

cámara -> liveness -> embedding -> comparación 1:N -> threshold -> margen
opcional -> empleado -> acción permitida.

El alta no crea una jornada. El empleado debe abandonar el cuadro y ser
reconocido de nuevo.

## 7. Flujo de jornada

Android persiste una transición local y un evento firmado. WorkManager envía:

- dispositivo y credencial;
- P-256;
- prueba biométrica;
- timestamp original;
- idempotency key;
- versión conocida.

Edge revalida dispositivo, tenant, sucursal, alcance, lease y firma. PostgreSQL
aplica INICIAR, PAUSAR, REANUDAR o FINALIZAR y devuelve accepted, duplicate,
conflict o rejected.

## 8. Face match

- Threshold obligatorio y primario.
- Liveness obligatorio.
- Margin best-vs-second opcional.
- Margin null no bloquea.
- Margin configurado se aplica como filtro adicional.
- Sin segundo candidato no hay comparación de margen.

El margin no es el alpha de triplet loss de entrenamiento FaceNet.

## 9. QR histórico

Las tablas de invitación permanecen por trazabilidad. Migración 0060:

- revoca pendientes;
- sustituye RPC antiguas por fallos cerrados;
- retira grants;
- evita creación, canje y finalización QR.

No se usa un teléfono personal para biometría ni jornadas.

## 10. Límites de seguridad

- service_role solo en Edge.
- Credenciales y claves privadas nunca salen del Terminal.
- Embeddings no se registran.
- No se guardan imágenes.
- El cliente no decide empresa efectiva.
- RLS no se sustituye por filtros de UI.
- SECURITY DEFINER fija search_path y grants.
- Los diagnósticos físicos no forman parte de release.

## 11. Entornos

- STAGING aceptado: [STAGING_PROJECT_REF].
- PRODUCCIÓN protegida: [PRODUCTION_PROJECT_REF].
- La promoción a producción es una fase separada.