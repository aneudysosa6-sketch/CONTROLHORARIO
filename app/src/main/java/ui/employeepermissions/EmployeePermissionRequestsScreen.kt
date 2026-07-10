package com.example.controlhorario.ui.employeepermissions

import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import com.example.controlhorario.database.EmployeePermissionRequestEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.ui.components.OSINETActionCard
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETTextField
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun EmployeePermissionRequestsScreen(
    viewModel: EmployeePermissionRequestsViewModel,
    employees: List<Employee>,
    reviewerName: String,
    onBack: () -> Unit
) {
    val requests by viewModel.requests.collectAsState()
    var statusFilter by remember { mutableStateOf(EmployeePermissionRequestEntity.STATUS_PENDING) }
    var typeFilter by remember { mutableStateOf("TODOS") }
    val filtered = requests.filter { request ->
        (statusFilter == "TODOS" || request.status == statusFilter) &&
            (typeFilter == "TODOS" || request.requestType == typeFilter)
    }
    val grouped = filtered.groupBy { it.employeeId to it.employeeName }

    OSINETScreen {
        OSINETHeader(
            title = "Permisos de Empleados",
            subtitle = "Revisar archivos, aprobar o rechazar solicitudes"
        )
        Spacer(Modifier.height(12.dp))
        OSINETCard {
            Text("Estado", color = OSINETColors.TextPrimary)
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OSINETButton("PENDIENTES", onClick = { statusFilter = EmployeePermissionRequestEntity.STATUS_PENDING }, modifier = Modifier.weight(1f))
                OSINETButton("APROBADOS", onClick = { statusFilter = EmployeePermissionRequestEntity.STATUS_APPROVED }, modifier = Modifier.weight(1f))
            }
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OSINETButton("RECHAZADOS", onClick = { statusFilter = EmployeePermissionRequestEntity.STATUS_REJECTED }, modifier = Modifier.weight(1f))
                OSINETButton("TODOS", onClick = { statusFilter = "TODOS" }, modifier = Modifier.weight(1f))
            }
            Spacer(Modifier.height(10.dp))
            Text("Tipo", color = OSINETColors.TextPrimary)
            Spacer(Modifier.height(8.dp))
            OSINETActionCard("Todos los permisos", if (typeFilter == "TODOS") "Seleccionado" else "Ver todo", onClick = { typeFilter = "TODOS" })
            Spacer(Modifier.height(8.dp))
            OSINETActionCard("Médico", if (typeFilter == EmployeePermissionRequestEntity.TYPE_MEDICAL) "Seleccionado" else "Filtrar", onClick = { typeFilter = EmployeePermissionRequestEntity.TYPE_MEDICAL })
            Spacer(Modifier.height(8.dp))
            OSINETActionCard("Licencia médica", if (typeFilter == EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE) "Seleccionado" else "Filtrar", onClick = { typeFilter = EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE })
        }
        Spacer(Modifier.height(12.dp))
        if (grouped.isEmpty()) {
            OSINETCard {
                Text("No hay permisos para mostrar.", color = OSINETColors.TextSecondary)
            }
        } else {
            grouped.forEach { (employeeKey, employeeRequests) ->
                EmployeePermissionGroup(
                    employeeName = employeeKey.second,
                    employeeRequests = employeeRequests,
                    employee = employees.firstOrNull { it.id == employeeKey.first },
                    reviewerName = reviewerName,
                    viewModel = viewModel
                )
                Spacer(Modifier.height(10.dp))
            }
        }
        Spacer(Modifier.height(16.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}

@Composable
private fun EmployeePermissionGroup(
    employeeName: String,
    employeeRequests: List<EmployeePermissionRequestEntity>,
    employee: Employee?,
    reviewerName: String,
    viewModel: EmployeePermissionRequestsViewModel
) {
    var expanded by remember(employeeName) { mutableStateOf(false) }
    OSINETCard {
        OSINETActionCard(
            title = employeeName.ifBlank { "Empleado sin nombre" },
            subtitle = "${employeeRequests.size} permisos registrados",
            onClick = { expanded = !expanded }
        )
        if (expanded) {
            Spacer(Modifier.height(8.dp))
            employeeRequests.forEach { request ->
                EmployeePermissionRow(
                    request = request,
                    employee = employee,
                    reviewerName = reviewerName,
                    viewModel = viewModel
                )
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun EmployeePermissionRow(
    request: EmployeePermissionRequestEntity,
    employee: Employee?,
    reviewerName: String,
    viewModel: EmployeePermissionRequestsViewModel
) {
    val context = LocalContext.current
    var rejectReason by remember(request.id) { mutableStateOf("") }
    var showRejectReason by remember(request.id) { mutableStateOf(false) }
    var licenseStart by remember(request.id) { mutableStateOf(request.licenseStartDate) }
    var licenseEnd by remember(request.id) { mutableStateOf(request.licenseEndDate) }
    var percent by remember(request.id) { mutableStateOf(if (request.licensePayPercent > 0.0) request.licensePayPercent.toString() else "") }
    val normalDailyAmount = (employee?.sueldo ?: 0.0) / 15.0
    val percentValue = percent.toDoubleOrNull() ?: 0.0
    val dailyLicenseAmount = normalDailyAmount * (percentValue / 100.0)

    OSINETCard {
        Text("${request.employeeCode} · ${displayType(request.requestType)}", color = OSINETColors.TextPrimary)
        Text("Estado: ${request.status} · ${request.requestedDate}", color = OSINETColors.GreenSoft)
        if (request.message.isNotBlank()) {
            Text("Mensaje: ${request.message}", color = OSINETColors.TextSecondary)
        }
        if (request.attachmentUri.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            Text("Adjunto: ${request.attachmentLabel.ifBlank { request.attachmentUri }}", color = OSINETColors.TextSecondary)
            Spacer(Modifier.height(8.dp))
            OSINETSecondaryButton("Ver archivo", onClick = { openAttachment(context, request.attachmentUri) })
        }
        if (request.status == EmployeePermissionRequestEntity.STATUS_REJECTED && request.rejectionReason.isNotBlank()) {
            Text("Motivo rechazo: ${request.rejectionReason}", color = OSINETColors.Danger)
        }
        if (request.status == EmployeePermissionRequestEntity.STATUS_APPROVED && request.requestType == EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE) {
            Text("Licencia: ${request.licenseStartDate} a ${request.licenseEndDate}", color = OSINETColors.TextSecondary)
            Text("Pago diario: ${money(request.licenseDailyAmount)} · Total: ${money(request.licenseTotalAmount)}", color = OSINETColors.GreenSoft)
        }
        if (request.status == EmployeePermissionRequestEntity.STATUS_PENDING) {
            if (request.requestType == EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE) {
                Spacer(Modifier.height(8.dp))
                OSINETTextField(licenseStart, { licenseStart = it }, "Fecha inicio yyyy-MM-dd", Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                OSINETTextField(licenseEnd, { licenseEnd = it }, "Fecha fin yyyy-MM-dd", Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                OSINETTextField(percent, { percent = it.filter { char -> char.isDigit() || char == '.' }.take(5) }, "Porcentaje a pagar", Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                Text("Pago diario calculado: ${money(dailyLicenseAmount)}", color = OSINETColors.GreenSoft)
            }
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OSINETButton(
                    "APROBAR",
                    enabled = request.requestType != EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE ||
                        (licenseStart.isNotBlank() && licenseEnd.isNotBlank() && percentValue > 0.0),
                    onClick = {
                        viewModel.approveRequest(
                            request = request,
                            reviewedBy = reviewerName,
                            now = nowDateTime(),
                            licenseStartDate = licenseStart,
                            licenseEndDate = licenseEnd,
                            licensePayPercent = percentValue,
                            normalDailyAmount = normalDailyAmount
                        )
                    },
                    modifier = Modifier.weight(1f)
                )
                OSINETButton("RECHAZAR", onClick = { showRejectReason = true }, modifier = Modifier.weight(1f))
            }
            if (showRejectReason) {
                Spacer(Modifier.height(8.dp))
                OSINETTextField(rejectReason, { rejectReason = it }, "Motivo del rechazo", Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                OSINETButton(
                    "CONFIRMAR RECHAZO",
                    enabled = rejectReason.isNotBlank(),
                    onClick = {
                        viewModel.rejectRequest(
                            requestId = request.id,
                            reviewedBy = reviewerName,
                            reason = rejectReason.trim(),
                            now = nowDateTime()
                        )
                    }
                )
            }
        }
    }
}

private fun displayType(type: String): String = when (type) {
    EmployeePermissionRequestEntity.TYPE_LATE -> "Llegaré tarde"
    EmployeePermissionRequestEntity.TYPE_MEDICAL -> "Médico"
    EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE -> "Licencia médica"
    EmployeePermissionRequestEntity.TYPE_PERSONAL -> "Motivo personal"
    else -> type
}

private fun openAttachment(context: Context, uri: String) {
    runCatching {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
    }
}

private fun nowDateTime(): String =
    SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date())

private fun money(value: Double): String =
    NumberFormat.getCurrencyInstance(Locale("es", "DO")).format(value)
