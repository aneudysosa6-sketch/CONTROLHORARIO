package com.example.controlhorario.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.CompanySettingsRepository

class CompanySettingsViewModelFactory(
    private val repository: CompanySettingsRepository
) : ViewModelProvider.Factory {

    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(CompanySettingsViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return CompanySettingsViewModel(repository) as T
        }

        throw IllegalArgumentException("ViewModel desconocido")
    }
}