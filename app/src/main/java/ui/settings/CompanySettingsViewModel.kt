package com.example.controlhorario.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.CompanySettingsEntity
import com.example.controlhorario.repository.CompanySettingsRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class CompanySettingsViewModel(
    private val repository: CompanySettingsRepository
) : ViewModel() {

    val companySettings = repository.getCompanySettings()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = null
        )

    fun saveCompanySettings(settings: CompanySettingsEntity) {
        viewModelScope.launch {
            repository.saveCompanySettings(settings)
        }
    }
}