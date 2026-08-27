package com.example.controlhorario.ui.login

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import android.util.Log
import com.example.controlhorario.auth.AuthFlowException
import com.example.controlhorario.auth.AuthRepository
import com.example.controlhorario.database.AppUserEntity
import com.example.controlhorario.repository.AppUserRepository
import com.example.controlhorario.session.SessionCoordinator
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class AppUserViewModel(
    private val repository: AppUserRepository,
    private val authRepository: AuthRepository? = null,
) : ViewModel() {

    val users = repository.getAllUsers()

    private val _loginError = MutableStateFlow("")
    val loginError: StateFlow<String> = _loginError
    private val _loginLoading = MutableStateFlow(false)
    val loginLoading: StateFlow<Boolean> = _loginLoading

    fun login(
        username: String,
        password: String
    ) {
        if (_loginLoading.value) return
        viewModelScope.launch {
            _loginLoading.value = true
            _loginError.value = ""
            try {
                val auth = authRepository ?: throw AuthFlowException("configuration", code = "AUTH_NOT_CONFIGURED", message = "Supabase Auth no está configurado en Android.")
                val result = auth.login(username, password)
                SessionCoordinator.start(result, auth)
                Log.i(
                    TAG,
                    "sesion_nueva=true; " +
                        "rol_recibido=${result.principal.roleCodeOriginal}; " +
                        "rol_canonico=${result.principal.roleCode}; " +
                        "authorization_source=REMOTE",
                )
            } catch (error: AuthFlowException) {
                _loginError.value = error.visibleMessage()
                Log.e(TAG, "login=error; etapa=${error.stage}; codigo=${error.code}; error=${error.message}; details=${error.details}; hint=${error.hint}")
            } catch (error: Exception) {
                _loginError.value = error.message ?: "Error de autenticación no identificado."
                Log.e(TAG, "login=excepcion; error=${error.message}", error)
            } finally {
                _loginLoading.value = false
            }
        }
    }

    fun logout() {
        SessionCoordinator.logout()
    }

    fun saveUser(user: AppUserEntity) {
        viewModelScope.launch {
            repository.saveUser(user)
        }
    }

    fun clearError() {
        _loginError.value = ""
    }

    companion object { private const val TAG = "AndroidAuth" }
}
