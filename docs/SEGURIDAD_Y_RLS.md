# Seguridad y RLS

## Identidad y contexto

`auth.uid()` identifica; `profiles` aporta empresa/rol/estado; `empleados.perfil_id` aporta expediente. Helpers `SECURITY DEFINER` mínimos consultan estas tablas para evitar recursión. Siempre `search_path=''`, nombres con esquema, `REVOKE ALL ... FROM PUBLIC` y `GRANT EXECUTE TO authenticated` solo cuando el cliente necesita invocarlos.

## Resolución

1. Usuario y profile activos.
2. Empresa desde profile, nunca del body.
3. Permiso efectivo: perfil > rol > false.
4. Alcance máximo: propio/departamento/sucursal/empresa/global.
5. Conjuntos adicionales en `perfil_departamentos`/`perfil_sucursales`.
6. RLS exige tenant y alcance; ocultar UI no cuenta.

## Grupos RLS

| Grupo | Lectura cliente | Escritura cliente |
|---|---|---|
| Organización | propia empresa según permiso | administración limitada; operaciones sensibles RPC |
| Profiles/permisos | propio; administradores con capacidad | terceros autorizados, nunca auto-escalación |
| Empleados | propio/D/S/E | columnas no sensibles; salario/PIN/enlace por servidor |
| Horarios | propio o alcance | RPC/admin autorizado |
| Asistencia | propio o alcance | `register-attendance`; correcciones separadas |
| Solicitudes | propio/aprobadores | transición mediante RPC |
| Nómina | propia o roles específicos | solo Edge/RPC |
| Auditoría/seguridad | auditor autorizado | solo funciones/triggers servidor |
| Sync | propio dispositivo/tenant | RPC idempotente |

Nunca `USING (true)` para `authenticated`. `anon` no accede a tablas empresariales. Tablas globales se administran por migración o backend `super_admin`.

## Operaciones Edge/RPC

Aprovisionar usuarios, enlazar empleado, verificar PIN, registrar/corregir asistencia, cambiar salario/empresa/rol, procesar/aprobar nómina, generar exportaciones, subir documentos privados y revocar sesiones. Las funciones validan JWT y permiso; una clave privilegiada solo puede existir como secreto de servidor, nunca en Android/web/logs.

## PIN y biometría

- PIN: Argon2id preferido o bcrypt con costo vigente, salt único, comparación servidor, rate limit por empleado/dispositivo/IP, bloqueo temporal y auditoría sin valor ingresado.
- Room actual contiene `Employee.pin`; debe retirarse antes de producción conectada.
- La huella no se almacena como imagen ni plantilla en Supabase. `EmployeeBiometricEntity.templateBase64` no se sincroniza y debe migrarse/eliminarse de Room.
- Android confirma BiometricPrompt y vincula el resultado a dispositivo autorizado, nonce y ventana temporal; una bandera booleana aislada no prueba identidad.

## Autenticación

Alta por invitación/backend; profile y empleado se enlazan transaccionalmente. Recuperación usa Supabase Auth. Desactivar profile bloquea RLS y dispara revocación de sesiones/dispositivos. Cambios de correo/contraseña requieren reautenticación. MFA obligatorio para administración/nómina en fase productiva.

## Datos sensibles

Restringidos/cifrados: cuentas bancarias, fiscalidad, salario, documentos, IP, tokens y secretos. Auditoría excluye hashes, tokens, PIN y binarios. HTTPS obligatorio. Backups cifrados y pruebas periódicas de restauración.

## Hallazgos locales inmediatos

`SupervisorEntity.password`, `AppUserEntity.password` y `Employee.pin` conservan formatos heredados en Room. No se sincronizan y no deben recibir credenciales nuevas. La contraseña dejó de duplicarse en SharedPreferences; al guardar una sesión también se elimina la clave heredada. Las entidades N8N/WhatsApp con secretos están fuera de `AppDatabase` y corresponden a integraciones obsoletas.

La migración segura pendiente debe ser transaccional: añadir hashes con salt, migrar al validar la credencial heredada, comprobar todos los lectores, retirar columnas antiguas y destruir valores solo después de verificar respaldo y rollback. `EmployeeBiometricEntity.templateBase64` se mantiene exclusivamente para compatibilidad temporal con 2Connect: no se crean formatos nuevos, no se trata como imagen y no se sincroniza. `BiometricPrompt` permanece respaldado por el almacén seguro del sistema.
