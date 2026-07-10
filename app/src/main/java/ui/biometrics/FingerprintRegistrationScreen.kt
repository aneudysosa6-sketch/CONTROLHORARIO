package com.example.controlhorario.ui.biometrics

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.controlhorario.fingerprint.external.TwoConnectFingerprintManager
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETStatusText
import com.example.controlhorario.ui.components.OSINETTextField
import kotlinx.coroutines.launch

@Composable
fun FingerprintRegistrationScreen(
    viewModel: FingerprintRegistrationViewModel,
    onBack: () -> Unit,
    initialEmployeeCode: String = ""
) {
    val state by viewModel.state.collectAsState()
    val context = LocalContext.current
    val coroutineScope = rememberCoroutineScope()
    var employeeCode by remember(initialEmployeeCode) { mutableStateOf(initialEmployeeCode.filter(Char::isDigit).take(5)) }
    var supervisor by remember { mutableStateOf("admin") }
    var busy by remember { mutableStateOf(false) }
    var readerStatus by remember { mutableStateOf("Preparando lector 2Connect USB...") }
    val twoConnectManager = remember(context) {
        TwoConnectFingerprintManager(context) { status -> readerStatus = status }
    }

    DisposableEffect(twoConnectManager) {
        twoConnectManager.requestUsbPermission()
        onDispose { twoConnectManager.release() }
    }

    LaunchedEffect(initialEmployeeCode) {
        if (initialEmployeeCode.filter(Char::isDigit).isNotBlank()) {
            viewModel.identifyEmployee(initialEmployeeCode)
        }
    }

    OSINETScreen {
        OSINETHeader(
            title = "Registro de huella",
            subtitle = "Use el lector USB 2Connect conectado por OTG"
        )
        Spacer(Modifier.height(12.dp))
        OSINETStatusText(readerStatus)
        Spacer(Modifier.height(18.dp))

        OSINETTextField(employeeCode, { employeeCode = it.filter(Char::isDigit).take(5) }, "Código empleado", Modifier.fillMaxWidth())
        Spacer(Modifier.height(10.dp))
        OSINETTextField(supervisor, { supervisor = it }, "Registrado por", Modifier.fillMaxWidth())
        Spacer(Modifier.height(14.dp))

        OSINETButton(text = "Buscar empleado", onClick = { viewModel.identifyEmployee(employeeCode) })

        state.selectedEmployee?.let { employee ->
            Spacer(Modifier.height(16.dp))
            OSINETCard {
                Text("Empleado: ${employee.nombre}", color = OSINETColors.TextPrimary, fontWeight = FontWeight.SemiBold)
                Text("Código: ${employee.employeeCode.ifBlank { employee.pin }}", color = OSINETColors.TextSecondary)
                Text(if (employee.fingerprintRegistered) "Estado: huella registrada" else "Estado: sin huella registrada", color = if (employee.fingerprintRegistered) OSINETColors.GreenSoft else OSINETColors.Warning)
                if (state.registeredTemplateSize > 0) {
                    Text("Plantilla 2Connect: ${state.registeredTemplateSize} bytes", color = OSINETColors.TextSecondary)
                }
            }
            Spacer(Modifier.height(14.dp))
            OSINETButton(
                text = if (employee.fingerprintRegistered) "Actualizar huella 2Connect" else "Registrar huella 2Connect",
                onClick = {
                    if (busy) return@OSINETButton
                    busy = true
                    viewModel.setMessage("Iniciando captura con lector 2Connect...")
                    coroutineScope.launch {
                        val capture = twoConnectManager.enrollFingerprint()
                        busy = false
                        if (capture.success) {
                            viewModel.registerTwoConnectFingerprint(
                                registeredBy = supervisor,
                                templateBase64 = capture.templateBase64,
                                templateSize = capture.templateSize
                            )
                        } else {
                            viewModel.setMessage(capture.message)
                        }
                    }
                }
            )
        }

        if (busy) {
            Spacer(Modifier.height(12.dp))
            CircularProgressIndicator(color = OSINETColors.Green)
            OSINETStatusText("Espere. Capturando huella desde el lector externo...")
        }

        Spacer(Modifier.height(10.dp))
        OSINETButton(text = "Solicitar permiso USB", onClick = { twoConnectManager.requestUsbPermission() })
        Spacer(Modifier.height(10.dp))
        OSINETSecondaryButton(text = "Volver", onClick = onBack)

        if (state.message.isNotBlank()) {
            Spacer(Modifier.height(16.dp))
            OSINETStatusText(state.message, OSINETColors.TextPrimary)
        }
    }
}
