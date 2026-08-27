package com.example.controlhorario.model

import java.util.Locale

data class EmployeeDeviceScope(
    val companyId: String,
    val branchId: String?
)

fun interface EmployeeDeviceScopeSource {
    suspend fun current(): EmployeeDeviceScope?
}

/** Canonical employment guard shared by identification and attendance flows. */
object EmployeeEmploymentPolicy {
    private val activeStatuses = setOf("activo", "active")

    fun isEmploymentActive(employee: Employee): Boolean =
        employee.isActive && employee.employmentStatus.trim().lowercase(Locale.ROOT) in activeStatuses

    fun canRegisterAttendance(employee: Employee): Boolean =
        isEmploymentActive(employee) && employee.jornadaEnabled
}

/** Shared guard for every public employee-identification path. */
object EmployeeDeviceScopePolicy {
    fun allows(employee: Employee, scope: EmployeeDeviceScope): Boolean {
        if (scope.companyId.isBlank() || employee.remoteId.isNullOrBlank()) return false
        if (!EmployeeEmploymentPolicy.canRegisterAttendance(employee)) return false
        if (!employee.remoteCompanyId.equals(scope.companyId, ignoreCase = true)) return false
        return scope.branchId == null ||
            employee.remoteBranchId.equals(scope.branchId, ignoreCase = true)
    }
}
