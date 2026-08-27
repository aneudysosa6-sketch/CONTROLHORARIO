package com.example.controlhorario.face

import android.content.Context
import androidx.room.withTransaction
import com.example.controlhorario.R
import com.example.controlhorario.database.AppDatabase
import com.example.controlhorario.database.AppEventEntity
import com.example.controlhorario.database.EmployeeFaceBiometricEntity
import com.example.controlhorario.database.EmployeeSyncOutboxEntity
import com.example.controlhorario.device.EmployeeSyncClient
import com.example.controlhorario.device.EmployeeSyncRepository
import com.example.controlhorario.device.EmployeeUploadScheduler
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.security.DeviceIdentityManager
import java.io.IOException
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

class RoomInitialFaceEmployeeSource(
    private val repository: EmployeeRepository
) : InitialFaceEmployeeSource {
    override suspend fun findByExactEmployeeCode(employeeCode: String): Employee? =
        repository.findAnyByExactEmployeeCode(employeeCode)

    override suspend fun findByLocalId(employeeLocalId: Int): Employee? =
        repository.findAnyByLocalId(employeeLocalId)
}

class AndroidInitialFaceRemoteGateway(
    context: Context,
    private val database: AppDatabase
) : InitialFaceRemoteGateway {
    private val appContext = context.applicationContext

    override suspend fun inspect(employeeCode: String): InitialFaceRemoteState =
        withContext(Dispatchers.IO) {
            try {
                val identity = DeviceIdentityManager(appContext)
                val deviceId = identity.deviceId
                    ?: return@withContext InitialFaceRemoteState.Unavailable
                val credential = identity.credential()
                    ?: return@withContext InitialFaceRemoteState.Unavailable
                val summary = EmployeeSyncRepository(database).syncEmployeeFace(
                    EmployeeSyncClient(appContext.getString(R.string.employee_sync_url)),
                    deviceId,
                    credential,
                    employeeCode
                )
                // The identification destination remains in the back stack while this public
                // screen validates. If targeted sync changed Room, its decrypted cache must not
                // survive when the employee returns to identification.
                FaceTemplateInvalidationBus.invalidate()
                when {
                    summary.targetedEmployeeFound == false -> InitialFaceRemoteState.EmployeeNotFound
                    summary.targetedEmployeeActive == false -> InitialFaceRemoteState.EmployeeInactive
                    summary.targetedRemoteEmbeddingPresent == true -> InitialFaceRemoteState.Present(
                        valid = summary.targetedRemoteEmbeddingValid == true,
                        dimension = summary.targetedRemoteEmbeddingDimension
                    )
                    summary.targetedRemoteEmbeddingPresent == false -> InitialFaceRemoteState.Absent
                    else -> InitialFaceRemoteState.Unavailable
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: IOException) {
                InitialFaceRemoteState.Offline
            } catch (_: Exception) {
                InitialFaceRemoteState.Unavailable
            }
        }
}

class RoomInitialFacePersistence(
    private val database: AppDatabase,
    private val cipher: FaceEmbeddingCipher = FaceEmbeddingCipher()
) : InitialFacePersistence {
    override suspend fun insertInitial(
        employee: Employee,
        embedding: FloatArray,
        audit: InitialFaceEnrollmentAudit
    ): InitialFacePersistenceResult = withContext(Dispatchers.IO) {
        try {
            require(
                embedding.size == FaceEmbeddingEngine.EMBEDDING_DIMENSION &&
                    embedding.all(Float::isFinite)
            )
            val encrypted = cipher.encrypt(embedding)
            val verification = requireNotNull(
                cipher.decrypt(encrypted, FaceEmbeddingEngine.EMBEDDING_DIMENSION)
            )
            try {
                require(
                    verification.size == FaceEmbeddingEngine.EMBEDDING_DIMENSION &&
                        verification.all(Float::isFinite)
                )
                database.withTransaction {
                    if (database.employeeFaceBiometricDao().hasAnyForEmployee(employee.id)) {
                        return@withTransaction InitialFacePersistenceResult.AlreadyExists
                    }
                    val inserted = database.employeeFaceBiometricDao().insertIfAbsent(
                        EmployeeFaceBiometricEntity(
                            employeeId = employee.id,
                            encryptedEmbedding = encrypted,
                            embeddingVersion = 1,
                            modelName = "FaceNet-128",
                            embeddingDimension = FaceEmbeddingEngine.EMBEDDING_DIMENSION,
                            registeredAt = audit.occurredAt,
                            registeredBy = RESPONSIBLE_USER,
                            updatedAt = audit.occurredAt
                        )
                    )
                    if (inserted <= 0L) {
                        return@withTransaction InitialFacePersistenceResult.AlreadyExists
                    }

                    val key = UUID.randomUUID().toString()
                    val payload = JSONObject()
                        .put("idempotency_key", key)
                        .put("operation", "UPDATE")
                        .put("local_employee_id", employee.id)
                        .put("remote_id", employee.remoteId)
                        .put("employee_code", employee.employeeCode)
                        .put("face_enrollment_mode", "INITIAL_ONLY")
                        .put("face_enrollment_validation_mode", audit.validationMode.name)
                        .put("face_enrollment_occurred_at", audit.occurredAt)
                        .put("face_embedding", JSONArray(embedding.toList()))
                        .toString()
                    val outboxId = database.employeeSyncOutboxDao().insert(
                        EmployeeSyncOutboxEntity(
                            employeeLocalId = employee.id,
                            operation = "UPDATE",
                            payloadJson = payload,
                            idempotencyKey = key
                        )
                    )
                    require(outboxId > 0L)
                    database.appEventDao().saveEvent(
                        AppEventEntity(
                            title = InitialFaceEnrollmentAudit.EVENT_NAME,
                            description = audit.safeDescription(),
                            module = "SECURITY",
                            createdAt = audit.occurredAt
                        )
                    )
                    InitialFacePersistenceResult.Saved(outboxId)
                }
            } finally {
                verification.fill(0f)
            }
        } finally {
            embedding.fill(0f)
        }
    }

    private companion object { const val RESPONSIBLE_USER = "EMPLOYEE_SELF_SERVICE" }
}

object AndroidInitialFaceEnrollmentFactory {
    fun create(context: Context, database: AppDatabase): InitialFaceEnrollmentRepository {
        val employeeRepository = EmployeeRepository(
            database.employeeDao(),
            database.employeeSyncOutboxDao()
        )
        return InitialFaceEnrollmentRepository(
            employees = RoomInitialFaceEmployeeSource(employeeRepository),
            localFaces = InitialFaceLocalFaceSource {
                database.employeeFaceBiometricDao().hasAnyForEmployee(it)
            },
            remote = AndroidInitialFaceRemoteGateway(context, database),
            scopes = InitialFaceScopeSource {
                database.deviceEnrollmentDao().current()?.let { enrollment ->
                    enrollment.companyId?.takeIf(String::isNotBlank)?.let { companyId ->
                        InitialFaceEnrollmentScope(
                            deviceId = enrollment.deviceId,
                            companyId = companyId,
                            branchId = enrollment.branchId
                        )
                    }
                }
            },
            persistence = RoomInitialFacePersistence(database),
            scheduler = InitialFaceSyncScheduler {
                EmployeeUploadScheduler.enqueueImmediate(context.applicationContext)
            }
        )
    }
}
