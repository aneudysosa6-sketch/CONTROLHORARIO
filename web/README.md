# CONTROL HORARIO - Panel Web

Panel administrativo de CONTROL HORARIO para empleados, horarios, asistencia,
nómina, reportes, organización, usuarios, permisos y dispositivos.

La Web no es un Terminal de jornadas y no realiza enrolamiento facial público.

## Tecnologías

- React.
- TypeScript.
- Vite.
- React Router.
- Supabase JS.
- jsPDF.
- XLSX.

## Configuración local

Desde web:

pnpm install --frozen-lockfile
pnpm run dev

Variables públicas:

- VITE_SUPABASE_URL;
- VITE_SUPABASE_ANON_KEY o publishable key.

Nunca configure service_role en una variable VITE.

## Autenticación

El panel usa Supabase Auth. El usuario debe tener perfil activo, empresa, rol
activo y permisos efectivos. Los guards de UI no sustituyen RLS ni validación
RPC.

## Rostro

La ficha de empleado muestra PENDIENTE o ENROLADO y permite eliminar el rostro
solo con permiso y alcance. El nuevo rostro se registra exclusivamente en un
Terminal Android autorizado.

No existen:

- QR facial;
- token público;
- ruta /enrolar-rostro;
- cámara facial Web;
- credencial Terminal en navegador.

El PDF inicial puede indicar registro pendiente, pero no contiene QR o token.

## Pruebas y build

Ejecute todos los scripts test definidos en package.json y luego:

pnpm run build

La salida se genera en dist.

## Vercel

- Root Directory: web.
- Framework: Vite.
- Output: dist.
- Variables separadas por entorno.
- CSP y connect-src deben apuntar solo al proyecto Supabase del entorno.
- Ningún deploy STAGING autoriza sobrescribir producción.

## Seguridad

- No versionar .env.
- No exponer tokens, contraseñas o claves privadas.
- No guardar autorización como fuente local.
- No registrar payloads sensibles.
- Neutralizar fórmulas en exportaciones.
- Mantener HTTPS, CSP, no-referrer y frame-ancestors none.