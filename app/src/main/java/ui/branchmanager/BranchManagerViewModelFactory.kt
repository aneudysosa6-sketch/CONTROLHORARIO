package com.example.controlhorario.ui.branchmanager

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.AppEventRepository
import com.example.controlhorario.repository.AttendanceRepository
import com.example.controlhorario.repository.BranchRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.repository.SupervisorEventRepository

class BranchManagerViewModelFactory(
    private val branchId: Int,
    private val employeeRepository: EmployeeRepository,
    private val attendanceRepository: AttendanceRepository,
    private val branchRepository: BranchRepository,
    private val supervisorEventRepository: SupervisorEventRepository,
    private val appEventRepository: AppEventRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(BranchManagerViewModel::class.java)) {
            return BranchManagerViewModel(
                branchId = branchId,
                employeeRepository = employeeRepository,
                attendanceRepository = attendanceRepository,
                branchRepository = branchRepository,
                supervisorEventRepository = supervisorEventRepository,
                appEventRepository = appEventRepository
            ) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
