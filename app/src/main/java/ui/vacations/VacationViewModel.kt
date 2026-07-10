package com.example.controlhorario.ui.vacations

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.VacationEntity
import com.example.controlhorario.repository.VacationRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class VacationViewModel(
    private val repository: VacationRepository
) : ViewModel() {

    val vacations: StateFlow<List<VacationEntity>> =
        repository.getAllVacations()
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = emptyList()
            )

    val pendingVacations: StateFlow<List<VacationEntity>> =
        repository.getVacationsByStatus(VacationEntity.STATUS_PENDING)
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = emptyList()
            )

    val approvedVacations: StateFlow<List<VacationEntity>> =
        repository.getVacationsByStatus(VacationEntity.STATUS_APPROVED)
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = emptyList()
            )

    val rejectedVacations: StateFlow<List<VacationEntity>> =
        repository.getVacationsByStatus(VacationEntity.STATUS_REJECTED)
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = emptyList()
            )

    val cancelledVacations: StateFlow<List<VacationEntity>> =
        repository.getVacationsByStatus(VacationEntity.STATUS_CANCELLED)
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = emptyList()
            )

    fun saveVacation(vacation: VacationEntity) {
        viewModelScope.launch {
            repository.saveVacation(vacation)
        }
    }

    fun approveVacation(
        vacationId: Int,
        approvedBy: String,
        approvedDate: String,
        approvedDays: Int,
        remainingDays: Int,
        updatedAt: String
    ) {
        viewModelScope.launch {
            repository.approveVacation(
                vacationId = vacationId,
                approvedBy = approvedBy,
                approvedDate = approvedDate,
                approvedDays = approvedDays,
                remainingDays = remainingDays,
                updatedAt = updatedAt
            )
        }
    }

    fun rejectVacation(
        vacationId: Int,
        rejectedBy: String,
        rejectedDate: String,
        rejectionReason: String,
        updatedAt: String
    ) {
        viewModelScope.launch {
            repository.rejectVacation(
                vacationId = vacationId,
                rejectedBy = rejectedBy,
                rejectedDate = rejectedDate,
                rejectionReason = rejectionReason,
                updatedAt = updatedAt
            )
        }
    }

    fun cancelVacation(
        vacationId: Int,
        updatedAt: String
    ) {
        viewModelScope.launch {
            repository.cancelVacation(
                vacationId = vacationId,
                updatedAt = updatedAt
            )
        }
    }

    fun deactivateVacation(
        vacationId: Int,
        updatedAt: String
    ) {
        viewModelScope.launch {
            repository.deactivateVacation(
                vacationId = vacationId,
                updatedAt = updatedAt
            )
        }
    }
}