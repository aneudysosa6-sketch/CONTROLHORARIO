package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface EmployeePayrollSettingsDao {

    @Query("SELECT * FROM employee_payroll_settings WHERE employeeId = :employeeId LIMIT 1")
    fun getSettingsByEmployee(employeeId: Int): Flow<EmployeePayrollSettingsEntity?>

    @Query("SELECT * FROM employee_payroll_settings")
    fun getAllSettings(): Flow<List<EmployeePayrollSettingsEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveSettings(settings: EmployeePayrollSettingsEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveAllSettings(settings: List<EmployeePayrollSettingsEntity>)
}
