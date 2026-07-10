package com.example.controlhorario.repository

import com.example.controlhorario.database.WhatsAppOutboxDao
import com.example.controlhorario.database.WhatsAppOutboxEntity
import kotlinx.coroutines.flow.Flow

class WhatsAppOutboxRepository(
    private val dao: WhatsAppOutboxDao
) {
    fun getAll(): Flow<List<WhatsAppOutboxEntity>> = dao.getAll()
    fun getPending(): Flow<List<WhatsAppOutboxEntity>> = dao.getByStatus(WhatsAppOutboxEntity.STATUS_PENDING)
    suspend fun save(entity: WhatsAppOutboxEntity) = dao.save(entity)
    suspend fun markSent(id: Int, at: String) = dao.markSent(id, WhatsAppOutboxEntity.STATUS_SENT, at, at)
    suspend fun markError(id: Int, message: String, at: String) = dao.markError(id, WhatsAppOutboxEntity.STATUS_ERROR, message, at)
}
