package com.example.controlhorario.repository

import com.example.controlhorario.database.SupervisorWorkScheduleDao
import com.example.controlhorario.database.SupervisorWorkScheduleEntity
import kotlinx.coroutines.flow.Flow

class SupervisorWorkScheduleRepository(
    private val dao: SupervisorWorkScheduleDao
) {
    fun getAll(): Flow<List<SupervisorWorkScheduleEntity>> = dao.getAll()

    suspend fun getByEmployeeId(employeeId: Int): SupervisorWorkScheduleEntity? = dao.getByEmployeeId(employeeId)

    suspend fun save(schedule: SupervisorWorkScheduleEntity) = dao.save(schedule)
}
