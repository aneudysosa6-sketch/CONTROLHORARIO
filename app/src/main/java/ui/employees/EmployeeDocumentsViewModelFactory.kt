package com.example.controlhorario.ui.employees

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.EmployeeDocumentRepository

class EmployeeDocumentsViewModelFactory(
    private val repository: EmployeeDocumentRepository
) : ViewModelProvider.Factory {

    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(EmployeeDocumentsViewModel::class.java)) {
            @Suppress("UNCHECKED_CAST")
            return EmployeeDocumentsViewModel(repository) as T
        }

        throw IllegalArgumentException("ViewModel desconocido")
    }
}