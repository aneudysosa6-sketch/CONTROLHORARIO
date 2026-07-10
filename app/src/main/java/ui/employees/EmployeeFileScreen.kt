package com.example.controlhorario.ui.employees

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.model.Employee
import com.example.controlhorario.ui.components.OSINETButton

@Composable
fun EmployeeFileScreen(
    employee: Employee?,
    onGeneralInfoClick: () -> Unit,
    onDocumentsClick: () -> Unit,
    onAttendanceClick: () -> Unit,
    onPayrollClick: () -> Unit,
    onCreditsClick: () -> Unit,
    onPermissionsClick: () -> Unit,
    onWarningsClick: () -> Unit,
    onTrainingsClick: () -> Unit,
    onEvaluationsClick: () -> Unit,
    onCertificatesClick: () -> Unit,
    onBack: () -> Unit
) {
    if (employee == null) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp)
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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text(
            text = "Expediente Digital",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(6.dp))

        Text(
            text = employee.nombre,
            style = MaterialTheme.typography.titleMedium
        )

        Spacer(modifier = Modifier.height(20.dp))

        OSINETButton(
            text = "👤 Información general",
            onClick = onGeneralInfoClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "📁 Documentos",
            onClick = onDocumentsClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "🕒 Historial de asistencia",
            onClick = onAttendanceClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "💰 Nómina",
            onClick = onPayrollClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "💳 Créditos y descuentos",
            onClick = onCreditsClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "📄 Permisos",
            onClick = onPermissionsClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "⚠️ Amonestaciones",
            onClick = onWarningsClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "🎓 Capacitaciones",
            onClick = onTrainingsClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "📈 Evaluaciones",
            onClick = onEvaluationsClick
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETButton(
            text = "📄 Certificaciones",
            onClick = onCertificatesClick
        )

        Spacer(modifier = Modifier.height(24.dp))

        OutlinedButton(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("⬅ Volver")
        }
    }
}