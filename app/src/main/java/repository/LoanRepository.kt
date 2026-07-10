package com.example.controlhorario.repository

import com.example.controlhorario.database.LoanDao
import com.example.controlhorario.database.LoanEntity
import kotlinx.coroutines.flow.Flow

class LoanRepository(
    private val loanDao: LoanDao
) {
    fun getAllLoans(): Flow<List<LoanEntity>> =
        loanDao.getAllLoans()

    fun getLoansByEmployee(employeeId: Int): Flow<List<LoanEntity>> =
        loanDao.getLoansByEmployee(employeeId)

    fun getLoansByStatus(status: String): Flow<List<LoanEntity>> =
        loanDao.getLoansByStatus(status)

    fun getLoanById(loanId: Int): Flow<LoanEntity?> =
        loanDao.getLoanById(loanId)

    suspend fun saveLoan(loan: LoanEntity) {
        loanDao.saveLoan(loan)
    }

    suspend fun approveLoan(
        loanId: Int,
        approvedAmount: Double,
        payrollDiscount: Double,
        approvedBy: String,
        approvedDate: String,
        updatedAt: String
    ) {
        loanDao.approveLoan(
            loanId = loanId,
            status = LoanEntity.STATUS_APPROVED,
            approvedAmount = approvedAmount,
            balance = approvedAmount,
            payrollDiscount = payrollDiscount,
            approvedBy = approvedBy,
            approvedDate = approvedDate,
            updatedAt = updatedAt
        )
    }

    suspend fun deliverLoan(
        loanId: Int,
        deliveredBy: String,
        deliveredDate: String,
        updatedAt: String
    ) {
        loanDao.deliverLoan(
            loanId = loanId,
            status = LoanEntity.STATUS_DELIVERED,
            deliveredBy = deliveredBy,
            deliveredDate = deliveredDate,
            updatedAt = updatedAt
        )
    }

    suspend fun registerPayment(
        loan: LoanEntity,
        paymentAmount: Double,
        updatedAt: String
    ) {
        val paidAmount = loan.paidAmount + paymentAmount
        val balance = (loan.balance - paymentAmount).coerceAtLeast(0.0)
        val status = if (balance <= 0.0) LoanEntity.STATUS_PAID else loan.status
        loanDao.registerPayment(
            loanId = loan.id,
            paidAmount = paidAmount,
            balance = balance,
            status = status,
            updatedAt = updatedAt
        )
    }

    suspend fun rejectLoan(
        loanId: Int,
        rejectedBy: String,
        rejectedDate: String,
        rejectionReason: String,
        updatedAt: String
    ) {
        loanDao.rejectLoan(
            loanId = loanId,
            status = LoanEntity.STATUS_REJECTED,
            rejectedBy = rejectedBy,
            rejectedDate = rejectedDate,
            rejectionReason = rejectionReason,
            updatedAt = updatedAt
        )
    }

    suspend fun cancelLoan(loanId: Int, updatedAt: String) {
        loanDao.cancelLoan(loanId, LoanEntity.STATUS_CANCELLED, updatedAt)
    }

    suspend fun deactivateLoan(loanId: Int, updatedAt: String) {
        loanDao.deactivateLoan(loanId, updatedAt)
    }
}
