package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "n8n_settings")
data class N8NSettingsEntity(
    @PrimaryKey
    val id: Int = 1,
    val webhookUrl: String = "",
    val apiKey: String = "",
    val bearerToken: String = "",
    val timeoutSeconds: Int = 20,
    val enabled: Boolean = false,
    val lastStatus: String = STATUS_NOT_CONFIGURED,
    val lastMessage: String = "",
    val lastTestAt: String = "",
    val updatedAt: String = ""
) {
    companion object {
        const val STATUS_NOT_CONFIGURED = "SIN_CONFIGURAR"
        const val STATUS_CONNECTED = "CONECTADO"
        const val STATUS_ERROR = "ERROR"
    }
}
