# Plan de reestructuración modular

## Etapa 1 — completada en esta entrega

Investigación, auditoría, mapa actual/objetivo, protección biométrica, navegación web declarativa, adaptador de permisos y verificación de contratos críticos. Sin movimientos Android ni cambios de negocio.

## Etapa 2 — navegación y diseño web

Introducir shell jerárquico, rutas por dominio, componentes de acción/estado/error y permisos efectivos. Migrar una ruta por vez manteniendo redirects. Criterio: build, Vercel reload y cero rutas vacías.

## Etapa 3 — servicios y Supabase

Contratos TypeScript, Supabase Auth, employees/organization, feature flags y adaptadores mock→real. No retirar mocks hasta pruebas RLS y E2E.

## Etapa 4 — tiempo

Migración 0003/0004 probada localmente, outbox Android, UUID/idempotencia, horarios, jornadas, kiosco y Realtime mínimo. Hardware matrix obligatoria.

## Etapa 5 — ausencias

Solicitudes unificadas, adjuntos privados, aprobación multinivel, calendario y efecto explícito en asistencia/nómina. Conservar porcentajes configurados; revisión legal separada.

## Etapa 6 — nómina

Períodos versionados, pre-nómina, reglas existentes, snapshots, doble aprobación, exportaciones y pruebas doradas. No reemplazar motores hasta comparar resultados centavo por centavo.

## Etapa 7 — reportes/sistema

Reportes guardados, auditoría, seguridad, retención, observabilidad, performance y recuperación.

## Estrategia técnica

- Strangler: nueva feature consume adaptador; implementación vieja sigue disponible hasta paridad.
- Un dominio por PR/entrega; compilación Android+web en cada paso.
- No cambiar rutas y persistencia simultáneamente.
- Cada movimiento tiene compatibilidad temporal y rollback de código.
- Migraciones de datos son aditivas/compensatorias; históricos no se borran.

## Gates

Biometría/hardware, navegación, Room offline, RLS multiempresa, nómina dorada y Vercel constituyen gates independientes. Una etapa no avanza si falla alguno relacionado.
