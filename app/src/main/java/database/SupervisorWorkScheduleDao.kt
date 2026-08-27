package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface SupervisorWorkScheduleDao {

    @Query("SELECT * FROM supervisor_work_schedules ORDER BY employeeId")
    fun getAll(): Flow<List<SupervisorWorkScheduleEntity>>

    @Query("SELECT * FROM supervisor_work_schedules WHERE employeeId = :employeeId LIMIT 1")
    suspend fun getByEmployeeId(employeeId: Int): SupervisorWorkScheduleEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(schedule: SupervisorWorkScheduleEntity)
}
