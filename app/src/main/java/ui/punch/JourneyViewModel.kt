package com.example.controlhorario.ui.punch

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.attendance.AttendanceSyncScheduler
import com.example.controlhorario.database.JourneyEntity
import com.example.controlhorario.engine.JourneyAction
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.JourneyCurrentStateOutcome
import com.example.controlhorario.repository.JourneyCurrentStateSyncException
import com.example.controlhorario.repository.JourneyRepository
import com.example.controlhorario.security.DeviceIdentityManager
import java.time.Instant
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeout

@OptIn(ExperimentalCoroutinesApi::class)
class JourneyViewModel(
    private val context: Context,
    private val repository: JourneyRepository,
    private val employeeId: Int,
    initialWorkDate: String
) : ViewModel() {
    private val identity = DeviceIdentityManager(context)
    private val selectedWorkDate = MutableStateFlow(initialWorkDate)
    private val _remotePresentation = MutableStateFlow(JourneyRemotePresentation.loading())

    val workDate: StateFlow<String> = selectedWorkDate.asStateFlow()
    val journey: StateFlow<JourneyEntity?> = selectedWorkDate
        .flatMapLatest { repository.observe(employeeId, it) }
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)
    val remotePresentation: StateFlow<JourneyRemotePresentation> = _remotePresentation.asStateFlow()
    val loadingRemote = MutableStateFlow(true)
    val busy = MutableStateFlow(false)
    val error = MutableStateFlow("")
    val isPunchAuthorized = MutableStateFlow(currentAuthorization())

    init {
        refreshCurrentState()
    }

    fun refreshAuthorization() {
        isPunchAuthorized.value = currentAuthorization()
    }

    fun record(employee: Employee, action: JourneyAction, onSaved: () -> Unit) {
        val availableActions=JourneyActionAvailability.allowedActions(
            journey.value?.status,
            _remotePresentation.value.access
        )
        if (busy.value || action !in availableActions) return
        val deviceId = identity.deviceId
        val authorized = deviceId != null && JourneyBiometricGate.isAuthorized(employee.id, deviceId)
        isPunchAuthorized.value = authorized
        logAuth(employee.id, authorized, action)
        if (!authorized) {
            error.value = "Debe verificar PIN y rostro antes de cada acción."
            return
        }

        busy.value = true
        error.value = ""
        viewModelScope.launch {
            var proof: JourneyBiometricProof? = null
            runCatching {
                val remoteId = requireNotNull(employee.remoteId) { "Empleado pendiente de sincronización remota." }
                val safeDeviceId = requireNotNull(deviceId) { "Dispositivo no enrolado." }
                proof = requireNotNull(
                    JourneyBiometricGate.prepareProof(employee.id, safeDeviceId, action)
                ) { "BIOMETRIC_PROOF_REQUIRED" }
                val signature = identity.sign(
                    "${proof!!.id}|$remoteId|$safeDeviceId|${action.name}|${proof!!.issuedAt}|${proof!!.expiresAt}".toByteArray()
                )
                repository.recordAction(
                    employee.id,
                    remoteId,
                    employee.employeeCode,
                    employee.nombre,
                    safeDeviceId,
                    employee.remoteBranchId,
                    employee.remoteDepartmentId,
                    selectedWorkDate.value,
                    Instant.now().toString(),
                    action,
                    employee.jornadaEnabled,
                    proof!!,
                    signature
                )
            }.onSuccess { localResult ->
                val consumed = JourneyBiometricGate.consumeAfterSuccess(requireNotNull(proof).id)
                isPunchAuthorized.value = false
                if (BuildConfig.DEBUG) {
                    Log.d(
                        "PUNCH_SAVE",
                        "employeeId=${employee.id} action=${action.name} localRecordId=${localResult.journey.localId} " +
                            "outboxId=${localResult.outboxId} status=${localResult.journey.status} " +
                            "timestamp=${localResult.journey.updatedAt} syncStatus=${localResult.journey.syncStatus}"
                    )
                }
                logAction(employee.id, action, "saved authorizationConsumed=$consumed")
                AttendanceSyncScheduler.enqueue(context)
                onSaved()
            }.onFailure {
                isPunchAuthorized.value = currentAuthorization()
                logAction(employee.id, action, "failed type=${it.javaClass.simpleName}")
                error.value = when (it.message) {
                    "ATTENDANCE_DISABLED" -> "Tu registro de jornada está deshabilitado."
                    "ALREADY_FINALIZED" -> "La jornada de hoy ya fue finalizada."
                    "BIOMETRIC_PROOF_REQUIRED" -> "Debe verificar PIN y rostro antes de cada acción."
                    else -> it.message ?: "No fue posible registrar la jornada."
                }
            }
            busy.value = false
        }
    }

    private fun refreshCurrentState() {
        viewModelScope.launch {
            updateRemotePresentation(JourneyRemotePresentation.loading())
            val requestedAt = Instant.now().toString()
            val localBefore = runCatching {
                repository.observe(employeeId, selectedWorkDate.value).first()
            }.getOrNull()

            runCatching {
                repository.refreshCurrentState(employeeId, requestedAt)
            }.onSuccess { result ->
                selectedWorkDate.value = result.workDate
                when (result.finalResult) {
                    JourneyCurrentStateOutcome.LOCAL_PENDING -> {
                        updateRemotePresentation(JourneyRemotePresentation.pendingLocalAction())
                    }
                    JourneyCurrentStateOutcome.CONFLICT -> {
                        updateRemotePresentation(JourneyRemotePresentation.conflict())
                    }
                    JourneyCurrentStateOutcome.NETWORK_ERROR,
                    JourneyCurrentStateOutcome.LOCAL_CACHE -> {
                        val cache = readDisplayedJourney(result.workDate) ?: localBefore
                        updateRemotePresentation(cachedPresentation(cache))
                    }
                    JourneyCurrentStateOutcome.REMOTE_SUCCESS,
                    JourneyCurrentStateOutcome.REMOTE_EMPTY -> {
                        runCatching {
                            awaitRoomRefresh(result.workDate, result.remoteExists, result.remoteVersion)
                        }.onSuccess {
                            updateRemotePresentation(JourneyRemotePresentation.confirmed())
                        }.onFailure {
                            updateRemotePresentation(JourneyRemotePresentation.networkFailure(null))
                        }
                    }
                }
            }.onFailure { failure ->
                val cache = readDisplayedJourney(selectedWorkDate.value) ?: localBefore
                val presentation = when ((failure as? JourneyCurrentStateSyncException)?.outcome) {
                    JourneyCurrentStateOutcome.LOCAL_PENDING -> JourneyRemotePresentation.pendingLocalAction()
                    JourneyCurrentStateOutcome.CONFLICT -> JourneyRemotePresentation.conflict()
                    else -> cachedPresentation(cache)
                }
                updateRemotePresentation(presentation)
            }
        }
    }

    private suspend fun awaitRoomRefresh(workDate: String, remoteExists: Boolean, remoteVersion: Long?) {
        withTimeout(5_000) {
            journey.first { local ->
                if (!remoteExists) {
                    local == null || local.workDate == workDate
                } else {
                    local != null &&
                        local.workDate == workDate &&
                        (remoteVersion == null || local.syncVersion >= remoteVersion)
                }
            }
        }
    }

    private suspend fun readDisplayedJourney(workDate: String): JourneyEntity? = runCatching {
        repository.observe(employeeId, workDate).first()
    }.getOrNull()

    private suspend fun cachedPresentation(cache: JourneyEntity?): JourneyRemotePresentation {
        if (!cache.isValidJourneyCache()) return JourneyRemotePresentation.networkFailure(null)
        val validCache = requireNotNull(cache)
        selectedWorkDate.value = validCache.workDate
        return runCatching {
            awaitRoomRefresh(
                validCache.workDate,
                remoteExists = true,
                remoteVersion = validCache.syncVersion
            )
            JourneyRemotePresentation.networkFailure(validCache)
        }.getOrElse {
            JourneyRemotePresentation.networkFailure(null)
        }
    }

    private fun updateRemotePresentation(value: JourneyRemotePresentation) {
        _remotePresentation.value = value
        loadingRemote.value = value.loadingRemote
    }

    private fun currentAuthorization(): Boolean {
        val deviceId = identity.deviceId ?: return false
        return JourneyBiometricGate.isAuthorized(employeeId, deviceId)
    }

    private fun logAuth(targetEmployeeId: Int, authorized: Boolean, action: JourneyAction? = null) {
        if (BuildConfig.DEBUG) {
            Log.d(
                "PUNCH_AUTH",
                "employeeId=$targetEmployeeId pinVerified=true faceVerified=$authorized " +
                    "authorizedEmployeeId=$employeeId authorizationConsumed=${!authorized} " +
                    "isPunchAuthorized=$authorized action=${action?.name.orEmpty()}"
            )
        }
    }

    private fun logAction(targetEmployeeId: Int, action: JourneyAction, result: String) {
        if (BuildConfig.DEBUG) {
            Log.d("PUNCH_ACTION", "employeeId=$targetEmployeeId action=${action.name} result=$result")
        }
    }
}

class JourneyViewModelFactory(
    private val context: Context,
    private val repository: JourneyRepository,
    private val employeeId: Int,
    private val workDate: String
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        JourneyViewModel(context.applicationContext, repository, employeeId, workDate) as T
}
