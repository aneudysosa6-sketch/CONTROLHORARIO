package com.example.controlhorario.repository

import com.example.controlhorario.database.EmployeePermissionRequestDao
import com.example.controlhorario.database.EmployeePermissionRequestEntity
import com.example.controlhorario.database.MedicalLicenseDailyPaymentDao
import com.example.controlhorario.database.MedicalLicenseDailyPaymentEntity
import com.example.controlhorario.engine.MedicalLicensePolicy
import kotlinx.coroutines.flow.Flow

class EmployeePermissionRequestRepository(
    private val requestDao: EmployeePermissionRequestDao,
    private val dailyPaymentDao: MedicalLicenseDailyPaymentDao,
) {
    fun getAllRequests(): Flow<List<EmployeePermissionRequestEntity>> = requestDao.getAllRequests()
    fun getRequestsByEmployee(employeeId: Int) = requestDao.getRequestsByEmployee(employeeId)
    fun getAllMedicalLicensePayments(): Flow<List<MedicalLicenseDailyPaymentEntity>> = dailyPaymentDao.getAllPayments()
    suspend fun saveRequest(request: EmployeePermissionRequestEntity) { requestDao.saveRequest(request) }

    suspend fun approveRequest(request: EmployeePermissionRequestEntity, reviewedBy: String, now: String): Boolean {
        if (request.requestType == EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE ||
            request.status != EmployeePermissionRequestEntity.STATUS_PENDING
        ) return false
        return requestDao.approveRequest(
            request.id,
            EmployeePermissionRequestEntity.STATUS_APPROVED,
            reviewedBy,
            now,
            "",
            "",
            0.0,
            0.0,
            0.0,
            0.0,
            now,
        ) == 1
    }

    suspend fun saveDirectLicense(
        request: EmployeePermissionRequestEntity,
        actor: String,
        now: String,
        licenseStartDate: String,
        licenseEndDate: String,
        licensePayPercent: Double,
        monthlySalary: Double,
    ): Boolean {
        if (!MedicalLicensePolicy.validateDirect(
                request,
                licenseStartDate,
                licenseEndDate,
                licensePayPercent,
                monthlySalary,
            )
        ) return false
        val dates = MedicalLicensePolicy.dates(licenseStartDate, licenseEndDate)
        val normalDailyAmount = monthlySalary / 30.0
        val dailyAmount = normalDailyAmount * (licensePayPercent / 100.0)
        val updated = if (request.status == EmployeePermissionRequestEntity.STATUS_ACTIVE) {
            requestDao.editDirectLicense(
                request.id,
                actor,
                now,
                licenseStartDate,
                licenseEndDate,
                licensePayPercent,
                normalDailyAmount,
                dailyAmount,
                dailyAmount * dates.size,
                now,
            )
        } else {
            requestDao.activateDirectLicense(
                request.id,
                EmployeePermissionRequestEntity.STATUS_ACTIVE,
                actor,
                now,
                licenseStartDate,
                licenseEndDate,
                licensePayPercent,
                normalDailyAmount,
                dailyAmount,
                dailyAmount * dates.size,
                now,
            )
        }
        if (updated != 1) return false
        dailyPaymentDao.deactivateByRequest(request.id)
        dailyPaymentDao.savePayments(dates.map { date ->
            MedicalLicenseDailyPaymentEntity(
                permissionRequestId = request.id,
                employeeId = request.employeeId,
                employeeName = request.employeeName,
                employeeCode = request.employeeCode,
                date = date,
                normalDailyAmount = normalDailyAmount,
                payPercent = licensePayPercent,
                paymentAmount = dailyAmount,
                createdAt = now,
            )
        })
        return true
    }

    suspend fun cancelDirectLicense(requestId: Int, actor: String, reason: String, now: String): Boolean {
        if (reason.isBlank()) return false
        val updated = requestDao.cancelDirectLicense(
            requestId,
            EmployeePermissionRequestEntity.STATUS_CANCELLED,
            actor,
            now,
            reason,
            now,
        )
        if (updated != 1) return false
        dailyPaymentDao.deactivateByRequest(requestId)
        return true
    }

    suspend fun rejectRequest(requestId: Int, reviewedBy: String, reason: String, now: String): Boolean {
        if (reason.isBlank()) return false
        return requestDao.rejectRequest(
            requestId,
            EmployeePermissionRequestEntity.STATUS_REJECTED,
            reviewedBy,
            now,
            reason,
            now,
        ) == 1
    }
}
