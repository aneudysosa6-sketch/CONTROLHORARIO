package com.example.controlhorario.repository

import com.example.controlhorario.database.EmployeeFaceBiometricDao
import com.example.controlhorario.database.EmployeeFaceBiometricEntity
import com.example.controlhorario.database.FaceIdentificationTemplateRecord
import com.example.controlhorario.face.FaceEmbeddingEngine
import com.example.controlhorario.face.FaceTemplateInvalidationBus
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertTrue
import org.junit.Test

class EmployeeFaceBiometricRepositoryTest {
    @Test
    fun `replacing a face invalidates an already loaded identification cache`() = runBlocking {
        val before = FaceTemplateInvalidationBus.currentRevision
        val repository = EmployeeFaceBiometricRepository(FakeFaceDao())

        repository.replace(
            EmployeeFaceBiometricEntity(
                employeeId = 7,
                encryptedEmbedding = "encrypted",
                embeddingVersion = 1,
                modelName = "FaceNet-128",
                embeddingDimension = FaceEmbeddingEngine.EMBEDDING_DIMENSION,
                registeredAt = "2026-07-22T00:00:00Z",
                registeredBy = "TEST",
                updatedAt = "2026-07-22T00:00:00Z"
            )
        )

        assertTrue(FaceTemplateInvalidationBus.currentRevision > before)
    }

    private class FakeFaceDao : EmployeeFaceBiometricDao {
        override suspend fun activeForEmployee(employeeId: Int): EmployeeFaceBiometricEntity? = null
        override suspend fun hasAnyForEmployee(employeeId: Int): Boolean = false
        override suspend fun identificationTemplates(
            remoteCompanyId: String,
            remoteBranchId: String?
        ): List<FaceIdentificationTemplateRecord> = emptyList()

        override suspend fun insert(entity: EmployeeFaceBiometricEntity): Long = 1L
        override suspend fun insertIfAbsent(entity: EmployeeFaceBiometricEntity): Long = 1L
        override suspend fun deleteForEmployee(employeeId: Int): Int = 1
        override suspend fun deleteInitialSelfEnrollment(employeeId: Int): Int = 1
    }
}
