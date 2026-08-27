package com.example.controlhorario.ui.employeepermissions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.EmployeePermissionRequestEntity
import com.example.controlhorario.repository.EmployeePermissionRequestRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class EmployeePermissionRequestsViewModel(
    private val repository: EmployeePermissionRequestRepository,
) : ViewModel() {
    val requests: StateFlow<List<EmployeePermissionRequestEntity>> =
        repository.getAllRequests()
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun saveRequest(request: EmployeePermissionRequestEntity) {
        viewModelScope.launch { repository.saveRequest(request) }
    }

    fun approveRequest(request: EmployeePermissionRequestEntity, reviewedBy: String, now: String) {
        viewModelScope.launch { repository.approveRequest(request, reviewedBy, now) }
    }

    fun saveDirectLicense(
        request: EmployeePermissionRequestEntity,
        actor: String,
        now: String,
        licenseStartDate: String,
        licenseEndDate: String,
        licensePayPercent: Double,
        monthlySalary: Double,
    ) {
        viewModelScope.launch {
            repository.saveDirectLicense(
                request,
                actor,
                now,
                licenseStartDate,
                licenseEndDate,
                licensePayPercent,
                monthlySalary,
            )
        }
    }

    fun cancelDirectLicense(requestId: Int, actor: String, reason: String, now: String) {
        viewModelScope.launch { repository.cancelDirectLicense(requestId, actor, reason, now) }
    }

    fun rejectRequest(requestId: Int, reviewedBy: String, reason: String, now: String) {
        viewModelScope.launch { repository.rejectRequest(requestId, reviewedBy, reason, now) }
    }
}
