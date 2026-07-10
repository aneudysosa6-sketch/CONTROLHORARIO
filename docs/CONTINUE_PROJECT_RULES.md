# CONTINUE_PROJECT_RULES.md

# Reglas obligatorias para Continue
## OSINET Time ERP Enterprise

## Instrucción inicial obligatoria

Antes de cualquier cambio, Continue debe leer:

1. AGENT_RULES.md
2. CONTINUE_PROJECT_RULES.md
3. PROJECT_CONTEXT.md
4. PROJECT_RULES.md
5. OSINET_PROJECT_GUIDE.md

No modificar ningún archivo hasta terminar el análisis completo del proyecto actual.

## Cambio de carpeta o Workspace

Si el usuario cambió la carpeta del proyecto:

- Olvidar completamente el proyecto anterior.
- No reutilizar rutas viejas.
- No reutilizar clases viejas.
- No usar memoria de conversaciones anteriores.
- Reindexar el Workspace actual.
- Analizar la estructura real del proyecto abierto.

## Prohibido

Continue NO puede crear:

- PlaceholderScreen
- FakeScreen
- DemoScreen
- SampleScreen
- NavigationButton inventado
- FakeRepository
- FakeDAO
- FakeEntity
- FakeViewModel
- Clases vacías solo para compilar

## Regla KSP MissingType

Si aparece:

```text
[ksp] [MissingType]: Element 'com.example.controlhorario.database.AppDatabase' references a type that is not present
```

NO modificar AppDatabase primero.

Primero identificar:

- Qué Entity falta.
- Qué DAO falta.
- Qué clase no compila.
- Qué import está mal.
- Qué paquete no coincide.

## Arquitectura obligatoria

Nunca acceder al DAO desde Compose.

Flujo obligatorio:

```text
Compose Screen
↓
ViewModel
↓
Repository
↓
DAO
↓
Room
```

## Pantallas

No eliminar pantallas existentes.  
No eliminar botones existentes.  
No eliminar submenús.  
Si un botón no tiene pantalla, crear pantalla real siguiendo estilo OSINET.

## AppNavigation

No reemplazar AppNavigation con un placeholder.  
No dejar pantalla blanca.  
No crear menú básico temporal si existe navegación real.  
Primero revisar pantallas existentes.

## Administrador / Empleado

La app debe iniciar con:

- ADMINISTRADOR
- EMPLEADO

Administrador accede al ERP completo.  
Empleado solo accede al flujo de ponche.

## Empleado

Flujo:

```text
Ingresar código
↓
Buscar empleado
↓
Solicitar huella
↓
Registrar asistencia
↓
Mostrar confirmación
```

## Código automático

El código del empleado se genera automáticamente:

```text
00001
00002
00003
```

## Respuesta antes de editar

Antes de editar, Continue debe mostrar:

- Archivos que tocará.
- Por qué.
- Qué dependencias revisó.
- Riesgos.

## Respuesta después de editar

Después de editar, Continue debe mostrar:

- Archivos modificados.
- Cambios realizados.
- Importaciones ajustadas.
- Posibles efectos secundarios.

## No ejecutar Gradle

Continue no debe ejecutar Gradle salvo que el usuario lo pida explícitamente.
