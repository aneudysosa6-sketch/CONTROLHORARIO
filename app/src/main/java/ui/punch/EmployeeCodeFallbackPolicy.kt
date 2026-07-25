package com.example.controlhorario.ui.punch

import com.example.controlhorario.repository.KioskFaceAuthSettings
object EmployeeCodeFallbackPolicy {
    private const val MANAGE_PERMISSION = "kiosk.pin_fallback_manage"

    fun canManage(permissionCodes: Set<String>): Boolean =
        MANAGE_PERMISSION in permissionCodes

    fun requireCanManage(permissionCodes: Set<String>) {
        if (!canManage(permissionCodes)) {
            throw SecurityException("KIOSK_EMPLOYEE_CODE_FALLBACK_PERMISSION_DENIED")
        }
    }

    /** The persisted column keeps its legacy name until the next destructive schema migration. */
    fun isEnabled(settings: KioskFaceAuthSettings): Boolean = settings.pinFallbackEnabled
}
