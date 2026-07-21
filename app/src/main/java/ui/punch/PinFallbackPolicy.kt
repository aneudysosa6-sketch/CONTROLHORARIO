package com.example.controlhorario.ui.punch

import com.example.controlhorario.repository.KioskFaceAuthSettings
import com.example.controlhorario.ui.login.PermissionCatalog

object PinFallbackPolicy {
    fun canManage(permissionCodes: Set<String>): Boolean =
        PermissionCatalog.KIOSK_PIN_FALLBACK_MANAGE in permissionCodes

    fun requireCanManage(permissionCodes: Set<String>) {
        if (!canManage(permissionCodes)) throw SecurityException("KIOSK_PIN_FALLBACK_PERMISSION_DENIED")
    }

    fun isEnabled(settings: KioskFaceAuthSettings): Boolean = settings.pinFallbackEnabled
}
