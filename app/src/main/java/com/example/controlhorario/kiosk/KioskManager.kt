package com.example.controlhorario.kiosk

import android.content.Context
import android.util.Base64
import androidx.core.content.edit
import java.security.SecureRandom
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

data class KioskConfiguration(
    val enabled: Boolean,
    val hasExitPassword: Boolean,
)

class KioskManager(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    fun configuration() = KioskConfiguration(
        enabled = preferences.getBoolean(KEY_ENABLED, false),
        hasExitPassword = preferences.contains(KEY_PASSWORD_HASH),
    )

    fun enable(exitPassword: CharArray): Boolean {
        if (exitPassword.size < MIN_PASSWORD_LENGTH) return false
        val salt = ByteArray(SALT_BYTES).also(SecureRandom()::nextBytes)
        val hash = derive(exitPassword, salt)
        exitPassword.fill('\u0000')
        preferences.edit(commit = true) {
            putBoolean(KEY_ENABLED, true)
            putString(KEY_PASSWORD_SALT, Base64.encodeToString(salt, Base64.NO_WRAP))
            putString(KEY_PASSWORD_HASH, Base64.encodeToString(hash, Base64.NO_WRAP))
        }
        return preferences.getBoolean(KEY_ENABLED, false)
    }

    fun disable(): Boolean {
        preferences.edit(commit = true) { putBoolean(KEY_ENABLED, false) }
        return !preferences.getBoolean(KEY_ENABLED, true)
    }

    fun verify(password: CharArray): Boolean {
        val salt = preferences.getString(KEY_PASSWORD_SALT, null)?.let {
            runCatching { Base64.decode(it, Base64.NO_WRAP) }.getOrNull()
        } ?: return false
        val expected = preferences.getString(KEY_PASSWORD_HASH, null)?.let {
            runCatching { Base64.decode(it, Base64.NO_WRAP) }.getOrNull()
        } ?: return false
        val candidate = derive(password, salt)
        password.fill('\u0000')
        var difference = expected.size xor candidate.size
        expected.indices.forEach { index ->
            difference = difference or (expected[index].toInt() xor candidate.getOrElse(index) { 0 }.toInt())
        }
        candidate.fill(0)
        return difference == 0
    }

    private fun derive(password: CharArray, salt: ByteArray): ByteArray =
        PBEKeySpec(password, salt, ITERATIONS, HASH_BITS).let { spec ->
            try {
                SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
            } finally {
                spec.clearPassword()
            }
        }

    companion object {
        const val MIN_PASSWORD_LENGTH = 6
        private const val PREFERENCES = "control_horario_kiosk"
        private const val KEY_ENABLED = "enabled"
        private const val KEY_PASSWORD_HASH = "exit_password_hash"
        private const val KEY_PASSWORD_SALT = "exit_password_salt"
        private const val SALT_BYTES = 16
        private const val ITERATIONS = 210_000
        private const val HASH_BITS = 256
    }
}
