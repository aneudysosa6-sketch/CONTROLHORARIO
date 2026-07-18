package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

data class EmployeeBiometricReplacement(
    val deletedRows: Int,
    val insertedId: Long
)

@Dao
interface EmployeeBiometricDao {
    @Query("SELECT * FROM employee_biometrics WHERE isActive = 1 ORDER BY updatedAt DESC, id DESC")
    fun getAll(): Flow<List<EmployeeBiometricEntity>>

    @Query("SELECT * FROM employee_biometrics WHERE employeeId = :employeeId AND isActive = 1 ORDER BY updatedAt DESC, id DESC")
    fun getByEmployee(employeeId: Int): Flow<List<EmployeeBiometricEntity>>

    /**
     * Returns every active row so the repository can report legacy duplicates instead of
     * silently selecting an arbitrary record.  New writes use [replaceForEmployee], which
     * guarantees exactly one row for an employee.
     */
    @Query("SELECT * FROM employee_biometrics WHERE employeeId = :employeeId AND isActive = 1 ORDER BY updatedAt DESC, id DESC")
    suspend fun getActiveRowsByEmployee(employeeId: Int): List<EmployeeBiometricEntity>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(entity: EmployeeBiometricEntity): Long

    @Query("DELETE FROM employee_biometrics WHERE employeeId = :employeeId")
    suspend fun deleteAllByEmployee(employeeId: Int): Int

    /**
     * Replacing a reference is atomic: no concurrent verifier can observe an old/new mixed
     * set and no stale active rows survive a new registration.
     */
    @Transaction
    suspend fun replaceForEmployee(entity: EmployeeBiometricEntity): EmployeeBiometricReplacement {
        val deletedRows = deleteAllByEmployee(entity.employeeId)
        val insertedId = insert(entity)
        return EmployeeBiometricReplacement(deletedRows, insertedId)
    }
}
