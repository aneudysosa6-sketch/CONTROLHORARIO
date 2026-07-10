package com.example.controlhorario.ui.employees

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.EmployeePayrollSettingsEntity
import com.example.controlhorario.engine.GeneralPayrollEngine
import com.example.controlhorario.model.Employee
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETTextField
import java.text.NumberFormat
import java.util.Locale

@Composable
fun EmployeePayrollSettingsScreen(
    employee: Employee?,
    viewModel: EmployeePayrollSettingsViewModel,
    onBack: () -> Unit
) {
    if (employee == null) {
        Column(modifier = Modifier.fillMaxSize().padding(24.dp)) {
            Text("Empleado no encontrado")
            Spacer(modifier = Modifier.height(16.dp))
            OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("⬅ Volver") }
        }
        return
    }

    LaunchedEffect(employee.id) { viewModel.loadSettings(employee.id) }

    val currentSettings by viewModel.settings.collectAsState()
    val currency = NumberFormat.getCurrencyInstance(Locale("es", "DO"))
    val autoNormalHour = remember(employee.sueldo) { if (employee.sueldo > 0.0) employee.sueldo / 15.0 / 8.0 else 0.0 }

    var overtimePercent by remember { mutableStateOf("") }
    var nightPercent by remember { mutableStateOf("") }
    var holidayPercent by remember { mutableStateOf("") }
    var lunchHours by remember { mutableStateOf(employee.lunchHours.toString()) }

    var bonusAmount by remember { mutableStateOf("") }
    var commissionAmount by remember { mutableStateOf("") }
    var otherIncomeAmount by remember { mutableStateOf("") }

    var afpAmount by remember { mutableStateOf("") }
    var sfsAmount by remember { mutableStateOf("") }
    var isrAmount by remember { mutableStateOf("") }

    var totalLoanAmount by remember { mutableStateOf("") }
    var loanPaidAmount by remember { mutableStateOf("") }
    var loanPendingAmount by remember { mutableStateOf("") }
    var loanPayrollDiscountAmount by remember { mutableStateOf("") }

    var totalCreditAmount by remember { mutableStateOf("") }
    var creditPendingAmount by remember { mutableStateOf("") }
    var creditPayrollDiscountAmount by remember { mutableStateOf("") }

    var otherDiscountAmount by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }

    fun numeric(value: String): String = value.filter { it.isDigit() || it == '.' }
    fun toDouble(value: String): Double = value.toDoubleOrNull() ?: 0.0

    val overtimeHour = autoNormalHour + (autoNormalHour * toDouble(overtimePercent) / 100.0)
    val nightHour = autoNormalHour + (autoNormalHour * toDouble(nightPercent) / 100.0)
    val holidayHour = autoNormalHour + (autoNormalHour * toDouble(holidayPercent) / 100.0)
    val calculatedLoanPending = (toDouble(totalLoanAmount) - toDouble(loanPaidAmount)).coerceAtLeast(0.0)
    val calculatedCreditPending = (toDouble(totalCreditAmount) - toDouble(creditPayrollDiscountAmount)).coerceAtLeast(0.0)

    LaunchedEffect(currentSettings) {
        currentSettings?.let { settings ->
            overtimePercent = settings.overtimePercent.toString()
            nightPercent = settings.nightPercent.toString()
            holidayPercent = settings.holidayPercent.toString()
            lunchHours = settings.lunchHours.takeIf { it > 0.0 }?.toString() ?: employee.lunchHours.toString()
            bonusAmount = settings.bonusAmount.toString()
            commissionAmount = settings.commissionAmount.toString()
            otherIncomeAmount = settings.otherIncomeAmount.toString()
            afpAmount = settings.afpAmount.toString()
            sfsAmount = settings.sfsAmount.toString()
            isrAmount = settings.isrAmount.toString()
            totalLoanAmount = settings.totalLoanAmount.toString()
            loanPaidAmount = settings.loanPaidAmount.toString()
            loanPendingAmount = settings.loanPendingAmount.toString()
            loanPayrollDiscountAmount = settings.loanPayrollDiscountAmount.toString()
            totalCreditAmount = settings.totalCreditAmount.toString()
            creditPendingAmount = settings.creditPendingAmount.toString()
            creditPayrollDiscountAmount = settings.creditPayrollDiscountAmount.toString()
            otherDiscountAmount = settings.otherDiscountAmount.toString()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text("Datos de nómina del empleado", style = MaterialTheme.typography.headlineMedium)
        Text(employee.nombre, style = MaterialTheme.typography.titleMedium)
        Text("Sueldo quincenal: ${currency.format(employee.sueldo)}")
        Text("Hora normal automática: ${currency.format(autoNormalHour)}")

        Spacer(modifier = Modifier.height(18.dp))
        Text("Horas y porcentajes", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(lunchHours, { lunchHours = numeric(it) }, "Tiempo de almuerzo en horas", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(overtimePercent, { overtimePercent = numeric(it) }, "% hora extra", Modifier.fillMaxWidth())
        Text("Precio hora extra: ${currency.format(overtimeHour)}")
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(nightPercent, { nightPercent = numeric(it) }, "% hora nocturna", Modifier.fillMaxWidth())
        Text("Precio hora nocturna: ${currency.format(nightHour)}")
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(holidayPercent, { holidayPercent = numeric(it) }, "% hora festiva", Modifier.fillMaxWidth())
        Text("Precio hora festiva: ${currency.format(holidayHour)}")

        Spacer(modifier = Modifier.height(18.dp))
        Text("Ingresos adicionales", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(bonusAmount, { bonusAmount = numeric(it) }, "Incentivo / bono RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(commissionAmount, { commissionAmount = numeric(it) }, "Comisión RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(otherIncomeAmount, { otherIncomeAmount = numeric(it) }, "Otros ingresos RD$", Modifier.fillMaxWidth())

        Spacer(modifier = Modifier.height(18.dp))
        Text("Impuestos manuales", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(afpAmount, { afpAmount = numeric(it) }, "AFP RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(sfsAmount, { sfsAmount = numeric(it) }, "SFS RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(isrAmount, { isrAmount = numeric(it) }, "Impuesto / ISR RD$", Modifier.fillMaxWidth())
        Text("Columna IMPUESTOS del reporte = AFP + SFS")

        Spacer(modifier = Modifier.height(18.dp))
        Text("Préstamo", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(totalLoanAmount, { totalLoanAmount = numeric(it) }, "Total préstamo RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(loanPaidAmount, { loanPaidAmount = numeric(it) }, "Total pagado RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(loanPayrollDiscountAmount, { loanPayrollDiscountAmount = numeric(it) }, "Descuento quincenal RD$", Modifier.fillMaxWidth())
        Text("Pendiente calculado: ${currency.format(calculatedLoanPending)}")

        Spacer(modifier = Modifier.height(18.dp))
        Text("Crédito", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(totalCreditAmount, { totalCreditAmount = numeric(it) }, "Total crédito RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(creditPayrollDiscountAmount, { creditPayrollDiscountAmount = numeric(it) }, "Crédito a descontar RD$", Modifier.fillMaxWidth())
        Text("Crédito pendiente calculado: ${currency.format(calculatedCreditPending)}")

        Spacer(modifier = Modifier.height(18.dp))
        Text("Otros descuentos", style = MaterialTheme.typography.titleMedium)
        Spacer(modifier = Modifier.height(8.dp))
        OSINETTextField(otherDiscountAmount, { otherDiscountAmount = numeric(it) }, "ROTUR/FALT u otros RD$", Modifier.fillMaxWidth())

        if (message.isNotBlank()) {
            Spacer(modifier = Modifier.height(12.dp))
            Text(message)
        }

        Spacer(modifier = Modifier.height(16.dp))
        OSINETButton(
            text = "💾 Guardar datos de nómina",
            onClick = {
                val baseSettings = EmployeePayrollSettingsEntity(
                    employeeId = employee.id,
                    overtimePercent = toDouble(overtimePercent),
                    nightPercent = toDouble(nightPercent),
                    holidayPercent = toDouble(holidayPercent),
                    lunchHours = toDouble(lunchHours),
                    bonusAmount = toDouble(bonusAmount),
                    commissionAmount = toDouble(commissionAmount),
                    otherIncomeAmount = toDouble(otherIncomeAmount),
                    afpAmount = toDouble(afpAmount),
                    sfsAmount = toDouble(sfsAmount),
                    isrAmount = toDouble(isrAmount),
                    totalLoanAmount = toDouble(totalLoanAmount),
                    loanPaidAmount = toDouble(loanPaidAmount),
                    loanPendingAmount = calculatedLoanPending,
                    loanPayrollDiscountAmount = toDouble(loanPayrollDiscountAmount),
                    loanAmount = toDouble(loanPayrollDiscountAmount).coerceAtMost(calculatedLoanPending),
                    totalCreditAmount = toDouble(totalCreditAmount),
                    creditPendingAmount = calculatedCreditPending,
                    creditPayrollDiscountAmount = toDouble(creditPayrollDiscountAmount),
                    oneTimeCreditAmount = toDouble(creditPayrollDiscountAmount).coerceAtMost(toDouble(totalCreditAmount)),
                    otherDiscountAmount = toDouble(otherDiscountAmount)
                )
                viewModel.saveSettings(GeneralPayrollEngine.prepareAutoHourPrices(employee, baseSettings))
                message = "Datos de nómina guardados correctamente ✅"
            }
        )

        Spacer(modifier = Modifier.height(12.dp))
        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("⬅ Volver") }
    }
}
