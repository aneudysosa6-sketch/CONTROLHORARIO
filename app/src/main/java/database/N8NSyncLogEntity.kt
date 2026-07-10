package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "n8n_sync_log")
data class N8NSyncLogEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val eventType: String,
    val status: String,
    val requestSummary: String,
    val responseCode: Int = 0,
    val responseMessage: String = "",
    val errorMessage: String = "",
    val createdAt: String
)
