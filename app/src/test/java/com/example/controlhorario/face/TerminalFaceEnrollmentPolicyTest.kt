package com.example.controlhorario.face

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TerminalFaceEnrollmentPolicyTest {
    @Test
    fun buttonIsAbsentAtZeroAndUsesCorrectPluralization() {
        assertFalse(PendingFaceEnrollmentButtonPolicy.visible(0))
        assertTrue(PendingFaceEnrollmentButtonPolicy.visible(1))
        assertEquals("Registrar rostro nuevo (1 pendiente)", PendingFaceEnrollmentButtonPolicy.label(1))
        assertEquals("Registrar rostro nuevo (5 pendientes)", PendingFaceEnrollmentButtonPolicy.label(5))
    }

    @Test
    fun nullMarginWithNoPendingEmployeeAllowsIdentificationWithoutEnrollmentButton() {
        val capabilities = TerminalFaceCalibrationPolicy.resolve(
            pendingFaceCount = 0,
            faceMatchMargin = null,
        )

        assertFalse(capabilities.showEnrollmentAction)
        assertFalse(capabilities.enrollmentAllowed)
        assertTrue(capabilities.identificationAllowed)
        assertTrue(capabilities.attendanceAllowed)
        assertFalse(capabilities.showCalibrationRequiredMessage)
    }

    @Test
    fun nullMarginWithPendingEmployeesAllowsEnrollmentIdentificationAndAttendance() {
        val capabilities = TerminalFaceCalibrationPolicy.resolve(
            pendingFaceCount = 2,
            faceMatchMargin = null,
        )

        assertTrue(capabilities.showEnrollmentAction)
        assertTrue(capabilities.enrollmentAllowed)
        assertTrue(capabilities.identificationAllowed)
        assertTrue(capabilities.attendanceAllowed)
        assertFalse(capabilities.showCalibrationRequiredMessage)
    }

    @Test
    fun calibratedMarginEnablesNormalIdentificationAndAttendance() {
        val capabilities = TerminalFaceCalibrationPolicy.resolve(
            pendingFaceCount = 0,
            faceMatchMargin = 0.10,
        )

        assertTrue(capabilities.identificationAllowed)
        assertTrue(capabilities.attendanceAllowed)
        assertFalse(capabilities.showCalibrationRequiredMessage)
    }

    @Test
    fun normativeErrorsDoNotRevealAnotherEmployee() {
        assertEquals("SUPERVISOR DEBE ASIGNAR HORARIO Y DÍA LIBRE", TerminalFaceEnrollmentMessages.forCode("SCHEDULE_DAYOFF_REQUIRED"))
        assertEquals("Rostro ya registrado en otro empleado", TerminalFaceEnrollmentMessages.forCode("FACE_DUPLICATE"))
        assertEquals("Sin conexión. Inténtalo nuevamente cuando vuelva Internet.", TerminalFaceEnrollmentMessages.forCode("NETWORK_UNAVAILABLE"))
    }
}
