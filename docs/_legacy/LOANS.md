# LOANS.md

# Módulo Préstamos

## Estado

Implementado como módulo local con Room + Repository + Engine + ViewModel + Compose.

## Flujo

1. Administrador registra solicitud por código o PIN de empleado.
2. Solicitud queda en estado PENDIENTE.
3. Administrador aprueba o rechaza.
4. Préstamo aprobado puede marcarse como ENTREGADO.
5. Préstamo entregado acepta pagos o descuentos aplicados.
6. Cuando el balance llega a cero, pasa a PAGADO.

## Historial por estado

Los indicadores Pendientes, Aprobados y Entregados son accionables. Al tocarlos muestran una vista filtrada con los préstamos de ese estado y sus acciones disponibles.

## Datos

Entity: LoanEntity.
DAO: LoanDao.
Repository: LoanRepository.
Engine: LoanEngine.
UI: LoansScreen.

## Permisos

Usa PermissionCatalog.LOANS para mostrar acceso en el panel Administrador.
