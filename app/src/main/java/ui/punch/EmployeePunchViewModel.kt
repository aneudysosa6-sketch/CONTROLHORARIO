package com.example.controlhorario.ui.punch

import android.util.Base64
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.fingerprint.external.FingerprintTemplateDiagnostics
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.EmployeeCodePolicy
import com.example.controlhorario.repository.AttendanceRepository
import com.example.controlhorario.repository.EmployeeBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class EmployeePunchViewModel(
    private val employeeRepository: EmployeeRepository,
    private val attendanceRepository: AttendanceRepository,
    private val biometricRepository: EmployeeBiometricRepository
) : ViewModel() {

    private val _state = MutableStateFlow(EmployeePunchState())
    val state: StateFlow<EmployeePunchState> = _state.asStateFlow()

    fun appendDigit(digit: String) {
        val current = _state.value
        if (current.code.length >= REQUIRED_PIN_LENGTH || current.identifying || digit.length != 1 || !digit[0].isDigit()) return
        _state.value = current.copy(
            code = current.code + digit,
            employee = null,
            biometricVerified = false,
            hasTwoConnectTemplate = false,
            message = ""
        )
    }

    fun deleteLastDigit() {
        val current = _state.value
        if (current.identifying) return
        _state.value = current.copy(
            code = current.code.dropLast(1),
            employee = null,
            biometricVerified = false,
            hasTwoConnectTemplate = false,
            message = ""
        )
    }

    fun clear() {
        _state.value = EmployeePunchState()
    }

    fun identifyEmployee() {
        val digits = _state.value.code.filter { it.isDigit() }
        val code = digits.padStart(REQUIRED_PIN_LENGTH, '0')
        if (digits.length != REQUIRED_PIN_LENGTH || code == "00000") {
            clearAfterFailure("PIN incorrecto.")
            return
        }

        _state.value = _state.value.copy(identifying = true, message = "Buscando empleado...")
        viewModelScope.launch {
            val employee = employeeRepository.findByEmployeeCode(code)
            if (employee == null) {
                _state.value = EmployeePunchState(message = "PIN incorrecto. Intente nuevamente.")
            } else {
                if (!employee.jornadaEnabled) {
                    _state.value = EmployeePunchState(message = "Tu registro de jornada está deshabilitado.")
                    return@launch
                }
                val biometric = biometricRepository.getActiveByEmployee(employee.id)
                val hasTemplate = biometric?.templateBase64?.isNotBlank() == true
                _state.value = _state.value.copy(
                    code = code,
                    identifying = false,
                    employee = employee,
                    biometricVerified = false,
                    hasTwoConnectTemplate = hasTemplate,
                    message = if (hasTemplate) {
                        "Empleado identificado: ${employee.nombre}. Verificando huella automáticamente."
                    } else {
                        "Empleado identificado: ${employee.nombre}. Este empleado no tiene huella 2Connect registrada."
                    }
                )
            }
        }
    }

    suspend fun getStoredFingerprintTemplate(): StoredFingerprintTemplate? {
        val employee = _state.value.employee ?: return null
        val biometricLookup = biometricRepository.getActiveByEmployeeWithMetadata(employee.id)
        val biometric = biometricLookup.record ?: return null
        if (
            biometric.employeeId != employee.id ||
            biometric.biometricType != com.example.controlhorario.database.EmployeeBiometricEntity.TYPE_2CONNECT_USB ||
            biometric.templateBase64.isBlank() ||
            biometric.templateSize <= 0
        ) {
            return null
        }
        if (BuildConfig.DEBUG) {
            val decoded = runCatching {
                Base64.decode(biometric.templateBase64, Base64.NO_WRAP)
            }.getOrNull()
            val decodedBytes = decoded?.size ?: -1
            val selectedSha = decoded
                ?.let { FingerprintTemplateDiagnostics.summarize(it).sha256 }
                ?: "INVALID"
            decoded?.let { bytes ->
                FingerprintTemplateDiagnostics.log("D_AFTER_ROOM_READ", employee.id, bytes)
            }
            Log.d(
                "FINGERPRINT_DB",
                "employeeId=${employee.id} rowsFound=${biometricLookup.rowsFound} " +
                    "selectedRecordId=${biometric.id} selectedUpdatedAt=${biometric.updatedAt} " +
                    "selectedSha256=$selectedSha"
            )
            Log.d(
                "FINGERPRINT_VERIFY",
                "employeeId=${employee.id} storedEmployeeId=${biometric.employeeId} " +
                    "biometricType=${biometric.biometricType} " +
                    "biometricRecordId=${biometric.id} updatedAt=${biometric.updatedAt} " +
                    "base64LengthRead=${biometric.templateBase64.length} " +
                    "decodedBytes=$decodedBytes storedSizeColumn=${biometric.templateSize}"
            )
        }
        return StoredFingerprintTemplate(
            employeeId = employee.id,
            templateBase64 = biometric.templateBase64,
            templateSize = biometric.templateSize
        )
    }

    fun markFingerprintVerified(score: Int) {
        _state.value = _state.value.copy(
            biometricVerified = true,
            message = "Huella 2Connect verificada. Puntaje: $score. Abriendo asistencia..."
        )
    }

    fun setMessage(message: String) {
        _state.value = _state.value.copy(message = message, identifying = false)
    }

    fun keepEmployeeForFingerprintRetry(message: String) {
        val current = _state.value
        if (current.employee == null) {
            _state.value = EmployeePunchState(message = message)
            return
        }

        _state.value = current.copy(
            biometricVerified = false,
            identifying = false,
            message = message
        )
    }

    fun clearEmployeeAndCancelFingerprint() {
        _state.value = EmployeePunchState()
    }

    fun clearAfterFailure(message: String) {
        _state.value = EmployeePunchState(message = message)
    }

    fun registerAttendance(actionType: String) {
        val current = _state.value
        val employee = current.employee
        if (employee == null) {
            _state.value = current.copy(message = "Primero identifique el empleado.")
            return
        }
        if (!current.biometricVerified) {
            _state.value = current.copy(message = "Debe verificar la huella 2Connect antes de ponchar.")
            return
        }

        viewModelScope.launch {
            attendanceRepository.insertAttendance(
                AttendanceEntity(
                    employeeId = employee.id,
                    employeeName = employee.nombre,
                    date = today(),
                    time = currentTime(),
                    actionType = actionType,
                    biometricVerified = true,
                    deviceName = "2Connect USB Fingerprint Scanner",
                    notes = "Ponche verificado con lector 2Connect USB"
                )
            )
            _state.value = EmployeePunchState(message = "Ponche registrado correctamente: $actionType")
        }
    }

    private fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    private fun currentTime(): String = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date())

    companion object {
        const val REQUIRED_PIN_LENGTH = EmployeeCodePolicy.LENGTH
    }
}

data class EmployeePunchState(
    val code: String = "",
    val employee: Employee? = null,
    val biometricVerified: Boolean = false,
    val hasTwoConnectTemplate: Boolean = false,
    val identifying: Boolean = false,
    val message: String = ""
)

data class StoredFingerprintTemplate(
    val employeeId: Int,
    val templateBase64: String,
    val templateSize: Int
)
