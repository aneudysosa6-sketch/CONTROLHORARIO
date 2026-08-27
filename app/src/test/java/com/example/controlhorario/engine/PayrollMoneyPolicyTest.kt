package com.example.controlhorario.engine

import org.junit.Assert.assertEquals
import org.junit.Test

class PayrollMoneyPolicyTest {
    @Test fun monthlySalaryUsesThirtyDayEightHourConvention() {
        assertEquals(100.0, PayrollMoneyPolicy.hourlyRateFromMonthlySalary(24000.0), 0.000001)
    }

    @Test fun configuredInstallmentCannotCreateDebt() {
        assertEquals(0.0, PayrollMoneyPolicy.dueDiscount(0.0, 0.0, 500.0), 0.001)
        assertEquals(125.25, PayrollMoneyPolicy.dueDiscount(1000.0, 125.25, 500.0), 0.001)
    }

    @Test fun debtDeductionsNeverMakeNetPayNegative() {
        val allocation = PayrollMoneyPolicy.fundDebtDeductions(
            gross = 1000.0,
            mandatoryDeductions = 800.0,
            loanDue = 300.0,
            creditDue = 200.0
        )
        assertEquals(200.0, allocation.loan, 0.001)
        assertEquals(0.0, allocation.credit, 0.001)
    }

    @Test fun moneyUsesDecimalHalfUpRounding() {
        assertEquals(10.01, PayrollMoneyPolicy.money(10.005), 0.001)
        assertEquals(0.0, PayrollMoneyPolicy.money(Double.NaN), 0.001)
    }
}