package com.example.controlhorario.engine

import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.EmployeePayrollSettingsEntity
import com.example.controlhorario.database.LaborCalendarDayEntity
import com.example.controlhorario.database.PayrollSettingsEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.PayrollResult
import com.example.controlhorario.model.WorkScheduleTemplate
import java.text.NumberFormat
import java.util.Locale

object WhatsAppPayrollEngine {

    fun generatePayrollSummary(
        employee: Employee,
        periodStart: String,
        periodEnd: String,
        attendanceRecords: List<AttendanceEntity>,
        laborCalendarDays: List<LaborCalendarDayEntity>,
        workScheduleTemplate: WorkScheduleTemplate?,
        generalSettings: PayrollSettingsEntity?,
        employeeSettings: EmployeePayrollSettingsEntity?
    ): WhatsAppPayrollResult {

        val payroll = PayrollCalculationEngine.calculateEmployeePayroll(
            employee = employee,
            periodStart = periodStart,
            periodEnd = periodEnd,
            attendanceRecords = attendanceRecords,
            laborCalendarDays = laborCalendarDays,
            workScheduleTemplate = workScheduleTemplate,
            generalSettings = generalSettings,
            employeeSettings = employeeSettings
        )

        val currency = NumberFormat.getCurrencyInstance(
            Locale("es", "DO")
        )

        val summary = buildString {

            appendLine("💰 Vista previa de nómina")
            appendLine()

            appendLine("Empleado:")
            appendLine(employee.nombre)
            appendLine()

            appendLine("Período:")
            appendLine("$periodStart - $periodEnd")
            appendLine()

            appendLine("Horas trabajadas:")
            appendLine(payroll.totalWorkedHours)
            appendLine()

            appendLine("Total devengado:")
            appendLine(currency.format(payroll.totalIncome))
            appendLine()

            appendLine("Total descuentos:")
            appendLine(currency.format(payroll.totalDiscounts))
            appendLine()

            appendLine("Neto a pagar:")
            appendLine(currency.format(payroll.netPay))
            appendLine()

            appendLine("Si deseas el recibo en PDF responde:")
            appendLine()

            appendLine("3")
        }

        return WhatsAppPayrollResult(
            success = true,
            employee = employee,
            payrollResult = payroll,
            message = summary
        )
    }
}

data class WhatsAppPayrollResult(

    val success: Boolean,

    val employee: Employee,

    val payrollResult: PayrollResult,

    val message: String
)