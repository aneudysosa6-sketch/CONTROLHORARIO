package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface SupervisorPermissionDao {
    @Query("SELECT * FROM supervisor_permissions WHERE isActive = 1 ORDER BY id DESC")
    fun getAll(): Flow<List<SupervisorPermissionEntity>>

    @Query("SELECT * FROM supervisor_permissions WHERE supervisorUserId = :supervisorUserId AND isActive = 1")
    fun getBySupervisor(supervisorUserId: Int): Flow<List<SupervisorPermissionEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(entity: SupervisorPermissionEntity)

    @Query("UPDATE supervisor_permissions SET isActive = 0, updatedAt = :updatedAt WHERE id = :id")
    suspend fun deactivate(id: Int, updatedAt: String)
}
