package com.example.controlhorario.ui.face

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.face.FaceEmbeddingCipher
import com.example.controlhorario.face.FaceEmbeddingEngine
import com.example.controlhorario.face.FaceVerificationPolicy
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface FaceVerificationState {
    data object Loading : FaceVerificationState
    data object Ready : FaceVerificationState
    data object FaceNotRegistered : FaceVerificationState
    data object InvalidTemplate : FaceVerificationState
    data object Processing : FaceVerificationState
    data object Recognized : FaceVerificationState
    data object NotRecognized : FaceVerificationState
    data object AttemptsExhausted : FaceVerificationState
    data class Error(val message: String) : FaceVerificationState
}

/** Holds the decrypted reference only for the lifetime of this verification screen. */
class FaceVerificationViewModel(
    private val employeeId: Int,
    private val faces: EmployeeFaceBiometricRepository,
    private val cipher: FaceEmbeddingCipher = FaceEmbeddingCipher()
) : ViewModel() {
    private val _state = MutableStateFlow<FaceVerificationState>(FaceVerificationState.Loading)
    val state: StateFlow<FaceVerificationState> = _state.asStateFlow()

    private var reference: FloatArray? = null
    private val policy = FaceVerificationPolicy()
    private var completed = false

    fun load() = viewModelScope.launch {
        val record = faces.activeForEmployee(employeeId)
        if (record == null) {
            _state.value = FaceVerificationState.FaceNotRegistered
            return@launch
        }
        if (record.embeddingDimension != FaceEmbeddingEngine.EMBEDDING_DIMENSION) {
            _state.value = FaceVerificationState.InvalidTemplate
            return@launch
        }
        reference = runCatching {
            cipher.decrypt(record.encryptedEmbedding, record.embeddingDimension)
        }.getOrElse {
            _state.value = FaceVerificationState.InvalidTemplate
            return@launch
        }
        _state.value = if (reference?.size == FaceEmbeddingEngine.EMBEDDING_DIMENSION) {
            FaceVerificationState.Ready
        } else {
            FaceVerificationState.InvalidTemplate
        }
    }

    fun score(embedding: FloatArray) {
        val currentReference = reference ?: return
        if (completed || embedding.size != FaceEmbeddingEngine.EMBEDDING_DIMENSION) return

        _state.value = FaceVerificationState.Processing
        when (policy.accept(FaceEmbeddingEngine.cosine(currentReference, embedding))) {
            FaceVerificationPolicy.Decision.Accepted -> {
                completed = true
                _state.value = FaceVerificationState.Recognized
            }
            FaceVerificationPolicy.Decision.ReturnToCode -> {
                _state.value = FaceVerificationState.AttemptsExhausted
            }
            FaceVerificationPolicy.Decision.Retry -> {
                _state.value = FaceVerificationState.NotRecognized
            }
            FaceVerificationPolicy.Decision.Continue -> {
                _state.value = FaceVerificationState.Ready
            }
        }
    }

    override fun onCleared() {
        reference?.fill(0f)
        reference = null
        super.onCleared()
    }
}
