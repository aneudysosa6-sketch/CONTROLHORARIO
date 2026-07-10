package com.example.controlhorario.ui.employees

import androidx.compose.foundation.layout.*
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
import com.example.controlhorario.model.Employee

@Composable
fun EmployeeAttendanceHistoryScreen(
    employee: Employee?,
    attendanceRecords: List<AttendanceEntity>,
    onBack: () -> Unit
) {
    if (employee == null) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp),
            verticalArrangement = Arrangement.Center
        ) {
            Text("Empleado no encontrado")

            Spacer(modifier = Modifier.height(16.dp))

            OutlinedButton(
                onClick = onBack,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("⬅ Volver")
            }
        }
        return
    }

    val employeeRecords = attendanceRecords
        .filter { it.employeeId == employee.id }
        .sortedWith(
            compareByDescending<AttendanceEntity> { it.date }
                .thenByDescending { it.time }
        )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text(
            text = "Historial de asistencia",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(6.dp))

        Text(
            text = employee.nombre,
            style = MaterialTheme.typography.titleMedium
        )

        Spacer(modifier = Modifier.height(20.dp))

        if (employeeRecords.isEmpty()) {
            Card(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFF111111)
                )
            ) {
                Column(modifier = Modifier.padding(18.dp)) {
                    Text(
                        text = "Este empleado todavía no tiene registros de asistencia.",
                        color = Color.White
                    )
                }
            }
        } else {
            employeeRecords.forEach { record ->
                AttendanceHistoryCard(record = record)

                Spacer(modifier = Modifier.height(12.dp))
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        OutlinedButton(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("⬅ Volver")
        }
    }
}

@Composable
private fun AttendanceHistoryCard(
    record: AttendanceEntity
) {
    val actionText = when (record.actionType) {
        "INICIO_JORNADA" -> "Inicio de jornada"
        "PAUSA" -> "Pausa"
        "REANUDAR" -> "Reanudar"
        "FIN_JORNADA" -> "Fin de jornada"
        else -> record.actionType
    }

    val biometricText = if (record.biometricVerified) {
        "Verificada"
    } else {
        "No verificada"
    }

    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = Color(0xFF111111)
        ),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Column(modifier = Modifier.padding(18.dp)) {
            Text("📅 Fecha: ${record.date}", color = Color.White)
            Text("🕒 Hora: ${record.time}", color = Color.White)
            Text("📌 Acción: $actionText", color = Color.White)
            Text("👆 Biometría: $biometricText", color = Color.White)

            if (record.latitude != 0.0 || record.longitude != 0.0) {
                Text(
                    text = "📍 Ubicación: ${record.latitude}, ${record.longitude}",
                    color = Color.White
                )
            }

            if (record.deviceName.isNotBlank()) {
                Text("📱 Dispositivo: ${record.deviceName}", color = Color.White)
            }

            if (record.notes.isNotBlank()) {
                Text("📝 Nota: ${record.notes}", color = Color.White)
            }
        }
    }
}