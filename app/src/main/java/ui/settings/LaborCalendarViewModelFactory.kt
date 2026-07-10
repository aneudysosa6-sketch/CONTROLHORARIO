package com.example.controlhorario.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.LaborCalendarRepository

class LaborCalendarViewModelFactory(
    private val repository: LaborCalendarRepository
) : ViewModelProvider.Factory {

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(LaborCalendarViewModel::class.java)) {
            return LaborCalendarViewModel(repository) as T
        }

        throw IllegalArgumentException("Unknown ViewModel class")
    }
}