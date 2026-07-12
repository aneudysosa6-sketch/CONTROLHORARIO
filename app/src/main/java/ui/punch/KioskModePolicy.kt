package com.example.controlhorario.ui.punch

enum class KioskDestination { PIN, EXIT_AUTH, ADMIN_PANEL }

object KioskModePolicy {
    fun afterActivation() = KioskDestination.PIN
    fun afterBackPressed() = KioskDestination.EXIT_AUTH
    fun afterAuthentication(validCredentials: Boolean) =
        if (validCredentials) KioskDestination.ADMIN_PANEL else KioskDestination.PIN
    fun afterAttendance() = KioskDestination.PIN
    fun startDestination(kioskActive: Boolean) =
        if (kioskActive) KioskDestination.PIN else KioskDestination.ADMIN_PANEL
}
