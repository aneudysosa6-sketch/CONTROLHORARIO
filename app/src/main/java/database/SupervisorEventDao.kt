package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface SupervisorEventDao {

    @Query("SELECT * FROM supervisor_events WHERE supervisorId = :supervisorId ORDER BY createdAt DESC")
    fun getEventsForSupervisor(supervisorId: Int): Flow<List<SupervisorEventEntity>>

    @Query("SELECT * FROM supervisor_events ORDER BY createdAt DESC")
    fun getAllEvents(): Flow<List<SupervisorEventEntity>>

    @Query("DELETE FROM supervisor_events WHERE supervisorId = :supervisorId AND eventDate = :eventDate AND notificationPending = 0")
    suspend fun clearCalculatedEvents(supervisorId: Int, eventDate: String)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(event: SupervisorEventEntity)
}
