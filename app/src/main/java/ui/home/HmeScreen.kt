package com.example.controlhorario.ui.home

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.engine.AttendanceAction
import com.example.controlhorario.ui.components.OSINETButton

@Composable
fun HomeScreen(
    totalEmployees: Int,
    todayRecords: List<AttendanceEntity>,
    onEmployeesClick: () -> Unit,
    onSettingsClick: () -> Unit,
    onAttendanceClick: () -> Unit,
    onPayrollClick: () -> Unit = {},
    onReportsClick: () -> Unit = {},
    onSupervisorClick: () -> Unit = {},
    onNotificationsClick: () -> Unit = {}
) {
    val lastActionByEmployee = todayRecords
        .groupBy { it.employeeId }
        .mapValues { (_, records) ->
            records.maxByOrNull { it.id }?.actionType
        }

    val working = lastActionByEmployee.values.count {
        it == AttendanceAction.INICIO_JORNADA.name ||
                it == AttendanceAction.REANUDAR.name
    }

    val paused = lastActionByEmployee.values.count {
        it == AttendanceAction.PAUSA.name
    }

    val finished = lastActionByEmployee.values.count {
        it == AttendanceAction.FIN_JORNADA.name
    }

    val withoutDay = (totalEmployees - working - paused - finished)
        .coerceAtLeast(0)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
    ) {
        Text(
            text = "OSINET Time",
            style = MaterialTheme.typography.headlineMedium
        )

        Text(
            text = "Control Inteligente de Asistencia y Nómina",
            style = MaterialTheme.typography.bodyMedium
        )

        Spacer(modifier = Modifier.height(20.dp))

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(20.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color(0xFF111111)
            ),
            elevation = CardDefaults.cardElevation(6.dp)
        ) {
            Column(
                modifier = Modifier.padding(18.dp)
            ) {
                Text(
                    text = "📊 Resumen de hoy",
                    color = Color.White
                )

                Spacer(modifier = Modifier.height(10.dp))

                Text(
                    text = "👥 Empleados registrados: $totalEmployees",
                    color = Color.White
                )

                Text(
                    text = "🟢 Trabajando: $working",
                    color = Color(0xFF4CAF50)
                )

                Text(
                    text = "☕ En pausa: $paused",
                    color = Color(0xFFFFC107)
                )

                Text(
                    text = "🏁 Finalizados: $finished",
                    color = Color(0xFF64B5F6)
                )

                Text(
                    text = "⚪ Sin jornada: $withoutDay",
                    color = Color.LightGray
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        OSINETButton(
            text = "👥 Empleados",
            onClick = onEmployeesClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "🕒 Asistencia",
            onClick = onAttendanceClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "💰 Nómina",
            onClick = onPayrollClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "📊 Reportes",
            onClick = onReportsClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "⚙️ Configuración",
            onClick = onSettingsClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "🤖 Supervisor IA",
            onClick = onSupervisorClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "🔔 Notificaciones",
            onClick = onNotificationsClick
        )
    }
}