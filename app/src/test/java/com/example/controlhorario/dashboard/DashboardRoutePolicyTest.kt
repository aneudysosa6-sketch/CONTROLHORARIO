package com.example.controlhorario.dashboard

import com.example.controlhorario.auth.AuthenticatedPrincipal
import com.example.controlhorario.auth.AuthorizationPolicy
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DashboardRoutePolicyTest {
    @Test
    fun `resolver maps only canonical server roles`() {
        assertEquals(DashboardDestination.ADMIN, DashboardResolver.resolve("ADMIN"))
        assertEquals(DashboardDestination.SUPERVISOR, DashboardResolver.resolve("SUPERVISOR"))
        assertEquals(DashboardDestination.EMPLOYEE, DashboardResolver.resolve("EMPLEADO"))
        assertEquals(DashboardDestination.RRHH, DashboardResolver.resolve("RRHH"))
        assertEquals(DashboardDestination.NOMINA, DashboardResolver.resolve("NOMINA"))
        assertEquals(DashboardDestination.AUDITOR, DashboardResolver.resolve("AUDITOR"))
    }

    @Test
    fun `unknown or noncanonical role never receives a fallback dashboard`() {
        assertEquals(DashboardDestination.UNKNOWN, DashboardResolver.resolve(""))
        assertEquals(DashboardDestination.UNKNOWN, DashboardResolver.resolve("sup"))
        assertEquals(DashboardDestination.UNKNOWN, DashboardResolver.resolve("other"))
    }

    @Test
    fun `permissions authorize after destination resolution`() {
        val supervisor = principal("SUPERVISOR", setOf("supervisor.dashboard"))
        val deniedSupervisor = principal("SUPERVISOR", setOf("portal.ver_dashboard"))

        assertTrue(
            AuthorizationPolicy.canOpenDashboard(
                supervisor,
                DashboardResolver.resolve(supervisor.roleCode),
            ),
        )
        assertFalse(
            AuthorizationPolicy.canOpenDashboard(
                deniedSupervisor,
                DashboardResolver.resolve(deniedSupervisor.roleCode),
            ),
        )
    }

    @Test
    fun `empty permissions always deny a valid role`() {
        val admin = principal("ADMIN", emptySet())
        assertFalse(
            AuthorizationPolicy.canOpenDashboard(
                admin,
                DashboardResolver.resolve(admin.roleCode),
            ),
        )
    }

    private fun principal(
        roleCode: String,
        permissions: Set<String>,
    ) = AuthenticatedPrincipal(
        authUid = "auth-uid",
        profileId = "profile-id",
        employeeId = null,
        email = "user@example.com",
        companyId = "company-id",
        roleId = "role-id",
        roleCodeOriginal = roleCode.lowercase(),
        roleCode = roleCode,
        roleName = roleCode,
        fullName = "Usuario",
        active = true,
        permissionCodes = permissions,
        primaryDepartmentId = null,
        additionalDepartmentIds = emptySet(),
        branchIds = emptySet(),
        authorizationVersion = "v1",
        accessToken = "access-token",
        refreshToken = "refresh-token",
        accessTokenExpiresAt = Long.MAX_VALUE,
    )
}
