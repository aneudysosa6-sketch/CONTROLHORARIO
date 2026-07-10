package com.example.controlhorario.repository

import com.example.controlhorario.database.PendingAttendanceReviewDao
import com.example.controlhorario.database.PendingAttendanceReviewEntity
import kotlinx.coroutines.flow.Flow

class PendingAttendanceReviewRepository(
    private val dao: PendingAttendanceReviewDao
) {
    fun getAll(): Flow<List<PendingAttendanceReviewEntity>> = dao.getAll()

    fun getPending(): Flow<List<PendingAttendanceReviewEntity>> =
        dao.getByStatus(PendingAttendanceReviewEntity.STATUS_PENDING)

    suspend fun findPendingForEmployeeDate(employeeId: Int, date: String): PendingAttendanceReviewEntity? =
        dao.findPendingForEmployeeDate(employeeId, date)

    suspend fun save(entity: PendingAttendanceReviewEntity): Long = dao.save(entity)

    suspend fun update(entity: PendingAttendanceReviewEntity) = dao.update(entity)

    suspend fun approve(id: Int, note: String, reviewedBy: String = "Administrador") =
        dao.updateStatus(id, PendingAttendanceReviewEntity.STATUS_APPROVED, note, reviewedBy)

    suspend fun reject(id: Int, note: String, reviewedBy: String = "Administrador") =
        dao.updateStatus(id, PendingAttendanceReviewEntity.STATUS_REJECTED, note, reviewedBy)

    suspend fun markEditedApproved(id: Int, note: String, reviewedBy: String = "Administrador") =
        dao.updateStatus(id, PendingAttendanceReviewEntity.STATUS_EDITED, note, reviewedBy)
}
