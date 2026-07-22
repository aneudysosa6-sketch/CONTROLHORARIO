package com.example.controlhorario.ui.employees

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.controlhorario.ui.components.OSINETTextField
import java.text.NumberFormat
import java.util.Locale

@Composable
fun EmployeeListScreen(
    viewModel: EmployeeViewModel,
    onEmployeeClick: (Int) -> Unit,
    onBack: () -> Unit
) {
    val employees by viewModel.employees.collectAsState()
    var searchText by remember { mutableStateOf("") }

    val filteredEmployees = employees.filter { employee ->
        val query = searchText.trim()
        query.isBlank() ||
                employee.employeeCode.contains(query, ignoreCase = true) ||
                employee.nombre.contains(query, ignoreCase = true) ||
                employee.cedula.contains(query, ignoreCase = true) ||
                employee.telefono.contains(query, ignoreCase = true) ||
                employee.cargo.contains(query, ignoreCase = true) ||
                employee.departamento.contains(query, ignoreCase = true)
    }.sortedBy { it.employeeCode.padStart(8, '0') }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
    ) {
        Text("Lista de empleados", style = MaterialTheme.typography.headlineMedium)

        Spacer(modifier = Modifier.height(12.dp))

        Text("👥 Total empleados: ${employees.size}")

        Spacer(modifier = Modifier.height(16.dp))

        OSINETTextField(
            value = searchText,
            onValueChange = { searchText = it },
            label = "🔍 Buscar por código, nombre o cédula",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(20.dp))

        if (filteredEmployees.isEmpty()) {
            Text("No hay empleados para mostrar.")
        } else {
            LazyColumn {
                items(filteredEmployees) { employee ->

                    val sueldoFormateado = NumberFormat
                        .getCurrencyInstance(Locale("es", "DO"))
                        .format(employee.sueldo)

                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(bottom = 14.dp)
                            .clickable {
                                onEmployeeClick(employee.id)
                            },
                        shape = RoundedCornerShape(18.dp),
                        colors = CardDefaults.cardColors(containerColor = Color(0xFF111111)),
                        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp)
                    ) {
                        Column(modifier = Modifier.padding(18.dp)) {
                            Text(
                                text = employee.nombre.uppercase(),
                                style = MaterialTheme.typography.titleLarge,
                                color = Color.White
                            )

                            Spacer(modifier = Modifier.height(10.dp))

                            Text(
                                if (employee.remoteId == null) {
                                    "🔢 Código: pendiente de asignación"
                                } else {
                                    "🔢 Código: ${employee.employeeCode}"
                                },
                                color = Color.White
                            )
                            Text("🪪 Cédula: ${employee.cedula}", color = Color.White)
                            Text("📱 Teléfono: ${employee.telefono}", color = Color.White)
                            Text("💼 Cargo: ${employee.cargo}", color = Color.White)
                            Text("🏢 Departamento: ${employee.departamento}", color = Color.White)
                            Text("💰 Sueldo: $sueldoFormateado", color = Color.White)
                            Spacer(modifier = Modifier.height(10.dp))

                            Text("🟢 Activo", color = Color(0xFF4CAF50))
                        }
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        OutlinedButton(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("⬅ Volver")
        }
    }
}
