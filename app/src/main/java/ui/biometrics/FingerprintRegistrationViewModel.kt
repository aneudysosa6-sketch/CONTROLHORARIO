package com.example.controlhorario.ui.biometrics

import android.util.Base64
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.database.EmployeeBiometricEntity
import com.example.controlhorario.fingerprint.external.FingerprintTemplateDiagnostics
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.EmployeeBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class FingerprintRegistrationViewModel(
    private val biometricRepository: EmployeeBiometricRepository,
    private val employeeRepository: EmployeeRepository
) : ViewModel() {

    private val _state = MutableStateFlow(FingerprintRegistrationState())
    val state: StateFlow<FingerprintRegistrationState> = _state.asStateFlow()

    fun identifyEmployee(codeText: String) {
        val digits = codeText.filter { it.isDigit() }
        val code = digits.padStart(5, '0')
        if (digits.isBlank() || code == "00000") {
            _state.value = _state.value.copy(message = "Digite un código de empleado válido.")
            return
        }

        viewModelScope.launch {
            val employee = employeeRepository.findByEmployeeCode(code)
            _state.value = if (employee == null) {
                _state.value.copy(
                    employeeCode = code,
                    selectedEmployee = null,
                    message = "No existe empleado activo con código $code."
                )
            } else {
                val currentBiometric = biometricRepository.getActiveByEmployee(employee.id)
                _state.value.copy(
                    employeeCode = code,
                    selectedEmployee = employee,
                    registeredTemplateSize = currentBiometric?.templateSize ?: 0,
                    message = if (currentBiometric?.templateBase64?.isNotBlank() == true) {
                        "Empleado encontrado: ${employee.nombre}. Tiene huella 2Connect activa."
                    } else {
                        "Empleado encontrado: ${employee.nombre}. Ahora puede registrar la huella con el lector 2Connect."
                    }
                )
            }
        }
    }

    fun registerTwoConnectFingerprint(
        registeredBy: String,
        templateBase64: String,
        templateSize: Int
    ) {
        val employee = _state.value.selectedEmployee
        if (employee == null) {
            _state.value = _state.value.copy(message = "Primero busque y seleccione un empleado.")
            return
        }
        if (templateBase64.isBlank()) {
            _state.value = _state.value.copy(message = "La plantilla capturada está vacía.")
            return
        }

        viewModelScope.launch {
            val now = nowDateTime()
            val registeredByValue = registeredBy.ifBlank { "ADMIN" }
            val templateBytes = runCatching {
                Base64.decode(templateBase64, Base64.NO_WRAP).size
            }.getOrDefault(-1)
            if (BuildConfig.DEBUG) {
                Log.d(
                    "FINGERPRINT_ENROLL",
                    "employeeId=${employee.id} templateBytes=$templateBytes " +
                        "templateBase64Length=${templateBase64.length} saveSuccess=false"
                )
            }
            val template = EmployeeBiometricEntity(
                employeeId = employee.id,
                employeeName = employee.nombre,
                biometricType = EmployeeBiometricEntity.TYPE_2CONNECT_USB,
                deviceName = "2Connect USB Fingerprint Scanner",
                templateBase64 = templateBase64,
                templateSize = templateSize,
                sdkProvider = "fplib-reader-v3.jar",
                registeredBy = registeredByValue,
                registeredAt = now,
                updatedAt = now,
                isActive = true
            )
            try {
                val replacement = biometricRepository.replaceForEmployee(template)
                val lookup = biometricRepository.getActiveByEmployeeWithMetadata(employee.id)
                val persisted = lookup.record
                val inputSha = FingerprintTemplateDiagnostics.summarize(
                    Base64.decode(templateBase64, Base64.NO_WRAP)
                ).sha256
                val persistedSha = persisted?.templateBase64?.let { encoded ->
                    runCatching {
                        FingerprintTemplateDiagnostics.summarize(
                            Base64.decode(encoded, Base64.NO_WRAP)
                        ).sha256
                    }.getOrNull()
                }
                if (persisted == null || lookup.rowsFound != 1 || persisted.id.toLong() != replacement.insertedId || inputSha != persistedSha) {
                    throw IllegalStateException("La plantilla recién registrada no pudo verificarse en Room.")
                }
                if (BuildConfig.DEBUG) {
                    Log.d(
                        "FINGERPRINT_DB",
                        "employeeId=${employee.id} deletedRows=${replacement.deletedRows} " +
                            "insertedId=${replacement.insertedId} sha256=$inputSha updatedAt=${persisted.updatedAt}"
                    )
                }
                saveAndReportSuccess(employee, templateSize, registeredByValue, now, persisted)
            } catch (error: Exception) {
                if (BuildConfig.DEBUG) {
                    Log.d(
                        "FINGERPRINT_ENROLL",
                        "employeeId=${employee.id} templateBytes=$templateBytes " +
                            "templateBase64Length=${templateBase64.length} saveSuccess=false",
                        error
                    )
                }
                throw error
            }
        }
    }

    private suspend fun saveAndReportSuccess(
        employee: Employee,
        templateSize: Int,
        registeredByValue: String,
        now: String,
        persisted: EmployeeBiometricEntity
    ) {
        val persistedBytes = runCatching {
            Base64.decode(persisted.templateBase64, Base64.NO_WRAP)
        }.getOrNull()
        persistedBytes?.let { bytes ->
            FingerprintTemplateDiagnostics.log("C_AFTER_ROOM_SAVE", employee.id, bytes)
        }
        if (BuildConfig.DEBUG) {
            Log.d(
                "FINGERPRINT_ENROLL",
                "employeeId=${employee.id} templateBytes=${persistedBytes?.size ?: -1} " +
                    "templateBase64Length=${persisted.templateBase64.length} " +
                    "persistedBase64Length=${persisted.templateBase64.length} " +
                    "persistedBytes=${persistedBytes?.size ?: -1} saveSuccess=true"
            )
        }
        employeeRepository.markFingerprintRegistered(
            employeeId = employee.id,
            registeredAt = now,
            registeredBy = registeredByValue
        )
        _state.value = _state.value.copy(
            selectedEmployee = employee.copy(
                fingerprintRegistered = true,
                fingerprintRegisteredAt = now,
                fingerprintRegisteredBy = registeredByValue
            ),
            registeredTemplateSize = templateSize,
            message = "Huella 2Connect registrada correctamente para ${employee.nombre}."
        )
    }

    fun setMessage(message: String) {
        _state.value = _state.value.copy(message = message)
    }

    private fun nowDateTime(): String =
        SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
}

data class FingerprintRegistrationState(
    val employeeCode: String = "",
    val selectedEmployee: Employee? = null,
    val registeredTemplateSize: Int = 0,
    val message: String = ""
)
