# Supabase de CONTROLHORARIO

## Estado

- `0001_initial_schema.sql`: informada como ejecutada en Supabase.
- `0002_empleados_permisos_portal.sql`: revisada y corregida, pero **no ejecutada**.
- Migraciones posteriores: solo planificadas en documentación; no existen todavía.

No crear tablas manualmente en el editor SQL remoto. Todo cambio se versiona en `migrations/`, se prueba con un stack local desde cero y se despliega de forma coordinada.

Antes de aplicar `0002`, consultar `docs/REVISION_MIGRACION_0002.md` y completar sus pruebas pendientes. El plano integral está indexado desde `docs/SUPABASE_DATABASE.md`.

`seed.sql` no crea usuarios ni contraseñas. Los secretos privilegiados no pertenecen al repositorio, Android o web.
