package com.example.controlhorario.ui.employees

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.PayrollHistoryEntity
import com.example.controlhorario.model.Employee
import java.text.NumberFormat
import java.util.Locale

@Composable
fun EmployeePayrollHistoryScreen(
    employee: Employee?,
    viewModel: PayrollHistoryViewModel,
    onBack: () -> Unit
) {
    if (employee == null) {
        Column(modifier = Modifier.fillMaxSize().padding(24.dp)) {
            Text("Empleado no encontrado")
            Spacer(modifier = Modifier.height(16.dp))
            OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                Text("⬅ Volver")
            }
        }
        return
    }

    LaunchedEffect(employee.id) {
        viewModel.loadHistory(employee.id)
    }

    val history by viewModel.history.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text("Historial de nómina", style = MaterialTheme.typography.headlineMedium)

        Spacer(modifier = Modifier.height(6.dp))

        Text(employee.nombre, style = MaterialTheme.typography.titleMedium)

        Spacer(modifier = Modifier.height(20.dp))

        if (history.isEmpty()) {
            Text("Este empleado todavía no tiene nóminas generadas.")
        } else {
            history.forEach { item ->
                PayrollHistoryCard(item)
                Spacer(modifier = Modifier.height(12.dp))
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
            Text("⬅ Volver")
        }
    }
}

@Composable
private fun PayrollHistoryCard(
    item: PayrollHistoryEntity
) {
    val currency = NumberFormat.getCurrencyInstance(Locale("es", "DO"))

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF111111))
    ) {
        Column(modifier = Modifier.padding(18.dp)) {
            Text("📅 Período: ${item.periodStart} - ${item.periodEnd}", color = Color.White)
            Text("🕒 Generada: ${item.createdAt}", color = Color.White)
            Text("💵 Devengado: ${currency.format(item.totalIncome)}", color = Color.White)
            Text("📉 Descuentos: ${currency.format(item.totalDiscounts)}", color = Color.White)
            Text("💳 Crédito temporal: ${currency.format(item.oneTimeCreditAmount)}", color = Color.White)

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "✅ Neto pagado: ${currency.format(item.netPay)}",
                color = Color(0xFF4CAF50),
                style = MaterialTheme.typography.titleMedium
            )
        }
    }
}