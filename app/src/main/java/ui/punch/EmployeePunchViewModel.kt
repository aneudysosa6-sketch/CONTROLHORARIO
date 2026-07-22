package com.example.controlhorario.ui.punch

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.EmployeeCodePolicy
import com.example.controlhorario.model.EmployeeDeviceScopePolicy
import com.example.controlhorario.model.EmployeeDeviceScopeSource
import com.example.controlhorario.device.EmployeeFaceAvailabilityCoordinator
import com.example.controlhorario.device.FaceAvailabilityResult
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** Resolves a public employee code. Authorization is issued only by the later facial route. */
class EmployeePunchViewModel(
    private val employeeRepository: EmployeeRepository,
    private val faceRepository: EmployeeFaceBiometricRepository,
    private val faceAvailability: EmployeeFaceAvailabilityCoordinator,
    private val scopeSource: EmployeeDeviceScopeSource
) : ViewModel() {
    private val _state = MutableStateFlow(EmployeePunchState())
    val state: StateFlow<EmployeePunchState> = _state.asStateFlow()

    fun appendDigit(digit: String) {
        val current = _state.value
        if (current.code.length >= REQUIRED_CODE_LENGTH || current.identifying || digit.length != 1 || !digit[0].isDigit()) return
        val code = current.code + digit
        _state.value = current.copy(code = code, employee = null, hasFaceTemplate = false, message = "")
        if (code.length == REQUIRED_CODE_LENGTH) identifyEmployee()
    }

    fun deleteLastDigit() {
        val current = _state.value
        if (current.identifying) return
        _state.value = current.copy(code = current.code.dropLast(1), employee = null, hasFaceTemplate = false, message = "")
    }

    fun clear() {
        _state.value = EmployeePunchState()
    }

    fun retryFaceSync() {
        val current = _state.value
        val employee = current.employee ?: return
        if (!current.canRetryFaceSync || current.identifying) return
        viewModelScope.launch { synchronizeMissingFace(employee, current.code) }
    }

    /** Allows a five-digit historical code to be submitted explicitly and normalized to six. */
    fun submitCode() {
        val current = _state.value
        if (current.identifying) return
        if (!EmployeeCodePolicy.isValid(current.code)) {
            clearAfterFailure("Código de empleado incorrecto.")
            return
        }
        identifyEmployee()
    }

    private fun identifyEmployee() {
        val entered = _state.value.code
        val code = EmployeeCodePolicy.normalizeOrNull(entered)
        Log.d("EMPLOYEE_LOOKUP", "layer=EmployeePunchViewModel event=START enteredDigits=${entered.length}")
        if (code == null) {
            clearAfterFailure("Código de empleado incorrecto.")
            return
        }
        _state.value = _state.value.copy(code = code, identifying = true, message = "Buscando empleado...")
        viewModelScope.launch {
            val scope = scopeSource.current()
            if (scope == null) {
                _state.value = EmployeePunchState(message = "Este dispositivo no tiene una empresa y sucursal válidas.")
                return@launch
            }
            val employee = employeeRepository.findByEmployeeCode(code)
            when {
                employee == null -> _state.value = EmployeePunchState(message = "Código de empleado incorrecto. Intente nuevamente.")
                !EmployeeDeviceScopePolicy.allows(employee, scope) ->
                    _state.value = EmployeePunchState(message = "Empleado fuera del alcance de este dispositivo.")
                !employee.jornadaEnabled -> _state.value = EmployeePunchState(message = "Tu registro de jornada está deshabilitado.")
                else -> {
                    val hasFace = faceRepository.activeForEmployee(employee.id) != null
                    if (hasFace) showFaceReady(employee, code, "LOCAL") else synchronizeMissingFace(employee, code)
                }
            }
        }
    }

    private suspend fun synchronizeMissingFace(employee: Employee, enteredCode: String) {
        val current = _state.value
        if (current.identifying && current.employee != null) return
        _state.value = current.faceSyncStarted(employee, enteredCode)
        Log.d("FACE_CROSS_DEVICE_SYNC", "employeeCode=${EmployeeCodePolicy.maskForLog(employee.employeeCode)} localEmployeeId=${employee.id} localFaceBefore=false targetedSyncStarted=true")
        try {
            when (faceAvailability.ensure(employee)) {
                FaceAvailabilityResult.LOCAL,
                FaceAvailabilityResult.SYNCED -> showFaceReady(employee, enteredCode, "FACE_AVAILABLE")
                FaceAvailabilityResult.NOT_REGISTERED -> {
                    _state.value = _state.value.copy(
                        code = enteredCode,
                        employee = employee,
                        hasFaceTemplate = false,
                        identifying = false,
                        faceSyncCompleted = true,
                        canRetryFaceSync = false,
                        message = "Rostro no registrado. Contacte al administrador."
                    )
                    Log.d("FACE_CROSS_DEVICE_SYNC", "employeeCode=${EmployeeCodePolicy.maskForLog(employee.employeeCode)} localEmployeeId=${employee.id} localFaceAfter=false finalResult=NOT_REGISTERED")
                }
            }
        } catch (error: Exception) {
            Log.e("FACE_CROSS_DEVICE_SYNC", "employeeCode=${EmployeeCodePolicy.maskForLog(employee.employeeCode)} localEmployeeId=${employee.id} localFaceAfter=false finalResult=NETWORK_ERROR", error)
            _state.value = _state.value.faceSyncFailed(employee, enteredCode)
        }
    }

    private fun showFaceReady(employee: Employee, code: String, result: String) {
        _state.value = EmployeePunchState(
            code = code,
            employee = employee,
            hasFaceTemplate = true,
            identifying = false,
            faceSyncCompleted = true,
            message = "Empleado identificado: ${employee.nombre}. Validando rostro."
        )
        Log.d("FACE_CROSS_DEVICE_SYNC", "employeeCode=${EmployeeCodePolicy.maskForLog(employee.employeeCode)} remoteId=${employee.remoteId} localEmployeeId=${employee.id} localFaceAfter=true finalResult=$result")
    }

    private fun clearAfterFailure(message: String) {
        _state.value = EmployeePunchState(message = message)
    }

    companion object {
        const val REQUIRED_CODE_LENGTH = EmployeeCodePolicy.LENGTH
    }
}

data class EmployeePunchState(
    val code: String = "",
    val employee: Employee? = null,
    val hasFaceTemplate: Boolean = false,
    val identifying: Boolean = false,
    val faceSyncCompleted: Boolean = false,
    val canRetryFaceSync: Boolean = false,
    val message: String = ""
)

internal fun EmployeePunchState.faceSyncStarted(employee: Employee, enteredCode: String) = copy(
    code = enteredCode,
    employee = employee,
    hasFaceTemplate = false,
    identifying = true,
    faceSyncCompleted = false,
    canRetryFaceSync = false,
    message = "Sincronizando rostro..."
)

internal fun EmployeePunchState.faceSyncFailed(employee: Employee, enteredCode: String) = copy(
    code = enteredCode,
    employee = employee,
    hasFaceTemplate = false,
    identifying = false,
    faceSyncCompleted = false,
    canRetryFaceSync = true,
    message = "No se pudo sincronizar el rostro. Verifique la conexión y reintente."
)
