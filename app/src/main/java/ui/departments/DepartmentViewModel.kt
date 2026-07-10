package com.example.controlhorario.ui.departments

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.DepartmentEntity
import com.example.controlhorario.repository.DepartmentRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class DepartmentViewModel(
    private val repository: DepartmentRepository
) : ViewModel() {

    val departments: StateFlow<List<DepartmentEntity>> =
        repository.getAllDepartments()
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = emptyList()
            )

    fun addDepartment(
        branchId: Int,
        name: String,
        code: String,
        description: String,
        manager: String
    ) {
        if (branchId <= 0 || name.isBlank() || code.isBlank()) return

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
        }
    }

    fun deleteDepartment(department: DepartmentEntity) {
        viewModelScope.launch {
            repository.delete(department)
        }
    }
}