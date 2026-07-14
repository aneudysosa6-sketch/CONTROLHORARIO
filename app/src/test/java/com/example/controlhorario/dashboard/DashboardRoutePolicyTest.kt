package com.example.controlhorario.dashboard

import com.example.controlhorario.auth.AuthFlowException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DashboardRoutePolicyTest {
    @Test fun `admin abre Dashboard administrador`() {
        assertEquals(DashboardDestination.ADMIN, DashboardRoutePolicy.destination("admin", setOf("portal.ver_dashboard"), false))
    }

    @Test fun `supervisor con permiso RC3 abre Dashboard supervisor`() {
        assertEquals(DashboardDestination.SUPERVISOR_RC3, DashboardRoutePolicy.destination("supervisor", setOf("supervisor.dashboard"), false))
    }

    @Test fun `supervisor sin RC3 usa fallback compatible`() {
        assertEquals(DashboardDestination.SUPERVISOR_FALLBACK, DashboardRoutePolicy.destination("supervisor", setOf("portal.ver_dashboard"), false))
        assertTrue(DashboardRoutePolicy.shouldFallbackFromRc3("PGRST202"))
    }

    @Test fun `loading no redirige prematuramente`() {
        assertEquals(DashboardDestination.LOADING, DashboardRoutePolicy.destination(null, emptySet(), true))
    }

    @Test fun `employee abre su portal privado`() {
        assertEquals(DashboardDestination.EMPLOYEE, DashboardRoutePolicy.destination("employee", setOf("empleado.perfil_ver"), false))
    }

    @Test fun `error PostgREST conserva codigo details y hint visibles`() {
        val error = AuthFlowException("dashboard", "PGRST200", "Join ambiguo", "No relationship", "Use una FK explícita")
        val visible = error.visibleMessage()
        assertTrue(visible.contains("PGRST200"))
        assertTrue(visible.contains("No relationship"))
        assertTrue(visible.contains("Use una FK explícita"))
    }
}
