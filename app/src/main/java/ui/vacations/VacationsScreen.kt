package com.example.controlhorario.ui.vacations

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import com.example.controlhorario.database.VacationEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.EmployeeCodePolicy
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETTextField
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun VacationsScreen(
    viewModel: VacationViewModel,
    employees: List<Employee>,
    onBack: () -> Unit
) {
    val vacations by viewModel.vacations.collectAsState()
    val pending by viewModel.pendingVacations.collectAsState()
    val approved by viewModel.approvedVacations.collectAsState()
    val rejected by viewModel.rejectedVacations.collectAsState()

    var employeeCode by remember { mutableStateOf("") }
    var startDate by remember { mutableStateOf("") }
    var endDate by remember { mutableStateOf("") }
    var requestedDays by remember { mutableStateOf("") }
    var reason by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text("Vacaciones", style = MaterialTheme.typography.headlineMedium)
        Text("Solicitudes, aprobación, rechazo e historial local.")
        Spacer(Modifier.height(16.dp))

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            SummaryCard("Pendientes", pending.size.toString(), Color(0xFFFFB300), Modifier.weight(1f))
            SummaryCard("Aprobadas", approved.size.toString(), Color(0xFF2E7D32), Modifier.weight(1f))
            SummaryCard("Rechazadas", rejected.size.toString(), Color(0xFFC62828), Modifier.weight(1f))
        }

        Spacer(Modifier.height(18.dp))
        Text("Nueva solicitud", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        OSINETTextField(employeeCode, { employeeCode = EmployeeCodePolicy.sanitizeInput(it) }, "Código empleado", Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        OSINETTextField(startDate, { startDate = it }, "Fecha inicio (yyyy-MM-dd)", Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        OSINETTextField(endDate, { endDate = it }, "Fecha final (yyyy-MM-dd)", Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        OSINETTextField(requestedDays, { requestedDays = it.filter(Char::isDigit) }, "Días solicitados", Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        OSINETTextField(reason, { reason = it }, "Motivo", Modifier.fillMaxWidth())
        Spacer(Modifier.height(10.dp))
        OSINETButton(
            text = "Guardar solicitud",
            onClick = {
            val code = EmployeeCodePolicy.normalizeOrNull(employeeCode)
            if (code == null) {
                message = EmployeeCodePolicy.ERROR
                return@OSINETButton
            }
            val matches = employees.filter {
                EmployeeCodePolicy.matches(it.employeeCode, code)
            }.distinctBy(Employee::id)
            val employee = matches.singleOrNull()
            if (employee == null) {
                message = if (matches.isEmpty()) {
                    "No existe empleado activo con código $code."
                } else {
                    "El código coincide con más de un empleado. Revise los datos."
                }
                return@OSINETButton
            }
            if (startDate.isBlank() || endDate.isBlank()) {
                message = "Debe indicar fecha de inicio y fecha final."
                return@OSINETButton
            }
            val now = nowDateTime()
            viewModel.saveVacation(
                VacationEntity(
                    employeeId = employee.id,
                    employeeName = employee.nombre,
                    employeeCode = EmployeeCodePolicy.normalizeOrNull(employee.employeeCode) ?: code,
                    startDate = startDate.trim(),
                    endDate = endDate.trim(),
                    requestedDays = requestedDays.toIntOrNull() ?: 0,
                    reason = reason.trim(),
                    requestedBy = "ADMIN",
                    requestedDate = now,
                    createdAt = now,
                    updatedAt = now
                )
            )
            message = "Solicitud guardada para ${employee.nombre}."
            employeeCode = ""
            startDate = ""
            endDate = ""
            requestedDays = ""
            reason = ""
            }
        )

        if (message.isNotBlank()) {
            Spacer(Modifier.height(10.dp))
            Text(message)
        }

        Spacer(Modifier.height(20.dp))
        Text("Solicitudes registradas", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        if (vacations.isEmpty()) {
            Text("No hay vacaciones registradas.")
        } else {
            vacations.forEach { vacation ->
                VacationRow(vacation, viewModel)
                Spacer(Modifier.height(8.dp))
            }
        }

        Spacer(Modifier.height(16.dp))
        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("Volver") }
    }
}

@Composable
private fun SummaryCard(title: String, value: String, color: Color, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.12f))
    ) {
        Column(Modifier.padding(12.dp)) {
            Text(title, color = color, style = MaterialTheme.typography.labelLarge)
            Text(value, style = MaterialTheme.typography.headlineSmall, color = color)
        }
    }
}

@Composable
private fun VacationRow(vacation: VacationEntity, viewModel: VacationViewModel) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFF7F7F7))
    ) {
        Column(Modifier.padding(14.dp)) {
            Text(vacation.employeeName, style = MaterialTheme.typography.titleMedium)
            Text("Código: ${vacation.employeeCode}")
            Text("${vacation.startDate} hasta ${vacation.endDate} · ${vacation.requestedDays} días")
            Text("Estado: ${vacation.status}")
            if (vacation.reason.isNotBlank()) Text("Motivo: ${vacation.reason}")
            if (vacation.status == VacationEntity.STATUS_PENDING) {
                Spacer(Modifier.height(8.dp))
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OSINETButton("Aprobar", onClick = {
                        val now = nowDateTime()
                        viewModel.approveVacation(
                            vacationId = vacation.id,
                            approvedBy = "ADMIN",
                            approvedDate = now,
                            approvedDays = vacation.requestedDays,
                            remainingDays = 0,
                            updatedAt = now
                        )
                    }, modifier = Modifier.weight(1f))
                    OSINETButton("Rechazar", onClick = {
                        val now = nowDateTime()
                        viewModel.rejectVacation(
                            vacationId = vacation.id,
                            rejectedBy = "ADMIN",
                            rejectedDate = now,
                            rejectionReason = "Rechazado por administración",
                            updatedAt = now
                        )
                    }, modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

private fun nowDateTime(): String =
    SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
