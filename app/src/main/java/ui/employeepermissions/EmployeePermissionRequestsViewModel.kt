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
    private val repository: EmployeePermissionRequestRepository
) : ViewModel() {
    val requests: StateFlow<List<EmployeePermissionRequestEntity>> =
        repository.getAllRequests()
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun saveRequest(request: EmployeePermissionRequestEntity) {
        viewModelScope.launch {
            repository.saveRequest(request)
        }
    }

    fun approveRequest(
        request: EmployeePermissionRequestEntity,
        reviewedBy: String,
        now: String,
        licenseStartDate: String = "",
        licenseEndDate: String = "",
        licensePayPercent: Double = 0.0,
        normalDailyAmount: Double = 0.0
    ) {
        viewModelScope.launch {
            repository.approveRequest(
                request = request,
                reviewedBy = reviewedBy,
                now = now,
                licenseStartDate = licenseStartDate,
                licenseEndDate = licenseEndDate,
                licensePayPercent = licensePayPercent,
                normalDailyAmount = normalDailyAmount
            )
        }
    }

    fun rejectRequest(requestId: Int, reviewedBy: String, reason: String, now: String) {
        viewModelScope.launch {
            repository.rejectRequest(
                requestId = requestId,
                reviewedBy = reviewedBy,
                reason = reason,
                now = now
            )
        }
    }
}
