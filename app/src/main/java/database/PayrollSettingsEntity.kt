package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "payroll_settings")
data class PayrollSettingsEntity(
    @PrimaryKey
    val id: Int = 1,
    val normalHourPrice: Double = 0.0,
    val overtimeHourPrice: Double = 0.0,
    val nightHourPrice: Double = 0.0,
    val sundayHourPrice: Double = 0.0,
    val holidayHourPrice: Double = 0.0,
    val bonusAmount: Double = 0.0,
    val commissionAmount: Double = 0.0,
    val otherIncomeAmount: Double = 0.0,
    val afpAmount: Double = 0.0,
    val sfsAmount: Double = 0.0,
    val isrAmount: Double = 0.0,
    val loanAmount: Double = 0.0,
    val otherDiscountAmount: Double = 0.0
)