package com.example.controlhorario.whatsapp

import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.model.Employee

object WhatsAppAttendanceEngine {

    fun generateAttendanceSummary(
        employee: Employee,
        attendanceRecords: List<AttendanceEntity>
    ): WhatsAppAttendanceResult {

        val employeeRecords = attendanceRecords
            .filter { it.employeeId == employee.id }
            .sortedWith(
                compareByDescending<AttendanceEntity> { it.date }
                    .thenByDescending { it.time }
            )

        if (employeeRecords.isEmpty()) {
            return WhatsAppAttendanceResult(
                success = false,
                employee = employee,
                totalRecords = 0,
                firstDate = "",
                lastDate = "",
                records = emptyList(),
                message = """
                    📅 Historial de asistencia
                    
                    No existen asistencias registradas para este empleado.
                """.trimIndent()
            )
        }

        val firstDate = employeeRecords.last().date
        val lastDate = employeeRecords.first().date

        val summary = buildString {
            appendLine("📅 Historial de asistencia")
            appendLine()
            appendLine("Empleado:")
            appendLine(employee.nombre)
            appendLine()
            appendLine("Total de registros:")
            appendLine(employeeRecords.size)
            appendLine()
            appendLine("Desde:")
            appendLine(firstDate)
            appendLine()
            appendLine("Hasta:")
            appendLine(lastDate)
            appendLine()
            appendLine("Últimos registros:")
            appendLine()

            employeeRecords
                .take(10)
                .forEach { record ->
                    appendLine("${record.date}   ${record.time}")
                    appendLine("Acción: ${formatAction(record.actionType)}")
                    appendLine()
                }

            if (employeeRecords.size > 10) {
                appendLine("...")
                appendLine()
                appendLine("El PDF contendrá el historial completo.")
            }
        }

        return WhatsAppAttendanceResult(
            success = true,
            employee = employee,
            totalRecords = employeeRecords.size,
            firstDate = firstDate,
            lastDate = lastDate,
            records = employeeRecords,
            message = summary
        )
    }

    private fun formatAction(actionType: String): String {
        return when (actionType) {
            "INICIO_JORNADA" -> "Inicio de jornada"
            "PAUSA" -> "Pausa"
            "REANUDAR" -> "Reanudar jornada"
            "FIN_JORNADA" -> "Fin de jornada"
            else -> actionType
        }
    }
}

data class WhatsAppAttendanceResult(
    val success: Boolean,
    val employee: Employee,
    val totalRecords: Int,
    val firstDate: String,
    val lastDate: String,
    val records: List<AttendanceEntity>,
    val message: String
)