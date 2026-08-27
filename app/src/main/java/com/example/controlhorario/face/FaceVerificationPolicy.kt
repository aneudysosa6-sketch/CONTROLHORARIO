package com.example.controlhorario.face

class FaceVerificationPolicy(private val threshold: Float = FaceEmbeddingEngine.COSINE_THRESHOLD) {
    var samples = 0; private set
    var consecutive = 0; private set
    var failedAttempts = 0; private set
    fun accept(score: Float): Decision {
        samples++
        consecutive = if (score >= threshold) consecutive + 1 else 0
        if (consecutive >= 3) return Decision.Accepted
        if (samples >= 5) { failedAttempts++; samples = 0; consecutive = 0; return if (failedAttempts >= 3) Decision.ReturnToCode else Decision.Retry }
        return Decision.Continue
    }
    sealed interface Decision { data object Continue: Decision; data object Accepted: Decision; data object Retry: Decision; data object ReturnToCode: Decision }
}
