package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "payroll_history")
data class PayrollHistoryEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val employeeId: Int,
    val employeeName: String,
    val periodStart: String,
    val periodEnd: String,
    val totalIncome: Double,
    val totalDiscounts: Double,
    val netPay: Double,
    val oneTimeCreditAmount: Double,
    val createdAt: String
)