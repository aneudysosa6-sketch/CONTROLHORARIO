package com.example.controlhorario.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

object OSINETColors {
    val Background = Color(0xFF06111F)
    val Surface = Color(0xFF091A2E)
    val SurfaceAlt = Color(0xFF0D233A)
    val Green = Color(0xFF128CFF)
    val GreenSoft = Color(0xFF55B8FF)
    val TextPrimary = Color(0xFFF4F4F4)
    val TextSecondary = Color(0xFFCFCFCF)
    val Border = Color(0xFF17476F)
    val Warning = Color(0xFFFFC107)
    val Danger = Color(0xFFE53935)
    val Info = Color(0xFF00A3FF)
}

@Composable
fun OSINETScreen(
    modifier: Modifier = Modifier,
    scroll: Boolean = true,
    content: @Composable ColumnScope.() -> Unit
) {
    Scaffold(containerColor = OSINETColors.Background) { paddingValues ->
        val base = modifier
            .fillMaxSize()
            .background(OSINETColors.Background)
            .padding(paddingValues)
            .padding(horizontal = 24.dp, vertical = 22.dp)
        Column(
            modifier = if (scroll) base.verticalScroll(rememberScrollState()) else base,
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Top,
            content = content
        )
    }
}

@Composable
fun OSINETHeader(
    title: String,
    subtitle: String? = null,
    icon: ImageVector? = null
) {
    if (icon != null) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = OSINETColors.Green,
            modifier = Modifier.size(46.dp)
        )
        Spacer(Modifier.height(10.dp))
    }
    Text(
        text = title,
        color = OSINETColors.TextPrimary,
        style = MaterialTheme.typography.headlineMedium,
        fontWeight = FontWeight.SemiBold,
        textAlign = TextAlign.Center,
        modifier = Modifier.fillMaxWidth()
    )
    if (!subtitle.isNullOrBlank()) {
        Spacer(Modifier.height(6.dp))
        Text(
            text = subtitle,
            color = OSINETColors.TextSecondary,
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
fun OSINETCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = OSINETColors.Surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 3.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            content = content
        )
    }
}

@Composable
fun OSINETActionCard(
    title: String,
    subtitle: String? = null,
    icon: ImageVector? = null,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Card(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = OSINETColors.Surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 4.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (icon != null) {
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .background(OSINETColors.Green.copy(alpha = 0.16f), CircleShape),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(icon, contentDescription = null, tint = OSINETColors.Green, modifier = Modifier.size(28.dp))
                }
                Spacer(Modifier.width(14.dp))
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(title, color = OSINETColors.TextPrimary, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                if (!subtitle.isNullOrBlank()) Text(subtitle, color = OSINETColors.TextSecondary, style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable
fun OSINETSecondaryButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier
            .fillMaxWidth()
            .height(56.dp),
        shape = RoundedCornerShape(16.dp),
        border = BorderStroke(1.dp, OSINETColors.Border),
        colors = ButtonDefaults.outlinedButtonColors(
            contentColor = OSINETColors.TextPrimary,
            containerColor = Color.Transparent
        )
    ) { Text(text = text, color = OSINETColors.TextPrimary) }
}


@Composable
fun OSINETLogo(
    modifier: Modifier = Modifier,
    subtitle: String = "SISTEMA EMPRESARIAL"
) {
    Column(modifier = modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(68.dp)
                .border(3.dp, OSINETColors.Green, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Box(
                modifier = Modifier
                    .size(42.dp)
                    .border(2.dp, OSINETColors.GreenSoft, CircleShape)
            )
        }
        Spacer(Modifier.height(10.dp))
        Text(
            text = "OSINET ERP",
            color = OSINETColors.TextPrimary,
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.ExtraBold,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
        Text(
            text = subtitle,
            color = OSINETColors.GreenSoft,
            style = MaterialTheme.typography.labelLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth()
        )
    }
}

@Composable
fun OSINETNeonEventCard(
    title: String,
    subtitle: String,
    isNew: Boolean,
    onOpen: () -> Unit,
    modifier: Modifier = Modifier
) {
    val transition = rememberInfiniteTransition(label = "osinet_neon_border")
    val alpha = transition.animateFloat(
        initialValue = 0.38f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 850),
            repeatMode = RepeatMode.Reverse
        ),
        label = "neon_alpha"
    )
    val borderColor = if (isNew) OSINETColors.Green.copy(alpha = alpha.value) else OSINETColors.Border
    Card(
        onClick = onOpen,
        modifier = modifier
            .fillMaxWidth()
            .then(
                if (isNew) Modifier
                    .shadow(16.dp, RoundedCornerShape(18.dp), ambientColor = OSINETColors.Green, spotColor = OSINETColors.Green)
                    .border(1.8.dp, borderColor, RoundedCornerShape(18.dp))
                else Modifier.border(1.dp, borderColor, RoundedCornerShape(18.dp))
            ),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = OSINETColors.Surface),
        elevation = CardDefaults.cardElevation(defaultElevation = if (isNew) 8.dp else 2.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, color = OSINETColors.TextPrimary, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(subtitle, color = OSINETColors.TextSecondary, style = MaterialTheme.typography.bodyMedium)
            if (isNew) Text("Nuevo evento", color = OSINETColors.GreenSoft, style = MaterialTheme.typography.labelMedium)
        }
    }
}

@Composable
fun OSINETStatusText(text: String, color: Color = OSINETColors.TextSecondary) {
    if (text.isNotBlank()) {
        Text(
            text = text,
            color = color,
            style = MaterialTheme.typography.bodyMedium,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center
        )
    }
}
