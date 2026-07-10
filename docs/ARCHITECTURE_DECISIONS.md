# ARCHITECTURE_DECISIONS.md

# Decisiones de arquitectura

## Room local

Se usa Room porque el ERP debe funcionar sin backend.

## MVVM

Se usa MVVM para separar UI, estado y datos.

## Compose

Se usa Compose para UI moderna Android.

## Sin Firebase

La app debe operar localmente y no depender de servicios externos.

## Integración externa eliminada futuro

La integración externa fue eliminada del proyecto. Toda la lógica será interna del ERP.
