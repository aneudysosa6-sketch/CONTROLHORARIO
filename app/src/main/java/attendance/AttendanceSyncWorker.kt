package com.example.controlhorario.attendance

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.R
import com.example.controlhorario.database.AppEventEntity
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.database.JourneyOutboxEntity
import com.example.controlhorario.security.DeviceIdentityManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import org.json.JSONObject

class AttendanceSyncWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result = AttendanceSyncExecutionGate.mutex.withLock { doWorkLocked() }

    private suspend fun doWorkLocked(): Result {
        val identity = DeviceIdentityManager(applicationContext)
        val deviceId = identity.deviceId ?: return Result.failure()
        val credential = identity.credential() ?: return Result.failure()
        val database = DatabaseProvider.getDatabase(applicationContext)
        val dao = database.journeyDao()
        val pending = dao.pending(System.currentTimeMillis())
        if (pending.isEmpty()) {
            syncLog("status=NO_PENDING")
            return Result.success()
        }

        pending.forEach { item ->
            syncLog("employeeId=${employeeId(item)} action=${item.operation} localRecordId=${item.journeyLocalId} status=${item.state} timestamp=${item.createdAt} idempotencyKey=${item.idempotencyKey}")
        }
        val client = AttendanceSyncClient(applicationContext.getString(R.string.attendance_sync_url))
        val blockedJourneys = mutableSetOf<Int>()
        pending.forEach { item ->
            if (item.journeyLocalId in blockedJourneys) return@forEach
            try {
                val knownVersion = AttendanceKnownVersionPolicy.select(
                    dao.findByLocalId(item.journeyLocalId)?.syncVersion,
                    AttendanceOutboxVersionRebaser.versionFrom(item)
                )
                val outbound = AttendanceOutboxVersionRebaser.rebase(item, knownVersion)
                val result = withContext(Dispatchers.IO) {
                    client.upload(deviceId, credential, listOf(outbound))
                }.firstOrNull { it.idempotencyKey == item.idempotencyKey }
                    ?: throw IllegalStateException("INVALID_ATTENDANCE_SYNC_RESPONSE")
                val now = System.currentTimeMillis()
                when (result.result) {
                    "accepted", "duplicate" -> {
                        val remote = requireNotNull(result.remote) { "INVALID_ATTENDANCE_SYNC_RESPONSE" }
                        dao.acknowledgeRemoteOperation(
                            item, remote.id, remote.status, remote.startedAt, remote.pauseStartedAt,
                            remote.pauseEndedAt, remote.finishedAt, remote.workedMinutes, remote.breakMinutes,
                            remote.version, remote.rawJson, now
                        )
                        syncLog("employeeId=${employeeId(item)} action=${item.operation} localRecordId=${item.journeyLocalId} syncStatus=ENVIADA result=${result.result} remoteStatus=${result.remote?.status.orEmpty()} version=${result.version}")
                    }
                    "conflict" -> {
                        dao.rejectRemoteOperation(item, "CONFLICTO", result.errorCode ?: "VERSION_CONFLICT", result.rawRemote, now)
                        blockedJourneys += item.journeyLocalId
                        database.appEventDao().saveEvent(AppEventEntity(title = "Conflicto de jornada", description = "Requiere resolución administrativa.", module = "JORNADAS"))
                        syncLog("employeeId=${employeeId(item)} action=${item.operation} localRecordId=${item.journeyLocalId} syncStatus=CONFLICTO error=${result.errorCode.orEmpty()}")
                    }
                    else -> {
                        dao.rejectRemoteOperation(item, "RECHAZADA", result.errorCode ?: "REJECTED", result.rawRemote, now)
                        blockedJourneys += item.journeyLocalId
                        database.appEventDao().saveEvent(AppEventEntity(title = "Error definitivo de sincronización", description = result.errorCode ?: "Operación rechazada", module = "JORNADAS"))
                        syncLog("employeeId=${employeeId(item)} action=${item.operation} localRecordId=${item.journeyLocalId} syncStatus=RECHAZADA error=${result.errorCode.orEmpty()}")
                    }
                }
            } catch (error: Exception) {
                val permanent = error is AttendanceSyncHttpException && error.status in 400..499
                dao.markFailed(item.id, if (permanent) "RECHAZADA" else "PENDIENTE", if (permanent) Long.MAX_VALUE else System.currentTimeMillis() + backoff(item.attempts), error.message ?: "NETWORK_ERROR")
                syncLog("employeeId=${employeeId(item)} action=${item.operation} localRecordId=${item.journeyLocalId} syncStatus=${if (permanent) "RECHAZADA" else "PENDIENTE"} errorType=${error.javaClass.simpleName} error=${error.message.orEmpty()}")
                if (permanent) {
                    database.appEventDao().saveEvent(AppEventEntity(title = "Sincronización de jornada rechazada", description = "El dispositivo o la operación requiere revisión.", module = "JORNADAS"))
                    return Result.failure()
                }
                return Result.retry()
            }
        }
        return Result.success()
    }

    private fun employeeId(item: JourneyOutboxEntity) = runCatching { JSONObject(item.payload).optString("employee_remote_id") }.getOrDefault("")
    private fun backoff(attempt: Int) = 30_000L shl attempt.coerceAtMost(8)
    private fun syncLog(message: String) { if (BuildConfig.DEBUG) Log.d("PUNCH_SYNC", message) }
}
