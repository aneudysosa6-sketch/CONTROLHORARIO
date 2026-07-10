package com.example.controlhorario.repository

import com.example.controlhorario.database.EmployeePermissionRequestDao
import com.example.controlhorario.database.EmployeePermissionRequestEntity
import com.example.controlhorario.database.MedicalLicenseDailyPaymentDao
import com.example.controlhorario.database.MedicalLicenseDailyPaymentEntity
import kotlinx.coroutines.flow.Flow
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

class EmployeePermissionRequestRepository(
    private val requestDao: EmployeePermissionRequestDao,
    private val dailyPaymentDao: MedicalLicenseDailyPaymentDao
) {
    fun getAllRequests(): Flow<List<EmployeePermissionRequestEntity>> = requestDao.getAllRequests()

    fun getRequestsByEmployee(employeeId: Int): Flow<List<EmployeePermissionRequestEntity>> =
        requestDao.getRequestsByEmployee(employeeId)

    fun getAllMedicalLicensePayments(): Flow<List<MedicalLicenseDailyPaymentEntity>> =
        dailyPaymentDao.getAllPayments()

    suspend fun saveRequest(request: EmployeePermissionRequestEntity) {
        requestDao.saveRequest(request)
    }

    suspend fun approveRequest(
        request: EmployeePermissionRequestEntity,
        reviewedBy: String,
        now: String,
        licenseStartDate: String = "",
        licenseEndDate: String = "",
        licensePayPercent: Double = 0.0,
        normalDailyAmount: Double = 0.0
    ) {
        val dailyAmount = if (request.requestType == EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE) {
            normalDailyAmount * (licensePayPercent / 100.0)
        } else {
            0.0
        }
        val dates = if (request.requestType == EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE) {
            datesBetween(licenseStartDate, licenseEndDate)
        } else {
            emptyList()
        }
        requestDao.approveRequest(
            requestId = request.id,
            status = EmployeePermissionRequestEntity.STATUS_APPROVED,
            reviewedBy = reviewedBy,
            reviewedDate = now,
            licenseStartDate = licenseStartDate,
            licenseEndDate = licenseEndDate,
            licensePayPercent = licensePayPercent,
            normalDailyAmount = normalDailyAmount,
            licenseDailyAmount = dailyAmount,
            licenseTotalAmount = dailyAmount * dates.size,
            updatedAt = now
        )
        if (request.requestType == EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE && dates.isNotEmpty()) {
            dailyPaymentDao.deactivateByRequest(request.id)
            dailyPaymentDao.savePayments(
                dates.map { date ->
                    MedicalLicenseDailyPaymentEntity(
                        permissionRequestId = request.id,
                        employeeId = request.employeeId,
                        employeeName = request.employeeName,
                        employeeCode = request.employeeCode,
                        date = date,
                        normalDailyAmount = normalDailyAmount,
                        payPercent = licensePayPercent,
                        paymentAmount = dailyAmount,
                        createdAt = now
                    )
                }
            )
        }
    }

    suspend fun rejectRequest(
        requestId: Int,
        reviewedBy: String,
        reason: String,
        now: String
    ) {
        requestDao.rejectRequest(
            requestId = requestId,
            status = EmployeePermissionRequestEntity.STATUS_REJECTED,
            reviewedBy = reviewedBy,
            reviewedDate = now,
            rejectionReason = reason,
            updatedAt = now
        )
        dailyPaymentDao.deactivateByRequest(requestId)
    }

    private fun datesBetween(start: String, end: String): List<String> {
        val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        return try {
            val startDate = formatter.parse(start) ?: return emptyList()
            val endDate = formatter.parse(end) ?: return emptyList()
            if (endDate.before(startDate)) return emptyList()
            val calendar = Calendar.getInstance().apply { time = startDate }
            val finalCalendar = Calendar.getInstance().apply { time = endDate }
            val dates = mutableListOf<String>()
            while (!calendar.after(finalCalendar)) {
                dates += formatter.format(calendar.time)
                calendar.add(Calendar.DAY_OF_MONTH, 1)
            }
            dates
        } catch (e: Exception) {
            emptyList()
        }
    }
}
