package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface PayrollHistoryDao {

    @Query("SELECT * FROM payroll_history WHERE employeeId = :employeeId ORDER BY id DESC")
    fun getHistoryByEmployee(employeeId: Int): Flow<List<PayrollHistoryEntity>>

    @Insert
    suspend fun insertPayrollHistory(history: PayrollHistoryEntity)
}