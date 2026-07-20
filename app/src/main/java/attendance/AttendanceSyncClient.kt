package com.example.controlhorario.attendance

import android.util.Log
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.database.JourneyOutboxEntity
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.LocalDate
import java.util.UUID

data class AttendanceRemoteSnapshot(
    val id: String?,
    val status: String,
    val startedAt: String?,
    val pauseStartedAt: String?,
    val pauseEndedAt: String?,
    val finishedAt: String?,
    val workedMinutes: Int,
    val breakMinutes: Int,
    val version: Long,
    val rawJson: String = ""
)
data class AttendanceSyncResult(val idempotencyKey: String, val result: String, val errorCode: String?, val version: Long, val remote: AttendanceRemoteSnapshot?, val rawRemote: String)
data class AttendanceCurrentState(
    val exists: Boolean,
    val workDate: String,
    val remote: AttendanceRemoteSnapshot?
)

internal object AttendanceCurrentStateContract {
    private val workDatePattern = Regex("^\\d{4}-\\d{2}-\\d{2}$")
    private val statuses = setOf("SIN_INICIAR", "EN_CURSO", "EN_PAUSA", "FINALIZADA")
    fun validWorkDate(value:String)=workDatePattern.matches(value)&&runCatching{LocalDate.parse(value)}.isSuccess
    fun validRemote(status:String,version:Long,workedMinutes:Int,breakMinutes:Int)=
        status in statuses&&version>=0&&workedMinutes>=0&&breakMinutes>=0
    fun validRemoteId(value:String?)=value?.let{runCatching{UUID.fromString(it)}.isSuccess&&it.length==36}==true
}

internal object AttendanceOutboxVersionRebaser {
    fun versionFrom(operation:JourneyOutboxEntity):Long=
        runCatching{JSONObject(operation.payload).optLong("known_version",0)}.getOrDefault(0)

    fun rebase(operation:JourneyOutboxEntity,knownVersion:Long):JourneyOutboxEntity {
        require(knownVersion>=0){"INVALID_KNOWN_VERSION"}
        return operation.copy(payload=JSONObject(operation.payload).put("known_version",knownVersion).toString())
    }
}

internal object AttendanceKnownVersionPolicy {
    fun select(localSyncVersion:Long?,payloadKnownVersion:Long):Long {
        require(payloadKnownVersion>=0){"INVALID_KNOWN_VERSION"}
        return localSyncVersion?.also{require(it>=0){"INVALID_LOCAL_SYNC_VERSION"}}?:payloadKnownVersion
    }
}

interface AttendanceSyncGateway {
    fun upload(deviceId: String, credential: String, operations: List<JourneyOutboxEntity>): List<AttendanceSyncResult>
    fun fetchCurrentState(deviceId: String, credential: String, employeeRemoteId: String, requestedAt: String): AttendanceCurrentState
}

class AttendanceSyncClient(private val endpoint: String) : AttendanceSyncGateway {
    override fun upload(deviceId: String, credential: String, operations: List<JourneyOutboxEntity>): List<AttendanceSyncResult> {
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
                val version = row.optLong("sync_version")
                AttendanceSyncResult(
                    row.optString("idempotency_key"), row.optString("result"), row.optString("error_code").takeIf(String::isNotBlank), version,
                    remote?.let { parseRemote(it, version) }, remote?.toString().orEmpty(),
                )
            }
        } finally {
            connection.disconnect()
        }
    }

    override fun fetchCurrentState(
        deviceId: String,
        credential: String,
        employeeRemoteId: String,
        requestedAt: String
    ): AttendanceCurrentState {
        require(endpoint.startsWith("https://") && endpoint.endsWith("/functions/v1/attendance-sync"))
        val request = JSONObject()
            .put("mode", "current_state")
            .put("employee_remote_id", employeeRemoteId)
            .put("requested_at", requestedAt)
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
            connection.outputStream.use { it.write(request.toString().toByteArray()) }
            val status = connection.responseCode
            val response = (if (status in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()?.use { it.readText() }.orEmpty()
            journeyStateLog("employeeRemoteId=$employeeRemoteId deviceId=$deviceId requestedAt=$requestedAt httpStatus=$status")
            if (status !in 200..299) throw AttendanceSyncHttpException(status, response)
            return parseCurrentState(JSONObject(response))
        } finally {
            connection.disconnect()
        }
    }

    private fun summary(operation: JourneyOutboxEntity) = runCatching {
        val payload = JSONObject(operation.payload)
        "employeeId=${payload.optString("employee_remote_id")} action=${payload.optString("action")} workDate=${payload.optString("work_date")} idempotencyKey=${operation.idempotencyKey}"
    }.getOrDefault("idempotencyKey=${operation.idempotencyKey}")
    private fun apiLog(message: String) { if (BuildConfig.DEBUG) Log.d("PUNCH_API", message) }
    private fun journeyStateLog(message: String) { if (BuildConfig.DEBUG) Log.d("JOURNEY_STATE_SYNC", message) }

    private fun parseCurrentState(json: JSONObject): AttendanceCurrentState {
        require(json.opt("exists") is Boolean) { "INVALID_CURRENT_STATE_RESPONSE" }
        val exists = json.optBoolean("exists", false)
        val workDate = json.optString("work_date")
        require(AttendanceCurrentStateContract.validWorkDate(workDate)) { "INVALID_CURRENT_STATE_WORK_DATE" }
        val remoteJson = json.optJSONObject("remote")
        if (!exists) {
            require(remoteJson == null) { "INVALID_CURRENT_STATE_RESPONSE" }
            return AttendanceCurrentState(false, workDate, null)
        }
        requireNotNull(remoteJson) { "INVALID_CURRENT_STATE_RESPONSE" }
        val version = remoteJson.optLong("version_sync", -1)
        val remote=parseRemote(remoteJson, version)
        require(AttendanceCurrentStateContract.validRemoteId(remote.id)){"INVALID_CURRENT_STATE_REMOTE_ID"}
        return AttendanceCurrentState(true, workDate, remote)
    }

    private fun parseRemote(json: JSONObject, version: Long): AttendanceRemoteSnapshot {
        val status = json.optString("estado")
        val workedMinutes = json.optInt("minutos_trabajados", -1)
        val breakMinutes = json.optInt("minutos_pausa", -1)
        require(AttendanceCurrentStateContract.validRemote(status,version,workedMinutes,breakMinutes)) { "INVALID_CURRENT_STATE_REMOTE" }
        return AttendanceRemoteSnapshot(
            id = json.optString("id").takeIf(String::isNotBlank),
            status = status,
            startedAt = json.nullable("iniciado_en"),
            pauseStartedAt = json.nullable("pausa_iniciada_en"),
            pauseEndedAt = json.nullable("pausa_finalizada_en"),
            finishedAt = json.nullable("finalizado_en"),
            workedMinutes = workedMinutes,
            breakMinutes = breakMinutes,
            version = version,
            rawJson = json.toString()
        )
    }

    private fun JSONObject.nullable(key: String) = if (isNull(key)) null else optString(key).takeIf(String::isNotBlank)

}

class AttendanceSyncHttpException(val status: Int, val response: String) : Exception("attendance-sync HTTP $status")
