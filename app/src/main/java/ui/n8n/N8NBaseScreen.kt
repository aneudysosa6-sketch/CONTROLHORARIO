package com.example.controlhorario.ui.n8n

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.N8NOutboxEntity
import com.example.controlhorario.database.N8NSettingsEntity
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun N8NBaseScreen(
    viewModel: N8NBaseViewModel,
    onBack: () -> Unit
) {
    val settings by viewModel.settings.collectAsState()
    val outbox by viewModel.outbox.collectAsState()
    val logs by viewModel.logs.collectAsState()

    var webhookUrl by remember { mutableStateOf("") }
    var apiKey by remember { mutableStateOf("") }
    var bearerToken by remember { mutableStateOf("") }
    var timeoutText by remember { mutableStateOf("20") }
    var enabled by remember { mutableStateOf(false) }

    LaunchedEffect(settings?.updatedAt, settings?.lastTestAt) {
        val current = settings ?: return@LaunchedEffect
        webhookUrl = current.webhookUrl
        apiKey = current.apiKey
        bearerToken = current.bearerToken
        timeoutText = current.timeoutSeconds.toString()
        enabled = current.enabled
    }

    val pending = outbox.count { it.status == N8NOutboxEntity.STATUS_PENDING }
    val sent = outbox.count { it.status == N8NOutboxEntity.STATUS_SENT }
    val errors = outbox.count { it.status == N8NOutboxEntity.STATUS_ERROR }

    OSINETScreen {
        OSINETHeader(
            title = "Configuración N8N",
            subtitle = "Webhook central para WhatsApp, Gmail, eventos, permisos y nómina"
        )
        Spacer(Modifier.height(16.dp))

        OSINETCard {
            Text("Estado", color = OSINETColors.TextPrimary, style = MaterialTheme.typography.titleMedium)
            val status = settings?.lastStatus ?: N8NSettingsEntity.STATUS_NOT_CONFIGURED
            val statusColor = when (status) {
                N8NSettingsEntity.STATUS_CONNECTED -> OSINETColors.Green
                N8NSettingsEntity.STATUS_ERROR -> OSINETColors.Danger
                else -> OSINETColors.Warning
            }
            Text(status, color = statusColor, style = MaterialTheme.typography.bodyLarge)
            if (!settings?.lastMessage.isNullOrBlank()) {
                Text(settings?.lastMessage.orEmpty(), color = OSINETColors.TextSecondary)
            }
            if (!settings?.lastTestAt.isNullOrBlank()) {
                Text("Última prueba: ${settings?.lastTestAt}", color = OSINETColors.TextSecondary)
            }
        }

        Spacer(Modifier.height(12.dp))

        OSINETCard {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Integración activa", color = OSINETColors.TextPrimary)
                    Text("Cuando esté apagada, la app solo guardará eventos locales.", color = OSINETColors.TextSecondary)
                }
                Switch(checked = enabled, onCheckedChange = { enabled = it })
            }
            OSINETTextField(webhookUrl, { webhookUrl = it }, "URL Webhook N8N", Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OSINETTextField(apiKey, { apiKey = it }, "API Key opcional", Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OSINETTextField(
                value = bearerToken,
                onValueChange = { bearerToken = it },
                label = "Bearer Token opcional",
                modifier = Modifier.fillMaxWidth(),
                visualTransformation = PasswordVisualTransformation()
            )
            Spacer(Modifier.height(8.dp))
            OSINETTextField(
                value = timeoutText,
                onValueChange = { timeoutText = it.filter { ch -> ch.isDigit() } },
                label = "Timeout segundos",
                modifier = Modifier.fillMaxWidth(),
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
            )
            Spacer(Modifier.height(12.dp))
            OSINETButton(
                text = "Guardar configuración",
                onClick = {
                    viewModel.saveSettings(webhookUrl, apiKey, bearerToken, timeoutText.toIntOrNull() ?: 20, enabled)
                }
            )
            Spacer(Modifier.height(8.dp))
            OSINETButton(
                text = "Probar conexión",
                onClick = {
                    viewModel.testConnection(webhookUrl, apiKey, bearerToken, timeoutText.toIntOrNull() ?: 20, enabled)
                }
            )
            Spacer(Modifier.height(8.dp))
            OSINETSecondaryButton("Restablecer", onClick = { viewModel.resetSettings() })
        }

        Spacer(Modifier.height(12.dp))

        OSINETCard {
            Text("Cola local", color = OSINETColors.TextPrimary, style = MaterialTheme.typography.titleMedium)
            Text("Pendientes: $pending", color = OSINETColors.Warning)
            Text("Enviados: $sent", color = OSINETColors.Green)
            Text("Errores: $errors", color = OSINETColors.Danger)
            Spacer(Modifier.height(8.dp))
            OSINETButton("Crear evento de prueba", onClick = { viewModel.queueTestEvent() })
            Spacer(Modifier.height(8.dp))
            OSINETButton("Enviar pendientes", onClick = { viewModel.sendPending() })
        }

        Spacer(Modifier.height(12.dp))

        OSINETCard {
            Text("Historial de sincronización", color = OSINETColors.TextPrimary, style = MaterialTheme.typography.titleMedium)
            if (logs.isEmpty()) {
                Text("Sin registros todavía.", color = OSINETColors.TextSecondary)
            } else {
                logs.take(8).forEach { log ->
                    Text("${log.eventType} - ${log.status}", color = OSINETColors.TextPrimary)
                    val detail = if (log.errorMessage.isBlank()) log.responseMessage else log.errorMessage
                    if (detail.isNotBlank()) Text(detail, color = OSINETColors.TextSecondary)
                    Spacer(Modifier.height(6.dp))
                }
            }
            Spacer(Modifier.height(8.dp))
            OSINETSecondaryButton("Limpiar historial", onClick = { viewModel.clearLogs() })
        }

        Spacer(Modifier.height(16.dp))
        OSINETSecondaryButton("Volver", onClick = onBack)
    }
}
