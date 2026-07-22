package com.example.controlhorario.ui.login

object PermissionCatalog {
    const val DASHBOARD = "Dashboard"
    const val EMPLOYEES = "Empleados"
    const val ATTENDANCE = "Jornadas"
    const val PAYROLL = "Nómina"
    const val LOANS = "Préstamos"
    const val LOAN_APPROVAL = "Aprobar Préstamos"
    const val BRANCH_MANAGER = "Encargado de Sucursal"
    const val ATTENDANCE_DASHBOARD = "Dashboard Asistencias"
    const val MEDICAL_LICENSES = "Licencias Médicas"
    const val MEDICAL_LICENSE_APPROVAL = "Aprobar Licencias"
    const val EMPLOYEE_PERMISSION_REQUESTS = "Permisos Empleados"
    const val REPORTS = "Reportes"
    const val SETTINGS = "Configuración"
    const val USER_PERMISSIONS = "Accesos y Permisos"
    const val EMPLOYEE_PORTAL = "Portal del Empleado"
    const val INCIDENTS = "Incidencias"
    const val PIN_MODE = "Activar Modo PIN"
    const val FINGERPRINTS = "Registro facial"
    const val EXPORT_PDF = "Exportar PDF"
    const val EXPORT_EXCEL = "Exportar Excel"
    const val EDIT_ATTENDANCE = "Editar Jornadas"
    const val APPROVE_ATTENDANCE = "Aprobar Jornadas"
    const val CHANGE_SCHEDULES = "Modificar Horarios"
    const val KIOSK_PIN_FALLBACK_MANAGE = "kiosk.pin_fallback_manage"

    val all = listOf(
        DASHBOARD,
        EMPLOYEES,
        ATTENDANCE,
        PAYROLL,
        LOANS,
        LOAN_APPROVAL,
        BRANCH_MANAGER,
        ATTENDANCE_DASHBOARD,
        MEDICAL_LICENSES,
        MEDICAL_LICENSE_APPROVAL,
        EMPLOYEE_PERMISSION_REQUESTS,
        REPORTS,
        SETTINGS,
        USER_PERMISSIONS,
        EMPLOYEE_PORTAL,
        INCIDENTS,
        PIN_MODE,
        FINGERPRINTS,
        EXPORT_PDF,
        EXPORT_EXCEL,
        EDIT_ATTENDANCE,
        APPROVE_ATTENDANCE,
        CHANGE_SCHEDULES,
        KIOSK_PIN_FALLBACK_MANAGE
    )
}

fun String.hasPermission(permission: String): Boolean {
    if (isBlank()) return false
    return split(',').map { it.trim() }.contains(permission)
}
