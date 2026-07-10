package com.example.controlhorario.repository

import com.example.controlhorario.database.PayrollHistoryDao
import com.example.controlhorario.database.PayrollHistoryEntity
import kotlinx.coroutines.flow.Flow

class PayrollHistoryRepository(
    private val dao: PayrollHistoryDao
) {
    fun getHistoryByEmployee(employeeId: Int): Flow<List<PayrollHistoryEntity>> {
        return dao.getHistoryByEmployee(employeeId)
    }

    suspend fun insertPayrollHistory(history: PayrollHistoryEntity) {
        dao.insertPayrollHistory(history)
    }
}