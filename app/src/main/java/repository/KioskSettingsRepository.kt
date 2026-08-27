package com.example.controlhorario.repository

import com.example.controlhorario.database.KioskSettingsDao
import com.example.controlhorario.database.KioskSettingsEntity
import com.example.controlhorario.face.FaceEmbeddingEngine
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

data class KioskFaceAuthSettings(
    val companyId: String,
    val deviceId: String,
    val faceOnlyEnabled: Boolean,
    val pinFallbackEnabled: Boolean,
    val faceMatchThreshold: Float,
    val faceMatchMargin: Float?,
    val remoteUpdatedAt: String?,
    val lastSyncedAt: Long?,
)

class KioskSettingsRepository(private val dao: KioskSettingsDao) {
    fun observe(companyId: String, deviceId: String): Flow<KioskFaceAuthSettings> =
        dao.observe(companyId, deviceId).map { it?.toDomain() ?: defaults(companyId, deviceId) }

    suspend fun current(companyId: String, deviceId: String): KioskFaceAuthSettings =
        dao.current(companyId, deviceId)?.toDomain() ?: defaults(companyId, deviceId)

    suspend fun currentForDevice(deviceId: String): KioskFaceAuthSettings? =
        dao.currentForDevice(deviceId)?.toDomain()

    suspend fun saveRemote(settings: KioskSettingsEntity) {
        require(UUID_REGEX.matches(settings.companyId)) { "COMPANY_ID_INVALID" }
        require(UUID_REGEX.matches(settings.deviceId)) { "DEVICE_ID_INVALID" }
        validate(settings.faceMatchThreshold, settings.faceMatchMargin)
        dao.save(settings)
    }

    private fun KioskSettingsEntity.toDomain() = KioskFaceAuthSettings(
        companyId = companyId,
        deviceId = deviceId,
        faceOnlyEnabled = faceOnlyEnabled,
        pinFallbackEnabled = pinFallbackEnabled,
        faceMatchThreshold = faceMatchThreshold,
        faceMatchMargin = faceMatchMargin,
        remoteUpdatedAt = remoteUpdatedAt,
        lastSyncedAt = lastSyncedAt,
    )

    companion object {
        private val UUID_REGEX = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
        fun defaults(companyId: String, deviceId: String) = KioskFaceAuthSettings(
            companyId = companyId,
            deviceId = deviceId,
            faceOnlyEnabled = true,
            pinFallbackEnabled = true,
            faceMatchThreshold = FaceEmbeddingEngine.COSINE_THRESHOLD,
            faceMatchMargin = null,
            remoteUpdatedAt = null,
            lastSyncedAt = null,
        )

        fun validate(threshold: Float, margin: Float?) {
            require(threshold.isFinite() && threshold in 0f..1f) { "FACE_MATCH_THRESHOLD_INVALID" }
            require(margin == null || margin.isFinite() && margin in 0f..2f) { "FACE_MATCH_MARGIN_INVALID" }
        }
    }
}
