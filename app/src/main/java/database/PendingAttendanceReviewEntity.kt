package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "pending_attendance_reviews",
    indices = [
        Index(value = ["employeeId"]),
        Index(value = ["reviewDate"]),
        Index(value = ["status"])
    ]
)
data class PendingAttendanceReviewEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val employeeId: Int,
    val employeeCode: String,
    val employeeName: String,
    val employeePhone: String = "",
    val departmentId: Int = 0,
    val departmentName: String = "",
    val branchId: Int = 0,
    val reviewDate: String,
    val checkInTime: String = "",
    val lunchOutTime: String = "",
    val lunchInTime: String = "",
    val checkOutTime: String = "",
    val reason: String,
    val severity: String,
    val calculatedHours: Double = 0.0,
    val status: String = STATUS_PENDING,
    val adminNote: String = "",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val reviewedAt: Long = 0L,
    val reviewedBy: String = "",
    val notificationQueued: Boolean = false
) {
    companion object {
        const val STATUS_PENDING = "PENDIENTE_APROBACION"
        const val STATUS_APPROVED = "APROBADA"
        const val STATUS_REJECTED = "RECHAZADA"
        const val STATUS_EDITED = "EDITADA_APROBADA"

        const val SEVERITY_CRITICAL = "CRITICA"
        const val SEVERITY_HIGH = "ALTA"
        const val SEVERITY_MEDIUM = "MEDIA"
        const val SEVERITY_INFO = "INFORMATIVA"
    }
}
