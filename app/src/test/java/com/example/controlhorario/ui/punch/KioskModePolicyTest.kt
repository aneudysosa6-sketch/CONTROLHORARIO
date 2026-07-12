package com.example.controlhorario.ui.punch

import org.junit.Assert.assertEquals
import org.junit.Test

class KioskModePolicyTest {
    @Test fun normalAdministrativeSessionStartsAtPanel() =
        assertEquals(KioskDestination.ADMIN_PANEL, KioskModePolicy.startDestination(false))
    @Test fun activatingPinModeOpensOnlyPin() =
        assertEquals(KioskDestination.PIN, KioskModePolicy.afterActivation())
    @Test fun backRequiresFullAuthentication() =
        assertEquals(KioskDestination.EXIT_AUTH, KioskModePolicy.afterBackPressed())
    @Test fun invalidCredentialsReturnToPin() =
        assertEquals(KioskDestination.PIN, KioskModePolicy.afterAuthentication(false))
    @Test fun validCredentialsOpenAdministrativePanel() =
        assertEquals(KioskDestination.ADMIN_PANEL, KioskModePolicy.afterAuthentication(true))
    @Test fun restartedActiveKioskStartsAtPin() =
        assertEquals(KioskDestination.PIN, KioskModePolicy.startDestination(true))
    @Test fun attendanceAlwaysReturnsToPin() =
        assertEquals(KioskDestination.PIN, KioskModePolicy.afterAttendance())
}
