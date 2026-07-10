package com.example.controlhorario.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.model.WorkScheduleTemplate
import com.example.controlhorario.repository.WorkScheduleTemplateRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class WorkScheduleTemplateViewModel(
    private val repository: WorkScheduleTemplateRepository
) : ViewModel() {

    val templates = repository.getAllTemplates()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )

    fun addTemplate(template: WorkScheduleTemplate) {
        viewModelScope.launch {
            repository.addTemplate(template)
        }
    }
}