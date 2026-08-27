package com.example.controlhorario.model

data class GeneralPayrollRow(
    val employeeId: Int,
    val employeeCode: String,
    val employeeName: String,
    val baseSalary: Double,
    val overtimePayment: Double,
    val holidayPayment: Double,
    val medicalLicensePayment: Double = 0.0,
    val incentivePayment: Double,
    val totalGross: Double,
    val loanDiscount: Double,
    val creditDiscount: Double,
    val taxes: Double,
    val otherDiscount: Double,
    val totalPay: Double
)

data class GeneralPayrollSummary(
    val employeeCount: Int = 0,
    val totalSalaries: Double = 0.0,
    val totalOvertime: Double = 0.0,
    val totalMedicalLicenses: Double = 0.0,
    val totalIncentives: Double = 0.0,
    val totalLoans: Double = 0.0,
    val totalCredits: Double = 0.0,
    val totalTaxes: Double = 0.0,
    val totalOtherDiscounts: Double = 0.0,
    val totalGeneralPaid: Double = 0.0
)

data class GeneralPayrollExport(
    val periodStart: String,
    val periodEnd: String,
    val rows: List<GeneralPayrollRow>,
    val summary: GeneralPayrollSummary
)
