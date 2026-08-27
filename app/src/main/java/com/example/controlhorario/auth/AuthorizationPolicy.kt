package com.example.controlhorario.auth

import com.example.controlhorario.dashboard.DashboardDestination

enum class AppCapability {
    DASHBOARD,
    EMPLOYEES,
    USERS,
    ATTENDANCE,
    INCIDENTS,
    PAYROLL,
    SETTINGS,
    EMPLOYEE_REQUESTS,
}

object AuthorizationPolicy {
    fun has(principal: AuthenticatedPrincipal, permissionCode: String): Boolean =
        permissionCode in principal.permissionCodes

    fun hasAny(principal: AuthenticatedPrincipal, vararg permissionCodes: String): Boolean =
        permissionCodes.any(principal.permissionCodes::contains)

    fun can(principal: AuthenticatedPrincipal, capability: AppCapability): Boolean {
        val codes = principal.permissionCodes
        if (codes.isEmpty()) return false
        return when (capability) {
            AppCapability.DASHBOARD ->
                "portal.ver_dashboard" in codes || "supervisor.dashboard" in codes
            AppCapability.EMPLOYEES -> codes.any { it.startsWith("empleados.") }
            AppCapability.USERS -> codes.any {
                it in setOf(
                    "usuarios.view",
                    "usuarios.create",
                    "usuarios.edit",
                    "usuarios.administrar",
                    "permisos.administrar",
                    "roles.administrar",
                )
            }
            AppCapability.ATTENDANCE -> codes.any { it.startsWith("jornadas.") }
            AppCapability.INCIDENTS -> codes.any { it.startsWith("incidencias.") }
            AppCapability.PAYROLL -> codes.any { it.startsWith("nomina.") }
            AppCapability.SETTINGS -> codes.any { it.startsWith("configuracion.") }
            AppCapability.EMPLOYEE_REQUESTS ->
                codes.any { it.startsWith("permisos_empleados.") } ||
                    codes.any { it.startsWith("jornadas.") }
        }
    }

    fun canOpenDashboard(
        principal: AuthenticatedPrincipal,
        destination: DashboardDestination,
    ): Boolean = when (destination) {
        DashboardDestination.SUPERVISOR -> has(principal, "supervisor.dashboard")
        DashboardDestination.EMPLOYEE ->
            principal.permissionCodes.any { it.startsWith("empleado.") }
        DashboardDestination.ADMIN,
        DashboardDestination.RRHH,
        DashboardDestination.NOMINA,
        DashboardDestination.AUDITOR -> has(principal, "portal.ver_dashboard")
        DashboardDestination.UNKNOWN -> false
    }
}
