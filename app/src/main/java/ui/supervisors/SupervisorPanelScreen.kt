package com.example.controlhorario.ui.supervisors

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
import com.example.controlhorario.database.SupervisorEventEntity
import com.example.controlhorario.ui.components.OSINETActionCard
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun SupervisorHomeScreen(
    supervisorId: Int,
    onJornadas: () -> Unit,
    onEventos: () -> Unit,
    onPermisos: () -> Unit,
    onAdminOnOff: () -> Unit,
    onLogout: () -> Unit
) {
    OSINETScreen {
        OSINETHeader(
            title = "Panel Supervisor",
            subtitle = "Control operativo de empleados asignados"
        )
        Spacer(Modifier.height(12.dp))
        Text("ID supervisor: $supervisorId", color = OSINETColors.TextSecondary)
        Spacer(Modifier.height(24.dp))
        OSINETActionCard("Jornadas", "Horarios e historial de empleados asignados", onClick = onJornadas)
        Spacer(Modifier.height(10.dp))
        OSINETActionCard("Eventos", "Alertas con minutos y prioridad", onClick = onEventos)
        Spacer(Modifier.height(10.dp))
        OSINETActionCard("Permisos", "Solicitudes internas pendientes", onClick = onPermisos)
        Spacer(Modifier.height(10.dp))
        OSINETActionCard("ADMIN OF/ON", "Activar o desactivar registro de jornadas", onClick = onAdminOnOff)
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Cerrar sesión", onLogout)
    }
}

@Composable
fun SupervisorJornadasScreen(
    viewModel: SupervisorPanelViewModel,
    onBack: () -> Unit
) {
    val employee by viewModel.selectedEmployee.collectAsState()
    val schedule by viewModel.selectedSchedule.collectAsState()
    val message by viewModel.message.collectAsState()
    var code by remember { mutableStateOf("") }
    var start by remember(schedule) { mutableStateOf(schedule?.startTime ?: "08:00") }
    var lunchOut by remember(schedule) { mutableStateOf(schedule?.lunchOutTime ?: "12:00") }
    var lunchIn by remember(schedule) { mutableStateOf(schedule?.lunchInTime ?: "13:00") }
    var end by remember(schedule) { mutableStateOf(schedule?.endTime ?: "17:00") }

    OSINETScreen {
        OSINETHeader(
            title = "Jornadas",
            subtitle = "Solo empleados de departamentos asignados"
        )
        Spacer(Modifier.height(18.dp))
        OSINETTextField(value = code, onValueChange = { code = it.filter(Char::isDigit).take(5) }, label = "Código de empleado", modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(10.dp))
        OSINETButton("Buscar", onClick = { viewModel.findEmployeeByCode(code) })
        if (message.isNotBlank()) {
            Spacer(Modifier.height(10.dp))
            Text(message, color = OSINETColors.TextSecondary)
        }

        employee?.let { emp ->
            Spacer(Modifier.height(14.dp))
            OSINETCard {
                Text("Código: ${emp.employeeCode.ifBlank { emp.pin }}", color = OSINETColors.TextSecondary)
                Text("Nombre: ${emp.nombre}", color = OSINETColors.TextPrimary, fontWeight = FontWeight.SemiBold)
                Text("Departamento: ${emp.departamento}", color = OSINETColors.TextSecondary)
                Text(if (emp.isActive) "Estado: Activo" else "Estado: Inactivo", color = if (emp.isActive) OSINETColors.GreenSoft else OSINETColors.Danger)
                OSINETTextField(start, { start = it.take(5) }, "Hora entrada (HH:mm)", Modifier.fillMaxWidth())
                OSINETTextField(lunchOut, { lunchOut = it.take(5) }, "Salida almuerzo (HH:mm)", Modifier.fillMaxWidth())
                OSINETTextField(lunchIn, { lunchIn = it.take(5) }, "Llegada almuerzo (HH:mm)", Modifier.fillMaxWidth())
                OSINETTextField(end, { end = it.take(5) }, "Fin de trabajo (HH:mm)", Modifier.fillMaxWidth())
                OSINETButton("Guardar horario", onClick = { viewModel.saveSchedule(start, lunchOut, lunchIn, end) })
            }
        }
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}

@Composable
fun SupervisorEventosScreen(
    viewModel: SupervisorPanelViewModel,
    onBack: () -> Unit
) {
    val events by viewModel.events.collectAsState()
    val message by viewModel.message.collectAsState()
    OSINETScreen {
        OSINETHeader(
            title = "Eventos",
            subtitle = "Alertas automáticas con tiempo exacto"
        )
        Spacer(Modifier.height(18.dp))
        OSINETButton("Actualizar eventos de hoy", onClick = { viewModel.generateTodayEvents() })
        if (message.isNotBlank()) {
            Spacer(Modifier.height(10.dp))
            Text(message, color = OSINETColors.TextSecondary)
        }
        Spacer(Modifier.height(10.dp))
        events.forEach { event ->
            SupervisorEventCard(event)
            Spacer(Modifier.height(10.dp))
        }
        if (events.isEmpty()) Text("No hay eventos registrados.", color = OSINETColors.TextSecondary)
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}

@Composable
private fun SupervisorEventCard(event: SupervisorEventEntity) {
    val icon = when (event.severity) {
        "VERDE" -> "🟢"
        "AMARILLO" -> "🟡"
        else -> "🔴"
    }
    OSINETCard {
        Text("Empleado: ${event.employeeName}", color = OSINETColors.TextPrimary, fontWeight = FontWeight.SemiBold)
        Text("Departamento: ${event.departmentName}", color = OSINETColors.TextSecondary)
        Text("$icon ${event.detail}", color = OSINETColors.TextPrimary)
        if (event.minutes > 0) Text("Tiempo: ${event.minutes} minutos", color = OSINETColors.Warning)
        Text("Fecha: ${event.eventDate}", color = OSINETColors.TextSecondary)
        if (event.notificationPending) Text("Notificación interna pendiente", color = OSINETColors.GreenSoft)
    }
}

@Composable
fun SupervisorPermisosScreen(onBack: () -> Unit) {
    OSINETScreen {
        OSINETHeader(
            title = "Permisos",
            subtitle = "Solicitudes internas de los empleados asignados"
        )
        Spacer(Modifier.height(22.dp))
        OSINETCard {
            Text("Tipos de permisos", color = OSINETColors.TextPrimary, fontWeight = FontWeight.SemiBold)
            Text("1. Cita médica", color = OSINETColors.TextSecondary)
            Text("2. Llegar tarde", color = OSINETColors.TextSecondary)
            Text("3. Enfermedad en casa", color = OSINETColors.TextSecondary)
            Text("4. Asunto personal", color = OSINETColors.TextSecondary)
        }
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}

@Composable
fun SupervisorAdminOnOffScreen(
    viewModel: SupervisorPanelViewModel,
    onBack: () -> Unit
) {
    val employee by viewModel.selectedEmployee.collectAsState()
    val message by viewModel.message.collectAsState()
    var code by remember { mutableStateOf("") }
    OSINETScreen {
        OSINETHeader(
            title = "ADMIN OF/ON",
            subtitle = "Activar o desactivar el registro de jornadas"
        )
        Spacer(Modifier.height(18.dp))
        OSINETTextField(value = code, onValueChange = { code = it.filter(Char::isDigit).take(5) }, label = "Código de empleado", modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(10.dp))
        OSINETButton("Buscar", onClick = { viewModel.findEmployeeByCode(code) })
        if (message.isNotBlank()) {
            Spacer(Modifier.height(10.dp))
            Text(message, color = OSINETColors.TextSecondary)
        }
        employee?.let { emp ->
            Spacer(Modifier.height(14.dp))
            OSINETCard {
                Text("Código: ${emp.employeeCode.ifBlank { emp.pin }}", color = OSINETColors.TextSecondary)
                Text("Nombre: ${emp.nombre}", color = OSINETColors.TextPrimary, fontWeight = FontWeight.SemiBold)
                Text("Departamento: ${emp.departamento}", color = OSINETColors.TextSecondary)
                Text(if (emp.isActive) "Estado: Activo" else "Estado: Inactivo", color = if (emp.isActive) OSINETColors.GreenSoft else OSINETColors.Danger)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { viewModel.setEmployeeActive(true) }) { Text("ACTIVAR") }
                    OutlinedButton(onClick = { viewModel.setEmployeeActive(false) }) { Text("DESACTIVAR") }
                }
                Text("Al desactivar se genera una incidencia interna REGISTRO_DESHABILITADO.", color = OSINETColors.TextSecondary)
            }
        }
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}
