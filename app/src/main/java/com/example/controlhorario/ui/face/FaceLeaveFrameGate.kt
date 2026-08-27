package com.example.controlhorario.ui.face

/** Rearms face identification only after a continuous period with no face in frame. */
internal class FaceLeaveFrameGate(
    private val requiredAbsenceMillis: Long = REQUIRED_ABSENCE_MILLIS,
) {
    private var absenceStartedAt: Long? = null
    private var confirmed = false

    init {
        require(requiredAbsenceMillis > 0L) { "invalid_required_absence" }
    }

    @Synchronized
    fun observe(facePresent: Boolean, nowMillis: Long): Boolean {
        if (confirmed) return false
        if (facePresent) {
            absenceStartedAt = null
            return false
        }

        val startedAt = absenceStartedAt
        if (startedAt == null) {
            absenceStartedAt = nowMillis
            return false
        }
        if ((nowMillis - startedAt).coerceAtLeast(0L) < requiredAbsenceMillis) {
            return false
        }

        confirmed = true
        return true
    }

    private companion object {
        const val REQUIRED_ABSENCE_MILLIS = 750L
    }
}