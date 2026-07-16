# AI_PROMPTS.md

# Prompt inicial obligatorio para Continue

```text
Lee primero:

AGENT_RULES.md
CONTINUE_PROJECT_RULES.md
PROJECT_CONTEXT.md
PROJECT_RULES.md
OSINET_PROJECT_GUIDE.md

No hagas cambios hasta terminar el análisis completo del proyecto actual.

Si el Workspace cambió:
- Olvida completamente el proyecto anterior.
- Reindexa el proyecto actual.
- No uses rutas anteriores.

Trabaja como Arquitecto de Software Senior.
No inventes clases.
No crees placeholders.
No elimines funcionalidades.
```

## Prompt para MissingType

```text
Investiga solamente.

Error:
[ksp] MissingType en AppDatabase.

No modifiques AppDatabase.

Lista:
- Entities en @Database
- DAOs declarados
- Primera clase faltante
- Paquete esperado
- Archivo existente o ausente

No crees placeholder.
No ejecutes Gradle.
```

## Prompt para botón sin pantalla

```text
Lee primero las reglas del proyecto.

Busca el botón indicado.
Busca si existe pantalla real.
Si existe, conecta navegación.
Si no existe, crea módulo completo.
No eliminar subbotones.
No usar placeholder.
```
