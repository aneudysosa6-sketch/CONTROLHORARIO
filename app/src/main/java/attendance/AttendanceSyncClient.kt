package com.example.controlhorario.attendance

import android.util.Log
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.database.JourneyOutboxEntity
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class AttendanceRemoteSnapshot(val id: String?, val status: String, val startedAt: String?, val pauseStartedAt: String?, val pauseEndedAt: String?, val finishedAt: String?, val workedMinutes: Int, val breakMinutes: Int)
data class AttendanceSyncResult(val idempotencyKey: String, val result: String, val errorCode: String?, val version: Long, val remote: AttendanceRemoteSnapshot?, val rawRemote: String)

class AttendanceSyncClient(private val endpoint: String) {
    fun upload(deviceId: String, credential: String, operations: List<JourneyOutboxEntity>): List<AttendanceSyncResult> {
        require(endpoint.startsWith("https://") && endpoint.endsWith("/functions/v1/attendance-sync"))
        val rows = JSONArray()
        operations.forEach { rows.put(JSONObject(it.payload)) }
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15_000
            readTimeout = 25_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("x-device-id", deviceId)
            setRequestProperty("x-device-credential", credential)
        }
        try {
            apiLog("endpoint=$endpoint operations=${operations.size} payload=${operations.joinToString(prefix = "[", postfix = "]") { summary(it) }}")
            connection.outputStream.use { it.write(JSONObject().put("operations", rows).toString().toByteArray()) }
            val status = connection.responseCode
            val response = (if (status in 200..299) connection.inputStream else connection.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            apiLog("endpoint=$endpoint httpStatus=$status response=${response.take(512)}")
            if (status !in 200..299) throw AttendanceSyncHttpException(status, response)
            val json = JSONObject(response).getJSONArray("results")
            return (0 until json.length()).map { json.getJSONObject(it) }.map { row ->
                val remote = row.optJSONObject("remote")
                AttendanceSyncResult(
                    row.optString("idempotency_key"), row.optString("result"), row.optString("error_code").takeIf(String::isNotBlank), row.optLong("sync_version"),
                    remote?.let { AttendanceRemoteSnapshot(it.optString("id").takeIf(String::isNotBlank), it.optString("estado"), it.nullable("iniciado_en"), it.nullable("pausa_iniciada_en"), it.nullable("pausa_finalizada_en"), it.nullable("finalizado_en"), it.optInt("minutos_trabajados"), it.optInt("minutos_pausa")) }, remote?.toString().orEmpty(),
                )
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun summary(operation: JourneyOutboxEntity) = runCatching {
        val payload = JSONObject(operation.payload)
        "employeeId=${payload.optString("employee_remote_id")} action=${payload.optString("action")} workDate=${payload.optString("work_date")} idempotencyKey=${operation.idempotencyKey}"
    }.getOrDefault("idempotencyKey=${operation.idempotencyKey}")
    private fun apiLog(message: String) { if (BuildConfig.DEBUG) Log.d("PUNCH_API", message) }
    private fun JSONObject.nullable(key: String) = if (isNull(key)) null else optString(key).takeIf(String::isNotBlank)
}

class AttendanceSyncHttpException(val status: Int, val response: String) : Exception("attendance-sync HTTP $status")
