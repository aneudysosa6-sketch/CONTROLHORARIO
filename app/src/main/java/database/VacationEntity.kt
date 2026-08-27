package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "vacations")
data class VacationEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val employeeId: Int,
    val employeeName: String = "",
    val employeeCode: String = "",
    val startDate: String,
    val endDate: String,
    val requestedDays: Int = 0,
    val approvedDays: Int = 0,
    val remainingDays: Int = 0,
    val reason: String = "",
    val status: String = STATUS_PENDING,
    val requestedBy: String = "",
    val requestedDate: String = "",
    val approvedBy: String = "",
    val approvedDate: String = "",
    val rejectedBy: String = "",
    val rejectedDate: String = "",
    val rejectionReason: String = "",
    val notes: String = "",
    val createdAt: String = "",
    val updatedAt: String = createdAt,
    val isActive: Boolean = true
) {
    companion object {
        const val STATUS_PENDING = "PENDIENTE"
        const val STATUS_APPROVED = "APROBADA"
        const val STATUS_REJECTED = "RECHAZADA"
        const val STATUS_CANCELLED = "CANCELADA"
    }
}
