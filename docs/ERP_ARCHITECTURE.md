# ERP_ARCHITECTURE.md

# Arquitectura OSINET Time ERP Enterprise

## Capas

```text
UI Compose
↓
ViewModel
↓
Repository
↓
DAO
↓
Room Database
```

## Capa UI

Contiene pantallas Jetpack Compose.  
No debe acceder directamente a DAO.  
Debe consumir estado desde ViewModel.

## ViewModel

Responsable de:

- Estado de pantalla.
- Validaciones visuales.
- Llamadas a Repository.
- Lógica de presentación.

## Repository

Responsable de:

- Acceso coordinado a DAO.
- Operaciones de persistencia.
- Separar UI de base de datos.

## DAO

Responsable de consultas Room.

## Entity

Representación persistente.

Debe incluir, cuando aplique:

- createdAt
- updatedAt
- isActive

## Engine

Contiene lógica de negocio pura.

Ejemplos:

- PayrollEngine
- AttendanceEngine
- PermissionEngine
- Motores internos de incidencias y notificaciones

## Límite de arquitectura

CONTROLHORARIO no incluye Gmail, WhatsApp ni n8n. Las alertas y notificaciones son internas. No existen adaptadores, clientes HTTP, colas de entrega ni credenciales para mensajería externa.
