package com.example.controlhorario.session

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

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

    private fun setActive(active: Boolean) {
        _isActive.value = active
        appContext
            ?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.edit()
            ?.putBoolean(KEY_ACTIVE, active)
            ?.apply()
    }
}
