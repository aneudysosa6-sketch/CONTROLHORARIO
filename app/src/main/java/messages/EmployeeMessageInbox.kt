package com.example.controlhorario.messages

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import com.example.controlhorario.attendance.EmployeeMessagePayload
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

object EmployeeMessageInbox {
    private const val PREFS = "employee_message_inbox"
    private const val PAYLOADS = "encrypted_payloads"
    private const val PRELOADED = "preloaded"
    private const val DISPLAY = "display"
    private const val AWAITING_RECEIPT = "awaiting_receipt"
    private const val KEY_ALIAS = "control_horario_employee_message"
    private const val MAX_AUDIO_BYTES = 10L * 1024L * 1024L

    private data class StoredMessage(val payload: EmployeeMessagePayload, val state: String)

    private val mutableVisible = MutableStateFlow<EmployeeMessagePayload?>(null)
    val visible: StateFlow<EmployeeMessagePayload?> = mutableVisible.asStateFlow()

    @Volatile private var initialized = false

    @Synchronized
    fun initialize(context: Context) {
        if (initialized) return
        initialized = true
        mutableVisible.value = readAll(context).firstOrNull { it.state == DISPLAY }?.payload
    }

    @Synchronized
    fun reconcilePreloaded(context: Context, remoteMessages: List<EmployeeMessagePayload>) {
        initialize(context)
        val applicationContext = context.applicationContext
        val local = readAll(applicationContext).associateBy { it.payload.id }
        val validated = remoteMessages
            .asSequence()
            .filter { EmployeeMessagePolicy.isValid(it.type, it.text, it.audioUrl, it.audioDurationSeconds) }
            .distinctBy { it.id }
            .map { remote ->
                val current = local[remote.id]
                if (current != null) current
                else {
                    val cached = if (remote.type == "VOZ_GRABADA") cacheAudio(applicationContext, remote, strict = true) else remote
                    StoredMessage(cached, PRELOADED)
                }
            }
            .toList()
        val remoteIds = validated.mapTo(mutableSetOf()) { it.payload.id }
        local.values.filter { it.payload.id !in remoteIds }.forEach { deleteCachedAudio(applicationContext, it.payload) }
        persist(applicationContext, validated)
        mutableVisible.value = validated.firstOrNull { it.state == DISPLAY }?.payload
    }

    @Synchronized
    fun deliverForEmployee(context: Context, employeeRemoteId: String): EmployeeMessagePayload? {
        initialize(context)
        val all = readAll(context).toMutableList()
        if (all.any { it.state == DISPLAY }) return all.first { it.state == DISPLAY }.payload
        val index = all.indexOfFirst {
            it.state == PRELOADED && it.payload.employeeRemoteId == employeeRemoteId
        }
        if (index < 0) return null
        val selected = all[index]
        all[index] = selected.copy(state = DISPLAY)
        persist(context, all)
        mutableVisible.value = selected.payload
        return selected.payload
    }

    @Synchronized
    fun publish(context: Context, message: EmployeeMessagePayload) {
        initialize(context)
        if (!EmployeeMessagePolicy.isValid(message.type, message.text, message.audioUrl, message.audioDurationSeconds)) return
        val stored = if (message.type == "VOZ_GRABADA") cacheAudio(context.applicationContext, message, strict = false) else message
        val all = readAll(context).filterNot { it.payload.id == stored.id }.toMutableList()
        all += StoredMessage(stored, DISPLAY)
        persist(context, all)
        mutableVisible.value = stored
    }

    @Synchronized
    fun acknowledgeForReceipt(context: Context): EmployeeMessagePayload? {
        initialize(context)
        val all = readAll(context).toMutableList()
        val index = all.indexOfFirst { it.state == DISPLAY }
        if (index < 0) return null
        val selected = all[index]
        all[index] = selected.copy(state = AWAITING_RECEIPT)
        persist(context, all)
        mutableVisible.value = null
        return selected.payload
    }

    @Synchronized
    fun pendingReceipt(context: Context): EmployeeMessagePayload? {
        initialize(context)
        return readAll(context).firstOrNull { it.state == AWAITING_RECEIPT }?.payload
    }

    @Synchronized
    fun clearConfirmed(context: Context, messageId: String) {
        initialize(context)
        val all = readAll(context)
        all.firstOrNull { it.payload.id == messageId }?.let { deleteCachedAudio(context.applicationContext, it.payload) }
        val remaining = all.filterNot { it.payload.id == messageId }
        persist(context, remaining)
        mutableVisible.value = remaining.firstOrNull { it.state == DISPLAY }?.payload
    }

    private fun cacheAudio(context: Context, message: EmployeeMessagePayload, strict: Boolean): EmployeeMessagePayload {
        val source = message.audioUrl ?: return message
        if (File(source).isAbsolute && source.startsWith(context.noBackupFilesDir.absolutePath)) return message
        val target = File(
            File(context.noBackupFilesDir, "employee-message-audio").apply { mkdirs() },
            message.id + ".audio",
        )
        return try {
            val url = URL(source)
            require(url.protocol == "https")
            val connection = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 15_000
                readTimeout = 25_000
                instanceFollowRedirects = false
            }
            try {
                require(connection.responseCode in 200..299)
                val declaredLength = connection.contentLengthLong
                require(declaredLength in 1..MAX_AUDIO_BYTES)
                connection.inputStream.use { input -> target.outputStream().use { output -> input.copyTo(output) } }
                require(target.length() in 1..MAX_AUDIO_BYTES)
                message.copy(audioUrl = target.absolutePath)
            } finally {
                connection.disconnect()
            }
        } catch (error: Exception) {
            target.delete()
            if (strict) throw error
            message
        }
    }

    private fun readAll(context: Context): List<StoredMessage> = runCatching {
        val encrypted = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(PAYLOADS, null)
            ?.takeIf(String::isNotBlank)
            ?: return emptyList()
        val values = JSONArray(decrypt(encrypted))
        (0 until values.length()).mapNotNull { index -> deserialize(values.getJSONObject(index)) }
    }.getOrDefault(emptyList())

    private fun persist(context: Context, messages: List<StoredMessage>) {
        val prefs = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (messages.isEmpty()) {
            prefs.edit().remove(PAYLOADS).commit()
            return
        }
        val array = JSONArray()
        messages.forEach { stored ->
            array.put(
                JSONObject()
                    .put("state", stored.state)
                    .put("id", stored.payload.id)
                    .put("employee_id", stored.payload.employeeRemoteId)
                    .put("type", stored.payload.type)
                    .put("text", stored.payload.text ?: JSONObject.NULL)
                    .put("audio_url", stored.payload.audioUrl ?: JSONObject.NULL)
                    .put("audio_duration_seconds", stored.payload.audioDurationSeconds),
            )
        }
        prefs.edit().putString(PAYLOADS, encrypt(array.toString())).commit()
    }

    private fun deserialize(json: JSONObject): StoredMessage? {
        val payload = EmployeeMessagePayload(
            id = json.getString("id"),
            employeeRemoteId = json.getString("employee_id"),
            type = json.getString("type"),
            text = json.optString("text").takeIf(String::isNotBlank),
            audioUrl = json.optString("audio_url").takeIf(String::isNotBlank),
            audioDurationSeconds = json.optInt("audio_duration_seconds", 0),
        )
        val valid = EmployeeMessagePolicy.isValid(payload.type, payload.text, payload.audioUrl, payload.audioDurationSeconds) ||
            (payload.type == "VOZ_GRABADA" && !payload.audioUrl.isNullOrBlank() &&
                payload.audioDurationSeconds in 1..30 && File(payload.audioUrl).isAbsolute)
        return payload.takeIf { valid }?.let {
            StoredMessage(it, json.optString("state", PRELOADED).takeIf { state ->
                state in setOf(PRELOADED, DISPLAY, AWAITING_RECEIPT)
            } ?: PRELOADED)
        }
    }

    private fun deleteCachedAudio(context: Context, message: EmployeeMessagePayload) {
        message.audioUrl?.takeIf { it.startsWith(context.noBackupFilesDir.absolutePath) }
            ?.let { runCatching { File(it).delete() } }
    }

    private fun encrypt(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, encryptionKey())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(cipher.iv, Base64.NO_WRAP) + "." +
            Base64.encodeToString(encrypted, Base64.NO_WRAP)
    }

    private fun decrypt(value: String): String {
        val parts = value.split('.', limit = 2)
        require(parts.size == 2)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            encryptionKey(),
            GCMParameterSpec(128, Base64.decode(parts[0], Base64.NO_WRAP)),
        )
        return cipher.doFinal(Base64.decode(parts[1], Base64.NO_WRAP)).toString(Charsets.UTF_8)
    }

    private fun encryptionKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .build(),
            )
            generateKey()
        }
    }
}
