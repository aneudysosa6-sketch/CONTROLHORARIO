package com.example.controlhorario.ui.face

import com.example.controlhorario.face.FaceIdentifiedEmployee
import com.example.controlhorario.face.FaceIdentificationResult
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FaceIdentificationSessionPolicyTest {
    @Test fun `same employee requires three consecutive confirmed frames`() {
        val policy = FaceIdentificationSessionPolicy()
        assertTrue(policy.accept(match(7)) is FaceIdentificationSessionPolicy.Decision.Continue)
        assertTrue(policy.accept(match(7)) is FaceIdentificationSessionPolicy.Decision.Continue)
        val decision = policy.accept(match(7))
        assertTrue(decision is FaceIdentificationSessionPolicy.Decision.Confirmed)
        assertEquals(7, (decision as FaceIdentificationSessionPolicy.Decision.Confirmed).result.employee.localEmployeeId)
    }

    @Test fun `different winner resets temporal stability`() {
        val policy = FaceIdentificationSessionPolicy()
        policy.accept(match(7))
        policy.accept(match(7))
        val changed = policy.accept(match(8)) as FaceIdentificationSessionPolicy.Decision.Continue
        assertEquals(1, changed.consecutiveMatches)
    }

    @Test fun `fallback becomes eligible only after several no match frames`() {
        val policy = FaceIdentificationSessionPolicy()
        repeat(FaceIdentificationSessionPolicy.MAX_INCONCLUSIVE_SAMPLES - 1) {
            assertTrue(policy.accept(noMatch()) is FaceIdentificationSessionPolicy.Decision.Continue)
        }
        assertEquals(FaceIdentificationSessionPolicy.Decision.NoMatch, policy.accept(noMatch()))
    }

    @Test fun `close candidates become ambiguous only after controlled attempts`() {
        val policy = FaceIdentificationSessionPolicy()
        val ambiguous = FaceIdentificationResult.MatchAmbiguous(.90f, .86f, .04f)
        repeat(FaceIdentificationSessionPolicy.MAX_INCONCLUSIVE_SAMPLES - 1) {
            assertTrue(policy.accept(ambiguous) is FaceIdentificationSessionPolicy.Decision.Continue)
        }
        assertEquals(FaceIdentificationSessionPolicy.Decision.Ambiguous, policy.accept(ambiguous))
    }

    private fun match(employeeId: Int) = FaceIdentificationResult.MatchConfirmed(
        employee = FaceIdentifiedEmployee(employeeId, employeeId.toString(), "Employee $employeeId"),
        topScore = .90f,
        secondScore = .40f,
        scoreMargin = .50f,
    )

    private fun noMatch() = FaceIdentificationResult.NoMatch(.50f, .40f, .10f)
}
