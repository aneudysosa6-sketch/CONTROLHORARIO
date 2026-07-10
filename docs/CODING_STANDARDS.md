# CODING_STANDARDS.md

# Estándares de código

## Kotlin

- Nombres claros.
- Funciones pequeñas.
- Evitar lógica pesada en Compose.
- Evitar duplicados.
- Usar data class para estados.
- Usar sealed class para acciones cuando aplique.

## Compose

- Pantalla recibe estado.
- Pantalla emite eventos.
- ViewModel procesa eventos.

## Room

- DAO solo consultas.
- Repository coordina DAO.
- Entity estable.

## Imports

No dejar imports viejos como:

```kotlin
import engine.*
import ui.*
```

Usar paquetes correctos del proyecto actual.
