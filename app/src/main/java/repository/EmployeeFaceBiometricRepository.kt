package com.example.controlhorario.repository

import com.example.controlhorario.database.EmployeeFaceBiometricDao
import com.example.controlhorario.database.EmployeeFaceBiometricEntity
import com.example.controlhorario.database.FaceIdentificationTemplateRecord
import com.example.controlhorario.face.FaceTemplateInvalidationBus

class EmployeeFaceBiometricRepository(private val dao: EmployeeFaceBiometricDao) {
    suspend fun activeForEmployee(employeeId: Int) = dao.activeForEmployee(employeeId)
    suspend fun hasAnyForEmployee(employeeId: Int) = dao.hasAnyForEmployee(employeeId)
    suspend fun identificationTemplates(
        remoteCompanyId: String,
        remoteBranchId: String?
    ): List<FaceIdentificationTemplateRecord> =
        dao.identificationTemplates(remoteCompanyId, remoteBranchId)
    suspend fun replace(entity: EmployeeFaceBiometricEntity): Long =
        dao.replaceForEmployee(entity).also { FaceTemplateInvalidationBus.invalidate() }

    suspend fun insertIfAbsent(entity: EmployeeFaceBiometricEntity): Long =
        dao.insertIfAbsent(entity).also { insertedId ->
            if (insertedId > 0L) FaceTemplateInvalidationBus.invalidate()
        }

    suspend fun delete(employeeId: Int): Int = dao.deleteForEmployee(employeeId).also { deleted ->
        if (deleted > 0) FaceTemplateInvalidationBus.invalidate()
    }
}
