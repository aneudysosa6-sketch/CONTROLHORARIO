package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface N8NOutboxDao {
    @Query("SELECT * FROM n8n_outbox ORDER BY id DESC")
    fun observeAll(): Flow<List<N8NOutboxEntity>>

    @Query("SELECT * FROM n8n_outbox WHERE status = :status ORDER BY id ASC")
    suspend fun getByStatusOnce(status: String): List<N8NOutboxEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(entity: N8NOutboxEntity): Long

    @Query("UPDATE n8n_outbox SET status = :status, attempts = attempts + 1, sentAt = :sentAt, updatedAt = :updatedAt, responseCode = :responseCode, responseMessage = :responseMessage, errorMessage = '' WHERE id = :id")
    suspend fun markSent(id: Int, status: String, sentAt: String, updatedAt: String, responseCode: Int, responseMessage: String)

    @Query("UPDATE n8n_outbox SET status = :status, attempts = attempts + 1, updatedAt = :updatedAt, responseCode = :responseCode, responseMessage = :responseMessage, errorMessage = :errorMessage WHERE id = :id")
    suspend fun markError(id: Int, status: String, updatedAt: String, responseCode: Int, responseMessage: String, errorMessage: String)
}
