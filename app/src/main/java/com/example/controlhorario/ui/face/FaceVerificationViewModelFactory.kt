package com.example.controlhorario.ui.face

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.model.EmployeeDeviceScopeSource

class FaceVerificationViewModelFactory(
    private val employeeId: Int,
    private val faces: EmployeeFaceBiometricRepository,
    private val employees: EmployeeRepository,
    private val scopeSource: EmployeeDeviceScopeSource
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        FaceVerificationViewModel(employeeId, faces, employees, scopeSource) as T
}
