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

    /** Local creation must never replace an employee when a code collides. */
    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insertNewEmployee(employee: Employee): Long

    @Update
    suspend fun updateEmployee(employee: Employee)

    @Query("SELECT * FROM employees WHERE isActive = 1 AND LOWER(TRIM(employmentStatus)) != 'desvinculado' ORDER BY id DESC")
    fun getAllEmployees(): Flow<List<Employee>>

    @Query("SELECT * FROM employees WHERE isActive = 0 OR LOWER(TRIM(employmentStatus)) = 'desvinculado' ORDER BY updatedAt DESC")
    fun getTerminatedEmployees(): Flow<List<Employee>>

    @Query("SELECT * FROM employees WHERE id = :employeeId LIMIT 1")
    fun getEmployeeById(employeeId: Int): Flow<Employee?>

    @Query("SELECT * FROM employees WHERE id = :employeeId LIMIT 1")
    suspend fun findByLocalId(employeeId: Int): Employee?

    @Query("SELECT * FROM employees WHERE employeeCode = :employeeCode AND isActive = 1 AND remoteId IS NOT NULL LIMIT 1")
    suspend fun findByEmployeeCode(employeeCode: String): Employee?

    @Query("SELECT * FROM employees WHERE employeeCode IN (:employeeCodes) AND isActive = 1 AND remoteId IS NOT NULL")
    suspend fun findByEmployeeCodes(employeeCodes: List<String>): List<Employee>

    @Query("""
        SELECT employeeCode
        FROM employees
        WHERE employeeCode != ''
        ORDER BY CAST(employeeCode AS INTEGER) DESC
        LIMIT 1
    """)
    suspend fun getLastEmployeeCode(): String?

    @Query("SELECT employeeCode FROM employees WHERE employeeCode != ''")
    suspend fun getAllEmployeeCodes(): List<String>

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

    @Query("SELECT * FROM employees WHERE employeeCode IN (:employeeCodes)")
    suspend fun findAnyByEmployeeCodes(employeeCodes: List<String>): List<Employee>

    @Query("SELECT * FROM employees WHERE remoteId = :remoteId LIMIT 1")
    suspend fun findByRemoteId(remoteId: String): Employee?

    @Query("SELECT * FROM employees WHERE departmentId IN (:departmentIds) AND isActive = 1 AND LOWER(TRIM(employmentStatus)) != 'desvinculado' ORDER BY employeeCode ASC")
    fun getEmployeesByDepartments(departmentIds: List<Int>): Flow<List<Employee>>

    @Query("SELECT * FROM employees WHERE branchId = :branchId AND isActive = 1 AND LOWER(TRIM(employmentStatus)) != 'desvinculado' ORDER BY employeeCode ASC")
    fun getEmployeesByBranch(branchId: Int): Flow<List<Employee>>

    @Query("UPDATE employees SET isActive = :active, updatedAt = :updatedAt WHERE id = :employeeId")
    suspend fun setEmployeeActive(employeeId: Int, active: Boolean, updatedAt: Long = System.currentTimeMillis())

    @Query("UPDATE employees SET jornadaEnabled = :enabled, updatedAt = :updatedAt WHERE id = :employeeId")
    suspend fun setJornadaEnabled(employeeId: Int, enabled: Boolean, updatedAt: Long = System.currentTimeMillis())

    @Query("SELECT COUNT(*) FROM employees WHERE remoteId IS NOT NULL")
    fun observeSyncedTotal(): Flow<Int>

    @Query("SELECT COUNT(*) FROM employees WHERE remoteId IS NOT NULL AND isActive = 1 AND LOWER(TRIM(employmentStatus)) != 'desvinculado'")
    fun observeSyncedActive(): Flow<Int>

    @Query("SELECT COUNT(*) FROM employees WHERE remoteId IS NOT NULL AND (isActive = 0 OR LOWER(TRIM(employmentStatus)) = 'desvinculado')")
    fun observeSyncedInactive(): Flow<Int>

    @Query("UPDATE employees SET pin='',remoteId=:remoteId,syncStatus='SYNCED',lastSyncError=NULL,remoteUpdatedAt=:remoteUpdatedAt,lastSyncedAt=:now WHERE id=:employeeId")
    suspend fun markRemoteSynced(employeeId:Int,remoteId:String,remoteUpdatedAt:String,now:Long)

    @Query("UPDATE employees SET employeeCode=:employeeCode,pin='',remoteId=:remoteId,syncStatus='SYNCED',lastSyncError=NULL,remoteUpdatedAt=:remoteUpdatedAt,lastSyncedAt=:now,updatedAt=:now WHERE id=:employeeId")
    suspend fun markCreateRemoteSynced(employeeId:Int,employeeCode:String,remoteId:String,remoteUpdatedAt:String,now:Long)

    /** Internal only: relocates a not-yet-synced local placeholder during authoritative adoption. */
    @Query("UPDATE employees SET employeeCode=:employeeCode,pin='',updatedAt=:now WHERE id=:employeeId")
    suspend fun updateProvisionalEmployeeCode(employeeId:Int,employeeCode:String,now:Long)

    @Query("UPDATE employees SET syncStatus=:status,lastSyncError=:error WHERE id=:employeeId")
    suspend fun setSyncStatus(employeeId:Int,status:String,error:String?=null)

    /** Upload workers must never overwrite the authoritative tombstone state. */
    @Query("""
        UPDATE employees
        SET syncStatus=:status,lastSyncError=:error
        WHERE id=:employeeId
          AND NOT (isActive = 0 AND LOWER(TRIM(employmentStatus)) = 'desvinculado')
    """)
    suspend fun setUploadSyncStatus(employeeId:Int,status:String,error:String?=null):Int

    @Query("UPDATE employees SET remoteCompanyId=:companyId WHERE remoteId IS NOT NULL AND remoteCompanyId IS NULL")
    suspend fun backfillRemoteCompanyScope(companyId:String):Int
}
