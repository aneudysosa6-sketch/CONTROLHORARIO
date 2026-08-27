package com.example.controlhorario.ui.kiosk

import android.app.Activity
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.unit.dp
import com.example.controlhorario.kiosk.DeviceOwnerHelper
import com.example.controlhorario.kiosk.KioskController
import com.example.controlhorario.kiosk.KioskManager
import com.example.controlhorario.session.KioskModeManager

@Composable
fun KioskDeviceSettingsScreen(
    onBack: () -> Unit,
    onActivated: () -> Unit,
    onFaceAuthSettings: () -> Unit,
) {
    val context = LocalContext.current
    val activity = context as? Activity
    val manager = remember(context) { KioskManager(context) }
    val deviceOwner = remember(context) {
        DeviceOwnerHelper(context).isDeviceOwner()
    }

    var enabled by remember {
        mutableStateOf(manager.configuration().enabled)
    }

    var message by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            "Terminal facial",
            style = MaterialTheme.typography.headlineSmall,
            color = Color.White,
        )

        Text(
            "Al activarlo, este dispositivo quedará dedicado al reconocimiento facial y al registro de jornadas de los empleados.",
            style = MaterialTheme.typography.bodyMedium,
            color = Color(0xFFD7E2F0),
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = Color(0xFF101E33),
            ),
        ) {
            Column(
                modifier = Modifier.padding(18.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Text(
                    "Estado: ${if (enabled) "ACTIVO" else "INACTIVO"}",
                    color = if (enabled) {
                        Color(0xFF2DD4A3)
                    } else {
                        Color(0xFFFF6378)
                    },
                    style = MaterialTheme.typography.titleMedium,
                )

                Text(
                    "Una vez activo no se podrá regresar al panel administrativo mediante Atrás, Inicio ni cerrando la aplicación.",
                    color = Color(0xFFE8EEF7),
                    style = MaterialTheme.typography.bodyLarge,
                )

                Text(
                    "Para salir será necesario iniciar sesión nuevamente con un usuario que tenga el permiso «Administrar terminal facial».",
                    color = Color(0xFFE8EEF7),
                    style = MaterialTheme.typography.bodyLarge,
                )

                Button(
                    onClick = {
                        val currentActivity = activity

                        if (currentActivity == null) {
                            message = "No fue posible acceder a la actividad Android."
                            return@Button
                        }

                        val controller = KioskController(currentActivity)

                        when {
                            !controller.enter() -> {
                                controller.exit()
                                enabled = false
                                message =
                                    "Este dispositivo todavía no está preparado como Device Owner."
                            }

                            !KioskModeManager.activate() -> {
                                controller.exit()
                                enabled = false
                                message =
                                    "No fue posible guardar la activación del terminal."
                            }

                            else -> {
                                enabled = true
                                message = "Terminal facial activado."
                                onActivated()
                            }
                        }
                    },
                    enabled = !enabled && deviceOwner,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        if (enabled) {
                            "Terminal facial activo"
                        } else {
                            "Activar terminal facial"
                        }
                    )
                }
            }
        }

        OutlinedButton(
            onClick = onFaceAuthSettings,
            enabled = !enabled,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Configuración facial avanzada")
        }

        DeviceStatusCard(
            enabled = manager.configuration().enabled,
        )

        if (!deviceOwner) {
            Text(
                text = "Puedes administrar esta función desde este dispositivo, pero para activarlo como terminal bloqueado primero debe prepararse como Device Owner.",
                color = Color(0xFFFFC857),
                style = MaterialTheme.typography.bodyMedium,
            )
        }

        if (message.isNotBlank()) {
            Text(
                text = message,
                color = MaterialTheme.colorScheme.primary,
            )
        }

        Spacer(Modifier.height(4.dp))

        TextButton(
            onClick = onBack,
            enabled = !enabled,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Volver")
        }
    }
}

@Composable
private fun DeviceStatusCard(enabled: Boolean) {
    val context = LocalContext.current
    val deviceOwner = remember(context) {
        DeviceOwnerHelper(context).isDeviceOwner()
    }

    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(
                "Estado del dispositivo",
                style = MaterialTheme.typography.titleMedium,
                color = Color.White,
            )

            Text(
                "Terminal facial: ${if (enabled) "ACTIVO" else "INACTIVO"}",
                color = Color(0xFFE8EEF7),
            )

            Text(
                "Device Owner: ${if (deviceOwner) "PREPARADO" else "NO ASIGNADO"}",
                color = if (deviceOwner) {
                    Color(0xFF2DD4A3)
                } else {
                    Color(0xFFFFC857)
                },
            )
        }
    }
}