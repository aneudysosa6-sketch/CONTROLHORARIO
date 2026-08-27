package com.example.controlhorario.ui.payroll

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETTextField
import java.text.NumberFormat
import java.util.Locale

@Composable
fun GeneralPayrollScreen(
    viewModel: GeneralPayrollViewModel,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val state by viewModel.state.collectAsState()
    val currency = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("es-DO"))

    var periodStart by remember { mutableStateOf(GeneralPayrollViewModel.defaultStartDate()) }
    var periodEnd by remember { mutableStateOf(GeneralPayrollViewModel.defaultEndDate()) }

    val uploadLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) {
            viewModel.uploadTemplate(context, uri)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text("GENERAL NÓMINA", style = MaterialTheme.typography.headlineMedium)
        Text("Generación de nómina general desde datos de empleados")

        Spacer(Modifier.height(16.dp))

        Row(modifier = Modifier.fillMaxWidth()) {
            OSINETButton(
                text = "Quincena actual",
                modifier = Modifier.weight(1f),
                onClick = {
                    periodStart = GeneralPayrollViewModel.currentFortnightStartDate()
                    periodEnd = GeneralPayrollViewModel.currentFortnightEndDate()
                }
            )
            Spacer(Modifier.padding(4.dp))
            OSINETButton(
                text = "Mes actual",
                modifier = Modifier.weight(1f),
                onClick = {
                    periodStart = GeneralPayrollViewModel.defaultStartDate()
                    periodEnd = GeneralPayrollViewModel.defaultEndDate()
                }
            )
        }

        Spacer(Modifier.height(12.dp))

        OSINETTextField(
            value = periodStart,
            onValueChange = { periodStart = it },
            label = "Fecha inicio yyyy-MM-dd",
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(8.dp))
        OSINETTextField(
            value = periodEnd,
            onValueChange = { periodEnd = it },
            label = "Fecha final yyyy-MM-dd",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(Modifier.height(16.dp))

        OSINETButton(
            text = "Descargar plantilla",
            onClick = { viewModel.downloadTemplate(context) }
        )
        Spacer(Modifier.height(8.dp))
        OSINETButton(
            text = "Subir plantilla",
            onClick = {
                uploadLauncher.launch(
                    arrayOf(
                        "text/*",
                        "text/csv",
                        "application/csv",
                        "application/vnd.ms-excel",
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                    )
                )
            }
        )

        Spacer(Modifier.height(16.dp))

        OSINETButton(
            text = "Generar nómina general",
            onClick = { viewModel.generatePayrollAndFiles(context, periodStart, periodEnd) }
        )
        Spacer(Modifier.height(8.dp))
        OSINETButton(
            text = "Descargar nómina",
            enabled = state.templateUploaded && !state.templateHasErrors,
            onClick = { viewModel.generatePayrollAndFiles(context, periodStart, periodEnd) }
        )

        state.message.takeIf { it.isNotBlank() }?.let {
            Spacer(Modifier.height(12.dp))
            Text(it)
        }

        state.payroll?.let { payroll ->
            Spacer(Modifier.height(16.dp))
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Resumen de nómina", style = MaterialTheme.typography.titleMedium)
                    Text("Cantidad de empleados: ${payroll.summary.employeeCount}")
                    Text("Total sueldos: ${currency.format(payroll.summary.totalSalaries)}")
                    Text("Total horas extras: ${currency.format(payroll.summary.totalOvertime)}")
                    Text("Total licencias médicas: ${currency.format(payroll.summary.totalMedicalLicenses)}")
                    Text("Total incentivos: ${currency.format(payroll.summary.totalIncentives)}")
                    Text("Total préstamos: ${currency.format(payroll.summary.totalLoans)}")
                    Text("Total créditos: ${currency.format(payroll.summary.totalCredits)}")
                    Text("Total impuestos: ${currency.format(payroll.summary.totalTaxes)}")
                    Text("Total otros descuentos: ${currency.format(payroll.summary.totalOtherDiscounts)}")
                    Text("TOTAL GENERAL PAGADO: ${currency.format(payroll.summary.totalGeneralPaid)}")
                    if (state.lastPdfPath.isNotBlank()) Text("PDF: ${state.lastPdfPath}")
                    if (state.lastCsvPath.isNotBlank()) Text("Excel/CSV: ${state.lastCsvPath}")
                }
            }

            Spacer(Modifier.height(12.dp))
            OSINETButton("Regenerar PDF", onClick = { viewModel.exportPdf(context) })
            Spacer(Modifier.height(8.dp))
            OSINETButton("Regenerar Excel/CSV", onClick = { viewModel.exportCsv(context) })
            Spacer(Modifier.height(8.dp))
            OSINETButton("Aplicar saldos de préstamos y créditos", onClick = { viewModel.saveBalancesAfterPayroll() })

            Spacer(Modifier.height(16.dp))
            Text("Exportación local", style = MaterialTheme.typography.titleMedium)
            Text("La nómina se genera dentro del ERP. Para compartirla, use el PDF o Excel/CSV exportado.")
        }

        Spacer(Modifier.height(16.dp))
        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("Volver") }
    }
}
