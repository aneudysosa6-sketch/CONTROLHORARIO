package com.example.controlhorario.repository

import com.example.controlhorario.database.PayrollSettingsDao
import com.example.controlhorario.database.PayrollSettingsEntity
import kotlinx.coroutines.flow.Flow

class PayrollSettingsRepository(
    private val dao: PayrollSettingsDao
) {
    fun getPayrollSettings(): Flow<PayrollSettingsEntity?> {
        return dao.getPayrollSettings()
    }

    suspend fun savePayrollSettings(settings: PayrollSettingsEntity) {
        dao.savePayrollSettings(settings)
    }
}