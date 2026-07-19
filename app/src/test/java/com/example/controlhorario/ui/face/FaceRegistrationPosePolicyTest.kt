package com.example.controlhorario.ui.face

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FaceRegistrationPosePolicyTest {
    @Test
    fun acceptsFrontImmediatelyWithinFifteenDegrees() {
        val policy = FaceRegistrationPosePolicy()
        val accepted = policy.observe(15f, -15f, 15f)
        assertTrue(accepted is FaceRegistrationPosePolicy.PoseObservation.Accepted)
        assertEquals(1, policy.completedSamples)
        assertEquals(FaceRegistrationPose.LEFT, policy.currentPose)
    }

    @Test
    fun oppositeLateralAndVerticalPosesAreRequired() {
        val policy = FaceRegistrationPosePolicy()
        accept(policy, 0f, 0f)       // front
        accept(policy, 20f, 0f)      // first lateral sign
        accept(policy, -20f, 0f)     // opposite lateral sign
        accept(policy, 0f, 15f)      // first vertical sign
        accept(policy, 0f, -15f)     // opposite vertical sign
        assertEquals(5, policy.completedSamples)
    }

    private fun accept(policy: FaceRegistrationPosePolicy, y: Float, x: Float) {
        policy.observe(y, x, 0f)
    }
}
