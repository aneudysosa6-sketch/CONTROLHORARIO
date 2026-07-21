package com.example.controlhorario.ui.punch

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.controlhorario.engine.JourneyAction
import com.example.controlhorario.engine.JourneyStatus
import com.example.controlhorario.model.Employee
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton

@Composable
fun Rc2EmployeeAttendanceScreen(
    employee: Employee?,
    viewModel: JourneyViewModel,
    onFinish: () -> Unit
) {
    BackHandler(onBack = onFinish)
    val journey by viewModel.journey.collectAsState()
    val busy by viewModel.busy.collectAsState()
    val error by viewModel.error.collectAsState()
    val authorized by viewModel.isPunchAuthorized.collectAsState()
    val remotePresentation by viewModel.remotePresentation.collectAsState()
    val status = JourneyActionAvailability.effectiveStatus(journey?.status,remotePresentation.access)
    val allowed = JourneyActionAvailability.allowedActions(journey?.status,remotePresentation.access)
    val journeyStateReady = remotePresentation.actionsAllowed && status != null
    val stateMessage = when {
        remotePresentation.loadingRemote -> remotePresentation.message
        !remotePresentation.actionsAllowed -> remotePresentation.message
        remotePresentation.access == JourneyRemoteAccess.PENDING -> remotePresentation.message
        status == JourneyStatus.FINALIZADA -> "La jornada de hoy ya fue finalizada."
        authorized -> "Rostro validado. Registra una sola acción."
        else -> "Autorización vencida. Confirme su rostro nuevamente."
    }

    OSINETScreen {
        OSINETHeader("Registrar jornada", "Selecciona una acción permitida")
        Spacer(Modifier.height(18.dp))
        OSINETCard {
            Text(
                employee?.nombre ?: "Empleado no encontrado",
                color = OSINETColors.TextPrimary,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = when {
                    remotePresentation.loadingRemote -> "Estado actual: Confirmando…"
                    status == null -> "Estado actual: No confirmado"
                    else -> "Estado actual: ${statusLabel(status)}"
                },
                color = OSINETColors.GreenSoft
            )
            if (!remotePresentation.loadingRemote && journey != null) {
                Text(
                    "Trabajado: ${journey?.workedMinutes ?: 0} min · Pausa: ${journey?.breakMinutes ?: 0} min",
                    color = OSINETColors.TextSecondary
                )
            }
        }
        Spacer(Modifier.height(14.dp))
        if (remotePresentation.loadingRemote) {
            CircularProgressIndicator(
                modifier = Modifier.align(Alignment.CenterHorizontally),
                color = OSINETColors.Green
            )
            Spacer(Modifier.height(12.dp))
        }
        Text(
            stateMessage,
            color = OSINETColors.TextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(18.dp))
        JourneyActionButton(
            "Iniciar Jornada",
            JourneyAction.INICIAR,
            allowed,
            busy,
            authorized,
            journeyStateReady,
            employee,
            viewModel,
            onFinish
        )
        Spacer(Modifier.height(10.dp))
        JourneyActionButton(
            "Pausar Jornada",
            JourneyAction.PAUSAR,
            allowed,
            busy,
            authorized,
            journeyStateReady,
            employee,
            viewModel,
            onFinish
        )
        Spacer(Modifier.height(10.dp))
        JourneyActionButton(
            "Reanudar Jornada",
            JourneyAction.REANUDAR,
            allowed,
            busy,
            authorized,
            journeyStateReady,
            employee,
            viewModel,
            onFinish
        )
        Spacer(Modifier.height(10.dp))
        JourneyActionButton(
            "Finalizar Jornada",
            JourneyAction.FINALIZAR,
            allowed,
            busy,
            authorized,
            journeyStateReady,
            employee,
            viewModel,
            onFinish
        )
        if (error.isNotBlank()) {
            Spacer(Modifier.height(12.dp))
            Text(
                error,
                color = OSINETColors.Warning,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
        }
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Cancelar", onFinish)
    }
}

@Composable
private fun JourneyActionButton(
    text: String,
    action: JourneyAction,
    allowed: Set<JourneyAction>,
    busy: Boolean,
    authorized: Boolean,
    journeyStateReady: Boolean,
    employee: Employee?,
    viewModel: JourneyViewModel,
    onFinish: () -> Unit
) = OSINETButton(
    text = text,
    onClick = { employee?.let { viewModel.record(it, action, onFinish) } },
    enabled = employee != null && !busy && authorized && journeyStateReady && action in allowed
)

private fun statusLabel(status: JourneyStatus) = when (status) {
    JourneyStatus.SIN_INICIAR -> "SIN INICIAR"
    JourneyStatus.EN_CURSO -> "EN CURSO"
    JourneyStatus.EN_PAUSA -> "EN PAUSA"
    JourneyStatus.FINALIZADA -> "FINALIZADA"
}
