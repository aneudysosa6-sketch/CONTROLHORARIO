package com.example.controlhorario.repository

import com.example.controlhorario.database.LoanDao
import com.example.controlhorario.database.LoanEntity
import com.example.controlhorario.engine.LoanLifecyclePolicy
import kotlinx.coroutines.flow.Flow

class LoanRepository(private val loanDao:LoanDao) {
    fun getAllLoans():Flow<List<LoanEntity>> = loanDao.getAllLoans()
    fun getLoansByEmployee(employeeId:Int)=loanDao.getLoansByEmployee(employeeId)
    fun getLoansByStatus(status:String)=loanDao.getLoansByStatus(status)
    fun getLoanById(loanId:Int)=loanDao.getLoanById(loanId)

    suspend fun saveLoan(loan:LoanEntity):Boolean {
        if(!LoanLifecyclePolicy.canCreate(loan.requestedAmount)) return false
        loanDao.saveLoan(loan)
        return true
    }
    suspend fun approveLoan(loanId:Int,approvedAmount:Double,payrollDiscount:Double,approvedBy:String,approvedDate:String,updatedAt:String):Boolean {
        if(!LoanLifecyclePolicy.canApprove(LoanEntity.STATUS_PENDING,approvedAmount,payrollDiscount)) return false
        return loanDao.approveLoan(loanId,LoanEntity.STATUS_APPROVED,approvedAmount,approvedAmount,payrollDiscount,approvedBy,approvedDate,updatedAt)==1
    }
    suspend fun deliverLoan(loanId:Int,deliveredBy:String,deliveredDate:String,updatedAt:String):Boolean =
        loanDao.deliverLoan(loanId,LoanEntity.STATUS_DELIVERED,deliveredBy,deliveredDate,updatedAt)==1
    suspend fun registerPayment(loan:LoanEntity,paymentAmount:Double,updatedAt:String):Boolean {
        val update=LoanLifecyclePolicy.paymentUpdate(loan,paymentAmount)?:return false
        return loanDao.registerPayment(loan.id,update.paidAmount,update.balance,update.status,updatedAt)==1
    }
    suspend fun rejectLoan(loanId:Int,rejectedBy:String,rejectedDate:String,rejectionReason:String,updatedAt:String):Boolean {
        if(!LoanLifecyclePolicy.canReject(LoanEntity.STATUS_PENDING,rejectionReason)) return false
        return loanDao.rejectLoan(loanId,LoanEntity.STATUS_REJECTED,rejectedBy,rejectedDate,rejectionReason,updatedAt)==1
    }
    suspend fun cancelLoan(loanId:Int,updatedAt:String):Boolean =
        loanDao.cancelLoan(loanId,LoanEntity.STATUS_CANCELLED,updatedAt)==1
    suspend fun deactivateLoan(loanId:Int,updatedAt:String){loanDao.deactivateLoan(loanId,updatedAt)}
}