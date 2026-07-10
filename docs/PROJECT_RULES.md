# PROJECT_RULES.md

## Reglas generales

1. Nunca eliminar funcionalidades existentes.
2. Nunca reemplazar pantallas sin leerlas completas.
3. Nunca inventar clases.
4. Nunca inventar propiedades.
5. Nunca crear placeholders.
6. Nunca modificar AppDatabase sin revisar todas las entidades y DAOs.
7. Mantener arquitectura MVVM.
8. Mantener Room como persistencia local.
9. Mantener Compose como UI.
10. Todo módulo debe ser escalable.

## Regla de módulos

Cada módulo profesional debe incluir:

- Entity
- DAO
- Repository
- Engine
- ViewModel
- ViewModelFactory
- Compose Screen
- Navigation
- Documentación

## Regla de navegación

Cada botón visible debe tener destino real.

Si un botón abre un submenú, los subbotones deben conservarse.

## Regla de compilación

Cada cambio debe dejar el proyecto en estado compilable.

Si no se puede compilar, documentar el primer error y la causa probable.
