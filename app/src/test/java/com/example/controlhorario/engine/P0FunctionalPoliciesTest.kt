package com.example.controlhorario.engine

import java.math.BigDecimal
import java.time.Instant
import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class P0FunctionalPoliciesTest {
    private val general = TerminalConfiguration("company-a", "branch-terminal", TerminalUsageType.GENERAL)

    @Test fun general_accepts_active_employee_from_another_branchBecauseBranchIsNotEligibility() {
        assertTrue(TerminalEligibilityPolicy.isEligible(general, TerminalEmployee("company-a", "dept-x", true)))
    }

    @Test fun general_rejects_inactive_and_otherCompanyEmployees() {
        assertFalse(TerminalEligibilityPolicy.isEligible(general, TerminalEmployee("company-a", "dept-x", false)))
        assertFalse(TerminalEligibilityPolicy.isEligible(general, TerminalEmployee("company-b", "dept-x", true)))
    }

    @Test fun departments_requiresSelectionAndRestrictsEmployees() {
        assertTrue(TerminalEligibilityPolicy.validate(general.copy(usageType = TerminalUsageType.DEPARTMENTS)).isFailure)
        val configured = general.copy(usageType = TerminalUsageType.DEPARTMENTS, departmentIds = setOf("dept-a", "dept-b"))
        assertTrue(TerminalEligibilityPolicy.isEligible(configured, TerminalEmployee("company-a", "dept-b", true)))
        assertFalse(TerminalEligibilityPolicy.isEligible(configured, TerminalEmployee("company-a", "dept-c", true)))
        assertEquals("TERMINAL NO AUTORIZADO PARA SU DEPARTAMENTO", TerminalEligibilityPolicy.REJECTION_MESSAGE)
    }

    @Test fun generalTransitionClearsDepartmentSelection() {
        val normalized = TerminalEligibilityPolicy.validate(general.copy(departmentIds = setOf("stale"))).getOrThrow()
        assertTrue(normalized.departmentIds.isEmpty())
    }

    @Test fun directLicenseUsesCalendarDaysAndSalaryDividedByThirty() {
        val days = DirectLicensePolicy.calculateDays(
            LocalDate.of(2026, 8, 30), LocalDate.of(2026, 9, 1), BigDecimal("30000"), BigDecimal("50"),
        )
        assertEquals(3, days.size)
        assertEquals(BigDecimal("500.00"), days.first().amount)
    }

    @Test(expected = IllegalArgumentException::class)
    fun licenseCannotEditBeforeOriginalStart() {
        DirectLicensePolicy.editableDates(LocalDate.of(2026, 8, 10), LocalDate.of(2026, 8, 9), LocalDate.of(2026, 8, 12))
    }

    @Test fun onlyStartAllowsManualZeroToEightHours() {
        val start = JourneyEvent(JourneyEventType.INICIAR, Instant.parse("2026-08-24T08:00:00Z"))
        assertEquals(480, NoPayResolutionPolicy.resolve(listOf(start), IncompleteJourneyDecision.PAY_DEMONSTRABLE, BigDecimal("8")).recognizedMinutes)
        assertEquals(0, NoPayResolutionPolicy.resolve(listOf(start), IncompleteJourneyDecision.PAY_DEMONSTRABLE, BigDecimal.ZERO).recognizedMinutes)
    }

    @Test(expected = IllegalArgumentException::class)
    fun onlyStartRejectsMoreThanEightManualHours() {
        NoPayResolutionPolicy.resolve(
            listOf(JourneyEvent(JourneyEventType.INICIAR, Instant.parse("2026-08-24T08:00:00Z"))),
            IncompleteJourneyDecision.PAY_DEMONSTRABLE,
            BigDecimal("8.01"),
        )
    }

    @Test fun eventfulIncompleteJourneyUsesOnlyClosedDemonstrableIntervals() {
        val events = listOf(
            JourneyEvent(JourneyEventType.INICIAR, Instant.parse("2026-08-24T08:00:00Z")),
            JourneyEvent(JourneyEventType.PAUSAR, Instant.parse("2026-08-24T10:00:00Z")),
            JourneyEvent(JourneyEventType.REANUDAR, Instant.parse("2026-08-24T10:30:00Z")),
        )
        assertEquals(120, NoPayResolutionPolicy.resolve(events, IncompleteJourneyDecision.PAY_DEMONSTRABLE).recognizedMinutes)
        assertEquals(0, NoPayResolutionPolicy.resolve(events, IncompleteJourneyDecision.NO_PAY).recognizedMinutes)
    }

    @Test fun priorAdjustmentsAreDeltaBasedAndIdempotent() {
        val adjustment = PriorAdjustment("payroll:item:v1", "payroll", "employee", PriorAdjustmentPolicy.delta(BigDecimal("100"), BigDecimal("125")))
        val once = PriorAdjustmentPolicy.appendIdempotently(emptyList(), adjustment)
        assertEquals(once, PriorAdjustmentPolicy.appendIdempotently(once, adjustment))
        assertEquals(BigDecimal("25"), once.single().amount)
    }

    @Test fun monthlyBlacklistUsesStrictThresholdsAndNeverBlocksPunches() {
        assertTrue(MonthlyBlacklistPolicy.reasons(MonthlyAttendanceCounters(2, 5, 5)).isEmpty())
        val reasons = MonthlyBlacklistPolicy.reasons(MonthlyAttendanceCounters(3, 6, 6))
        assertEquals(3, reasons.size)
        assertFalse(MonthlyBlacklistPolicy.blocksAttendance(reasons))
    }

    @Test fun offlineMessageFirstDeliveryWinsAndRemoteTombstoneRemovesContent() {
        val first = OfflineEmployeeMessage("m1", "e1", "one")
        val second = OfflineEmployeeMessage("m2", "e1", "two")
        val delivered = OfflineMessagePolicy.deliverFirst(listOf(first, second), "e1", Instant.parse("2026-08-24T12:00:00Z"))
        assertTrue(delivered.first().deliveredAt != null)
        assertTrue(delivered.last().deliveredAt == null)
        assertTrue(OfflineMessagePolicy.reconcile(delivered, listOf(second)).single().id == "m2")
    }
}
