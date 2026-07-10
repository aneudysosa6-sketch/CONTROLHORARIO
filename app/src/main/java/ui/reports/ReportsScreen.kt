package com.example.controlhorario.ui.reports

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
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.SupervisorPermissionEntity
import com.example.controlhorario.database.VacationEntity
import com.example.controlhorario.engine.AttendanceAction
import com.example.controlhorario.model.Employee

@Composable
fun ReportsScreen(
    employees: List<Employee>,
    attendance: List<AttendanceEntity>,
    vacations: List<VacationEntity>,
    permissions: List<SupervisorPermissionEntity>,
    onBack: () -> Unit
) {
    val lastActionByEmployee = attendance.groupBy { it.employeeId }
        .mapValues { (_, records) -> records.maxByOrNull { it.id }?.actionType.orEmpty() }
    val working = lastActionByEmployee.values.count { it == AttendanceAction.INICIO_JORNADA.name || it == AttendanceAction.REANUDAR.name }
    val paused = lastActionByEmployee.values.count { it == AttendanceAction.PAUSA.name }
    val finished = lastActionByEmployee.values.count { it == AttendanceAction.FIN_JORNADA.name }
    val pendingVacations = vacations.count { it.status == VacationEntity.STATUS_PENDING }

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp).verticalScroll(rememberScrollState())
    ) {
        Text("Reportes", style = MaterialTheme.typography.headlineMedium)
        Text("Resumen local de empleados, asistencia, vacaciones y permisos internos.")
        Spacer(Modifier.height(18.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ReportCard("Empleados", employees.size.toString(), Modifier.weight(1f))
            ReportCard("Registros", attendance.size.toString(), Modifier.weight(1f))
        }
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ReportCard("Trabajando", working.toString(), Modifier.weight(1f))
            ReportCard("En pausa", paused.toString(), Modifier.weight(1f))
            ReportCard("Finalizados", finished.toString(), Modifier.weight(1f))
        }
        Spacer(Modifier.height(8.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ReportCard("Vacaciones pendientes", pendingVacations.toString(), Modifier.weight(1f))
            ReportCard("Permisos", permissions.size.toString(), Modifier.weight(1f))
        }

        Spacer(Modifier.height(20.dp))
        Text("Últimos registros de asistencia", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        attendance.take(12).forEach { record ->
            Card(Modifier.fillMaxWidth().padding(vertical = 4.dp), shape = RoundedCornerShape(12.dp)) {
                Column(Modifier.padding(12.dp)) {
                    Text(record.employeeName, style = MaterialTheme.typography.titleSmall)
                    Text("${record.date} ${record.time} · ${record.actionType}")
                }
            }
        }
        if (attendance.isEmpty()) Text("Todavía no hay asistencia registrada.")
        Spacer(Modifier.height(18.dp))
        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("Volver") }
    }
}

@Composable
private fun ReportCard(title: String, value: String, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color(0xFFF7F7F7))
    ) {
        Column(Modifier.padding(14.dp)) {
            Text(title, style = MaterialTheme.typography.labelLarge)
            Text(value, style = MaterialTheme.typography.headlineSmall, color = Color(0xFF1B8F3A))
        }
    }
}
