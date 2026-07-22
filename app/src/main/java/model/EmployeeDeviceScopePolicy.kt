package com.example.controlhorario.model

import java.util.Locale

data class EmployeeDeviceScope(
    val companyId: String,
    val branchId: String?
)

fun interface EmployeeDeviceScopeSource {
    suspend fun current(): EmployeeDeviceScope?
}

/** Shared guard for every public employee-identification path. */
object EmployeeDeviceScopePolicy {
    private val activeStatuses = setOf("activo", "active")

    fun allows(employee: Employee, scope: EmployeeDeviceScope): Boolean {
        if (scope.companyId.isBlank() || employee.remoteId.isNullOrBlank()) return false
        if (!employee.isActive || !employee.jornadaEnabled) return false
        if (employee.employmentStatus.lowercase(Locale.ROOT) !in activeStatuses) return false
        if (!employee.remoteCompanyId.equals(scope.companyId, ignoreCase = true)) return false
        return scope.branchId == null ||
            employee.remoteBranchId.equals(scope.branchId, ignoreCase = true)
    }
}
