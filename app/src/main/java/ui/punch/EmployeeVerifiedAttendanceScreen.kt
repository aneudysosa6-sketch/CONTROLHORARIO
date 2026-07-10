package com.example.controlhorario.ui.punch

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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.controlhorario.engine.AttendanceAction
import com.example.controlhorario.engine.AttendanceStateMachine
import com.example.controlhorario.model.Employee
import com.example.controlhorario.ui.attendance.AttendanceViewModel
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun EmployeeVerifiedAttendanceScreen(
    employee: Employee?,
    viewModel: AttendanceViewModel,
    onFinish: () -> Unit
) {
    val records by viewModel.attendanceRecords.collectAsState()
    var message by remember { mutableStateOf("Huella verificada. Seleccione la acción de asistencia.") }
    val today = currentDate()
    val todayRecords = records
        .filter { it.employeeId == employee?.id && it.date == today }
        .sortedBy { it.time }
    val currentState = AttendanceStateMachine.getCurrentState(todayRecords.map { it.actionType })
    val employeeCode = employee?.employeeCode?.ifBlank { employee.pin }.orEmpty()
    val stateMessage = if (currentState == com.example.controlhorario.engine.AttendanceState.FINALIZADA) {
        "La jornada de hoy ya fue finalizada."
    } else {
        message
    }

    OSINETScreen {
        OSINETHeader(
            title = "Registrar jornada",
            subtitle = "Selecciona la acción que deseas realizar"
        )
        Spacer(Modifier.height(18.dp))
        OSINETCard {
            Text("Empleado", color = OSINETColors.TextSecondary)
            Text(employee?.nombre ?: "Empleado no encontrado", color = OSINETColors.TextPrimary, fontWeight = FontWeight.SemiBold)
            Text("Código: $employeeCode", color = OSINETColors.TextSecondary)
            Text("Estado actual: ${attendanceStateLabel(currentState)}", color = OSINETColors.GreenSoft)
        }
        Spacer(Modifier.height(14.dp))
        Text(
            text = stateMessage,
            color = OSINETColors.TextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(18.dp))
        EmployeeAttendanceActionButton(
            text = "Iniciar Jornada",
            employee = employee,
            viewModel = viewModel,
            action = AttendanceAction.INICIO_JORNADA,
            currentStateActions = todayRecords.map { it.actionType },
            onMessage = { message = it },
            onRegistered = onFinish
        )
        Spacer(Modifier.height(10.dp))
        EmployeeAttendanceActionButton(
            text = "Pausar Jornada",
            employee = employee,
            viewModel = viewModel,
            action = AttendanceAction.PAUSA,
            currentStateActions = todayRecords.map { it.actionType },
            onMessage = { message = it },
            onRegistered = onFinish
        )
        Spacer(Modifier.height(10.dp))
        EmployeeAttendanceActionButton(
            text = "Reanudar Jornada",
            employee = employee,
            viewModel = viewModel,
            action = AttendanceAction.REANUDAR,
            currentStateActions = todayRecords.map { it.actionType },
            onMessage = { message = it },
            onRegistered = onFinish
        )
        Spacer(Modifier.height(10.dp))
        EmployeeAttendanceActionButton(
            text = "Finalizar Jornada",
            employee = employee,
            viewModel = viewModel,
            action = AttendanceAction.FIN_JORNADA,
            currentStateActions = todayRecords.map { it.actionType },
            onMessage = { message = it },
            onRegistered = onFinish
        )
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Cancelar", onFinish)
    }
}

@Composable
private fun EmployeeAttendanceActionButton(
    text: String,
    employee: Employee?,
    viewModel: AttendanceViewModel,
    action: AttendanceAction,
    currentStateActions: List<String>,
    onMessage: (String) -> Unit,
    onRegistered: () -> Unit
) {
    val currentState = AttendanceStateMachine.getCurrentState(currentStateActions)
    val canRegister = AttendanceStateMachine.canRegisterAction(currentState, action)

    OSINETButton(
        text = text,
        onClick = {
            if (employee == null) {
                onMessage("Empleado no encontrado.")
                return@OSINETButton
            }
            if (!canRegister) {
                onMessage(AttendanceStateMachine.getErrorMessage(currentState, action))
                return@OSINETButton
            }
            viewModel.registerAttendanceAndThen(
                employeeId = employee.id,
                employeeName = employee.nombre,
                date = currentDate(),
                time = currentTime(),
                actionType = action.name,
                biometricVerified = true,
                deviceName = "2Connect USB Fingerprint Scanner",
                notes = "Asistencia registrada después de validar huella 2Connect",
                onSaved = onRegistered
            )
            onMessage("Asistencia registrada correctamente: ${action.name}")
        },
        modifier = Modifier.fillMaxWidth(),
        enabled = canRegister && employee != null
    )
}

private fun attendanceStateLabel(state: com.example.controlhorario.engine.AttendanceState): String {
    return when (state) {
        com.example.controlhorario.engine.AttendanceState.SIN_JORNADA -> "SIN JORNADA"
        com.example.controlhorario.engine.AttendanceState.TRABAJANDO -> "EN CURSO"
        com.example.controlhorario.engine.AttendanceState.EN_PAUSA -> "EN PAUSA"
        com.example.controlhorario.engine.AttendanceState.FINALIZADA -> "FINALIZADA"
    }
}

private fun currentDate(): String = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
private fun currentTime(): String = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())
