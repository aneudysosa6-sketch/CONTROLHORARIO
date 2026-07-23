package com.example.controlhorario.ui.kiosk

import android.app.Activity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.example.controlhorario.kiosk.DeviceOwnerHelper
import com.example.controlhorario.kiosk.KioskController
import com.example.controlhorario.kiosk.KioskManager
import com.example.controlhorario.session.KioskModeManager

@Composable
fun KioskDeviceSettingsScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val activity = context as? Activity
    val manager = remember(context) { KioskManager(context) }
    var enabled by remember { mutableStateOf(manager.configuration().enabled) }
    var password by remember { mutableStateOf("") }
    var confirmation by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }

    Column(
        Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("Configuración del Dispositivo", style = MaterialTheme.typography.headlineSmall)
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF101E33)),
        ) {
            Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Column(Modifier.weight(1f)) {
                        Text("Activar modo kiosco")
                        Text(
                            if (enabled) "ACTIVO" else "INACTIVO",
                            color = if (enabled) Color(0xFF2DD4A3) else Color(0xFFFF6378),
                        )
                    }
                    Switch(checked = enabled, onCheckedChange = { enabled = it; message = "" })
                }
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text("Contraseña de salida") },
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = confirmation,
                    onValueChange = { confirmation = it },
                    label = { Text("Confirmar contraseña") },
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Button(
                    onClick = {
                        message = when {
                            !enabled -> "Use «Desactivar kiosco» para confirmar la salida."
                            password.length < KioskManager.MIN_PASSWORD_LENGTH -> "La contraseña debe tener al menos 6 caracteres."
                            password != confirmation -> "Las contraseñas no coinciden."
                            !manager.enable(password.toCharArray()) -> "No fue posible guardar la configuración."
                            else -> {
                                KioskModeManager.activate()
                                activity?.let { KioskController(it).enter() }
                                password = ""
                                confirmation = ""
                                "Modo kiosco activado."
                            }
                        }
                    },
                    modifier = Modifier.fillMaxWidth(),
                ) { Text("Guardar") }
            }
        }
        DeviceStatusCard(enabled = manager.configuration().enabled)
        if (message.isNotBlank()) Text(message, color = MaterialTheme.colorScheme.primary)
        OutlinedButton(
            onClick = {
                if (manager.disable()) {
                    enabled = false
                    KioskModeManager.deactivate()
                    activity?.let { KioskController(it).exit() }
                    message = "Modo kiosco desactivado."
                }
            },
            enabled = manager.configuration().enabled,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Desactivar kiosco") }
        Spacer(Modifier.height(4.dp))
        TextButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("Volver") }
    }
}

@Composable
private fun DeviceStatusCard(enabled: Boolean) {
    val context = LocalContext.current
    val deviceOwner = remember(context) { DeviceOwnerHelper(context).isDeviceOwner() }
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Estado del dispositivo", style = MaterialTheme.typography.titleMedium)
            Text("Modo kiosco: ${if (enabled) "ACTIVO" else "INACTIVO"}")
            Text("Device Owner: ${if (deviceOwner) "PREPARADO" else "NO ASIGNADO"}")
        }
    }
}

@Composable
fun KioskExitDialog(
    onDismiss: () -> Unit,
    onExit: () -> Unit,
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val manager = remember(context) { KioskManager(context) }
    var password by remember { mutableStateOf("") }
    var invalid by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Salir del modo kiosco") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it; invalid = false },
                    label = { Text("Contraseña") },
                    visualTransformation = PasswordVisualTransformation(),
                    singleLine = true,
                )
                if (invalid) Text("Contraseña incorrecta.", color = MaterialTheme.colorScheme.error)
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancelar") } },
        confirmButton = {
            Button(onClick = {
                if (manager.verify(password.toCharArray()) && manager.disable()) {
                    KioskModeManager.deactivate()
                    activity?.let { KioskController(it).exit() }
                    onExit()
                } else {
                    invalid = true
                }
                password = ""
            }) { Text("Salir") }
        },
    )
}
