package com.example.controlhorario.ui.employees

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.controlhorario.model.Employee
import com.example.controlhorario.session.UserSessionManager
import com.example.controlhorario.ui.components.OSINETTextField
import java.text.NumberFormat
import java.util.Locale

enum class EmployeeDirectoryScope {
    ACTIVE,
    TERMINATED,
}

@Composable
fun EmployeeListScreen(
    viewModel: EmployeeViewModel,
    onEmployeeClick: (Int) -> Unit,
    onBack: () -> Unit,
    directoryScope: EmployeeDirectoryScope = EmployeeDirectoryScope.ACTIVE,
) {
    val activeEmployees by viewModel.employees.collectAsState()
    val terminatedEmployees by viewModel.terminatedEmployees.collectAsState()
    val currentUser by UserSessionManager.currentUser.collectAsState()
    var searchText by remember { mutableStateOf("") }
    var teamOnly by remember(directoryScope) { mutableStateOf(false) }

    val source = when (directoryScope) {
        EmployeeDirectoryScope.ACTIVE -> activeEmployees
        EmployeeDirectoryScope.TERMINATED -> terminatedEmployees
    }
    val hasTeamScope = (currentUser?.departmentId ?: 0) > 0 || (currentUser?.branchId ?: 0) > 0
    val visibleEmployees = source
        .asSequence()
        .filter { employee -> !teamOnly || belongsToMyTeam(employee, currentUser?.departmentId ?: 0, currentUser?.branchId ?: 0) }
        .filter { employee ->
            val query = searchText.trim()
            query.isBlank() ||
                employee.employeeCode.contains(query, ignoreCase = true) ||
                employee.nombre.contains(query, ignoreCase = true) ||
                employee.cedula.contains(query, ignoreCase = true) ||
                employee.telefono.contains(query, ignoreCase = true) ||
                employee.cargo.contains(query, ignoreCase = true) ||
                employee.departamento.contains(query, ignoreCase = true)
        }
        .sortedBy { it.employeeCode.padStart(8, '0') }
        .toList()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
    ) {
        Text(
            text = if (directoryScope == EmployeeDirectoryScope.TERMINATED) {
                "Empleados dados de baja"
            } else {
                "Empleados"
            },
            style = MaterialTheme.typography.headlineMedium,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = if (directoryScope == EmployeeDirectoryScope.TERMINATED) {
                "Empleados inactivos o desvinculados"
            } else {
                "Directorio de empleados activos"
            },
        )
        Spacer(modifier = Modifier.height(12.dp))

        Row(modifier = Modifier.fillMaxWidth()) {
            Button(
                onClick = { teamOnly = false },
                modifier = Modifier.weight(1f),
                enabled = !teamOnly,
            ) {
                Text("Todos")
            }
            Spacer(modifier = Modifier.weight(0.05f))
            OutlinedButton(
                onClick = { teamOnly = true },
                modifier = Modifier.weight(1f),
                enabled = !teamOnly,
            ) {
                Text("Solo mi equipo")
            }
        }

        if (teamOnly && !hasTeamScope) {
            Spacer(modifier = Modifier.height(8.dp))
            Text("No tienes un departamento o sucursal asignados para filtrar tu equipo.")
        }

        Spacer(modifier = Modifier.height(12.dp))
        Text("Total empleados: ${visibleEmployees.size}")

        Spacer(modifier = Modifier.height(16.dp))
        OSINETTextField(
            value = searchText,
            onValueChange = { searchText = it },
            label = "Buscar por código, nombre o cédula",
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(modifier = Modifier.height(20.dp))

        if (visibleEmployees.isEmpty()) {
            Text(
                if (teamOnly) "No hay empleados de tu equipo para mostrar."
                else "No hay empleados para mostrar.",
            )
        } else {
            LazyColumn(modifier = Modifier.weight(1f, fill = false)) {
                items(visibleEmployees, key = Employee::id) { employee ->
                    EmployeeDirectoryCard(
                        employee = employee,
                        terminated = directoryScope == EmployeeDirectoryScope.TERMINATED,
                        onClick = { onEmployeeClick(employee.id) },
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))
        OutlinedButton(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Volver")
        }
    }
}

private fun belongsToMyTeam(employee: Employee, departmentId: Int, branchId: Int): Boolean = when {
    departmentId > 0 -> employee.departmentId == departmentId
    branchId > 0 -> employee.branchId == branchId
    else -> false
}

@Composable
private fun EmployeeDirectoryCard(
    employee: Employee,
    terminated: Boolean,
    onClick: () -> Unit,
) {
    val salary = NumberFormat.getCurrencyInstance(Locale.forLanguageTag("es-DO")).format(employee.sueldo)
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 14.dp)
            .clickable(onClick = onClick),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF111111)),
        elevation = CardDefaults.cardElevation(defaultElevation = 6.dp),
    ) {
        Column(modifier = Modifier.padding(18.dp)) {
            Text(
                text = employee.nombre.uppercase(),
                style = MaterialTheme.typography.titleLarge,
                color = Color.White,
            )
            Spacer(modifier = Modifier.height(10.dp))
            Text(
                if (employee.remoteId == null) {
                    "Código: pendiente de asignación"
                } else {
                    "Código: ${employee.employeeCode}"
                },
                color = Color.White,
            )
            Text("Cédula: ${employee.cedula}", color = Color.White)
            Text("Teléfono: ${employee.telefono}", color = Color.White)
            Text("Cargo: ${employee.cargo}", color = Color.White)
            Text("Departamento: ${employee.departamento}", color = Color.White)
            Text("Sueldo: ${salary}", color = Color.White)
            Spacer(modifier = Modifier.height(10.dp))
            Text(
                if (terminated) "Dado de baja" else "Activo",
                color = if (terminated) Color(0xFFFF9800) else Color(0xFF4CAF50),
            )
        }
    }
}
