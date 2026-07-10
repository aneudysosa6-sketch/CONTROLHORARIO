package com.example.controlhorario.engine

import com.example.controlhorario.model.Employee

object WhatsAppConversationEngine {

    fun processIncomingMessage(
        incomingPhoneNumber: String,
        message: String,
        employees: List<Employee>
    ): WhatsAppConversationResult {

        val securityResult = WhatsAppEmployeeSecurityEngine.findEmployeeByPhoneNumber(
            incomingPhoneNumber = incomingPhoneNumber,
            employees = employees
        )

        if (!securityResult.isAuthorized || securityResult.employee == null) {
            return WhatsAppConversationResult(
                authorized = false,
                employee = null,
                command = WhatsAppCommand.UNKNOWN,
                message = WhatsAppMenuEngine.getUnauthorizedMessage().message
            )
        }

        val employee = securityResult.employee

        val commandResult = WhatsAppCommandEngine.processMessage(message)

        return when (commandResult.command) {

            WhatsAppCommand.MENU -> {
                WhatsAppConversationResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.MENU,
                    message = WhatsAppMenuEngine.getMainMenu(employee.nombre).message
                )
            }

            WhatsAppCommand.ATTENDANCE_HISTORY -> {
                WhatsAppConversationResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.ATTENDANCE_HISTORY,
                    message = WhatsAppMenuEngine.getAttendanceHistoryMessage().message
                )
            }

            WhatsAppCommand.PAYROLL_PREVIEW -> {
                WhatsAppConversationResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.PAYROLL_PREVIEW,
                    message = WhatsAppMenuEngine.getPayrollPreviewMessage().message
                )
            }

            WhatsAppCommand.PAYROLL_PDF -> {
                WhatsAppConversationResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.PAYROLL_PDF,
                    message = WhatsAppMenuEngine.getPayrollReceiptMessage().message
                )
            }

            WhatsAppCommand.CREDIT_STATUS -> {
                WhatsAppConversationResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.CREDIT_STATUS,
                    message = WhatsAppMenuEngine.getCreditStatusMessage().message
                )
            }

            WhatsAppCommand.UNKNOWN -> {
                WhatsAppConversationResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.UNKNOWN,
                    message = commandResult.response
                )
            }
        }
    }
}

data class WhatsAppConversationResult(
    val authorized: Boolean,
    val employee: Employee?,
    val command: WhatsAppCommand,
    val message: String
)