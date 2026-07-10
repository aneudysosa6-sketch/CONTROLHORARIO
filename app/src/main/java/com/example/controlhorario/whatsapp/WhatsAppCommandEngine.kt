package com.example.controlhorario.engine

object WhatsAppCommandEngine {

    fun processMessage(message: String): WhatsAppCommandResult {

        val command = normalize(message)

        if (command.isBlank()) {
            return WhatsAppCommandResult(
                command = WhatsAppCommand.UNKNOWN,
                response = "No recibí ningún mensaje."
            )
        }

        if (isMenuCommand(command)) {
            return WhatsAppCommandResult(
                command = WhatsAppCommand.MENU,
                response = ""
            )
        }

        if (isAttendanceCommand(command)) {
            return WhatsAppCommandResult(
                command = WhatsAppCommand.ATTENDANCE_HISTORY,
                response = ""
            )
        }

        if (isPayrollPreviewCommand(command)) {
            return WhatsAppCommandResult(
                command = WhatsAppCommand.PAYROLL_PREVIEW,
                response = ""
            )
        }

        if (isPayrollPdfCommand(command)) {
            return WhatsAppCommandResult(
                command = WhatsAppCommand.PAYROLL_PDF,
                response = ""
            )
        }

        if (isCreditCommand(command)) {
            return WhatsAppCommandResult(
                command = WhatsAppCommand.CREDIT_STATUS,
                response = ""
            )
        }

        return WhatsAppCommandResult(
            command = WhatsAppCommand.UNKNOWN,
            response =
                """
            No entendí tu mensaje.

            Puedes escribir:

            • menú
            • asistencia
            • nómina
            • pdf
            • crédito

            También puedes escribir:

            1
            2
            3
            4
            """.trimIndent()
        )
    }

    private fun normalize(text: String): String {

        return text
            .trim()
            .lowercase()
            .replace("á", "a")
            .replace("é", "e")
            .replace("í", "i")
            .replace("ó", "o")
            .replace("ú", "u")
    }

    private fun isMenuCommand(text: String): Boolean {

        return text in listOf(
            "0",
            "hola",
            "menu",
            "inicio",
            "start",
            "help",
            "ayuda",
            "opciones"
        )
    }

    private fun isAttendanceCommand(text: String): Boolean {

        return text in listOf(
            "1",
            "asistencia",
            "historial",
            "historial asistencia",
            "historial de asistencia",
            "entrada",
            "salida",
            "jornada"
        )
    }

    private fun isPayrollPreviewCommand(text: String): Boolean {

        return text in listOf(
            "2",
            "nomina",
            "pago",
            "salario",
            "vista previa",
            "vista previa nomina",
            "pre nomina",
            "prenomina"
        )
    }

    private fun isPayrollPdfCommand(text: String): Boolean {

        return text in listOf(
            "3",
            "pdf",
            "recibo",
            "comprobante",
            "recibo pdf",
            "recibo nomina",
            "recibo de nomina"
        )
    }

    private fun isCreditCommand(text: String): Boolean {

        return text in listOf(
            "4",
            "credito",
            "credito pendiente",
            "descuento",
            "descuentos",
            "prestamo",
            "prestamos",
            "cooperativa"
        )
    }
}

enum class WhatsAppCommand {

    MENU,

    ATTENDANCE_HISTORY,

    PAYROLL_PREVIEW,

    PAYROLL_PDF,

    CREDIT_STATUS,

    UNKNOWN
}

data class WhatsAppCommandResult(

    val command: WhatsAppCommand,

    val response: String
)