package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface WhatsAppOutboxDao {
    @Query("SELECT * FROM whatsapp_outbox WHERE isActive = 1 ORDER BY id DESC")
    fun getAll(): Flow<List<WhatsAppOutboxEntity>>

    @Query("SELECT * FROM whatsapp_outbox WHERE status = :status AND isActive = 1 ORDER BY id ASC")
    fun getByStatus(status: String): Flow<List<WhatsAppOutboxEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(entity: WhatsAppOutboxEntity)

    @Query("UPDATE whatsapp_outbox SET status = :status, sentAt = :sentAt, updatedAt = :updatedAt WHERE id = :id")
    suspend fun markSent(id: Int, status: String, sentAt: String, updatedAt: String)

    @Query("UPDATE whatsapp_outbox SET status = :status, errorMessage = :errorMessage, updatedAt = :updatedAt WHERE id = :id")
    suspend fun markError(id: Int, status: String, errorMessage: String, updatedAt: String)
}
