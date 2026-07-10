package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "app_events")
data class AppEventEntity(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val title: String,
    val description: String,
    val module: String,
    val isRead: Boolean = false,
    val createdAt: String = System.currentTimeMillis().toString(),
    val openedAt: String = ""
)
