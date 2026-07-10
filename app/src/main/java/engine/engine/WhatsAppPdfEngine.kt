package com.example.controlhorario.engine

import android.content.Context
import com.example.controlhorario.model.Employee
import java.io.File

object WhatsAppPdfEngine {

    fun getLatestPayrollPdf(
        context: Context,
        employee: Employee
    ): WhatsAppPdfResult {

        val folder = File(
            context.getExternalFilesDir(null),
            "Nominas"
        )

        if (!folder.exists()) {
            folder.mkdirs()
        }

        val pdfFiles = folder.listFiles()

            ?.filter {

                it.extension.lowercase() == "pdf" &&
                        it.name.contains(
                            "recibo_nomina_${employee.id}_"
                        )

            }

            ?.sortedByDescending {

                it.lastModified()

            }

            ?: emptyList()

        if (pdfFiles.isEmpty()) {

            return WhatsAppPdfResult(

                success = false,

                pdfType = WhatsAppPdfType.PAYROLL,

                pdfFile = null,

                message =
                    """
                No existe ningún recibo PDF generado para este empleado.
                """.trimIndent()

            )
        }

        return WhatsAppPdfResult(

            success = true,

            pdfType = WhatsAppPdfType.PAYROLL,

            pdfFile = pdfFiles.first(),

            message =
                """
            Recibo PDF encontrado correctamente.
            """.trimIndent()

        )
    }

    fun getLatestAttendancePdf(
        context: Context,
        employee: Employee
    ): WhatsAppPdfResult {

        val folder = File(
            context.getExternalFilesDir(null),
            "Asistencias"
        )

        if (!folder.exists()) {
            folder.mkdirs()
        }

        val pdfFiles = folder.listFiles()

            ?.filter {

                it.extension.lowercase() == "pdf" &&
                        it.name.contains(
                            "asistencia_${employee.id}_"
                        )

            }

            ?.sortedByDescending {

                it.lastModified()

            }

            ?: emptyList()

        if (pdfFiles.isEmpty()) {

            return WhatsAppPdfResult(

                success = false,

                pdfType = WhatsAppPdfType.ATTENDANCE,

                pdfFile = null,

                message =
                    """
                No existe historial PDF para este empleado.
                """.trimIndent()

            )
        }

        return WhatsAppPdfResult(

            success = true,

            pdfType = WhatsAppPdfType.ATTENDANCE,

            pdfFile = pdfFiles.first(),

            message =
                """
            Historial PDF encontrado.
            """.trimIndent()

        )
    }

    fun getLatestPayrollPreviewPdf(
        context: Context,
        employee: Employee
    ): WhatsAppPdfResult {

        val folder = File(
            context.getExternalFilesDir(null),
            "VistaPreviaNomina"
        )

        if (!folder.exists()) {
            folder.mkdirs()
        }

        val pdfFiles = folder.listFiles()

            ?.filter {

                it.extension.lowercase() == "pdf" &&
                        it.name.contains(
                            "preview_nomina_${employee.id}_"
                        )

            }

            ?.sortedByDescending {

                it.lastModified()

            }

            ?: emptyList()

        if (pdfFiles.isEmpty()) {

            return WhatsAppPdfResult(

                success = false,

                pdfType = WhatsAppPdfType.PAYROLL_PREVIEW,

                pdfFile = null,

                message =
                    """
                No existe vista previa PDF para este empleado.
                """.trimIndent()

            )
        }

        return WhatsAppPdfResult(

            success = true,

            pdfType = WhatsAppPdfType.PAYROLL_PREVIEW,

            pdfFile = pdfFiles.first(),

            message =
                """
            Vista previa PDF encontrada.
            """.trimIndent()

        )
    }
}

enum class WhatsAppPdfType {

    PAYROLL,

    ATTENDANCE,

    PAYROLL_PREVIEW

}

data class WhatsAppPdfResult(

    val success: Boolean,

    val pdfType: WhatsAppPdfType,

    val pdfFile: File?,

    val message: String

)