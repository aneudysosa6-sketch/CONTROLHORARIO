package com.example.controlhorario.ui.settings

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
import com.example.controlhorario.database.PayrollSettingsEntity
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun PayrollSettingsScreen(
    viewModel: PayrollSettingsViewModel,
    onBack: () -> Unit
) {
    val currentSettings by viewModel.payrollSettings.collectAsState()

    var normalHourPrice by remember { mutableStateOf("") }
    var overtimeHourPrice by remember { mutableStateOf("") }
    var nightHourPrice by remember { mutableStateOf("") }
    var sundayHourPrice by remember { mutableStateOf("") }
    var holidayHourPrice by remember { mutableStateOf("") }

    var bonusAmount by remember { mutableStateOf("") }
    var commissionAmount by remember { mutableStateOf("") }
    var otherIncomeAmount by remember { mutableStateOf("") }

    var afpAmount by remember { mutableStateOf("") }
    var sfsAmount by remember { mutableStateOf("") }
    var isrAmount by remember { mutableStateOf("") }
    var loanAmount by remember { mutableStateOf("") }
    var otherDiscountAmount by remember { mutableStateOf("") }

    var message by remember { mutableStateOf("") }

    LaunchedEffect(currentSettings) {
        currentSettings?.let { settings ->
            normalHourPrice = settings.normalHourPrice.toString()
            overtimeHourPrice = settings.overtimeHourPrice.toString()
            nightHourPrice = settings.nightHourPrice.toString()
            sundayHourPrice = settings.sundayHourPrice.toString()
            holidayHourPrice = settings.holidayHourPrice.toString()

            bonusAmount = settings.bonusAmount.toString()
            commissionAmount = settings.commissionAmount.toString()
            otherIncomeAmount = settings.otherIncomeAmount.toString()

            afpAmount = settings.afpAmount.toString()
            sfsAmount = settings.sfsAmount.toString()
            isrAmount = settings.isrAmount.toString()
            loanAmount = settings.loanAmount.toString()
            otherDiscountAmount = settings.otherDiscountAmount.toString()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text(
            text = "Configuración de Nómina RD",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text("Modo mixto: la app calculará automático, pero estos valores se podrán editar en RD$.")

        Spacer(modifier = Modifier.height(20.dp))

        Text("Pago por horas", style = MaterialTheme.typography.titleMedium)

        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(normalHourPrice, { normalHourPrice = it }, "Precio hora normal RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(overtimeHourPrice, { overtimeHourPrice = it }, "Precio hora extra RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(nightHourPrice, { nightHourPrice = it }, "Precio hora nocturna RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(sundayHourPrice, { sundayHourPrice = it }, "Precio hora domingo RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(holidayHourPrice, { holidayHourPrice = it }, "Precio hora feriado RD$", Modifier.fillMaxWidth())

        Spacer(modifier = Modifier.height(20.dp))

        Text("Ingresos adicionales", style = MaterialTheme.typography.titleMedium)

        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(bonusAmount, { bonusAmount = it }, "Bono RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(commissionAmount, { commissionAmount = it }, "Comisión RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(otherIncomeAmount, { otherIncomeAmount = it }, "Otros ingresos RD$", Modifier.fillMaxWidth())

        Spacer(modifier = Modifier.height(20.dp))

        Text("Descuentos manuales en RD$", style = MaterialTheme.typography.titleMedium)

        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(afpAmount, { afpAmount = it }, "AFP RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(sfsAmount, { sfsAmount = it }, "SFS RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(isrAmount, { isrAmount = it }, "ISR RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(loanAmount, { loanAmount = it }, "Préstamos RD$", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(otherDiscountAmount, { otherDiscountAmount = it }, "Otros descuentos RD$", Modifier.fillMaxWidth())

        Spacer(modifier = Modifier.height(16.dp))

        if (message.isNotBlank()) {
            Text(message)
            Spacer(modifier = Modifier.height(12.dp))
        }

        OSINETButton(
            text = "💾 Guardar configuración",
            onClick = {
                val settings = PayrollSettingsEntity(
                    normalHourPrice = normalHourPrice.toDoubleOrNull() ?: 0.0,
                    overtimeHourPrice = overtimeHourPrice.toDoubleOrNull() ?: 0.0,
                    nightHourPrice = nightHourPrice.toDoubleOrNull() ?: 0.0,
                    sundayHourPrice = sundayHourPrice.toDoubleOrNull() ?: 0.0,
                    holidayHourPrice = holidayHourPrice.toDoubleOrNull() ?: 0.0,
                    bonusAmount = bonusAmount.toDoubleOrNull() ?: 0.0,
                    commissionAmount = commissionAmount.toDoubleOrNull() ?: 0.0,
                    otherIncomeAmount = otherIncomeAmount.toDoubleOrNull() ?: 0.0,
                    afpAmount = afpAmount.toDoubleOrNull() ?: 0.0,
                    sfsAmount = sfsAmount.toDoubleOrNull() ?: 0.0,
                    isrAmount = isrAmount.toDoubleOrNull() ?: 0.0,
                    loanAmount = loanAmount.toDoubleOrNull() ?: 0.0,
                    otherDiscountAmount = otherDiscountAmount.toDoubleOrNull() ?: 0.0
                )

                viewModel.savePayrollSettings(settings)
                message = "Configuración de nómina guardada correctamente ✅"
            }
        )

        Spacer(modifier = Modifier.height(12.dp))

        OutlinedButton(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("⬅ Volver")
        }
    }
}