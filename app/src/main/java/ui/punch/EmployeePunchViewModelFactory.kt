package com.example.controlhorario.ui.punch

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import com.example.controlhorario.device.EmployeeFaceAvailabilityCoordinator
import com.example.controlhorario.model.EmployeeDeviceScopeSource

class EmployeePunchViewModelFactory(
    private val employeeRepository: EmployeeRepository,
    private val faceRepository: EmployeeFaceBiometricRepository,
    private val faceAvailability: EmployeeFaceAvailabilityCoordinator,
    private val scopeSource: EmployeeDeviceScopeSource
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(EmployeePunchViewModel::class.java)) {
            return EmployeePunchViewModel(
                employeeRepository = employeeRepository,
                faceRepository = faceRepository,
                faceAvailability = faceAvailability,
                scopeSource = scopeSource
            ) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
