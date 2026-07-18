package com.example.controlhorario.ui.punch

import android.util.Log
import androidx.activity.compose.BackHandler
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
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.fingerprint.external.FingerprintVerificationAttemptGate
import com.example.controlhorario.fingerprint.external.FingerprintVerificationPolicy
import com.example.controlhorario.fingerprint.external.FingerprintVerificationResult
import com.example.controlhorario.fingerprint.external.TwoConnectFingerprintManager
import com.example.controlhorario.security.DeviceIdentityManager
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val FINGERPRINT_RETRY_DELAY_MS = 500L

private enum class FingerprintAttemptState {
    IDLE,
    CAPTURING,
    WAITING_FINGER_LIFT,
    READY_TO_RETRY,
    SUCCESS,
    CANCELLED
}

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
    var readerRevision by remember { mutableIntStateOf(0) }
    var busy by remember { mutableStateOf(false) }
    var verificationJob by remember { mutableStateOf<Job?>(null) }
    var retryJob by remember { mutableStateOf<Job?>(null) }
    var fingerprintAttemptState by remember { mutableStateOf(FingerprintAttemptState.IDLE) }
    val attemptGate = remember { FingerprintVerificationAttemptGate() }

    val twoConnectManager = remember(context) {
        TwoConnectFingerprintManager(context) { status ->
            readerStatus = status
            if (
                status.contains("concedido", ignoreCase = true) ||
                status.contains("conectado", ignoreCase = true) ||
                status.contains("listo", ignoreCase = true)
            ) {
                readerRevision += 1
            }
        }
    }

    fun logRetry(
        attemptId: Long,
        state: String,
        waitingFingerLift: Boolean,
        fingerLiftDetected: Boolean? = null,
        retryScheduled: Boolean,
        cancelReason: String? = null
    ) {
        if (!BuildConfig.DEBUG) return
        Log.d(
            "FINGERPRINT_RETRY",
            "attemptId=$attemptId state=$state waitingFingerLift=$waitingFingerLift " +
                "fingerLiftDetected=$fingerLiftDetected retryScheduled=$retryScheduled " +
                "verificationJobActive=${verificationJob?.isActive == true} " +
                "retryJobActive=${retryJob?.isActive == true} cancelReason=$cancelReason"
        )
    }

    fun scheduleFingerprintRetry(employeeId: Int, attemptId: Long) {
        retryJob?.cancel()
        fingerprintAttemptState = FingerprintAttemptState.READY_TO_RETRY
        logRetry(attemptId, "READY_TO_RETRY", false, retryScheduled = true)
        retryJob = coroutineScope.launch {
            delay(FINGERPRINT_RETRY_DELAY_MS)
            val current = viewModel.state.value
            if (
                current.employee?.id == employeeId &&
                current.hasTwoConnectTemplate &&
                verificationJob?.isActive != true &&
                fingerprintAttemptState == FingerprintAttemptState.READY_TO_RETRY
            ) {
                fingerprintAttemptState = FingerprintAttemptState.IDLE
                logRetry(attemptId, "RETRY_STARTED", false, fingerLiftDetected = true, retryScheduled = false)
                readerRevision += 1
            } else {
                logRetry(attemptId, "RETRY_CANCELLED", false, retryScheduled = false, cancelReason = "state_changed")
            }
            retryJob = null
        }
    }

    fun clearEmployeeAndCancelFingerprint() {
        attemptGate.invalidate()
        retryJob?.cancel()
        verificationJob?.cancel()
        retryJob = null
        verificationJob = null
        busy = false
        fingerprintAttemptState = FingerprintAttemptState.CANCELLED
        logRetry(-1, "CANCELLED", false, retryScheduled = false, cancelReason = "clear")
        twoConnectManager.close()
        viewModel.clearEmployeeAndCancelFingerprint()
        fingerprintAttemptState = FingerprintAttemptState.IDLE
    }

    BackHandler {
        clearEmployeeAndCancelFingerprint()
        onBack()
    }

    DisposableEffect(twoConnectManager) {
        twoConnectManager.requestUsbPermission()
        onDispose {
            attemptGate.invalidate()
            retryJob?.cancel()
            verificationJob?.cancel()
            fingerprintAttemptState = FingerprintAttemptState.CANCELLED
            logRetry(-1, "CANCELLED", false, retryScheduled = false, cancelReason = "disposed")
            twoConnectManager.release()
        }
    }

    LaunchedEffect(state.code) {
        if (
            state.code.length == EmployeePunchViewModel.REQUIRED_PIN_LENGTH &&
            state.employee == null &&
            !state.identifying &&
            !busy
        ) {
            viewModel.identifyEmployee()
        }
    }

    LaunchedEffect(state.employee?.id, state.hasTwoConnectTemplate, readerRevision) {
        val employee = state.employee ?: return@LaunchedEffect
        if (
            !state.hasTwoConnectTemplate ||
            busy ||
            verificationJob?.isActive == true ||
            fingerprintAttemptState != FingerprintAttemptState.IDLE
        ) {
            return@LaunchedEffect
        }

        Log.i(
            "FINGERPRINT_UI_TRACE",
            "screen=EmployeePunchScreen button=AUTO_VERIFY employeeId=${employee.id} action=CLICK " +
                "managerClass=${twoConnectManager::class.java.name} " +
                "methodRequested=verifyFingerprint timestamp=${System.currentTimeMillis()}"
        )
        val attemptId = attemptGate.begin()
        fingerprintAttemptState = FingerprintAttemptState.CAPTURING
        verificationJob = coroutineScope.launch {
            var retry = false

            fun isCurrentAttempt(): Boolean =
                attemptGate.isCurrent(attemptId) &&
                    viewModel.state.value.employee?.id == employee.id

            fun logVerification(
                result: FingerprintVerificationResult,
                uiMessage: String
            ) {
                if (!BuildConfig.DEBUG) return

                val diagnostics = twoConnectManager.verificationDiagnostics()
                val score = when (result) {
                    is FingerprintVerificationResult.Match -> result.score
                    is FingerprintVerificationResult.NoMatch -> result.score
                    is FingerprintVerificationResult.DeviceError -> result.score
                    else -> null
                }
                val decision = when (result) {
                    is FingerprintVerificationResult.Match -> "MATCH"
                    is FingerprintVerificationResult.NoMatch -> "NO_MATCH"
                    is FingerprintVerificationResult.CaptureError -> "CAPTURE_FAILED"
                    is FingerprintVerificationResult.DeviceError -> "READER_ERROR"
                    is FingerprintVerificationResult.MissingTemplate -> "MISSING_TEMPLATE"
                }
                Log.d(
                    "FINGERPRINT_VERIFY",
                    "attemptId=" + attemptId +
                        " employeeId=" + employee.id +
                        " usbConnected=" + diagnostics.usbConnected +
                        " usbPermission=" + diagnostics.usbPermissionGranted +
                        " readerOpened=" + diagnostics.readerOpened +
                        " imageResult=" + diagnostics.imageResult +
                        " featureGenerationResult=" + diagnostics.featureGenerationResult +
                        " fpUpCharResult=" + diagnostics.templateDownloadResult +
                        " sdkReportedCapturedSize=" + diagnostics.sdkReportedCapturedSize +
                        " initMatchResult=" + diagnostics.initMatchResult +
                        " initMatchInvoked=" + diagnostics.initMatchInvoked +
                        " capturedSize=" + diagnostics.capturedSize +
                        " capturedNonZeroBytes=" + diagnostics.capturedNonZeroBytes +
                        " base64LengthRead=" + diagnostics.storedBase64Length +
                        " storedSize=" + diagnostics.storedSize +
                        " storedNonZeroBytes=" + diagnostics.storedNonZeroBytes +
                        " matchTemplateExecuted=" + diagnostics.matchTemplateExecuted +
                        " result=" + result::class.simpleName +
                        " score=" + score +
                        " threshold=100" +
                        " decision=" + (diagnostics.decision ?: decision) +
                        " failure=" + diagnostics.failure +
                        " uiMessage=" + uiMessage
                )
            }

            try {
                busy = true
                viewModel.setMessage("Esperando huella…")
                if (BuildConfig.DEBUG) {
                    Log.d(
                        "FINGERPRINT_VERIFY",
                        "attemptId=" + attemptId +
                            " employeeId=" + employee.id +
                            " stage=START" +
                            " usbConnected=" + twoConnectManager.isSupportedDeviceConnected() +
                            " usbPermission=" + twoConnectManager.hasUsbPermission() +
                            " readerOpened=" + twoConnectManager.isOpen()
                    )
                }

                val storedTemplate = viewModel.getStoredFingerprintTemplate()
                if (storedTemplate == null || storedTemplate.employeeId != employee.id) {
                    val result = FingerprintVerificationResult.MissingTemplate
                    logVerification(result, "Empleado sin huella 2Connect registrada.")
                    if (isCurrentAttempt()) {
                        viewModel.keepEmployeeForFingerprintRetry(
                            "Empleado sin huella 2Connect registrada."
                        )
                    }
                    return@launch
                }

                val capture = twoConnectManager.captureTemplateForVerification(
                    debugEmployeeId = employee.id,
                    attemptId = attemptId
                )
                if (!isCurrentAttempt()) return@launch

                val result = twoConnectManager.verifyCapturedTemplate(
                    debugEmployeeId = employee.id,
                    storedTemplateBase64 = storedTemplate.templateBase64,
                    storedTemplateSize = storedTemplate.templateSize,
                    capture = capture
                )
                if (!isCurrentAttempt()) return@launch

                when (result) {
                    is FingerprintVerificationResult.Match -> {
                        if (!FingerprintVerificationPolicy.canAuthorize(result)) {
                            viewModel.keepEmployeeForFingerprintRetry(
                                "No fue posible confirmar la huella."
                            )
                            return@launch
                        }

                        viewModel.markFingerprintVerified(result.score)
                        logVerification(result, "Huella 2Connect verificada. Abriendo asistencia.")
                        fingerprintAttemptState = FingerprintAttemptState.SUCCESS
                        val deviceId = DeviceIdentityManager(context).deviceId
                        if (deviceId.isNullOrBlank()) {
                            viewModel.keepEmployeeForFingerprintRetry(
                                "Dispositivo no enrolado."
                            )
                            return@launch
                        }

                        if (isCurrentAttempt()) {
                            JourneyBiometricGate.open(employee.id, deviceId)
                            onVerified(employee.id)
                        }
                    }

                    is FingerprintVerificationResult.NoMatch -> {
                        logVerification(result, "Huella incorrecta. Retire el dedo e intente nuevamente.")
                        viewModel.keepEmployeeForFingerprintRetry(
                            "Huella incorrecta. Retire el dedo e intente nuevamente."
                        )
                        fingerprintAttemptState = FingerprintAttemptState.WAITING_FINGER_LIFT
                        logRetry(
                            attemptId,
                            "NO_MATCH",
                            waitingFingerLift = true,
                            retryScheduled = false
                        )
                        val fingerLiftDetected = twoConnectManager.waitForFingerLift()
                        if (!isCurrentAttempt()) return@launch
                        logRetry(
                            attemptId,
                            "WAITING_FINGER_LIFT",
                            waitingFingerLift = true,
                            fingerLiftDetected = fingerLiftDetected,
                            retryScheduled = fingerLiftDetected
                        )
                        if (fingerLiftDetected) {
                            retry = true
                        } else {
                            fingerprintAttemptState = FingerprintAttemptState.IDLE
                            viewModel.keepEmployeeForFingerprintRetry(
                                "Retire el dedo del lector para intentar nuevamente."
                            )
                        }
                    }

                    is FingerprintVerificationResult.MissingTemplate -> {
                        logVerification(result, "Empleado sin huella 2Connect registrada.")
                        viewModel.keepEmployeeForFingerprintRetry(
                            "Empleado sin huella 2Connect registrada."
                        )
                    }

                    is FingerprintVerificationResult.CaptureError -> {
                        val readerReady =
                            twoConnectManager.isSupportedDeviceConnected() &&
                                twoConnectManager.hasUsbPermission()
                        viewModel.keepEmployeeForFingerprintRetry(
                            if (readerReady) {
                                "No se pudo leer la huella. Coloque el dedo nuevamente."
                            } else {
                                result.message
                            }
                        )
                        logVerification(result, viewModel.state.value.message)
                        // A reader/capture error has no captured finger to wait for. Retrying
                        // automatically produced repeated OpenDevice calls against the same SDK
                        // session; wait for a new explicit attempt instead.
                        fingerprintAttemptState = FingerprintAttemptState.IDLE
                        retry = false
                    }

                    is FingerprintVerificationResult.DeviceError -> {
                        val readerReady =
                            twoConnectManager.isSupportedDeviceConnected() &&
                                twoConnectManager.hasUsbPermission()
                        viewModel.keepEmployeeForFingerprintRetry(result.message)
                        logVerification(result, result.message)
                        retry = readerReady &&
                            !result.message.contains("umbral", ignoreCase = true)
                    }
                }
            } catch (cancelled: CancellationException) {
                if (attemptGate.isCurrent(attemptId)) {
                    fingerprintAttemptState = FingerprintAttemptState.CANCELLED
                    logRetry(attemptId, "CANCELLED", false, retryScheduled = false, cancelReason = "job_cancelled")
                }
                throw cancelled
            } catch (_: Exception) {
                if (isCurrentAttempt()) {
                    val readerReady =
                        twoConnectManager.isSupportedDeviceConnected() &&
                            twoConnectManager.hasUsbPermission()
                    viewModel.keepEmployeeForFingerprintRetry(
                        if (readerReady) {
                            "Error temporal del lector. Intente nuevamente."
                        } else {
                            "Lector 2Connect no disponible. Reconéctelo o solicite permiso USB."
                        }
                    )
                    retry = readerReady
                }
            } finally {
                if (attemptGate.isCurrent(attemptId)) {
                    busy = false
                    verificationJob = null
                }
            }

            if (
                retry &&
                isCurrentAttempt() &&
                viewModel.state.value.hasTwoConnectTemplate
            ) {
                scheduleFingerprintRetry(employee.id, attemptId)
            }
        }
    }

    val showUsbPermission =
        state.employee != null &&
            twoConnectManager.isSupportedDeviceConnected() &&
            !twoConnectManager.hasUsbPermission()

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
                text = state.code.ifBlank { "" }
                    .padEnd(EmployeePunchViewModel.REQUIRED_PIN_LENGTH, '•'),
                color = OSINETColors.TextPrimary,
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold
            )
        }

        Spacer(Modifier.height(18.dp))
        NumericPad(
            enabled = !busy && !state.identifying && state.employee == null,
            onDigit = viewModel::appendDigit,
            onDelete = viewModel::deleteLastDigit,
            onClear = ::clearEmployeeAndCancelFingerprint
        )

        if (state.identifying || busy) {
            Spacer(Modifier.height(18.dp))
            CircularProgressIndicator(color = OSINETColors.Green)
            Spacer(Modifier.height(8.dp))
            Text(
                text = if (busy) "Esperando huella…" else "Buscando empleado...",
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
                Text(
                    "Código: ${employee.employeeCode.ifBlank { employee.pin }}",
                    color = OSINETColors.TextSecondary
                )
                Text(
                    text = if (state.hasTwoConnectTemplate) {
                        "Huella 2Connect: registrada"
                    } else {
                        "Huella 2Connect: no registrada"
                    },
                    color = if (state.hasTwoConnectTemplate) {
                        OSINETColors.GreenSoft
                    } else {
                        OSINETColors.Warning
                    }
                )
            }
        }

        if (showUsbPermission) {
            Spacer(Modifier.height(18.dp))
            OSINETButton(
                "Solicitar permiso USB",
                onClick = { twoConnectManager.requestUsbPermission() }
            )
        }

        Spacer(Modifier.height(10.dp))
        OSINETSecondaryButton(
            "Volver",
            onClick = {
                clearEmployeeAndCancelFingerprint()
                onBack()
            }
        )
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
    Column(
        verticalArrangement = Arrangement.spacedBy(10.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
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
                        enabled = enabled || key == "C",
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
                    ) {
                        Text(key, fontWeight = FontWeight.SemiBold)
                    }
                }
            }
        }
    }
}
