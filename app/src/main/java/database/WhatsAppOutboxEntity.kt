package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "whatsapp_outbox")
data class WhatsAppOutboxEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val phoneNumber: String,
    val message: String,
    val payloadJson: String = "",
    val status: String = STATUS_PENDING,
    val createdAt: String,
    val updatedAt: String = createdAt,
    val sentAt: String = "",
    val errorMessage: String = "",
    val isActive: Boolean = true
) {
    companion object {
        const val STATUS_PENDING = "PENDIENTE"
        const val STATUS_SENT = "ENVIADO"
        const val STATUS_ERROR = "ERROR"
    }
}
