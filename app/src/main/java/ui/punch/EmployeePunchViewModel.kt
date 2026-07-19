package com.example.controlhorario.ui.punch

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.EmployeeCodePolicy
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** Identifies the employee by code. The biometric proof is always performed on the facial route. */
class EmployeePunchViewModel(
    private val employeeRepository: EmployeeRepository,
    private val faceRepository: EmployeeFaceBiometricRepository
) : ViewModel() {
    private val _state = MutableStateFlow(EmployeePunchState())
    val state: StateFlow<EmployeePunchState> = _state.asStateFlow()

    fun appendDigit(digit: String) {
        val current = _state.value
        if (current.code.length >= REQUIRED_PIN_LENGTH || current.identifying || digit.length != 1 || !digit[0].isDigit()) return
        val code = current.code + digit
        _state.value = current.copy(code = code, employee = null, hasFaceTemplate = false, message = "")
        if (code.length == REQUIRED_PIN_LENGTH) identifyEmployee()
    }

    fun deleteLastDigit() {
        val current = _state.value
        if (current.identifying) return
        _state.value = current.copy(code = current.code.dropLast(1), employee = null, hasFaceTemplate = false, message = "")
    }

    fun clear() {
        _state.value = EmployeePunchState()
    }

    private fun identifyEmployee() {
        val digits = _state.value.code.filter { it.isDigit() }
        val code = digits.padStart(REQUIRED_PIN_LENGTH, '0')
        Log.d("EMPLOYEE_LOOKUP", "layer=EmployeePunchViewModel event=START enteredDigits=${digits.length}")
        if (digits.length != REQUIRED_PIN_LENGTH || code == "00000") {
            clearAfterFailure("PIN incorrecto.")
            return
        }
        _state.value = _state.value.copy(identifying = true, message = "Buscando empleado...")
        viewModelScope.launch {
            val employee = employeeRepository.findByEmployeeCode(code)
            when {
                employee == null -> _state.value = EmployeePunchState(message = "PIN incorrecto. Intente nuevamente.")
                !employee.jornadaEnabled -> _state.value = EmployeePunchState(message = "Tu registro de jornada está deshabilitado.")
                else -> {
                    val hasFace = faceRepository.activeForEmployee(employee.id) != null
                    _state.value = EmployeePunchState(
                        code = code,
                        employee = employee,
                        hasFaceTemplate = hasFace,
                        message = if (hasFace) {
                            "Empleado identificado: ${employee.nombre}. Validando rostro."
                        } else {
                            "Este empleado no tiene un rostro registrado. Contacte al administrador."
                        }
                    )
                    Log.d("EMPLOYEE_STATE", "event=EMPLOYEE_ASSIGNED employeeId=${employee.id} hasFaceTemplate=$hasFace")
                }
            }
        }
    }

    private fun clearAfterFailure(message: String) {
        _state.value = EmployeePunchState(message = message)
    }

    companion object {
        const val REQUIRED_PIN_LENGTH = EmployeeCodePolicy.LENGTH
    }
}

data class EmployeePunchState(
    val code: String = "",
    val employee: Employee? = null,
    val hasFaceTemplate: Boolean = false,
    val identifying: Boolean = false,
    val message: String = ""
)
