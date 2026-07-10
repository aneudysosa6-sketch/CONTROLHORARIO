package com.example.controlhorario.repository

import com.example.controlhorario.database.SupervisorDao
import com.example.controlhorario.database.SupervisorDepartmentEntity
import com.example.controlhorario.database.SupervisorEntity
import kotlinx.coroutines.flow.Flow

class SupervisorRepository(
    private val dao: SupervisorDao
) {
    fun getAllSupervisors(): Flow<List<SupervisorEntity>> = dao.getAllSupervisors()

    fun getDepartmentIdsForSupervisor(supervisorId: Int): Flow<List<Int>> =
        dao.getDepartmentIdsForSupervisor(supervisorId)

    suspend fun getDepartmentIdsNow(supervisorId: Int): List<Int> = dao.getDepartmentIdsNow(supervisorId)

    suspend fun login(username: String, password: String): SupervisorEntity? = dao.login(username, password)

    suspend fun saveSupervisor(supervisor: SupervisorEntity, departmentIds: List<Int>) {
        val id = dao.save(supervisor).toInt().takeIf { it > 0 } ?: supervisor.id
        dao.clearDepartments(id)
        departmentIds.distinct().forEach { departmentId ->
            dao.addDepartmentCrossRef(SupervisorDepartmentEntity(supervisorId = id, departmentId = departmentId))
        }
    }

    suspend fun setActive(supervisorId: Int, active: Boolean) = dao.setActive(supervisorId, active)
}
