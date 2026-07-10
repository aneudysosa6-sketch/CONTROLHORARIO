package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "n8n_outbox")
data class N8NOutboxEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val eventType: String,
    val title: String,
    val payloadJson: String,
    val status: String = STATUS_PENDING,
    val attempts: Int = 0,
    val createdAt: String,
    val updatedAt: String = createdAt,
    val sentAt: String = "",
    val responseCode: Int = 0,
    val responseMessage: String = "",
    val errorMessage: String = ""
) {
    companion object {
        const val STATUS_PENDING = "PENDIENTE"
        const val STATUS_SENT = "ENVIADO"
        const val STATUS_ERROR = "ERROR"
    }
}
