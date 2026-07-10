# MASTER_PROJECT_RULES.md

# OSINET Time ERP Enterprise

## Documento Maestro del Proyecto

## PRIORIDAD ABSOLUTA

Antes de modificar cualquier archivo, toda IA (Continue, ChatGPT,
Cursor, Claude, Gemini, etc.) debe leer en este orden:

1.  AGENT_RULES.md
2.  CONTINUE_PROJECT_RULES.md
3.  PROJECT_CONTEXT.md
4.  PROJECT_RULES.md
5.  ERP_MEMORY.md
6.  OSINET_PROJECT_GUIDE.md
7.  DATABASE.md
8.  MODULES.md
9.  NAVIGATION.md

No modificar ningún archivo hasta finalizar el análisis completo del
proyecto.

------------------------------------------------------------------------

## CAMBIO DE WORKSPACE

Si el usuario cambió la carpeta del proyecto:

-   Olvidar completamente el proyecto anterior.
-   Reindexar el Workspace.
-   Analizar nuevamente la estructura real.
-   Nunca reutilizar rutas o clases antiguas.

------------------------------------------------------------------------

## REGLAS PERMANENTES

-   Nunca eliminar módulos existentes.
-   Nunca reemplazar pantallas reales por placeholders.
-   Nunca inventar clases, métodos o propiedades.
-   No modificar AppDatabase hasta identificar exactamente el origen de
    un error MissingType.
-   Mantener arquitectura MVVM + Room + Jetpack Compose.
-   Cada botón debe tener una pantalla real.
-   Mantener el flujo:
    -   Inicio
    -   ADMINISTRADOR
    -   EMPLEADO

Empleado: - Solo registra asistencia. - Código automático (00001, 00002,
...). - Validación por huella. - Sin acceso al ERP.

Administrador: - Acceso total al ERP.

------------------------------------------------------------------------

## FORMA DE TRABAJAR DEL PROYECTO

Las modificaciones deben hacerse por módulos completos.

Cuando sea posible entregar:

-   Carpeta Android Studio completa del módulo.
-   Documentación.
-   Cambios realizados.
-   Errores comunes.

Nunca entregar código incompleto deliberadamente.

------------------------------------------------------------------------

## OBJETIVO

Construir un ERP Android profesional, estable, escalable y bien
documentado.
