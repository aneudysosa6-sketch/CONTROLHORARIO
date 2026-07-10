package com.example.controlhorario.repository

import com.example.controlhorario.database.LaborCalendarDayDao
import com.example.controlhorario.database.LaborCalendarDayEntity
import kotlinx.coroutines.flow.Flow

class LaborCalendarRepository(
    private val dao: LaborCalendarDayDao
) {
    fun getAllDays(): Flow<List<LaborCalendarDayEntity>> {
        return dao.getAllDays()
    }

    suspend fun getDayByDate(date: String): LaborCalendarDayEntity? {
        return dao.getDayByDate(date)
    }

    suspend fun insertDay(day: LaborCalendarDayEntity) {
        dao.insertDay(day)
    }

    suspend fun updateDay(day: LaborCalendarDayEntity) {
        dao.updateDay(day)
    }

    suspend fun deleteDay(day: LaborCalendarDayEntity) {
        dao.deleteDay(day)
    }
}