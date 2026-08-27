package com.example.controlhorario.repository

import com.example.controlhorario.database.PendingAttendanceReviewDao
import com.example.controlhorario.database.PendingAttendanceReviewEntity
import kotlinx.coroutines.flow.Flow

class PendingAttendanceReviewRepository(
    private val dao: PendingAttendanceReviewDao,
) {
    fun getAll(): Flow<List<PendingAttendanceReviewEntity>> = dao.getAll()
    fun getPending(): Flow<List<PendingAttendanceReviewEntity>> =
        dao.getByStatus(PendingAttendanceReviewEntity.STATUS_PENDING)

    suspend fun findPendingForEmployeeDate(employeeId: Int, date: String): PendingAttendanceReviewEntity? =
        dao.findPendingForEmployeeDate(employeeId, date)

    suspend fun save(entity: PendingAttendanceReviewEntity): Long = dao.save(entity)
    suspend fun update(entity: PendingAttendanceReviewEntity) = dao.update(entity)

    suspend fun resolveNoPay(id: Int, note: String, reviewedBy: String = "Administrador") =
        dao.resolve(
            id = id,
            status = PendingAttendanceReviewEntity.STATUS_RESOLVED_NO_PAY,
            calculatedHours = 0.0,
            note = note,
            reviewedBy = reviewedBy,
        )

    suspend fun resolveDemonstrable(
        id: Int,
        calculatedHours: Double,
        note: String,
        reviewedBy: String = "Administrador",
    ): Int {
        require(calculatedHours.isFinite() && calculatedHours >= 0.0) { "Las horas demostrables deben ser válidas." }
        return dao.resolve(
            id = id,
            status = PendingAttendanceReviewEntity.STATUS_RESOLVED_DEMONSTRABLE,
            calculatedHours = calculatedHours,
            note = note,
            reviewedBy = reviewedBy,
        )
    }
}
