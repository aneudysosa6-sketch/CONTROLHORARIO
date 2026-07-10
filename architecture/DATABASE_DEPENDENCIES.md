# Database Dependencies

`extensions/private` → companies → roles/branches → departments → positions → profiles → empleados → permisos/asignaciones → RLS → provisioning audit/RPC → Edge Function → Web. Auth es dependencia externa de profiles. Android/Room consume DTOs después de API/sync, no FK cloud directas. Seed depende de permisos y roles; bootstrap depende del catálogo de permisos. Storage y Realtime dependen de profiles, tenant y permisos, pero no están habilitados todavía.
