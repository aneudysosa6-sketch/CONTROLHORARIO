package com.example.controlhorario.ui.employees

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.PayrollHistoryEntity
import com.example.controlhorario.repository.PayrollHistoryRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class PayrollHistoryViewModel(
    private val repository: PayrollHistoryRepository
) : ViewModel() {

    private val _history = MutableStateFlow<List<PayrollHistoryEntity>>(emptyList())
    val history: StateFlow<List<PayrollHistoryEntity>> = _history

    fun loadHistory(employeeId: Int) {
        viewModelScope.launch {
            repository.getHistoryByEmployee(employeeId).collect { records ->
                _history.value = records
            }
        }
    }

    fun saveHistory(history: PayrollHistoryEntity) {
        viewModelScope.launch {
            repository.insertPayrollHistory(history)
        }
    }
}