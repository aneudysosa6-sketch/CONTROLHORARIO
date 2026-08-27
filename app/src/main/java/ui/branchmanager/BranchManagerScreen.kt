package com.example.controlhorario.ui.branchmanager

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.SupervisorEventEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton

@Composable
fun BranchManagerScreen(
    viewModel: BranchManagerViewModel,
    onEmployeeMode: () -> Unit,
    onLogout: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    OSINETScreen {
        OSINETHeader(
            title = "Encargado de Sucursal",
            subtitle = state.branch?.name ?: "Sucursal asignada"
        )
        Spacer(Modifier.height(14.dp))
        OSINETCard {
            Text("Empleados: ${state.employees.size}", color = OSINETColors.TextPrimary)
            Text("Eventos de jornada: ${state.attendanceEvents.size}", color = OSINETColors.TextSecondary)
            Text("Eventos de supervisión: ${state.supervisorEvents.size}", color = OSINETColors.TextSecondary)
        }
        Spacer(Modifier.height(12.dp))
        OSINETButton("ACTIVAR MODO EMPLEADO", onClick = onEmployeeMode)
        Spacer(Modifier.height(14.dp))
        Text("Empleados de la sucursal", color = OSINETColors.TextPrimary)
        Spacer(Modifier.height(8.dp))
        state.employees.forEach { employee ->
            EmployeeRow(employee, onToggle = { viewModel.setEmployeeActive(employee.id, !employee.isActive) })
            Spacer(Modifier.height(8.dp))
        }
        Spacer(Modifier.height(14.dp))
        Text("Eventos recientes", color = OSINETColors.TextPrimary)
        Spacer(Modifier.height(8.dp))
        state.attendanceEvents.take(12).forEach { event ->
            AttendanceEventRow(event)
            Spacer(Modifier.height(8.dp))
        }
        state.supervisorEvents.take(12).forEach { event ->
            SupervisorEventRow(event)
            Spacer(Modifier.height(8.dp))
        }
        state.appEvents.take(8).forEach { event ->
            OSINETCard {
                Text(event.title, color = OSINETColors.TextPrimary)
                Text(event.description, color = OSINETColors.TextSecondary)
                Text(event.module, color = OSINETColors.GreenSoft)
            }
            Spacer(Modifier.height(8.dp))
        }
        Spacer(Modifier.height(10.dp))
        OSINETSecondaryButton("Cerrar sesión", onLogout)
    }
}

@Composable
private fun EmployeeRow(employee: Employee, onToggle: () -> Unit) {
    OSINETCard {
        Text("${employee.employeeCode} · ${employee.nombre}", color = OSINETColors.TextPrimary)
        Text("${employee.cargo} · ${employee.departamento}", color = OSINETColors.TextSecondary)
        Text(if (employee.isActive) "Activo" else "Desactivado", color = if (employee.isActive) OSINETColors.GreenSoft else OSINETColors.Warning)
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OSINETButton(
                text = if (employee.isActive) "DESACTIVAR" else "ACTIVAR",
                onClick = onToggle,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun AttendanceEventRow(event: AttendanceEntity) {
    OSINETCard {
        Text(event.employeeName, color = OSINETColors.TextPrimary)
        Text("${event.date} · ${event.time} · ${event.actionType}", color = OSINETColors.TextSecondary)
        if (event.notes.isNotBlank()) Text(event.notes, color = OSINETColors.GreenSoft)
    }
}

@Composable
private fun SupervisorEventRow(event: SupervisorEventEntity) {
    OSINETCard {
        Text(event.employeeName, color = OSINETColors.TextPrimary)
        Text("${event.eventDate} · ${event.eventType}", color = OSINETColors.TextSecondary)
        Text(event.detail, color = OSINETColors.GreenSoft)
    }
}
