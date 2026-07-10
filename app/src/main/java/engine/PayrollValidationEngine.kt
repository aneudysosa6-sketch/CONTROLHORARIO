package com.example.controlhorario.engine

import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.EmployeePayrollSettingsEntity
import com.example.controlhorario.database.PayrollSettingsEntity
import com.example.controlhorario.model.Employee

object PayrollValidationEngine {

    fun validateEmployeePayroll(
        employee: Employee?,
        periodStart: String,
        periodEnd: String,
        attendanceRecords: List<AttendanceEntity>,
        generalSettings: PayrollSettingsEntity?,
        employeeSettings: EmployeePayrollSettingsEntity?
    ): PayrollValidationResult {

        if (employee == null) {
            return PayrollValidationResult(
                isValid = false,
                message = "Empleado no encontrado."
            )
        }

        if (periodStart.isBlank()) {
            return PayrollValidationResult(
                isValid = false,
                message = "La fecha de inicio del período está vacía."
            )
        }

        if (periodEnd.isBlank()) {
            return PayrollValidationResult(
                isValid = false,
                message = "La fecha final del período está vacía."
            )
        }

        val employeeRecords = attendanceRecords.filter {
            it.employeeId == employee.id &&
                    it.date >= periodStart &&
                    it.date <= periodEnd
        }

        if (employeeRecords.isEmpty()) {
            return PayrollValidationResult(
                isValid = false,
                message = "Este empleado no tiene asistencia registrada en el período seleccionado."
            )
        }

        val hasIndividualSettings = employeeSettings != null
        val hasGeneralSettings = generalSettings != null

        if (!hasIndividualSettings && !hasGeneralSettings) {
            return PayrollValidationResult(
                isValid = false,
                message = "No existe configuración de nómina general ni individual para este empleado."
            )
        }

        val normalHourPrice = employeeSettings?.normalHourPrice
            ?: generalSettings?.normalHourPrice
            ?: 0.0

        if (normalHourPrice <= 0.0 && employee.sueldo <= 0.0) {
            return PayrollValidationResult(
                isValid = false,
                message = "El empleado no tiene sueldo ni precio de hora normal configurado."
            )
        }

        return PayrollValidationResult(
            isValid = true,
            message = "Validación correcta."
        )
    }
}

data class PayrollValidationResult(
    val isValid: Boolean,
    val message: String
)