package com.example.controlhorario.ui.punch

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.controlhorario.fingerprint.external.TwoConnectFingerprintManager
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import kotlinx.coroutines.launch

@Composable
fun EmployeePunchScreen(
    viewModel: EmployeePunchViewModel,
    onVerified: (employeeId: Int) -> Unit,
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var readerStatus by remember { mutableStateOf("Preparando lector 2Connect USB...") }
    var busy by remember { mutableStateOf(false) }
    var lastAutoVerifiedEmployeeId by remember { mutableIntStateOf(0) }
    val twoConnectManager = remember(context) {
        TwoConnectFingerprintManager(context) { status -> readerStatus = status }
    }

    DisposableEffect(twoConnectManager) {
        twoConnectManager.requestUsbPermission()
        onDispose { twoConnectManager.release() }
    }

    LaunchedEffect(state.code) {
        if (state.code.length == EmployeePunchViewModel.REQUIRED_PIN_LENGTH &&
            state.employee == null &&
            !state.identifying &&
            !busy
        ) {
            viewModel.identifyEmployee()
        }
    }

    LaunchedEffect(state.employee?.id, state.hasTwoConnectTemplate) {
        val employee = state.employee ?: return@LaunchedEffect
        if (!state.hasTwoConnectTemplate || busy || lastAutoVerifiedEmployeeId == employee.id) return@LaunchedEffect
        lastAutoVerifiedEmployeeId = employee.id
        busy = true
        viewModel.setMessage("Empleado identificado. Coloque el dedo en el lector 2Connect.")
        coroutineScope.launch {
            val storedTemplate = viewModel.getStoredTemplateBase64()
            if (storedTemplate.isNullOrBlank()) {
                busy = false
                viewModel.clearAfterFailure("Este empleado no tiene huella 2Connect registrada.")
                return@launch
            }
            val capture = twoConnectManager.captureTemplateForVerification()
            if (!capture.success) {
                busy = false
                viewModel.clearAfterFailure(capture.message)
                return@launch
            }
            val score = twoConnectManager.matchTemplates(storedTemplate, capture.templateBase64)
            busy = false
            if (score > 0) {
                viewModel.markFingerprintVerified(score)
                onVerified(employee.id)
            } else {
                viewModel.clearAfterFailure("Huella incorrecta. Intente nuevamente.")
            }
        }
    }

    OSINETScreen {
        OSINETHeader(
            title = "Registro de código",
            subtitle = "Ingresa tu código de empleado"
        )
        Spacer(Modifier.height(18.dp))
        Text(
            text = readerStatus,
            color = OSINETColors.TextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(22.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(OSINETColors.SurfaceAlt, RoundedCornerShape(18.dp))
                .padding(horizontal = 24.dp, vertical = 24.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            Text(
                text = state.code.ifBlank { "" }.padEnd(EmployeePunchViewModel.REQUIRED_PIN_LENGTH, '•'),
                color = OSINETColors.TextPrimary,
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold
            )
        }

        Spacer(Modifier.height(18.dp))
        NumericPad(
            enabled = !busy && !state.identifying,
            onDigit = viewModel::appendDigit,
            onDelete = viewModel::deleteLastDigit,
            onClear = viewModel::clear
        )

        if (state.identifying || busy) {
            Spacer(Modifier.height(18.dp))
            CircularProgressIndicator(color = OSINETColors.Green)
            Spacer(Modifier.height(8.dp))
            Text(
                text = if (busy) "Verificando huella 2Connect..." else "Buscando empleado...",
                color = OSINETColors.TextSecondary
            )
        }

        if (state.message.isNotBlank()) {
            Spacer(Modifier.height(14.dp))
            Text(
                text = state.message,
                color = OSINETColors.TextPrimary,
                textAlign = TextAlign.Center,
                modifier = Modifier.fillMaxWidth()
            )
        }

        state.employee?.let { employee ->
            Spacer(Modifier.height(14.dp))
            OSINETCard {
                Text("Empleado: ${employee.nombre}", color = OSINETColors.TextPrimary)
                Text("Código: ${employee.employeeCode.ifBlank { employee.pin }}", color = OSINETColors.TextSecondary)
                Text(
                    text = if (state.hasTwoConnectTemplate) "Huella 2Connect: registrada" else "Huella 2Connect: no registrada",
                    color = if (state.hasTwoConnectTemplate) OSINETColors.GreenSoft else OSINETColors.Warning
                )
            }
        }

        Spacer(Modifier.height(18.dp))
        OSINETButton("Solicitar permiso USB", onClick = { twoConnectManager.requestUsbPermission() })
        Spacer(Modifier.height(10.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}

@Composable
private fun NumericPad(
    enabled: Boolean,
    onDigit: (String) -> Unit,
    onDelete: () -> Unit,
    onClear: () -> Unit
) {
    val rows = listOf(
        listOf("1", "2", "3"),
        listOf("4", "5", "6"),
        listOf("7", "8", "9"),
        listOf("C", "0", "⌫")
    )
    Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
        rows.forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                row.forEach { key ->
                    Button(
                        modifier = Modifier
                            .weight(1f)
                            .height(56.dp),
                        enabled = enabled,
                        shape = RoundedCornerShape(18.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = OSINETColors.GreenSoft,
                            contentColor = OSINETColors.Background,
                            disabledContainerColor = OSINETColors.SurfaceAlt,
                            disabledContentColor = OSINETColors.TextSecondary
                        ),
                        onClick = {
                            when (key) {
                                "C" -> onClear()
                                "⌫" -> onDelete()
                                else -> onDigit(key)
                            }
                        }
                    ) { Text(key, fontWeight = FontWeight.SemiBold) }
                }
            }
        }
    }
}
