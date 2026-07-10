package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "employee_payroll_settings")
data class EmployeePayrollSettingsEntity(
    @PrimaryKey
    val employeeId: Int,
    val normalHourPrice: Double = 0.0,
    val overtimeHourPrice: Double = 0.0,
    val nightHourPrice: Double = 0.0,
    val sundayHourPrice: Double = 0.0,
    val holidayHourPrice: Double = 0.0,
    val overtimePercent: Double = 0.0,
    val nightPercent: Double = 0.0,
    val holidayPercent: Double = 0.0,
    val lunchHours: Double = 0.0,
    val bonusAmount: Double = 0.0,
    val commissionAmount: Double = 0.0,
    val otherIncomeAmount: Double = 0.0,
    val afpAmount: Double = 0.0,
    val sfsAmount: Double = 0.0,
    val isrAmount: Double = 0.0,
    val loanAmount: Double = 0.0,
    val totalLoanAmount: Double = 0.0,
    val loanPaidAmount: Double = 0.0,
    val loanPendingAmount: Double = 0.0,
    val loanPayrollDiscountAmount: Double = 0.0,
    val totalCreditAmount: Double = 0.0,
    val creditPendingAmount: Double = 0.0,
    val creditPayrollDiscountAmount: Double = 0.0,
    val cooperativeAmount: Double = 0.0,
    val privateInsuranceAmount: Double = 0.0,
    val phoneDiscountAmount: Double = 0.0,
    val foodDiscountAmount: Double = 0.0,
    val transportDiscountAmount: Double = 0.0,
    val oneTimeCreditAmount: Double = 0.0,
    val otherDiscountAmount: Double = 0.0
)
