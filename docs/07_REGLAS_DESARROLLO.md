# REGLAS DE DESARROLLO

## 1. Alcance

Estas reglas aplican a Android, Web, Supabase, Edge Functions, N8N, scripts y
documentacion.

## 2. Antes de modificar

1. Leer [00_LEER_PRIMERO.md](./00_LEER_PRIMERO.md).
2. Confirmar el problema con evidencia real.
3. Identificar archivos exactos.
4. Identificar fuente de verdad y contrato.
5. Revisar migraciones y consumidores.
6. Separar causa raiz de sintomas.
7. Definir alcance y elementos que no se tocaran.
8. Definir validaciones y despliegue.

No se cambia codigo por intuicion.

## 3. Una sola fuente de verdad

- Auth: Supabase Auth.
- Autorizacion: `obtener_mi_autorizacion()`.
- Rol para navegacion: `role_code_canonical`.
- Permisos: `permission_codes`.
- Alcance: asignaciones remotas, RPC y RLS.
- Datos oficiales: PostgreSQL.
- Cache/offline Android: Room.
- Documentacion: esta carpeta.

Una copia de UI es derivada y reemplazable. No se convierte en autoridad.

## 4. Autenticacion

- No guardar contrasenas.
- Persistir solo tokens y expiracion necesarios.
- Usar la persistencia oficial de Supabase.
- Renovar token por el mecanismo oficial.
- Recargar autorizacion al iniciar.
- No borrar tokens por un error temporal de red.
- Limpiar sesion al cerrar, invalidarse o desactivarse la cuenta.
- No mezclar principal viejo con autorizacion nueva.

## 5. Roles, permisos y alcance

- Normalizar roles en servidor.
- Conservar original solo para diagnostico.
- Navegar con canonico.
- Autorizar con permiso explicito.
- No conceder por nombre de rol.
- No agregar bypass administrativo.
- No permitir cuando la lista requerida esta vacia.
- No calcular departamentos solo en cliente.
- RLS es obligatoria.

## 6. Base de datos

- No modificar migraciones historicas aplicadas.
- Crear una migracion nueva y secuencial.
- Confirmar columnas y tipos reales.
- Evitar SQL dinamico salvo necesidad justificada.
- Mantener funciones `SECURITY DEFINER` con `search_path` seguro.
- Revisar grants despues de reemplazar funciones.
- Mantener filtros de `company_id`.
- Agregar indices segun consultas reales.
- Incluir auditoria para acciones sensibles.
- Probar RLS positiva y negativamente.

## 7. Edge Functions

- `service_role` solo en entorno de servidor.
- Validar JWT o credencial de dispositivo dentro del handler cuando
  `verify_jwt=false`.
- No confiar en `company_id`, rol o permiso enviados por cliente.
- Validar input con esquema explicito.
- Usar idempotencia en operaciones repetibles.
- Responder errores funcionales estables.
- Configurar CORS con el minimo necesario.
- No devolver stack traces o secretos.
- Registrar actor, accion, resultado y correlation ID.

## 8. Android

- Mantener separadas UI, ViewModel, repositorio, API y almacenamiento.
- No acceder a Supabase directamente desde Composables.
- Room no autoriza.
- WorkManager debe tolerar reintentos.
- Toda mutacion offline necesita idempotencia.
- Las claves se guardan en Android Keystore.
- No guardar tokens o plantillas en texto plano.
- Navegar con el resolver unico.
- Evitar agregar rutas duplicadas a `AppNavigation`.

## 9. Web

- No consultar tablas protegidas para reconstruir autorizacion local.
- Usar `AuthProvider` como estado de sesion de UI.
- Los guards usan permisos remotos.
- El resolver de dashboard usa rol canonico.
- Ocultar menu no reemplaza guard.
- No usar datos mock en rutas productivas.
- No exponer secretos en variables `VITE_*`.
- Mantener TypeScript estricto y evitar `any`.
- Toda tabla debe tener version movil.

## 10. Nomina

- Los resultados oficiales son los persistidos por el motor SQL.
- No duplicar reglas nuevas en Android.
- Cualquier cambio requiere casos numericos reproducibles.
- Mantener trazabilidad de regla, periodo, ajuste y actor.
- No permitir neto negativo si el contrato vigente lo impide.
- Exportaciones deben reflejar exactamente el resultado persistido.

## 11. Biometria

- No registrar plantillas o embeddings.
- Cifrar datos locales.
- No transmitir sin TLS.
- Separar identificacion, verificacion y liveness.
- No afirmar liveness si no esta implementado.
- Proporcionar fallback autorizado.
- Auditar enrolamiento y reemplazo.
- Requerir pruebas con hardware para huella.

## 12. Errores y logs

UI:

- mensaje funcional;
- accion de recuperacion;
- sin SQL ni stack trace.

Log:

- componente/RPC;
- correlation ID;
- presencia de IDs;
- codigo tecnico;
- conteos no sensibles;
- resultado.

Prohibido:

- tokens;
- contrasenas;
- claves;
- plantillas biometricas;
- documentos completos;
- secretos de N8N.

## 13. Dependencias

- Fijar versiones para builds reproducibles.
- No introducir una libreria si la plataforma ya resuelve el problema.
- Revisar licencia y mantenimiento.
- No usar `latest` en nuevas dependencias.
- Actualizar lockfiles de forma intencional.
- Mantener SDK propietario aislado.

## 14. Codificacion y formato

- Archivos de texto: UTF-8 sin BOM.
- Final de linea coherente con el proyecto.
- No introducir binarios en fuentes.
- SQL y codigo: nombres estables y legibles.
- Documentacion: enlaces relativos dentro de `docs`.
- No guardar secretos en el repositorio.

## 15. Validaciones por capa

### Android

```powershell
.\gradlew.bat :app:testDebugUnitTest
.\gradlew.bat :app:assembleDebug
.\gradlew.bat :app:lintDebug
```

Cuando aplique:

- prueba con cierre total de la app;
- prueba sin red;
- prueba con cambio de rol;
- prueba en dispositivo 2Connect;
- prueba de camara y kiosco.

### Web

```powershell
cd web
pnpm run build
```

Ademas:

- rutas protegidas;
- refresh de pagina;
- movil/tablet/escritorio;
- sesion expirada;
- permiso retirado;
- estado vacio/error.

### Supabase

```powershell
supabase migration list --linked
supabase db push --linked
supabase functions list
```

`db push` y deploy remoto solo se ejecutan con el proyecto confirmado. Una
revision estatica no se reporta como despliegue.

### Seguridad

- RLS multiempresa;
- acceso anonimo;
- perfil inactivo;
- handler sin JWT;
- credencial de dispositivo invalida;
- ID de otra empresa;
- replay de idempotency key.

## 16. Definicion de terminado

Un cambio esta terminado cuando:

1. La causa raiz esta corregida.
2. No se amplio el alcance sin necesidad.
3. Contratos y consumidores coinciden.
4. Seguridad no se debilito.
5. Validaciones aplicables pasaron.
6. Despliegues requeridos se completaron y verificaron.
7. Errores de usuario son funcionales.
8. Logs no exponen datos sensibles.
9. Documentacion oficial fue actualizada.
10. Deudas restantes quedaron explicitas.

## 17. Cambios documentales

Actualizar:

- `01_ESTADO_PROYECTO.md` si cambia el estado real;
- `ARCHITECTURE_DECISIONS.md` si cambia una decision;
- `CHANGELOG.md` para un hito;
- `ROADMAP.md` para prioridades;
- guia de plataforma para contratos o comandos.

No crear reportes paralelos en `docs`. El contenido debe integrarse en uno de
los 17 documentos oficiales.
