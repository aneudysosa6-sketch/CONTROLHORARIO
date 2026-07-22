package com.example.controlhorario.ui.employees

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.EmployeeRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class EmployeeViewModel(
    private val repository: EmployeeRepository
) : ViewModel() {

    val employees = repository.getAllEmployees()
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )

    private val _lastCreatedEmployeeId = MutableStateFlow<Int?>(null)
    val lastCreatedEmployeeId: StateFlow<Int?> = _lastCreatedEmployeeId.asStateFlow()

    private val _editingEmployee = MutableStateFlow<Employee?>(null)
    val editingEmployee: StateFlow<Employee?> = _editingEmployee.asStateFlow()

    fun addEmployee(employee: Employee, onResult: (Result<Int>) -> Unit = {}) {
        viewModelScope.launch {
            val result = runCatching { repository.addEmployee(employee) }
            result.onSuccess { _lastCreatedEmployeeId.value = it }
            onResult(result)
        }
    }

    fun clearLastCreatedEmployee() {
        _lastCreatedEmployeeId.value = null
    }

    fun loadEmployeeForEdit(employeeKey: String) {
        viewModelScope.launch { _editingEmployee.value = repository.findForEdit(employeeKey) }
    }

    fun updateEmployee(employee: Employee, onResult: (Result<Unit>) -> Unit = {}) {
        viewModelScope.launch {
            val result = runCatching { repository.updateEmployee(employee) }
            result.onSuccess { _editingEmployee.value = employee }
            onResult(result)
        }
    }
}
