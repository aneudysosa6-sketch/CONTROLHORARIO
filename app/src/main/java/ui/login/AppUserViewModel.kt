package com.example.controlhorario.ui.login

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.AppUserEntity
import com.example.controlhorario.database.UserRole
import com.example.controlhorario.repository.AppUserRepository
import com.example.controlhorario.session.UserSessionManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class AppUserViewModel(
    private val repository: AppUserRepository
) : ViewModel() {

    private val _currentUser = MutableStateFlow<AppUserEntity?>(null)
    val currentUser: StateFlow<AppUserEntity?> = _currentUser
    val users = repository.getAllUsers()

    private val _loginError = MutableStateFlow("")
    val loginError: StateFlow<String> = _loginError

    fun createDefaultAdminIfNeeded() {
        viewModelScope.launch {
            val existingUser = repository.getUserByUsername("admin")

            if (existingUser == null) {
                repository.saveUser(
                    AppUserEntity(
                        fullName = "Administrador OSINET",
                        username = "admin",
                        password = "Rr19760707..--@",
                        role = UserRole.ADMINISTRADOR.name,
                        permissionsCsv = PermissionCatalog.all.joinToString(","),
                        createdAt = System.currentTimeMillis().toString()
                    )
                )
            }
        }
    }

    fun login(
        username: String,
        password: String
    ) {
        viewModelScope.launch {
            val user = repository.login(
                username = username,
                password = password
            )

            if (user == null) {
                _loginError.value = "Usuario o contraseña incorrectos."
                return@launch
            }

            repository.updateLastLogin(
                user.id,
                System.currentTimeMillis().toString()
            )

            UserSessionManager.login(user)
            _currentUser.value = user
            _loginError.value = ""
        }
    }

    fun logout() {
        UserSessionManager.logout()
        _currentUser.value = null
    }

    fun saveUser(user: AppUserEntity) {
        viewModelScope.launch {
            repository.saveUser(user)
        }
    }

    fun clearError() {
        _loginError.value = ""
    }
}