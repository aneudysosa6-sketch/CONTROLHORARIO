package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface N8NSettingsDao {
    @Query("SELECT * FROM n8n_settings WHERE id = 1 LIMIT 1")
    fun observeSettings(): Flow<N8NSettingsEntity?>

    @Query("SELECT * FROM n8n_settings WHERE id = 1 LIMIT 1")
    suspend fun getSettings(): N8NSettingsEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(settings: N8NSettingsEntity)

    @Query("UPDATE n8n_settings SET lastStatus = :status, lastMessage = :message, lastTestAt = :testedAt, updatedAt = :updatedAt WHERE id = 1")
    suspend fun updateTestStatus(status: String, message: String, testedAt: String, updatedAt: String)
}
