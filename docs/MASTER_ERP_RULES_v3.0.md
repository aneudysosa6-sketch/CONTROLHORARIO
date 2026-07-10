# MASTER_ERP_RULES_v3.0

## Instrucción obligatoria
Leer primero este documento, luego AGENT_RULES.md y CONTINUE_PROJECT_RULES.md. No modificar archivos hasta terminar el análisis completo del Workspace.

## Regla de trabajo
- Trabajar siempre sobre el último ZIP del proyecto.
- Un módulo por entrega.
- No romper módulos funcionales.
- Mantener el proyecto compilando.

## Modo Kiosko protegido
El ponchador NO se cambia:

PIN -> Huella 2Connect -> Registrar jornada -> volver automáticamente a PIN.

La búsqueda por nombre o código solo aplica en módulos internos administrativos. El ponchador usa solo PIN/código + huella.

## Integración externa eliminada eliminado
Integración externa eliminada queda eliminado de la operación del ERP. No agregar botones, pantallas ni textos de Integración externa eliminada. Toda la lógica será interna del ERP.

## Usuarios
El módulo Usuarios reemplaza al módulo Supervisores como administración de usuarios. Permite crear administradores, supervisores, asistentes y empleados.

Los roles son descriptivos. Los permisos por módulo controlan el acceso.

## Portal del empleado
Cada empleado solo ve su propia información:
- Pagos
- Préstamos
- Historial
- Permisos
- Licencias médicas

## Préstamos
Un préstamo solo afecta el perfil del empleado y la nómina cuando se confirma ENTREGADO.

## Nómina
La nómina se calcula con datos de ponche y descuentos configurados. Los permisos comunes no afectan nómina.

## Licencias médicas
Módulo independiente. Si se aprueba, se indica inicio, fin y porcentaje interno. Al empleado solo se muestra Pago autorizado, no porcentaje.

## UI
Campo oscuro usa texto blanco. Campo claro usa texto negro.
