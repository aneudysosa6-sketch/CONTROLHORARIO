package com.example.controlhorario.session

import android.content.Context
import com.example.controlhorario.kiosk.KioskManager
import androidx.core.content.edit
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
        val professionalMode = KioskManager(context).configuration().enabled
        val legacyMode = appContext?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.getBoolean(KEY_ACTIVE, false) == true
        _isActive.value = professionalMode || legacyMode
    }

    fun activate() = setActive(true)
    fun deactivate() = setActive(false)

    /** Persist the kiosk exit before exposing it to navigation. */
    suspend fun deactivateAndPersist(): Boolean = withContext(Dispatchers.IO) {
        val context = appContext ?: return@withContext false
        val professionalCommitted = KioskManager(context).disable()
        val preferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        preferences.edit(commit = true) { putBoolean(KEY_ACTIVE, false) }
        if (!professionalCommitted || preferences.getBoolean(KEY_ACTIVE, true)) {
            return@withContext false
        }
        _isActive.value = false
        true
    }

    private fun setActive(active: Boolean) {
        _isActive.value = active
        if (!active) appContext?.let { KioskManager(it).disable() }
        appContext?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.edit { putBoolean(KEY_ACTIVE, active) }
    }
}
