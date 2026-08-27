package com.example.controlhorario.database

import androidx.room.Entity

@Entity(
    tableName = "kiosk_settings",
    primaryKeys = ["companyId", "deviceId"]
)
data class KioskSettingsEntity(
    val companyId: String,
    val deviceId: String,
    val faceOnlyEnabled: Boolean = true,
    val pinFallbackEnabled: Boolean = true,
    val faceMatchThreshold: Float = 0.75f,
    val faceMatchMargin: Float? = null,
    val remoteUpdatedAt: String,
    val lastSyncedAt: Long,
)
