package com.example.controlhorario.whatsapp

import com.example.controlhorario.database.WhatsAppOutboxEntity

object N8NWhatsAppIntegrationEngine {

    fun buildAttendancePayload(
        phone: String,
        employeeName: String,
        action: String,
        dateTime: String
    ): WhatsAppOutboxEntity {
        val message = "OSINET: $employeeName registró $action a las $dateTime"
        val json = """
            {
              "type": "attendance",
              "employeeName": "$employeeName",
              "action": "$action",
              "dateTime": "$dateTime"
            }
        """.trimIndent()

        return WhatsAppOutboxEntity(
            phoneNumber = phone,
            message = message,
            payloadJson = json,
            createdAt = dateTime
        )
    }

    fun buildPayrollPayload(
        phone: String,
        employeeName: String,
        netPay: Double,
        dateTime: String
    ): WhatsAppOutboxEntity {
        val message = "OSINET: Nómina disponible para $employeeName. Neto a pagar: RD$ $netPay"
        val json = """
            {
              "type": "payroll",
              "employeeName": "$employeeName",
              "netPay": $netPay,
              "dateTime": "$dateTime"
            }
        """.trimIndent()

        return WhatsAppOutboxEntity(
            phoneNumber = phone,
            message = message,
            payloadJson = json,
            createdAt = dateTime
        )
    }

    fun buildSupervisorAlert(
        phone: String,
        title: String,
        detail: String,
        dateTime: String
    ): WhatsAppOutboxEntity {
        val message = "OSINET Supervisor: $title - $detail"
        val json = """
            {
              "type": "supervisor_alert",
              "title": "$title",
              "detail": "$detail",
              "dateTime": "$dateTime"
            }
        """.trimIndent()

        return WhatsAppOutboxEntity(
            phoneNumber = phone,
            message = message,
            payloadJson = json,
            createdAt = dateTime
        )
    }
}