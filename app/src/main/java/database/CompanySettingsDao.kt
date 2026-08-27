package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface CompanySettingsDao {

    @Query("SELECT * FROM company_settings WHERE id = 1 LIMIT 1")
    fun getCompanySettings(): Flow<CompanySettingsEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveCompanySettings(settings: CompanySettingsEntity)
}