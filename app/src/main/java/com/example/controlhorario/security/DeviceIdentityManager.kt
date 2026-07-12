package com.example.controlhorario.security

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec

/** Identidad local del kiosco; no contiene lógica de huella ni secretos de Supabase. */
class DeviceIdentityManager(context: Context) {
    private val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
    private val keyStore = KeyStore.getInstance(KEYSTORE).apply { load(null) }

    val installationId: String get() = preferences.getString(INSTALLATION_ID, null)
        ?: UUID.randomUUID().toString().also { preferences.edit().putString(INSTALLATION_ID, it).apply() }

    fun publicKeySpkiBase64(): String {
        ensureSigningKey()
        return Base64.encodeToString(keyStore.getCertificate(SIGNING_ALIAS).publicKey.encoded, Base64.NO_WRAP)
    }

    fun sign(payload: ByteArray): String = Signature.getInstance("SHA256withECDSA").run {
        ensureSigningKey(); initSign(keyStore.getKey(SIGNING_ALIAS, null) as java.security.PrivateKey)
        update(payload); Base64.encodeToString(sign(), Base64.NO_WRAP)
    }

    fun storeCredential(credential: String) {
        ensureEncryptionKey()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, keyStore.getKey(ENCRYPTION_ALIAS, null)) }
        val encrypted = cipher.doFinal(credential.toByteArray(Charsets.UTF_8))
        preferences.edit().putString(CREDENTIAL_IV, Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .putString(CREDENTIAL_VALUE, Base64.encodeToString(encrypted, Base64.NO_WRAP)).apply()
    }

    fun credential(): String? {
        val iv = preferences.getString(CREDENTIAL_IV, null) ?: return null
        val encrypted = preferences.getString(CREDENTIAL_VALUE, null) ?: return null
        ensureEncryptionKey()
        return Cipher.getInstance("AES/GCM/NoPadding").run {
            init(Cipher.DECRYPT_MODE, keyStore.getKey(ENCRYPTION_ALIAS, null), GCMParameterSpec(128, Base64.decode(iv, Base64.NO_WRAP)))
            doFinal(Base64.decode(encrypted, Base64.NO_WRAP)).toString(Charsets.UTF_8)
        }
    }

    fun clearCredential() = preferences.edit().remove(CREDENTIAL_IV).remove(CREDENTIAL_VALUE).apply()

    val deviceId: String? get() = preferences.getString(DEVICE_ID, null)

    fun completeEnrollment(deviceId: String, credential: String) {
        storeCredential(credential)
        preferences.edit().putString(DEVICE_ID, deviceId).apply()
    }

    private fun ensureSigningKey() {
        if (keyStore.containsAlias(SIGNING_ALIAS)) return
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, KEYSTORE).apply {
            initialize(KeyGenParameterSpec.Builder(SIGNING_ALIAS, KeyProperties.PURPOSE_SIGN)
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1")).setDigests(KeyProperties.DIGEST_SHA256).build())
            generateKeyPair()
        }
    }

    private fun ensureEncryptionKey() {
        if (keyStore.containsAlias(ENCRYPTION_ALIAS)) return
        KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE).apply {
            init(KeyGenParameterSpec.Builder(ENCRYPTION_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
            generateKey()
        }
    }

    private companion object {
        const val KEYSTORE="AndroidKeyStore"; const val PREFERENCES="secure_device_identity"
        const val INSTALLATION_ID="installation_id"; const val CREDENTIAL_IV="credential_iv"; const val CREDENTIAL_VALUE="credential_value"
        const val DEVICE_ID="device_id"
        const val SIGNING_ALIAS="controlhorario_device_signing_v1"; const val ENCRYPTION_ALIAS="controlhorario_device_credential_v1"
    }
}
