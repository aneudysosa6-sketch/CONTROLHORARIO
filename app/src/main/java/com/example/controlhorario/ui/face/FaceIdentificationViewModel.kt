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
import com.example.controlhorario.face.FaceTemplateInvalidationBus
import com.example.controlhorario.face.FaceTemplateScope
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.repository.KioskSettingsRepository
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

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
    ERROR,
}

data class FaceIdentificationUiState(
    val phase: FaceIdentificationPhase = FaceIdentificationPhase.PREPARING,
    val message: String = "Preparando identificación facial…",
    val employee: Employee? = null,
    val canUseEmployeeCode: Boolean = false,
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
    private val templateUseMutex = Mutex()
    private val stability = FaceIdentificationSessionPolicy()
    private var engine: FaceIdentificationEngine? = null
    private var scope: FaceTemplateScope? = null
    private var employeeCodeFallbackEnabled = false
    private var started = false
    private var timeoutJob: Job? = null
    private var identificationJob: Job? = null
    private var observedTemplateRevision = FaceTemplateInvalidationBus.currentRevision

    init {
        viewModelScope.launch {
            FaceTemplateInvalidationBus.revisions.collect { revision ->
                if (revision <= observedTemplateRevision) return@collect
                observedTemplateRevision = revision
                invalidateTemplateSession(revision)
            }
        }
    }

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
        val identificationRevision = FaceTemplateInvalidationBus.currentRevision
        identificationJob = viewModelScope.launch {
            try {
                if (identificationRevision != observedTemplateRevision) {
                    // Do not combine samples collected before and after a Room face change.
                    stability.reset()
                }
                val result = templateUseMutex.withLock {
                    currentEngine.identify(embedding, currentScope, embeddingMs)
                }
                if (identificationRevision != FaceTemplateInvalidationBus.currentRevision) {
                    stability.reset()
                    return@launch
                }
                when (val decision = stability.accept(result)) {
                    is FaceIdentificationSessionPolicy.Decision.Continue -> {
                        mutableState.value = mutableState.value.copy(
                            phase = FaceIdentificationPhase.SEARCHING,
                            message = if (decision.consecutiveMatches > 0) "Rostro detectado" else "Buscando rostro…",
                            completedSamples = decision.consecutiveMatches,
                        )
                    }

                    is FaceIdentificationSessionPolicy.Decision.Confirmed ->
                        confirmEmployee(decision.result, identificationRevision)
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
                identificationJob = null
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
            canUseEmployeeCode = employeeCodeFallbackEnabled,
        )
        scheduleTimeout()
    }

    fun synchronizeTemplates() {
        if (mutableState.value.phase == FaceIdentificationPhase.SYNCING) return
        timeoutJob?.cancel()
        mutableState.value = mutableState.value.copy(
            phase = FaceIdentificationPhase.SYNCING,
            message = "Sincronizando rostros…",
            canUseEmployeeCode = false,
            canRetry = false,
        )
        viewModelScope.launch {
            val synchronized = try {
                syncGateway.synchronize()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                false
            }
            identificationJob?.cancelAndJoin()
            identificationJob = null
            identifying.set(false)
            stability.reset()
            templateUseMutex.withLock { engine?.clearSession() }
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
        // pinFallbackEnabled is the legacy persisted column name. Functionally it now means
        // employee-code fallback; an employee PIN is never read or verified.
        employeeCodeFallbackEnabled = settings?.pinFallbackEnabled ?: true

        if (companyId.isNullOrBlank()) {
            conclude(FaceIdentificationPhase.NO_TEMPLATES, "Sincronice el dispositivo para cargar los rostros de su empresa.", allowRetry = true)
            return
        }
        // The legacy faceOnlyEnabled flag no longer selects a code-first flow. Employee mode
        // always starts with 1:N facial identification; code is offered only after no match.
        val margin = settings?.faceMatchMargin
        Log.d(
            TAG,
            "stage=config settingsPresent=${settings != null} " +
                "threshold=${settings?.faceMatchThreshold ?: "UNAVAILABLE"} " +
                "configuredMargin=${margin ?: "NULL"}"
        )
        if (margin == null) {
            mutableState.value = FaceIdentificationUiState(
                phase = FaceIdentificationPhase.CONFIGURATION_REQUIRED,
                message = "La identificación facial necesita calibración del administrador.",
                canUseEmployeeCode = employeeCodeFallbackEnabled,
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
            canUseEmployeeCode = employeeCodeFallbackEnabled,
        )
        scheduleTimeout()
    }

    private suspend fun confirmEmployee(
        result: FaceIdentificationResult.MatchConfirmed,
        identificationRevision: Long,
    ) {
        val employee = employeeRepository.findActiveByLocalId(result.employee.localEmployeeId)
        if (identificationRevision != FaceTemplateInvalidationBus.currentRevision) {
            stability.reset()
            return
        }
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
            canUseEmployeeCode = false,
            canRetry = false,
            completedSamples = FaceIdentificationSessionPolicy.REQUIRED_CONSECUTIVE_MATCHES,
        )
    }

    /**
     * Stop an in-flight comparison before wiping its arrays. This also clears a provisional
     * IDENTIFIED state, cancelling the screen's short navigation delay when Room revoked it.
     */
    private suspend fun invalidateTemplateSession(revision: Long) {
        val currentEngine = engine ?: return
        if (scope == null) return
        timeoutJob?.cancel()
        mutableState.value = FaceIdentificationUiState(
            phase = FaceIdentificationPhase.PREPARING,
            message = "Actualizando rostros…",
        )
        identificationJob?.cancelAndJoin()
        identificationJob = null
        identifying.set(false)
        stability.reset()
        templateUseMutex.withLock { currentEngine.clearSession() }
        mutableState.value = FaceIdentificationUiState(
            phase = FaceIdentificationPhase.SEARCHING,
            message = "Buscando rostro…",
            canUseEmployeeCode = employeeCodeFallbackEnabled,
        )
        Log.d(TAG, "templatesInvalidated=true revision=$revision")
        scheduleTimeout()
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
            canUseEmployeeCode = employeeCodeFallbackEnabled,
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
        identificationJob?.cancel()
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
