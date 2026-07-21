package com.example.controlhorario.database

/**
 * Minimal Room projection used to build the in-memory face-identification cache.
 * The encrypted value never leaves the repository/cache boundary.
 */
data class FaceIdentificationTemplateRecord(
    val employeeId: Int,
    val employeeCode: String,
    val employeeName: String,
    val remoteCompanyId: String?,
    val remoteBranchId: String?,
    val employeeActive: Boolean,
    val jornadaEnabled: Boolean,
    val biometricActive: Boolean,
    val encryptedEmbedding: String,
    val embeddingDimension: Int
)
