package com.example.controlhorario.ui.punch

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETScreen

/** PIN identification only. Facial verification occurs in its own destination; no USB reader is created here. */
@Composable
fun EmployeePunchScreen(
    viewModel: EmployeePunchViewModel,
    onVerified: (Int) -> Unit,
    onRegisterFace: (Int) -> Unit,
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsState()
    var navigated by remember { mutableStateOf(false) }
    var showPin by remember { mutableStateOf(false) }
    val canInput = !state.identifying && state.employee == null

    LaunchedEffect(state.employee?.id, state.hasFaceTemplate) {
        val employee = state.employee
        if (employee != null && state.hasFaceTemplate && !navigated) {
            navigated = true
            onVerified(employee.id)
        }
    }

    OSINETScreen(scroll = true) {
        BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
            val landscape = maxWidth > maxHeight
            val keySize = when {
                landscape -> 92.dp
                maxWidth < 400.dp -> 92.dp
                else -> 104.dp
            }
            val keyTextSize = if (keySize >= 92.dp) 46.sp else 38.sp
            val keyGap = if (landscape) 10.dp else 14.dp

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(if (landscape) 10.dp else 16.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                PinHeader()
                PinField(
                    pin = state.code,
                    showPin = showPin,
                    onVisibilityToggle = { showPin = !showPin }
                )
                if (state.identifying) {
                    CircularProgressIndicator(color = OSINETColors.Green)
                }
                if (state.message.isNotBlank()) {
                    Text(
                        text = state.message,
                        color = if (state.message.contains("incorrecto", ignoreCase = true)) {
                            MaterialTheme.colorScheme.error
                        } else {
                            OSINETColors.TextSecondary
                        },
                        style = MaterialTheme.typography.bodyLarge,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth()
                    )
                }

                PinKeypad(
                    keySize = keySize,
                    textSize = keyTextSize,
                    gap = keyGap,
                    enabled = canInput,
                    pinEntered = state.code.isNotEmpty(),
                    onDigit = viewModel::appendDigit,
                    onDelete = viewModel::deleteLastDigit,
                    onClear = {
                        navigated = false
                        viewModel.clear()
                    }
                )

                val employeeWithoutFace = state.employee?.takeUnless { state.hasFaceTemplate }
                if (employeeWithoutFace != null) {
                    Button(
                        onClick = { onRegisterFace(employeeWithoutFace.id) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(58.dp),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = OSINETColors.Green,
                            contentColor = Color.White
                        ),
                        shape = RoundedCornerShape(18.dp)
                    ) { Text("Registrar rostro", fontWeight = FontWeight.Bold) }
                }
                TextButton(
                    onClick = onBack,
                    modifier = Modifier.semantics { contentDescription = "Salir del modo PIN" }
                ) {
                    Text("Salir", color = OSINETColors.GreenSoft, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

@Composable
private fun PinHeader() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(
                Brush.linearGradient(
                    listOf(OSINETColors.Info, OSINETColors.Green, OSINETColors.SurfaceAlt)
                )
            )
            .padding(vertical = 20.dp, horizontal = 18.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("🔒", fontSize = 30.sp, modifier = Modifier.semantics { contentDescription = "Acceso seguro" })
            Text(
                "Identifícate",
                color = Color.White,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.ExtraBold
            )
            Text(
                "Ingresa tu código PIN",
                color = Color(0xFFEAEAEA),
                style = MaterialTheme.typography.bodyLarge
            )
        }
    }
}

@Composable
private fun PinField(pin: String, showPin: Boolean, onVisibilityToggle: () -> Unit) {
    val active = pin.isNotEmpty()
    val borderColor by androidx.compose.animation.animateColorAsState(
        targetValue = if (active) OSINETColors.Info else OSINETColors.Border,
        animationSpec = tween(220),
        label = "pin_border"
    )
    val display = when {
        pin.isEmpty() -> "Ingresa tu PIN"
        showPin -> pin
        else -> "•".repeat(pin.length)
    }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(88.dp)
            .clip(RoundedCornerShape(22.dp))
            .background(OSINETColors.SurfaceAlt.copy(alpha = .92f))
            .border(if (active) 2.dp else 1.dp, borderColor, RoundedCornerShape(22.dp))
            .padding(horizontal = 22.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = display,
            color = if (pin.isEmpty()) OSINETColors.TextSecondary else Color.White,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.weight(1f)
        )
        TextButton(
            onClick = onVisibilityToggle,
            modifier = Modifier.semantics {
                contentDescription = if (showPin) "Ocultar PIN" else "Mostrar PIN"
            }
        ) {
            Text(if (showPin) "OCULTAR" else "MOSTRAR", color = OSINETColors.GreenSoft)
        }
    }
}

@Composable
private fun PinKeypad(
    keySize: androidx.compose.ui.unit.Dp,
    textSize: androidx.compose.ui.unit.TextUnit,
    gap: androidx.compose.ui.unit.Dp,
    enabled: Boolean,
    pinEntered: Boolean,
    onDigit: (String) -> Unit,
    onDelete: () -> Unit,
    onClear: () -> Unit
) {
    val rows = listOf(listOf("1", "2", "3"), listOf("4", "5", "6"), listOf("7", "8", "9"))
    Column(verticalArrangement = Arrangement.spacedBy(gap), horizontalAlignment = Alignment.CenterHorizontally) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                row.forEach { digit ->
                    PinKey(
                        label = digit,
                        contentDescription = "Número $digit",
                        keySize = keySize,
                        textSize = textSize,
                        enabled = enabled,
                        onClick = { onDigit(digit) }
                    )
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
            PinKey(
                label = "⌫",
                contentDescription = "Borrar último dígito",
                keySize = keySize,
                textSize = (textSize.value - 8).sp,
                enabled = enabled,
                onClick = onDelete
            )
            PinKey(
                label = "0",
                contentDescription = "Número 0",
                keySize = keySize,
                textSize = textSize,
                enabled = enabled,
                onClick = { onDigit("0") }
            )
            PinKey(
                label = "✓",
                secondaryLabel = "ACEPTAR",
                contentDescription = "Aceptar PIN. La validación se ejecuta automáticamente al completar el código",
                keySize = keySize,
                textSize = (textSize.value - 14).sp,
                enabled = enabled && pinEntered,
                accent = true,
                onClick = {
                    // La validación existente se activa automáticamente al completar el PIN.
                }
            )
        }
        OutlinedButton(
            onClick = onClear,
            enabled = enabled,
            shape = RoundedCornerShape(16.dp),
            modifier = Modifier.height(42.dp)
        ) {
            Text("Limpiar código", color = OSINETColors.GreenSoft)
        }
    }
}

@Composable
private fun PinKey(
    label: String,
    contentDescription: String,
    keySize: androidx.compose.ui.unit.Dp,
    textSize: androidx.compose.ui.unit.TextUnit,
    enabled: Boolean,
    onClick: () -> Unit,
    secondaryLabel: String? = null,
    accent: Boolean = false
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) .94f else 1f,
        animationSpec = tween(100),
        label = "pin_key_scale"
    )
    val shape = CircleShape
    Box(
        modifier = Modifier
            .size(keySize)
            .graphicsLayer { scaleX = scale; scaleY = scale }
            .clip(shape)
            .background(
                if (accent) {
                    Brush.linearGradient(listOf(OSINETColors.Info, OSINETColors.Green))
                } else {
                    Brush.linearGradient(listOf(OSINETColors.SurfaceAlt, OSINETColors.Surface))
                }
            )
            .border(1.dp, OSINETColors.Border, shape)
    ) {
        Button(
            onClick = onClick,
            enabled = enabled,
            interactionSource = interaction,
            modifier = Modifier
                .fillMaxSize()
                .semantics { this.contentDescription = contentDescription },
            shape = shape,
            colors = ButtonDefaults.buttonColors(
                containerColor = Color.Transparent,
                contentColor = Color.White,
                disabledContainerColor = Color.Transparent,
                disabledContentColor = OSINETColors.TextSecondary.copy(alpha = .45f)
            ),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(label, color = Color.White, fontSize = textSize, fontWeight = FontWeight.Bold)
                if (secondaryLabel != null) {
                    Text(secondaryLabel, color = Color.White, fontSize = 10.sp, fontWeight = FontWeight.ExtraBold)
                }
            }
        }
    }
}
