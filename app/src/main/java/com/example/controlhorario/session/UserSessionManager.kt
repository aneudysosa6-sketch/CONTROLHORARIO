package com.example.controlhorario.session

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.example.controlhorario.auth.AuthenticatedPrincipal
import com.example.controlhorario.auth.AuthFlowException
import com.example.controlhorario.auth.AuthRepository
import com.example.controlhorario.auth.AuthSessionStore
import com.example.controlhorario.auth.SupabaseSession
import com.example.controlhorario.dashboard.DashboardRoutePolicy
import com.example.controlhorario.database.AppUserEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext

sealed interface SessionRestoreResult {
    object Success : SessionRestoreResult
    object NoStoredSession : SessionRestoreResult
    data class ValidationError(val message: String) : SessionRestoreResult
    data class NetworkError(val message: String) : SessionRestoreResult
}

object UserSessionManager {
    private const val PREFS_NAME = "osinet_session"
    private const val KEY_REFRESH_TOKEN = "refresh_token"
    private const val KEY_ACCESS_TOKEN = "access_token"
    private const val KEY_ACCESS_TOKEN_EXPIRES_AT = "access_token_expires_at"
    private const val KEY_ROLE = "role"
    private const val LOG_TAG = "UserSessionManager"

    private var appContext: Context? = null
    private val _currentUser = MutableStateFlow<AppUserEntity?>(null)
    val currentUser: StateFlow<AppUserEntity?> = _currentUser

    private val transientAuthCodes = setOf(
        "NETWORK_ERROR",
        "NETWORK_ON_MAIN_THREAD",
        "DNS_ERROR",
        "TLS_ERROR",
        "TIMEOUT",
        "CONNECTION_REFUSED",
        "INVALID_URL",
    )

    fun init(context: Context) {
        appContext = context.applicationContext
        _currentUser.value = null
    }

    fun login(user: AppUserEntity) {
        _currentUser.value = user
        saveSession()
    }

    fun loginRemote(user: AppUserEntity, principal: AuthenticatedPrincipal? = null) {
        _currentUser.value = user
        saveSession(principal)
    }

    suspend fun restoreFromSupabase(authRepository: AuthRepository): SessionRestoreResult = withContext(Dispatchers.IO) {
        val prefs = appContext?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?: return@withContext SessionRestoreResult.ValidationError("No fue posible iniciar sesión local.")
        val storedSession = loadStoredSession(prefs) ?: return@withContext SessionRestoreResult.NoStoredSession
        val persistedRoleCode = prefs.getString(KEY_ROLE, "").orEmpty()
        try {
            val restored = authRepository.restore(storedSession)
            AuthSessionStore.setPrincipal(restored.principal)
            _currentUser.value = restored.user
            saveSession(restored.principal)
            val destination = DashboardRoutePolicy.destination(
                restored.principal.roleCode,
                restored.principal.permissionCodes,
                loading = false,
            )
            Log.i(
                LOG_TAG,
                "bootstrap_user_id=${restored.principal.authUid}; " +
                    "persisted_role_code=${persistedRoleCode.ifBlank { "<none>" }}; " +
                    "server_role_code=${restored.principal.roleCode}; " +
                    "server_role_name=${restored.principal.roleName}; " +
                    "permission_count=${restored.principal.permissionCodes.size}; " +
                    "authorization_source=REMOTE; " +
                    "dashboard_destination=${DashboardRoutePolicy.dashboardLabel(destination)}"
            )
            SessionRestoreResult.Success
        } catch (error: AuthFlowException) {
            if (shouldClearSession(error)) {
                clear()
            } else {
                AuthSessionStore.clear()
                _currentUser.value = null
            }
            val stage = error.stage
            val code = error.code.orEmpty()
            Log.w(LOG_TAG, "session_restore=failed; stage=$stage; code=$code; message=${error.message}; details=${error.details}; hint=${error.hint}")
            return@withContext when {
                isNetworkFailure(code) -> SessionRestoreResult.NetworkError("No se pudo validar la sesión: ${error.message}")
                error.code in setOf("PROFILE_INACTIVE", "ROLE_INACTIVE", "PROFILE_NOT_FOUND", "ROLE_NOT_FOUND", "ROLE_CODE_MISSING", "ROLE_NAME_MISSING") ->
                    SessionRestoreResult.ValidationError("Tu sesión ya no es válida para este rol. Cierra sesión e inténtalo nuevamente.")
                else -> SessionRestoreResult.ValidationError("No fue posible validar tu acceso en el servidor.")
            }
        } catch (error: Exception) {
            _currentUser.value = null
            AuthSessionStore.clear()
            Log.w(LOG_TAG, "session_restore=unexpected_error; error=${error.message}")
            SessionRestoreResult.ValidationError("No fue posible validar tu sesión actual.")
        }
    }

    fun logout() {
        _currentUser.value = null
        AuthSessionStore.clear()
        clearPersistedSession()
    }

    fun getCurrentUser(): AppUserEntity? = _currentUser.value

    fun isLoggedIn(): Boolean = _currentUser.value != null

    fun hasRole(role: String): Boolean = _currentUser.value?.role == role

    fun currentUserName(): String = _currentUser.value?.fullName ?: ""

    fun currentUserRole(): String = _currentUser.value?.role ?: ""

    fun currentUserId(): Int = _currentUser.value?.id ?: 0

    private fun saveSession(principal: AuthenticatedPrincipal? = null) {
        val editor = appContext?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)?.edit() ?: return
        editor
            .remove("user_id")
            .remove("full_name")
            .remove("username")
            .remove("email")
            .remove("password")
            .remove("permissions")
            .remove("employee_id")
            .remove("branch_id")
            .remove("department_id")
            .remove("is_active")
            .remove("created_at")
            .remove("updated_at")
            .remove("last_login_at")
            .remove("auth_uid")
            .remove(KEY_ROLE)
            .remove("legacy_role")
            .remove("legacy_perms")
        if (principal != null) {
            editor
                .putString(KEY_ACCESS_TOKEN, principal.accessToken)
                .putString(KEY_REFRESH_TOKEN, principal.refreshToken)
                .putLong(KEY_ACCESS_TOKEN_EXPIRES_AT, principal.accessTokenExpiresAt)
        } else {
            editor.remove(KEY_ACCESS_TOKEN)
                .remove(KEY_REFRESH_TOKEN)
                .remove(KEY_ACCESS_TOKEN_EXPIRES_AT)
        }
        editor.apply()
    }

    private fun loadStoredSession(prefs: SharedPreferences): SupabaseSession? {
        val accessToken = prefs.getString(KEY_ACCESS_TOKEN, "").orEmpty()
        val refreshToken = prefs.getString(KEY_REFRESH_TOKEN, "").orEmpty()
        if (accessToken.isBlank() || refreshToken.isBlank()) return null
        return SupabaseSession(
            accessToken = accessToken,
            refreshToken = refreshToken,
            accessTokenExpiresAt = prefs.getLong(KEY_ACCESS_TOKEN_EXPIRES_AT, 0L),
        )
    }

    private fun clear() {
        _currentUser.value = null
        AuthSessionStore.clear()
        clearPersistedSession()
    }

    private fun clearPersistedSession() {
        appContext
            ?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.edit()
            ?.clear()
            ?.apply()
    }

    private fun shouldClearSession(error: AuthFlowException): Boolean {
        if (isNetworkFailure(error.code)) return false
        return when (error.code) {
            "PROFILE_INACTIVE",
            "ROLE_INACTIVE",
            "PROFILE_NOT_FOUND",
            "ROLE_NOT_FOUND",
            "ROLE_CODE_MISSING",
            "ROLE_NAME_MISSING",
            "PROFILE_INCOMPLETE",
            "PORTAL_ACCESS_DENIED",
            "AUTH_USER_ID_MISSING",
            "AUTH_USER_EMAIL_MISSING",
            "REFRESH_TOKEN_MISSING" -> true
            "HTTP_400",
            "HTTP_401",
            "HTTP_403",
            "HTTP_404" -> true
            else -> false
        }
    }

    private fun isNetworkFailure(code: String?): Boolean =
        code in transientAuthCodes || code?.startsWith("HTTP_5") == true
}
