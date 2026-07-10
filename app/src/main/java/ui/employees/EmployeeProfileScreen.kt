package com.example.controlhorario.ui.employees

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.BranchEntity
import com.example.controlhorario.database.DepartmentEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.ui.components.OSINETButton
import java.text.NumberFormat
import java.util.Locale

@Composable
fun EmployeeProfileScreen(
    employee: Employee?,
    branches: List<BranchEntity>,
    departments: List<DepartmentEntity>,
    onEmployeeFileClick: () -> Unit,
    onAttendanceHistoryClick: () -> Unit,
    onEmployeePayrollSettingsClick: () -> Unit,
    onPayrollPreviewClick: () -> Unit,
    onPayrollHistoryClick: () -> Unit,
    onFingerprintClick: () -> Unit,
    onEditEmployeeClick: () -> Unit = {},
    onPermissionsClick: () -> Unit = {},
    onWarningsClick: () -> Unit = {},
    onBack: () -> Unit
) {
    if (employee == null) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text("Empleado no encontrado")

            Spacer(modifier = Modifier.height(16.dp))

            OutlinedButton(onClick = onBack) {
                Text("⬅ Volver")
            }
        }
        return
    }

    val branchName = branches
        .firstOrNull { it.id == employee.branchId }
        ?.name
        ?: "Sucursal no encontrada"

    val departmentName = departments
        .firstOrNull { it.id == employee.departmentId }
        ?.name
        ?: employee.departamento.ifBlank { "Departamento no encontrado" }

    val sueldoFormateado = NumberFormat
        .getCurrencyInstance(Locale("es", "DO"))
        .format(employee.sueldo)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Card(
            shape = CircleShape,
            colors = CardDefaults.cardColors(
                containerColor = Color(0xFF4CAF50)
            ),
            modifier = Modifier.size(90.dp)
        ) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "👤",
                    style = MaterialTheme.typography.headlineLarge
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = employee.nombre.uppercase(),
            style = MaterialTheme.typography.headlineSmall
        )

        Text(
            text = "🟢 Activo",
            color = Color(0xFF4CAF50)
        )

        Spacer(modifier = Modifier.height(20.dp))

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(18.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color(0xFF111111)
            )
        ) {
            Column(
                modifier = Modifier.padding(18.dp)
            ) {
                Text("👤 Nombre: ${employee.nombre}", color = Color.White)
                Text("🪪 Cédula: ${employee.cedula}", color = Color.White)
                Text("📱 Teléfono: ${employee.telefono}", color = Color.White)
                Text("🏢 Sucursal: $branchName", color = Color.White)
                Text("🏬 Departamento: $departmentName", color = Color.White)
                Text("💼 Cargo: ${employee.cargo}", color = Color.White)
                Text("💰 Sueldo: $sueldoFormateado", color = Color.White)
                Text("🔐 PIN: ${employee.pin}", color = Color.White)
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        OSINETButton(
            text = "📂 Expediente Digital",
            onClick = onEmployeeFileClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "✏️ Editar empleado",
            onClick = onEditEmployeeClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "👆 Registrar huella",
            onClick = onFingerprintClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "🕒 Historial de asistencia",
            onClick = onAttendanceHistoryClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "💰 Configuración de nómina",
            onClick = onEmployeePayrollSettingsClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "🧮 Vista previa de nómina",
            onClick = onPayrollPreviewClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "📑 Historial de nómina",
            onClick = onPayrollHistoryClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "📄 Permisos",
            onClick = onPermissionsClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "⚠️ Amonestaciones",
            onClick = onWarningsClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "📁 Documentos",
            onClick = onEmployeeFileClick
        )

        Spacer(modifier = Modifier.height(20.dp))

        OutlinedButton(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("⬅ Volver")
        }
    }
}