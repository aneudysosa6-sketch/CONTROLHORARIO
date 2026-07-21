package com.example.controlhorario.ui.punch

import org.junit.Assert.assertEquals
import org.junit.Test

class KioskModePolicyTest {
    @Test fun normalAdministrativeSessionStartsAtPanel() =
        assertEquals(KioskDestination.ADMIN_PANEL, KioskModePolicy.startDestination(false))
    @Test fun activatingKioskStartsWithFaceIdentification() =
        assertEquals(KioskDestination.FACE_IDENTIFICATION, KioskModePolicy.afterActivation())
    @Test fun backRequiresFullAuthentication() =
        assertEquals(KioskDestination.EXIT_AUTH, KioskModePolicy.afterBackPressed())
    @Test fun invalidCredentialsReturnToFaceIdentification() =
        assertEquals(KioskDestination.FACE_IDENTIFICATION, KioskModePolicy.afterAuthentication(false))
    @Test fun validCredentialsOpenAdministrativePanel() =
        assertEquals(KioskDestination.ADMIN_PANEL, KioskModePolicy.afterAuthentication(true))
    @Test fun restartedActiveKioskStartsAtFaceIdentification() =
        assertEquals(KioskDestination.FACE_IDENTIFICATION, KioskModePolicy.startDestination(true))
    @Test fun attendanceAlwaysReturnsToFaceIdentification() =
        assertEquals(KioskDestination.FACE_IDENTIFICATION, KioskModePolicy.afterAttendance())
}
