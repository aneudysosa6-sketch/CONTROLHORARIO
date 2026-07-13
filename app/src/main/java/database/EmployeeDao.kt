package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.example.controlhorario.model.Employee
import kotlinx.coroutines.flow.Flow

@Dao
interface EmployeeDao {

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertEmployee(employee: Employee): Long

    @Update
    suspend fun updateEmployee(employee: Employee)

    @Query("SELECT * FROM employees WHERE isActive = 1 ORDER BY id DESC")
    fun getAllEmployees(): Flow<List<Employee>>

    @Query("SELECT * FROM employees WHERE id = :employeeId LIMIT 1")
    fun getEmployeeById(employeeId: Int): Flow<Employee?>

    @Query("SELECT * FROM employees WHERE id = :employeeId LIMIT 1")
    suspend fun findByLocalId(employeeId: Int): Employee?

    @Query("SELECT * FROM employees WHERE employeeCode = :employeeCode AND isActive = 1 LIMIT 1")
    suspend fun findByEmployeeCode(employeeCode: String): Employee?

    @Query("SELECT * FROM employees WHERE pin = :pin AND isActive = 1 LIMIT 1")
    suspend fun findByPin(pin: String): Employee?

    @Query("""
        SELECT employeeCode
        FROM employees
        WHERE employeeCode != ''
        ORDER BY CAST(employeeCode AS INTEGER) DESC
        LIMIT 1
    """)
    suspend fun getLastEmployeeCode(): String?

    @Query("""
        UPDATE employees
        SET fingerprintRegistered = 1,
            fingerprintRegisteredAt = :registeredAt,
            fingerprintRegisteredBy = :registeredBy,
            updatedAt = :updatedAt
        WHERE id = :employeeId
    """)
    suspend fun markFingerprintRegistered(
        employeeId: Int,
        registeredAt: String,
        registeredBy: String,
        updatedAt: Long = System.currentTimeMillis()
    )

    @Query("SELECT * FROM employees WHERE employeeCode = :employeeCode LIMIT 1")
    suspend fun findAnyByEmployeeCode(employeeCode: String): Employee?

    @Query("SELECT * FROM employees WHERE pin = :pin LIMIT 1")
    suspend fun findAnyByPin(pin: String): Employee?

    @Query("SELECT * FROM employees WHERE remoteId = :remoteId LIMIT 1")
    suspend fun findByRemoteId(remoteId: String): Employee?

    @Query("SELECT * FROM employees WHERE departmentId IN (:departmentIds) ORDER BY employeeCode ASC")
    fun getEmployeesByDepartments(departmentIds: List<Int>): Flow<List<Employee>>

    @Query("SELECT * FROM employees WHERE branchId = :branchId ORDER BY employeeCode ASC")
    fun getEmployeesByBranch(branchId: Int): Flow<List<Employee>>

    @Query("UPDATE employees SET isActive = :active, updatedAt = :updatedAt WHERE id = :employeeId")
    suspend fun setEmployeeActive(employeeId: Int, active: Boolean, updatedAt: Long = System.currentTimeMillis())

    @Query("UPDATE employees SET jornadaEnabled = :enabled, updatedAt = :updatedAt WHERE id = :employeeId")
    suspend fun setJornadaEnabled(employeeId: Int, enabled: Boolean, updatedAt: Long = System.currentTimeMillis())

    @Query("SELECT COUNT(*) FROM employees WHERE remoteId IS NOT NULL")
    fun observeSyncedTotal(): Flow<Int>

    @Query("SELECT COUNT(*) FROM employees WHERE remoteId IS NOT NULL AND isActive = 1")
    fun observeSyncedActive(): Flow<Int>

    @Query("SELECT COUNT(*) FROM employees WHERE remoteId IS NOT NULL AND isActive = 0")
    fun observeSyncedInactive(): Flow<Int>
}
