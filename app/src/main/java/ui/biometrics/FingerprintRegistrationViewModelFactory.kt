package com.example.controlhorario.ui.biometrics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.EmployeeBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository

class FingerprintRegistrationViewModelFactory(
    private val biometricRepository: EmployeeBiometricRepository,
    private val employeeRepository: EmployeeRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(FingerprintRegistrationViewModel::class.java)) {
            return FingerprintRegistrationViewModel(biometricRepository, employeeRepository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
    }
}
