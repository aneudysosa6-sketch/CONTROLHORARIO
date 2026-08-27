package com.example.controlhorario.ui.punch

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch

data class KioskExitAuthUiState(
    val authenticating: Boolean = false,
    val errorMessage: String? = null,
)

sealed interface KioskExitAuthEvent {
    data class NavigateHome(
        val userId: Int,
        val roleCode: String,
    ) : KioskExitAuthEvent
}

class KioskExitAuthViewModel(
    private val coordinator: KioskExitCoordinator,
) : ViewModel() {
    private val _state = MutableStateFlow(KioskExitAuthUiState())
    val state: StateFlow<KioskExitAuthUiState> = _state

    private val eventChannel = Channel<KioskExitAuthEvent>(capacity = Channel.BUFFERED)
    val events = eventChannel.receiveAsFlow()

    fun authenticate(identifier: String, password: String) {
        if (_state.value.authenticating) return
        _state.value = KioskExitAuthUiState(authenticating = true)
        viewModelScope.launch {
            try {
                when (val result = coordinator.exit(identifier, password)) {
                    is KioskExitResult.Success -> {
                        _state.value = KioskExitAuthUiState()
                        eventChannel.send(
                            KioskExitAuthEvent.NavigateHome(
                                userId = result.userId,
                                roleCode = result.roleCode,
                            ),
                        )
                    }
                    is KioskExitResult.Failure -> {
                        _state.value = KioskExitAuthUiState(errorMessage = result.message)
                    }
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                _state.value = KioskExitAuthUiState(
                    errorMessage = KioskExitCoordinator.SESSION_ERROR_MESSAGE,
                )
            }
        }
    }

    fun clearError() {
        val current = _state.value
        if (current.errorMessage != null) _state.value = current.copy(errorMessage = null)
    }
}

class KioskExitAuthViewModelFactory(
    private val coordinator: KioskExitCoordinator,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        require(modelClass.isAssignableFrom(KioskExitAuthViewModel::class.java)) {
            "ViewModel no soportado: ${modelClass.name}"
        }
        return KioskExitAuthViewModel(coordinator) as T
    }
}
