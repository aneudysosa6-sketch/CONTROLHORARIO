package com.example.controlhorario.fingerprint.external

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FingerprintVerificationPolicyTest {
    @Test
    fun `solo un Match explicito puede autorizar`() {
        assertTrue(
            FingerprintVerificationPolicy.canAuthorize(
                FingerprintVerificationResult.Match(80)
            )
        )
        assertFalse(
            FingerprintVerificationPolicy.canAuthorize(
                FingerprintVerificationResult.NoMatch(80)
            )
        )
        assertFalse(
            FingerprintVerificationPolicy.canAuthorize(
                FingerprintVerificationResult.MissingTemplate
            )
        )
        assertFalse(
            FingerprintVerificationPolicy.canAuthorize(
                FingerprintVerificationResult.CaptureError("Error de captura")
            )
        )
        assertFalse(
            FingerprintVerificationPolicy.canAuthorize(
                FingerprintVerificationResult.DeviceError("Score sin umbral", 80)
            )
        )
    }

    @Test
    fun `un callback de intento anterior queda invalidado`() {
        val gate = FingerprintVerificationAttemptGate()
        val first = gate.begin()
        val second = gate.begin()

        assertFalse(gate.isCurrent(first))
        assertTrue(gate.isCurrent(second))

        gate.invalidate()
        assertFalse(gate.isCurrent(second))
    }

    @Test
    fun `el umbral oficial exige score estrictamente mayor que 100`() {
        val below = FingerprintVerificationPolicy.resultForOfficialScore(99, 100)
        val equal = FingerprintVerificationPolicy.resultForOfficialScore(100, 100)
        val above = FingerprintVerificationPolicy.resultForOfficialScore(101, 100)

        assertFalse(FingerprintVerificationPolicy.canAuthorize(below))
        assertFalse(FingerprintVerificationPolicy.canAuthorize(equal))
        assertTrue(FingerprintVerificationPolicy.canAuthorize(above))
    }

    @Test
    fun `el jar incluido usa referencia y candidato binarios de 512`() {
        assertTrue(FingerprintVerificationPolicy.hasOfficialBinaryTemplateSizes(512, 512))
        assertTrue(
            FingerprintVerificationPolicy.hasValidOfficialBinaryTemplates(
                ByteArray(512) { 1 },
                ByteArray(512) { 1 }
            )
        )
        assertTrue(
            FingerprintVerificationPolicy.canAuthorize(
                FingerprintVerificationPolicy.resultForOfficialScore(101, 100)
            )
        )
        assertFalse(FingerprintVerificationPolicy.hasOfficialBinaryTemplateSizes(512, 256))
        assertFalse(FingerprintVerificationPolicy.hasOfficialBinaryTemplateSizes(256, 256))
        assertFalse(FingerprintVerificationPolicy.hasOfficialBinaryTemplateSizes(0, 512))
    }

    @Test
    fun `plantillas binarias vacias no llegan a MatchTemplate`() {
        val validReference = ByteArray(512) { 1 }
        val emptyCapture = ByteArray(512)
        assertFalse(FingerprintVerificationPolicy.shouldExecuteMatch(validReference, emptyCapture))
        assertFalse(
            FingerprintVerificationPolicy.hasValidOfficialBinaryTemplates(
                ByteArray(512),
                ByteArray(512) { 1 }
            )
        )
        assertFalse(
            FingerprintVerificationPolicy.hasValidOfficialBinaryTemplates(
                ByteArray(512) { 1 },
                ByteArray(512)
            )
        )
    }

    @Test
    fun `plantilla inexistente o corrupta no puede reutilizar un Match anterior`() {
        assertTrue(
            FingerprintVerificationPolicy.canAuthorize(
                FingerprintVerificationPolicy.resultForOfficialScore(101, 100)
            )
        )

        assertFalse(
            FingerprintVerificationPolicy.canAuthorize(
                FingerprintVerificationResult.NoMatch(null)
            )
        )
        assertFalse(FingerprintVerificationPolicy.hasValidOfficialBinaryTemplates(null, ByteArray(512)))
        assertFalse(
            FingerprintVerificationPolicy.hasValidOfficialBinaryTemplates(ByteArray(511), ByteArray(512))
        )
    }
}
