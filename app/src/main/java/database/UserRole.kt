package com.example.controlhorario.database

enum class UserRole(
    val displayName: String
) {
    ADMINISTRADOR("Administrador"),
    RECURSOS_HUMANOS("Recursos Humanos"),
    ENCARGADO("Encargado"),
    SUPERVISOR("Supervisor"),
    EMPLEADO("Empleado"),
    UNKNOWN("Desconocido");

    companion object {
        fun fromName(value: String): UserRole {
            return entries.firstOrNull { it.name.equals(value.trim(), ignoreCase = true) }
                ?: UNKNOWN
        }
    }
}
