package com.example.controlhorario.session

import android.content.Context
import android.util.Log
import com.example.controlhorario.auth.AuthenticatedPrincipal
import com.example.controlhorario.auth.AuthFlowException
import com.example.controlhorario.auth.AuthRepository
import com.example.controlhorario.auth.AuthSessionStore
import com.example.controlhorario.auth.SupabaseSession
import com.example.controlhorario.database.AppUserEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext

object UserSessionManager {
    private const val PREFS_NAME = "osinet_session"
    private const val KEY_USER_ID = "user_id"
    private const val KEY_FULL_NAME = "full_name"
    private const val KEY_USERNAME = "username"
    private const val KEY_EMAIL = "email"
    // Legacy key kept only so existing plaintext values can be removed safely.
    private const val LEGACY_KEY_PASSWORD = "password"
    private const val KEY_ROLE = "role"
    private const val KEY_PERMISSIONS = "permissions"
    private const val KEY_EMPLOYEE_ID = "employee_id"
    private const val KEY_BRANCH_ID = "branch_id"
    private const val KEY_DEPARTMENT_ID = "department_id"
    private const val KEY_IS_ACTIVE = "is_active"
    private const val KEY_CREATED_AT = "created_at"
    private const val KEY_UPDATED_AT = "updated_at"
    private const val KEY_LAST_LOGIN_AT = "last_login_at"
    private const val KEY_AUTH_UID = "auth_uid"
    private const val KEY_ACCESS_TOKEN = "access_token"
    private const val KEY_REFRESH_TOKEN = "refresh_token"
    private const val KEY_ACCESS_TOKEN_EXPIRES_AT = "access_token_expires_at"
    private const val LOG_TAG = "UserSessionManager"

    private var appContext: Context? = null

    private val _currentUser =
        MutableStateFlow<AppUserEntity?>(null)

    val currentUser: StateFlow<AppUserEntity?> = _currentUser

    fun init(context: Context) {
        appContext = context.applicationContext
        restoreSession()
    }

    fun login(user: AppUserEntity) {
        _currentUser.value = user
        saveSession(user)
    }

    fun loginRemote(user: AppUserEntity, principal: AuthenticatedPrincipal? = null) {
        _currentUser.value = user
        saveSession(user, principal)
    }

    suspend fun restoreFromSupabase(authRepository: AuthRepository): Boolean = withContext(Dispatchers.IO) {
        val prefs = appContext?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE) ?: return@withContext false
        val storedSession = loadStoredSession(prefs) ?: return@withContext false
        try {
            val restored = authRepository.restore(storedSession)
            AuthSessionStore.setPrincipal(restored.principal)
            _currentUser.value = restored.user
            saveSession(restored.user, restored.principal)
            true
        } catch (error: AuthFlowException) {
            Log.w(LOG_TAG, "session_restore=invalid; etapa=${error.stage}; codigo=${error.code}; mensaje=${error.message}")
            clear()
            false
        } catch (error: Exception) {
            Log.w(LOG_TAG, "session_restore=failure; error=${error.message}")
            false
        }
    }

    fun logout() {
        _currentUser.value = null
        AuthSessionStore.clear()
        clearPersistedSession()
    }

    fun getCurrentUser(): AppUserEntity? {
        return _currentUser.value
    }

    fun isLoggedIn(): Boolean {
        return _currentUser.value != null
    }

    fun hasRole(role: String): Boolean {
        return _currentUser.value?.role == role
    }

    fun currentUserName(): String {
        return _currentUser.value?.fullName ?: ""
    }

    fun currentUserRole(): String {
        return _currentUser.value?.role ?: ""
    }

    fun currentUserId(): Int {
        return _currentUser.value?.id ?: 0
    }

    private fun saveSession(user: AppUserEntity, principal: AuthenticatedPrincipal? = null) {
        val editor = appContext
            ?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.edit()
            ?: return
        editor.putInt(KEY_USER_ID, user.id)
            .putString(KEY_FULL_NAME, user.fullName)
            .putString(KEY_USERNAME, user.username)
            .putString(KEY_EMAIL, user.email)
            .remove(LEGACY_KEY_PASSWORD)
            .putString(KEY_ROLE, user.role)
            .putString(KEY_PERMISSIONS, user.permissionsCsv)
            .putInt(KEY_EMPLOYEE_ID, user.employeeId)
            .putInt(KEY_BRANCH_ID, user.branchId)
            .putInt(KEY_DEPARTMENT_ID, user.departmentId)
            .putBoolean(KEY_IS_ACTIVE, user.isActive)
            .putString(KEY_CREATED_AT, user.createdAt)
            .putString(KEY_UPDATED_AT, user.updatedAt)
            .putString(KEY_LAST_LOGIN_AT, user.lastLoginAt)
            .putString(KEY_AUTH_UID, principal?.authUid ?: user.email)
        if (principal != null) {
            editor.putString(KEY_ACCESS_TOKEN, principal.accessToken)
                .putString(KEY_REFRESH_TOKEN, principal.refreshToken)
                .putLong(KEY_ACCESS_TOKEN_EXPIRES_AT, principal.accessTokenExpiresAt)
        } else {
            editor.remove(KEY_ACCESS_TOKEN)
                .remove(KEY_REFRESH_TOKEN)
                .remove(KEY_ACCESS_TOKEN_EXPIRES_AT)
        }
        editor.apply()
    }

    private fun loadStoredSession(prefs: android.content.SharedPreferences): SupabaseSession? {
        val accessToken = prefs.getString(KEY_ACCESS_TOKEN, "").orEmpty()
        val refreshToken = prefs.getString(KEY_REFRESH_TOKEN, "").orEmpty()
        if (accessToken.isBlank() || refreshToken.isBlank()) return null
        val authUid = prefs.getString(KEY_AUTH_UID, "").orEmpty()
        val email = prefs.getString(KEY_EMAIL, "").orEmpty()
        if (authUid.isBlank() || email.isBlank()) return null
        return SupabaseSession(
            accessToken = accessToken,
            refreshToken = refreshToken,
            accessTokenExpiresAt = prefs.getLong(KEY_ACCESS_TOKEN_EXPIRES_AT, 0L),
            authUid = authUid,
            email = email,
        )
    }

    private fun restoreSession() {
        val prefs = appContext?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE) ?: return
        val userId = prefs.getInt(KEY_USER_ID, 0)
        if (userId == 0 || !prefs.getBoolean(KEY_IS_ACTIVE, true)) return
        _currentUser.value = AppUserEntity(
            id = userId,
            fullName = prefs.getString(KEY_FULL_NAME, "").orEmpty(),
            username = prefs.getString(KEY_USERNAME, "").orEmpty(),
            email = prefs.getString(KEY_EMAIL, "").orEmpty(),
            // Authentication secrets are never restored into the persisted session.
            password = "",
            role = prefs.getString(KEY_ROLE, "").orEmpty(),
            permissionsCsv = prefs.getString(KEY_PERMISSIONS, "").orEmpty(),
            employeeId = prefs.getInt(KEY_EMPLOYEE_ID, 0),
            branchId = prefs.getInt(KEY_BRANCH_ID, 0),
            departmentId = prefs.getInt(KEY_DEPARTMENT_ID, 0),
            isActive = true,
            createdAt = prefs.getString(KEY_CREATED_AT, "").orEmpty(),
            updatedAt = prefs.getString(KEY_UPDATED_AT, "").orEmpty(),
            lastLoginAt = prefs.getString(KEY_LAST_LOGIN_AT, "").orEmpty()
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
}
