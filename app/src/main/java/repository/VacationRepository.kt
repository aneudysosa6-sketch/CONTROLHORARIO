package com.example.controlhorario.repository

import com.example.controlhorario.database.VacationDao
import com.example.controlhorario.database.VacationEntity
import kotlinx.coroutines.flow.Flow

class VacationRepository(
    private val vacationDao: VacationDao
) {
    fun getAllVacations(): Flow<List<VacationEntity>> =
        vacationDao.getAllVacations()

    fun getVacationsByEmployee(employeeId: Int): Flow<List<VacationEntity>> =
        vacationDao.getVacationsByEmployee(employeeId)

    fun getVacationsByStatus(status: String): Flow<List<VacationEntity>> =
        vacationDao.getVacationsByStatus(status)

    fun getVacationById(vacationId: Int): Flow<VacationEntity?> =
        vacationDao.getVacationById(vacationId)

    suspend fun saveVacation(vacation: VacationEntity) {
        vacationDao.saveVacation(vacation)
    }

    suspend fun approveVacation(
        vacationId: Int,
        approvedBy: String,
        approvedDate: String,
        approvedDays: Int,
        remainingDays: Int,
        updatedAt: String
    ) {
        vacationDao.approveVacation(
            vacationId = vacationId,
            status = VacationEntity.STATUS_APPROVED,
            approvedBy = approvedBy,
            approvedDate = approvedDate,
            approvedDays = approvedDays,
            remainingDays = remainingDays,
            updatedAt = updatedAt
        )
    }

    suspend fun rejectVacation(
        vacationId: Int,
        rejectedBy: String,
        rejectedDate: String,
        rejectionReason: String,
        updatedAt: String
    ) {
        vacationDao.rejectVacation(
            vacationId = vacationId,
            status = VacationEntity.STATUS_REJECTED,
            rejectedBy = rejectedBy,
            rejectedDate = rejectedDate,
            rejectionReason = rejectionReason,
            updatedAt = updatedAt
        )
    }

    suspend fun cancelVacation(
        vacationId: Int,
        updatedAt: String
    ) {
        vacationDao.cancelVacation(
            vacationId = vacationId,
            status = VacationEntity.STATUS_CANCELLED,
            updatedAt = updatedAt
        )
    }

    suspend fun deactivateVacation(
        vacationId: Int,
        updatedAt: String
    ) {
        vacationDao.deactivateVacation(
            vacationId = vacationId,
            updatedAt = updatedAt
        )
    }
}
