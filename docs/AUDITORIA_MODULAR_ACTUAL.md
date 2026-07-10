# Auditoría modular actual

| Módulo | Android/Room | Web | Supabase | Clasificación / dependencia principal |
|---|---|---|---|---|
| Login/usuarios | AppUser local, password legado | login demo/localStorage | Auth diseñado, no integrado | parcial; requiere migración segura |
| Empleados | CRUD, ficha, documentos, nómina, huella | CRUD demo funcional | `empleados` en 0002 pendiente | funcional local / web simulado |
| Organización | branches/departments/settings | configuración visual | 0001 ejecutada | parcial; adaptadores pendientes |
| Kiosco/PIN | real, PIN 5 dígitos | flujo PIN demo | Edge futura | Android funcional; web simulado |
| Biometría | BiometricPrompt + 2Connect real | mensaje informativo correcto | no debe almacenar plantilla | funcional crítico/protegido |
| Asistencia | eventos Room y cuatro acciones | tabla/jornadas demo | plan 0004 | funcional local; central pendiente |
| Horarios | plantilla y supervisor schedule | visual | plan 0003 | parcial/duplicado |
| Incidencias/correcciones | PendingAttendanceReview | no completo | plan 0004 | parcial |
| Vacaciones | Entity/DAO/UI | no pantalla dedicada | plan 0005 | funcional local, central pendiente |
| Permisos/licencias | solicitudes, adjuntos, porcentaje ingresado | no completo | plan 0005 | parcial; no inventar porcentaje |
| Préstamos | Entity/DAO/Repository/Engine/UI | no | futuro no planificado aún | funcional local |
| Nómina | motores, configuración, historial, PDF/export | carga/proceso demo/CSV | plan 0006 | funcional local parcial; web simulado |
| Reportes | asistencia/nómina/PDF | demo | plan H/0006+ | parcial |
| Supervisores | entidades/pantallas/permisos duplicados | no | roles/alcances 0002 | requiere reorganización |
| Notificaciones | AppEvent; outboxes legados | icono demo | plan 0008 | parcial/legado |
| Sincronización | N8N entities no registradas | ninguna | plan 0010 | obsoleto/pending |
| Auditoría | eventos parciales | ninguna | plan 0009 | pendiente |

## Hallazgos de código

- `AppNavigation.kt` concentra rutas y pantallas auxiliares: funcional pero requiere extracción gradual.
- 28 clases `@Entity`; cinco no están registradas en `AppDatabase` v26: `SupervisorDepartmentEntity`, `N8NSettingsEntity`, `N8NOutboxEntity`, `N8NSyncLogEntity`, `WhatsAppOutboxEntity`.
- `Employee.pin`, `AppUserEntity.password`, `SupervisorEntity.password` y `EmployeeBiometricEntity.templateBase64` son riesgos locales; no deben llegar a Supabase.
- La web tiene páginas operativas y botones con acción, pero servicios/datos/autenticación son simulados.
- `0001` está reportada como ejecutada; `0002` está corregida pero no probada ni ejecutada.
- Reglas de nómina usan valores configurables existentes; no se modificaron porcentajes o fórmulas.

## TODO prioritario

1. Tests instrumentados del lector/ponche.
2. Resolver entidades Room no registradas y credenciales legadas mediante migraciones específicas.
3. Integrar Supabase Auth y contratos typed sin borrar mocks hasta validar.
4. Extraer navegación Android por feature manteniendo rutas/adaptadores.
5. Implementar asistencia central append-only antes de nómina central.
