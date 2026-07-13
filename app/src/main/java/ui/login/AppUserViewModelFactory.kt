package com.example.controlhorario.ui.login

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.AppUserRepository
import com.example.controlhorario.auth.AuthRepository

class AppUserViewModelFactory(
    private val repository: AppUserRepository,
    private val authRepository: AuthRepository? = null,
) : ViewModelProvider.Factory {

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(
        modelClass: Class<T>
    ): T {

        if (modelClass.isAssignableFrom(AppUserViewModel::class.java)) {
            return AppUserViewModel(repository, authRepository) as T
        }

        throw IllegalArgumentException(
            "Unknown ViewModel class: ${modelClass.name}"
        )
    }
}
