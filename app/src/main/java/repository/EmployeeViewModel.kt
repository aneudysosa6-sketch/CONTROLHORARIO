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

    private val _lastCreatedCode = MutableStateFlow("")
    val lastCreatedCode: StateFlow<String> = _lastCreatedCode.asStateFlow()

    private val _editingEmployee = MutableStateFlow<Employee?>(null)
    val editingEmployee: StateFlow<Employee?> = _editingEmployee.asStateFlow()

    fun addEmployee(employee: Employee) {
        viewModelScope.launch {
            val generatedCode = repository.addEmployee(employee)
            _lastCreatedCode.value = generatedCode
        }
    }

    fun clearLastCreatedCode() {
        _lastCreatedCode.value = ""
    }

    fun loadEmployeeForEdit(employeeKey: String) {
        viewModelScope.launch { _editingEmployee.value = repository.findForEdit(employeeKey) }
    }

    fun updateEmployee(employee: Employee, onSaved: () -> Unit = {}) {
        viewModelScope.launch { repository.updateEmployee(employee);_editingEmployee.value=employee;onSaved() }
    }
}
