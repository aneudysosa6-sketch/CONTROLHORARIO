package com.example.controlhorario.ui.face

import android.util.Log
import com.example.controlhorario.BuildConfig
import kotlin.math.abs

enum class FaceRegistrationPose(val instruction: String) {
    FRONT("Mire directamente a la cámara"),
    LEFT("Gire ligeramente el rostro hacia su izquierda"),
    RIGHT("Gire ligeramente el rostro hacia su derecha"),
}

class FaceRegistrationPosePolicy {
    private var stableFrames = 0
    private var lateralSign: Int? = null
    var completedSamples: Int = 0
        private set

    val currentPose: FaceRegistrationPose
        get() = FaceRegistrationPose.entries[completedSamples.coerceAtMost(FaceRegistrationPose.entries.lastIndex)]

    fun reset() {
        stableFrames = 0
        lateralSign = null
        completedSamples = 0
    }

    fun observe(y: Float, x: Float, z: Float): PoseObservation {
        val pose = currentPose
        val valid = matches(pose, y, x, z)
        stableFrames = if (valid) stableFrames + 1 else 0
        if (!valid) return PoseObservation.Waiting(pose, guidance(pose, y, x, z))
        if (stableFrames < REQUIRED_STABLE_FRAMES) return PoseObservation.Waiting(pose, "Mantenga la pose estable")
        if (pose == FaceRegistrationPose.LEFT) lateralSign = sign(y)
        stableFrames = 0
        completedSamples++
        debug(pose, y, x, z)
        return PoseObservation.Accepted(pose, completedSamples)
    }

    private fun matches(pose: FaceRegistrationPose, y: Float, x: Float, z: Float): Boolean {
        if (abs(z) > MAX_ROLL || abs(x) > FRONT_LIMIT) return false
        return when (pose) {
            FaceRegistrationPose.FRONT -> abs(y) <= FRONT_LIMIT
            FaceRegistrationPose.LEFT -> lateral(y)
            FaceRegistrationPose.RIGHT -> lateral(y) && sign(y) == -(lateralSign ?: return false)
        }
    }

    private fun lateral(value: Float) = abs(value) in TURN_MIN..TURN_MAX
    private fun sign(value: Float): Int = if (value >= 0f) 1 else -1

    private fun guidance(pose: FaceRegistrationPose, y: Float, x: Float, z: Float): String = when {
        abs(z) > MAX_ROLL -> "Mantenga la cabeza recta"
        abs(x) > FRONT_LIMIT -> "Mantenga el rostro nivelado"
        pose == FaceRegistrationPose.FRONT -> "Regrese al centro"
        abs(y) < TURN_MIN -> "Gire un poco más"
        else -> pose.instruction
    }

    private fun debug(pose: FaceRegistrationPose, y: Float, x: Float, z: Float) {
        if (BuildConfig.DEBUG) runCatching { Log.d("FACE_REG_POSE", "pose=$pose accepted=true completed=$completedSamples x=$x y=$y z=$z") }
    }

    sealed interface PoseObservation {
        data class Waiting(val pose: FaceRegistrationPose, val guidance: String) : PoseObservation
        data class Accepted(val pose: FaceRegistrationPose, val completedSamples: Int) : PoseObservation
    }

    companion object {
        const val REQUIRED_STABLE_FRAMES = 1
        private const val FRONT_LIMIT = 15f
        private const val TURN_MIN = 15f
        private const val TURN_MAX = 35f
        private const val MAX_ROLL = 15f
    }
}

class FaceRegistrationLivenessPolicy {
    private var openSeen = false
    private var closedSeen = false
    var isVerified: Boolean = false
        private set

    fun observe(leftEye: Float?, rightEye: Float?): Observation {
        if (isVerified) return Observation.Verified
        if (leftEye == null || rightEye == null) return Observation.Waiting("Mire al frente y parpadee")
        val bothOpen = leftEye >= OPEN_THRESHOLD && rightEye >= OPEN_THRESHOLD
        val bothClosed = leftEye <= CLOSED_THRESHOLD && rightEye <= CLOSED_THRESHOLD
        when {
            bothOpen && closedSeen -> {
                isVerified = true
                return Observation.Verified
            }
            bothOpen -> openSeen = true
            bothClosed && openSeen -> closedSeen = true
        }
        return Observation.Waiting(if (openSeen) "Parpadee una vez" else "Abra los ojos y mire al frente")
    }

    sealed interface Observation {
        data class Waiting(val guidance: String) : Observation
        data object Verified : Observation
    }

    private companion object {
        const val OPEN_THRESHOLD = 0.70f
        const val CLOSED_THRESHOLD = 0.30f
    }
}
