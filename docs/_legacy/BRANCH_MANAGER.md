# BRANCH_MANAGER.md

# Encargado de Sucursal

## Estado

Implementado como rol de usuario con sucursal asignada.

## Alcance

- Puede abrir Panel Encargado.
- Puede ver empleados de su sucursal.
- Puede activar o desactivar empleados solo de su sucursal.
- Puede ver eventos de asistencia, eventos de supervisor y eventos internos relacionados.
- Puede abrir Activar modo PIN.
- No recibe permisos de Nómina por defecto.

## Datos

Usa AppUserEntity.branchId para asignar la sucursal.

## Sesión

La sesión queda guardada en el dispositivo después del login y se mantiene hasta tocar Cerrar sesión.
