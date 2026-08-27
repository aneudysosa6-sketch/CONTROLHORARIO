package com.example.controlhorario.ui.access

import org.junit.Assert.assertEquals
import org.junit.Test

class SupervisorScopePolicyTest {
    private val departments = listOf(
        SupervisorScopeDepartment("a-1", "a", true),
        SupervisorScopeDepartment("a-off", "a", false),
        SupervisorScopeDepartment("b-1", "b", true),
    )

    @Test
    fun allowsMultipleBranchesWhenEachHasASelectedDepartment() {
        val selection = SupervisorScopeSelection(setOf("a", "b"), setOf("a-1", "b-1"))
        assertEquals(SupervisorScopeDecision.Allowed(selection), SupervisorScopePolicy.validate(selection, departments))
    }

    @Test
    fun requiresAtLeastOneDepartmentForEverySelectedBranch() {
        val result = SupervisorScopePolicy.validate(
            SupervisorScopeSelection(setOf("a", "b"), setOf("a-1")),
            departments,
        )
        assertEquals(SupervisorScopeDecision.Denied("SUPERVISOR_BRANCH_WITHOUT_DEPARTMENTS"), result)
    }

    @Test
    fun rejectsInactiveOrCrossScopeDepartments() {
        val inactive = SupervisorScopePolicy.validate(
            SupervisorScopeSelection(setOf("a"), setOf("a-off")),
            departments,
        )
        val crossScope = SupervisorScopePolicy.validate(
            SupervisorScopeSelection(setOf("a"), setOf("b-1")),
            departments,
        )
        assertEquals(SupervisorScopeDecision.Denied("SUPERVISOR_DEPARTMENTS_INVALID"), inactive)
        assertEquals(SupervisorScopeDecision.Denied("SUPERVISOR_DEPARTMENTS_INVALID"), crossScope)
    }
}