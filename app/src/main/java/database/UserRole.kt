package com.example.controlhorario.database

enum class UserRole(
    val displayName: String
) {
    ADMINISTRADOR("Administrador"),
    RECURSOS_HUMANOS("Recursos Humanos"),
    ENCARGADO("Encargado"),
    SUPERVISOR("Supervisor"),
    EMPLEADO("Empleado");

    companion object {
        fun fromName(value: String): UserRole {
            return entries.firstOrNull { it.name == value }
                ?: ADMINISTRADOR
        }
    }
}
