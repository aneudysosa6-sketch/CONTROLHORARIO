package com.example.controlhorario.ui.face

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository

class FaceVerificationViewModelFactory(
    private val employeeId: Int,
    private val faces: EmployeeFaceBiometricRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        FaceVerificationViewModel(employeeId, faces) as T
}
