package com.example.controlhorario.repository

import com.example.controlhorario.database.DepartmentDao
import com.example.controlhorario.database.DepartmentEntity
import kotlinx.coroutines.flow.Flow

class DepartmentRepository(
    private val dao: DepartmentDao
) {
    fun getAllDepartments(): Flow<List<DepartmentEntity>> = dao.getAllDepartments()

    fun getDepartmentsByBranch(branchId: Int): Flow<List<DepartmentEntity>> =
        dao.getDepartmentsByBranch(branchId)

    suspend fun insert(department: DepartmentEntity) {
        dao.insert(department)
    }

    suspend fun update(department: DepartmentEntity) {
        dao.update(department)
    }

    suspend fun setActive(department: DepartmentEntity, active: Boolean) {
        dao.update(department.copy(active = active))
    }
}