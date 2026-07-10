package com.example.controlhorario.engine

import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.EmployeePayrollSettingsEntity
import com.example.controlhorario.database.LaborCalendarDayEntity
import com.example.controlhorario.database.MedicalLicenseDailyPaymentEntity
import com.example.controlhorario.database.PayrollSettingsEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.GeneralPayrollExport
import com.example.controlhorario.model.GeneralPayrollRow
import com.example.controlhorario.model.GeneralPayrollSummary

object GeneralPayrollEngine {

    data class CalculationResult(
        val export: GeneralPayrollExport,
        val updatedSettings: List<EmployeePayrollSettingsEntity>
    )

    fun calculate(
        employees: List<Employee>,
        settings: List<EmployeePayrollSettingsEntity>,
        attendanceRecords: List<AttendanceEntity>,
        laborCalendarDays: List<LaborCalendarDayEntity>,
        medicalLicensePayments: List<MedicalLicenseDailyPaymentEntity> = emptyList(),
        generalSettings: PayrollSettingsEntity?,
        periodStart: String,
        periodEnd: String
    ): CalculationResult {
        val settingsByEmployee = settings.associateBy { it.employeeId }
        val updatedSettings = mutableListOf<EmployeePayrollSettingsEntity>()

        val rows = employees
            .filter { it.isActive }
            .sortedBy { it.employeeCode.ifBlank { it.pin }.toIntOrNull() ?: Int.MAX_VALUE }
            .map { employee ->
                val employeeSettings = prepareAutoHourPrices(employee, settingsByEmployee[employee.id])
                val medicalLicensePayment = medicalLicensePayments
                    .filter {
                        it.employeeId == employee.id &&
                            it.date >= periodStart &&
                            it.date <= periodEnd &&
                            it.isActive
                    }
                    .sumOf { it.paymentAmount }

                val result = PayrollCalculationEngine.calculateEmployeePayroll(
                    employee = employee,
                    periodStart = periodStart,
                    periodEnd = periodEnd,
                    attendanceRecords = attendanceRecords,
                    laborCalendarDays = laborCalendarDays,
                    workScheduleTemplate = null,
                    generalSettings = generalSettings,
                    employeeSettings = employeeSettings
                )

                val loanDiscount = calculateDueDiscount(
                    total = employeeSettings.totalLoanAmount,
                    pending = employeeSettings.loanPendingAmount,
                    configuredDiscount = employeeSettings.loanPayrollDiscountAmount.takeIf { it > 0.0 } ?: employeeSettings.loanAmount
                )
                val creditDiscount = calculateDueDiscount(
                    total = employeeSettings.totalCreditAmount,
                    pending = employeeSettings.creditPendingAmount,
                    configuredDiscount = employeeSettings.creditPayrollDiscountAmount.takeIf { it > 0.0 } ?: employeeSettings.oneTimeCreditAmount
                )

                val taxes = employeeSettings.afpAmount + employeeSettings.sfsAmount
                val incentive = employeeSettings.bonusAmount + employeeSettings.commissionAmount + employeeSettings.otherIncomeAmount
                val totalGross = employee.sueldo + result.overtimePayment + result.holidayPayment + medicalLicensePayment + incentive
                val totalPay = totalGross - loanDiscount - creditDiscount - taxes - employeeSettings.otherDiscountAmount

                updatedSettings += updateBalancesAfterPayroll(
                    settings = employeeSettings,
                    loanDiscount = loanDiscount,
                    creditDiscount = creditDiscount
                )

                GeneralPayrollRow(
                    employeeId = employee.id,
                    employeeCode = employee.employeeCode.ifBlank { employee.pin },
                    employeeName = employee.nombre,
                    baseSalary = employee.sueldo,
                    overtimePayment = result.overtimePayment,
                    holidayPayment = result.holidayPayment,
                    medicalLicensePayment = medicalLicensePayment,
                    incentivePayment = incentive,
                    totalGross = totalGross,
                    loanDiscount = loanDiscount,
                    creditDiscount = creditDiscount,
                    taxes = taxes,
                    otherDiscount = employeeSettings.otherDiscountAmount,
                    totalPay = totalPay
                )
            }

        val summary = GeneralPayrollSummary(
            employeeCount = rows.size,
            totalSalaries = rows.sumOf { it.baseSalary },
            totalOvertime = rows.sumOf { it.overtimePayment },
            totalMedicalLicenses = rows.sumOf { it.medicalLicensePayment },
            totalIncentives = rows.sumOf { it.incentivePayment },
            totalLoans = rows.sumOf { it.loanDiscount },
            totalCredits = rows.sumOf { it.creditDiscount },
            totalTaxes = rows.sumOf { it.taxes },
            totalOtherDiscounts = rows.sumOf { it.otherDiscount },
            totalGeneralPaid = rows.sumOf { it.totalPay }
        )

        return CalculationResult(
            export = GeneralPayrollExport(
                periodStart = periodStart,
                periodEnd = periodEnd,
                rows = rows,
                summary = summary
            ),
            updatedSettings = updatedSettings
        )
    }

    fun prepareAutoHourPrices(
        employee: Employee,
        settings: EmployeePayrollSettingsEntity?
    ): EmployeePayrollSettingsEntity {
        val base = settings ?: EmployeePayrollSettingsEntity(employeeId = employee.id)
        val normalHour = if (employee.sueldo > 0.0) employee.sueldo / 15.0 / 8.0 else base.normalHourPrice
        val overtime = normalHour + (normalHour * base.overtimePercent / 100.0)
        val night = normalHour + (normalHour * base.nightPercent / 100.0)
        val holiday = normalHour + (normalHour * base.holidayPercent / 100.0)
        return base.copy(
            normalHourPrice = normalHour,
            overtimeHourPrice = if (base.overtimePercent > 0.0) overtime else base.overtimeHourPrice,
            nightHourPrice = if (base.nightPercent > 0.0) night else base.nightHourPrice,
            holidayHourPrice = if (base.holidayPercent > 0.0) holiday else base.holidayHourPrice,
            lunchHours = if (base.lunchHours > 0.0) base.lunchHours else employee.lunchHours
        )
    }

    private fun calculateDueDiscount(total: Double, pending: Double, configuredDiscount: Double): Double {
        val balance = when {
            pending > 0.0 -> pending
            total > 0.0 -> total
            else -> 0.0
        }
        if (configuredDiscount <= 0.0) return 0.0
        if (balance <= 0.0) return configuredDiscount
        return configuredDiscount.coerceAtMost(balance)
    }

    private fun updateBalancesAfterPayroll(
        settings: EmployeePayrollSettingsEntity,
        loanDiscount: Double,
        creditDiscount: Double
    ): EmployeePayrollSettingsEntity {
        val currentLoanPending = if (settings.loanPendingAmount > 0.0) settings.loanPendingAmount else settings.totalLoanAmount
        val newLoanPending = (currentLoanPending - loanDiscount).coerceAtLeast(0.0)
        val newLoanPaid = settings.loanPaidAmount + loanDiscount

        val currentCreditPending = if (settings.creditPendingAmount > 0.0) settings.creditPendingAmount else settings.totalCreditAmount
        val newCreditPending = (currentCreditPending - creditDiscount).coerceAtLeast(0.0)

        return settings.copy(
            totalLoanAmount = if (newLoanPending <= 0.0) 0.0 else settings.totalLoanAmount,
            loanPaidAmount = if (newLoanPending <= 0.0) 0.0 else newLoanPaid,
            loanPendingAmount = if (newLoanPending <= 0.0) 0.0 else newLoanPending,
            loanPayrollDiscountAmount = if (newLoanPending <= 0.0) 0.0 else settings.loanPayrollDiscountAmount,
            loanAmount = if (newLoanPending <= 0.0) 0.0 else loanDiscount,
            totalCreditAmount = if (newCreditPending <= 0.0) 0.0 else settings.totalCreditAmount,
            creditPendingAmount = if (newCreditPending <= 0.0) 0.0 else newCreditPending,
            creditPayrollDiscountAmount = if (newCreditPending <= 0.0) 0.0 else settings.creditPayrollDiscountAmount,
            oneTimeCreditAmount = if (newCreditPending <= 0.0) 0.0 else creditDiscount
        )
    }
}
