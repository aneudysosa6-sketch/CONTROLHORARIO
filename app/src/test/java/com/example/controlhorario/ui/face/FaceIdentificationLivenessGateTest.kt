package com.example.controlhorario.ui.face

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FaceIdentificationLivenessGateTest {
    @Test
    fun livenessFailurePreventsEmbeddingFromReachingMatcherRegardlessOfScore() {
        val gate = FaceIdentificationLivenessGate()

        gate.observe(0.9f, 0.9f, 10L)

        assertFalse(gate.canEmitEmbedding(10L))
    }
    @Test
    fun blocksEmbeddingUntilOpenClosedOpenBlinkCompletes() {
        val gate = FaceIdentificationLivenessGate()

        assertFalse(gate.canEmitEmbedding(0L))
        gate.observe(0.9f, 0.9f, 10L)
        gate.observe(0.1f, 0.1f, 20L)
        assertFalse(gate.canEmitEmbedding(20L))
        gate.observe(0.9f, 0.9f, 30L)

        assertTrue(gate.canEmitEmbedding(30L))
    }

    @Test
    fun resetsAfterFaceLeavesFrame() {
        val gate = verifiedGate()

        gate.onNoFace(100L)
        gate.onNoFace(850L)

        assertFalse(gate.canEmitEmbedding(850L))
    }

    @Test
    fun resetsImmediatelyWhenMultipleFacesAppear() {
        val gate = verifiedGate()

        gate.onMultipleFaces()

        assertFalse(gate.canEmitEmbedding(40L))
    }

    @Test
    fun expiresVerifiedWindow() {
        val gate = verifiedGate()

        assertTrue(gate.canEmitEmbedding(4_999L))
        assertFalse(gate.canEmitEmbedding(5_030L))
    }

    private fun verifiedGate(): FaceIdentificationLivenessGate =
        FaceIdentificationLivenessGate().also { gate ->
            gate.observe(0.9f, 0.9f, 10L)
            gate.observe(0.1f, 0.1f, 20L)
            gate.observe(0.9f, 0.9f, 30L)
        }
}