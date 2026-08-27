package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "supervisor_events",
    indices = [Index(value = ["supervisorId"]), Index(value = ["employeeId"]), Index(value = ["eventDate"])]
)
data class SupervisorEventEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val supervisorId: Int,
    val employeeId: Int,
    val employeeName: String,
    val departmentName: String,
    val eventType: String,
    val eventDate: String,
    val detail: String,
    val minutes: Int = 0,
    val severity: String = "ROJO",
    val reviewed: Boolean = false,
    val createdAt: Long = System.currentTimeMillis(),
    val notificationPending: Boolean = false
)
