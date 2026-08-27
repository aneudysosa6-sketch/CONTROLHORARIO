package com.example.controlhorario.ui.permissions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.SupervisorPermissionEntity
import com.example.controlhorario.repository.SupervisorPermissionRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class PermissionsViewModel(
    private val repository: SupervisorPermissionRepository
) : ViewModel() {
    val permissions: StateFlow<List<SupervisorPermissionEntity>> =
        repository.getAll().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun save(entity: SupervisorPermissionEntity) {
        viewModelScope.launch { repository.save(entity) }
    }
}
