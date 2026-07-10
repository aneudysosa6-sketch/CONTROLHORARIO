package com.example.controlhorario.repository

import com.example.controlhorario.database.EmployeeBiometricDao
import com.example.controlhorario.database.EmployeeBiometricEntity
import kotlinx.coroutines.flow.Flow

class EmployeeBiometricRepository(
    private val dao: EmployeeBiometricDao
) {
    fun getAll(): Flow<List<EmployeeBiometricEntity>> = dao.getAll()
    fun getByEmployee(employeeId: Int): Flow<EmployeeBiometricEntity?> = dao.getByEmployee(employeeId)
    suspend fun getActiveByEmployee(employeeId: Int): EmployeeBiometricEntity? = dao.getActiveByEmployee(employeeId)
    suspend fun save(entity: EmployeeBiometricEntity) = dao.save(entity)
    suspend fun deactivateByEmployee(employeeId: Int, updatedAt: String) = dao.deactivateByEmployee(employeeId, updatedAt)
}
