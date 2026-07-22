package com.example.controlhorario.model

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmployeeDeviceScopePolicyTest {
    private val scope = EmployeeDeviceScope("company-a", "branch-a")
    private val employee = Employee(
        id = 7,
        employeeCode = "000007",
        remoteId = "remote-7",
        remoteCompanyId = "company-a",
        remoteBranchId = "branch-a",
        employmentStatus = "activo",
        isActive = true,
        jornadaEnabled = true
    )

    @Test fun `same company and branch is allowed`() {
        assertTrue(EmployeeDeviceScopePolicy.allows(employee, scope))
    }

    @Test fun `another branch is denied`() {
        assertFalse(EmployeeDeviceScopePolicy.allows(employee.copy(remoteBranchId = "branch-b"), scope))
    }

    @Test fun `missing tenant scope is denied`() {
        assertFalse(EmployeeDeviceScopePolicy.allows(employee.copy(remoteCompanyId = null), scope))
    }

    @Test fun `inactive employee is denied`() {
        assertFalse(EmployeeDeviceScopePolicy.allows(employee.copy(isActive = false), scope))
    }
}
