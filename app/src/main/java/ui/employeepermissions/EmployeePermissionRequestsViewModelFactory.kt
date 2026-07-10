package com.example.controlhorario.ui.employeepermissions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.EmployeePermissionRequestRepository

class EmployeePermissionRequestsViewModelFactory(
    private val repository: EmployeePermissionRequestRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return EmployeePermissionRequestsViewModel(repository) as T
    }
}
