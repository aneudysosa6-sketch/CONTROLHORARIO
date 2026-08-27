package com.example.controlhorario.repository

import com.example.controlhorario.database.CompanySettingsDao
import com.example.controlhorario.database.CompanySettingsEntity
import kotlinx.coroutines.flow.Flow

class CompanySettingsRepository(
    private val dao: CompanySettingsDao
) {
    fun getCompanySettings(): Flow<CompanySettingsEntity?> {
        return dao.getCompanySettings()
    }

    suspend fun saveCompanySettings(settings: CompanySettingsEntity) {
        dao.saveCompanySettings(settings)
    }
}