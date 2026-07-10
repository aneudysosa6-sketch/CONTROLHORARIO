package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "loans")
data class LoanEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val employeeId: Int,
    val employeeName: String = "",
    val employeeCode: String = "",
    val requestedAmount: Double = 0.0,
    val approvedAmount: Double = 0.0,
    val paidAmount: Double = 0.0,
    val balance: Double = 0.0,
    val payrollDiscount: Double = 0.0,
    val reason: String = "",
    val status: String = STATUS_PENDING,
    val requestedBy: String = "",
    val requestedDate: String = "",
    val approvedBy: String = "",
    val approvedDate: String = "",
    val deliveredBy: String = "",
    val deliveredDate: String = "",
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
        const val STATUS_APPROVED = "APROBADO"
        const val STATUS_DELIVERED = "ENTREGADO"
        const val STATUS_PAID = "PAGADO"
        const val STATUS_REJECTED = "RECHAZADO"
        const val STATUS_CANCELLED = "CANCELADO"
    }
}
