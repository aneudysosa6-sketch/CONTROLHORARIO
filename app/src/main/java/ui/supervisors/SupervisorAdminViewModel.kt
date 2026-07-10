package com.example.controlhorario.ui.supervisors

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.BranchEntity
import com.example.controlhorario.database.DepartmentEntity
import com.example.controlhorario.database.SupervisorEntity
import com.example.controlhorario.repository.BranchRepository
import com.example.controlhorario.repository.DepartmentRepository
import com.example.controlhorario.repository.SupervisorRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class SupervisorAdminViewModel(
    private val supervisorRepository: SupervisorRepository,
    private val branchRepository: BranchRepository,
    private val departmentRepository: DepartmentRepository
) : ViewModel() {

    private val _supervisors = MutableStateFlow<List<SupervisorEntity>>(emptyList())
    val supervisors: StateFlow<List<SupervisorEntity>> = _supervisors.asStateFlow()

    private val _branches = MutableStateFlow<List<BranchEntity>>(emptyList())
    val branches: StateFlow<List<BranchEntity>> = _branches.asStateFlow()

    private val _departments = MutableStateFlow<List<DepartmentEntity>>(emptyList())
    val departments: StateFlow<List<DepartmentEntity>> = _departments.asStateFlow()

    private val _selectedDepartmentIds = MutableStateFlow<List<Int>>(emptyList())
    val selectedDepartmentIds: StateFlow<List<Int>> = _selectedDepartmentIds.asStateFlow()

    private val _message = MutableStateFlow("")
    val message: StateFlow<String> = _message.asStateFlow()

    init {
        viewModelScope.launch { supervisorRepository.getAllSupervisors().collect { _supervisors.value = it } }
        viewModelScope.launch { branchRepository.getAllBranches().collect { _branches.value = it } }
        viewModelScope.launch { departmentRepository.getAllDepartments().collect { _departments.value = it } }
    }

    fun loadDepartmentsForSupervisor(supervisorId: Int) {
        viewModelScope.launch {
            _selectedDepartmentIds.value = supervisorRepository.getDepartmentIdsNow(supervisorId)
        }
    }

    fun toggleDepartment(departmentId: Int) {
        val current = _selectedDepartmentIds.value.toMutableList()
        if (current.contains(departmentId)) current.remove(departmentId) else current.add(departmentId)
        _selectedDepartmentIds.value = current.sorted()
    }

    fun clearSelection() {
        _selectedDepartmentIds.value = emptyList()
        _message.value = ""
    }

    fun saveSupervisor(
        supervisorId: Int,
        fullName: String,
        username: String,
        password: String,
        isActive: Boolean
    ) {
        val cleanName = fullName.trim()
        val cleanUser = username.trim()
        val cleanPass = password.trim()
        if (cleanName.isBlank() || cleanUser.isBlank() || cleanPass.isBlank()) {
            _message.value = "Complete nombre, usuario y contraseña."
            return
        }
        if (_selectedDepartmentIds.value.isEmpty()) {
            _message.value = "Debe asignar al menos un departamento."
            return
        }
        viewModelScope.launch {
            supervisorRepository.saveSupervisor(
                SupervisorEntity(
                    id = supervisorId,
                    fullName = cleanName,
                    username = cleanUser,
                    password = cleanPass,
                    isActive = isActive,
                    updatedAt = System.currentTimeMillis()
                ),
                _selectedDepartmentIds.value
            )
            _message.value = "Supervisor guardado correctamente."
            _selectedDepartmentIds.value = emptyList()
        }
    }

    fun setActive(supervisorId: Int, active: Boolean) {
        viewModelScope.launch { supervisorRepository.setActive(supervisorId, active) }
    }
}

class SupervisorAdminViewModelFactory(
    private val supervisorRepository: SupervisorRepository,
    private val branchRepository: BranchRepository,
    private val departmentRepository: DepartmentRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return SupervisorAdminViewModel(supervisorRepository, branchRepository, departmentRepository) as T
    }
}
