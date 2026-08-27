package com.example.controlhorario.repository

import com.example.controlhorario.database.SupervisorEventDao
import com.example.controlhorario.database.SupervisorEventEntity
import kotlinx.coroutines.flow.Flow

class SupervisorEventRepository(
    private val dao: SupervisorEventDao
) {
    fun getEventsForSupervisor(supervisorId: Int): Flow<List<SupervisorEventEntity>> =
        dao.getEventsForSupervisor(supervisorId)

    fun getAllEvents(): Flow<List<SupervisorEventEntity>> =
        dao.getAllEvents()

    suspend fun clearCalculatedEvents(supervisorId: Int, eventDate: String) =
        dao.clearCalculatedEvents(supervisorId, eventDate)

    suspend fun insert(event: SupervisorEventEntity) = dao.insert(event)
}
