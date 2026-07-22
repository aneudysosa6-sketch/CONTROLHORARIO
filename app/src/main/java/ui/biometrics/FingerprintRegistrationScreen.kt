package com.example.controlhorario.ui.biometrics

import android.util.Log
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
import com.example.controlhorario.fingerprint.external.TwoConnectReaderProvider
import com.example.controlhorario.fingerprint.external.OfficialFingerprintDiagnostic
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETStatusText
import com.example.controlhorario.ui.components.OSINETTextField
import com.example.controlhorario.model.EmployeeCodePolicy
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
    var employeeCode by remember(initialEmployeeCode) {
        mutableStateOf(
            EmployeeCodePolicy.normalizeOrNull(initialEmployeeCode)
                ?: EmployeeCodePolicy.sanitizeInput(initialEmployeeCode)
        )
    }
    var supervisor by remember { mutableStateOf("admin") }
    var busy by remember { mutableStateOf(false) }
    var readerStatus by remember { mutableStateOf("Preparando lector 2Connect USB...") }
    var officialDiagnosticMessage by remember { mutableStateOf("") }
    val twoConnectManager = remember(context) {
        TwoConnectReaderProvider.acquire(context) { status -> readerStatus = status }
    }
    val officialDiagnostic = remember(context) {
        OfficialFingerprintDiagnostic(context) { status -> readerStatus = status }
    }

    LaunchedEffect(Unit) {
        Log.i(
            "REGISTER_SCREEN_OPENED",
            "screen=FingerprintRegistrationScreen initialEmployeeCodePresent=${initialEmployeeCode.isNotBlank()} " +
                "timestamp=${System.currentTimeMillis()}"
        )
    }

    DisposableEffect(twoConnectManager, officialDiagnostic) {
        twoConnectManager.requestUsbPermission()
        onDispose { officialDiagnostic.release() }
    }

    LaunchedEffect(initialEmployeeCode) {
        if (initialEmployeeCode.filter(Char::isDigit).isNotBlank()) {
            viewModel.identifyEmployee(initialEmployeeCode)
        }
    }

    OSINETScreen {
        OSINETHeader(
            title = "Registro facial",
            subtitle = "Use el registro facial local del dispositivo"
        )
        Spacer(Modifier.height(12.dp))
        OSINETStatusText(readerStatus)
        Spacer(Modifier.height(18.dp))

        OSINETTextField(employeeCode, { employeeCode = EmployeeCodePolicy.sanitizeInput(it) }, "Código empleado", Modifier.fillMaxWidth())
        Spacer(Modifier.height(10.dp))
        OSINETTextField(supervisor, { supervisor = it }, "Registrado por", Modifier.fillMaxWidth())
        Spacer(Modifier.height(14.dp))

        OSINETButton(text = "Buscar empleado", onClick = { viewModel.identifyEmployee(employeeCode) })

        state.selectedEmployee?.let { employee ->
            Spacer(Modifier.height(16.dp))
            OSINETCard {
                Text("Empleado: ${employee.nombre}", color = OSINETColors.TextPrimary, fontWeight = FontWeight.SemiBold)
                Text("Código: ${employee.employeeCode}", color = OSINETColors.TextSecondary)
                Text(if (employee.fingerprintRegistered) "Estado: rostro registrado" else "Estado: sin rostro registrado", color = if (employee.fingerprintRegistered) OSINETColors.GreenSoft else OSINETColors.Warning)
                if (state.registeredTemplateSize > 0) {
                    Text("Plantilla 2Connect: ${state.registeredTemplateSize} bytes", color = OSINETColors.TextSecondary)
                }
            }
            Spacer(Modifier.height(14.dp))
            OSINETButton(
                text = if (employee.fingerprintRegistered) "Actualizar rostro" else "Registrar rostro",
                onClick = {
                    if (busy) return@OSINETButton
                    Log.i(
                        "REGISTER_BUTTON_CLICKED",
                        "screen=FingerprintRegistrationScreen employeeId=${employee.id} " +
                            "operation=${if (employee.fingerprintRegistered) "UPDATE" else "CREATE"} " +
                            "timestamp=${System.currentTimeMillis()}"
                    )
                    Log.i(
                        "FINGERPRINT_UI_TRACE",
                        "screen=FingerprintRegistrationScreen " +
                            "button=${if (employee.fingerprintRegistered) "UPDATE_FINGERPRINT" else "CREATE_FINGERPRINT"} " +
                            "employeeId=${employee.id} action=CLICK " +
                            "managerClass=${twoConnectManager::class.java.name} " +
                            "methodRequested=enrollFingerprint timestamp=${System.currentTimeMillis()}"
                    )
                    busy = true
                    viewModel.setMessage("Iniciando captura con lector 2Connect...")
                    coroutineScope.launch {
                        val capture = twoConnectManager.enrollFingerprint(debugEmployeeId = employee.id)
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
            Spacer(Modifier.height(10.dp))
            OSINETSecondaryButton(
                text = "Diagnóstico oficial: registrar en memoria",
                onClick = {
                    if (busy) return@OSINETSecondaryButton
                    busy = true
                    coroutineScope.launch {
                        officialDiagnosticMessage = when (val result = officialDiagnostic.enrollReference()) {
                            is OfficialFingerprintDiagnostic.Result.Enrolled ->
                                "Diagnóstico oficial listo: referencia ${result.referenceSize} bytes en memoria."
                            is OfficialFingerprintDiagnostic.Result.Error -> result.message
                            is OfficialFingerprintDiagnostic.Result.Compared -> "Estado diagnóstico inesperado."
                        }
                        busy = false
                    }
                }
            )
            Spacer(Modifier.height(10.dp))
            OSINETSecondaryButton(
                text = "Diagnóstico oficial: capturar y comparar",
                onClick = {
                    if (busy) return@OSINETSecondaryButton
                    busy = true
                    coroutineScope.launch {
                        officialDiagnosticMessage = when (val result = officialDiagnostic.captureAndCompare()) {
                            is OfficialFingerprintDiagnostic.Result.Compared ->
                                "Diagnóstico: ref/ref=${result.refRef}; mat/mat=${result.matMat}; score=${result.score}."
                            is OfficialFingerprintDiagnostic.Result.Error -> result.message
                            is OfficialFingerprintDiagnostic.Result.Enrolled -> "Estado diagnóstico inesperado."
                        }
                        busy = false
                    }
                }
            )
        }

        if (busy) {
            Spacer(Modifier.height(12.dp))
            CircularProgressIndicator(color = OSINETColors.Green)
            OSINETStatusText("Espere. Preparando el registro facial...")
        }

        Spacer(Modifier.height(10.dp))
        OSINETButton(text = "Solicitar permiso USB", onClick = { twoConnectManager.requestUsbPermission() })
        Spacer(Modifier.height(10.dp))
        OSINETSecondaryButton(text = "Volver", onClick = onBack)

        if (state.message.isNotBlank()) {
            Spacer(Modifier.height(16.dp))
            OSINETStatusText(state.message, OSINETColors.TextPrimary)
        }
        if (officialDiagnosticMessage.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            OSINETStatusText(officialDiagnosticMessage, OSINETColors.TextPrimary)
        }
    }
}
