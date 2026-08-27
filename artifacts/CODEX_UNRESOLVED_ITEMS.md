# Elementos vigentes no resueltos

Fecha de reconciliacion: 2026-08-24

Los contratos P0 de Terminal GENERAL, Terminal DEPARTMENTS, autorizacion inmediata, Licencias, NO PAGAR, AJUSTES ANTERIORES, EMPLEADO EN LISTA NEGRA y mensajes offline precargados estan implementados localmente. No se registran como deuda local.

## PENDIENTE DE VALIDACION EXTERNA

| Prioridad | Elemento | Entorno requerido | Evidencia necesaria |
|---|---|---|---|
| P0 | Aplicar migraciones 0045 a 0050 en orden | STAGING | Respaldo, plan revisado, conteos y ejecucion sin errores |
| P0 | Ejecutar pgTAP, incluido 0050 | PostgreSQL local o STAGING | Resultado completo de pruebas SQL |
| P0 | Validar RLS multiempresa | STAGING | Casos positivos/negativos con dos empresas |
| P0 | Validar SECURITY DEFINER y grants | STAGING | Roles permitidos/denegados y alcance efectivo |
| P0 | Desplegar/probar Edge Functions | STAGING | Enrollment, sync y attendance contra 0050 |
| P0 | Validar autorizacion inmediata E2E | STAGING | Cambio de rol/permiso/alcance con sesiones abiertas |
| P0 | Validar licencias, NO PAGAR, ajustes y lista negra | STAGING | Periodos, jornadas y nominas reales |
| P1 | Terminal GENERAL/DEPARTMENTS | Hardware + STAGING | Enrolamiento, sync, ubicacion y rechazo literal |
| P1 | Camara, rostro, TwoConnect y quiosco | Hardware | Pruebas fisicas no destructivas |
| P1 | Offline y primera recepcion multi-terminal | Dos terminales | Desconexion, reconciliacion y tombstones |
| P1 | Audio/TTS real | Hardware + Storage STAGING | Precarga, reproduccion y borrado remoto |
| P1 | SMTP/recuperacion/notificaciones externas | Proveedores externos | Configuracion y entrega verificadas |
| P1 | Firma release | Custodia de claves | Keystore y procedimiento de distribucion |

## DEUDA LOCAL REAL

| Prioridad | Elemento | Impacto |
|---|---|---|
| P1 | Paridad administrativa Android de roles personalizados si se exige gestion completa en esa plataforma | Funcionalidad administrativa no P0 |
| P2 | Logs/artefactos historicos con referencias de entorno deben excluirse de commits | Higiene y riesgo de divulgacion |
| P2 | Bundle Web con chunks superiores a 500 kB | Rendimiento inicial |
| P2 | Advertencias lint no bloqueantes | Mantenibilidad |
| P3 | API Locale deprecada en flujo TTS heredado | Compatibilidad futura |

## Limites de la evidencia

- Implementado localmente no significa E2E.
- Ninguna migracion P0 fue aplicada a STAGING.
- pgTAP 0050 no fue ejecutado.
- No se instalo APK ni se operaron telefonos.
- Produccion `[PRODUCTION_PROJECT_REF]` no fue modificada.
