package com.example.controlhorario.ui.settings

import org.junit.Assert.assertEquals
import org.junit.Test

class OrganizationLifecyclePolicyTest {
    @Test
    fun branchDeactivationRequiresInactiveDepartments() {
        assertEquals(
            OrganizationLifecycleDecision.Denied("Desactiva o reasigna primero los departamentos activos de esta sucursal."),
            OrganizationLifecyclePolicy.branchStatusChange(activating = false, activeDepartmentCount = 1),
        )
        assertEquals(
            OrganizationLifecycleDecision.Allowed,
            OrganizationLifecyclePolicy.branchStatusChange(activating = false, activeDepartmentCount = 0),
        )
    }

    @Test
    fun departmentDeactivationRequiresMovedEmployees() {
        assertEquals(
            OrganizationLifecycleDecision.Denied("Mueve primero los empleados activos de este departamento."),
            OrganizationLifecyclePolicy.departmentStatusChange(activating = false, activeEmployeeCount = 2),
        )
        assertEquals(
            OrganizationLifecycleDecision.Allowed,
            OrganizationLifecyclePolicy.departmentStatusChange(activating = true, activeEmployeeCount = 2),
        )
    }
}