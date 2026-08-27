package com.example.controlhorario.face

import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.EmployeeCodePolicy
import java.util.Locale
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Public self-enrollment accepts one deliberately narrow identifier format. It never uses PIN. */
object InitialFaceEmployeeCodePolicy {
    const val PUBLIC_CODE_LENGTH = EmployeeCodePolicy.LENGTH

    fun isValid(value: String): Boolean = EmployeeCodePolicy.isValid(value)

    fun normalizeOrNull(value: String): String? = EmployeeCodePolicy.normalizeOrNull(value)

    fun lookupCandidates(value: String): List<String> = EmployeeCodePolicy.lookupCandidates(value)
}

data class InitialFaceEnrollmentScope(
    val deviceId: String,
    val companyId: String,
    val branchId: String?
)

enum class InitialFaceValidationMode { ONLINE_VERIFIED, OFFLINE_CACHED }

enum class InitialFaceEnrollmentDenial {
    INVALID_EMPLOYEE_CODE,
    EMPLOYEE_NOT_FOUND,
    EMPLOYEE_CODE_AMBIGUOUS,
    EMPLOYEE_INACTIVE,
    EMPLOYEE_NOT_SYNCED,
    DEVICE_SCOPE_MISSING,
    COMPANY_MISMATCH,
    BRANCH_MISMATCH,
    JOURNEY_DISABLED,
    LOCAL_FACE_ALREADY_REGISTERED,
    REMOTE_FACE_ALREADY_REGISTERED,
    REMOTE_FACE_INVALID,
    REMOTE_EMPLOYEE_NOT_FOUND,
    REMOTE_EMPLOYEE_INACTIVE,
    REMOTE_VALIDATION_FAILED,
    INVALID_EMBEDDING,
    PERMIT_EXPIRED,
    PERMIT_ALREADY_USED,
    EMPLOYEE_CHANGED,
    CONCURRENT_ENROLLMENT,
    STORAGE_FAILED
}

@ConsistentCopyVisibility
data class InitialFaceEnrollmentPermit internal constructor(
    val token: String,
    val employeeLocalId: Int,
    val issuedAt: Long,
    val expiresAt: Long,
    val validationMode: InitialFaceValidationMode
)

sealed interface InitialFaceEligibility {
    data class Allowed(
        val employee: Employee,
        val permit: InitialFaceEnrollmentPermit
    ) : InitialFaceEligibility

    data class Denied(val reason: InitialFaceEnrollmentDenial) : InitialFaceEligibility
}

sealed interface InitialFaceCommitResult {
    data class Saved(
        val employeeLocalId: Int,
        val outboxId: Long,
        val validationMode: InitialFaceValidationMode
    ) : InitialFaceCommitResult

    data class Denied(val reason: InitialFaceEnrollmentDenial) : InitialFaceCommitResult
}

sealed interface InitialFaceRemoteState {
    data object Absent : InitialFaceRemoteState
    data class Present(val valid: Boolean, val dimension: Int?) : InitialFaceRemoteState
    data object EmployeeNotFound : InitialFaceRemoteState
    data object EmployeeInactive : InitialFaceRemoteState
    data object Offline : InitialFaceRemoteState
    data object Unavailable : InitialFaceRemoteState
}

interface InitialFaceEmployeeSource {
    suspend fun findByExactEmployeeCode(employeeCode: String): Employee?
    suspend fun findByLocalId(employeeLocalId: Int): Employee?
}

fun interface InitialFaceLocalFaceSource {
    suspend fun exists(employeeLocalId: Int): Boolean
}

fun interface InitialFaceRemoteGateway {
    suspend fun inspect(employeeCode: String): InitialFaceRemoteState
}

fun interface InitialFaceScopeSource {
    suspend fun current(): InitialFaceEnrollmentScope?
}

data class InitialFaceEnrollmentAudit(
    val deviceId: String,
    val employeeLocalId: Int,
    val employeeCode: String,
    val remoteId: String,
    val companyId: String,
    val branchId: String?,
    val validationMode: InitialFaceValidationMode,
    val occurredAt: String,
    val outcome: String = "LOCAL_QUEUED"
) {
    val eventName: String = EVENT_NAME
    val responsibleUser: String = RESPONSIBLE_USER

    /** Explicit allow-list serialization keeps biometrics, PINs, photos and personal data out. */
    fun safeDescription(): String = listOf(
        "event=$eventName",
        "responsibleUser=$responsibleUser",
        "deviceId=$deviceId",
        "employeeLocalId=$employeeLocalId",
        "employeeCode=$employeeCode",
        "remoteId=$remoteId",
        "companyId=$companyId",
        "branchId=${branchId.orEmpty()}",
        "validationMode=${validationMode.name}",
        "occurredAt=$occurredAt",
        "outcome=$outcome"
    ).joinToString(";")

    companion object {
        const val EVENT_NAME = "FACE_FIRST_ENROLLMENT"
        const val RESPONSIBLE_USER = "EMPLOYEE_SELF_SERVICE"
    }
}

sealed interface InitialFacePersistenceResult {
    data class Saved(val outboxId: Long) : InitialFacePersistenceResult
    data object AlreadyExists : InitialFacePersistenceResult
}

fun interface InitialFacePersistence {
    suspend fun insertInitial(
        employee: Employee,
        embedding: FloatArray,
        audit: InitialFaceEnrollmentAudit
    ): InitialFacePersistenceResult
}

fun interface InitialFaceSyncScheduler { fun enqueue() }

/** Only known business rejections invalidate the local offline-first template immediately. */
object InitialFaceUploadRejectionPolicy {
    private val definitiveCodes = setOf(
        "INVALID_PAYLOAD",
        "EMPLOYEE_NOT_FOUND",
        "EMPLOYEE_CHANGED",
        "EMPLOYEE_INACTIVE",
        "BRANCH_MISMATCH",
        "JOURNEY_DISABLED",
        "IDEMPOTENCY_KEY_REUSED"
    )

    fun isDefinitive(errorCode: String?): Boolean =
        errorCode != null && errorCode in definitiveCodes

    fun safeAuditOutcome(errorCode: String?): String =
        if (isDefinitive(errorCode)) "REMOTE_REJECTED_$errorCode" else "REMOTE_REJECTED"
}

/**
 * Coordinates public first-time enrollment. Admin registration remains on its legacy replacement
 * flow; this repository has no replacement or deletion operation by design.
 */
class InitialFaceEnrollmentRepository(
    private val employees: InitialFaceEmployeeSource,
    private val localFaces: InitialFaceLocalFaceSource,
    private val remote: InitialFaceRemoteGateway,
    private val scopes: InitialFaceScopeSource,
    private val persistence: InitialFacePersistence,
    private val scheduler: InitialFaceSyncScheduler,
    private val clockMillis: () -> Long = System::currentTimeMillis,
    private val isoTimestamp: (Long) -> String = { java.time.Instant.ofEpochMilli(it).toString() },
    private val permitTtlMillis: Long = DEFAULT_PERMIT_TTL_MILLIS
) {
    private val mutex = Mutex()
    private val permits = mutableMapOf<String, PermitRecord>()

    suspend fun check(publicEmployeeCode: String): InitialFaceEligibility = mutex.withLock {
        purgeExpiredPermits()
        val canonicalCode = InitialFaceEmployeeCodePolicy.normalizeOrNull(publicEmployeeCode)
            ?: return@withLock denied(InitialFaceEnrollmentDenial.INVALID_EMPLOYEE_CODE)
        val candidates = InitialFaceEmployeeCodePolicy.lookupCandidates(publicEmployeeCode)

        val matches = candidates.mapNotNull { employees.findByExactEmployeeCode(it) }
            .distinctBy(Employee::id)
        if (matches.isEmpty()) return@withLock denied(InitialFaceEnrollmentDenial.EMPLOYEE_NOT_FOUND)
        if (matches.size != 1) return@withLock denied(InitialFaceEnrollmentDenial.EMPLOYEE_CODE_AMBIGUOUS)
        val initialEmployee = matches.single()
        val scope = scopes.current()
            ?: return@withLock denied(InitialFaceEnrollmentDenial.DEVICE_SCOPE_MISSING)
        validateEmployee(initialEmployee, scope, requireSynced = false)?.let {
            return@withLock denied(it)
        }
        if (localFaces.exists(initialEmployee.id)) {
            return@withLock denied(InitialFaceEnrollmentDenial.LOCAL_FACE_ALREADY_REGISTERED)
        }

        val remoteState = remote.inspect(canonicalCode)
        val mode = when (remoteState) {
            InitialFaceRemoteState.Absent -> InitialFaceValidationMode.ONLINE_VERIFIED
            InitialFaceRemoteState.Offline -> InitialFaceValidationMode.OFFLINE_CACHED
            is InitialFaceRemoteState.Present -> return@withLock denied(
                if (remoteState.valid) InitialFaceEnrollmentDenial.REMOTE_FACE_ALREADY_REGISTERED
                else InitialFaceEnrollmentDenial.REMOTE_FACE_INVALID
            )
            InitialFaceRemoteState.EmployeeNotFound ->
                return@withLock denied(InitialFaceEnrollmentDenial.REMOTE_EMPLOYEE_NOT_FOUND)
            InitialFaceRemoteState.EmployeeInactive ->
                return@withLock denied(InitialFaceEnrollmentDenial.REMOTE_EMPLOYEE_INACTIVE)
            InitialFaceRemoteState.Unavailable ->
                return@withLock denied(InitialFaceEnrollmentDenial.REMOTE_VALIDATION_FAILED)
        }

        // Targeted synchronization may have changed employee status/scope or downloaded a face.
        val employee = employees.findByLocalId(initialEmployee.id)
            ?: return@withLock denied(InitialFaceEnrollmentDenial.EMPLOYEE_NOT_FOUND)
        if (initialEmployee.remoteId != null &&
            !initialEmployee.remoteId.equals(employee.remoteId, ignoreCase = true)
        ) {
            return@withLock denied(InitialFaceEnrollmentDenial.EMPLOYEE_CHANGED)
        }
        validateEmployee(employee, scope, requireSynced = true)?.let {
            return@withLock denied(it)
        }
        if (localFaces.exists(employee.id)) {
            return@withLock denied(
                if (mode == InitialFaceValidationMode.ONLINE_VERIFIED)
                    InitialFaceEnrollmentDenial.REMOTE_FACE_ALREADY_REGISTERED
                else InitialFaceEnrollmentDenial.LOCAL_FACE_ALREADY_REGISTERED
            )
        }

        permits.values.removeAll { it.employee.id == employee.id }
        val now = clockMillis()
        val permit = InitialFaceEnrollmentPermit(
            token = UUID.randomUUID().toString(),
            employeeLocalId = employee.id,
            issuedAt = now,
            expiresAt = now + permitTtlMillis,
            validationMode = mode
        )
        permits[permit.token] = PermitRecord(permit, employee, canonicalCode, scope)
        InitialFaceEligibility.Allowed(
            employee.copy(
                employeeCode = canonicalCode
            ),
            permit
        )
    }

    suspend fun commit(
        permit: InitialFaceEnrollmentPermit,
        embedding: FloatArray
    ): InitialFaceCommitResult = mutex.withLock {
        try {
        if (!validEmbedding(embedding)) {
            return@withLock commitDenied(InitialFaceEnrollmentDenial.INVALID_EMBEDDING)
        }
        val stored = permits.remove(permit.token)
            ?: return@withLock commitDenied(InitialFaceEnrollmentDenial.PERMIT_ALREADY_USED)
        val now = clockMillis()
        if (now > stored.permit.expiresAt) {
            return@withLock commitDenied(InitialFaceEnrollmentDenial.PERMIT_EXPIRED)
        }
        if (stored.permit != permit || stored.employee.id != permit.employeeLocalId) {
            return@withLock commitDenied(InitialFaceEnrollmentDenial.PERMIT_ALREADY_USED)
        }

        val scope = scopes.current()
            ?: return@withLock commitDenied(InitialFaceEnrollmentDenial.DEVICE_SCOPE_MISSING)
        if (!sameScope(scope, stored.scope)) {
            return@withLock commitDenied(InitialFaceEnrollmentDenial.EMPLOYEE_CHANGED)
        }
        var employee = employees.findByLocalId(permit.employeeLocalId)
            ?: return@withLock commitDenied(InitialFaceEnrollmentDenial.EMPLOYEE_NOT_FOUND)
        validateEmployee(employee, scope, requireSynced = true)?.let {
            return@withLock commitDenied(it)
        }
        if (!sameEmployeeIdentity(employee, stored.employee)) {
            return@withLock commitDenied(InitialFaceEnrollmentDenial.EMPLOYEE_CHANGED)
        }
        if (localFaces.exists(employee.id)) {
            return@withLock commitDenied(InitialFaceEnrollmentDenial.LOCAL_FACE_ALREADY_REGISTERED)
        }

        var validationMode = permit.validationMode
        when (val state = remote.inspect(stored.canonicalEmployeeCode)) {
            InitialFaceRemoteState.Absent -> validationMode = InitialFaceValidationMode.ONLINE_VERIFIED
            InitialFaceRemoteState.Offline -> validationMode = InitialFaceValidationMode.OFFLINE_CACHED
            is InitialFaceRemoteState.Present -> return@withLock commitDenied(
                if (state.valid) InitialFaceEnrollmentDenial.REMOTE_FACE_ALREADY_REGISTERED
                else InitialFaceEnrollmentDenial.REMOTE_FACE_INVALID
            )
            InitialFaceRemoteState.EmployeeNotFound ->
                return@withLock commitDenied(InitialFaceEnrollmentDenial.REMOTE_EMPLOYEE_NOT_FOUND)
            InitialFaceRemoteState.EmployeeInactive ->
                return@withLock commitDenied(InitialFaceEnrollmentDenial.REMOTE_EMPLOYEE_INACTIVE)
            InitialFaceRemoteState.Unavailable ->
                return@withLock commitDenied(InitialFaceEnrollmentDenial.REMOTE_VALIDATION_FAILED)
        }

        employee = employees.findByLocalId(employee.id)
            ?: return@withLock commitDenied(InitialFaceEnrollmentDenial.EMPLOYEE_NOT_FOUND)
        validateEmployee(employee, scope, requireSynced = true)?.let {
            return@withLock commitDenied(it)
        }
        if (!sameEmployeeIdentity(employee, stored.employee)) {
            return@withLock commitDenied(InitialFaceEnrollmentDenial.EMPLOYEE_CHANGED)
        }
        if (localFaces.exists(employee.id)) {
            return@withLock commitDenied(InitialFaceEnrollmentDenial.CONCURRENT_ENROLLMENT)
        }

        val remoteId = employee.remoteId
            ?: return@withLock commitDenied(InitialFaceEnrollmentDenial.EMPLOYEE_NOT_SYNCED)
        val audit = InitialFaceEnrollmentAudit(
            deviceId = scope.deviceId,
            employeeLocalId = employee.id,
            employeeCode = stored.canonicalEmployeeCode,
            remoteId = remoteId,
            companyId = scope.companyId,
            branchId = scope.branchId,
            validationMode = validationMode,
            occurredAt = isoTimestamp(now)
        )
        val persistenceEmbedding = embedding.copyOf()
        val saved = try {
            persistence.insertInitial(
                employee.copy(
                    employeeCode = stored.canonicalEmployeeCode
                ),
                persistenceEmbedding,
                audit
            )
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            return@withLock commitDenied(InitialFaceEnrollmentDenial.STORAGE_FAILED)
        } finally {
            persistenceEmbedding.fill(0f)
        }
        when (saved) {
            is InitialFacePersistenceResult.Saved -> {
                // Room + outbox are already committed. A transient WorkManager scheduling
                // failure must not invite a second enrollment; the existing periodic worker
                // will still pick up the pending outbox.
                runCatching { scheduler.enqueue() }
                InitialFaceCommitResult.Saved(employee.id, saved.outboxId, validationMode)
            }
            InitialFacePersistenceResult.AlreadyExists ->
                commitDenied(InitialFaceEnrollmentDenial.CONCURRENT_ENROLLMENT)
        }
        } finally {
            embedding.fill(0f)
        }
    }

    private fun validateEmployee(
        employee: Employee,
        scope: InitialFaceEnrollmentScope,
        requireSynced: Boolean
    ): InitialFaceEnrollmentDenial? {
        if (!employee.isActive || employee.employmentStatus.lowercase(Locale.ROOT) !in ACTIVE_STATUSES) {
            return InitialFaceEnrollmentDenial.EMPLOYEE_INACTIVE
        }
        if (!employee.jornadaEnabled) return InitialFaceEnrollmentDenial.JOURNEY_DISABLED
        if (scope.deviceId.isBlank() || scope.companyId.isBlank()) {
            return InitialFaceEnrollmentDenial.DEVICE_SCOPE_MISSING
        }
        employee.remoteCompanyId?.let {
            if (!it.equals(scope.companyId, ignoreCase = true)) {
                return InitialFaceEnrollmentDenial.COMPANY_MISMATCH
            }
        }
        if (scope.branchId != null && employee.remoteBranchId != null &&
            !employee.remoteBranchId.equals(scope.branchId, ignoreCase = true)
        ) return InitialFaceEnrollmentDenial.BRANCH_MISMATCH
        if (requireSynced) {
            if (employee.remoteId.isNullOrBlank() || employee.remoteCompanyId.isNullOrBlank() ||
                employee.lastSyncedAt == null || employee.lastSyncedAt <= 0L
            ) return InitialFaceEnrollmentDenial.EMPLOYEE_NOT_SYNCED
            if (scope.branchId != null && employee.remoteBranchId.isNullOrBlank()) {
                return InitialFaceEnrollmentDenial.BRANCH_MISMATCH
            }
        }
        return null
    }

    private fun sameScope(a: InitialFaceEnrollmentScope, b: InitialFaceEnrollmentScope): Boolean =
        a.deviceId.equals(b.deviceId, ignoreCase = true) &&
            a.companyId.equals(b.companyId, ignoreCase = true) &&
            (a.branchId == null && b.branchId == null ||
                a.branchId?.equals(b.branchId.orEmpty(), ignoreCase = true) == true)

    private fun sameEmployeeIdentity(a: Employee, b: Employee): Boolean =
        a.id == b.id && EmployeeCodePolicy.matches(a.employeeCode, b.employeeCode) &&
            a.remoteId == b.remoteId &&
            a.remoteCompanyId.equalsNullable(b.remoteCompanyId) &&
            a.remoteBranchId.equalsNullable(b.remoteBranchId)

    private fun String?.equalsNullable(other: String?): Boolean = when {
        this == null || other == null -> this == other
        else -> equals(other, ignoreCase = true)
    }

    private fun purgeExpiredPermits() {
        val now = clockMillis()
        permits.values.removeAll { now > it.permit.expiresAt }
    }

    private fun validEmbedding(value: FloatArray): Boolean =
        value.size == FaceEmbeddingEngine.EMBEDDING_DIMENSION && value.all(Float::isFinite)

    private fun denied(reason: InitialFaceEnrollmentDenial) = InitialFaceEligibility.Denied(reason)
    private fun commitDenied(reason: InitialFaceEnrollmentDenial) = InitialFaceCommitResult.Denied(reason)

    private data class PermitRecord(
        val permit: InitialFaceEnrollmentPermit,
        val employee: Employee,
        val canonicalEmployeeCode: String,
        val scope: InitialFaceEnrollmentScope
    )

    private companion object {
        val ACTIVE_STATUSES = setOf("activo", "active")
        const val DEFAULT_PERMIT_TTL_MILLIS = 10 * 60 * 1000L
    }
}
