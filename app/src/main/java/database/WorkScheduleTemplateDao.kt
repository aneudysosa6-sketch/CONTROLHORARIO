package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import com.example.controlhorario.model.WorkScheduleTemplate
import kotlinx.coroutines.flow.Flow

@Dao
interface WorkScheduleTemplateDao {

    @Insert
    suspend fun insertTemplate(template: WorkScheduleTemplate)

    @Query("SELECT * FROM work_schedule_templates ORDER BY id DESC")
    fun getAllTemplates(): Flow<List<WorkScheduleTemplate>>
}