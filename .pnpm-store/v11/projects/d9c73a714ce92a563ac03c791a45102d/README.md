# OSINET Time ERP Enterprise — Panel web

Panel administrativo responsive de CONTROLHORARIO para empleados, asistencia, jornadas, reportes, nómina y configuración. Esta primera versión usa datos demostrativos y una capa de servicios preparada para sustituirse por una API.

## Tecnologías

- React, TypeScript, Vite y React Router.
- CSS mantenible con diseño responsive.
- `localStorage` exclusivamente para sesión y datos temporales de demostración.

## Uso local

```bash
npm install
npm run dev
```

## Autenticación

El panel usa Supabase Auth con correo y contraseña. Copie `.env.example` a `.env.local` y configure `VITE_SUPABASE_URL` y `VITE_SUPABASE_PUBLISHABLE_KEY`. La clave `service_role` nunca debe usarse en el navegador.

El usuario debe existir en Auth y tener un `profiles` activo, un rol activo y el permiso efectivo `portal.acceder`. No existen credenciales demo ni se guardan contraseñas en `localStorage`.

### Bootstrap inicial

Cuando el primer usuario Auth todavía no tiene profile, abra `/bootstrap`. Inicie sesión y complete la configuración inicial usando el secreto temporal configurado directamente en la Edge Function. El secreto no se configura como variable Vite ni se persiste en el navegador. Después del éxito, elimine o rote `USER_PROVISIONING_BOOTSTRAP_SECRET` en Supabase.

## Compilación

```bash
npm run build
```

La salida se genera en `dist/`. Para previsualizarla: `npm run preview`.

## Despliegue en Vercel

1. Importar el repositorio en Vercel.
2. Seleccionar **Root Directory:** `web`.
3. Framework Preset: **Vite**.
4. Build Command: `npm run build`.
5. Output Directory: `dist`.
6. Install Command: `npm install` (o automático).

`vercel.json` redirige las rutas a `index.html` para que React Router funcione al recargar.

## Seguridad

No subir archivos `.env`, contraseñas reales, tokens ni claves privadas. La autenticación y los datos actuales son demostrativos; antes de producción se debe conectar una API segura, aplicar autorización por rol en servidor y reemplazar `localStorage` para datos empresariales.
