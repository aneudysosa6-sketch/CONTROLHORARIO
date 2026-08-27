package com.example.controlhorario.ui.employees

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.EmployeePayrollSettingsRepository

class EmployeePayrollSettingsViewModelFactory(
    private val repository: EmployeePayrollSettingsRepository
) : ViewModelProvider.Factory {

    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(EmployeePayrollSettingsViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return EmployeePayrollSettingsViewModel(repository) as T
        }

        throw IllegalArgumentException("ViewModel desconocido")
    }
}