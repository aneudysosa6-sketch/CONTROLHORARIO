package com.example.controlhorario.repository

import com.example.controlhorario.database.SupervisorPermissionDao
import com.example.controlhorario.database.SupervisorPermissionEntity
import kotlinx.coroutines.flow.Flow

class SupervisorPermissionRepository(
    private val dao: SupervisorPermissionDao
) {
    fun getAll(): Flow<List<SupervisorPermissionEntity>> = dao.getAll()
    fun getBySupervisor(supervisorUserId: Int): Flow<List<SupervisorPermissionEntity>> = dao.getBySupervisor(supervisorUserId)
    suspend fun save(entity: SupervisorPermissionEntity) = dao.save(entity)
    suspend fun deactivate(id: Int, updatedAt: String) = dao.deactivate(id, updatedAt)
}
