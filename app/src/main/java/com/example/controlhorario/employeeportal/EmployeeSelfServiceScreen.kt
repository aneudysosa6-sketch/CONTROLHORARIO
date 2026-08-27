package com.example.controlhorario.employeeportal

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.shadow
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.controlhorario.auth.AuthenticatedPrincipal
import com.example.controlhorario.ui.components.ControlHorarioBrandMark
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.text.NumberFormat
import java.util.Locale
import java.util.UUID

private object EmployeePortalColors {
    val Background = Color(0xFF020A15)
    val BackgroundGlow = Color(0xFF063667)
    val Surface = Color(0xFF06172A)
    val SurfaceRaised = Color(0xFF0A2038)
    val Border = Color(0xFF15456F)
    val BorderBright = Color(0xFF087CFF)
    val Blue = Color(0xFF087CFF)
    val Cyan = Color(0xFF16C8FF)
    val Text = Color(0xFFF3F7FC)
    val Muted = Color(0xFFA5B2C6)
    val Green = Color(0xFF12E979)
    val GreenSurface = Color(0xFF063B2A)
    val Amber = Color(0xFFFFC24B)
    val Danger = Color(0xFFFF6378)
}

private enum class PortalSection(val label: String, val icon: PortalIcon) {
    PROFILE("PERFIL", PortalIcon.PROFILE),
    EARNINGS("GANANCIAS HOY", PortalIcon.CHART),
    LOANS("PRESTAMO", PortalIcon.WALLET),
    REQUEST("SOLICITUD DE PRESTAMO", PortalIcon.DOCUMENT)
}

private enum class PortalIcon {
    PROFILE,
    CHART,
    WALLET,
    DOCUMENT,
    LOGOUT,
    ID,
    EMAIL,
    PHONE,
    BUILDING,
    WORK,
    SHIELD,
    CALENDAR,
    MONEY,
    CLOCK,
    NOTE
}

private data class PortalField(
    val label: String,
    val value: String,
    val icon: PortalIcon,
    val status: Boolean = false
)

@Composable
fun EmployeeSelfServiceScreen(
    principal: AuthenticatedPrincipal,
    onLogout: () -> Unit
) {
    val api = remember(principal.authUid) { EmployeePortalApi(principal) }
    val scope = rememberCoroutineScope()
    var payload by remember { mutableStateOf<EmployeePortalPayload?>(null) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var selectedSectionName by rememberSaveable { mutableStateOf(PortalSection.PROFILE.name) }
    var amount by rememberSaveable { mutableStateOf("") }
    var discount by rememberSaveable { mutableStateOf("") }
    var reason by rememberSaveable { mutableStateOf("") }
    var idempotency by rememberSaveable { mutableStateOf(UUID.randomUUID().toString()) }
    val selectedSection = PortalSection.entries.firstOrNull { it.name == selectedSectionName }
        ?: PortalSection.PROFILE

    fun load() {
        scope.launch {
            loading = true
            error = ""
            runCatching { api.load() }
                .onSuccess { payload = it }
                .onFailure { error = it.message ?: "No fue posible cargar el portal." }
            loading = false
        }
    }

    fun submitLoanRequest() {
        val total = amount.toDoubleOrNull()
        val quota = discount.toDoubleOrNull()
        if (total == null || quota == null || total <= 0 || quota <= 0 || quota > total || reason.trim().length < 3) {
            error = "Revisa el monto, la cuota y el motivo."
            return
        }
        scope.launch {
            loading = true
            error = ""
            message = ""
            runCatching { api.requestLoan(total, quota, reason.trim(), idempotency) }
                .onSuccess {
                    idempotency = UUID.randomUUID().toString()
                    amount = ""
                    discount = ""
                    reason = ""
                    message = "Solicitud enviada para revision."
                    payload = api.load()
                }
                .onFailure { error = it.message ?: "No fue posible enviar la solicitud." }
            loading = false
        }
    }

    LaunchedEffect(principal.authUid) { load() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.radialGradient(
                    colors = listOf(EmployeePortalColors.BackgroundGlow, EmployeePortalColors.Background),
                    center = Offset(160f, 80f),
                    radius = 1050f
                )
            )
    ) {
        Column(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .widthIn(max = 920.dp)
                .verticalScroll(rememberScrollState())
                .windowInsetsPadding(WindowInsets.safeDrawing)
                .padding(horizontal = 18.dp, vertical = 20.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            EmployeePortalHeader(onLogout)
            Spacer(Modifier.height(4.dp))
            PortalNavigation(
                selected = selectedSection,
                onSelect = {
                    selectedSectionName = it.name
                    error = ""
                    message = ""
                }
            )

            if (error.isNotBlank()) {
                PortalNotice(error, EmployeePortalColors.Danger, "No fue posible completar la operacion")
            }
            if (message.isNotBlank()) {
                PortalNotice(message, EmployeePortalColors.Green, "Operacion completada")
            }

            when {
                loading -> PortalLoading()
                payload == null -> PortalEmpty(
                    title = "No fue posible cargar tu informacion",
                    detail = "Revisa tu conexion e intentalo nuevamente.",
                    actionLabel = "REINTENTAR",
                    onAction = ::load
                )
                else -> {
                    val data = requireNotNull(payload)
                    when (selectedSection) {
                        PortalSection.PROFILE -> ProfileContent(data.profile)
                        PortalSection.EARNINGS -> EarningsContent(data.earnings)
                        PortalSection.LOANS -> LoanListContent(data.json.optJSONArray("prestamos") ?: JSONArray())
                        PortalSection.REQUEST -> LoanRequestContent(
                            amount = amount,
                            discount = discount,
                            reason = reason,
                            requests = data.json.optJSONArray("solicitudes") ?: JSONArray(),
                            onAmountChange = { amount = decimalInput(it) },
                            onDiscountChange = { discount = decimalInput(it) },
                            onReasonChange = { reason = it },
                            onSubmit = ::submitLoanRequest
                        )
                    }
                }
            }
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun EmployeePortalHeader(onLogout: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            modifier = Modifier.weight(1f),
            verticalAlignment = Alignment.CenterVertically
        ) {
            ControlHorarioBrandMark(Modifier.size(66.dp))
            Spacer(Modifier.width(12.dp))
            Text(
                text = "Portal privado\ndel empleado",
                color = EmployeePortalColors.Text,
                fontSize = 17.sp,
                lineHeight = 21.sp,
                fontWeight = FontWeight.Medium
            )
        }
        OutlinedButton(
            onClick = onLogout,
            shape = RoundedCornerShape(15.dp),
            border = BorderStroke(1.dp, EmployeePortalColors.Border),
            colors = ButtonDefaults.outlinedButtonColors(
                containerColor = EmployeePortalColors.Surface.copy(alpha = 0.72f),
                contentColor = EmployeePortalColors.Cyan
            ),
            contentPadding = PaddingValues(horizontal = 13.dp, vertical = 12.dp)
        ) {
            PortalLineIcon(PortalIcon.LOGOUT, Modifier.size(22.dp))
            Spacer(Modifier.width(7.dp))
            Text("Cerrar sesion", fontSize = 12.sp, maxLines = 1)
        }
    }
}

@Composable
private fun PortalNavigation(
    selected: PortalSection,
    onSelect: (PortalSection) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(9.dp)) {
        PortalSection.entries.forEach { section ->
            val active = selected == section
            val shape = RoundedCornerShape(20.dp)
            val background = if (active) {
                Brush.horizontalGradient(
                    listOf(Color(0xFF083D96), Color(0xFF0665E8), Color(0xFF07336C))
                )
            } else {
                Brush.horizontalGradient(
                    listOf(Color(0xFF07192C), Color(0xFF061426))
                )
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 72.dp)
                    .clip(shape)
                    .background(background)
                    .border(
                        width = if (active) 1.4.dp else 1.dp,
                        color = if (active) EmployeePortalColors.BorderBright else EmployeePortalColors.Border,
                        shape = shape
                    )
                    .clickable { onSelect(section) }
                    .padding(horizontal = 20.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier.width(62.dp),
                    contentAlignment = Alignment.Center
                ) {
                    if (section == PortalSection.PROFILE) {
                        ControlHorarioBrandMark(Modifier.size(48.dp))
                    } else {
                        PortalLineIcon(section.icon, Modifier.size(34.dp))
                    }
                }
                Box(
                    modifier = Modifier
                        .padding(horizontal = 17.dp)
                        .width(1.dp)
                        .height(42.dp)
                        .background(if (active) Color.White.copy(alpha = 0.24f) else EmployeePortalColors.Border)
                )
                Text(
                    text = section.label,
                    color = EmployeePortalColors.Text,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 0.25.sp
                )
            }
        }
    }
}

@Composable
private fun ProfileContent(profile: JSONObject) {
    val fields = listOf(
        PortalField("Nombre", profile.optString("nombre"), PortalIcon.PROFILE),
        PortalField("Codigo", profile.optString("codigo"), PortalIcon.ID),
        PortalField("Correo", profile.optString("correo"), PortalIcon.EMAIL),
        PortalField("Telefono", profile.optString("telefono"), PortalIcon.PHONE),
        PortalField("Sucursal", profile.optString("sucursal"), PortalIcon.BUILDING),
        PortalField("Departamento", profile.optString("departamento"), PortalIcon.WORK),
        PortalField("Puesto", profile.optString("puesto"), PortalIcon.PROFILE),
        PortalField("Estado", profile.optString("estado"), PortalIcon.SHIELD, status = true)
    )
    PortalPanel {
        PortalPanelHeading(
            title = "Mi perfil",
            subtitle = "Informacion laboral y de contacto",
            icon = PortalIcon.PROFILE,
            branded = true
        )
        fields.forEachIndexed { index, field ->
            ProfileFieldRow(field)
            if (index != fields.lastIndex) {
                HorizontalDivider(
                    modifier = Modifier.padding(start = 58.dp),
                    color = EmployeePortalColors.Border.copy(alpha = 0.68f)
                )
            }
        }
    }
}

@Composable
private fun EarningsContent(earnings: JSONObject) {
    val total = earnings.optDouble("total")
    PortalPanel {
        PortalPanelHeading(
            title = "Ganancias hoy",
            subtitle = "Acumulado disponible hasta el ultimo corte",
            icon = PortalIcon.CHART
        )
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(
                    Brush.horizontalGradient(
                        listOf(Color(0xFF063C79), Color(0xFF087CFF), Color(0xFF07509B))
                    )
                )
                .padding(20.dp)
        ) {
            Column {
                Text("TOTAL ACUMULADO", color = Color(0xFFBDE5FF), fontSize = 11.sp, letterSpacing = 1.2.sp)
                Text(
                    currency(total),
                    color = Color.White,
                    fontSize = 30.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
        Spacer(Modifier.height(4.dp))
        listOf(
            PortalField(
                "Periodo",
                "${displayValue(earnings.optString("periodo_inicio"))} - ${displayValue(earnings.optString("periodo_fin"))}",
                PortalIcon.CALENDAR
            ),
            PortalField("Corte", earnings.optString("corte"), PortalIcon.CLOCK),
            PortalField("Pago normal", currency(earnings.optDouble("pago_normal")), PortalIcon.MONEY),
            PortalField("Horas extra", currency(earnings.optDouble("pago_extra")), PortalIcon.CLOCK),
            PortalField("Incentivo", currency(earnings.optDouble("incentivo")), PortalIcon.CHART)
        ).forEachIndexed { index, field ->
            ProfileFieldRow(field)
            if (index != 4) {
                HorizontalDivider(
                    modifier = Modifier.padding(start = 58.dp),
                    color = EmployeePortalColors.Border.copy(alpha = 0.68f)
                )
            }
        }
    }
}

@Composable
private fun LoanListContent(loans: JSONArray) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        PortalSectionTitle("Mis prestamos", "Consulta balances y descuentos aplicados")
        if (loans.length() == 0) {
            PortalEmpty(
                title = "No tienes prestamos registrados",
                detail = "Cuando exista un prestamo aprobado aparecera en esta seccion."
            )
        } else {
            repeat(loans.length()) { index ->
                loans.optJSONObject(index)?.let { loan ->
                    LoanCard(loan, index + 1)
                }
            }
        }
    }
}

@Composable
private fun LoanCard(loan: JSONObject, number: Int) {
    PortalPanel {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text("PRESTAMO ${number.toString().padStart(2, '0')}", color = EmployeePortalColors.Cyan, fontSize = 10.sp, letterSpacing = 1.2.sp)
                Text(currency(loan.optDouble("monto_total")), color = EmployeePortalColors.Text, fontSize = 24.sp, fontWeight = FontWeight.Bold)
            }
            StatusBadge(loan.optString("estado"))
        }
        Spacer(Modifier.height(3.dp))
        listOf(
            PortalField("Pendiente", currency(loan.optDouble("pendiente")), PortalIcon.WALLET),
            PortalField("Cuota", currency(loan.optDouble("descuento_periodo")), PortalIcon.MONEY),
            PortalField("Motivo", loan.optString("motivo"), PortalIcon.NOTE),
            PortalField(
                "Descuentos",
                (loan.optJSONArray("movimientos")?.length() ?: 0).toString(),
                PortalIcon.CHART
            )
        ).forEachIndexed { index, field ->
            ProfileFieldRow(field)
            if (index != 3) {
                HorizontalDivider(
                    modifier = Modifier.padding(start = 58.dp),
                    color = EmployeePortalColors.Border.copy(alpha = 0.68f)
                )
            }
        }
    }
}

@Composable
private fun LoanRequestContent(
    amount: String,
    discount: String,
    reason: String,
    requests: JSONArray,
    onAmountChange: (String) -> Unit,
    onDiscountChange: (String) -> Unit,
    onReasonChange: (String) -> Unit,
    onSubmit: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        PortalPanel {
            PortalPanelHeading(
                title = "Solicitar prestamo",
                subtitle = "Completa los datos para enviar la solicitud a revision",
                icon = PortalIcon.DOCUMENT
            )
            PortalTextField(
                value = amount,
                onValueChange = onAmountChange,
                label = "Monto solicitado",
                keyboardType = KeyboardType.Decimal,
                singleLine = true
            )
            PortalTextField(
                value = discount,
                onValueChange = onDiscountChange,
                label = "Descuento por periodo",
                keyboardType = KeyboardType.Decimal,
                singleLine = true
            )
            PortalTextField(
                value = reason,
                onValueChange = onReasonChange,
                label = "Motivo",
                minLines = 3
            )
            Button(
                onClick = onSubmit,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = EmployeePortalColors.Blue,
                    contentColor = Color.White
                )
            ) {
                PortalLineIcon(PortalIcon.DOCUMENT, Modifier.size(21.dp), Color.White)
                Spacer(Modifier.width(9.dp))
                Text("ENVIAR SOLICITUD", fontWeight = FontWeight.Bold, letterSpacing = 0.5.sp)
            }
        }

        PortalSectionTitle("Mis solicitudes", "Seguimiento de solicitudes enviadas")
        if (requests.length() == 0) {
            PortalEmpty(
                title = "No hay solicitudes",
                detail = "Las solicitudes enviadas apareceran aqui."
            )
        } else {
            repeat(requests.length()) { index ->
                requests.optJSONObject(index)?.let { request ->
                    RequestCard(request, index + 1)
                }
            }
        }
    }
}

@Composable
private fun RequestCard(request: JSONObject, number: Int) {
    PortalPanel {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "SOLICITUD ${number.toString().padStart(2, '0')}",
                color = EmployeePortalColors.Cyan,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                letterSpacing = 1.sp
            )
            StatusBadge(request.optString("estado"))
        }
        listOf(
            PortalField("Monto", currency(request.optDouble("monto_solicitado")), PortalIcon.MONEY),
            PortalField("Cuota", currency(request.optDouble("descuento_periodo")), PortalIcon.CLOCK),
            PortalField("Motivo", request.optString("motivo"), PortalIcon.NOTE)
        ).forEachIndexed { index, field ->
            ProfileFieldRow(field)
            if (index != 2) {
                HorizontalDivider(
                    modifier = Modifier.padding(start = 58.dp),
                    color = EmployeePortalColors.Border.copy(alpha = 0.68f)
                )
            }
        }
    }
}

@Composable
private fun PortalPanel(content: @Composable ColumnScope.() -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(
                elevation = 20.dp,
                shape = RoundedCornerShape(24.dp),
                ambientColor = EmployeePortalColors.Blue.copy(alpha = 0.15f),
                spotColor = EmployeePortalColors.Blue.copy(alpha = 0.22f)
            ),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = EmployeePortalColors.Surface.copy(alpha = 0.96f)),
        border = BorderStroke(1.dp, EmployeePortalColors.Border)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content
        )
    }
}

@Composable
private fun PortalPanelHeading(
    title: String,
    subtitle: String,
    icon: PortalIcon,
    branded: Boolean = false
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        if (branded) {
            Box(
                modifier = Modifier
                    .size(76.dp)
                    .border(1.4.dp, EmployeePortalColors.BorderBright, RoundedCornerShape(38.dp))
                    .padding(5.dp),
                contentAlignment = Alignment.Center
            ) {
                ControlHorarioBrandMark(Modifier.fillMaxSize())
            }
        } else {
            PortalIconFrame(icon, Modifier.size(52.dp))
        }
        Spacer(Modifier.width(16.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                title,
                color = EmployeePortalColors.Text,
                fontSize = 23.sp,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(5.dp))
            Box(
                modifier = Modifier
                    .width(48.dp)
                    .height(2.dp)
                    .background(EmployeePortalColors.Blue, RoundedCornerShape(1.dp))
            )
            Spacer(Modifier.height(6.dp))
            Text(subtitle, color = EmployeePortalColors.Muted, fontSize = 11.sp)
        }
    }
    HorizontalDivider(color = EmployeePortalColors.Border.copy(alpha = 0.5f))
}

@Composable
private fun ProfileFieldRow(field: PortalField) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        PortalIconFrame(field.icon, Modifier.size(42.dp))
        Spacer(Modifier.width(13.dp))
        Text(
            text = "${field.label}:",
            color = EmployeePortalColors.Muted,
            fontSize = 13.sp,
            modifier = Modifier.weight(0.42f)
        )
        if (field.status) {
            Box(modifier = Modifier.weight(0.58f)) {
                StatusBadge(field.value)
            }
        } else {
            Text(
                text = displayValue(field.value),
                color = EmployeePortalColors.Text,
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(0.58f),
                overflow = TextOverflow.Ellipsis,
                maxLines = 2
            )
        }
    }
}

@Composable
private fun PortalIconFrame(
    icon: PortalIcon,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(13.dp))
            .background(EmployeePortalColors.SurfaceRaised)
            .border(1.dp, EmployeePortalColors.Border, RoundedCornerShape(13.dp)),
        contentAlignment = Alignment.Center
    ) {
        PortalLineIcon(icon, Modifier.fillMaxSize().padding(9.dp))
    }
}

@Composable
private fun StatusBadge(value: String) {
    val normalized = value.trim().uppercase(Locale.ROOT)
    val active = normalized in setOf("ACTIVO", "ACTIVE", "APROBADO", "APPROVED", "PAGADO", "PAID")
    val rejected = normalized in setOf("RECHAZADO", "REJECTED", "INACTIVO", "INACTIVE", "CANCELADO", "CANCELLED")
    val color = when {
        active -> EmployeePortalColors.Green
        rejected -> EmployeePortalColors.Danger
        else -> EmployeePortalColors.Amber
    }
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(color.copy(alpha = 0.12f))
            .border(1.dp, color.copy(alpha = 0.5f), RoundedCornerShape(12.dp))
            .padding(horizontal = 11.dp, vertical = 7.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(color, RoundedCornerShape(4.dp))
            )
            Spacer(Modifier.width(7.dp))
            Text(
                displayValue(value).uppercase(Locale.ROOT),
                color = color,
                fontSize = 11.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
        }
    }
}

@Composable
private fun PortalSectionTitle(title: String, subtitle: String) {
    Column(modifier = Modifier.padding(horizontal = 3.dp, vertical = 4.dp)) {
        Text(title, color = EmployeePortalColors.Text, fontSize = 23.sp, fontWeight = FontWeight.Bold)
        Text(subtitle, color = EmployeePortalColors.Muted, fontSize = 12.sp)
    }
}

@Composable
private fun PortalNotice(message: String, color: Color, title: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = color.copy(alpha = 0.1f)),
        border = BorderStroke(1.dp, color.copy(alpha = 0.45f))
    ) {
        Column(Modifier.padding(15.dp)) {
            Text(title, color = color, fontWeight = FontWeight.Bold, fontSize = 12.sp)
            Text(message, color = EmployeePortalColors.Text, fontSize = 12.sp)
        }
    }
}

@Composable
private fun PortalLoading() {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .height(210.dp),
        shape = RoundedCornerShape(24.dp),
        colors = CardDefaults.cardColors(containerColor = EmployeePortalColors.Surface),
        border = BorderStroke(1.dp, EmployeePortalColors.Border)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            CircularProgressIndicator(color = EmployeePortalColors.Cyan, strokeWidth = 3.dp)
            Spacer(Modifier.height(15.dp))
            Text("Cargando tu portal...", color = EmployeePortalColors.Muted)
        }
    }
}

@Composable
private fun PortalEmpty(
    title: String,
    detail: String,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(22.dp),
        colors = CardDefaults.cardColors(containerColor = EmployeePortalColors.Surface),
        border = BorderStroke(1.dp, EmployeePortalColors.Border)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(30.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            PortalIconFrame(PortalIcon.DOCUMENT, Modifier.size(52.dp))
            Text(title, color = EmployeePortalColors.Text, fontWeight = FontWeight.Bold)
            Text(detail, color = EmployeePortalColors.Muted, fontSize = 12.sp)
            if (actionLabel != null && onAction != null) {
                Spacer(Modifier.height(5.dp))
                OutlinedButton(
                    onClick = onAction,
                    border = BorderStroke(1.dp, EmployeePortalColors.Blue),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = EmployeePortalColors.Cyan)
                ) {
                    Text(actionLabel)
                }
            }
        }
    }
}

@Composable
private fun PortalTextField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    keyboardType: KeyboardType = KeyboardType.Text,
    singleLine: Boolean = false,
    minLines: Int = 1
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        modifier = Modifier.fillMaxWidth(),
        singleLine = singleLine,
        minLines = minLines,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        shape = RoundedCornerShape(14.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedTextColor = EmployeePortalColors.Text,
            unfocusedTextColor = EmployeePortalColors.Text,
            focusedBorderColor = EmployeePortalColors.Cyan,
            unfocusedBorderColor = EmployeePortalColors.Border,
            focusedLabelColor = EmployeePortalColors.Cyan,
            unfocusedLabelColor = EmployeePortalColors.Muted,
            cursorColor = EmployeePortalColors.Cyan,
            focusedContainerColor = EmployeePortalColors.Background.copy(alpha = 0.52f),
            unfocusedContainerColor = EmployeePortalColors.Background.copy(alpha = 0.52f)
        )
    )
}

@Composable
private fun PortalLineIcon(
    icon: PortalIcon,
    modifier: Modifier = Modifier,
    color: Color = EmployeePortalColors.Cyan
) {
    Canvas(modifier = modifier) {
        val scaleX = size.width / 24f
        val scaleY = size.height / 24f
        val stroke = 1.8f
        val style = Stroke(width = stroke, cap = StrokeCap.Round)

        withTransform({ scale(scaleX, scaleY, Offset.Zero) }) {
            when (icon) {
                PortalIcon.PROFILE -> {
                    drawCircle(color, 4f, Offset(12f, 7f), style = style)
                    drawArc(color, 205f, 130f, false, Offset(4f, 10f), Size(16f, 11f), style = style)
                }
                PortalIcon.CHART -> {
                    drawRoundRect(color, Offset(4f, 12f), Size(3f, 7f), CornerRadius(1f), style = style)
                    drawRoundRect(color, Offset(10.5f, 8f), Size(3f, 11f), CornerRadius(1f), style = style)
                    drawRoundRect(color, Offset(17f, 4f), Size(3f, 15f), CornerRadius(1f), style = style)
                    drawLine(color, Offset(3f, 21f), Offset(21f, 21f), stroke, StrokeCap.Round)
                }
                PortalIcon.WALLET -> {
                    drawRoundRect(color, Offset(3f, 6f), Size(18f, 14f), CornerRadius(2f), style = style)
                    drawLine(color, Offset(5f, 6f), Offset(17f, 3f), stroke, StrokeCap.Round)
                    drawRoundRect(color, Offset(14f, 10f), Size(8f, 6f), CornerRadius(2f), style = style)
                    drawCircle(color, 0.9f, Offset(17f, 13f))
                }
                PortalIcon.DOCUMENT, PortalIcon.NOTE -> {
                    val path = Path().apply {
                        moveTo(6f, 3f); lineTo(15f, 3f); lineTo(20f, 8f); lineTo(20f, 21f); lineTo(6f, 21f); close()
                        moveTo(15f, 3f); lineTo(15f, 8f); lineTo(20f, 8f)
                    }
                    drawPath(path, color, style = style)
                    drawLine(color, Offset(9f, 12f), Offset(17f, 12f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(9f, 16f), Offset(17f, 16f), stroke, StrokeCap.Round)
                }
                PortalIcon.LOGOUT -> {
                    drawRoundRect(color, Offset(3f, 3f), Size(9f, 18f), CornerRadius(2f), style = style)
                    drawLine(color, Offset(9f, 12f), Offset(21f, 12f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(17f, 8f), Offset(21f, 12f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(17f, 16f), Offset(21f, 12f), stroke, StrokeCap.Round)
                }
                PortalIcon.ID -> {
                    drawRoundRect(color, Offset(2f, 5f), Size(20f, 14f), CornerRadius(2f), style = style)
                    drawCircle(color, 2.2f, Offset(7f, 10f), style = style)
                    drawArc(color, 205f, 130f, false, Offset(3.8f, 11f), Size(6.4f, 5f), style = style)
                    drawLine(color, Offset(13f, 10f), Offset(19f, 10f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(13f, 14f), Offset(18f, 14f), stroke, StrokeCap.Round)
                }
                PortalIcon.EMAIL -> {
                    drawRoundRect(color, Offset(3f, 5f), Size(18f, 14f), CornerRadius(2f), style = style)
                    drawLine(color, Offset(4f, 7f), Offset(12f, 13f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(20f, 7f), Offset(12f, 13f), stroke, StrokeCap.Round)
                }
                PortalIcon.PHONE -> {
                    val path = Path().apply {
                        moveTo(7f, 3f)
                        cubicTo(5f, 3f, 3.8f, 5f, 4.3f, 7.2f)
                        cubicTo(5.8f, 13.4f, 10.6f, 18.2f, 16.8f, 19.7f)
                        cubicTo(19f, 20.2f, 21f, 19f, 21f, 17f)
                        lineTo(17f, 14f)
                        lineTo(13.8f, 16.2f)
                        cubicTo(11.5f, 15.2f, 8.8f, 12.5f, 7.8f, 10.2f)
                        lineTo(10f, 7f)
                        close()
                    }
                    drawPath(path, color, style = style)
                }
                PortalIcon.BUILDING -> {
                    drawRoundRect(color, Offset(5f, 3f), Size(14f, 18f), CornerRadius(1f), style = style)
                    listOf(8f, 12f, 16f).forEach { x ->
                        drawLine(color, Offset(x, 7f), Offset(x, 8.5f), stroke, StrokeCap.Round)
                        drawLine(color, Offset(x, 11f), Offset(x, 12.5f), stroke, StrokeCap.Round)
                    }
                    drawRoundRect(color, Offset(10f, 16f), Size(4f, 5f), CornerRadius(0.7f), style = style)
                }
                PortalIcon.WORK -> {
                    drawRoundRect(color, Offset(3f, 7f), Size(18f, 13f), CornerRadius(2f), style = style)
                    drawRoundRect(color, Offset(8f, 4f), Size(8f, 4f), CornerRadius(1f), style = style)
                    drawLine(color, Offset(3f, 12f), Offset(21f, 12f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(10f, 12f), Offset(14f, 12f), stroke + 1f, StrokeCap.Round)
                }
                PortalIcon.SHIELD -> {
                    val path = Path().apply {
                        moveTo(12f, 3f); lineTo(20f, 6f); lineTo(19f, 14f)
                        cubicTo(18.5f, 18f, 15.7f, 20.5f, 12f, 22f)
                        cubicTo(8.3f, 20.5f, 5.5f, 18f, 5f, 14f)
                        lineTo(4f, 6f); close()
                    }
                    drawPath(path, color, style = style)
                    drawLine(color, Offset(8.5f, 12f), Offset(11f, 14.5f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(11f, 14.5f), Offset(16f, 9.5f), stroke, StrokeCap.Round)
                }
                PortalIcon.CALENDAR -> {
                    drawRoundRect(color, Offset(3f, 5f), Size(18f, 16f), CornerRadius(2f), style = style)
                    drawLine(color, Offset(3f, 9f), Offset(21f, 9f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(8f, 3f), Offset(8f, 7f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(16f, 3f), Offset(16f, 7f), stroke, StrokeCap.Round)
                }
                PortalIcon.MONEY -> {
                    drawCircle(color, 9f, Offset(12f, 12f), style = style)
                    drawLine(color, Offset(12f, 6.5f), Offset(12f, 17.5f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(9f, 9f), Offset(15f, 9f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(9f, 15f), Offset(15f, 15f), stroke, StrokeCap.Round)
                }
                PortalIcon.CLOCK -> {
                    drawCircle(color, 9f, Offset(12f, 12f), style = style)
                    drawLine(color, Offset(12f, 12f), Offset(12f, 6f), stroke, StrokeCap.Round)
                    drawLine(color, Offset(12f, 12f), Offset(17f, 15f), stroke, StrokeCap.Round)
                }
            }
        }
    }
}

private fun displayValue(value: String): String = value.trim().takeIf { it.isNotBlank() } ?: "—"

private fun decimalInput(value: String): String {
    val normalized = value.replace(',', '.').filter { it.isDigit() || it == '.' }
    val firstDot = normalized.indexOf('.')
    return if (firstDot < 0) normalized else {
        normalized.substring(0, firstDot + 1) +
            normalized.substring(firstDot + 1).replace(".", "").take(2)
    }
}

private fun currency(value: Double): String =
    NumberFormat.getCurrencyInstance(Locale("es", "DO")).format(value)
