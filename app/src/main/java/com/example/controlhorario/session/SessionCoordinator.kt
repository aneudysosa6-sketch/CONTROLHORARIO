package com.example.controlhorario.session

import android.content.Context
import android.util.Log
import com.example.controlhorario.auth.AuthFlowException
import com.example.controlhorario.auth.AuthRepository
import com.example.controlhorario.auth.AuthenticatedLogin
import com.example.controlhorario.auth.AuthenticatedPrincipal
import com.example.controlhorario.auth.SupabaseSession
import com.example.controlhorario.database.AppUserEntity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

sealed interface SessionState {
    data object Loading : SessionState
    data class Authenticated(
        val principal: AuthenticatedPrincipal,
        val localUser: AppUserEntity,
    ) : SessionState
    data object Unauthenticated : SessionState
    data class AccessDenied(
        val message: String,
        val accountDisabled: Boolean = false,
    ) : SessionState
    data class NetworkUnavailable(val message: String) : SessionState
    data class Error(val message: String) : SessionState
}

object SessionCoordinator {
    private const val PREFS_NAME = "osinet_session"
    private const val KEY_ACCESS_TOKEN = "access_token"
    private const val KEY_REFRESH_TOKEN = "refresh_token"
    private const val KEY_EXPIRES_AT = "access_token_expires_at"
    private const val AUTHORIZATION_REFRESH_MS = 5_000L
    private const val TAG = "SessionCoordinator"

    private var appContext: Context? = null
    private var authRepository: AuthRepository? = null
    private val monitorScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private var monitorJob: Job? = null
    private val _state = MutableStateFlow<SessionState>(SessionState.Loading)
    val state: StateFlow<SessionState> = _state

    private val transientCodes = setOf(
        "NETWORK_ERROR", "NETWORK_ON_MAIN_THREAD", "DNS_ERROR", "TLS_ERROR",
        "TIMEOUT", "CONNECTION_REFUSED", "INVALID_URL",
    )

    fun init(context: Context) {
        appContext = context.applicationContext
        _state.value = SessionState.Loading
    }

    fun start(login: AuthenticatedLogin, repository: AuthRepository? = null) {
        authRepository = repository ?: authRepository
        persistTokens(login.principal)
        _state.value = SessionState.Authenticated(login.principal, login.user)
        logAuthorization(login.principal, source = "REMOTE_LOGIN")
        startAuthorizationMonitor()
    }

    suspend fun bootstrap(repository: AuthRepository): SessionState =
        withContext(Dispatchers.IO) {
            authRepository = repository
            _state.value = SessionState.Loading
            val stored = readStoredSession()
            if (stored == null) {
                _state.value = SessionState.Unauthenticated
                return@withContext _state.value
            }
            try {
                applyRestored(repository.restore(stored), "REMOTE")
                startAuthorizationMonitor()
            } catch (error: AuthFlowException) {
                _state.value = classify(error)
            } catch (error: Exception) {
                Log.e(TAG, "session_restore=unexpected; message=${error.message}", error)
                _state.value = SessionState.Error("No fue posible validar la sesion actual.")
            }
            _state.value
        }

    suspend fun retry(repository: AuthRepository): SessionState = bootstrap(repository)

    fun logout() {
        stopAuthorizationMonitor()
        clearPersistedTokens()
        _state.value = SessionState.Unauthenticated
    }

    fun invalidateForDisabledAccount() {
        stopAuthorizationMonitor()
        clearPersistedTokens()
        _state.value = SessionState.AccessDenied(
            message = "La cuenta esta desactivada.",
            accountDisabled = true,
        )
    }

    fun principalOrNull(): AuthenticatedPrincipal? =
        (_state.value as? SessionState.Authenticated)?.principal

    fun localUserOrNull(): AppUserEntity? =
        (_state.value as? SessionState.Authenticated)?.localUser

    private fun startAuthorizationMonitor() {
        val repository = authRepository ?: return
        monitorJob?.cancel()
        monitorJob = monitorScope.launch {
            while (isActive) {
                delay(AUTHORIZATION_REFRESH_MS)
                val stored = readStoredSession() ?: break
                try {
                    applyRestored(repository.restore(stored), "REMOTE_REFRESH")
                } catch (error: AuthFlowException) {
                    val classified = classify(error)
                    if (classified !is SessionState.NetworkUnavailable && classified !is SessionState.Error) {
                        _state.value = classified
                        if (classified !is SessionState.Authenticated) break
                    }
                } catch (error: Exception) {
                    Log.w(TAG, "authorization_refresh=transient; type=${error.javaClass.simpleName}")
                }
            }
        }
    }

    private fun stopAuthorizationMonitor() {
        monitorJob?.cancel()
        monitorJob = null
    }

    private fun applyRestored(login: AuthenticatedLogin, source: String) {
        persistTokens(login.principal)
        _state.value = SessionState.Authenticated(login.principal, login.user)
        logAuthorization(login.principal, source)
    }

    private fun classify(error: AuthFlowException): SessionState {
        val code = error.code.orEmpty()
        val serverMessage = error.message.uppercase()
        Log.w(TAG, "session_restore=failed; stage=${error.stage}; code=$code; message=${error.message}; details=${error.details}; hint=${error.hint}")
        if (isNetworkFailure(code)) {
            return SessionState.NetworkUnavailable("No hay conexion para validar tu acceso. La sesion guardada se conserva.")
        }
        if (isConfirmedInvalidToken(error)) {
            clearPersistedTokens()
            return SessionState.Unauthenticated
        }
        if (serverMessage in setOf("PROFILE_INACTIVE", "PROFILE_NOT_FOUND", "COMPANY_INACTIVE", "ROLE_INACTIVE", "ROLE_NOT_FOUND")) {
            clearPersistedTokens()
            return SessionState.AccessDenied(
                message = "La cuenta esta desactivada o ya no tiene acceso.",
                accountDisabled = true,
            )
        }
        if (serverMessage == "PORTAL_ACCESS_DENIED" || code == "PORTAL_ACCESS_DENIED" || code == "HTTP_403" || code == "42501") {
            return SessionState.AccessDenied("Tu usuario no tiene permiso para acceder a esta seccion.")
        }
        return SessionState.Error("No fue posible validar tu acceso en el servidor.")
    }

    private fun isConfirmedInvalidToken(error: AuthFlowException): Boolean {
        val message = error.message.lowercase()
        return error.code == "HTTP_401" ||
            error.code in setOf("invalid_grant", "refresh_token_not_found") ||
            message.contains("invalid jwt") ||
            message.contains("refresh token")
    }

    private fun isNetworkFailure(code: String?): Boolean =
        code in transientCodes || code?.startsWith("HTTP_5") == true

    private fun readStoredSession(): SupabaseSession? {
        val prefs = appContext?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE) ?: return null
        val accessToken = prefs.getString(KEY_ACCESS_TOKEN, "").orEmpty()
        val refreshToken = prefs.getString(KEY_REFRESH_TOKEN, "").orEmpty()
        if (accessToken.isBlank() || refreshToken.isBlank()) return null
        return SupabaseSession(
            accessToken = accessToken,
            refreshToken = refreshToken,
            accessTokenExpiresAt = prefs.getLong(KEY_EXPIRES_AT, 0L),
        )
    }

    private fun persistTokens(principal: AuthenticatedPrincipal) {
        appContext?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)?.edit()
            ?.clear()
            ?.putString(KEY_ACCESS_TOKEN, principal.accessToken)
            ?.putString(KEY_REFRESH_TOKEN, principal.refreshToken)
            ?.putLong(KEY_EXPIRES_AT, principal.accessTokenExpiresAt)
            ?.apply()
    }

    private fun clearPersistedTokens() {
        appContext?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)?.edit()?.clear()?.apply()
    }

    private fun logAuthorization(principal: AuthenticatedPrincipal, source: String) {
        Log.i(
            TAG,
            "bootstrap_user_id_present=${principal.authUid.isNotBlank()}; " +
                "server_role_code=${principal.roleCode}; server_role_name=${principal.roleName}; " +
                "permission_count=${principal.permissionCodes.size}; authorization_source=$source; " +
                "authorization_version=${principal.authorizationVersion}",
        )
    }
}
