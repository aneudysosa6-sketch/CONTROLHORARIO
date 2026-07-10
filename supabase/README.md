# Supabase de CONTROLHORARIO

## Estado

- `0001_FINAL.sql`: núcleo, organización e identidad.
- `0002_FINAL.sql`: empleados, permisos y RLS granular.
- `0003_FINAL.sql`: auditoría, provisioning y bootstrap.

La secuencia FINAL es un diseño de reemplazo y no fue ejecutada. `seed.sql` contiene únicamente capacidades globales; no crea empresas ni usuarios.
- Migraciones posteriores: solo planificadas en documentación; no existen todavía.

No crear tablas manualmente en el editor SQL remoto. Todo cambio se versiona en `migrations/`, se prueba con un stack local desde cero y se despliega de forma coordinada.

Antes de aplicar `0002`, consultar `docs/REVISION_MIGRACION_0002.md` y completar sus pruebas pendientes. El plano integral está indexado desde `docs/SUPABASE_DATABASE.md`.

`seed.sql` no crea usuarios ni contraseñas. Los secretos privilegiados no pertenecen al repositorio, Android o web.
