package com.example.controlhorario.repository

import com.example.controlhorario.database.AppEventDao
import com.example.controlhorario.database.AppEventEntity
import kotlinx.coroutines.flow.Flow

class AppEventRepository(
    private val dao: AppEventDao
) {
    fun getAllEvents(): Flow<List<AppEventEntity>> =
        dao.getAllEvents()

    suspend fun saveEvent(event: AppEventEntity) {
        dao.saveEvent(event)
    }

    suspend fun markRead(eventId: Int) {
        dao.markRead(eventId)
    }
}
