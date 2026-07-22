package com.example.controlhorario.ui.face

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import android.content.Context
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.face.InitialFaceEnrollmentRepository

class FaceRegistrationViewModelFactory(
    private val context: Context,
    private val employees: EmployeeRepository,
    private val faces: EmployeeFaceBiometricRepository,
    private val mode: FaceRegistrationMode = FaceRegistrationMode.ADMIN,
    private val initialEnrollment: InitialFaceEnrollmentRepository? = null
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        FaceRegistrationViewModel(
            context.applicationContext,
            employees,
            faces,
            mode = mode,
            initialEnrollment = initialEnrollment
        ) as T
}
