package com.example.controlhorario.engine

import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.PayrollResult
import java.text.NumberFormat
import java.util.Locale

object WhatsAppNotificationEngine {

    fun payrollWillBeProcessedTomorrow(
        employee: Employee
    ): WhatsAppNotificationResult {
        return WhatsAppNotificationResult(
            success = true,
            phoneNumber = employee.telefono,
            message = """
                👋 Hola, ${employee.nombre}.
                
                Te informamos que mañana se procesará tu nómina en OSINET Time.
                
                Cuando esté disponible, podrás solicitar:
                
                1️⃣ Historial de asistencia
                2️⃣ Vista previa de nómina
                3️⃣ Recibo PDF
                4️⃣ Créditos y descuentos
            """.trimIndent()
        )
    }

    fun payrollGenerated(
        employee: Employee,
        result: PayrollResult
    ): WhatsAppNotificationResult {
        val currency = NumberFormat.getCurrencyInstance(Locale("es", "DO"))

        return WhatsAppNotificationResult(
            success = true,
            phoneNumber = employee.telefono,
            message = """
                💰 Nómina generada
                
                Hola, ${employee.nombre}.
                
                Tu nómina del período:
                ${result.periodStart} - ${result.periodEnd}
                
                ya fue generada correctamente.
                
                Total devengado:
                ${currency.format(result.totalIncome)}
                
                Total descuentos:
                ${currency.format(result.totalDiscounts)}
                
                Neto a pagar:
                ${currency.format(result.netPay)}
                
                Puedes responder:
                
                3️⃣ para recibir tu recibo PDF
                4️⃣ para ver créditos y descuentos
            """.trimIndent()
        )
    }

    fun payrollPdfAvailable(
        employee: Employee
    ): WhatsAppNotificationResult {
        return WhatsAppNotificationResult(
            success = true,
            phoneNumber = employee.telefono,
            message = """
                📄 Recibo disponible
                
                Hola, ${employee.nombre}.
                
                Tu recibo de nómina ya está disponible.
                
                Responde con:
                
                3
                
                para solicitar tu último recibo PDF.
            """.trimIndent()
        )
    }

    fun newCreditRegistered(
        employee: Employee,
        creditAmount: Double
    ): WhatsAppNotificationResult {
        val currency = NumberFormat.getCurrencyInstance(Locale("es", "DO"))

        return WhatsAppNotificationResult(
            success = true,
            phoneNumber = employee.telefono,
            message = """
                💳 Crédito registrado
                
                Hola, ${employee.nombre}.
                
                Se registró un nuevo crédito temporal en tu nómina:
                
                ${currency.format(creditAmount)}
                
                Este monto será descontado una sola vez en la próxima nómina generada.
                
                Puedes responder:
                
                4
                
                para consultar tus créditos y descuentos.
            """.trimIndent()
        )
    }



    fun permissionApproved(
        employee: Employee,
        date: String,
        reason: String
    ): WhatsAppNotificationResult {
        return WhatsAppNotificationResult(
            success = true,
            phoneNumber = employee.telefono,
            message = """
                📄 Permiso aprobado
                
                Hola, ${employee.nombre}.
                
                Tu permiso fue aprobado para la fecha:
                
                $date
                
                Motivo:
                $reason
            """.trimIndent()
        )
    }

    fun attendanceAlert(
        employee: Employee,
        message: String
    ): WhatsAppNotificationResult {
        return WhatsAppNotificationResult(
            success = true,
            phoneNumber = employee.telefono,
            message = """
                🕒 Alerta de asistencia
                
                Hola, ${employee.nombre}.
                
                $message
            """.trimIndent()
        )
    }
}

data class WhatsAppNotificationResult(
    val success: Boolean,
    val phoneNumber: String,
    val message: String
)