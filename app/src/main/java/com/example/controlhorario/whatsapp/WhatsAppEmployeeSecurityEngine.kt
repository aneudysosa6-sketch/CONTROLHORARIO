package com.example.controlhorario.engine

import com.example.controlhorario.model.Employee

object WhatsAppEmployeeSecurityEngine {

    fun findEmployeeByPhoneNumber(
        incomingPhoneNumber: String,
        employees: List<Employee>
    ): WhatsAppEmployeeValidationResult {
        val normalizedIncomingPhone = normalizePhoneNumber(incomingPhoneNumber)

        if (normalizedIncomingPhone.isBlank()) {
            return WhatsAppEmployeeValidationResult(
                isAuthorized = false,
                employee = null,
                message = "Número de WhatsApp inválido."
            )
        }

        val employee = employees.firstOrNull { currentEmployee ->
            normalizePhoneNumber(currentEmployee.telefono) == normalizedIncomingPhone
        }

        if (employee == null) {
            return WhatsAppEmployeeValidationResult(
                isAuthorized = false,
                employee = null,
                message = "Este número no está registrado como empleado."
            )
        }

        return WhatsAppEmployeeValidationResult(
            isAuthorized = true,
            employee = employee,
            message = "Empleado autorizado correctamente."
        )
    }

    fun canAccessEmployeeData(
        incomingPhoneNumber: String,
        employee: Employee?
    ): WhatsAppEmployeeValidationResult {
        if (employee == null) {
            return WhatsAppEmployeeValidationResult(
                isAuthorized = false,
                employee = null,
                message = "Empleado no encontrado."
            )
        }

        val normalizedIncomingPhone = normalizePhoneNumber(incomingPhoneNumber)
        val normalizedEmployeePhone = normalizePhoneNumber(employee.telefono)

        if (normalizedIncomingPhone.isBlank() || normalizedEmployeePhone.isBlank()) {
            return WhatsAppEmployeeValidationResult(
                isAuthorized = false,
                employee = null,
                message = "No se pudo validar el número del empleado."
            )
        }

        if (normalizedIncomingPhone != normalizedEmployeePhone) {
            return WhatsAppEmployeeValidationResult(
                isAuthorized = false,
                employee = null,
                message = "No tienes permiso para consultar información de otro empleado."
            )
        }

        return WhatsAppEmployeeValidationResult(
            isAuthorized = true,
            employee = employee,
            message = "Acceso autorizado."
        )
    }

    private fun normalizePhoneNumber(phoneNumber: String): String {
        return phoneNumber
            .replace("+", "")
            .replace("-", "")
            .replace(" ", "")
            .replace("(", "")
            .replace(")", "")
            .trim()
    }
}

data class WhatsAppEmployeeValidationResult(
    val isAuthorized: Boolean,
    val employee: Employee?,
    val message: String
)