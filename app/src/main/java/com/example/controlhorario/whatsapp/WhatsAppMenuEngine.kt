package com.example.controlhorario.engine

object WhatsAppMenuEngine {

    fun getMainMenu(employeeName: String): WhatsAppMenuResponse {
        val cleanName = employeeName.ifBlank { "empleado" }

        val message = """
            👋 Hola, $cleanName.
            
            Bienvenido al sistema OSINET Time.
            
            Selecciona una opción:
            
            1️⃣ Historial de asistencia
            2️⃣ Vista previa de nómina
            3️⃣ Último recibo PDF
            4️⃣ Créditos y descuentos
            
            Responde solo con el número de la opción.
        """.trimIndent()

        return WhatsAppMenuResponse(
            success = true,
            message = message
        )
    }

    fun getInvalidOptionMessage(): WhatsAppMenuResponse {
        return WhatsAppMenuResponse(
            success = false,
            message = """
                ❌ Opción no válida.
                
                Responde con una de estas opciones:
                
                1️⃣ Historial de asistencia
                2️⃣ Vista previa de nómina
                3️⃣ Último recibo PDF
                4️⃣ Créditos y descuentos
            """.trimIndent()
        )
    }

    fun getUnauthorizedMessage(): WhatsAppMenuResponse {
        return WhatsAppMenuResponse(
            success = false,
            message = "❌ Este número no está registrado como empleado en OSINET Time."
        )
    }

    fun getAttendanceHistoryMessage(): WhatsAppMenuResponse {
        return WhatsAppMenuResponse(
            success = true,
            message = "📅 Has solicitado tu historial de asistencia. OSINET Time preparará tu información."
        )
    }

    fun getPayrollPreviewMessage(): WhatsAppMenuResponse {
        return WhatsAppMenuResponse(
            success = true,
            message = "💰 Has solicitado tu vista previa de nómina. OSINET Time preparará tu información."
        )
    }

    fun getPayrollReceiptMessage(): WhatsAppMenuResponse {
        return WhatsAppMenuResponse(
            success = true,
            message = "📄 Has solicitado tu último recibo PDF de nómina. OSINET Time buscará tu recibo más reciente."
        )
    }

    fun getCreditStatusMessage(): WhatsAppMenuResponse {
        return WhatsAppMenuResponse(
            success = true,
            message = "💳 Has solicitado tu estado de créditos y descuentos. OSINET Time preparará el resumen."
        )
    }

    fun processMenuOption(option: String): WhatsAppMenuResponse {
        return when (option.trim()) {
            "1" -> getAttendanceHistoryMessage()
            "2" -> getPayrollPreviewMessage()
            "3" -> getPayrollReceiptMessage()
            "4" -> getCreditStatusMessage()
            else -> getInvalidOptionMessage()
        }
    }
}

data class WhatsAppMenuResponse(
    val success: Boolean,
    val message: String
)