package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface LoanDao {
    @Query("SELECT * FROM loans WHERE isActive = 1 ORDER BY id DESC")
    fun getAllLoans(): Flow<List<LoanEntity>>

    @Query("SELECT * FROM loans WHERE employeeId = :employeeId AND isActive = 1 ORDER BY id DESC")
    fun getLoansByEmployee(employeeId: Int): Flow<List<LoanEntity>>

    @Query("SELECT * FROM loans WHERE status = :status AND isActive = 1 ORDER BY id DESC")
    fun getLoansByStatus(status: String): Flow<List<LoanEntity>>

    @Query("SELECT * FROM loans WHERE id = :loanId LIMIT 1")
    fun getLoanById(loanId: Int): Flow<LoanEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveLoan(loan: LoanEntity)

    @Query("""
        UPDATE loans
        SET status = :status,
            approvedAmount = :approvedAmount,
            balance = :balance,
            payrollDiscount = :payrollDiscount,
            approvedBy = :approvedBy,
            approvedDate = :approvedDate,
            updatedAt = :updatedAt
        WHERE id = :loanId
    """)
    suspend fun approveLoan(
        loanId: Int,
        status: String,
        approvedAmount: Double,
        balance: Double,
        payrollDiscount: Double,
        approvedBy: String,
        approvedDate: String,
        updatedAt: String
    )

    @Query("""
        UPDATE loans
        SET status = :status,
            deliveredBy = :deliveredBy,
            deliveredDate = :deliveredDate,
            updatedAt = :updatedAt
        WHERE id = :loanId
    """)
    suspend fun deliverLoan(
        loanId: Int,
        status: String,
        deliveredBy: String,
        deliveredDate: String,
        updatedAt: String
    )

    @Query("""
        UPDATE loans
        SET paidAmount = :paidAmount,
            balance = :balance,
            status = :status,
            updatedAt = :updatedAt
        WHERE id = :loanId
    """)
    suspend fun registerPayment(
        loanId: Int,
        paidAmount: Double,
        balance: Double,
        status: String,
        updatedAt: String
    )

    @Query("""
        UPDATE loans
        SET status = :status,
            rejectedBy = :rejectedBy,
            rejectedDate = :rejectedDate,
            rejectionReason = :rejectionReason,
            updatedAt = :updatedAt
        WHERE id = :loanId
    """)
    suspend fun rejectLoan(
        loanId: Int,
        status: String,
        rejectedBy: String,
        rejectedDate: String,
        rejectionReason: String,
        updatedAt: String
    )

    @Query("UPDATE loans SET status = :status, updatedAt = :updatedAt WHERE id = :loanId")
    suspend fun cancelLoan(loanId: Int, status: String, updatedAt: String)

    @Query("UPDATE loans SET isActive = 0, updatedAt = :updatedAt WHERE id = :loanId")
    suspend fun deactivateLoan(loanId: Int, updatedAt: String)
}
