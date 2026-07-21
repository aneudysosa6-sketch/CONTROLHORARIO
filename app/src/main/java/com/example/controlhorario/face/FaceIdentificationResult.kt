package com.example.controlhorario.face

enum class FaceIdentificationStatus {
    MATCH_CONFIRMED,
    MATCH_AMBIGUOUS,
    NO_MATCH,
    NO_TEMPLATES,
    ERROR
}

enum class FaceIdentificationError {
    INVALID_EMBEDDING,
    CACHE_LOAD_FAILED,
    CACHE_CLOSED,
    IDENTIFICATION_IN_PROGRESS
}

data class FaceIdentifiedEmployee(
    val localEmployeeId: Int,
    val employeeCode: String,
    val employeeName: String
)

sealed interface FaceIdentificationResult {
    val status: FaceIdentificationStatus
    val topScore: Float?
    val secondScore: Float?
    val scoreMargin: Float?

    data class MatchConfirmed(
        val employee: FaceIdentifiedEmployee,
        override val topScore: Float,
        override val secondScore: Float?,
        override val scoreMargin: Float?
    ) : FaceIdentificationResult {
        override val status = FaceIdentificationStatus.MATCH_CONFIRMED
    }

    data class MatchAmbiguous(
        override val topScore: Float,
        override val secondScore: Float,
        override val scoreMargin: Float
    ) : FaceIdentificationResult {
        override val status = FaceIdentificationStatus.MATCH_AMBIGUOUS
    }

    data class NoMatch(
        override val topScore: Float?,
        override val secondScore: Float?,
        override val scoreMargin: Float?
    ) : FaceIdentificationResult {
        override val status = FaceIdentificationStatus.NO_MATCH
    }

    data object NoTemplates : FaceIdentificationResult {
        override val status = FaceIdentificationStatus.NO_TEMPLATES
        override val topScore: Float? = null
        override val secondScore: Float? = null
        override val scoreMargin: Float? = null
    }

    data class Error(val reason: FaceIdentificationError) : FaceIdentificationResult {
        override val status = FaceIdentificationStatus.ERROR
        override val topScore: Float? = null
        override val secondScore: Float? = null
        override val scoreMargin: Float? = null
    }
}

/**
 * The threshold deliberately inherits the value already used by the 1:1 verifier.
 * No default margin is provided: it must come from measured/company configuration.
 */
data class FaceIdentificationConfig(
    val matchMargin: Float,
    val matchThreshold: Float = FaceEmbeddingEngine.COSINE_THRESHOLD
) {
    init {
        require(matchThreshold.isFinite() && matchThreshold in -1f..1f) {
            "invalid_face_match_threshold"
        }
        require(matchMargin.isFinite() && matchMargin in 0f..2f) {
            "invalid_face_match_margin"
        }
    }
}

/**
 * Company is part of the cache key so decrypted templates are never reused after a
 * company-context change. Room employee data is already scoped by employee-sync.
 */
data class FaceTemplateScope(
    val companyScopeKey: String,
    val remoteBranchId: String? = null
) {
    init {
        require(companyScopeKey.isNotBlank()) { "missing_company_scope" }
    }
}
