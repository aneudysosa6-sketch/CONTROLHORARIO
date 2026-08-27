package com.example.controlhorario.kiosk

import android.content.Context
import androidx.core.content.edit

data class KioskConfiguration(
    val enabled: Boolean,
)

class KioskManager(context: Context) {
    private val applicationContext = context.applicationContext
    private val preferences =
        applicationContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    private val bootPreferences = applicationContext
        .createDeviceProtectedStorageContext()
        .getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    init {
        if (runCatching { preferences.getBoolean(KEY_ENABLED, false) }.getOrDefault(false)) {
            bootPreferences.edit(commit = true) {
                putBoolean(KEY_ENABLED, true)
            }
        }
    }

    fun configuration() = KioskConfiguration(
        enabled =
            bootPreferences.getBoolean(KEY_ENABLED, false) ||
                preferences.getBoolean(KEY_ENABLED, false),
    )

    fun enable(): Boolean {
        val normalCommitted = preferences.edit()
            .putBoolean(KEY_ENABLED, true)
            .remove(LEGACY_PASSWORD_HASH)
            .remove(LEGACY_PASSWORD_SALT)
            .commit()

        val bootCommitted = bootPreferences.edit()
            .putBoolean(KEY_ENABLED, true)
            .commit()

        return normalCommitted &&
            bootCommitted &&
            configuration().enabled
    }

    fun disable(): Boolean {
        val normalCommitted = preferences.edit()
            .putBoolean(KEY_ENABLED, false)
            .remove(LEGACY_PASSWORD_HASH)
            .remove(LEGACY_PASSWORD_SALT)
            .commit()

        val bootCommitted = bootPreferences.edit()
            .putBoolean(KEY_ENABLED, false)
            .commit()

        return normalCommitted &&
            bootCommitted &&
            !configuration().enabled
    }

    companion object {
        private const val PREFERENCES = "control_horario_kiosk"
        private const val KEY_ENABLED = "enabled"

        // Se conservan únicamente para eliminar credenciales creadas
        // por versiones anteriores de la aplicación.
        private const val LEGACY_PASSWORD_HASH = "exit_password_hash"
        private const val LEGACY_PASSWORD_SALT = "exit_password_salt"
    }
}