package com.example.controlhorario.engine

import android.content.ContentValues
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import com.example.controlhorario.database.CompanySettingsEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.PayrollResult
import java.io.File
import java.io.FileOutputStream
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

object PayrollPdfEngine {

    data class PdfGenerationResult(
        val success: Boolean,
        val fileName: String,
        val displayPath: String,
        val errorMessage: String = ""
    )

    fun generatePayrollReceiptPdf(
        context: Context,
        company: CompanySettingsEntity?,
        employee: Employee,
        result: PayrollResult
    ): PdfGenerationResult {
        return try {
            val document = PdfDocument()

            val pageInfo = PdfDocument.PageInfo.Builder(595, 842, 1).create()
            val page = document.startPage(pageInfo)
            val canvas = page.canvas

            drawReceipt(
                canvas = canvas,
                company = company,
                employee = employee,
                result = result
            )

            document.finishPage(page)

            val fileName = "recibo_nomina_${employee.id}_${result.periodStart}_${result.periodEnd}.pdf"
                .replace(" ", "_")
                .replace("/", "-")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                saveWithMediaStore(
                    context = context,
                    document = document,
                    fileName = fileName
                )
            } else {
                saveLegacy(
                    document = document,
                    fileName = fileName
                )
            }
        } catch (e: Exception) {
            PdfGenerationResult(
                success = false,
                fileName = "",
                displayPath = "",
                errorMessage = e.message ?: "Error desconocido al generar el PDF."
            )
        }
    }

    private fun saveWithMediaStore(
        context: Context,
        document: PdfDocument,
        fileName: String
    ): PdfGenerationResult {
        val resolver = context.contentResolver

        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
            put(
                MediaStore.Downloads.RELATIVE_PATH,
                Environment.DIRECTORY_DOWNLOADS + "/OSINET Time/Nominas"
            )
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val uri = resolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            contentValues
        ) ?: throw Exception("No se pudo crear el archivo PDF en Descargas.")

        resolver.openOutputStream(uri)?.use { output ->
            document.writeTo(output)
        } ?: throw Exception("No se pudo abrir el archivo PDF para escribir.")

        contentValues.clear()
        contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(uri, contentValues, null, null)

        document.close()

        return PdfGenerationResult(
            success = true,
            fileName = fileName,
            displayPath = "Descargas/OSINET Time/Nominas/$fileName"
        )
    }

    private fun saveLegacy(
        document: PdfDocument,
        fileName: String
    ): PdfGenerationResult {
        val downloadsFolder = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS
        )

        val osinetFolder = File(downloadsFolder, "OSINET Time/Nominas")

        if (!osinetFolder.exists()) {
            osinetFolder.mkdirs()
        }

        val file = File(osinetFolder, fileName)

        FileOutputStream(file).use { output ->
            document.writeTo(output)
        }

        document.close()

        return PdfGenerationResult(
            success = true,
            fileName = fileName,
            displayPath = file.absolutePath
        )
    }

    private fun drawReceipt(
        canvas: Canvas,
        company: CompanySettingsEntity?,
        employee: Employee,
        result: PayrollResult
    ) {
        val titlePaint = Paint().apply {
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textSize = 20f
        }

        val sectionPaint = Paint().apply {
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textSize = 14f
        }

        val textPaint = Paint().apply {
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            textSize = 11f
        }

        val boldPaint = Paint().apply {
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            textSize = 11f
        }

        val currency = NumberFormat.getCurrencyInstance(Locale("es", "DO"))

        var y = 45f

        canvas.drawText(
            company?.companyName?.ifBlank { "OSINET TIME" } ?: "OSINET TIME",
            40f,
            y,
            titlePaint
        )

        y += 22f

        canvas.drawText("RNC: ${company?.rnc ?: ""}", 40f, y, textPaint)
        y += 16f
        canvas.drawText("Teléfono: ${company?.phone ?: ""}", 40f, y, textPaint)
        y += 16f
        canvas.drawText("Email: ${company?.email ?: ""}", 40f, y, textPaint)
        y += 16f
        canvas.drawText("Dirección: ${company?.address ?: ""}", 40f, y, textPaint)

        y += 35f

        canvas.drawLine(40f, y, 555f, y, textPaint)

        y += 28f

        canvas.drawText("RECIBO DE NÓMINA", 210f, y, titlePaint)

        y += 35f

        canvas.drawText("Empleado: ${employee.nombre}", 40f, y, boldPaint)
        y += 18f
        canvas.drawText("Cédula: ${employee.cedula}", 40f, y, textPaint)
        y += 18f
        canvas.drawText("Cargo: ${employee.cargo}", 40f, y, textPaint)
        y += 18f
        canvas.drawText("Departamento: ${employee.departamento}", 40f, y, textPaint)
        y += 18f
        canvas.drawText("Período: ${result.periodStart} - ${result.periodEnd}", 40f, y, textPaint)

        y += 30f

        y = drawSectionTitle(canvas, "HORAS TRABAJADAS", y, sectionPaint)

        y = drawLine(canvas, "Horas normales", result.normalHours.toString(), y, textPaint)
        y = drawLine(canvas, "Horas extras", result.overtimeHours.toString(), y, textPaint)
        y = drawLine(canvas, "Horas nocturnas", result.nightHours.toString(), y, textPaint)
        y = drawLine(canvas, "Horas domingo", result.sundayHours.toString(), y, textPaint)
        y = drawLine(canvas, "Horas feriado", result.holidayHours.toString(), y, textPaint)
        y = drawLine(canvas, "Total horas", result.totalWorkedHours.toString(), y, boldPaint)

        y += 18f

        y = drawSectionTitle(canvas, "INGRESOS", y, sectionPaint)

        y = drawLine(canvas, "Sueldo base", currency.format(result.baseSalary), y, textPaint)
        y = drawLine(canvas, "Pago horas normales", currency.format(result.normalHourPayment), y, textPaint)
        y = drawLine(canvas, "Pago horas extras", currency.format(result.overtimePayment), y, textPaint)
        y = drawLine(canvas, "Pago horas nocturnas", currency.format(result.nightPayment), y, textPaint)
        y = drawLine(canvas, "Pago domingos", currency.format(result.sundayPayment), y, textPaint)
        y = drawLine(canvas, "Pago feriados", currency.format(result.holidayPayment), y, textPaint)
        y = drawLine(canvas, "Bonos", currency.format(result.bonusAmount), y, textPaint)
        y = drawLine(canvas, "Comisiones", currency.format(result.commissionAmount), y, textPaint)
        y = drawLine(canvas, "Otros ingresos", currency.format(result.otherIncomeAmount), y, textPaint)
        y = drawLine(canvas, "TOTAL DEVENGADO", currency.format(result.totalIncome), y, boldPaint)

        y += 18f

        y = drawSectionTitle(canvas, "DESCUENTOS", y, sectionPaint)

        y = drawLine(canvas, "AFP", currency.format(result.afpAmount), y, textPaint)
        y = drawLine(canvas, "SFS", currency.format(result.sfsAmount), y, textPaint)
        y = drawLine(canvas, "ISR", currency.format(result.isrAmount), y, textPaint)
        y = drawLine(canvas, "Préstamo", currency.format(result.loanAmount), y, textPaint)
        y = drawLine(canvas, "Cooperativa", currency.format(result.cooperativeAmount), y, textPaint)
        y = drawLine(canvas, "Seguro privado", currency.format(result.privateInsuranceAmount), y, textPaint)
        y = drawLine(canvas, "Celular", currency.format(result.phoneDiscountAmount), y, textPaint)
        y = drawLine(canvas, "Comedor", currency.format(result.foodDiscountAmount), y, textPaint)
        y = drawLine(canvas, "Transporte", currency.format(result.transportDiscountAmount), y, textPaint)
        y = drawLine(canvas, "Crédito temporal", currency.format(result.oneTimeCreditAmount), y, textPaint)
        y = drawLine(canvas, "Otros descuentos", currency.format(result.otherDiscountAmount), y, textPaint)
        y = drawLine(canvas, "TOTAL DESCUENTOS", currency.format(result.totalDiscounts), y, boldPaint)

        y += 25f

        canvas.drawLine(40f, y, 555f, y, textPaint)
        y += 28f

        canvas.drawText("NETO A PAGAR:", 40f, y, titlePaint)
        canvas.drawText(currency.format(result.netPay), 380f, y, titlePaint)

        y += 70f

        canvas.drawLine(60f, y, 230f, y, textPaint)
        canvas.drawLine(350f, y, 520f, y, textPaint)

        y += 18f

        canvas.drawText("Firma empleado", 95f, y, textPaint)
        canvas.drawText("Firma responsable", 380f, y, textPaint)

        val createdAt = SimpleDateFormat(
            "yyyy-MM-dd HH:mm:ss",
            Locale.getDefault()
        ).format(Date())

        canvas.drawText("Generado: $createdAt", 40f, 810f, textPaint)
    }

    private fun drawSectionTitle(
        canvas: Canvas,
        title: String,
        y: Float,
        paint: Paint
    ): Float {
        canvas.drawText(title, 40f, y, paint)
        return y + 22f
    }

    private fun drawLine(
        canvas: Canvas,
        label: String,
        value: String,
        y: Float,
        paint: Paint
    ): Float {
        canvas.drawText(label, 55f, y, paint)
        canvas.drawText(value, 390f, y, paint)
        return y + 16f
    }
}