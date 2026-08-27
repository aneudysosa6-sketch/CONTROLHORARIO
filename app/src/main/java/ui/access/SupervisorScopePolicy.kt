package com.example.controlhorario.ui.access

data class SupervisorScopeDepartment(
    val id: String,
    val branchId: String,
    val active: Boolean,
)

data class SupervisorScopeSelection(
    val branchIds: Set<String>,
    val departmentIds: Set<String>,
)

sealed interface SupervisorScopeDecision {
    data class Allowed(val selection: SupervisorScopeSelection) : SupervisorScopeDecision
    data class Denied(val reason: String) : SupervisorScopeDecision
}

object SupervisorScopePolicy {
    fun validate(
        selection: SupervisorScopeSelection,
        departments: Collection<SupervisorScopeDepartment>,
    ): SupervisorScopeDecision {
        if (selection.branchIds.isEmpty()) return SupervisorScopeDecision.Denied("SUPERVISOR_BRANCH_REQUIRED")
        if (selection.departmentIds.isEmpty()) return SupervisorScopeDecision.Denied("SIN_DEPARTAMENTOS")

        val activeById = departments.filter(SupervisorScopeDepartment::active)
            .associateBy(SupervisorScopeDepartment::id)
        if (selection.departmentIds.any { id -> activeById[id]?.branchId !in selection.branchIds }) {
            return SupervisorScopeDecision.Denied("SUPERVISOR_DEPARTMENTS_INVALID")
        }
        if (selection.branchIds.any { branchId ->
                selection.departmentIds.none { id -> activeById[id]?.branchId == branchId }
            }
        ) {
            return SupervisorScopeDecision.Denied("SUPERVISOR_BRANCH_WITHOUT_DEPARTMENTS")
        }
        return SupervisorScopeDecision.Allowed(selection)
    }
}