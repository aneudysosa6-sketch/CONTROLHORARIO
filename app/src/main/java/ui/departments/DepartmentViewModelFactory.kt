package com.example.controlhorario.ui.departments

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.DepartmentRepository

class DepartmentViewModelFactory(
    private val repository: DepartmentRepository
) : ViewModelProvider.Factory {

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {

        if (modelClass.isAssignableFrom(DepartmentViewModel::class.java)) {
            return DepartmentViewModel(repository) as T
        }

        throw IllegalArgumentException("Unknown ViewModel class")
    }
}