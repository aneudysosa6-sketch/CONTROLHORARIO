package com.example.controlhorario.ui.incidents

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.PendingAttendanceReviewEntity
import com.example.controlhorario.engine.AttendanceAction
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun PendingAttendanceReviewScreen(
    viewModel: PendingAttendanceReviewViewModel,
    onBack: () -> Unit
) {
    val reviews by viewModel.reviews.collectAsState()
    val message by viewModel.message.collectAsState()
    val dashboardDate by viewModel.dashboardDate.collectAsState()
    val attendanceRecords by viewModel.attendanceRecords.collectAsState()
    var historyFilter by remember { mutableStateOf("") }
    val dayRecords = attendanceRecords.filter { it.date == dashboardDate }
    val started = dayRecords.filter { it.actionType == AttendanceAction.INICIO_JORNADA.name }
    val pauses = dayRecords.filter { it.actionType == AttendanceAction.PAUSA.name }
    val unfinished = dayRecords
        .groupBy { it.employeeId }
        .mapNotNull { (_, records) ->
            val last = records.maxByOrNull { it.id }
            if (last != null && last.actionType != AttendanceAction.FIN_JORNADA.name) last else null
        }

    OSINETScreen {
        OSINETHeader(
            title = "Centro de Incidencias",
            subtitle = "Jornadas pendientes clasificadas por gravedad"
        )
        Spacer(Modifier.height(14.dp))
        OSINETButton("Ejecutar cierre de ayer", onClick = { viewModel.runClosureForYesterday() })
        Spacer(Modifier.height(8.dp))
        OSINETSecondaryButton("Ejecutar cierre de hoy", onClick = { viewModel.runClosureForToday() })
        if (message.isNotBlank()) {
            Spacer(Modifier.height(10.dp))
            Text(message, color = OSINETColors.TextSecondary)
        }
        Spacer(Modifier.height(18.dp))

        OSINETCard {
            Text("Dashboard asistencias", color = OSINETColors.TextPrimary, fontWeight = FontWeight.Bold)
            OSINETTextField(
                value = dashboardDate,
                onValueChange = { viewModel.setDashboardDate(it) },
                label = "Buscar por fecha yyyy-MM-dd",
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(8.dp))
            DashboardMetric("Todos los inicios", started.size, "INICIO_JORNADA") { historyFilter = "INICIO_JORNADA" }
            DashboardMetric("Pausas", pauses.size, "PAUSA") { historyFilter = "PAUSA" }
            DashboardMetric("Sin finalizar", unfinished.size, "SIN_FINALIZAR") { historyFilter = "SIN_FINALIZAR" }
        }

        if (historyFilter.isNotBlank()) {
            Spacer(Modifier.height(10.dp))
            OSINETCard {
                Text("Historial: $historyFilter", color = OSINETColors.TextPrimary, fontWeight = FontWeight.Bold)
                val history = when (historyFilter) {
                    "SIN_FINALIZAR" -> unfinished
                    else -> dayRecords.filter { it.actionType == historyFilter }
                }
                history.forEach { record ->
                    AttendanceHistoryRow(
                        record = record,
                        allowFinish = historyFilter == "SIN_FINALIZAR",
                        onFinish = { viewModel.finishOpenShift(record.employeeId, record.employeeName) }
                    )
                    Spacer(Modifier.height(6.dp))
                }
                OSINETSecondaryButton("Cerrar historial", onClick = { historyFilter = "" })
            }
        }
        Spacer(Modifier.height(18.dp))

        val ordered = reviews.sortedWith(compareBy<PendingAttendanceReviewEntity> { severityOrder(it.severity) }.thenByDescending { it.createdAt })
        if (ordered.isEmpty()) {
            OSINETCard { Text("No hay jornadas pendientes de aprobación.", color = OSINETColors.TextSecondary) }
        }
        ordered.forEach { review ->
            PendingReviewCard(
                review = review,
                onApprove = { viewModel.approve(review) },
                onEdit = { viewModel.markEdited(review) },
                onReject = { viewModel.reject(review) }
            )
            Spacer(Modifier.height(10.dp))
        }
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}

@Composable
private fun DashboardMetric(title: String, count: Int, key: String, onOpen: () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
        Text("$title: $count", color = OSINETColors.TextPrimary, modifier = Modifier.weight(1f))
        OutlinedButton(onClick = onOpen) { Text("Abrir historia") }
    }
}

@Composable
private fun AttendanceHistoryRow(
    record: AttendanceEntity,
    allowFinish: Boolean,
    onFinish: () -> Unit
) {
    OSINETCard {
        Text(record.employeeName, color = OSINETColors.TextPrimary)
        Text("${record.date} ${record.time} · ${record.actionType}", color = OSINETColors.TextSecondary)
        if (record.notes.isNotBlank()) Text(record.notes, color = OSINETColors.GreenSoft)
        if (allowFinish) {
            OSINETButton("Finalizar jornada", onClick = onFinish)
        }
    }
}

@Composable
private fun PendingReviewCard(
    review: PendingAttendanceReviewEntity,
    onApprove: () -> Unit,
    onEdit: () -> Unit,
    onReject: () -> Unit
) {
    val icon = when (review.severity) {
        PendingAttendanceReviewEntity.SEVERITY_CRITICAL -> "🔴"
        PendingAttendanceReviewEntity.SEVERITY_HIGH -> "🟠"
        PendingAttendanceReviewEntity.SEVERITY_MEDIUM -> "🟡"
        else -> "🔵"
    }
    OSINETCard {
        Text("$icon ${review.severity}", color = OSINETColors.TextPrimary, fontWeight = FontWeight.Bold)
        Text("Empleado: ${review.employeeName}", color = OSINETColors.TextPrimary, fontWeight = FontWeight.SemiBold)
        Text("Código: ${review.employeeCode}", color = OSINETColors.TextSecondary)
        Text("Departamento: ${review.departmentName}", color = OSINETColors.TextSecondary)
        Text("Fecha: ${review.reviewDate}", color = OSINETColors.TextSecondary)
        Text("Entrada: ${review.checkInTime.ifBlank { "No registrada" }}", color = OSINETColors.TextSecondary)
        Text("Pausa: ${review.lunchOutTime.ifBlank { "No registrada" }}", color = OSINETColors.TextSecondary)
        Text("Reanudación: ${review.lunchInTime.ifBlank { "No registrada" }}", color = OSINETColors.TextSecondary)
        Text("Salida: ${review.checkOutTime.ifBlank { "No registrada" }}", color = OSINETColors.TextSecondary)
        Text("Horas calculadas: ${"%.2f".format(review.calculatedHours)}", color = OSINETColors.Warning)
        Text("Motivo: ${review.reason}", color = OSINETColors.TextSecondary)
        Text("Notificación interna: pendiente de revisión", color = OSINETColors.GreenSoft)
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            OutlinedButton(onClick = onApprove) { Text("Aprobar") }
            OutlinedButton(onClick = onEdit) { Text("Editar") }
            OutlinedButton(onClick = onReject) { Text("Rechazar") }
        }
    }
}

private fun severityOrder(severity: String): Int = when (severity) {
    PendingAttendanceReviewEntity.SEVERITY_CRITICAL -> 0
    PendingAttendanceReviewEntity.SEVERITY_HIGH -> 1
    PendingAttendanceReviewEntity.SEVERITY_MEDIUM -> 2
    else -> 3
}
