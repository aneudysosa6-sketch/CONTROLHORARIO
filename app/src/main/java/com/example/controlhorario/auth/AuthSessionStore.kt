package com.example.controlhorario.auth

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

object AuthSessionStore {
    private val _principal = MutableStateFlow<AuthenticatedPrincipal?>(null)
    val principal: StateFlow<AuthenticatedPrincipal?> = _principal

    fun start(value: AuthenticatedPrincipal) { _principal.value = value }
    fun clear() { _principal.value = null }
}
