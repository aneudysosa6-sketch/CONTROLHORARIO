package com.example.controlhorario.ui.punch

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.AttendanceRepository
import com.example.controlhorario.repository.EmployeeBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository

class EmployeePunchViewModelFactory(
    private val employeeRepository: EmployeeRepository,
    private val attendanceRepository: AttendanceRepository,
    private val biometricRepository: EmployeeBiometricRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(EmployeePunchViewModel::class.java)) {
            return EmployeePunchViewModel(
                employeeRepository = employeeRepository,
                attendanceRepository = attendanceRepository,
                biometricRepository = biometricRepository
            ) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
