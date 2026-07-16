# TODO maestro — CONTROLHORARIO

Fuente oficial: `docs/`. Prioridades derivadas de la auditoría estática de 2026-07-16. Esta lista no autoriza cambios funcionales por sí sola; cada ítem requiere análisis de impacto conforme a `01_MASTER_PROJECT_RULES.md`.

## P0 — Bloqueantes de seguridad y puesta en marcha

- [ ] Confirmar en un entorno aislado el estado real de Supabase frente a las migraciones `0001_FINAL.sql` a `0013_employee_portal_loans.sql`.
- [ ] Aplicar y validar la cadena completa sólo mediante el proceso autorizado; no mezclar `migrations_archivadas`.
- [ ] Ejecutar pruebas de RLS con dos empresas, usuario inactivo, permisos mínimos, alcance de supervisor y denegación de acceso biométrico/dispositivo.
- [ ] Validar los grants y el acceso efectivo de cada RPC, especialmente las redefinidas en migraciones posteriores.
- [ ] Desplegar y probar de forma controlada `user-provisioning`, `employee-management`, `device-enrollment`, `employee-sync` y `attendance-sync`.
- [ ] Revisar las funciones con `verify_jwt=false`: autenticación propia, credencial revocada, replay, límites y auditoría.
- [ ] Establecer una configuración reproducible y segura para URLs, claves publicables y secretos de Edge Functions.

## P1 — Integridad de jornadas, biometría y offline

- [ ] Probar lector 2Connect real: USB, calidad, registro, coincidencia, PIN+huella, desconexión y recuperación.
- [ ] Probar kiosco Android y salida administrativa sin debilitar PIN + huella.
- [ ] Probar enrolamiento Android, revocación, renovación/reintento y sincronización paginada de empleados.
- [ ] Validar outbox de jornadas: idempotencia, reintentos, 4xx/5xx, conflictos, reanudación y convergencia de estados.
- [ ] Definir el contrato definitivo de sincronización biométrica sin transferir plantilla o imagen a Web.
- [ ] Verificar que datos locales heredados de PIN/biometría tienen un plan de migración seguro antes de producción.

## P1 — Nómina y préstamos

- [ ] Designar y documentar la fuente de verdad de cálculo de nómina entre Android local y motor SQL RC4.
- [ ] Crear casos dorados de nómina y probar paridad centavo a centavo de salarios, horas, descuentos, préstamos y créditos.
- [ ] Validar transiciones Calculada → Revisada → Aprobada → Cerrada y su auditoría.
- [ ] Validar que sólo jornadas finalizadas y sin revisión pendiente entran a nómina.
- [ ] Completar las pruebas de exportación PDF/XLSX y autorización de descarga.
- [ ] Alinear préstamos locales Android con `prestamo_solicitudes`, movimientos y descuentos de nómina Supabase.

## P1 — Consolidación de clientes

- [ ] Consolidar el portal de empleado Android: conservar únicamente la ruta conectada a RPC después de verificar paridad; retirar la implementación embebida heredada de forma segura.
- [ ] Aclarar o unificar responsabilidades entre `employee-sync` y la acción homónima en `device-enrollment`.
- [ ] Dividir `AppNavigation.kt` por dominio conservando rutas y protecciones existentes.
- [ ] Completar la validación de administración Android/Web contra permisos y alcance reales.

## P2 — Módulos oficiales pendientes de madurez

- [ ] Completar reportes conectados de asistencia, nómina, productividad e incidencias.
- [ ] Unificar el centro de eventos/auditoría para Android, Web y Supabase.
- [ ] Validar el portal empleado: perfil, ganancias, préstamos y solicitud; sin exponer jornadas, conforme a `10_PORTAL_EMPLEADO.md`.
- [ ] Validar el flujo completo de vacaciones y permisos contra reglas de asistencia y nómina.
- [ ] Validar horarios, calendario laboral único, feriados y jornadas editables sólo durante 30 días.

## P2 — Calidad, deuda técnica y entrega

- [ ] Sustituir wrappers RPC repetidos de Web por una infraestructura común con errores tipados y telemetría.
- [ ] Revisar `web/src/services/storage.ts` como candidato a código muerto.
- [ ] Revisar `ModuleScreen` embebido en navegación como candidato a código muerto.
- [ ] Confirmar referencias antes de retirar `mockData`, `OperationsPages`, artefactos `vite.config.js`/`.d.ts` y `*.tsbuildinfo`.
- [ ] Mantener `docs/_legacy`, `app/*_DOCS` y migraciones archivadas claramente separados de la documentación/cadena vigente.
- [ ] Fijar versiones de dependencias Web en lugar de `latest` para builds reproducibles.
- [ ] Convertir scripts estáticos en una pirámide de pruebas: SQL/RLS, Edge Function, Web integrado, Android y hardware.
- [ ] Actualizar esta lista y `PROJECT_ANALYSIS.md` tras cada despliegue, decisión de arquitectura o cierre de módulo.
