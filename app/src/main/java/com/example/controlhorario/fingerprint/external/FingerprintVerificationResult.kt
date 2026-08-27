package com.example.controlhorario.fingerprint.external

sealed class FingerprintVerificationResult {
    data class Match(val score: Int) : FingerprintVerificationResult()
    data class NoMatch(val score: Int?) : FingerprintVerificationResult()
    data class CaptureError(val message: String) : FingerprintVerificationResult()
    data class DeviceError(val message: String, val score: Int? = null) :
        FingerprintVerificationResult()

    data object MissingTemplate : FingerprintVerificationResult()
}

/**
 * Invalidates stale capture callbacks. Only the currently issued attempt can
 * authorize a journey after a biometric match.
 */
class FingerprintVerificationAttemptGate {
    private var activeAttempt = 0L

    fun begin(): Long = ++activeAttempt

    fun invalidate() {
        ++activeAttempt
    }

    fun isCurrent(attemptId: Long): Boolean = activeAttempt == attemptId
}

object FingerprintVerificationPolicy {
    /** The bundled fplib-reader-v3 demo passes a complete 512-byte candidate to matching. */
    fun hasOfficialBinaryTemplateSizes(referenceSize: Int, capturedSize: Int): Boolean =
        referenceSize == REFERENCE_TEMPLATE_BYTES && capturedSize == CAPTURE_TEMPLATE_BYTES

    fun hasValidOfficialBinaryTemplates(reference: ByteArray?, captured: ByteArray?): Boolean =
        reference != null &&
            captured != null &&
            reference.isNotEmpty() &&
            captured.isNotEmpty() &&
            reference.any { it.toInt() != 0 } &&
            captured.any { it.toInt() != 0 } &&
            hasOfficialBinaryTemplateSizes(reference.size, captured.size)

    fun shouldExecuteMatch(reference: ByteArray?, captured: ByteArray?): Boolean =
        hasValidOfficialBinaryTemplates(reference, captured)

    /** The SDK manual specifies a match only when the score is strictly > threshold. */
    fun resultForOfficialScore(score: Int, threshold: Int): FingerprintVerificationResult =
        if (score > threshold) {
            FingerprintVerificationResult.Match(score)
        } else {
            FingerprintVerificationResult.NoMatch(score)
        }

    fun canAuthorize(result: FingerprintVerificationResult): Boolean =
        result is FingerprintVerificationResult.Match

    private const val REFERENCE_TEMPLATE_BYTES = 512
    private const val CAPTURE_TEMPLATE_BYTES = 512
}
