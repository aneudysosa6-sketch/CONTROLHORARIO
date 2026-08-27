package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface PayrollSettingsDao {

    @Query("SELECT * FROM payroll_settings WHERE id = 1 LIMIT 1")
    fun getPayrollSettings(): Flow<PayrollSettingsEntity?>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun savePayrollSettings(settings: PayrollSettingsEntity)
}