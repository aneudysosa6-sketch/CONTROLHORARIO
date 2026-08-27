package com.example.controlhorario.face

import android.content.Context
import com.example.controlhorario.R
import com.example.controlhorario.model.EmployeeCodePolicy
import com.example.controlhorario.security.DeviceIdentityManager
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.time.Instant
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

class AndroidTerminalFaceEnrollmentGateway(context: Context) : TerminalFaceEnrollmentGateway {
    private val appContext = context.applicationContext
    private val endpoint = appContext.getString(R.string.face_enrollment_url)
    private val identity = DeviceIdentityManager(appContext)

    override suspend fun lookup(employeeCode: String): TerminalFaceEnrollmentLookup = withContext(Dispatchers.IO) {
        val code = EmployeeCodePolicy.normalizeOrNull(employeeCode)
            ?: throw TerminalFaceEnrollmentException("EMPLOYEE_CODE_INVALID")
        val response = post(JSONObject().put("action", "lookup").put("employee_code", code))
        val dimension = response.optInt("embedding_dimension", -1)
        val model = response.optString("model_name")
        if (dimension != FaceEmbeddingEngine.EMBEDDING_DIMENSION || model != "FaceNet-128") {
            throw TerminalFaceEnrollmentException("FACE_MODEL_INCOMPATIBLE")
        }
        TerminalFaceEnrollmentLookup(
            employeeRemoteId = response.requireUuid("employee_id"),
            employeeCode = requireNotNull(EmployeeCodePolicy.normalizeOrNull(response.getString("employee_code"))),
            employeeName = response.getString("employee_name").trim().ifBlank {
                throw TerminalFaceEnrollmentException("EMPLOYEE_NOT_FOUND")
            },
            modelName = model,
            embeddingDimension = dimension,
        )
    }

    override suspend fun complete(
        lookup: TerminalFaceEnrollmentLookup,
        embedding: FloatArray,
        livenessVerified: Boolean,
    ): TerminalFaceEnrollmentConfirmation = withContext(Dispatchers.IO) {
        if (!livenessVerified) throw TerminalFaceEnrollmentException("FACE_LIVENESS_INCOMPLETE")
        if (embedding.size != FaceEmbeddingEngine.EMBEDDING_DIMENSION || !embedding.all(Float::isFinite)) {
            throw TerminalFaceEnrollmentException("FACE_EMBEDDING_INVALID")
        }
        val embeddingJson = JSONArray(embedding.toList())
        val embeddingHash = sha256Float32(embedding)
        val idempotencyKey = UUID.randomUUID().toString()
        val response = post(
            JSONObject()
                .put("action", "complete")
                .put("idempotency_key", idempotencyKey)
                .put("employee_id", lookup.employeeRemoteId)
                .put("embedding", embeddingJson)
                .put("embedding_sha256", embeddingHash)
                .put(
                    "capture_metadata",
                    JSONObject()
                        .put("poses_completed", 3)
                        .put("blink_verified", true)
                        .put("client_model", "FaceNet-128"),
                ),
            requestId = idempotencyKey,
        )
        val values = response.optJSONArray("face_embedding")
            ?: throw TerminalFaceEnrollmentException("FACE_CONFIRMATION_INVALID")
        val confirmed = FloatArray(values.length()) { index ->
            values.optDouble(index, Double.NaN).toFloat()
        }
        val returnedHash = response.optString("embedding_sha256")
        if (
            confirmed.size != FaceEmbeddingEngine.EMBEDDING_DIMENSION ||
            !confirmed.all(Float::isFinite) ||
            returnedHash != embeddingHash || sha256Float32(confirmed) != embeddingHash
        ) {
            confirmed.fill(0f)
            throw TerminalFaceEnrollmentException("FACE_CONFIRMATION_INVALID")
        }
        val pending = response.optInt("pending_face_count", 0).coerceAtLeast(0)
        PendingFaceEnrollmentCountStore.update(appContext, pending)
        TerminalFaceEnrollmentConfirmation(
            employeeRemoteId = response.requireUuid("employee_id"),
            enrolledAt = response.getString("enrolled_at"),
            modelName = response.getString("model_name"),
            embeddingDimension = response.getInt("embedding_dimension"),
            embedding = confirmed,
            pendingFaceCount = pending,
        )
    }

    private fun post(body: JSONObject, requestId: String = UUID.randomUUID().toString()): JSONObject {
        require(endpoint.startsWith("https://") && endpoint.endsWith("/functions/v1/face-enrollment"))
        val deviceId = identity.deviceId ?: throw TerminalFaceEnrollmentException("INVALID_DEVICE_CREDENTIAL")
        val credential = identity.credential() ?: throw TerminalFaceEnrollmentException("INVALID_DEVICE_CREDENTIAL")
        val occurredAt = Instant.now().toString()
        body.put("request_id", requestId).put("occurred_at", occurredAt)
        val rawBody = body.toString()
        val signedPayload = "$requestId|$deviceId|$occurredAt|${sha256Hex(rawBody)}"
        val signature = identity.sign(signedPayload.toByteArray(Charsets.UTF_8))
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15_000
            readTimeout = 30_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("x-device-id", deviceId)
            setRequestProperty("x-device-credential", credential)
            setRequestProperty("x-device-request-id", requestId)
            setRequestProperty("x-device-signature", signature)
        }
        try {
            connection.outputStream.use { it.write(rawBody.toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val responseBody = (if (status in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()?.use { it.readText() }.orEmpty()
            val response = runCatching { JSONObject(responseBody) }.getOrElse {
                throw TerminalFaceEnrollmentException("FACE_RESPONSE_INVALID")
            }
            if (status !in 200..299) {
                val code = response.optString("error_code", "FACE_ENROLLMENT_ERROR")
                val message = response.optString("message").takeIf(String::isNotBlank)
                    ?: TerminalFaceEnrollmentMessages.forCode(code)
                throw TerminalFaceEnrollmentException(code, message)
            }
            return response
        } catch (known: TerminalFaceEnrollmentException) {
            throw known
        } catch (_: IOException) {
            throw TerminalFaceEnrollmentException("NETWORK_UNAVAILABLE")
        } finally {
            connection.disconnect()
        }
    }

    private fun JSONObject.requireUuid(name: String): String = getString(name).also {
        if (!UUID_PATTERN.matches(it)) throw TerminalFaceEnrollmentException("FACE_RESPONSE_INVALID")
    }

    private fun sha256Float32(value: FloatArray): String {
        val bytes = ByteBuffer.allocate(value.size * Float.SIZE_BYTES)
            .order(ByteOrder.LITTLE_ENDIAN)
        value.forEach(bytes::putFloat)
        return MessageDigest.getInstance("SHA-256").digest(bytes.array())
            .joinToString("") { "%02x".format(it) }
    }

    private fun sha256Hex(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(Charsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    private companion object {
        val UUID_PATTERN = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
    }
}
