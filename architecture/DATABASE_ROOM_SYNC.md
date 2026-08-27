# Database Room Sync

Supabase será fuente maestra; Room mantiene operación offline. IDs cloud UUID y IDs Room actuales requieren tabla de mapeo durante transición. Sync futuro necesita outbox idempotente, `updated_at`, tombstones, cursor servidor y conflictos por versión. PIN/plantilla 2Connect heredados nunca se suben. No cambiar lector, BiometricPrompt, kiosco ni cuatro eventos. Nómina no se sincroniza hasta definir autoridad y cierre inmutable.
