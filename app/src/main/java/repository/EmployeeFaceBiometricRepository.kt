package com.example.controlhorario.repository

import com.example.controlhorario.database.EmployeeFaceBiometricDao
import com.example.controlhorario.database.EmployeeFaceBiometricEntity
import com.example.controlhorario.database.FaceIdentificationTemplateRecord

class EmployeeFaceBiometricRepository(private val dao: EmployeeFaceBiometricDao) {
    suspend fun activeForEmployee(employeeId: Int) = dao.activeForEmployee(employeeId)
    suspend fun hasAnyForEmployee(employeeId: Int) = dao.hasAnyForEmployee(employeeId)
    suspend fun identificationTemplates(
        remoteCompanyId: String,
        remoteBranchId: String?
    ): List<FaceIdentificationTemplateRecord> =
        dao.identificationTemplates(remoteCompanyId, remoteBranchId)
    suspend fun replace(entity: EmployeeFaceBiometricEntity) = dao.replaceForEmployee(entity)
    suspend fun insertIfAbsent(entity: EmployeeFaceBiometricEntity) = dao.insertIfAbsent(entity)
    suspend fun delete(employeeId: Int) = dao.deleteForEmployee(employeeId)
}
