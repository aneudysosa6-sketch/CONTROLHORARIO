package com.example.controlhorario.ui.biometrics

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.EmployeeBiometricEntity
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
            biometricRepository.deactivateByEmployee(employee.id, now)
            biometricRepository.save(
                EmployeeBiometricEntity(
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
            )
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
