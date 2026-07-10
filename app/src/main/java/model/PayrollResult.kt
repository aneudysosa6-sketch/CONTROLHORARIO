package com.example.controlhorario.model

data class PayrollResult(
    val employeeId: Int,
    val employeeName: String,
    val periodStart: String,
    val periodEnd: String,

    val normalHours: Double = 0.0,
    val overtimeHours: Double = 0.0,
    val nightHours: Double = 0.0,
    val sundayHours: Double = 0.0,
    val holidayHours: Double = 0.0,
    val totalWorkedHours: Double = 0.0,

    val normalHourPayment: Double = 0.0,
    val overtimePayment: Double = 0.0,
    val nightPayment: Double = 0.0,
    val sundayPayment: Double = 0.0,
    val holidayPayment: Double = 0.0,

    val baseSalary: Double = 0.0,
    val bonusAmount: Double = 0.0,
    val commissionAmount: Double = 0.0,
    val otherIncomeAmount: Double = 0.0,

    val afpAmount: Double = 0.0,
    val sfsAmount: Double = 0.0,
    val isrAmount: Double = 0.0,

    val loanAmount: Double = 0.0,
    val cooperativeAmount: Double = 0.0,
    val privateInsuranceAmount: Double = 0.0,
    val phoneDiscountAmount: Double = 0.0,
    val foodDiscountAmount: Double = 0.0,
    val transportDiscountAmount: Double = 0.0,
    val oneTimeCreditAmount: Double = 0.0,
    val otherDiscountAmount: Double = 0.0,

    val totalIncome: Double = 0.0,
    val totalDiscounts: Double = 0.0,
    val netPay: Double = 0.0,

    val temporaryCreditMustBeCleared: Boolean = false,
    val notes: String = ""
)