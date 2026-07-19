package com.example.controlhorario.repository

import com.example.controlhorario.database.EmployeeFaceBiometricDao
import com.example.controlhorario.database.EmployeeFaceBiometricEntity

class EmployeeFaceBiometricRepository(private val dao: EmployeeFaceBiometricDao) {
    suspend fun activeForEmployee(employeeId: Int) = dao.activeForEmployee(employeeId)
    suspend fun replace(entity: EmployeeFaceBiometricEntity) = dao.replaceForEmployee(entity)
    suspend fun delete(employeeId: Int) = dao.deleteForEmployee(employeeId)
}
