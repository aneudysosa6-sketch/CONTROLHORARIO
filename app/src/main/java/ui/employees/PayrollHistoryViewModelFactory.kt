package com.example.controlhorario.ui.employees

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.PayrollHistoryRepository

class PayrollHistoryViewModelFactory(
    private val repository: PayrollHistoryRepository
) : ViewModelProvider.Factory {

    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(PayrollHistoryViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return PayrollHistoryViewModel(repository) as T
        }

        throw IllegalArgumentException("ViewModel desconocido")
    }
}