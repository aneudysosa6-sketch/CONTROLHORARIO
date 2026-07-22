package com.example.controlhorario.ui.face

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun InitialFaceEnrollmentScreen(
    code: String,
    busy: Boolean,
    message: String,
    onCodeChange: (String) -> Unit,
    onContinue: () -> Unit,
    onCancel: () -> Unit,
) {
    val canContinue = code.length == REQUIRED_CODE_LENGTH && code.all { it in '0'..'9' } &&
        code != "000000" && !busy

    OSINETScreen {
        OSINETHeader(
            title = "Registro inicial de rostro",
            subtitle = "Ingrese su código de empleado para continuar",
        )
        Spacer(Modifier.height(18.dp))

        OSINETCard {
            OSINETTextField(
                value = code,
                onValueChange = { value ->
                    if (!busy) {
                        onCodeChange(value.filter { it in '0'..'9' }.take(REQUIRED_CODE_LENGTH))
                    }
                },
                label = "Código de empleado (6 dígitos)",
                modifier = Modifier
                    .fillMaxWidth()
                    .semantics { contentDescription = "Código de empleado de 6 dígitos" },
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Number,
                    imeAction = ImeAction.Done,
                ),
            )
            Text(
                text = "${code.length.coerceAtMost(REQUIRED_CODE_LENGTH)} de $REQUIRED_CODE_LENGTH dígitos",
                color = OSINETColors.TextSecondary,
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.End,
                modifier = Modifier.fillMaxWidth(),
            )

            if (busy) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .semantics {
                            liveRegion = LiveRegionMode.Polite
                            contentDescription = "Procesando registro inicial de rostro"
                        },
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(22.dp),
                        color = OSINETColors.GreenSoft,
                        strokeWidth = 2.dp,
                    )
                    Text(
                        text = "  Procesando…",
                        color = OSINETColors.TextSecondary,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }

            if (message.isNotBlank()) {
                Text(
                    text = message,
                    color = OSINETColors.TextSecondary,
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .fillMaxWidth()
                        .semantics {
                            liveRegion = LiveRegionMode.Polite
                            contentDescription = message
                        },
                )
            }

            OSINETButton(
                text = if (busy) "PROCESANDO…" else "CONTINUAR",
                onClick = onContinue,
                enabled = canContinue,
            )
            OSINETSecondaryButton(
                text = "Cancelar",
                onClick = onCancel,
            )
        }
    }
}

private const val REQUIRED_CODE_LENGTH = 6
