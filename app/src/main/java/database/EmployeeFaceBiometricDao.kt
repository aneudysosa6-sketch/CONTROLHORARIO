package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction

@Dao
interface EmployeeFaceBiometricDao {
    @Query("SELECT * FROM employee_face_biometrics WHERE employeeId = :employeeId AND isActive = 1 LIMIT 1")
    suspend fun activeForEmployee(employeeId: Int): EmployeeFaceBiometricEntity?

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(entity: EmployeeFaceBiometricEntity): Long

    @Query("DELETE FROM employee_face_biometrics WHERE employeeId = :employeeId")
    suspend fun deleteForEmployee(employeeId: Int): Int

    @Transaction
    suspend fun replaceForEmployee(entity: EmployeeFaceBiometricEntity): Long {
        deleteForEmployee(entity.employeeId)
        return insert(entity)
    }
}
