package com.example.controlhorario.ui.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.ui.components.OSINETButton

@Composable
fun CompanySettingsScreen(
    onCompanyInfoClick: () -> Unit,
    onBranchesClick: () -> Unit,
    onDepartmentsClick: () -> Unit,
    onWorkScheduleTemplatesClick: () -> Unit,
    onLaborCalendarClick: () -> Unit,
    onPayrollSettingsClick: () -> Unit,
    onNotificationsClick: () -> Unit,
    onBack: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
    ) {

        Text(
            text = "Configuración de Empresa",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(20.dp))

        OSINETButton(
            text = "🏢 Datos de la empresa",
            onClick = onCompanyInfoClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "🏬 Sucursales",
            onClick = onBranchesClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "🏢 Departamentos",
            onClick = onDepartmentsClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "🕒 Plantillas de jornada",
            onClick = onWorkScheduleTemplatesClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "📅 Calendario laboral",
            onClick = onLaborCalendarClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "💰 Configuración de nómina",
            onClick = onPayrollSettingsClick
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETButton(
            text = "🔔 Notificaciones y notificaciones",
            onClick = onNotificationsClick
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