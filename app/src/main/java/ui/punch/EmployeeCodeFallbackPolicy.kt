package com.example.controlhorario.ui.punch

import com.example.controlhorario.repository.KioskFaceAuthSettings
import com.example.controlhorario.ui.login.PermissionCatalog

object EmployeeCodeFallbackPolicy {
    fun canManage(permissionCodes: Set<String>): Boolean =
        PermissionCatalog.KIOSK_EMPLOYEE_CODE_FALLBACK_MANAGE in permissionCodes

    fun requireCanManage(permissionCodes: Set<String>) {
        if (!canManage(permissionCodes)) {
            throw SecurityException("KIOSK_EMPLOYEE_CODE_FALLBACK_PERMISSION_DENIED")
        }
    }

    /** The persisted column keeps its legacy name until the next destructive schema migration. */
    fun isEnabled(settings: KioskFaceAuthSettings): Boolean = settings.pinFallbackEnabled
}
