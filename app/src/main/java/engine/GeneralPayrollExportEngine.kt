package com.example.controlhorario.engine

import android.content.ContentValues
import android.content.Context
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.example.controlhorario.database.CompanySettingsEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.GeneralPayrollExport
import java.io.File
import java.io.FileOutputStream
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object GeneralPayrollExportEngine {

    data class ExportFileResult(
        val success: Boolean,
        val fileName: String = "",
        val displayPath: String = "",
        val errorMessage: String = ""
    )

    fun generateDiscountTemplateCsv(context: Context, employees: List<Employee>): ExportFileResult {
        return try {
            val sortedEmployees = employees
                .filter { it.isActive }
                .sortedBy { it.employeeCode.ifBlank { it.pin }.toIntOrNull() ?: Int.MAX_VALUE }
            val content = buildString {
                appendLine("CODIGO EMPLEADO,NOMBRE EMPLEADO,DESCU-PRES,DESCU-CRED,ROTUR/FALT")
                sortedEmployees.forEach { employee ->
                    appendLine("${csv(employee.employeeCode.ifBlank { employee.pin })},${csv(employee.nombre)},,,")
                }
            }
            saveTextToDownloads(
                context = context,
                fileName = "plantilla_descuentos_nomina.csv",
                mimeType = "text/csv",
                relativeFolder = "OSINET Time/Nominas",
                content = content
            )
        } catch (e: Exception) {
            ExportFileResult(false, errorMessage = e.message ?: "Error generando plantilla.")
        }
    }

    fun generateGeneralPayrollCsv(context: Context, payroll: GeneralPayrollExport): ExportFileResult {
        return try {
            val content = buildString {
                appendLine("PAGOS DE EMPLEADOS,${payroll.periodEnd}")
                appendLine("CODIGOS,EMPLEADOS,SUELDO,H/EXT,FESTIVO,LICENCIA MEDICA,INCENTIVO,TOTAL BRUTO,DESCU-PRES,DESCU-CRED,IMPUESTOS,ROTUR/FALT,TOTAL A PAGAR")
                payroll.rows.forEach { row ->
                    appendLine(
                        listOf(
                            row.employeeCode,
                            row.employeeName,
                            money(row.baseSalary),
                            money(row.overtimePayment),
                            money(row.holidayPayment),
                            money(row.medicalLicensePayment),
                            money(row.incentivePayment),
                            money(row.totalGross),
                            money(row.loanDiscount),
                            money(row.creditDiscount),
                            money(row.taxes),
                            money(row.otherDiscount),
                            money(row.totalPay)
                        ).joinToString(",") { csv(it) }
                    )
                }
                appendLine()
                appendLine("RESUMEN DE NOMINA")
                appendLine("Cantidad de empleados,${payroll.summary.employeeCount}")
                appendLine("Total Sueldos,${money(payroll.summary.totalSalaries)}")
                appendLine("Total Horas Extras,${money(payroll.summary.totalOvertime)}")
                appendLine("Total Licencias Medicas,${money(payroll.summary.totalMedicalLicenses)}")
                appendLine("Total Incentivos,${money(payroll.summary.totalIncentives)}")
                appendLine("Total Prestamos,${money(payroll.summary.totalLoans)}")
                appendLine("Total Creditos,${money(payroll.summary.totalCredits)}")
                appendLine("Total Impuestos,${money(payroll.summary.totalTaxes)}")
                appendLine("Total Otros Descuentos,${money(payroll.summary.totalOtherDiscounts)}")
                appendLine("TOTAL GENERAL PAGADO,${money(payroll.summary.totalGeneralPaid)}")
            }
            saveTextToDownloads(
                context = context,
                fileName = "nomina_general_${payroll.periodStart}_${payroll.periodEnd}.csv".replace("/", "-"),
                mimeType = "text/csv",
                relativeFolder = "OSINET Time/Nominas",
                content = content
            )
        } catch (e: Exception) {
            ExportFileResult(false, errorMessage = e.message ?: "Error generando CSV.")
        }
    }

    fun generateGeneralPayrollPdf(
        context: Context,
        company: CompanySettingsEntity?,
        payroll: GeneralPayrollExport
    ): ExportFileResult {
        return try {
            val document = PdfDocument()
            val titlePaint = Paint().apply { typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textSize = 18f }
            val headerPaint = Paint().apply { typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textSize = 7.5f }
            val textPaint = Paint().apply { typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL); textSize = 7.2f }
            val boldPaint = Paint().apply { typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD); textSize = 8.2f }
            val currency = NumberFormat.getCurrencyInstance(Locale("es", "DO"))

            var pageNumber = 1
            var page = document.startPage(PdfDocument.PageInfo.Builder(842, 595, pageNumber).create())
            var canvas = page.canvas
            var y = 28f

            canvas.drawText(company?.companyName?.ifBlank { "OSINET" } ?: "OSINET", 24f, y, boldPaint)
            canvas.drawText("PAGOS DE EMPLEADOS", 300f, y, titlePaint)
            canvas.drawText(payroll.periodEnd, 720f, y, titlePaint)
            y += 18f
            canvas.drawText("Periodo: ${payroll.periodStart} - ${payroll.periodEnd}", 24f, y, textPaint)
            canvas.drawText("Correo empresa: ${company?.email.orEmpty()}", 600f, y, textPaint)
            y += 18f

            y = drawSummary(canvas, payroll, currency, y, boldPaint, textPaint)
            y += 10f
            y = drawTableHeader(canvas, y, headerPaint)

            payroll.rows.forEachIndexed { index, row ->
                if (y > 565f) {
                    document.finishPage(page)
                    pageNumber++
                    page = document.startPage(PdfDocument.PageInfo.Builder(842, 595, pageNumber).create())
                    canvas = page.canvas
                    y = 30f
                    y = drawTableHeader(canvas, y, headerPaint)
                }
                canvas.drawText(row.employeeCode, 24f, y, textPaint)
                canvas.drawText(row.employeeName.take(20), 74f, y, textPaint)
                canvas.drawText(currency.format(row.baseSalary), 180f, y, textPaint)
                canvas.drawText(currency.format(row.overtimePayment), 250f, y, textPaint)
                canvas.drawText(currency.format(row.holidayPayment), 315f, y, textPaint)
                canvas.drawText(currency.format(row.medicalLicensePayment), 375f, y, textPaint)
                canvas.drawText(currency.format(row.incentivePayment), 440f, y, textPaint)
                canvas.drawText(currency.format(row.totalGross), 505f, y, textPaint)
                canvas.drawText(currency.format(row.loanDiscount), 580f, y, textPaint)
                canvas.drawText(currency.format(row.creditDiscount), 640f, y, textPaint)
                canvas.drawText(currency.format(row.taxes), 695f, y, textPaint)
                canvas.drawText(currency.format(row.otherDiscount), 735f, y, textPaint)
                canvas.drawText(currency.format(row.totalPay), 780f, y, textPaint)
                y += 14f
            }

            document.finishPage(page)

            val fileName = "nomina_general_${payroll.periodStart}_${payroll.periodEnd}.pdf".replace("/", "-")
            savePdfToDownloads(context, document, fileName)
        } catch (e: Exception) {
            ExportFileResult(false, errorMessage = e.message ?: "Error generando PDF.")
        }
    }

    private fun drawSummary(
        canvas: android.graphics.Canvas,
        payroll: GeneralPayrollExport,
        currency: NumberFormat,
        yStart: Float,
        boldPaint: Paint,
        textPaint: Paint
    ): Float {
        var y = yStart
        canvas.drawText("RESUMEN DE NÓMINA", 24f, y, boldPaint); y += 13f
        canvas.drawText("Cantidad de empleados: ${payroll.summary.employeeCount}", 24f, y, textPaint)
        canvas.drawText("Total Sueldos: ${currency.format(payroll.summary.totalSalaries)}", 210f, y, textPaint)
        canvas.drawText("Total Horas Extras: ${currency.format(payroll.summary.totalOvertime)}", 420f, y, textPaint)
        canvas.drawText("Total Lic. Médicas: ${currency.format(payroll.summary.totalMedicalLicenses)}", 625f, y, textPaint); y += 13f
        canvas.drawText("Total Incentivos: ${currency.format(payroll.summary.totalIncentives)}", 24f, y, textPaint)
        canvas.drawText("Total Préstamos: ${currency.format(payroll.summary.totalLoans)}", 210f, y, textPaint)
        canvas.drawText("Total Créditos: ${currency.format(payroll.summary.totalCredits)}", 420f, y, textPaint)
        canvas.drawText("Total Impuestos: ${currency.format(payroll.summary.totalTaxes)}", 625f, y, textPaint)
        y += 13f
        canvas.drawText("Total Otros: ${currency.format(payroll.summary.totalOtherDiscounts)}", 24f, y, textPaint); y += 13f
        canvas.drawText("TOTAL GENERAL PAGADO: ${currency.format(payroll.summary.totalGeneralPaid)}", 24f, y, boldPaint)
        return y + 13f
    }

    private fun drawTableHeader(canvas: android.graphics.Canvas, yStart: Float, paint: Paint): Float {
        val y = yStart
        canvas.drawText("CODIGOS", 24f, y, paint)
        canvas.drawText("EMPLEADOS", 74f, y, paint)
        canvas.drawText("SUELDO", 180f, y, paint)
        canvas.drawText("H/EXT", 250f, y, paint)
        canvas.drawText("FESTIVO", 315f, y, paint)
        canvas.drawText("LIC.MED", 375f, y, paint)
        canvas.drawText("INCENTIVO", 440f, y, paint)
        canvas.drawText("TOTAL BRUTO", 505f, y, paint)
        canvas.drawText("DESCU-PRES", 580f, y, paint)
        canvas.drawText("DESCU-CRED", 640f, y, paint)
        canvas.drawText("IMP.", 695f, y, paint)
        canvas.drawText("OTROS", 735f, y, paint)
        canvas.drawText("TOTAL A PAGAR", 780f, y, paint)
        return y + 14f
    }

    private fun saveTextToDownloads(context: Context, fileName: String, mimeType: String, relativeFolder: String, content: String): ExportFileResult {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, mimeType)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/$relativeFolder")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("No se pudo crear el archivo.")
            context.contentResolver.openOutputStream(uri)?.use { it.write(content.toByteArray()) }
                ?: throw Exception("No se pudo escribir el archivo.")
            values.clear(); values.put(MediaStore.Downloads.IS_PENDING, 0)
            context.contentResolver.update(uri, values, null, null)
        } else {
            val folder = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), relativeFolder)
            if (!folder.exists()) folder.mkdirs()
            File(folder, fileName).writeText(content)
        }
        return ExportFileResult(true, fileName, "Descargas/$relativeFolder/$fileName")
    }

    private fun savePdfToDownloads(context: Context, document: PdfDocument, fileName: String): ExportFileResult {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/OSINET Time/Nominas")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = context.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw Exception("No se pudo crear el PDF.")
            context.contentResolver.openOutputStream(uri)?.use { document.writeTo(it) }
                ?: throw Exception("No se pudo escribir el PDF.")
            values.clear(); values.put(MediaStore.Downloads.IS_PENDING, 0)
            context.contentResolver.update(uri, values, null, null)
        } else {
            val folder = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "OSINET Time/Nominas")
            if (!folder.exists()) folder.mkdirs()
            FileOutputStream(File(folder, fileName)).use { document.writeTo(it) }
        }
        document.close()
        return ExportFileResult(true, fileName, "Descargas/OSINET Time/Nominas/$fileName")
    }

    private fun money(value: Double): String = NumberFormat.getCurrencyInstance(Locale("es", "DO")).format(value)
    private fun csv(value: String): String = "\"${value.replace("\"", "\"\"")}\""
}
