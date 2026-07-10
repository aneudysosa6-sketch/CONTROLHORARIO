package com.example.controlhorario.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.WorkScheduleTemplateRepository

class WorkScheduleTemplateViewModelFactory(
    private val repository: WorkScheduleTemplateRepository
) : ViewModelProvider.Factory {

    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(WorkScheduleTemplateViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return WorkScheduleTemplateViewModel(repository) as T
        }

        throw IllegalArgumentException("ViewModel desconocido")
    }
}