package com.example.controlhorario.device

import android.content.Context
import android.util.Log
import androidx.room.withTransaction
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
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.EmployeeCodePolicy
import com.example.controlhorario.security.DeviceIdentityManager
import java.time.Instant
import kotlinx.coroutines.CancellationException
import org.json.JSONObject

object EmployeeTerminationUploadPolicy {
    fun isTerminated(employee: Employee): Boolean =
        !employee.isActive && employee.employmentStatus.trim().equals("desvinculado", ignoreCase = true)
}

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
        val pendingItems = outbox.pending(startedAt)
        if (pendingItems.isEmpty()) return Result.success()
        val items = buildList {
            pendingItems.forEach { item ->
                if (discardIfTerminated(database, item, startedAt)) return@forEach
                if (outbox.markSyncing(item.id, startedAt) == 1) {
                    employeeDao.setUploadSyncStatus(item.employeeLocalId, "SYNCING")
                    add(item)
                }
            }
        }
        if (items.isEmpty()) return Result.success()
        val batchTracker = EmployeeUploadBatchTracker(items)
        Log.d(
            "FACE_REGISTRATION_CRASH",
            "stage=upload_started operations=${items.size} " +
                "facial=${items.count { it.payloadJson.contains("\"face_embedding\"") }}"
        )

        return try {
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
                if (discardIfTerminated(database, item, System.currentTimeMillis())) {
                    batchTracker.markHandled(item.id, item.idempotencyKey)
                    return@forEach
                }
                when {
                    result.result == "accepted" || result.result == "duplicate" -> {
                        if (!EmployeeUploadAuthorityPolicy.accepts(item.operation, result.employeeCode)) {
                            employeeDao.setUploadSyncStatus(
                                item.employeeLocalId,
                                "FAILED",
                                EMPLOYEE_CODE_AUTHORITY_MISSING
                            )
                            outbox.markFailed(
                                item.id,
                                EMPLOYEE_CODE_AUTHORITY_MISSING,
                                Long.MAX_VALUE,
                                System.currentTimeMillis()
                            )
                            Log.e(
                                "EMPLOYEE_REMOTE_UPDATE",
                                "localEmployeeId=${item.employeeLocalId} " +
                                    "status=FAILED reason=$EMPLOYEE_CODE_AUTHORITY_MISSING"
                            )
                            batchTracker.markHandled(item.id, item.idempotencyKey)
                            return@forEach
                        }
                        completeAccepted(database,item,result)
                        Log.d(
                            "EMPLOYEE_REMOTE_UPDATE",
                            "localEmployeeId=${item.employeeLocalId} remoteId=${result.remoteId} " +
                                "authoritativeCode=${result.employeeCode?.let(EmployeeCodePolicy::maskForLog) ?: "unchanged"} status=SYNCED"
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
                                employeeDao.setUploadSyncStatus(
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
                            employeeDao.setUploadSyncStatus(
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
                        employeeDao.setUploadSyncStatus(
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
                        employeeDao.setUploadSyncStatus(item.employeeLocalId, "FAILED", result.error)
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
            var omittedRetryNeeded = false
            omittedItems.forEach { item ->
                if (discardIfTerminated(database, item, System.currentTimeMillis())) {
                    batchTracker.markHandled(item.id, item.idempotencyKey)
                    return@forEach
                }
                omittedRetryNeeded = true
                employeeDao.setUploadSyncStatus(
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
            if (omittedRetryNeeded) retryNeeded = true
            Log.d("FACE_REGISTRATION_CRASH", "stage=upload_finished results=${results.size}")
            if (retryNeeded) Result.retry() else Result.success()
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: Exception) {
            var uncancelledFailure = false
            batchTracker.unresolvedItems().forEach {
                if (discardIfTerminated(database, it, System.currentTimeMillis())) {
                    batchTracker.markHandled(it.id, it.idempotencyKey)
                    return@forEach
                }
                uncancelledFailure = true
                outbox.markFailed(
                    it.id,
                    error.message ?: "NETWORK_ERROR",
                    System.currentTimeMillis() + RETRY_DELAY_MILLIS,
                    System.currentTimeMillis()
                )
                employeeDao.setUploadSyncStatus(it.employeeLocalId, "FAILED", error.message)
            }
            Log.e(
                "FACE_REGISTRATION_CRASH",
                "stage=error file=EmployeeUploadWorker.kt pipelineStage=upload message=${error.message}",
                error
            )
            if (!uncancelledFailure) {
                Result.success()
            } else if (error is EmployeeUploadHttpException && error.status in 400..499) {
                Result.failure()
            } else {
                Result.retry()
            }
        }
    }

    private suspend fun discardIfTerminated(
        database: AppDatabase,
        item: EmployeeSyncOutboxEntity,
        now: Long
    ): Boolean {
        val employee = database.employeeDao().findByLocalId(item.employeeLocalId)
            ?: return false
        if (!EmployeeTerminationUploadPolicy.isTerminated(employee)) return false
        val discarded = database.employeeSyncOutboxDao()
            .discardOperationalForTerminated(item.employeeLocalId, now)
        if (discarded > 0) {
            Log.i(
                "EMPLOYEE_TERMINATION",
                "localEmployeeId=${item.employeeLocalId} discardedOperationalOutbox=$discarded"
            )
        }
        return true
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
            "employeeCode=${EmployeeCodePolicy.maskForLog(employee.employeeCode)} remoteId=${result.remoteId ?: employee.remoteId} " +
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
                "employeeCode=${EmployeeCodePolicy.maskForLog(employee.employeeCode)} remoteId=${result.remoteId ?: employee.remoteId} " +
                    "localEmployeeId=${employee.id} finalResult=REMOTE_RACE_NOT_RECONCILED"
            )
            return false
        }

        database.employeeDao().setUploadSyncStatus(employee.id, "SYNCED")
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
            "employeeCode=${EmployeeCodePolicy.maskForLog(employee.employeeCode)} remoteId=${result.remoteId ?: employee.remoteId} " +
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
        database.employeeDao().setUploadSyncStatus(
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
                "employeeCode=${EmployeeCodePolicy.maskForLog(employee.employeeCode)} remoteId=${result.remoteId ?: employee.remoteId} " +
                    "localEmployeeId=${employee.id} localInitialFaceRemoved=${removed > 0} " +
                    "finalResult=${InitialFaceUploadRejectionPolicy.safeAuditOutcome(result.error)}"
            )
        }
    }

    private fun isInitialOnly(item: EmployeeSyncOutboxEntity): Boolean = runCatching {
        JSONObject(item.payloadJson).optString("face_enrollment_mode") == "INITIAL_ONLY"
    }.getOrDefault(false)

    private suspend fun completeAccepted(
        database: AppDatabase,
        item: EmployeeSyncOutboxEntity,
        result: EmployeeUploadResult
    ) {
        val remoteId = requireNotNull(result.remoteId) { "employee_upsert_remote_id_missing" }
        val now = System.currentTimeMillis()
        val completed = database.withTransaction {
            val outbox = database.employeeSyncOutboxDao()
            if (outbox.syncingCount(item.id) != 1) return@withTransaction false
            val employeeDao = database.employeeDao()
            val current = employeeDao.findByLocalId(item.employeeLocalId)
            if (current != null && EmployeeTerminationUploadPolicy.isTerminated(current)) {
                outbox.discardOperationalForTerminated(item.employeeLocalId, now)
                return@withTransaction false
            }
            if (item.operation == "CREATE") {
                val authoritativeCode = requireNotNull(
                    EmployeeUploadAuthorityPolicy.authoritativeCode(
                        item.operation,
                        result.employeeCode
                    )
                ) { EMPLOYEE_CODE_AUTHORITY_MISSING }
                val employee = requireNotNull(employeeDao.findByLocalId(item.employeeLocalId)) {
                    "local_employee_missing_${item.employeeLocalId}"
                }
                val collision = employeeDao.findAnyByEmployeeCode(authoritativeCode)
                    ?.takeIf { it.id != employee.id }
                if (collision != null) {
                    check(collision.remoteId == null && collision.syncStatus != "SYNCED") {
                        "authoritative_employee_code_collision_${EmployeeCodePolicy.maskForLog(authoritativeCode)}"
                    }
                    val releasedPlaceholder = requireNotNull(
                        EmployeeCodePolicy.normalizeOrNull(
                            employee.employeeCode
                        )
                    ) { "local_placeholder_invalid" }
                    // Swap inside one transaction so a concurrent server allocation can take a
                    // local placeholder already assigned to another unsynced CREATE.
                    employeeDao.updateProvisionalEmployeeCode(
                        employee.id,
                        "__authoritative_swap_${employee.id}",
                        now
                    )
                    employeeDao.updateProvisionalEmployeeCode(
                        collision.id,
                        releasedPlaceholder,
                        now
                    )
                    rewritePendingEmployeePayloads(
                        database,
                        collision.id,
                        releasedPlaceholder,
                        remoteId = null,
                        now = now
                    )
                }
                employeeDao.markCreateRemoteSynced(
                    item.employeeLocalId,
                    authoritativeCode,
                    remoteId,
                    result.updatedAt.orEmpty(),
                    now
                )
                rewritePendingEmployeePayloads(
                    database,
                    item.employeeLocalId,
                    authoritativeCode,
                    remoteId,
                    now
                )
            } else {
                employeeDao.markRemoteSynced(
                    item.employeeLocalId,
                    remoteId,
                    result.updatedAt.orEmpty(),
                    now
                )
            }
            outbox.markSynced(item.id,now) == 1
        }
        if (completed && item.operation == "CREATE") FaceTemplateInvalidationBus.invalidate()
    }

    private suspend fun rewritePendingEmployeePayloads(
        database: AppDatabase,
        employeeId: Int,
        employeeCode: String,
        remoteId: String?,
        now: Long
    ) {
        val outbox = database.employeeSyncOutboxDao()
        outbox.unsyncedForEmployee(employeeId).forEach { pending ->
            val payload = JSONObject(pending.payloadJson)
            if (pending.operation == "CREATE" && remoteId == null) {
                payload.remove("employee_code")
            } else {
                payload.put("employee_code",employeeCode)
            }
            if (remoteId == null) payload.remove("remote_id") else payload.put("remote_id",remoteId)
            outbox.updatePayload(pending.id,payload.toString(),now)
        }
    }

    private companion object {
        const val FACE_ALREADY_REGISTERED = "FACE_ALREADY_REGISTERED"
        const val FACE_RECONCILIATION_FAILED = "FACE_REMOTE_WINNER_UNAVAILABLE"
        const val FACE_RECONCILIATION_RETRY = "FACE_REMOTE_WINNER_RETRY"
        const val FACE_TAG = "FACE_FIRST_ENROLLMENT"
        const val EMPLOYEE_CODE_AUTHORITY_MISSING = "EMPLOYEE_CODE_AUTHORITY_MISSING"
        const val UPLOAD_RESPONSE_MISSING = "EMPLOYEE_UPLOAD_RESPONSE_MISSING"
        const val RETRY_DELAY_MILLIS = 30_000L
    }
}
