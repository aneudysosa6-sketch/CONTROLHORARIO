package com.example.controlhorario.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.PayrollSettingsEntity
import com.example.controlhorario.repository.PayrollSettingsRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class PayrollSettingsViewModel(
    private val repository: PayrollSettingsRepository
) : ViewModel() {

    val payrollSettings = repository.getPayrollSettings()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = null
        )

    fun savePayrollSettings(settings: PayrollSettingsEntity) {
        viewModelScope.launch {
            repository.savePayrollSettings(settings)
        }
    }
}