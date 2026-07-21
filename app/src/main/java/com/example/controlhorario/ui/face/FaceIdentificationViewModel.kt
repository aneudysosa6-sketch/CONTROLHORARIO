package com.example.controlhorario.ui.face

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.DeviceEnrollmentDao
import com.example.controlhorario.face.FaceIdentificationConfig
import com.example.controlhorario.face.FaceIdentificationEngine
import com.example.controlhorario.face.FaceIdentificationError
import com.example.controlhorario.face.FaceIdentificationResult
import com.example.controlhorario.face.FaceTemplateCache
import com.example.controlhorario.face.FaceTemplateScope
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.repository.KioskSettingsRepository
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class FaceIdentificationPhase {
    PREPARING,
    SEARCHING,
    IDENTIFYING,
    IDENTIFIED,
    AMBIGUOUS,
    NO_MATCH,
    NO_TEMPLATES,
    SYNCING,
    CONFIGURATION_REQUIRED,
    PIN_REQUIRED,
    ERROR,
}

data class FaceIdentificationUiState(
    val phase: FaceIdentificationPhase = FaceIdentificationPhase.PREPARING,
    val message: String = "Preparando identificación facial…",
    val employee: Employee? = null,
    val canUsePin: Boolean = false,
    val canRetry: Boolean = false,
    val completedSamples: Int = 0,
    val requiredSamples: Int = FaceIdentificationSessionPolicy.REQUIRED_CONSECUTIVE_MATCHES,
) {
    val cameraEnabled: Boolean
        get() = phase == FaceIdentificationPhase.SEARCHING || phase == FaceIdentificationPhase.IDENTIFYING
}

fun interface FaceTemplateSyncGateway {
    suspend fun synchronize(): Boolean
}

/** Owns decrypted 1:N templates only for the lifetime of this screen. */
class FaceIdentificationViewModel(
    private val deviceId: String,
    private val enrollmentDao: DeviceEnrollmentDao,
    private val settingsRepository: KioskSettingsRepository,
    private val employeeRepository: EmployeeRepository,
    private val faceRepository: EmployeeFaceBiometricRepository,
    private val syncGateway: FaceTemplateSyncGateway,
) : ViewModel() {
    private val mutableState = MutableStateFlow(FaceIdentificationUiState())
    val state: StateFlow<FaceIdentificationUiState> = mutableState.asStateFlow()

    private val identifying = AtomicBoolean(false)
    private val stability = FaceIdentificationSessionPolicy()
    private var engine: FaceIdentificationEngine? = null
    private var scope: FaceTemplateScope? = null
    private var pinFallbackEnabled = false
    private var started = false
    private var timeoutJob: Job? = null

    fun start() {
        if (started) return
        started = true
        viewModelScope.launch { prepare() }
    }

    fun onEmbedding(embedding: FloatArray, embeddingMs: Long) {
        val currentEngine = engine
        val currentScope = scope
        if (currentEngine == null || currentScope == null || !mutableState.value.cameraEnabled || !identifying.compareAndSet(false, true)) {
            embedding.fill(0f)
            return
        }
        mutableState.value = mutableState.value.copy(
            phase = FaceIdentificationPhase.IDENTIFYING,
            message = "Identificando empleado…",
        )
        viewModelScope.launch {
            try {
                when (val decision = stability.accept(currentEngine.identify(embedding, currentScope, embeddingMs))) {
                    is FaceIdentificationSessionPolicy.Decision.Continue -> {
                        mutableState.value = mutableState.value.copy(
                            phase = FaceIdentificationPhase.SEARCHING,
                            message = if (decision.consecutiveMatches > 0) "Rostro detectado" else "Buscando rostro…",
                            completedSamples = decision.consecutiveMatches,
                        )
                    }

                    is FaceIdentificationSessionPolicy.Decision.Confirmed -> confirmEmployee(decision.result)
                    FaceIdentificationSessionPolicy.Decision.Ambiguous -> conclude(
                        FaceIdentificationPhase.AMBIGUOUS,
                        "Hay más de una coincidencia posible.",
                    )

                    FaceIdentificationSessionPolicy.Decision.NoMatch -> conclude(
                        FaceIdentificationPhase.NO_MATCH,
                        "No pudimos identificarte.",
                    )

                    FaceIdentificationSessionPolicy.Decision.NoTemplates -> conclude(
                        FaceIdentificationPhase.NO_TEMPLATES,
                        "No hay rostros disponibles en este dispositivo.",
                        allowRetry = true,
                    )

                    is FaceIdentificationSessionPolicy.Decision.Error -> {
                        if (decision.result.reason != FaceIdentificationError.IDENTIFICATION_IN_PROGRESS) {
                            conclude(FaceIdentificationPhase.ERROR, "No fue posible completar la identificación.", allowRetry = true)
                        }
                    }
                }
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                Log.e(TAG, "result=ERROR type=${error.javaClass.simpleName}")
                conclude(FaceIdentificationPhase.ERROR, "No fue posible completar la identificación.", allowRetry = true)
            } finally {
                embedding.fill(0f)
                identifying.set(false)
            }
        }
    }

    fun retry() {
        if (mutableState.value.phase == FaceIdentificationPhase.SYNCING) return
        if (engine == null || scope == null) {
            mutableState.value = FaceIdentificationUiState()
            viewModelScope.launch { prepare() }
            return
        }
        stability.reset()
        mutableState.value = FaceIdentificationUiState(
            phase = FaceIdentificationPhase.SEARCHING,
            message = "Buscando rostro…",
            canUsePin = false,
        )
        scheduleTimeout()
    }

    fun synchronizeTemplates() {
        if (mutableState.value.phase == FaceIdentificationPhase.SYNCING) return
        timeoutJob?.cancel()
        mutableState.value = mutableState.value.copy(
            phase = FaceIdentificationPhase.SYNCING,
            message = "Sincronizando rostros…",
            canUsePin = false,
            canRetry = false,
        )
        viewModelScope.launch {
            val synchronized = runCatching { syncGateway.synchronize() }.getOrDefault(false)
            engine?.clearSession()
            if (synchronized) retry() else conclude(
                FaceIdentificationPhase.ERROR,
                "No se pudo sincronizar. Verifique la conexión y reintente.",
                allowRetry = true,
            )
        }
    }

    private suspend fun prepare() {
        val enrollment = enrollmentDao.current()
        val storedSettings = settingsRepository.currentForDevice(deviceId)
        val companyId = enrollment?.companyId ?: storedSettings?.companyId
        val settings = storedSettings?.takeIf { it.companyId == companyId }
        pinFallbackEnabled = settings?.pinFallbackEnabled ?: true

        if (companyId.isNullOrBlank()) {
            conclude(FaceIdentificationPhase.NO_TEMPLATES, "Sincronice el dispositivo para cargar los rostros de su empresa.", allowRetry = true)
            return
        }
        if (settings?.faceOnlyEnabled == false) {
            mutableState.value = FaceIdentificationUiState(
                phase = FaceIdentificationPhase.PIN_REQUIRED,
                message = "Use PIN para continuar con la verificación facial.",
                canUsePin = pinFallbackEnabled,
            )
            return
        }
        val margin = settings?.faceMatchMargin
        if (margin == null) {
            mutableState.value = FaceIdentificationUiState(
                phase = FaceIdentificationPhase.CONFIGURATION_REQUIRED,
                message = "La identificación facial necesita calibración del administrador.",
                canUsePin = pinFallbackEnabled,
                canRetry = false,
            )
            return
        }

        val cache = FaceTemplateCache(faceRepository)
        engine = FaceIdentificationEngine(
            cache = cache,
            config = FaceIdentificationConfig(
                matchThreshold = settings.faceMatchThreshold,
                matchMargin = margin,
            ),
        )
        scope = FaceTemplateScope(
            companyScopeKey = companyId,
            remoteBranchId = enrollment?.branchId,
        )
        mutableState.value = FaceIdentificationUiState(
            phase = FaceIdentificationPhase.SEARCHING,
            message = "Buscando rostro…",
        )
        scheduleTimeout()
    }

    private suspend fun confirmEmployee(result: FaceIdentificationResult.MatchConfirmed) {
        val employee = employeeRepository.findActiveByLocalId(result.employee.localEmployeeId)
        if (employee == null || !employee.jornadaEnabled) {
            stability.reset()
            conclude(FaceIdentificationPhase.NO_MATCH, "No pudimos identificarte.")
            return
        }
        timeoutJob?.cancel()
        engine?.clearSession()
        mutableState.value = mutableState.value.copy(
            phase = FaceIdentificationPhase.IDENTIFIED,
            message = "Empleado identificado: ${employee.nombre}",
            employee = employee,
            canUsePin = false,
            canRetry = false,
            completedSamples = FaceIdentificationSessionPolicy.REQUIRED_CONSECUTIVE_MATCHES,
        )
    }

    private fun conclude(
        phase: FaceIdentificationPhase,
        message: String,
        allowRetry: Boolean = true,
    ) {
        timeoutJob?.cancel()
        mutableState.value = mutableState.value.copy(
            phase = phase,
            message = message,
            employee = null,
            canUsePin = pinFallbackEnabled && (phase == FaceIdentificationPhase.AMBIGUOUS || phase == FaceIdentificationPhase.NO_MATCH),
            canRetry = allowRetry,
            completedSamples = 0,
        )
    }

    private fun scheduleTimeout() {
        timeoutJob?.cancel()
        timeoutJob = viewModelScope.launch {
            delay(IDENTIFICATION_TIMEOUT_MILLIS)
            if (mutableState.value.cameraEnabled) {
                stability.reset()
                conclude(FaceIdentificationPhase.NO_MATCH, "No pudimos identificarte.")
            }
        }
    }

    override fun onCleared() {
        timeoutJob?.cancel()
        engine?.close()
        engine = null
        scope = null
        super.onCleared()
    }

    private companion object {
        const val IDENTIFICATION_TIMEOUT_MILLIS = 20_000L
        const val TAG = "FACE_IDENTIFICATION_PERF"
    }
}

class FaceIdentificationViewModelFactory(
    private val deviceId: String,
    private val enrollmentDao: DeviceEnrollmentDao,
    private val settingsRepository: KioskSettingsRepository,
    private val employeeRepository: EmployeeRepository,
    private val faceRepository: EmployeeFaceBiometricRepository,
    private val syncGateway: FaceTemplateSyncGateway,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(FaceIdentificationViewModel::class.java)) {
            return FaceIdentificationViewModel(
                deviceId,
                enrollmentDao,
                settingsRepository,
                employeeRepository,
                faceRepository,
                syncGateway,
            ) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class")
    }
}
