package com.example.controlhorario.repository

import com.example.controlhorario.database.EmployeePayrollSettingsDao
import com.example.controlhorario.database.EmployeePayrollSettingsEntity
import kotlinx.coroutines.flow.Flow

class EmployeePayrollSettingsRepository(
    private val dao: EmployeePayrollSettingsDao
) {
    fun getSettingsByEmployee(employeeId: Int): Flow<EmployeePayrollSettingsEntity?> {
        return dao.getSettingsByEmployee(employeeId)
    }

    fun getAllSettings(): Flow<List<EmployeePayrollSettingsEntity>> {
        return dao.getAllSettings()
    }

    suspend fun saveSettings(settings: EmployeePayrollSettingsEntity) {
        dao.saveSettings(settings)
    }

    suspend fun saveAllSettings(settings: List<EmployeePayrollSettingsEntity>) {
        dao.saveAllSettings(settings)
    }
}
