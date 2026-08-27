# WEB ADMINISTRATIVA

Última actualización: 2026-08-26

## 1. Propósito

La Web cubre administración completa:

- empresas, sucursales y departamentos;
- empleados y horarios;
- usuarios, roles y permisos;
- dispositivos;
- asistencia y jornadas administrativas;
- nómina y pagos;
- préstamos;
- reportes;
- portal autorizado;
- seguridad y auditoría.

La Web no es un Terminal de jornadas.

## 2. Plataforma

- React.
- TypeScript.
- Vite.
- React Router.
- Supabase JS.
- jsPDF.
- XLSX.

Directorio: web.
Salida: web/dist.

## 3. Autenticación y autorización

Supabase Auth administra la sesión. AuthProvider hidrata la autorización
servidora. Los guards usan permisos efectivos y las operaciones remotas
revalidan empresa y alcance.

Variables públicas permitidas:

- VITE_SUPABASE_URL;
- VITE_SUPABASE_ANON_KEY o publishable key.

Nunca se usa service_role en Vite o navegador.

## 4. Rutas

Las rutas públicas se limitan al bootstrap y autenticación Web. Las rutas
administrativas están dentro de guards.

No existe una ruta pública de kiosco operativo.
No existe /enrolar-rostro.
No existe una cámara facial Web.
No existe generación o regeneración de QR facial.

## 5. Rostro en ficha de empleado

La ficha puede mostrar:

- PENDIENTE;
- ENROLADO;
- fecha de registro.

Un usuario con permiso y alcance puede eliminar la plantilla. El empleado
vuelve al conteo pendiente del Terminal en la siguiente sincronización.

La Web no captura rostro ni recibe credencial Terminal.

## 6. Ficha inicial

El PDF inicial puede indicar que el rostro está pendiente y debe registrarse en
un Terminal Android autorizado. No contiene:

- QR;
- token;
- URL pública de enrolamiento;
- credencial de dispositivo.

## 7. Seguridad

- CSP conecta únicamente con STAGING en el proyecto de preview.
- Referrer Policy no-referrer.
- X-Content-Type-Options nosniff.
- Frame ancestors none.
- Sin secretos en bundle.
- Sin tokens en URL.
- Sin modelos o runtimes faciales del flujo QR antiguo.
- Exportaciones neutralizan fórmulas peligrosas.

## 8. Pruebas vigentes

Los scripts de package.json cubren:

- código de empleado;
- alcance supervisor;
- dependencias Edge;
- seguridad de device enrollment;
- exportaciones;
- contratos P0;
- terminal-only;
- alta facial Terminal.

Build final:

pnpm install --frozen-lockfile
pnpm run build

## 9. Entornos

El preview STAGING usa exclusivamente [STAGING_PROJECT_REF]. Producción
[PRODUCTION_PROJECT_REF] no fue desplegada ni modificada durante esta aceptación.