package com.example.controlhorario.ui.face

import android.util.Log
import com.example.controlhorario.BuildConfig
import kotlin.math.abs

enum class FaceRegistrationPose(val instruction: String) {
    FRONT("Mire directamente a la cámara"),
    LEFT("Gire ligeramente el rostro hacia su izquierda"),
    RIGHT("Gire ligeramente el rostro hacia su derecha"),
    UP("Levante ligeramente el rostro"),
    DOWN("Baje ligeramente el rostro")
}

/**
 * Enforces five materially different registration poses. The first lateral and vertical samples
 * calibrate ML Kit's sign on the physical front camera; their paired pose must be the opposite sign.
 */
class FaceRegistrationPosePolicy {
    private var stableFrames = 0
    private var lateralSign: Int? = null
    private var verticalSign: Int? = null
    var completedSamples: Int = 0
        private set

    val currentPose: FaceRegistrationPose
        get() = FaceRegistrationPose.entries[completedSamples.coerceAtMost(FaceRegistrationPose.entries.lastIndex)]

    fun reset() {
        stableFrames = 0
        lateralSign = null
        verticalSign = null
        completedSamples = 0
    }

    fun observe(y: Float, x: Float, z: Float): PoseObservation {
        val pose = currentPose
        val valid = matches(pose, y, x, z)
        stableFrames = if (valid) stableFrames + 1 else 0
        if (!valid) {
            return PoseObservation.Waiting(pose, guidance(pose, y, x, z)).also {
                debug(pose, y, x, z, valid = false, reason = guidance(pose, y, x, z))
            }
        }
        if (stableFrames < REQUIRED_STABLE_FRAMES) {
            return PoseObservation.Waiting(pose, "Mantenga la pose estable").also {
                debug(pose, y, x, z, valid = true, reason = "stable_frames=$stableFrames/$REQUIRED_STABLE_FRAMES")
            }
        }

        if (pose == FaceRegistrationPose.LEFT) lateralSign = sign(y)
        if (pose == FaceRegistrationPose.UP) verticalSign = sign(x)
        stableFrames = 0
        completedSamples++
        return PoseObservation.Accepted(pose, completedSamples).also {
            debug(pose, y, x, z, valid = true, reason = "sample_accepted=$completedSamples")
        }
    }

    private fun matches(pose: FaceRegistrationPose, y: Float, x: Float, z: Float): Boolean {
        if (abs(z) > MAX_ROLL) return false
        return when (pose) {
            FaceRegistrationPose.FRONT -> abs(y) <= FRONT_LIMIT && abs(x) <= FRONT_LIMIT
            FaceRegistrationPose.LEFT -> lateral(y) && abs(x) <= FRONT_LIMIT
            FaceRegistrationPose.RIGHT -> lateral(y) && sign(y) == -(lateralSign ?: return false)
            FaceRegistrationPose.UP -> vertical(x) && abs(y) <= FRONT_LIMIT
            FaceRegistrationPose.DOWN -> vertical(x) && sign(x) == -(verticalSign ?: return false)
        }
    }

    private fun lateral(value: Float) = abs(value) in TURN_MIN..TURN_MAX
    private fun vertical(value: Float) = abs(value) in TILT_MIN..TILT_MAX
    private fun sign(value: Float): Int = if (value >= 0f) 1 else -1

    private fun guidance(pose: FaceRegistrationPose, y: Float, x: Float, z: Float): String = when {
        abs(z) > MAX_ROLL -> "Mantenga la cabeza recta"
        pose == FaceRegistrationPose.FRONT -> "Regrese al centro"
        pose == FaceRegistrationPose.LEFT && abs(y) < TURN_MIN -> "Gire un poco más"
        pose == FaceRegistrationPose.RIGHT && abs(y) < TURN_MIN -> "Gire un poco más"
        pose == FaceRegistrationPose.UP && abs(x) < TILT_MIN -> "Levante un poco más el rostro"
        pose == FaceRegistrationPose.DOWN && abs(x) < TILT_MIN -> "Baje un poco más el rostro"
        else -> pose.instruction
    }

    private fun debug(pose: FaceRegistrationPose, y: Float, x: Float, z: Float, valid: Boolean, reason: String) {
        if (BuildConfig.DEBUG) {
            runCatching {
                Log.d(
                    "FACE_REG_POSE",
                    "x=$x y=$y z=$z pose=$pose valid=$valid completed=$completedSamples reason=$reason"
                )
            }
        }
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
        private const val TILT_MIN = 10f
        private const val TILT_MAX = 25f
        private const val MAX_ROLL = 15f
    }
}
