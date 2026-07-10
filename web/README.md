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

Acceso demo: usuario `admin`, contraseña `Admin123!`. No es una credencial real y debe reemplazarse al conectar autenticación de servidor.

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
