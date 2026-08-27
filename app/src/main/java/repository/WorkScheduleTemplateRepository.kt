package com.example.controlhorario.repository

import com.example.controlhorario.database.WorkScheduleTemplateDao
import com.example.controlhorario.model.WorkScheduleTemplate
import kotlinx.coroutines.flow.Flow

class WorkScheduleTemplateRepository(
    private val dao: WorkScheduleTemplateDao
) {
    fun getAllTemplates(): Flow<List<WorkScheduleTemplate>> {
        return dao.getAllTemplates()
    }

    suspend fun addTemplate(template: WorkScheduleTemplate) {
        dao.insertTemplate(template)
    }
}