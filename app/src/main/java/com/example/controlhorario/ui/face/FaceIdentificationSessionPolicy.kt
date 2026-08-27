package com.example.controlhorario.ui.face

import com.example.controlhorario.face.FaceIdentificationResult

/**
 * Adds temporal stability to the per-frame 1:N matcher. A single good frame is not
 * sufficient to identify an employee.
 */
class FaceIdentificationSessionPolicy(
    private val requiredConsecutiveMatches: Int = REQUIRED_CONSECUTIVE_MATCHES,
    private val maxInconclusiveSamples: Int = MAX_INCONCLUSIVE_SAMPLES,
) {
    private var candidateEmployeeId: Int? = null
    private var consecutiveMatches = 0
    private var inconclusiveSamples = 0

    fun accept(result: FaceIdentificationResult): Decision = when (result) {
        is FaceIdentificationResult.MatchConfirmed -> {
            val employeeId = result.employee.localEmployeeId
            consecutiveMatches = if (candidateEmployeeId == employeeId) consecutiveMatches + 1 else 1
            candidateEmployeeId = employeeId
            inconclusiveSamples = 0
            if (consecutiveMatches >= requiredConsecutiveMatches) {
                Decision.Confirmed(result)
            } else {
                Decision.Continue(consecutiveMatches, requiredConsecutiveMatches)
            }
        }

        is FaceIdentificationResult.MatchAmbiguous -> {
            resetCandidate()
            inconclusiveSamples++
            if (inconclusiveSamples >= maxInconclusiveSamples) Decision.Ambiguous else Decision.Continue(0, requiredConsecutiveMatches)
        }

        is FaceIdentificationResult.NoMatch -> {
            resetCandidate()
            inconclusiveSamples++
            if (inconclusiveSamples >= maxInconclusiveSamples) Decision.NoMatch else Decision.Continue(0, requiredConsecutiveMatches)
        }

        FaceIdentificationResult.NoTemplates -> Decision.NoTemplates
        is FaceIdentificationResult.Error -> Decision.Error(result)
    }

    fun reset() {
        resetCandidate()
        inconclusiveSamples = 0
    }

    private fun resetCandidate() {
        candidateEmployeeId = null
        consecutiveMatches = 0
    }

    sealed interface Decision {
        data class Continue(val consecutiveMatches: Int, val requiredMatches: Int) : Decision
        data class Confirmed(val result: FaceIdentificationResult.MatchConfirmed) : Decision
        data object Ambiguous : Decision
        data object NoMatch : Decision
        data object NoTemplates : Decision
        data class Error(val result: FaceIdentificationResult.Error) : Decision
    }

    companion object {
        const val REQUIRED_CONSECUTIVE_MATCHES = 3
        const val MAX_INCONCLUSIVE_SAMPLES = 5
    }
}
