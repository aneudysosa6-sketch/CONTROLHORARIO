package com.example.controlhorario.ui.face

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.waitForUpOrCancellation
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETLogo
import com.example.controlhorario.face.PendingFaceEnrollmentButtonPolicy
import kotlinx.coroutines.delay
import kotlinx.coroutines.withTimeoutOrNull

@Composable
fun FaceIdentificationScreen(
    viewModel: FaceIdentificationViewModel,
    onIdentified: (Int) -> Unit,
    onKioskExit: () -> Unit,
    requireFaceExit: Boolean = false,
    onFaceExitConfirmed: () -> Unit = {},
    pendingFaceCount: Int = 0,
    onRegisterFace: () -> Unit = {},
) {
    val state by viewModel.state.collectAsState()
    var cameraGranted by remember { mutableStateOf(false) }
    var navigationConsumed by rememberSaveable { mutableStateOf(false) }
    var guidance by remember { mutableStateOf("Mire a la cámara para identificarse") }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        cameraGranted = it
    }

    LaunchedEffect(viewModel) {
        viewModel.start()
        permission.launch(Manifest.permission.CAMERA)
    }
    LaunchedEffect(state.employee?.id) {
        val employee = state.employee
        if (employee == null) {
            navigationConsumed = false
            return@LaunchedEffect
        }
        if (!navigationConsumed) {
            delay(650)
            if (!navigationConsumed) {
                navigationConsumed = true
                onIdentified(employee.id)
            }
        }
    }

    OSINETScreen {
        OSINETLogo(
            modifier = Modifier.fiveSecondHold {
                onKioskExit()
            },
            subtitle = "CONTROL HORARIO · TERMINAL FACIAL",
        )
        Spacer(Modifier.height(12.dp))
        OSINETHeader("Identificación facial", "Mire a la cámara para identificarse")
        Spacer(Modifier.height(16.dp))

        when (state.phase) {
            FaceIdentificationPhase.PREPARING,
            FaceIdentificationPhase.SYNCING -> IdentificationProgress(state.message)

            FaceIdentificationPhase.IDENTIFIED -> IdentificationMessage(state.message, success = true)

            FaceIdentificationPhase.SEARCHING,
            FaceIdentificationPhase.IDENTIFYING -> {
                if (cameraGranted) {
                    FaceEmbeddingCamera(
                        onEmbedding = viewModel::onEmbedding,
                        onGuidance = { guidance = it },
                        visualState = if (state.phase == FaceIdentificationPhase.IDENTIFYING) {
                            FaceVerificationState.Processing
                        } else {
                            FaceVerificationState.Ready
                        },
                        message = if (requireFaceExit) {
                            "Retírate de la cámara para continuar"
                        } else if (state.phase == FaceIdentificationPhase.IDENTIFYING) {
                            state.message
                        } else {
                            guidance
                        },
                        attempt = (state.completedSamples + 1).coerceAtMost(state.requiredSamples),
                        embeddingEnabled = !requireFaceExit,
                        onFaceExitConfirmed = onFaceExitConfirmed,
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        text = if (requireFaceExit) {
                            "Retírate de la cámara para continuar"
                        } else {
                            state.message
                        },
                        style = MaterialTheme.typography.titleMedium,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                } else {
                    IdentificationMessage("Se necesita permiso de cámara para identificar el rostro.")
                }

            }

            else -> IdentificationActions(
                state = state,
                onRetry = viewModel::retry,
                onSynchronize = viewModel::synchronizeTemplates,
            )
        }
        if (!requireFaceExit && PendingFaceEnrollmentButtonPolicy.visible(pendingFaceCount)) {
            Button(onClick = onRegisterFace, modifier = Modifier.fillMaxWidth()) {
                Text(PendingFaceEnrollmentButtonPolicy.label(pendingFaceCount))
            }
        }
        Spacer(Modifier.height(16.dp))
    }
}

private fun Modifier.fiveSecondHold(onCompleted: () -> Unit): Modifier = pointerInput(onCompleted) {
    awaitEachGesture {
        awaitFirstDown(requireUnconsumed = false)
        val releasedBeforeThreshold = withTimeoutOrNull(5_000L) {
            waitForUpOrCancellation()
            true
        } ?: false
        if (!releasedBeforeThreshold) onCompleted()
    }
}

@Composable
private fun IdentificationProgress(message: String) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        CircularProgressIndicator()
        Text(message, textAlign = TextAlign.Center)
    }
}

@Composable
private fun IdentificationMessage(message: String, success: Boolean = false) {
    Text(
        text = message,
        color = if (success) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
        style = MaterialTheme.typography.titleLarge,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth().padding(24.dp),
    )
}

@Composable
private fun IdentificationActions(
    state: FaceIdentificationUiState,
    onRetry: () -> Unit,
    onSynchronize: () -> Unit,
) {
    Column(
        modifier = Modifier.fillMaxWidth().padding(vertical = 18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        IdentificationMessage(state.message)
        if (state.phase == FaceIdentificationPhase.NO_TEMPLATES) {
            Button(onClick = onSynchronize, modifier = Modifier.fillMaxWidth()) {
                Text("Sincronizar rostros")
            }
        } else if (state.canRetry) {
            OutlinedButton(onClick = onRetry, modifier = Modifier.fillMaxWidth()) {
                Text("Reintentar rostro")
            }
        }
    }
}
