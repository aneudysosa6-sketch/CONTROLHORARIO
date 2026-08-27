package com.example.controlhorario.ui.departments

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.DepartmentEntity
import com.example.controlhorario.repository.DepartmentRepository
import com.example.controlhorario.ui.settings.OrganizationLifecycleDecision
import com.example.controlhorario.ui.settings.OrganizationLifecyclePolicy
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class DepartmentViewModel(
    private val repository: DepartmentRepository
) : ViewModel() {
    val departments: StateFlow<List<DepartmentEntity>> = repository.getAllDepartments()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    private val _feedback = MutableStateFlow("")
    val feedback = _feedback.asStateFlow()

    fun addDepartment(
        branchId: Int,
        name: String,
        code: String,
        description: String,
        manager: String
    ) {
        if (branchId <= 0 || name.isBlank() || code.isBlank()) {
            _feedback.value = "Sucursal, nombre y codigo son obligatorios."
            return
        }
        viewModelScope.launch {
            repository.insert(
                DepartmentEntity(
                    branchId = branchId,
                    name = name.trim(),
                    code = code.trim(),
                    description = description.trim(),
                    manager = manager.trim(),
                    active = true
                )
            )
            _feedback.value = "Departamento creado."
        }
    }

    fun setDepartmentActive(department: DepartmentEntity, activeEmployeeCount: Int) {
        val activating = !department.active
        when (val decision = OrganizationLifecyclePolicy.departmentStatusChange(activating, activeEmployeeCount)) {
            OrganizationLifecycleDecision.Allowed -> viewModelScope.launch {
                repository.setActive(department, activating)
                _feedback.value = if (activating) {
                    "Departamento reactivado."
                } else {
                    "Departamento desactivado; su historial se conserva."
                }
            }
            is OrganizationLifecycleDecision.Denied -> _feedback.value = decision.message
        }
    }
}