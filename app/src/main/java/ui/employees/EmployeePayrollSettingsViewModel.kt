package com.example.controlhorario.ui.employees

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.EmployeePayrollSettingsEntity
import com.example.controlhorario.repository.EmployeePayrollSettingsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class EmployeePayrollSettingsViewModel(
    private val repository: EmployeePayrollSettingsRepository
) : ViewModel() {

    private val _settings = MutableStateFlow<EmployeePayrollSettingsEntity?>(null)
    val settings: StateFlow<EmployeePayrollSettingsEntity?> = _settings

    fun loadSettings(employeeId: Int) {
        viewModelScope.launch {
            repository.getSettingsByEmployee(employeeId).collect { result ->
                _settings.value = result
            }
        }
    }

    fun saveSettings(settings: EmployeePayrollSettingsEntity) {
        viewModelScope.launch {
            repository.saveSettings(settings)
        }
    }

    fun clearOneTimeCredit() {
        val currentSettings = _settings.value ?: return

        val updatedSettings = currentSettings.copy(
            oneTimeCreditAmount = 0.0
        )

        viewModelScope.launch {
            repository.saveSettings(updatedSettings)
            _settings.value = updatedSettings
        }
    }
}