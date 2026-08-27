package com.example.controlhorario.ui.face

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FaceRegistrationPosePolicyTest {
    @Test
    fun capturesFrontLeftAndOppositeRightOnly() {
        val policy = FaceRegistrationPosePolicy()
        accept(policy, 0f)
        assertEquals(FaceRegistrationPose.LEFT, policy.currentPose)
        accept(policy, 20f)
        assertEquals(FaceRegistrationPose.RIGHT, policy.currentPose)
        accept(policy, -20f)
        assertEquals(3, policy.completedSamples)
    }

    @Test
    fun rejectsSameLateralDirectionForRightPose() {
        val policy = FaceRegistrationPosePolicy()
        accept(policy, 0f)
        accept(policy, 20f)
        val result = policy.observe(20f, 0f, 0f)
        assertTrue(result is FaceRegistrationPosePolicy.PoseObservation.Waiting)
        assertEquals(2, policy.completedSamples)
    }

    private fun accept(policy: FaceRegistrationPosePolicy, y: Float) {
        assertTrue(policy.observe(y, 0f, 0f) is FaceRegistrationPosePolicy.PoseObservation.Accepted)
    }
}
