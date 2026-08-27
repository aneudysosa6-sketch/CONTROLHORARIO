# Database Master Plan

Fuente canónica: `0001_FINAL.sql` → `0002_FINAL.sql` → `0003_FINAL.sql` → `seed.sql`. Core separa identidad Auth, profile empresarial y empleado laboral. Toda fila operativa lleva tenant; relaciones sensibles usan FK compuesta. El cliente nunca decide tenant ni escribe profiles. User Provisioning controla bootstrap y altas. Horarios, asistencia, solicitudes, nómina, Storage y Realtime permanecen como módulos versionados futuros: no se crean tablas sin cerrar previamente sus invariantes de negocio.

Principios: UUID servidor, `timestamptz`, UTC, RLS deny-by-default, permisos por capacidad y alcance, auditoría append-only, borrado restrictivo para históricos, secretos solo Edge, migraciones forward-only y Room como caché/offline, nunca fuente maestra cloud.

| Tabla | Propósito/dependencias | Usuarios |
|---|---|---|
| companies | tenant raíz | Web/Edge/Supabase; futura sync Android |
| roles | autorización; depende company | Web/Edge/RLS |
| branches/departments/positions | organización jerárquica | Android/Web/Room sync/nómina futura |
| profiles | Auth 1:1 y contexto tenant | Web/Auth/RLS/Edge |
| empleados | expediente; profile opcional | Android/Web/Room/Edge/nómina futura |
| permisos | catálogo global | Web/RLS/Edge |
| rol_permisos/perfil_permisos | grants base y overrides | RLS/Edge/Web admin |
| perfil_sucursales/perfil_departamentos | alcance adicional | RLS/Web supervisión |
| user_provisioning_audit | evidencia append-only | Edge/Web auditor autorizado |

Realtime no publica actualmente ninguna de estas tablas; Storage no depende de tablas hasta crear políticas de objetos. Nómina solo consume organización/empleados en una fase futura y no fue modificada.
