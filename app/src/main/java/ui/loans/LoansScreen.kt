package com.example.controlhorario.ui.loans

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.material3.Text
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.LoanEntity
import com.example.controlhorario.engine.LoanEngine
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.EmployeeCodePolicy
import com.example.controlhorario.ui.components.OSINETActionCard
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETTextField
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@Composable
fun LoansScreen(
    viewModel: LoanViewModel,
    employees: List<Employee>,
    onBack: () -> Unit
) {
    val loans by viewModel.loans.collectAsState()
    val summary by viewModel.summary.collectAsState()

    var employeeCode by remember { mutableStateOf("") }
    var requestedAmount by remember { mutableStateOf("") }
    var payrollDiscount by remember { mutableStateOf("") }
    var reason by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    var selectedHistoryStatus by remember { mutableStateOf("") }

    OSINETScreen {
        OSINETHeader(
            title = "Préstamos",
            subtitle = "Solicitudes, aprobación, entrega y balance por empleado"
        )
        Spacer(Modifier.height(14.dp))
        LoanSummary(
            summary = summary,
            onPending = { selectedHistoryStatus = LoanEntity.STATUS_PENDING },
            onApproved = { selectedHistoryStatus = LoanEntity.STATUS_APPROVED },
            onDelivered = { selectedHistoryStatus = LoanEntity.STATUS_DELIVERED }
        )
        if (selectedHistoryStatus.isNotBlank()) {
            Spacer(Modifier.height(14.dp))
            LoanHistoryPanel(
                title = historyTitle(selectedHistoryStatus),
                loans = loans.filter { it.status == selectedHistoryStatus },
                viewModel = viewModel,
                onClose = { selectedHistoryStatus = "" }
            )
        }
        Spacer(Modifier.height(14.dp))
        OSINETCard {
            Text("Nueva solicitud", color = OSINETColors.TextPrimary)
            Spacer(Modifier.height(8.dp))
            OSINETTextField(employeeCode, { employeeCode = EmployeeCodePolicy.sanitizeInput(it) }, "Código de empleado", Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OSINETTextField(requestedAmount, { requestedAmount = amountInput(it) }, "Monto solicitado", Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OSINETTextField(payrollDiscount, { payrollDiscount = amountInput(it) }, "Descuento por nómina", Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OSINETTextField(reason, { reason = it }, "Motivo", Modifier.fillMaxWidth())
            Spacer(Modifier.height(10.dp))
            OSINETButton(
                text = "GUARDAR SOLICITUD",
                enabled = EmployeeCodePolicy.isValid(employeeCode) && requestedAmount.isNotBlank(),
                onClick = {
                    val code = EmployeeCodePolicy.normalizeOrNull(employeeCode) ?: return@OSINETButton
                    val matches = employees.filter {
                        EmployeeCodePolicy.matches(it.employeeCode, code)
                    }.distinctBy(Employee::id)
                    val employee = matches.singleOrNull()
                    val amount = LoanEngine.normalizeAmount(requestedAmount)
                    val discount = LoanEngine.normalizeAmount(payrollDiscount)
                    if (employee == null) {
                        message = if (matches.isEmpty()) {
                            "No existe empleado activo con código $code."
                        } else {
                            "El código coincide con más de un empleado. Revise los datos."
                        }
                        return@OSINETButton
                    }
                    if (amount <= 0.0) {
                        message = "El monto solicitado debe ser mayor que cero."
                        return@OSINETButton
                    }
                    val now = nowDateTime()
                    viewModel.saveLoan(
                        LoanEntity(
                            employeeId = employee.id,
                            employeeName = employee.nombre,
                            employeeCode = EmployeeCodePolicy.normalizeOrNull(employee.employeeCode) ?: code,
                            requestedAmount = amount,
                            payrollDiscount = discount,
                            reason = reason.trim(),
                            requestedBy = "ADMIN",
                            requestedDate = now,
                            createdAt = now,
                            updatedAt = now
                        )
                    )
                    employeeCode = ""
                    requestedAmount = ""
                    payrollDiscount = ""
                    reason = ""
                    message = "Solicitud de préstamo guardada para ${employee.nombre}."
                }
            )
            if (message.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(message, color = OSINETColors.GreenSoft)
            }
        }
        Spacer(Modifier.height(14.dp))
        Text("Solicitudes registradas", color = OSINETColors.TextPrimary)
        Spacer(Modifier.height(8.dp))
        if (loans.isEmpty()) {
            OSINETCard {
                Text("No hay préstamos registrados.", color = OSINETColors.TextSecondary)
            }
        } else {
            loans.forEach { loan ->
                LoanRow(loan = loan, viewModel = viewModel)
                Spacer(Modifier.height(8.dp))
            }
        }
        Spacer(Modifier.height(16.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}

@Composable
private fun LoanSummary(
    summary: LoanEngine.Summary,
    onPending: () -> Unit,
    onApproved: () -> Unit,
    onDelivered: () -> Unit
) {
    OSINETCard {
        OSINETActionCard("Pendientes", "${summary.pending} solicitudes en espera", onClick = onPending)
        Spacer(Modifier.height(8.dp))
        OSINETActionCard("Aprobados", "${summary.approved} préstamos aprobados", onClick = onApproved)
        Spacer(Modifier.height(8.dp))
        OSINETActionCard("Entregados", "${summary.delivered} préstamos entregados", onClick = onDelivered)
        Spacer(Modifier.height(8.dp))
        Text("Balance activo: ${money(summary.activeBalance)}", color = OSINETColors.GreenSoft)
        Text("Pagados: ${summary.paid}", color = OSINETColors.TextSecondary)
    }
}

@Composable
private fun LoanHistoryPanel(
    title: String,
    loans: List<LoanEntity>,
    viewModel: LoanViewModel,
    onClose: () -> Unit
) {
    OSINETCard {
        Text(title, color = OSINETColors.TextPrimary)
        Spacer(Modifier.height(8.dp))
        if (loans.isEmpty()) {
            Text("No hay registros para este estado.", color = OSINETColors.TextSecondary)
        } else {
            loans.forEach { loan ->
                LoanRow(loan = loan, viewModel = viewModel)
                Spacer(Modifier.height(8.dp))
            }
        }
        OSINETSecondaryButton("Cerrar historial", onClose)
    }
}

@Composable
private fun LoanRow(loan: LoanEntity, viewModel: LoanViewModel) {
    var paymentAmount by remember(loan.id) { mutableStateOf("") }

    OSINETCard {
        Text("${loan.employeeCode} · ${loan.employeeName}", color = OSINETColors.TextPrimary)
        Text("Estado: ${loan.status}", color = OSINETColors.GreenSoft)
        Text("Solicitado: ${money(loan.requestedAmount)} · Aprobado: ${money(loan.approvedAmount)}", color = OSINETColors.TextSecondary)
        Text("Balance: ${money(loan.balance)} · Descuento nómina: ${money(loan.payrollDiscount)}", color = OSINETColors.TextSecondary)
        if (loan.reason.isNotBlank()) {
            Text("Motivo: ${loan.reason}", color = OSINETColors.TextSecondary)
        }
        Spacer(Modifier.height(8.dp))
        when (loan.status) {
            LoanEntity.STATUS_PENDING -> {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OSINETButton(
                        text = "APROBAR",
                        modifier = Modifier.weight(1f),
                        onClick = {
                            val now = nowDateTime()
                            val amount = if (loan.approvedAmount > 0.0) loan.approvedAmount else loan.requestedAmount
                            viewModel.approveLoan(
                                loanId = loan.id,
                                approvedAmount = amount,
                                payrollDiscount = loan.payrollDiscount,
                                approvedBy = "ADMIN",
                                now = now
                            )
                        }
                    )
                    OSINETButton(
                        text = "RECHAZAR",
                        modifier = Modifier.weight(1f),
                        onClick = {
                            val now = nowDateTime()
                            viewModel.rejectLoan(loan.id, "ADMIN", "Rechazado por administración", now)
                        }
                    )
                }
            }
            LoanEntity.STATUS_APPROVED -> {
                OSINETButton(
                    text = "MARCAR ENTREGADO",
                    onClick = {
                        val now = nowDateTime()
                        viewModel.deliverLoan(loan.id, "ADMIN", now)
                    }
                )
            }
            LoanEntity.STATUS_DELIVERED -> {
                OSINETTextField(paymentAmount, { paymentAmount = amountInput(it) }, "Pago o descuento aplicado", Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
                OSINETButton(
                    text = "REGISTRAR PAGO",
                    enabled = paymentAmount.isNotBlank(),
                    onClick = {
                        val now = nowDateTime()
                        viewModel.registerPayment(loan, LoanEngine.normalizeAmount(paymentAmount), now)
                        paymentAmount = ""
                    }
                )
            }
            else -> {
                Text("Registro cerrado sin acciones pendientes.", color = OSINETColors.TextSecondary)
            }
        }
    }
}

private fun amountInput(value: String): String =
    value.filter { it.isDigit() || it == '.' || it == ',' }.take(12)

private fun money(value: Double): String =
    NumberFormat.getCurrencyInstance(Locale.forLanguageTag("es-DO")).format(value)

private fun nowDateTime(): String =
    SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())

private fun historyTitle(status: String): String =
    when (status) {
        LoanEntity.STATUS_PENDING -> "Historial de préstamos pendientes"
        LoanEntity.STATUS_APPROVED -> "Historial de préstamos aprobados"
        LoanEntity.STATUS_DELIVERED -> "Historial de préstamos entregados"
        else -> "Historial de préstamos"
    }
