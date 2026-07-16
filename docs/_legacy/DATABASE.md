# DATABASE.md

# Base de datos Room

## Reglas

- Toda Entity debe estar registrada en AppDatabase.
- Todo DAO debe existir antes de agregarse a AppDatabase.
- No agregar Entity si no compila.
- No agregar DAO si sus queries fallan.
- No modificar versión de DB sin razón.

## Diagnóstico KSP

Si aparece MissingType:

1. Abrir AppDatabase.kt.
2. Revisar entities.
3. Revisar abstract fun dao().
4. Verificar imports.
5. Verificar paquetes.
6. Identificar primera clase faltante.
7. Corregir la clase faltante.
8. Luego compilar.

Nunca crear entidades falsas.

## Tablas agregadas

### loans

Entity: LoanEntity.
DAO: LoanDao.
Uso: módulo Préstamos.

Campos principales:

- employeeId, employeeName, employeeCode.
- requestedAmount, approvedAmount, paidAmount, balance.
- payrollDiscount.
- status.
- requestedDate, approvedDate, deliveredDate, rejectedDate.
- isActive.
