package com.example.controlhorario.engine

import java.math.BigDecimal
import java.math.RoundingMode

object PayrollMoneyPolicy {
    data class DebtAllocation(val loan: Double, val credit: Double)

    fun money(value: Double): Double =
        if (value.isFinite()) BigDecimal.valueOf(value).setScale(2, RoundingMode.HALF_UP).toDouble() else 0.0

    fun hourlyRateFromMonthlySalary(
        monthlySalary: Double,
        calendarDays: Int = 30,
        dailyHours: Int = 8
    ): Double {
        if (!monthlySalary.isFinite() || monthlySalary <= 0.0 || calendarDays <= 0 || dailyHours <= 0) {
            return 0.0
        }
        return BigDecimal.valueOf(monthlySalary)
            .divide(BigDecimal.valueOf(calendarDays.toLong()), 8, RoundingMode.HALF_UP)
            .divide(BigDecimal.valueOf(dailyHours.toLong()), 6, RoundingMode.HALF_UP)
            .toDouble()
    }

    fun dueDiscount(total: Double, pending: Double, configured: Double): Double {
        if (!configured.isFinite() || configured <= 0.0) return 0.0
        val balance = when {
            pending.isFinite() && pending > 0.0 -> pending
            total.isFinite() && total > 0.0 -> total
            else -> 0.0
        }
        if (balance <= 0.0) return 0.0
        return money(configured.coerceAtMost(balance))
    }

    fun fundDebtDeductions(
        gross: Double,
        mandatoryDeductions: Double,
        loanDue: Double,
        creditDue: Double
    ): DebtAllocation {
        var available = money((gross - mandatoryDeductions.coerceAtLeast(0.0)).coerceAtLeast(0.0))
        val loan = money(loanDue.coerceIn(0.0, available))
        available = money((available - loan).coerceAtLeast(0.0))
        val credit = money(creditDue.coerceIn(0.0, available))
        return DebtAllocation(loan, credit)
    }
}