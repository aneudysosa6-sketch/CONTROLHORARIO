package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "medical_license_daily_payments")
data class MedicalLicenseDailyPaymentEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val permissionRequestId: Int,
    val employeeId: Int,
    val employeeName: String = "",
    val employeeCode: String = "",
    val date: String,
    val normalDailyAmount: Double,
    val payPercent: Double,
    val paymentAmount: Double,
    val createdAt: String = "",
    val isActive: Boolean = true
)
