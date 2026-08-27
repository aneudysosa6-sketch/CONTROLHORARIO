package com.example.controlhorario.ui.branchmanager

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.AppEventEntity
import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.BranchEntity
import com.example.controlhorario.database.SupervisorEventEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.AppEventRepository
import com.example.controlhorario.repository.AttendanceRepository
import com.example.controlhorario.repository.BranchRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.repository.SupervisorEventRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class BranchManagerUiState(
    val branch: BranchEntity? = null,
    val employees: List<Employee> = emptyList(),
    val attendanceEvents: List<AttendanceEntity> = emptyList(),
    val supervisorEvents: List<SupervisorEventEntity> = emptyList(),
    val appEvents: List<AppEventEntity> = emptyList()
)

class BranchManagerViewModel(
    private val branchId: Int,
    private val employeeRepository: EmployeeRepository,
    private val attendanceRepository: AttendanceRepository,
    private val branchRepository: BranchRepository,
    private val supervisorEventRepository: SupervisorEventRepository,
    private val appEventRepository: AppEventRepository
) : ViewModel() {
    val state: StateFlow<BranchManagerUiState> =
        combine(
            branchRepository.getAllBranches(),
            employeeRepository.getEmployeesByBranch(branchId),
            attendanceRepository.getAllAttendanceRecords(),
            supervisorEventRepository.getAllEvents(),
            appEventRepository.getAllEvents()
        ) { branches, employees, attendance, supervisorEvents, appEvents ->
            val employeeIds = employees.map { it.id }.toSet()
            BranchManagerUiState(
                branch = branches.firstOrNull { it.id == branchId },
                employees = employees,
                attendanceEvents = attendance.filter { it.employeeId in employeeIds },
                supervisorEvents = supervisorEvents.filter { it.employeeId in employeeIds },
                appEvents = appEvents
            )
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), BranchManagerUiState())

    fun setEmployeeActive(employeeId: Int, active: Boolean) {
        viewModelScope.launch {
            val employee = state.value.employees.firstOrNull { it.id == employeeId } ?: return@launch
            if (employee.branchId != branchId) return@launch
            employeeRepository.setEmployeeActive(employeeId, active)
            appEventRepository.saveEvent(
                AppEventEntity(
                    title = if (active) "Empleado activado" else "Empleado desactivado",
                    description = "${employee.employeeCode} · ${employee.nombre}",
                    module = "Encargado de Sucursal"
                )
            )
        }
    }
}
