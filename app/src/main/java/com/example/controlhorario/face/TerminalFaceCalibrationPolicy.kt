package com.example.controlhorario.face

data class TerminalFaceCapabilities(
    val showEnrollmentAction: Boolean,
    val enrollmentAllowed: Boolean,
    val identificationAllowed: Boolean,
    val attendanceAllowed: Boolean,
    val showCalibrationRequiredMessage: Boolean,
)

object TerminalFaceCalibrationPolicy {
    /**
     * A nullable margin disables only the optional best-vs-second ambiguity filter.
     * Threshold, liveness, and terminal authorization remain independent requirements.
     */
    @Suppress("UNUSED_PARAMETER")
    fun resolve(pendingFaceCount: Int, faceMatchMargin: Number?): TerminalFaceCapabilities {
        val hasPendingEnrollment = pendingFaceCount > 0
        return TerminalFaceCapabilities(
            showEnrollmentAction = hasPendingEnrollment,
            enrollmentAllowed = hasPendingEnrollment,
            identificationAllowed = true,
            attendanceAllowed = true,
            showCalibrationRequiredMessage = false,
        )
    }
}