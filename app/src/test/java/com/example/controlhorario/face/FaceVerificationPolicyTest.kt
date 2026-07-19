package com.example.controlhorario.face

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FaceVerificationPolicyTest {
    @Test
    fun acceptsOnlyAfterThreeConsecutiveMatches() {
        val policy = FaceVerificationPolicy(threshold = 0.75f)
        assertEquals(FaceVerificationPolicy.Decision.Continue, policy.accept(0.80f))
        assertEquals(FaceVerificationPolicy.Decision.Continue, policy.accept(0.81f))
        assertEquals(FaceVerificationPolicy.Decision.Accepted, policy.accept(0.82f))
    }

    @Test
    fun lowScoreBreaksTheConsecutiveMatchSequence() {
        val policy = FaceVerificationPolicy(threshold = 0.75f)
        policy.accept(0.80f)
        policy.accept(0.81f)
        policy.accept(0.70f)
        assertEquals(FaceVerificationPolicy.Decision.Continue, policy.accept(0.82f))
        assertEquals(1, policy.consecutive)
    }

    @Test
    fun returnsToCodeAfterThreeFailedAttempts() {
        val policy = FaceVerificationPolicy(threshold = 0.75f)
        repeat(2) {
            repeat(4) { policy.accept(0.1f) }
            assertEquals(FaceVerificationPolicy.Decision.Retry, policy.accept(0.1f))
        }
        repeat(4) { policy.accept(0.1f) }
        assertEquals(FaceVerificationPolicy.Decision.ReturnToCode, policy.accept(0.1f))
        assertTrue(policy.failedAttempts >= 3)
    }
}
