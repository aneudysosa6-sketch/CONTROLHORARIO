package com.example.controlhorario.ui.face

internal class FaceIdentificationLivenessGate(
    private val resetAfterNoFaceMillis: Long = DEFAULT_NO_FACE_RESET_MILLIS,
    private val validityMillis: Long = DEFAULT_VALIDITY_MILLIS,
) {
    private var policy = FaceRegistrationLivenessPolicy()
    private var noFaceSinceMillis: Long? = null
    private var verifiedAtMillis: Long? = null

    init {
        require(resetAfterNoFaceMillis > 0L)
        require(validityMillis > 0L)
    }

    fun observe(
        leftEyeOpenProbability: Float?,
        rightEyeOpenProbability: Float?,
        nowMillis: Long,
    ): FaceRegistrationLivenessPolicy.Observation {
        noFaceSinceMillis = null
        expireIfNeeded(nowMillis)
        if (policy.isVerified) return FaceRegistrationLivenessPolicy.Observation.Verified

        return policy.observe(leftEyeOpenProbability, rightEyeOpenProbability).also { observation ->
            if (observation == FaceRegistrationLivenessPolicy.Observation.Verified) {
                verifiedAtMillis = nowMillis
            }
        }
    }

    fun canEmitEmbedding(nowMillis: Long): Boolean {
        expireIfNeeded(nowMillis)
        return policy.isVerified && verifiedAtMillis != null
    }

    fun onNoFace(nowMillis: Long) {
        val absentSince = noFaceSinceMillis
        if (absentSince == null) {
            noFaceSinceMillis = nowMillis
        } else if (nowMillis - absentSince >= resetAfterNoFaceMillis) {
            reset()
        }
    }

    fun onMultipleFaces() = reset()

    private fun expireIfNeeded(nowMillis: Long) {
        val verifiedAt = verifiedAtMillis ?: return
        if (nowMillis - verifiedAt >= validityMillis) reset()
    }

    private fun reset() {
        policy = FaceRegistrationLivenessPolicy()
        noFaceSinceMillis = null
        verifiedAtMillis = null
    }

    private companion object {
        const val DEFAULT_NO_FACE_RESET_MILLIS = 750L
        const val DEFAULT_VALIDITY_MILLIS = 5_000L
    }
}