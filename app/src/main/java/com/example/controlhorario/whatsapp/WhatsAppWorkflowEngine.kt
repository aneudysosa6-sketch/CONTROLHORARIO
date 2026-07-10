package com.example.controlhorario.engine

import com.example.controlhorario.model.Employee

object WhatsAppWorkflowEngine {

    fun processEmployeeRequest(
        incomingPhoneNumber: String,
        message: String,
        employees: List<Employee>
    ): WhatsAppWorkflowResult {

        val conversationResult = WhatsAppConversationEngine.processIncomingMessage(
            incomingPhoneNumber = incomingPhoneNumber,
            message = message,
            employees = employees
        )

        if (!conversationResult.authorized || conversationResult.employee == null) {
            return WhatsAppWorkflowResult(
                authorized = false,
                employee = null,
                command = WhatsAppCommand.UNKNOWN,
                responseMessage = conversationResult.message,
                shouldGenerateAttendancePdf = false,
                shouldGeneratePayrollPreview = false,
                shouldSendPayrollPdf = false,
                shouldSendCreditStatus = false
            )
        }

        val employee = conversationResult.employee

        return when (conversationResult.command) {

            WhatsAppCommand.MENU -> {
                WhatsAppWorkflowResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.MENU,
                    responseMessage = conversationResult.message,
                    shouldGenerateAttendancePdf = false,
                    shouldGeneratePayrollPreview = false,
                    shouldSendPayrollPdf = false,
                    shouldSendCreditStatus = false
                )
            }

            WhatsAppCommand.ATTENDANCE_HISTORY -> {
                WhatsAppWorkflowResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.ATTENDANCE_HISTORY,
                    responseMessage = conversationResult.message,
                    shouldGenerateAttendancePdf = true,
                    shouldGeneratePayrollPreview = false,
                    shouldSendPayrollPdf = false,
                    shouldSendCreditStatus = false
                )
            }

            WhatsAppCommand.PAYROLL_PREVIEW -> {
                WhatsAppWorkflowResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.PAYROLL_PREVIEW,
                    responseMessage = conversationResult.message,
                    shouldGenerateAttendancePdf = false,
                    shouldGeneratePayrollPreview = true,
                    shouldSendPayrollPdf = false,
                    shouldSendCreditStatus = false
                )
            }

            WhatsAppCommand.PAYROLL_PDF -> {
                WhatsAppWorkflowResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.PAYROLL_PDF,
                    responseMessage = conversationResult.message,
                    shouldGenerateAttendancePdf = false,
                    shouldGeneratePayrollPreview = false,
                    shouldSendPayrollPdf = true,
                    shouldSendCreditStatus = false
                )
            }

            WhatsAppCommand.CREDIT_STATUS -> {
                WhatsAppWorkflowResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.CREDIT_STATUS,
                    responseMessage = conversationResult.message,
                    shouldGenerateAttendancePdf = false,
                    shouldGeneratePayrollPreview = false,
                    shouldSendPayrollPdf = false,
                    shouldSendCreditStatus = true
                )
            }

            WhatsAppCommand.UNKNOWN -> {
                WhatsAppWorkflowResult(
                    authorized = true,
                    employee = employee,
                    command = WhatsAppCommand.UNKNOWN,
                    responseMessage = conversationResult.message,
                    shouldGenerateAttendancePdf = false,
                    shouldGeneratePayrollPreview = false,
                    shouldSendPayrollPdf = false,
                    shouldSendCreditStatus = false
                )
            }
        }
    }
}

data class WhatsAppWorkflowResult(
    val authorized: Boolean,
    val employee: Employee?,
    val command: WhatsAppCommand,
    val responseMessage: String,
    val shouldGenerateAttendancePdf: Boolean,
    val shouldGeneratePayrollPreview: Boolean,
    val shouldSendPayrollPdf: Boolean,
    val shouldSendCreditStatus: Boolean
)