package com.example.controlhorario.session

import android.content.Context
import com.example.controlhorario.kiosk.KioskManager
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

        // KioskManager es la única fuente autoritativa del modo profesional.
        // La bandera antigua se conserva únicamente como espejo de compatibilidad.
        val active = KioskManager(context).configuration().enabled

        appContext
            ?.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            ?.edit()
            ?.putBoolean(KEY_ACTIVE, active)
            ?.commit()

        _isActive.value = active
    }

    fun activate(): Boolean {
        val context = appContext ?: return false
        val manager = KioskManager(context)

        val professionalCommitted = manager.enable()

        val preferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val legacyCommitted = preferences.edit()
            .putBoolean(KEY_ACTIVE, professionalCommitted)
            .commit()

        val active =
            professionalCommitted &&
                legacyCommitted &&
                manager.configuration().enabled

        if (!active) {
            manager.disable()

            preferences.edit()
                .putBoolean(KEY_ACTIVE, false)
                .commit()
        }

        _isActive.value = active
        return active
    }

    fun deactivate(): Boolean {
        val context = appContext ?: return false
        val manager = KioskManager(context)

        val professionalCommitted = manager.disable()

        val preferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val legacyCommitted = preferences.edit()
            .putBoolean(KEY_ACTIVE, false)
            .commit()

        val active = manager.configuration().enabled
        _isActive.value = active

        return professionalCommitted &&
            legacyCommitted &&
            !active
    }

    suspend fun deactivateAndPersist(): Boolean =
        withContext(Dispatchers.IO) {
            deactivate()
        }
}