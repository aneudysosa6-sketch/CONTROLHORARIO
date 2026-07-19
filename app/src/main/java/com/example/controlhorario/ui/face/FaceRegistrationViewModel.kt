package com.example.controlhorario.ui.face

import android.util.Log
import android.content.Context
import com.example.controlhorario.BuildConfig
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.EmployeeFaceBiometricEntity
import com.example.controlhorario.face.FaceEmbeddingCipher
import com.example.controlhorario.face.FaceEmbeddingEngine
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.device.EmployeeUploadScheduler
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class FaceRegistrationState(
    val employee: Employee? = null,
    val registered: Boolean = false,
    val samples: Int = 0,
    val currentPose: FaceRegistrationPose = FaceRegistrationPose.FRONT,
    val capturing: Boolean = false,
    val saving: Boolean = false,
    val registrationCompleted: Boolean = false,
    val cameraError: Boolean = false,
    val message: String = "Busque un empleado para registrar su rostro."
)

class FaceRegistrationViewModel(
    private val context: Context,
    private val employees: EmployeeRepository,
    private val faces: EmployeeFaceBiometricRepository,
    private val cipher: FaceEmbeddingCipher = FaceEmbeddingCipher()
) : ViewModel() {
    private val _state = MutableStateFlow(FaceRegistrationState())
    val state: StateFlow<FaceRegistrationState> = _state.asStateFlow()
    private val posePolicy = FaceRegistrationPosePolicy()
    private val samples = mutableListOf<FloatArray>()
    private var saving = false

    fun find(code: String) = viewModelScope.launch {
        val employee = employees.findByEmployeeCode(code.filter(Char::isDigit).padStart(5, '0'))
        val record = employee?.let { faces.activeForEmployee(it.id) }
        _state.value = if (employee == null) {
            FaceRegistrationState(message = "No existe un empleado activo con ese código.")
        } else {
            FaceRegistrationState(
                employee = employee,
                registered = record != null,
                message = if (record == null) "Rostro no registrado." else "Rostro registrado."
            )
        }
        debug("FACE_REG_EMPLOYEE_LOADED", "employeeId=${employee?.id ?: -1} active=${employee?.isActive == true}")
    }

    fun findByEmployeeId(employeeId: Int) = viewModelScope.launch {
        val employee = employees.findActiveByLocalId(employeeId)
        val record = employee?.let { faces.activeForEmployee(it.id) }
        _state.value = if (employee == null) {
            FaceRegistrationState(message = "No existe un empleado activo para el registro facial.")
        } else {
            FaceRegistrationState(
                employee = employee,
                registered = record != null,
                message = if (record == null) "Rostro no registrado." else "Rostro registrado."
            )
        }
        debug("FACE_REG_EMPLOYEE_LOADED", "employeeId=$employeeId active=${employee?.isActive == true}")
    }

    fun beginCapture() {
        if (_state.value.employee == null || saving) return
        samples.forEach { it.fill(0f) }
        samples.clear()
        posePolicy.reset()
        _state.value = _state.value.copy(
            samples = 0,
            currentPose = FaceRegistrationPose.FRONT,
            capturing = true,
            cameraError = false,
            message = FaceRegistrationPose.FRONT.instruction
        )
    }

    fun observeFace(y: Float, x: Float, z: Float, embedding: FloatArray): Boolean {
        val current = _state.value
        if (!current.capturing || saving || embedding.size != FaceEmbeddingEngine.EMBEDDING_DIMENSION) {
            debug(
                "FACE_REG_SAMPLE",
                "x=$x y=$y z=$z state=capturing:${current.capturing},saving:$saving " +
                    "pose=${current.currentPose} reason=precondition_failed embeddingSize=${embedding.size}"
            )
            return false
        }
        val result = posePolicy.observe(y, x, z)
        when (result) {
            is FaceRegistrationPosePolicy.PoseObservation.Waiting -> {
                _state.value = _state.value.copy(currentPose = result.pose, message = result.guidance)
                debug(
                    "FACE_REG_SAMPLE",
                    "x=$x y=$y z=$z state=waiting pose=${result.pose} reason=${result.guidance}"
                )
                return false
            }
            is FaceRegistrationPosePolicy.PoseObservation.Accepted -> {
                samples += FaceEmbeddingEngine.average(listOf(embedding))
                val done = result.completedSamples
                debug(
                    "FACE_REG_SAMPLE",
                    "x=$x y=$y z=$z state=accepted pose=${result.pose} samples=$done " +
                        "reason=sample_saved_in_memory"
                )
                if (done == FaceRegistrationPose.entries.size) {
                    _state.value = _state.value.copy(samples = done, capturing = false, saving = true, message = "Guardando rostro...")
                    save("ADMIN")
                } else {
                    _state.value = _state.value.copy(
                        samples = done,
                        currentPose = posePolicy.currentPose,
                        message = "Muestra $done de 5 completada. ${posePolicy.currentPose.instruction}"
                    )
                }
                return true
            }
        }
    }

    fun guidance(message: String) {
        if (_state.value.capturing && !saving) {
            _state.value = _state.value.copy(message = message)
        }
    }

    fun cameraFailure(error: Throwable) {
        debug("FACE_REG_CAMERA_ERROR", "type=${error.javaClass.simpleName} message=${error.message.orEmpty().take(120)}")
        _state.value = _state.value.copy(
            capturing = false,
            saving = false,
            cameraError = true,
            message = "No se pudo iniciar el registro facial."
        )
    }

    fun acknowledgeRegistrationCompleted() {
        _state.value = _state.value.copy(registrationCompleted = false)
    }

    private fun save(registeredBy: String) {
        if (saving) return
        saving = true
        viewModelScope.launch {
            val employee = _state.value.employee ?: run { saving = false; return@launch }
            runCatching {
            require(samples.size == FaceRegistrationPose.entries.size)
            require(samples.all { it.size == FaceEmbeddingEngine.EMBEDDING_DIMENSION })
            val embedding = FaceEmbeddingEngine.average(samples)
            val now = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.US).format(Date())
            val previous = faces.activeForEmployee(employee.id)
            val insertedId = faces.replace(
                EmployeeFaceBiometricEntity(
                    employeeId = employee.id,
                    encryptedEmbedding = cipher.encrypt(embedding),
                    embeddingVersion = 1,
                    modelName = "FaceNet-128",
                    embeddingDimension = FaceEmbeddingEngine.EMBEDDING_DIMENSION,
                    registeredAt = previous?.registeredAt ?: now,
                    registeredBy = registeredBy.ifBlank { "ADMIN" },
                    updatedAt = now
                )
            )
            require(insertedId > 0)
            val stored = requireNotNull(faces.activeForEmployee(employee.id))
            require(stored.embeddingDimension == FaceEmbeddingEngine.EMBEDDING_DIMENSION)
            require(cipher.decrypt(stored.encryptedEmbedding, stored.embeddingDimension)?.size == FaceEmbeddingEngine.EMBEDDING_DIMENSION)
            employees.enqueueFaceEmbedding(employee, embedding)
            EmployeeUploadScheduler.enqueueImmediate(context)
            }.onSuccess {
            _state.value = _state.value.copy(registered = true, samples = 5, capturing = false, saving = false, registrationCompleted = true, message = "Rostro registrado correctamente.")
            }.onFailure { error ->
                Log.d("FACE_REGISTRATION", "saveFailure=${error.javaClass.simpleName}")
                _state.value = _state.value.copy(capturing = false, saving = false, message = "No se pudo guardar el rostro. Intente nuevamente.")
            }
            saving = false
            samples.forEach { it.fill(0f) }
            samples.clear()
        }
    }

    fun remove() = viewModelScope.launch {
        val employee = _state.value.employee ?: return@launch
        faces.delete(employee.id)
        _state.value = _state.value.copy(registered = false, samples = 0, capturing = false, registrationCompleted = false, message = "Rostro eliminado completamente.")
    }

    override fun onCleared() {
        samples.forEach { it.fill(0f) }
        samples.clear()
        super.onCleared()
    }

    private fun debug(tag: String, message: String) {
        if (BuildConfig.DEBUG) Log.d(tag, message)
    }
}
