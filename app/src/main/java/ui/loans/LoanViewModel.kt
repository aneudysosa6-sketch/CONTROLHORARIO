package com.example.controlhorario.ui.loans

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.LoanEntity
import com.example.controlhorario.engine.LoanEngine
import com.example.controlhorario.repository.LoanRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class LoanViewModel(
    private val repository: LoanRepository
) : ViewModel() {
    val loans: StateFlow<List<LoanEntity>> =
        repository.getAllLoans()
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val summary: StateFlow<LoanEngine.Summary> =
        loans
            .map(LoanEngine::calculateSummary)
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), LoanEngine.calculateSummary(emptyList()))

    fun saveLoan(loan: LoanEntity) {
        viewModelScope.launch {
            repository.saveLoan(loan)
        }
    }

    fun approveLoan(
        loanId: Int,
        approvedAmount: Double,
        payrollDiscount: Double,
        approvedBy: String,
        now: String
    ) {
        viewModelScope.launch {
            repository.approveLoan(
                loanId = loanId,
                approvedAmount = approvedAmount,
                payrollDiscount = payrollDiscount,
                approvedBy = approvedBy,
                approvedDate = now,
                updatedAt = now
            )
        }
    }

    fun deliverLoan(loanId: Int, deliveredBy: String, now: String) {
        viewModelScope.launch {
            repository.deliverLoan(
                loanId = loanId,
                deliveredBy = deliveredBy,
                deliveredDate = now,
                updatedAt = now
            )
        }
    }

    fun registerPayment(loan: LoanEntity, paymentAmount: Double, now: String) {
        viewModelScope.launch {
            repository.registerPayment(loan, paymentAmount, now)
        }
    }

    fun rejectLoan(loanId: Int, rejectedBy: String, reason: String, now: String) {
        viewModelScope.launch {
            repository.rejectLoan(
                loanId = loanId,
                rejectedBy = rejectedBy,
                rejectedDate = now,
                rejectionReason = reason,
                updatedAt = now
            )
        }
    }

    fun cancelLoan(loanId: Int, now: String) {
        viewModelScope.launch {
            repository.cancelLoan(loanId, now)
        }
    }
}
