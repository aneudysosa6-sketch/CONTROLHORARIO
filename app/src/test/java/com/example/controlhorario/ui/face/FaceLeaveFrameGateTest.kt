package com.example.controlhorario.ui.face

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FaceLeaveFrameGateTest {
    @Test
    fun continuousAbsenceRearmsOnlyAfterRequiredDuration() {
        val gate = FaceLeaveFrameGate(requiredAbsenceMillis = 750L)

        assertFalse(gate.observe(facePresent = false, nowMillis = 100L))
        assertFalse(gate.observe(facePresent = false, nowMillis = 849L))
        assertTrue(gate.observe(facePresent = false, nowMillis = 850L))
        assertFalse(gate.observe(facePresent = false, nowMillis = 900L))
    }

    @Test
    fun seeingFaceAgainResetsAbsenceWindow() {
        val gate = FaceLeaveFrameGate(requiredAbsenceMillis = 750L)

        assertFalse(gate.observe(facePresent = false, nowMillis = 0L))
        assertFalse(gate.observe(facePresent = true, nowMillis = 700L))
        assertFalse(gate.observe(facePresent = false, nowMillis = 800L))
        assertFalse(gate.observe(facePresent = false, nowMillis = 1_549L))
        assertTrue(gate.observe(facePresent = false, nowMillis = 1_550L))
    }
}