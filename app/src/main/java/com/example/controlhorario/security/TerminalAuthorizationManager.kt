package com.example.controlhorario.security

import android.content.Context
import java.time.Instant
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class TerminalAuthorizationPhase {
    UNKNOWN,
    PENDING_VALIDATION,
    AUTHORIZED,
    BLOCKED,
}

data class TerminalAuthorizationSnapshot(
    val phase: TerminalAuthorizationPhase = TerminalAuthorizationPhase.UNKNOWN,
    val validatedAtMillis: Long = 0L,
    val credentialExpiresAtMillis: Long = 0L,
    val offlineLeaseExpiresAtMillis: Long = 0L,
    val reasonCode: String = "",
    val message: String = "",
)

enum class TerminalAccessKind {
    REGISTRATION,
    VALIDATION_REQUIRED,
    AUTHORIZED,
    BLOCKED,
}

/**
 * Contrato normativo de arranque visible de Android.
 * No se debe agregar un destino intermedio para confirmar que el Terminal fue autorizado.
 */
enum class TerminalVisibleDestination {
    REGISTRATION,
    CAMERA,
    UNAUTHORIZED,
}

object TerminalVisibleDestinationPolicy {
    fun resolve(accessKind: TerminalAccessKind): TerminalVisibleDestination = when (accessKind) {
        TerminalAccessKind.REGISTRATION -> TerminalVisibleDestination.REGISTRATION
        TerminalAccessKind.AUTHORIZED -> TerminalVisibleDestination.CAMERA
        TerminalAccessKind.VALIDATION_REQUIRED,
        TerminalAccessKind.BLOCKED -> TerminalVisibleDestination.UNAUTHORIZED
    }
}

data class TerminalAccess(
    val kind: TerminalAccessKind,
    val message: String = "",
    val canReEnroll: Boolean = false,
)

object TerminalStartupPolicy {
    fun resolve(
        deviceId: String?,
        credentialPresent: Boolean,
        authorization: TerminalAuthorizationSnapshot,
        nowMillis: Long,
    ): TerminalAccess {
        if (deviceId.isNullOrBlank() || !credentialPresent) {
            return TerminalAccess(TerminalAccessKind.REGISTRATION)
        }
        if (authorization.phase == TerminalAuthorizationPhase.BLOCKED) {
            return TerminalAccess(
                kind = TerminalAccessKind.BLOCKED,
                message = authorization.message.ifBlank { "La credencial del Terminal no es válida." },
                canReEnroll = true,
            )
        }
        if (authorization.credentialExpiresAtMillis in 1..nowMillis) {
            return TerminalAccess(
                kind = TerminalAccessKind.BLOCKED,
                message = "La credencial del Terminal venció.",
                canReEnroll = true,
            )
        }
        if (
            authorization.phase == TerminalAuthorizationPhase.AUTHORIZED &&
            authorization.offlineLeaseExpiresAtMillis > nowMillis
        ) {
            return TerminalAccess(TerminalAccessKind.AUTHORIZED)
        }
        return TerminalAccess(
            kind = TerminalAccessKind.VALIDATION_REQUIRED,
            message = "La autorización offline venció. Conecte el Terminal para validarlo.",
        )
    }
}

object TerminalAuthorizationManager {
    private const val PREFERENCES = "terminal_authorization_v1"
    private const val KEY_PHASE = "phase"
    private const val KEY_VALIDATED_AT = "validated_at"
    private const val KEY_CREDENTIAL_EXPIRES_AT = "credential_expires_at"
    private const val KEY_OFFLINE_LEASE_EXPIRES_AT = "offline_lease_expires_at"
    private const val KEY_REASON = "reason"
    private const val KEY_MESSAGE = "message"
    private const val FALLBACK_OFFLINE_LEASE_MILLIS = 24L * 60L * 60L * 1_000L

    private var appContext: Context? = null
    private val mutableState = MutableStateFlow(TerminalAuthorizationSnapshot())
    val state: StateFlow<TerminalAuthorizationSnapshot> = mutableState.asStateFlow()

    @Synchronized
    fun init(context: Context) {
        appContext = context.applicationContext
        mutableState.value = read()
    }

    fun markPendingValidation(credentialExpiresAt: String) {
        persist(
            TerminalAuthorizationSnapshot(
                phase = TerminalAuthorizationPhase.PENDING_VALIDATION,
                credentialExpiresAtMillis = instantMillis(credentialExpiresAt),
            ),
        )
    }

    fun recordAuthorized(
        validatedAt: String,
        credentialExpiresAt: String,
        offlineLeaseExpiresAt: String,
    ) {
        val validated = instantMillis(validatedAt)
        val credentialExpiry = instantMillis(credentialExpiresAt)
        val leaseExpiry = instantMillis(offlineLeaseExpiresAt)
        require(validated > 0L && credentialExpiry > validated && leaseExpiry > validated) {
            "INVALID_TERMINAL_AUTHORIZATION"
        }
        persist(
            TerminalAuthorizationSnapshot(
                phase = TerminalAuthorizationPhase.AUTHORIZED,
                validatedAtMillis = validated,
                credentialExpiresAtMillis = credentialExpiry,
                offlineLeaseExpiresAtMillis = minOf(credentialExpiry, leaseExpiry),
            ),
        )
    }

    fun recordAuthorizedWithCredentialLease(validatedAt: String, credentialExpiresAt: String) {
        val validatedAtMillis = instantMillis(validatedAt)
        val leaseExpiresAtMillis = minOf(
            instantMillis(credentialExpiresAt),
            validatedAtMillis + FALLBACK_OFFLINE_LEASE_MILLIS,
        )
        recordAuthorized(
            validatedAt,
            credentialExpiresAt,
            java.time.Instant.ofEpochMilli(leaseExpiresAtMillis).toString(),
        )
    }

    fun block(reasonCode: String, message: String = blockedMessage(reasonCode)) {
        val current = mutableState.value
        persist(
            current.copy(
                phase = TerminalAuthorizationPhase.BLOCKED,
                reasonCode = reasonCode,
                message = message,
                offlineLeaseExpiresAtMillis = 0L,
            ),
        )
    }

    fun access(identity: DeviceIdentityManager, nowMillis: Long = System.currentTimeMillis()): TerminalAccess =
        TerminalStartupPolicy.resolve(
            deviceId = identity.deviceId,
            credentialPresent = runCatching { !identity.credential().isNullOrBlank() }.getOrDefault(false),
            authorization = mutableState.value,
            nowMillis = nowMillis,
        )

    fun canRecord(identity: DeviceIdentityManager, nowMillis: Long = System.currentTimeMillis()): Boolean =
        access(identity, nowMillis).kind == TerminalAccessKind.AUTHORIZED

    fun refreshClock() {
        mutableState.value = mutableState.value.copy()
    }

    fun clear() {
        appContext?.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)?.edit()?.clear()?.commit()
        mutableState.value = TerminalAuthorizationSnapshot()
    }

    private fun read(): TerminalAuthorizationSnapshot {
        val preferences = appContext?.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            ?: return TerminalAuthorizationSnapshot()
        val phase = runCatching {
            TerminalAuthorizationPhase.valueOf(
                preferences.getString(KEY_PHASE, TerminalAuthorizationPhase.UNKNOWN.name).orEmpty(),
            )
        }.getOrDefault(TerminalAuthorizationPhase.UNKNOWN)
        return TerminalAuthorizationSnapshot(
            phase = phase,
            validatedAtMillis = preferences.getLong(KEY_VALIDATED_AT, 0L),
            credentialExpiresAtMillis = preferences.getLong(KEY_CREDENTIAL_EXPIRES_AT, 0L),
            offlineLeaseExpiresAtMillis = preferences.getLong(KEY_OFFLINE_LEASE_EXPIRES_AT, 0L),
            reasonCode = preferences.getString(KEY_REASON, "").orEmpty(),
            message = preferences.getString(KEY_MESSAGE, "").orEmpty(),
        )
    }

    private fun persist(value: TerminalAuthorizationSnapshot) {
        appContext?.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)?.edit()
            ?.putString(KEY_PHASE, value.phase.name)
            ?.putLong(KEY_VALIDATED_AT, value.validatedAtMillis)
            ?.putLong(KEY_CREDENTIAL_EXPIRES_AT, value.credentialExpiresAtMillis)
            ?.putLong(KEY_OFFLINE_LEASE_EXPIRES_AT, value.offlineLeaseExpiresAtMillis)
            ?.putString(KEY_REASON, value.reasonCode)
            ?.putString(KEY_MESSAGE, value.message)
            ?.commit()
        mutableState.value = value
    }

    private fun instantMillis(value: String): Long =
        runCatching { Instant.parse(value).toEpochMilli() }.getOrDefault(0L)

    private fun blockedMessage(reasonCode: String): String = when (reasonCode) {
        "DEVICE_REVOKED" -> "Este Terminal fue revocado por la administración Web."
        "DEVICE_CREDENTIAL_INVALID", "INVALID_DEVICE_CREDENTIAL" ->
            "La credencial del Terminal no existe, venció o ya no es válida."
        "DEVICE_COMPANY_MISMATCH" -> "La credencial pertenece a otra empresa."
        else -> "El Terminal no está autorizado para registrar jornadas."
    }
}