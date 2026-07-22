package com.example.controlhorario.device

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.controlhorario.R
import com.example.controlhorario.database.AppDatabase
import com.example.controlhorario.database.AppEventEntity
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.database.EmployeeSyncOutboxEntity
import com.example.controlhorario.face.FaceTemplateInvalidationBus
import com.example.controlhorario.face.InitialFaceEnrollmentAudit
import com.example.controlhorario.face.InitialFaceValidationMode
import com.example.controlhorario.face.InitialFaceUploadRejectionPolicy
import com.example.controlhorario.security.DeviceIdentityManager
import java.time.Instant
import kotlinx.coroutines.CancellationException
import org.json.JSONObject

class EmployeeUploadWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val database = DatabaseProvider.getDatabase(applicationContext)
        val outbox = database.employeeSyncOutboxDao()
        val startedAt = System.currentTimeMillis()
        val recovered = outbox.recoverInterruptedSyncing(startedAt)
        if (recovered > 0) {
            Log.w("EMPLOYEE_UPLOAD_RECOVERY", "recovered=$recovered")
        }
        val identity = DeviceIdentityManager(applicationContext)
        val deviceId = identity.deviceId ?: return Result.failure()
        val credential = identity.credential() ?: return Result.failure()
        val employeeDao = database.employeeDao()
        val items = outbox.pending(startedAt)
        if (items.isEmpty()) return Result.success()
        val batchTracker = EmployeeUploadBatchTracker(items)
        Log.d(
            "FACE_REGISTRATION_CRASH",
            "stage=upload_started operations=${items.size} " +
                "facial=${items.count { it.payloadJson.contains("\"face_embedding\"") }}"
        )

        return try {
            items.forEach {
                outbox.markSyncing(it.id, System.currentTimeMillis())
                employeeDao.setSyncStatus(it.employeeLocalId, "SYNCING")
            }
            val results = EmployeeUploadClient(
                applicationContext.getString(R.string.employee_upsert_url)
            ).upload(deviceId, credential, items)
            var retryNeeded = false
            results.forEach { result ->
                val item = batchTracker.unresolvedForResponse(result.key)
                if (item == null) {
                    Log.w(
                        "FACE_REGISTRATION_CRASH",
                        "stage=upload_response_ignored reason=unknown_or_duplicate_key"
                    )
                    return@forEach
                }
                when {
                    result.result == "accepted" || result.result == "duplicate" -> {
                        employeeDao.markRemoteSynced(
                            item.employeeLocalId,
                            requireNotNull(result.remoteId),
                            result.updatedAt.orEmpty(),
                            System.currentTimeMillis()
                        )
                        outbox.markSynced(item.id, System.currentTimeMillis())
                        Log.d(
                            "EMPLOYEE_REMOTE_UPDATE",
                            "localEmployeeId=${item.employeeLocalId} remoteId=${result.remoteId} status=SYNCED"
                        )
                    }
                    isInitialOnly(item) && result.error == FACE_ALREADY_REGISTERED -> {
                        try {
                            val reconciled = reconcileRemoteWinner(
                                database = database,
                                item = item,
                                deviceId = deviceId,
                                credential = credential,
                                result = result
                            )
                            if (!reconciled) {
                                employeeDao.setSyncStatus(
                                    item.employeeLocalId,
                                    "FAILED",
                                    FACE_RECONCILIATION_FAILED
                                )
                                outbox.markFailed(
                                    item.id,
                                    FACE_RECONCILIATION_FAILED,
                                    Long.MAX_VALUE,
                                    System.currentTimeMillis()
                                )
                            }
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (error: Exception) {
                            retryNeeded = true
                            employeeDao.setSyncStatus(
                                item.employeeLocalId,
                                "FAILED",
                                FACE_RECONCILIATION_RETRY
                            )
                            outbox.markFailed(
                                item.id,
                                FACE_RECONCILIATION_RETRY,
                                System.currentTimeMillis() + RETRY_DELAY_MILLIS,
                                System.currentTimeMillis()
                            )
                            Log.e(
                                FACE_TAG,
                                "localEmployeeId=${item.employeeLocalId} finalResult=RECONCILIATION_RETRY",
                                error
                            )
                        }
                    }
                    isInitialOnly(item) &&
                        InitialFaceUploadRejectionPolicy.isDefinitive(result.error) -> {
                        invalidateRejectedInitial(database, item, result)
                    }
                    isInitialOnly(item) -> {
                        // Unknown/database rejections may be transient. Keep the offline template
                        // and retry; only the explicit business codes above revoke it.
                        retryNeeded = true
                        employeeDao.setSyncStatus(
                            item.employeeLocalId,
                            "FAILED",
                            result.error ?: "INITIAL_FACE_UPLOAD_RETRY"
                        )
                        outbox.markFailed(
                            item.id,
                            result.error ?: "INITIAL_FACE_UPLOAD_RETRY",
                            System.currentTimeMillis() + RETRY_DELAY_MILLIS,
                            System.currentTimeMillis()
                        )
                    }
                    else -> {
                        employeeDao.setSyncStatus(item.employeeLocalId, "FAILED", result.error)
                        outbox.markFailed(
                            item.id,
                            result.error ?: "REJECTED",
                            Long.MAX_VALUE,
                            System.currentTimeMillis()
                        )
                    }
                }
                batchTracker.markHandled(item.id, item.idempotencyKey)
            }
            val omittedItems = batchTracker.unresolvedItems()
            omittedItems.forEach { item ->
                employeeDao.setSyncStatus(
                    item.employeeLocalId,
                    "FAILED",
                    UPLOAD_RESPONSE_MISSING
                )
                outbox.markFailed(
                    item.id,
                    UPLOAD_RESPONSE_MISSING,
                    System.currentTimeMillis() + RETRY_DELAY_MILLIS,
                    System.currentTimeMillis()
                )
                batchTracker.markHandled(item.id, item.idempotencyKey)
                Log.w(
                    "FACE_REGISTRATION_CRASH",
                    "stage=upload_response_missing localEmployeeId=${item.employeeLocalId}"
                )
            }
            if (omittedItems.isNotEmpty()) retryNeeded = true
            Log.d("FACE_REGISTRATION_CRASH", "stage=upload_finished results=${results.size}")
            if (retryNeeded) Result.retry() else Result.success()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            batchTracker.unresolvedItems().forEach {
                outbox.markFailed(
                    it.id,
                    error.message ?: "NETWORK_ERROR",
                    System.currentTimeMillis() + RETRY_DELAY_MILLIS,
                    System.currentTimeMillis()
                )
                employeeDao.setSyncStatus(it.employeeLocalId, "FAILED", error.message)
            }
            Log.e(
                "FACE_REGISTRATION_CRASH",
                "stage=error file=EmployeeUploadWorker.kt pipelineStage=upload message=${error.message}",
                error
            )
            if (error is EmployeeUploadHttpException && error.status in 400..499) {
                Result.failure()
            } else {
                Result.retry()
            }
        }
    }

    /**
     * A server-side INITIAL_ONLY race means the locally captured face lost. Remove it before
     * downloading the server winner so this device can never keep authorizing with the loser.
     */
    private suspend fun reconcileRemoteWinner(
        database: AppDatabase,
        item: EmployeeSyncOutboxEntity,
        deviceId: String,
        credential: String,
        result: EmployeeUploadResult
    ): Boolean {
        val payload = JSONObject(item.payloadJson)
        val employee = database.employeeDao().findByLocalId(item.employeeLocalId) ?: return false
        val removed = database.employeeFaceBiometricDao()
            .deleteInitialSelfEnrollment(item.employeeLocalId)
        FaceTemplateInvalidationBus.invalidate()
        Log.d(
            FACE_TAG,
            "employeeCode=${employee.employeeCode} remoteId=${result.remoteId ?: employee.remoteId} " +
                "localEmployeeId=${employee.id} localInitialFaceRemoved=${removed > 0} " +
                "finalResult=REMOTE_RACE_LOCAL_INVALIDATED"
        )
        val summary = EmployeeSyncRepository(database).syncEmployeeFace(
            EmployeeSyncClient(applicationContext.getString(R.string.employee_sync_url)),
            deviceId,
            credential,
            employee.employeeCode
        )
        // The targeted sync may have installed the server winner after the first invalidation.
        // Publish again even when validation below fails so an empty cache cannot remain stale.
        FaceTemplateInvalidationBus.invalidate()
        val remoteFace = database.employeeFaceBiometricDao().activeForEmployee(employee.id)
        val reconciled = summary.targetedEmployeeActive == true &&
            summary.targetedRemoteEmbeddingPresent == true &&
            summary.targetedRemoteEmbeddingValid == true &&
            remoteFace?.registeredBy == "SUPABASE"
        if (!reconciled) {
            Log.w(
                FACE_TAG,
                "employeeCode=${employee.employeeCode} remoteId=${result.remoteId ?: employee.remoteId} " +
                    "localEmployeeId=${employee.id} finalResult=REMOTE_RACE_NOT_RECONCILED"
            )
            return false
        }

        database.employeeDao().setSyncStatus(employee.id, "SYNCED")
        database.employeeSyncOutboxDao().markSynced(item.id, System.currentTimeMillis())
        try {
            val enrollment = database.deviceEnrollmentDao().current()
            val mode = runCatching {
                InitialFaceValidationMode.valueOf(
                    payload.optString("face_enrollment_validation_mode")
                )
            }.getOrDefault(InitialFaceValidationMode.OFFLINE_CACHED)
            val occurredAt = payload.optString("face_enrollment_occurred_at")
                .takeIf(String::isNotBlank) ?: Instant.now().toString()
            val audit = InitialFaceEnrollmentAudit(
                deviceId = enrollment?.deviceId.orEmpty(),
                employeeLocalId = employee.id,
                employeeCode = employee.employeeCode,
                remoteId = result.remoteId ?: employee.remoteId.orEmpty(),
                companyId = enrollment?.companyId.orEmpty(),
                branchId = enrollment?.branchId,
                validationMode = mode,
                occurredAt = occurredAt,
                outcome = "REMOTE_RACE_RECONCILED"
            )
            database.appEventDao().saveEvent(
                AppEventEntity(
                    title = InitialFaceEnrollmentAudit.EVENT_NAME,
                    description = audit.safeDescription(),
                    module = "SECURITY",
                    createdAt = Instant.now().toString()
                )
            )
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            Log.e(
                FACE_TAG,
                "localEmployeeId=${employee.id} auditResult=FAILED " +
                    "finalResult=REMOTE_RACE_RECONCILED",
                error
            )
        }
        Log.d(
            FACE_TAG,
            "employeeCode=${employee.employeeCode} remoteId=${result.remoteId ?: employee.remoteId} " +
                "localEmployeeId=${employee.id} finalResult=REMOTE_RACE_RECONCILED"
        )
        return true
    }

    private suspend fun invalidateRejectedInitial(
        database: AppDatabase,
        item: EmployeeSyncOutboxEntity,
        result: EmployeeUploadResult
    ) {
        val payload = JSONObject(item.payloadJson)
        val employee = database.employeeDao().findByLocalId(item.employeeLocalId)
        val removed = database.employeeFaceBiometricDao()
            .deleteInitialSelfEnrollment(item.employeeLocalId)
        FaceTemplateInvalidationBus.invalidate()
        database.employeeDao().setSyncStatus(
            item.employeeLocalId,
            "FAILED",
            result.error ?: "INITIAL_FACE_REJECTED"
        )
        database.employeeSyncOutboxDao().markFailed(
            item.id,
            result.error ?: "INITIAL_FACE_REJECTED",
            Long.MAX_VALUE,
            System.currentTimeMillis()
        )
        if (employee != null) {
            try {
                val enrollment = database.deviceEnrollmentDao().current()
                val mode = runCatching {
                    InitialFaceValidationMode.valueOf(
                        payload.optString("face_enrollment_validation_mode")
                    )
                }.getOrDefault(InitialFaceValidationMode.OFFLINE_CACHED)
                val occurredAt = payload.optString("face_enrollment_occurred_at")
                    .takeIf(String::isNotBlank) ?: Instant.now().toString()
                val audit = InitialFaceEnrollmentAudit(
                    deviceId = enrollment?.deviceId.orEmpty(),
                    employeeLocalId = employee.id,
                    employeeCode = employee.employeeCode,
                    remoteId = result.remoteId ?: employee.remoteId.orEmpty(),
                    companyId = enrollment?.companyId.orEmpty(),
                    branchId = enrollment?.branchId,
                    validationMode = mode,
                    occurredAt = occurredAt,
                    outcome = InitialFaceUploadRejectionPolicy.safeAuditOutcome(result.error)
                )
                database.appEventDao().saveEvent(
                    AppEventEntity(
                        title = InitialFaceEnrollmentAudit.EVENT_NAME,
                        description = audit.safeDescription(),
                        module = "SECURITY",
                        createdAt = Instant.now().toString()
                    )
                )
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                Log.e(
                    FACE_TAG,
                    "localEmployeeId=${employee.id} auditResult=FAILED " +
                        "finalResult=${InitialFaceUploadRejectionPolicy.safeAuditOutcome(result.error)}",
                    error
                )
            }
            Log.w(
                FACE_TAG,
                "employeeCode=${employee.employeeCode} remoteId=${result.remoteId ?: employee.remoteId} " +
                    "localEmployeeId=${employee.id} localInitialFaceRemoved=${removed > 0} " +
                    "finalResult=${InitialFaceUploadRejectionPolicy.safeAuditOutcome(result.error)}"
            )
        }
    }

    private fun isInitialOnly(item: EmployeeSyncOutboxEntity): Boolean = runCatching {
        JSONObject(item.payloadJson).optString("face_enrollment_mode") == "INITIAL_ONLY"
    }.getOrDefault(false)

    private companion object {
        const val FACE_ALREADY_REGISTERED = "FACE_ALREADY_REGISTERED"
        const val FACE_RECONCILIATION_FAILED = "FACE_REMOTE_WINNER_UNAVAILABLE"
        const val FACE_RECONCILIATION_RETRY = "FACE_REMOTE_WINNER_RETRY"
        const val FACE_TAG = "FACE_FIRST_ENROLLMENT"
        const val UPLOAD_RESPONSE_MISSING = "EMPLOYEE_UPLOAD_RESPONSE_MISSING"
        const val RETRY_DELAY_MILLIS = 30_000L
    }
}
