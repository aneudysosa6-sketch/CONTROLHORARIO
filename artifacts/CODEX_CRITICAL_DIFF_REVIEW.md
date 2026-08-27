# Revision critica vigente del changeset

Fecha de reconciliacion: 2026-08-24
Alcance: evidencia pre-commit. No equivale a aprobacion de despliegue o produccion.

## A. RESUELTOS LOCALMENTE

| Requisito | Resolucion vigente | Evidencia |
|---|---|---|
| Terminal GENERAL | Sin filtro por sucursal del empleado; empresa define elegibilidad y la sucursal del terminal define ubicacion | Migracion 0050, Edge, Android/Web y tests contractuales |
| Terminal DEPARTMENTS | Sucursal mas uno o mas departamentos, revision/cursor y validacion server-authoritative | 0050, device-enrollment, employee-sync, attendance-sync y DevicesPage |
| Autorizacion inmediata | Revision de autorizacion y revalidacion Web/Android sin logout ni reinicio | 0050, AuthContext, SessionCoordinator y guardas |
| Licencias | Alta directa, porcentaje 0-100, dias calendario, edicion hacia adelante y cancelacion | 0050, Android/Web y politicas P0 |
| NO PAGAR | Intervalos demostrables; manual 0-8 solo cuando existe unicamente INICIAR; editable solo con nomina abierta | 0050, Android/Web y tests P0 |
| AJUSTES ANTERIORES | Captura idempotente, siguiente nomina y detalle de origen | 0050, wrapper de nomina y portal P0 |
| EMPLEADO EN LISTA NEGRA | Calculo mensual/reportes; no participa en bloqueo de marcaciones | 0050, servicio Web y politica P0 |
| Mensajes offline precargados | Cola cifrada, audio precargado, primera recepcion y tombstones | Employee sync, inbox Android y funciones 0049/0050 |

Estos puntos estan implementados localmente. Ninguno se declara validado E2E.

## B. PENDIENTES DE STAGING

| Evidencia pendiente | Motivo |
|---|---|
| Aplicar migraciones 0045 a 0050 en orden | No se realizaron operaciones remotas |
| Ejecutar pgTAP, incluido 0050 | Docker local no esta disponible y STAGING no fue autorizado |
| Validar RLS multiempresa | Requiere identidades y datos reales de dos empresas |
| Validar funciones SECURITY DEFINER | Requiere PostgreSQL real, grants y perfiles de sesion |
| Desplegar/probar Edge Functions | Requiere despliegue autorizado a STAGING |
| Probar autorizacion con sesiones simultaneas | Requiere usuarios reales y cambios concurrentes |
| Probar licencias, NO PAGAR, ajustes y lista negra con nomina real | Requiere periodos/datos STAGING |
| Validar Storage privado y borrado de audio | Requiere bucket y politicas remotas |

## C. PENDIENTES DE HARDWARE

| Evidencia pendiente | Motivo |
|---|---|
| Terminal GENERAL y DEPARTMENTS E2E | Requiere terminal enrolado |
| Reconocimiento facial | Requiere camara/modelo/iluminacion real |
| Lector TwoConnect | Requiere lector fisico autorizado |
| Lock task y salida de quiosco | Requiere politica real del dispositivo |
| Asistencia offline | Requiere desconexion controlada |
| Primera recepcion multi-terminal | Requiere al menos dos terminales |
| Audio/TTS offline | Requiere microfono, altavoz y archivos reales |

## D. DEUDA TECNICA REAL

| Prioridad | Deuda | Impacto |
|---|---|---|
| P1 | Paridad administrativa Android para roles personalizados no esta completa si se exige gestion total desde Android | Brecha local fuera de los contratos P0 |
| P2 | Artefactos/logs historicos conservan referencias sensibles de entorno y deben excluirse de commits | Riesgo de higiene del repositorio, no del APK vigente |
| P2 | Bundle Web contiene chunks superiores a 500 kB | Rendimiento inicial mejorable |
| P2 | Lint conserva advertencias no bloqueantes | Mantenibilidad; no hay errores de lint |
| P3 | Uso heredado de API Locale deprecada en TTS | Deuda de compatibilidad menor |

## Conclusion pre-commit

No queda un conflicto funcional P0 conocido en codigo local. Las validaciones externas anteriores impiden afirmar E2E o aptitud para produccion, pero no impiden preparar commits selectivos con revision de archivos mixtos.
