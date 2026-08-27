package com.example.controlhorario.engine

import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.PendingAttendanceReviewEntity
import com.example.controlhorario.model.Employee

object PendingAttendanceReviewEngine {

    fun buildIfIncomplete(employee: Employee, date: String, records: List<AttendanceEntity>): PendingAttendanceReviewEntity? {
        val entrada = records.firstOrNull { it.actionType.contains("INICI", true) || it.actionType.contains("ENTRADA", true) }
        val salidaAlmuerzo = records.firstOrNull { it.actionType.contains("PAUSA", true) || it.actionType.contains("ALMUERZO", true) }
        val llegadaAlmuerzo = records.firstOrNull { it.actionType.contains("REAN", true) || it.actionType.contains("REGRES", true) }
        val salida = records.firstOrNull { it.actionType.contains("FINAL", true) || it.actionType.contains("SALIDA", true) }

        if (entrada == null) return null
        if (salida != null) return null

        val severity: String
        val reason: String
        val hours: Double

        when {
            salidaAlmuerzo == null && llegadaAlmuerzo == null -> {
                severity = PendingAttendanceReviewEntity.SEVERITY_CRITICAL
                reason = "Solo registró entrada. Requiere aprobación del administrador."
                hours = 0.0
            }
            salidaAlmuerzo != null && llegadaAlmuerzo == null -> {
                severity = PendingAttendanceReviewEntity.SEVERITY_HIGH
                reason = "Salió a almuerzo y no regresó. Se calculará solo hasta el último ponche válido si el administrador lo aprueba."
                hours = hoursBetween(entrada.time, salidaAlmuerzo.time)
            }
            salidaAlmuerzo != null && llegadaAlmuerzo != null -> {
                severity = PendingAttendanceReviewEntity.SEVERITY_MEDIUM
                reason = "Regresó del almuerzo, pero no finalizó la jornada. Requiere revisión."
                hours = hoursBetween(entrada.time, salidaAlmuerzo.time)
            }
            else -> {
                severity = PendingAttendanceReviewEntity.SEVERITY_INFO
                reason = "Diferencia menor detectada en jornada. Requiere revisión."
                hours = 0.0
            }
        }

        return PendingAttendanceReviewEntity(
            employeeId = employee.id,
            employeeCode = employee.employeeCode,
            employeeName = employee.nombre,
            employeePhone = employee.telefono,
            departmentId = employee.departmentId,
            departmentName = employee.departamento,
            branchId = employee.branchId,
            reviewDate = date,
            checkInTime = entrada.time,
            lunchOutTime = salidaAlmuerzo?.time ?: "",
            lunchInTime = llegadaAlmuerzo?.time ?: "",
            checkOutTime = salida?.time ?: "",
            reason = reason,
            severity = severity,
            calculatedHours = hours,
            notificationQueued = false
        )
    }

    private fun hoursBetween(start: String, end: String): Double {
        return try {
            val s = toMinutes(start)
            val e = toMinutes(end)
            if (e <= s) 0.0 else ((e - s).toDouble() / 60.0)
        } catch (_: Exception) {
            0.0
        }
    }

    private fun toMinutes(time: String): Int {
        val clean = time.take(5)
        val parts = clean.split(":")
        if (parts.size < 2) return 0
        return parts[0].toInt() * 60 + parts[1].toInt()
    }
}
