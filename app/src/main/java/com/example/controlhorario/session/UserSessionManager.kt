package com.example.controlhorario.session

import android.content.Context
import com.example.controlhorario.database.AppUserEntity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

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

    private var appContext: Context? = null

    private val _currentUser =
        MutableStateFlow<AppUserEntity?>(null)

    val currentUser: StateFlow<AppUserEntity?> =
        _currentUser

    fun init(context: Context) {
        appContext = context.applicationContext
        restoreSession()
    }

    fun login(user: AppUserEntity) {
        _currentUser.value = user
        saveSession(user)
    }

    fun logout() {
        _currentUser.value = null
        appContext
            ?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.edit()
            ?.clear()
            ?.apply()
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

    private fun saveSession(user: AppUserEntity) {
        appContext
            ?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.edit()
            ?.putInt(KEY_USER_ID, user.id)
            ?.putString(KEY_FULL_NAME, user.fullName)
            ?.putString(KEY_USERNAME, user.username)
            ?.putString(KEY_EMAIL, user.email)
            ?.remove(LEGACY_KEY_PASSWORD)
            ?.putString(KEY_ROLE, user.role)
            ?.putString(KEY_PERMISSIONS, user.permissionsCsv)
            ?.putInt(KEY_EMPLOYEE_ID, user.employeeId)
            ?.putInt(KEY_BRANCH_ID, user.branchId)
            ?.putInt(KEY_DEPARTMENT_ID, user.departmentId)
            ?.putBoolean(KEY_IS_ACTIVE, user.isActive)
            ?.putString(KEY_CREATED_AT, user.createdAt)
            ?.putString(KEY_UPDATED_AT, user.updatedAt)
            ?.putString(KEY_LAST_LOGIN_AT, user.lastLoginAt)
            ?.apply()
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
}
