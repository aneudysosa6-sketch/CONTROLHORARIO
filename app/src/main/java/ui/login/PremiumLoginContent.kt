package com.example.controlhorario.ui.login

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETLogo
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun PremiumLoginContent(
    username: String,
    password: String,
    error: String,
    loading: Boolean,
    onUsernameChange: (String) -> Unit,
    onPasswordChange: (String) -> Unit,
    onLogin: () -> Unit
) {
    var visible by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { visible = true }
    val contentAlpha by animateFloatAsState(if (visible) 1f else 0f, tween(700), label = "login_fade")
    Box(
        modifier = Modifier
            .fillMaxSize()
            .graphicsLayer { alpha = contentAlpha; translationY = (1f - contentAlpha) * 28f }
            .background(
                Brush.radialGradient(
                    colors = listOf(Color(0xFF0B3764), OSINETColors.Background),
                    center = Offset(240f, 180f),
                    radius = 1100f
                )
            )
            .padding(horizontal = 22.dp, vertical = 28.dp),
        contentAlignment = Alignment.Center
    ) {
        NeonLoginOrbits(Modifier.size(430.dp))
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 480.dp)
                .shadow(30.dp, RoundedCornerShape(28.dp), ambientColor = Color(0xFF1689FF), spotColor = Color(0xFF1689FF)),
            shape = RoundedCornerShape(28.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xF20A192B)),
            elevation = CardDefaults.cardElevation(defaultElevation = 12.dp)
        ) {
            Column(
                modifier = Modifier.padding(horizontal = 24.dp, vertical = 30.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                OSINETLogo(subtitle = "CONTROLHORARIO")
                Spacer(Modifier.height(24.dp))
                Text("Bienvenido", color = OSINETColors.TextPrimary, style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
                Text("Acceso seguro al panel administrativo", color = OSINETColors.TextSecondary, textAlign = TextAlign.Center)
                Spacer(Modifier.height(24.dp))
                OSINETTextField(
                    value = username,
                    onValueChange = onUsernameChange,
                    label = "Usuario / Correo",
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(13.dp))
                OSINETTextField(
                    value = password,
                    onValueChange = onPasswordChange,
                    label = "Contraseña",
                    modifier = Modifier.fillMaxWidth(),
                    visualTransformation = PasswordVisualTransformation()
                )
                if (error.isNotBlank()) {
                    Spacer(Modifier.height(14.dp))
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .background(OSINETColors.Danger.copy(alpha = .14f), RoundedCornerShape(12.dp))
                            .padding(13.dp)
                    ) { Text(error, color = Color(0xFFFFA4AF), style = MaterialTheme.typography.bodySmall) }
                }
                Spacer(Modifier.height(20.dp))
                OSINETButton(
                    text = if (loading) "Validando acceso…" else "Iniciar sesión",
                    enabled = !loading && username.isNotBlank() && password.isNotBlank(),
                    onClick = onLogin
                )
                if (loading) {
                    Spacer(Modifier.height(14.dp))
                    CircularProgressIndicator(modifier = Modifier.size(24.dp), color = OSINETColors.GreenSoft, strokeWidth = 2.dp)
                }
                Spacer(Modifier.height(16.dp))
                Text("SESIÓN PROTEGIDA · OSINET", color = OSINETColors.GreenSoft.copy(alpha = .72f), style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

@Composable
private fun NeonLoginOrbits(modifier: Modifier = Modifier) {
    val transition = rememberInfiniteTransition(label = "login_orbits")
    val blue = transition.animateFloat(0f, 360f, infiniteRepeatable(tween(13000, easing = LinearEasing)), label = "blue")
    val green = transition.animateFloat(360f, 0f, infiniteRepeatable(tween(17000, easing = LinearEasing)), label = "green")
    val amber = transition.animateFloat(0f, 360f, infiniteRepeatable(tween(21000, easing = LinearEasing), RepeatMode.Restart), label = "amber")
    Canvas(modifier) {
        fun orbit(rotation: Float, inset: Float, color: Color, start: Float, sweep: Float) {
            rotate(rotation) {
                val bounds = Size(size.width - inset * 2, size.height - inset * 2)
                drawArc(color.copy(alpha = .16f), start, sweep, false, Offset(inset, inset), bounds, style = Stroke(12f, cap = StrokeCap.Round))
                drawArc(color, start, sweep, false, Offset(inset, inset), bounds, style = Stroke(4f, cap = StrokeCap.Round))
            }
        }
        orbit(blue.value, 8f, Color(0xFF2AA8FF), -35f, 215f)
        orbit(green.value, 28f, Color(0xFF2DDEA5), 45f, 190f)
        orbit(amber.value, 48f, Color(0xFFFFC343), 150f, 165f)
    }
}
