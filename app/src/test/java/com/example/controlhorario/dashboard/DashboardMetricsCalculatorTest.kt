package com.example.controlhorario.dashboard

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class DashboardMetricsCalculatorTest {
    @Test fun `sin iniciar incluye activo habilitado sin fila de jornada`() {
        val metrics = DashboardMetricsCalculator.calculate(
            workDate = "2026-07-13",
            employees = listOf(
                DashboardEmployeeRow("a", active = true, journeyEnabled = true),
                DashboardEmployeeRow("b", active = true, journeyEnabled = true),
            ),
            journeys = listOf(DashboardJourneyRow("b", "EN_CURSO", pendingReview = false)),
            unreadOpenIncidents = 0,
        )

        assertEquals(1, metrics.notStarted)
        assertEquals(1, metrics.inProgress)
        assertEquals(2, metrics.activeEmployees)
    }

    @Test fun `resume estados pendientes e incidencias desde las mismas filas visibles`() {
        val metrics = DashboardMetricsCalculator.calculate(
            workDate = "2026-07-13",
            employees = listOf(
                DashboardEmployeeRow("a", true, true),
                DashboardEmployeeRow("b", true, true),
                DashboardEmployeeRow("c", true, true),
            ),
            journeys = listOf(
                DashboardJourneyRow("a", "EN_PAUSA", pendingReview = true),
                DashboardJourneyRow("b", "FINALIZADA", pendingReview = false),
            ),
            unreadOpenIncidents = 3,
        )

        assertEquals(1, metrics.notStarted)
        assertEquals(1, metrics.paused)
        assertEquals(1, metrics.finished)
        assertEquals(1, metrics.pending)
        assertEquals(3, metrics.incidents)
    }

    @Test fun `sin iniciar excluye inactivos y jornada deshabilitada`() {
        val metrics = DashboardMetricsCalculator.calculate(
            workDate = "2026-07-13",
            employees = listOf(
                DashboardEmployeeRow("inactive", active = false, journeyEnabled = true),
                DashboardEmployeeRow("disabled", active = true, journeyEnabled = false),
            ),
            journeys = emptyList(),
            unreadOpenIncidents = 0,
        )

        assertEquals(0, metrics.notStarted)
        assertEquals(1, metrics.activeEmployees)
    }

    @Test fun `fecha laboral usa zona horaria de empresa`() {
        val clock = Clock.fixed(Instant.parse("2026-07-14T02:30:00Z"), ZoneOffset.UTC)
        assertEquals("2026-07-13", CompanyWorkDate.resolve("America/Santo_Domingo", clock))
        assertEquals("2026-07-14", CompanyWorkDate.resolve("Europe/Madrid", clock))
    }
}
