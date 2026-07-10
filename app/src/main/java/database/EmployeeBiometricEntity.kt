package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "employee_biometrics")
data class EmployeeBiometricEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val employeeId: Int,
    val employeeName: String,
    val biometricType: String = TYPE_FINGERPRINT,
    val deviceName: String = "",
    val templateBase64: String = "",
    val templateSize: Int = 0,
    val sdkProvider: String = "",
    val registeredBy: String = "",
    val registeredAt: String,
    val updatedAt: String = registeredAt,
    val isActive: Boolean = true
) {
    companion object {
        const val TYPE_FINGERPRINT = "HUELLA"
        const val TYPE_FACE = "ROSTRO"
        const val TYPE_DEVICE_BIOMETRIC = "ANDROID_BIOMETRIC"
        const val TYPE_2CONNECT_USB = "2CONNECT_USB"
    }
}
