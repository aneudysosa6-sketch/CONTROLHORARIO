package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface LaborCalendarDayDao {

    @Query("SELECT * FROM labor_calendar_days ORDER BY date ASC")
    fun getAllDays(): Flow<List<LaborCalendarDayEntity>>

    @Query("SELECT * FROM labor_calendar_days WHERE date = :date LIMIT 1")
    suspend fun getDayByDate(date: String): LaborCalendarDayEntity?

    @Insert
    suspend fun insertDay(day: LaborCalendarDayEntity)

    @Update
    suspend fun updateDay(day: LaborCalendarDayEntity)

    @Delete
    suspend fun deleteDay(day: LaborCalendarDayEntity)
}