package com.example.controlhorario.ui.attendance

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.fragment.app.FragmentActivity
import com.example.controlhorario.engine.AttendanceAction
import com.example.controlhorario.engine.AttendanceStateMachine
import com.example.controlhorario.model.Employee
import com.example.controlhorario.security.BiometricAuthManager
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AttendanceScreen(
    employees: List<Employee>,
    viewModel: AttendanceViewModel,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val activity = context as? FragmentActivity

    val records by viewModel.attendanceRecords.collectAsState()

    var selectedEmployee by remember { mutableStateOf<Employee?>(null) }
    var expanded by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf("") }

    val currentDate = getCurrentDate()

    val selectedEmployeeRecordsToday = records
        .filter { record ->
            record.employeeId == selectedEmployee?.id &&
                    record.date == currentDate
        }
        .sortedBy { it.time }

    val currentState = AttendanceStateMachine.getCurrentState(
        selectedEmployeeRecordsToday.map { it.actionType }
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text("Control de Asistencia")
                }
            )
        }
    ) { padding ->

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
        ) {

            Text("Seleccionar empleado")

            Spacer(modifier = Modifier.height(8.dp))

            OutlinedButton(
                modifier = Modifier.fillMaxWidth(),
                onClick = {
                    expanded = true
                }
            ) {
                Text(selectedEmployee?.nombre ?: "Elegir empleado")
            }

            DropdownMenu(
                expanded = expanded,
                onDismissRequest = {
                    expanded = false
                }
            ) {
                employees.forEach { employee ->
                    DropdownMenuItem(
                        text = {
                            Text("${employee.nombre} - ${employee.cargo}")
                        },
                        onClick = {
                            selectedEmployee = employee
                            expanded = false
                            message = ""
                        }
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Card(
                modifier = Modifier.fillMaxWidth(),
                elevation = CardDefaults.cardElevation(4.dp)
            ) {
                Column(
                    modifier = Modifier.padding(12.dp)
                ) {
                    Text("Estado actual")
                    Text(currentState.name)
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            if (message.isNotBlank()) {
                Text(message)
                Spacer(modifier = Modifier.height(12.dp))
            }

            AttendanceActionButton(
                text = "🟢 Iniciar jornada",
                employee = selectedEmployee,
                viewModel = viewModel,
                action = AttendanceAction.INICIO_JORNADA,
                currentStateActions = selectedEmployeeRecordsToday.map { it.actionType },
                activity = activity,
                onMessage = { message = it }
            )

            Spacer(modifier = Modifier.height(8.dp))

            AttendanceActionButton(
                text = "☕ Pausa",
                employee = selectedEmployee,
                viewModel = viewModel,
                action = AttendanceAction.PAUSA,
                currentStateActions = selectedEmployeeRecordsToday.map { it.actionType },
                activity = activity,
                onMessage = { message = it }
            )

            Spacer(modifier = Modifier.height(8.dp))

            AttendanceActionButton(
                text = "▶ Reanudar",
                employee = selectedEmployee,
                viewModel = viewModel,
                action = AttendanceAction.REANUDAR,
                currentStateActions = selectedEmployeeRecordsToday.map { it.actionType },
                activity = activity,
                onMessage = { message = it }
            )

            Spacer(modifier = Modifier.height(8.dp))

            AttendanceActionButton(
                text = "🔴 Finalizar jornada",
                employee = selectedEmployee,
                viewModel = viewModel,
                action = AttendanceAction.FIN_JORNADA,
                currentStateActions = selectedEmployeeRecordsToday.map { it.actionType },
                activity = activity,
                onMessage = { message = it }
            )

            Spacer(modifier = Modifier.height(20.dp))

            OutlinedButton(
                modifier = Modifier.fillMaxWidth(),
                onClick = onBack
            ) {
                Text("⬅ Volver")
            }

            Spacer(modifier = Modifier.height(20.dp))

            Text("Historial de hoy")

            Spacer(modifier = Modifier.height(8.dp))

            LazyColumn {

                items(selectedEmployeeRecordsToday.reversed()) { record ->

                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 4.dp),
                        elevation = CardDefaults.cardElevation(3.dp)
                    ) {
                        Column(
                            modifier = Modifier.padding(12.dp)
                        ) {
                            Text(record.employeeName)
                            Text("${record.date} ${record.time}")
                            Text(record.actionType)
                            Text(
                                if (record.biometricVerified)
                                    "Biometría verificada"
                                else
                                    "Biometría pendiente"
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun AttendanceActionButton(
    text: String,
    employee: Employee?,
    viewModel: AttendanceViewModel,
    action: AttendanceAction,
    currentStateActions: List<String>,
    activity: FragmentActivity?,
    onMessage: (String) -> Unit
) {
    val currentState = AttendanceStateMachine.getCurrentState(currentStateActions)
    val canRegister = AttendanceStateMachine.canRegisterAction(currentState, action)

    Button(
        modifier = Modifier.fillMaxWidth(),
        enabled = employee != null && canRegister,
        onClick = {
            if (employee == null) {
                onMessage("Selecciona un empleado primero.")
                return@Button
            }

            if (!canRegister) {
                onMessage(
                    AttendanceStateMachine.getErrorMessage(
                        currentState = currentState,
                        action = action
                    )
                )
                return@Button
            }

            if (activity == null) {
                onMessage("No se pudo iniciar la verificación biométrica.")
                return@Button
            }

            val biometricAuthManager = BiometricAuthManager(activity)

            if (!biometricAuthManager.canAuthenticate()) {
                onMessage("Este dispositivo no tiene biometría configurada.")
                return@Button
            }

            onMessage("Esperando verificación biométrica...")

            biometricAuthManager.authenticate(
                onSuccess = {
                    viewModel.registerAttendance(
                        employeeId = employee.id,
                        employeeName = employee.nombre,
                        date = getCurrentDate(),
                        time = getCurrentTime(),
                        actionType = action.name,
                        biometricVerified = true,
                        deviceName = "Android"
                    )

                    onMessage("Marcación registrada con biometría verificada.")
                },
                onError = { error ->
                    onMessage("Biometría fallida: $error")
                }
            )
        }
    ) {
        Text(text)
    }
}

private fun getCurrentDate(): String {
    return SimpleDateFormat(
        "yyyy-MM-dd",
        Locale.getDefault()
    ).format(Date())
}

private fun getCurrentTime(): String {
    return SimpleDateFormat(
        "HH:mm",
        Locale.getDefault()
    ).format(Date())
}