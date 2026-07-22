package com.example.controlhorario.session

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.withContext

object KioskModeManager {
    private const val PREFS_NAME = "osinet_kiosk_mode"
    private const val KEY_ACTIVE = "active"

    private var appContext: Context? = null
    private val _isActive = MutableStateFlow(false)
    val isActive: StateFlow<Boolean> = _isActive

    fun init(context: Context) {
        appContext = context.applicationContext
        _isActive.value = appContext
            ?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.getBoolean(KEY_ACTIVE, false) == true
    }

    fun activate() = setActive(true)
    fun deactivate() = setActive(false)

    /** Persist the kiosk exit before exposing it to navigation. */
    suspend fun deactivateAndPersist(): Boolean = withContext(Dispatchers.IO) {
        val context = appContext ?: return@withContext false
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val committed = preferences.edit().putBoolean(KEY_ACTIVE, false).commit()
        if (!committed || preferences.getBoolean(KEY_ACTIVE, true)) {
            return@withContext false
        }
        _isActive.value = false
        true
    }

    private fun setActive(active: Boolean) {
        _isActive.value = active
        appContext
            ?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.edit()
            ?.putBoolean(KEY_ACTIVE, active)
            ?.apply()
    }
}
