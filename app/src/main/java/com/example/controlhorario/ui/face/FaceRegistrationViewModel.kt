package com.example.controlhorario.ui.face

import android.util.Log
import android.content.Context
import com.example.controlhorario.BuildConfig
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.EmployeeFaceBiometricEntity
import com.example.controlhorario.face.FaceEmbeddingCipher
import com.example.controlhorario.face.FaceEmbeddingEngine
import com.example.controlhorario.face.InitialFaceCommitResult
import com.example.controlhorario.face.InitialFaceEligibility
import com.example.controlhorario.face.InitialFaceEnrollmentDenial
import com.example.controlhorario.face.InitialFaceEnrollmentPermit
import com.example.controlhorario.face.InitialFaceEnrollmentRepository
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

data class FaceRegistrationState(
    val employee: Employee? = null,
    val registered: Boolean = false,
    val validating: Boolean = false,
    val samples: Int = 0,
    val currentPose: FaceRegistrationPose = FaceRegistrationPose.FRONT,
    val capturing: Boolean = false,
    val saving: Boolean = false,
    val registrationCompleted: Boolean = false,
    val cameraError: Boolean = false,
    val message: String = "Busque un empleado para registrar su rostro."
)

enum class FaceRegistrationMode { ADMIN, PUBLIC_INITIAL }

class FaceRegistrationViewModel(
    private val context: Context,
    private val employees: EmployeeRepository,
    private val faces: EmployeeFaceBiometricRepository,
    private val cipher: FaceEmbeddingCipher = FaceEmbeddingCipher(),
    private val mode: FaceRegistrationMode = FaceRegistrationMode.ADMIN,
    private val initialEnrollment: InitialFaceEnrollmentRepository? = null
) : ViewModel() {
    private val _state = MutableStateFlow(FaceRegistrationState())
    val state: StateFlow<FaceRegistrationState> = _state.asStateFlow()
    private val posePolicy = FaceRegistrationPosePolicy()
    private val samples = mutableListOf<FloatArray>()
    private var saving = false
    private var initialPermit: InitialFaceEnrollmentPermit? = null

    init {
        if (mode == FaceRegistrationMode.PUBLIC_INITIAL) {
            _state.value = FaceRegistrationState(message = "")
        }
    }

    fun find(code: String) = viewModelScope.launch {
        if (mode == FaceRegistrationMode.PUBLIC_INITIAL) {
            val enrollment = initialEnrollment
            if (enrollment == null) {
                initialPermit = null
                _state.value = FaceRegistrationState(message = "El autorregistro facial no está disponible.")
                return@launch
            }
            initialPermit = null
            _state.value = FaceRegistrationState(
                validating = true,
                message = "Validando empleado y disponibilidad del rostro..."
            )
            val eligibility = try {
                enrollment.check(code)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                Log.e("FACE_FIRST_ENROLLMENT", "stage=eligibility finalResult=ERROR", error)
                InitialFaceEligibility.Denied(
                    InitialFaceEnrollmentDenial.REMOTE_VALIDATION_FAILED
                )
            }
            _state.value = when (eligibility) {
                is InitialFaceEligibility.Allowed -> {
                    initialPermit = eligibility.permit
                    FaceRegistrationState(
                        employee = eligibility.employee,
                        registered = false,
                        message = "Empleado validado. Puede registrar su rostro por primera vez."
                    )
                }
                is InitialFaceEligibility.Denied -> FaceRegistrationState(
                    message = initialEnrollmentMessage(eligibility.reason)
                )
            }
            return@launch
        }
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
        if (mode == FaceRegistrationMode.PUBLIC_INITIAL) {
            initialPermit = null
            _state.value = FaceRegistrationState(
                message = "El autorregistro público requiere el código de empleado."
            )
            return@launch
        }
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
        if (mode == FaceRegistrationMode.PUBLIC_INITIAL && initialPermit == null) {
            _state.value = _state.value.copy(
                message = "La validación expiró. Vuelva a validar el código de empleado."
            )
            return
        }
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
        return try {
            val current = _state.value
            if (!current.capturing || saving || embedding.size != FaceEmbeddingEngine.EMBEDDING_DIMENSION) {
                debug(
                    "FACE_REG_SAMPLE",
                    "x=$x y=$y z=$z state=capturing:${current.capturing},saving:$saving " +
                        "pose=${current.currentPose} reason=precondition_failed embeddingSize=${embedding.size}"
                )
                false
            } else {
                when (val result = posePolicy.observe(y, x, z)) {
                    is FaceRegistrationPosePolicy.PoseObservation.Waiting -> {
                        _state.value = _state.value.copy(
                            currentPose = result.pose,
                            message = result.guidance,
                        )
                        debug(
                            "FACE_REG_SAMPLE",
                            "x=$x y=$y z=$z state=waiting pose=${result.pose} reason=${result.guidance}"
                        )
                        false
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
                            _state.value = _state.value.copy(
                                samples = done,
                                capturing = false,
                                saving = true,
                                message = "Guardando rostro...",
                            )
                            save("ADMIN")
                        } else {
                            _state.value = _state.value.copy(
                                samples = done,
                                currentPose = posePolicy.currentPose,
                                message = "Muestra $done de 5 completada. ${posePolicy.currentPose.instruction}",
                            )
                        }
                        true
                    }
                }
            }
        } finally {
            // The camera callback transfers ownership of this transient biometric buffer here.
            // Accepted samples are copied above; the raw frame embedding must never linger.
            embedding.fill(0f)
        }
    }

    fun guidance(message: String) {
        if (_state.value.capturing && !saving) {
            _state.value = _state.value.copy(message = message)
        }
    }

    fun cameraFailure(error: Throwable) {
        Log.e("FACE_REGISTRATION_CRASH", "stage=error file=FaceRegistrationViewModel.kt pipelineStage=camera message=${error.message}", error)
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
            withContext(Dispatchers.IO) {
            require(samples.size == FaceRegistrationPose.entries.size)
            require(samples.all { it.size == FaceEmbeddingEngine.EMBEDDING_DIMENSION })
            val embedding = FaceEmbeddingEngine.average(samples)
            debug(
                "FACE_EMBEDDING_FLOW",
                "stage=generated employeeId=${employee.id} dimension=${embedding.size} finite=${embedding.all { it.isFinite() }}"
            )
            if (mode == FaceRegistrationMode.PUBLIC_INITIAL) {
                val permit = initialPermit
                    ?: throw InitialEnrollmentException(
                        "La validación expiró. Vuelva a validar el código de empleado."
                    )
                val enrollment = requireNotNull(initialEnrollment)
                initialPermit = null
                try {
                    when (val result = enrollment.commit(permit, embedding)) {
                        is InitialFaceCommitResult.Saved -> {
                            crashLog(
                                "stage=embedding_queued employeeId=${employee.id} " +
                                    "mode=INITIAL_ONLY validationMode=${result.validationMode}"
                            )
                        }
                        is InitialFaceCommitResult.Denied -> throw InitialEnrollmentException(
                            initialEnrollmentMessage(result.reason)
                        )
                    }
                } finally {
                    embedding.fill(0f)
                }
            } else {
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
                debug(
                    "FACE_EMBEDDING_FLOW",
                    "stage=stored employeeId=${employee.id} rowId=$insertedId dimension=${stored.embeddingDimension} encrypted=true"
                )
                val recovered = requireNotNull(
                    cipher.decrypt(stored.encryptedEmbedding, stored.embeddingDimension)
                )
                try {
                    require(
                        recovered.size == FaceEmbeddingEngine.EMBEDDING_DIMENSION &&
                            recovered.all { it.isFinite() }
                    )
                    crashLog("stage=embedding_stored employeeId=${employee.id} dimension=${recovered.size}")
                    debug(
                        "FACE_EMBEDDING_FLOW",
                        "stage=decrypted employeeId=${employee.id} dimension=${recovered.size} finite=true"
                    )
                    employees.enqueueFaceEmbedding(employee, recovered)
                    crashLog("stage=embedding_queued employeeId=${employee.id} dimension=${recovered.size}")
                    EmployeeUploadScheduler.enqueueImmediate(context)
                } finally {
                    recovered.fill(0f)
                    embedding.fill(0f)
                }
            }
            }
            }.onSuccess {
            _state.value = _state.value.copy(registered = true, samples = 5, capturing = false, saving = false, registrationCompleted = true, message = "Rostro registrado correctamente.")
            }.onFailure { error ->
                if (error is CancellationException) throw error
                Log.e("FACE_REGISTRATION_CRASH", "stage=error file=FaceRegistrationViewModel.kt pipelineStage=storage message=${error.message}", error)
                val message = (error as? InitialEnrollmentException)?.message
                    ?: "No se pudo guardar el rostro. Intente nuevamente."
                _state.value = if (mode == FaceRegistrationMode.PUBLIC_INITIAL) {
                    FaceRegistrationState(message = message)
                } else {
                    _state.value.copy(capturing = false, saving = false, message = message)
                }
            }
            saving = false
            samples.forEach { it.fill(0f) }
            samples.clear()
        }
    }

    fun remove() = viewModelScope.launch {
        if (mode == FaceRegistrationMode.PUBLIC_INITIAL) {
            initialPermit = null
            _state.value = FaceRegistrationState(
                message = "El autorregistro no permite eliminar ni reemplazar un rostro."
            )
            return@launch
        }
        val employee = _state.value.employee ?: return@launch
        faces.delete(employee.id)
        _state.value = _state.value.copy(registered = false, samples = 0, capturing = false, registrationCompleted = false, message = "Rostro eliminado completamente.")
    }

    override fun onCleared() {
        initialPermit = null
        samples.forEach { it.fill(0f) }
        samples.clear()
        super.onCleared()
    }

    private fun debug(tag: String, message: String) {
        if (BuildConfig.DEBUG) Log.d(tag, message)
    }

    private fun crashLog(message: String) {
        if (BuildConfig.DEBUG) Log.d("FACE_REGISTRATION_CRASH", message)
    }

    private class InitialEnrollmentException(message: String) : IllegalStateException(message)
}

internal fun initialEnrollmentMessage(reason: InitialFaceEnrollmentDenial): String = when (reason) {
    InitialFaceEnrollmentDenial.INVALID_EMPLOYEE_CODE ->
        "Introduzca un código válido de 6 dígitos."
    InitialFaceEnrollmentDenial.EMPLOYEE_NOT_FOUND ->
        "No existe un empleado con ese código."
    InitialFaceEnrollmentDenial.EMPLOYEE_CODE_AMBIGUOUS ->
        "El código coincide con más de un empleado. Contacte al administrador."
    InitialFaceEnrollmentDenial.EMPLOYEE_INACTIVE,
    InitialFaceEnrollmentDenial.REMOTE_EMPLOYEE_INACTIVE ->
        "El empleado no está activo."
    InitialFaceEnrollmentDenial.JOURNEY_DISABLED ->
        "El empleado no tiene la jornada habilitada."
    InitialFaceEnrollmentDenial.COMPANY_MISMATCH,
    InitialFaceEnrollmentDenial.BRANCH_MISMATCH ->
        "El empleado no pertenece a la empresa o sucursal de este dispositivo."
    InitialFaceEnrollmentDenial.LOCAL_FACE_ALREADY_REGISTERED,
    InitialFaceEnrollmentDenial.REMOTE_FACE_ALREADY_REGISTERED,
    InitialFaceEnrollmentDenial.CONCURRENT_ENROLLMENT ->
        "Este empleado ya tiene un rostro registrado.\n" +
            "Solicite a un administrador si necesita reemplazarlo."
    InitialFaceEnrollmentDenial.REMOTE_FACE_INVALID ->
        "Existe un registro facial remoto que requiere revisión administrativa."
    InitialFaceEnrollmentDenial.EMPLOYEE_NOT_SYNCED ->
        "Este empleado todavía no está sincronizado en el dispositivo."
    InitialFaceEnrollmentDenial.DEVICE_SCOPE_MISSING ->
        "El dispositivo no tiene una empresa configurada."
    InitialFaceEnrollmentDenial.REMOTE_EMPLOYEE_NOT_FOUND ->
        "El empleado no existe en la empresa sincronizada."
    InitialFaceEnrollmentDenial.REMOTE_VALIDATION_FAILED ->
        "No se pudo validar el registro facial. Intente nuevamente."
    InitialFaceEnrollmentDenial.INVALID_EMBEDDING,
    InitialFaceEnrollmentDenial.STORAGE_FAILED ->
        "No se pudo guardar el rostro. Intente nuevamente."
    InitialFaceEnrollmentDenial.PERMIT_EXPIRED,
    InitialFaceEnrollmentDenial.PERMIT_ALREADY_USED,
    InitialFaceEnrollmentDenial.EMPLOYEE_CHANGED ->
        "La validación expiró. Vuelva a validar el código de empleado."
}
