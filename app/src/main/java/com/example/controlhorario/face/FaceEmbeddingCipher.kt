package com.example.controlhorario.face

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.nio.ByteBuffer
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Stores embeddings only as AES-GCM ciphertext backed by a non-exportable Android Keystore key. */
class FaceEmbeddingCipher {
    fun encrypt(values: FloatArray): String {
        val bytes = ByteBuffer.allocate(values.size * Float.SIZE_BYTES).apply {
            values.forEach(::putFloat)
        }.array()
        val cipher = Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, key()) }
        val cipherText = cipher.doFinal(bytes)
        return Base64.encodeToString(cipher.iv + cipherText, Base64.NO_WRAP)
    }

    fun decrypt(value: String, dimension: Int): FloatArray? = runCatching {
        val bytes = Base64.decode(value, Base64.NO_WRAP)
        require(bytes.size > IV_BYTES)
        val cipher = Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(TAG_BITS, bytes.copyOfRange(0, IV_BYTES)))
        }
        val plain = cipher.doFinal(bytes.copyOfRange(IV_BYTES, bytes.size))
        require(plain.size == dimension * Float.SIZE_BYTES)
        FloatArray(dimension) { index -> ByteBuffer.wrap(plain, index * Float.SIZE_BYTES, Float.SIZE_BYTES).float }
    }.getOrNull()

    private fun key(): SecretKey {
        val store = KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEY_STORE).apply {
            init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build())
        }.generateKey()
    }

    private companion object {
        const val ANDROID_KEY_STORE = "AndroidKeyStore"
        const val ALIAS = "controlhorario_face_embedding_v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val IV_BYTES = 12
        const val TAG_BITS = 128
    }
}
