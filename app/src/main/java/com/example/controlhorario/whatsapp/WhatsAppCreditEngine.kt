package com.example.controlhorario.engine

import com.example.controlhorario.database.EmployeePayrollSettingsEntity
import java.text.NumberFormat
import java.util.Locale

object WhatsAppCreditEngine {

    fun generateCreditSummary(
        employeeSettings: EmployeePayrollSettingsEntity?
    ): WhatsAppCreditResult {

        if (employeeSettings == null) {
            return WhatsAppCreditResult(
                success = false,
                message = """
                    No se encontró una configuración de nómina para este empleado.
                """.trimIndent()
            )
        }

        val currency = NumberFormat.getCurrencyInstance(
            Locale("es", "DO")
        )

        val temporaryCredit = employeeSettings.oneTimeCreditAmount

        val loan = employeeSettings.loanAmount

        val cooperative = employeeSettings.cooperativeAmount

        val privateInsurance = employeeSettings.privateInsuranceAmount

        val phone = employeeSettings.phoneDiscountAmount

        val food = employeeSettings.foodDiscountAmount

        val transport = employeeSettings.transportDiscountAmount

        val other = employeeSettings.otherDiscountAmount

        val totalFixedDiscounts =
            loan +
                    cooperative +
                    privateInsurance +
                    phone +
                    food +
                    transport +
                    other

        val totalCurrentDiscounts =
            totalFixedDiscounts +
                    temporaryCredit

        val message =
            """
            💳 Estado de descuentos
            
            ----------------------------
            
            📌 Crédito temporal:
            ${currency.format(temporaryCredit)}
            
            ----------------------------
            
            📌 Préstamo fijo:
            ${currency.format(loan)}
            
            📌 Cooperativa:
            ${currency.format(cooperative)}
            
            📌 Seguro médico:
            ${currency.format(privateInsurance)}
            
            📌 Celular:
            ${currency.format(phone)}
            
            📌 Comedor:
            ${currency.format(food)}
            
            📌 Transporte:
            ${currency.format(transport)}
            
            📌 Otros descuentos:
            ${currency.format(other)}
            
            ----------------------------
            
            💰 Descuentos fijos:
            ${currency.format(totalFixedDiscounts)}
            
            💰 Total descuentos actuales:
            ${currency.format(totalCurrentDiscounts)}
            """.trimIndent()

        return WhatsAppCreditResult(
            success = true,
            message = message
        )
    }
}

data class WhatsAppCreditResult(

    val success: Boolean,

    val message: String
)