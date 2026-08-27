package com.example.controlhorario.device

import android.util.Log
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.controlhorario.R
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.database.DeviceEnrollmentEntity
import com.example.controlhorario.security.DeviceIdentityManager
import com.example.controlhorario.security.TerminalAuthorizationManager
import java.time.Instant
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun DeviceEnrollmentScreen(onReady: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var code by remember { mutableStateOf("") }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    val identity = remember { DeviceIdentityManager(context) }
    val enrollmentEndpoint = stringResource(R.string.device_enrollment_url)
    val employeeSyncEndpoint = stringResource(R.string.employee_sync_url)

    Column(
        modifier = Modifier.fillMaxSize().padding(28.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "CÓDIGO DE REGISTRO DEL DISPOSITIVO",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(14.dp))
        Text(
            text = "Genere el código desde Web > Configuración general > Dispositivos.",
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(24.dp))
        OutlinedTextField(
            value = code,
            onValueChange = {
                code = it.filter(Char::isLetterOrDigit).uppercase().take(REGISTRATION_CODE_LENGTH)
                error = ""
            },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("Código de registro") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
            textStyle = MaterialTheme.typography.bodyLarge.copy(color = Color.Black),
        )
        if (error.isNotBlank()) {
            Spacer(Modifier.height(12.dp))
            Text(error, color = MaterialTheme.colorScheme.error, textAlign = TextAlign.Center)
        }
        Spacer(Modifier.height(18.dp))
        Button(
            enabled = !busy && code.length == REGISTRATION_CODE_LENGTH,
            modifier = Modifier.fillMaxWidth(),
            onClick = {
                busy = true
                error = ""
                scope.launch {
                    var credentialExpiresAt: String? = null
                    val result = runCatching {
                        withContext(Dispatchers.IO) {
                            val database = DatabaseProvider.getDatabase(context)
                            val enrollment = DeviceEnrollmentClient(enrollmentEndpoint).enroll(code, identity)
                            identity.completeEnrollment(enrollment.deviceId, enrollment.credential)
                            credentialExpiresAt = enrollment.expiresAt
                            database.deviceEnrollmentDao().save(
                                DeviceEnrollmentEntity(
                                    enrollment.deviceId,
                                    identity.installationId,
                                    enrollment.expiresAt,
                                ),
                            )
                            EmployeeSyncRepository(database).sync(
                                EmployeeSyncClient(employeeSyncEndpoint),
                                enrollment.deviceId,
                                enrollment.credential,
                            ).authorization
                        }
                    }
                    result.onSuccess { authorization ->
                        if (authorization != null) {
                            TerminalAuthorizationManager.recordAuthorized(
                                authorization.validatedAt,
                                authorization.credentialExpiresAt,
                                authorization.offlineLeaseExpiresAt,
                            )
                        } else {
                            TerminalAuthorizationManager.recordAuthorizedWithCredentialLease(
                                Instant.now().toString(),
                                requireNotNull(credentialExpiresAt),
                            )
                        }
                        DeviceSyncScheduler.start(context)
                        onReady()
                    }.onFailure { failure ->
                        Log.e(TAG, "No se pudo completar el registro del Terminal", failure)
                        if (identity.deviceId != null && credentialExpiresAt != null) {
                            TerminalAuthorizationManager.markPendingValidation(
                                requireNotNull(credentialExpiresAt),
                            )
                            DeviceSyncScheduler.start(context)
                            onReady()
                        } else {
                            error = "El código no es válido o no pudo verificarse."
                        }
                    }
                    busy = false
                }
            },
        ) {
            if (busy) CircularProgressIndicator() else Text("Registrar Terminal")
        }
    }
}

private const val REGISTRATION_CODE_LENGTH = 16
private const val TAG = "DeviceEnrollment"