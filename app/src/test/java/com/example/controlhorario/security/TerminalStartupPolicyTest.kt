package com.example.controlhorario.security

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TerminalStartupPolicyTest {
    private val now = 1_000_000L

    @Test
    fun visibleStartupContractContainsNoAuthorizedSuccessOrWelcomeDestination() {
        assertEquals(
            listOf(
                TerminalVisibleDestination.REGISTRATION,
                TerminalVisibleDestination.CAMERA,
                TerminalVisibleDestination.UNAUTHORIZED,
            ),
            TerminalVisibleDestination.values().toList(),
        )
    }

    @Test
    fun accessStatesResolveOnlyToTheNormativeVisibleStartupDestinations() {
        assertEquals(
            TerminalVisibleDestination.REGISTRATION,
            TerminalVisibleDestinationPolicy.resolve(TerminalAccessKind.REGISTRATION),
        )
        assertEquals(
            TerminalVisibleDestination.CAMERA,
            TerminalVisibleDestinationPolicy.resolve(TerminalAccessKind.AUTHORIZED),
        )
        assertEquals(
            TerminalVisibleDestination.UNAUTHORIZED,
            TerminalVisibleDestinationPolicy.resolve(TerminalAccessKind.VALIDATION_REQUIRED),
        )
        assertEquals(
            TerminalVisibleDestination.UNAUTHORIZED,
            TerminalVisibleDestinationPolicy.resolve(TerminalAccessKind.BLOCKED),
        )
    }

    @Test
    fun withoutDeviceCredentialOnlyRegistrationIsAvailable() {
        val access = TerminalStartupPolicy.resolve(
            deviceId = null,
            credentialPresent = false,
            authorization = TerminalAuthorizationSnapshot(),
            nowMillis = now,
        )
        assertEquals(TerminalAccessKind.REGISTRATION, access.kind)
        assertFalse(access.canReEnroll)
    }

    @Test
    fun validCredentialAndOfflineLeaseOpenFacialCameraFlow() {
        val access = TerminalStartupPolicy.resolve(
            deviceId = "terminal-id",
            credentialPresent = true,
            authorization = TerminalAuthorizationSnapshot(
                phase = TerminalAuthorizationPhase.AUTHORIZED,
                validatedAtMillis = now - 1_000,
                credentialExpiresAtMillis = now + 86_400_000,
                offlineLeaseExpiresAtMillis = now + 3_600_000,
            ),
            nowMillis = now,
        )
        assertEquals(TerminalAccessKind.AUTHORIZED, access.kind)
    }

    @Test
    fun restartRetainsDirectTerminalAccessWhilePersistedLeaseIsValid() {
        val persisted = TerminalAuthorizationSnapshot(
            phase = TerminalAuthorizationPhase.AUTHORIZED,
            validatedAtMillis = now - 10_000,
            credentialExpiresAtMillis = now + 86_400_000,
            offlineLeaseExpiresAtMillis = now + 600_000,
        )
        val afterRestart = TerminalStartupPolicy.resolve(
            deviceId = "terminal-id",
            credentialPresent = true,
            authorization = persisted,
            nowMillis = now + 30_000,
        )
        assertEquals(TerminalAccessKind.AUTHORIZED, afterRestart.kind)
    }

    @Test
    fun expiredOfflineLeaseCannotOpenCameraOrRecord() {
        val access = TerminalStartupPolicy.resolve(
            deviceId = "terminal-id",
            credentialPresent = true,
            authorization = TerminalAuthorizationSnapshot(
                phase = TerminalAuthorizationPhase.AUTHORIZED,
                credentialExpiresAtMillis = now + 86_400_000,
                offlineLeaseExpiresAtMillis = now - 1,
            ),
            nowMillis = now,
        )
        assertEquals(TerminalAccessKind.VALIDATION_REQUIRED, access.kind)
    }

    @Test
    fun revokedDeviceIsBlockedAndMayReturnToRegistration() {
        val access = TerminalStartupPolicy.resolve(
            deviceId = "terminal-id",
            credentialPresent = true,
            authorization = TerminalAuthorizationSnapshot(
                phase = TerminalAuthorizationPhase.BLOCKED,
                credentialExpiresAtMillis = now + 86_400_000,
                reasonCode = "DEVICE_REVOKED",
                message = "Revocado",
            ),
            nowMillis = now,
        )
        assertEquals(TerminalAccessKind.BLOCKED, access.kind)
        assertTrue(access.canReEnroll)
    }

    @Test
    fun expiredTerminalCredentialIsBlockedEvenWithFutureLease() {
        val access = TerminalStartupPolicy.resolve(
            deviceId = "terminal-id",
            credentialPresent = true,
            authorization = TerminalAuthorizationSnapshot(
                phase = TerminalAuthorizationPhase.AUTHORIZED,
                credentialExpiresAtMillis = now - 1,
                offlineLeaseExpiresAtMillis = now + 60_000,
            ),
            nowMillis = now,
        )
        assertEquals(TerminalAccessKind.BLOCKED, access.kind)
    }
}