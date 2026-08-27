package com.example.controlhorario.engine

import com.example.controlhorario.database.SupervisorPermissionEntity

object PermissionEngine {
    fun canSupervisorManageEmployee(
        permissions: List<SupervisorPermissionEntity>,
        supervisorUserId: Int,
        employeeId: Int
    ): Boolean {
        return permissions.any {
            it.supervisorUserId == supervisorUserId &&
                    it.employeeId == employeeId &&
                    it.isActive
        }
    }
}
