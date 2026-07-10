package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "employee_permission_requests")
data class EmployeePermissionRequestEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val employeeId: Int,
    val employeeName: String = "",
    val employeeCode: String = "",
    val branchId: Int = 0,
    val departmentId: Int = 0,
    val requestType: String,
    val message: String = "",
    val attachmentUri: String = "",
    val attachmentLabel: String = "",
    val status: String = STATUS_PENDING,
    val requestedDate: String = "",
    val reviewedBy: String = "",
    val reviewedDate: String = "",
    val rejectionReason: String = "",
    val licenseStartDate: String = "",
    val licenseEndDate: String = "",
    val licensePayPercent: Double = 0.0,
    val normalDailyAmount: Double = 0.0,
    val licenseDailyAmount: Double = 0.0,
    val licenseTotalAmount: Double = 0.0,
    val createdAt: String = "",
    val updatedAt: String = createdAt,
    val isActive: Boolean = true
) {
    companion object {
        const val TYPE_LATE = "LLEGARE_TARDE"
        const val TYPE_MEDICAL = "MEDICO"
        const val TYPE_MEDICAL_LICENSE = "LICENCIA_MEDICA"
        const val TYPE_PERSONAL = "MOTIVO_PERSONAL"

        const val STATUS_PENDING = "PENDIENTE"
        const val STATUS_APPROVED = "APROBADO"
        const val STATUS_REJECTED = "RECHAZADO"
    }
}
