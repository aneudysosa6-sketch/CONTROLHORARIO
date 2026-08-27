package com.example.controlhorario.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.PayrollSettingsRepository

class PayrollSettingsViewModelFactory(
    private val repository: PayrollSettingsRepository
) : ViewModelProvider.Factory {

    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(PayrollSettingsViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return PayrollSettingsViewModel(repository) as T
        }

        throw IllegalArgumentException("ViewModel desconocido")
    }
}