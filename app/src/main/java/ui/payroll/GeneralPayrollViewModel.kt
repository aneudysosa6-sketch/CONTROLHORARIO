package com.example.controlhorario.ui.payroll

import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.EmployeePayrollSettingsEntity
import com.example.controlhorario.engine.GeneralPayrollEngine
import com.example.controlhorario.engine.GeneralPayrollExportEngine
import com.example.controlhorario.model.GeneralPayrollExport
import com.example.controlhorario.repository.AttendanceRepository
import com.example.controlhorario.repository.CompanySettingsRepository
import com.example.controlhorario.repository.EmployeePayrollSettingsRepository
import com.example.controlhorario.repository.EmployeePermissionRequestRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.repository.LaborCalendarRepository
import com.example.controlhorario.repository.PayrollSettingsRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class GeneralPayrollViewModel(
    private val employeeRepository: EmployeeRepository,
    private val attendanceRepository: AttendanceRepository,
    private val laborCalendarRepository: LaborCalendarRepository,
    private val payrollSettingsRepository: PayrollSettingsRepository,
    private val employeePayrollSettingsRepository: EmployeePayrollSettingsRepository,
    private val employeePermissionRequestRepository: EmployeePermissionRequestRepository,
    private val companySettingsRepository: CompanySettingsRepository
) : ViewModel() {

    private val _state = MutableStateFlow(GeneralPayrollUiState())
    val state: StateFlow<GeneralPayrollUiState> = _state

    private var currentPayroll: GeneralPayrollExport? = null
    private var pendingUpdatedSettings: List<EmployeePayrollSettingsEntity> = emptyList()

    init {
        viewModelScope.launch {
            combine(
                employeeRepository.getAllEmployees(),
                attendanceRepository.getAllAttendanceRecords(),
                laborCalendarRepository.getAllDays(),
                payrollSettingsRepository.getPayrollSettings(),
                employeePayrollSettingsRepository.getAllSettings()
            ) { employees, attendance, laborDays, payrollSettings, employeeSettings ->
                PartialGeneralPayrollDataSnapshot(
                    employees = employees,
                    attendance = attendance,
                    laborDays = laborDays,
                    payrollSettings = payrollSettings,
                    employeeSettings = employeeSettings,
                    medicalLicensePayments = emptyList()
                )
            }.combine(employeePermissionRequestRepository.getAllMedicalLicensePayments()) { partial, medicalLicensePayments ->
                partial.copy(
                    medicalLicensePayments = medicalLicensePayments
                )
            }.combine(companySettingsRepository.getCompanySettings()) { partial, companySettings ->
                GeneralPayrollDataSnapshot(
                    employees = partial.employees,
                    attendance = partial.attendance,
                    laborDays = partial.laborDays,
                    payrollSettings = partial.payrollSettings,
                    employeeSettings = partial.employeeSettings,
                    medicalLicensePayments = partial.medicalLicensePayments,
                    companySettings = companySettings
                )
            }.collect { snapshot ->
                _state.value = _state.value.copy(snapshot = snapshot)
            }
        }
    }

    fun generatePayroll(periodStart: String, periodEnd: String) {
        val snapshot = _state.value.snapshot ?: run {
            _state.value = _state.value.copy(message = "Datos no disponibles todavía.")
            return
        }
        val result = GeneralPayrollEngine.calculate(
            employees = snapshot.employees,
            settings = snapshot.employeeSettings,
            attendanceRecords = snapshot.attendance,
            laborCalendarDays = snapshot.laborDays,
            medicalLicensePayments = snapshot.medicalLicensePayments,
            generalSettings = snapshot.payrollSettings,
            periodStart = periodStart,
            periodEnd = periodEnd
        )
        currentPayroll = result.export
        pendingUpdatedSettings = result.updatedSettings
        _state.value = _state.value.copy(
            payroll = result.export,
            message = "Nómina general calculada correctamente."
        )
    }


    fun generatePayrollAndFiles(context: Context, periodStart: String, periodEnd: String) {
        generatePayroll(periodStart, periodEnd)
        val payroll = currentPayroll ?: _state.value.payroll ?: return
        val company = _state.value.snapshot?.companySettings
        val pdfResult = GeneralPayrollExportEngine.generateGeneralPayrollPdf(context, company, payroll)
        val csvResult = GeneralPayrollExportEngine.generateGeneralPayrollCsv(context, payroll)
        val pdfMessage = if (pdfResult.success) "PDF: ${pdfResult.displayPath}" else "PDF error: ${pdfResult.errorMessage}"
        val csvMessage = if (csvResult.success) "Excel/CSV: ${csvResult.displayPath}" else "Excel/CSV error: ${csvResult.errorMessage}"
        _state.value = _state.value.copy(
            message = "Nómina general generada. $pdfMessage | $csvMessage",
            lastPdfPath = pdfResult.displayPath,
            lastCsvPath = csvResult.displayPath
        )
    }

    fun saveBalancesAfterPayroll() {
        val settings = pendingUpdatedSettings
        if (settings.isEmpty()) {
            _state.value = _state.value.copy(message = "Primero genere la nómina.")
            return
        }
        viewModelScope.launch {
            employeePayrollSettingsRepository.saveAllSettings(settings)
            _state.value = _state.value.copy(message = "Saldos de préstamos y créditos actualizados.")
        }
    }

    fun downloadTemplate(context: Context) {
        val employees = _state.value.snapshot?.employees.orEmpty()
        val result = GeneralPayrollExportEngine.generateDiscountTemplateCsv(context, employees)
        _state.value = _state.value.copy(
            message = if (result.success) "Plantilla generada: ${result.displayPath}" else "Error: ${result.errorMessage}"
        )
    }

    fun uploadTemplate(context: Context, uri: Uri) {
        val snapshot = _state.value.snapshot ?: return
        viewModelScope.launch {
            try {
                val content = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }.orEmpty()
                val currentSettings = snapshot.employeeSettings.associateBy { it.employeeId }
                val employeesByCode = snapshot.employees.associateBy { employee -> employee.employeeCode }
                val updated = mutableListOf<EmployeePayrollSettingsEntity>()

                content.lines().drop(1).filter { it.isNotBlank() }.forEach { line ->
                    val columns = parseCsvLine(line)
                    val code = columns.getOrNull(0)?.trim().orEmpty()
                    val employee = employeesByCode[code] ?: return@forEach
                    val base = currentSettings[employee.id] ?: EmployeePayrollSettingsEntity(employeeId = employee.id)
                    val loanDiscount = columns.getOrNull(2).toMoneyDouble()
                    val creditDiscount = columns.getOrNull(3).toMoneyDouble()
                    val otherDiscount = columns.getOrNull(4).toMoneyDouble()
                    val loanPending = if (base.loanPendingAmount > 0.0) base.loanPendingAmount else base.totalLoanAmount
                    val creditPending = if (base.creditPendingAmount > 0.0) base.creditPendingAmount else base.totalCreditAmount
                    updated += base.copy(
                        loanAmount = loanDiscount.coerceAtMost(if (loanPending > 0.0) loanPending else loanDiscount),
                        loanPayrollDiscountAmount = loanDiscount,
                        creditPayrollDiscountAmount = creditDiscount,
                        oneTimeCreditAmount = creditDiscount.coerceAtMost(if (creditPending > 0.0) creditPending else creditDiscount),
                        otherDiscountAmount = otherDiscount
                    )
                }

                if (updated.isNotEmpty()) {
                    employeePayrollSettingsRepository.saveAllSettings(updated)
                    _state.value = _state.value.copy(
                        message = "Plantilla subida. Descuentos aplicados: ${updated.size} empleados.",
                        templateUploaded = true,
                        templateHasErrors = false
                    )
                } else {
                    _state.value = _state.value.copy(
                        message = "No se encontraron descuentos válidos en la plantilla.",
                        templateUploaded = false,
                        templateHasErrors = true
                    )
                }
            } catch (e: Exception) {
                _state.value = _state.value.copy(
                    message = "Error subiendo plantilla: ${e.message}",
                    templateUploaded = false,
                    templateHasErrors = true
                )
            }
        }
    }

    fun exportPdf(context: Context) {
        val payroll = currentPayroll ?: _state.value.payroll ?: run {
            _state.value = _state.value.copy(message = "Primero genere la nómina.")
            return
        }
        val company = _state.value.snapshot?.companySettings
        val result = GeneralPayrollExportEngine.generateGeneralPayrollPdf(context, company, payroll)
        _state.value = _state.value.copy(
            message = if (result.success) "PDF generado: ${result.displayPath}" else "Error PDF: ${result.errorMessage}",
            lastPdfPath = result.displayPath
        )
    }

    fun exportCsv(context: Context) {
        val payroll = currentPayroll ?: _state.value.payroll ?: run {
            _state.value = _state.value.copy(message = "Primero genere la nómina.")
            return
        }
        val result = GeneralPayrollExportEngine.generateGeneralPayrollCsv(context, payroll)
        _state.value = _state.value.copy(
            message = if (result.success) "Excel/CSV generado: ${result.displayPath}" else "Error CSV: ${result.errorMessage}",
            lastCsvPath = result.displayPath
        )
    }

    fun markExternalSendPending(channel: String) {
        _state.value = _state.value.copy(
            message = "Envío por $channel preparado. Use el archivo exportado para compartirlo manualmente."
        )
    }

    companion object {
        fun defaultStartDate(): String = SimpleDateFormat("yyyy-MM-01", Locale.getDefault()).format(Date())
        fun defaultEndDate(): String = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

        fun currentFortnightStartDate(): String {
            val calendar = Calendar.getInstance()
            val day = calendar.get(Calendar.DAY_OF_MONTH)
            calendar.set(Calendar.DAY_OF_MONTH, if (day <= 15) 1 else 16)
            return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(calendar.time)
        }

        fun currentFortnightEndDate(): String {
            val calendar = Calendar.getInstance()
            val day = calendar.get(Calendar.DAY_OF_MONTH)
            if (day <= 15) {
                calendar.set(Calendar.DAY_OF_MONTH, 15)
            } else {
                calendar.set(Calendar.DAY_OF_MONTH, calendar.getActualMaximum(Calendar.DAY_OF_MONTH))
            }
            return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(calendar.time)
        }
    }
}

private fun String?.toMoneyDouble(): Double = this
    ?.replace("RD$", "")
    ?.replace("$", "")
    ?.replace(",", "")
    ?.trim()
    ?.toDoubleOrNull()
    ?: 0.0

private fun parseCsvLine(line: String): List<String> {
    val result = mutableListOf<String>()
    val current = StringBuilder()
    var inQuotes = false
    var i = 0
    while (i < line.length) {
        val c = line[i]
        when {
            c == '"' && inQuotes && i + 1 < line.length && line[i + 1] == '"' -> {
                current.append('"')
                i++
            }
            c == '"' -> inQuotes = !inQuotes
            c == ',' && !inQuotes -> {
                result += current.toString()
                current.clear()
            }
            else -> current.append(c)
        }
        i++
    }
    result += current.toString()
    return result
}
