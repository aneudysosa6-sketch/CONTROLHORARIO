package com.example.controlhorario.ui.face

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FaceRegistrationLivenessPolicyTest {
    @Test
    fun requiresOpenClosedOpenBlinkSequence() {
        val policy = FaceRegistrationLivenessPolicy()
        policy.observe(0.9f, 0.9f)
        policy.observe(0.1f, 0.1f)
        assertFalse(policy.isVerified)
        policy.observe(0.9f, 0.9f)
        assertTrue(policy.isVerified)
    }

    @Test
    fun oneClosedEyeDoesNotPass() {
        val policy = FaceRegistrationLivenessPolicy()
        policy.observe(0.9f, 0.9f)
        policy.observe(0.1f, 0.8f)
        policy.observe(0.9f, 0.9f)
        assertFalse(policy.isVerified)
    }
}
