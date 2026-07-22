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

    @Query("SELECT EXISTS(SELECT 1 FROM employee_face_biometrics WHERE employeeId = :employeeId)")
    suspend fun hasAnyForEmployee(employeeId: Int): Boolean

    @Query(
        """
        SELECT
            face.employeeId AS employeeId,
            employee.employeeCode AS employeeCode,
            employee.nombre AS employeeName,
            employee.remoteCompanyId AS remoteCompanyId,
            employee.remoteBranchId AS remoteBranchId,
            employee.isActive AS employeeActive,
            employee.jornadaEnabled AS jornadaEnabled,
            face.isActive AS biometricActive,
            face.encryptedEmbedding AS encryptedEmbedding,
            face.embeddingDimension AS embeddingDimension
        FROM employee_face_biometrics AS face
        INNER JOIN employees AS employee ON employee.id = face.employeeId
        WHERE face.isActive = 1
          AND employee.isActive = 1
          AND employee.jornadaEnabled = 1
          AND LOWER(TRIM(employee.employmentStatus)) IN ('activo', 'active')
          AND employee.remoteCompanyId = :remoteCompanyId
          AND (:remoteBranchId IS NULL OR employee.remoteBranchId = :remoteBranchId)
        ORDER BY employee.employeeCode ASC
        """
    )
    suspend fun identificationTemplates(
        remoteCompanyId: String,
        remoteBranchId: String?
    ): List<FaceIdentificationTemplateRecord>

    @Insert(onConflict = OnConflictStrategy.ABORT)
    suspend fun insert(entity: EmployeeFaceBiometricEntity): Long

    /**
     * Initial employee self-enrollment must never replace an existing template. The unique
     * employeeId index is the final local guard against two concurrent enrollment attempts.
     */
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertIfAbsent(entity: EmployeeFaceBiometricEntity): Long

    @Query("DELETE FROM employee_face_biometrics WHERE employeeId = :employeeId")
    suspend fun deleteForEmployee(employeeId: Int): Int

    @Query(
        "DELETE FROM employee_face_biometrics " +
            "WHERE employeeId = :employeeId AND registeredBy = 'EMPLOYEE_SELF_SERVICE'"
    )
    suspend fun deleteInitialSelfEnrollment(employeeId: Int): Int

    @Transaction
    suspend fun replaceForEmployee(entity: EmployeeFaceBiometricEntity): Long {
        deleteForEmployee(entity.employeeId)
        return insert(entity)
    }
}
