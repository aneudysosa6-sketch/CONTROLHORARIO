package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface N8NSyncLogDao {
    @Query("SELECT * FROM n8n_sync_log ORDER BY id DESC")
    fun observeAll(): Flow<List<N8NSyncLogEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(entity: N8NSyncLogEntity)

    @Query("DELETE FROM n8n_sync_log")
    suspend fun clear()
}
