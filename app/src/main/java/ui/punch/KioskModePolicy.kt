package com.example.controlhorario.ui.punch

enum class KioskDestination { FACE_IDENTIFICATION, EXIT_AUTH, ADMIN_PANEL }

object KioskModePolicy {
    fun afterActivation() = KioskDestination.FACE_IDENTIFICATION
    fun afterBackPressed() = KioskDestination.EXIT_AUTH
    fun afterAuthentication(validCredentials: Boolean) =
        if (validCredentials) KioskDestination.ADMIN_PANEL else KioskDestination.FACE_IDENTIFICATION
    fun afterAttendance() = KioskDestination.FACE_IDENTIFICATION
    fun startDestination(kioskActive: Boolean) =
        if (kioskActive) KioskDestination.FACE_IDENTIFICATION else KioskDestination.ADMIN_PANEL
}
