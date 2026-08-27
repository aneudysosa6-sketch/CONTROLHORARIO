package com.example.controlhorario.ui.settings

sealed interface OrganizationLifecycleDecision {
    data object Allowed : OrganizationLifecycleDecision
    data class Denied(val message: String) : OrganizationLifecycleDecision
}

object OrganizationLifecyclePolicy {
    fun branchStatusChange(activating: Boolean, activeDepartmentCount: Int): OrganizationLifecycleDecision {
        if (!activating && activeDepartmentCount > 0) {
            return OrganizationLifecycleDecision.Denied(
                "Desactiva o reasigna primero los departamentos activos de esta sucursal."
            )
        }
        return OrganizationLifecycleDecision.Allowed
    }

    fun departmentStatusChange(activating: Boolean, activeEmployeeCount: Int): OrganizationLifecycleDecision {
        if (!activating && activeEmployeeCount > 0) {
            return OrganizationLifecycleDecision.Denied(
                "Mueve primero los empleados activos de este departamento."
            )
        }
        return OrganizationLifecycleDecision.Allowed
    }
}