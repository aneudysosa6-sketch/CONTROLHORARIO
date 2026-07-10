package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface EmployeeBiometricDao {
    @Query("SELECT * FROM employee_biometrics WHERE isActive = 1 ORDER BY id DESC")
    fun getAll(): Flow<List<EmployeeBiometricEntity>>

    @Query("SELECT * FROM employee_biometrics WHERE employeeId = :employeeId AND isActive = 1 LIMIT 1")
    fun getByEmployee(employeeId: Int): Flow<EmployeeBiometricEntity?>

    @Query("SELECT * FROM employee_biometrics WHERE employeeId = :employeeId AND isActive = 1 ORDER BY id DESC LIMIT 1")
    suspend fun getActiveByEmployee(employeeId: Int): EmployeeBiometricEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(entity: EmployeeBiometricEntity)

    @Query("UPDATE employee_biometrics SET isActive = 0, updatedAt = :updatedAt WHERE employeeId = :employeeId")
    suspend fun deactivateByEmployee(employeeId: Int, updatedAt: String)
}
