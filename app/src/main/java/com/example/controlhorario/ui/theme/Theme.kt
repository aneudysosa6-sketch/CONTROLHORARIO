package com.example.controlhorario.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val OSINETDarkColorScheme = darkColorScheme(
    primary = Color(0xFF4CAF50),
    onPrimary = Color.White,
    secondary = Color(0xFF7DDC91),
    onSecondary = Color(0xFF101010),
    background = Color(0xFF101010),
    onBackground = Color(0xFFF4F4F4),
    surface = Color(0xFF1A1A1A),
    onSurface = Color(0xFFF4F4F4),
    surfaceVariant = Color(0xFF222222),
    onSurfaceVariant = Color(0xFFCFCFCF),
    outline = Color(0xFF3A3A3A),
    error = Color(0xFFE53935),
    onError = Color.White
)

@Composable
fun CONTROLHORARIOTheme(
    darkTheme: Boolean = true,
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = OSINETDarkColorScheme,
        typography = Typography,
        content = content
    )
}
