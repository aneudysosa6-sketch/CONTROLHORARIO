package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface AppEventDao {
    @Query("SELECT * FROM app_events ORDER BY id DESC")
    fun getAllEvents(): Flow<List<AppEventEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveEvent(event: AppEventEntity)

    @Query("UPDATE app_events SET isRead = 1, openedAt = :openedAt WHERE id = :eventId")
    suspend fun markRead(eventId: Int, openedAt: String = System.currentTimeMillis().toString())
}
